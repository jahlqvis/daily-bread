const test = require("node:test");
const assert = require("node:assert/strict");
const { EventEmitter } = require("node:events");
const http = require("node:http");

const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const { deleteAccount, _internals } = require("./index");

const NOW_MS = 1700000000000;
const NOW_SECONDS = NOW_MS / 1000;
const REAUTH_MESSAGE = "Recent authentication is required. Please reauthenticate and try again.";

function fakeServices(count = 0, now = () => NOW_MS) {
  const users = new Map([
    ["alice", { exists: true, bookmarks: new Map() }],
    ["bob", { exists: true, bookmarks: new Map([["other", {}]]) }],
  ]);
  for (let i = 0; i < count; i++) {
    // The deletion must include tombstones and malformed documents as well.
    users.get("alice").bookmarks.set(`bookmark-${i}`, i % 2 ? { deletedAt: 1 } : {});
  }

  const calls = [];
  const failures = {};
  const logs = [];
  function failOnce(stage) {
    if (failures[stage]) {
      const error = failures[stage];
      delete failures[stage];
      throw error;
    }
  }

  const db = {
    collection(name) {
      assert.equal(name, "users");
      return {
        doc(uid) {
          const user = users.get(uid);
          assert.ok(user, `unexpected UID: ${uid}`);
          return {
            collection(name) {
              assert.equal(name, "bookmarks");
              return {
                limit(size) {
                  calls.push(["limit", uid, size]);
                  return {
                    async get() {
                      calls.push(["query", uid]);
                      failOnce("query");
                      const ids = [...user.bookmarks.keys()].slice(0, size);
                      return {
                        empty: ids.length === 0,
                        docs: ids.map((id) => ({ ref: { uid, id } })),
                      };
                    },
                  };
                },
              };
            },
            async delete() {
              calls.push(["user", uid]);
              failOnce("user");
              user.exists = false;
            },
          };
        },
      };
    },
    batch() {
      const refs = [];
      return {
        delete(ref) { refs.push(ref); },
        async commit() {
          calls.push(["batch", refs.length]);
          failOnce("batch");
          for (const ref of refs) users.get(ref.uid).bookmarks.delete(ref.id);
        },
      };
    },
  };
  const auth = {
    async deleteUser(uid) {
      calls.push(["auth", uid]);
      failOnce("auth");
    },
  };
  const logger = { error: (...args) => logs.push(args) };
  const handler = _internals.createDeleteAccountHandler({ db, auth, logger, now, enabled: true });
  return { users, calls, failures, logs, handler, db, auth, logger };
}

const request = {
  auth: { uid: "alice", token: { auth_time: NOW_SECONDS } },
  data: { uid: "bob" },
};
const isInternal = (error) => error instanceof HttpsError && error.code === "internal";
const isReauthenticationRequired = (error) => {
  assert.ok(error instanceof HttpsError);
  assert.equal(error.code, "failed-precondition");
  assert.equal(error.message, REAUTH_MESSAGE);
  return true;
};

test("callable requires authentication and never uses a UID from the payload", async () => {
  const services = fakeServices(1);
  for (const invalid of [{}, { auth: null }, { auth: {} }]) {
    await assert.rejects(
      services.handler(invalid),
      (error) => error instanceof HttpsError && error.code === "unauthenticated",
    );
  }
  assert.deepEqual(services.calls, []);
  assert.deepEqual(await services.handler(request), { deleted: true });
  assert.equal(services.users.get("alice").exists, false);
  assert.equal(services.users.get("bob").exists, true);
  assert.equal(services.users.get("bob").bookmarks.size, 1);
  assert.deepEqual(services.calls.at(-1), ["auth", "alice"]);
});

test("missing or invalid authentication times require reauthentication without deletion", async () => {
  const services = fakeServices(1);
  const invalidTokens = [
    undefined, null, {}, { auth_time: null }, { auth_time: "1700000000" },
    { auth_time: NaN }, { auth_time: Infinity }, { auth_time: -Infinity },
    { auth_time: 0 }, { auth_time: -1 }, { auth_time: NOW_SECONDS - 0.5 },
    { auth_time: Number.MAX_SAFE_INTEGER + 1 }, { auth_time: {} },
  ];
  for (const token of invalidTokens) {
    await assert.rejects(services.handler({
      auth: { uid: "alice", token },
      data: { auth_time: NOW_SECONDS },
    }), isReauthenticationRequired);
  }
  assert.deepEqual(services.calls, []);
  assert.deepEqual(services.logs, []);
  assert.equal(services.users.get("alice").exists, true);
  assert.equal(services.users.get("alice").bookmarks.size, 1);
});

test("expired or future authentication requires reauthentication even with a fresh token", async () => {
  const services = fakeServices(1);
  for (const authTime of [NOW_SECONDS - 301, NOW_SECONDS + 1]) {
    await assert.rejects(services.handler({
      auth: { uid: "alice", token: { auth_time: authTime, iat: NOW_SECONDS } },
      data: { auth_time: NOW_SECONDS },
    }), isReauthenticationRequired);
  }
  assert.deepEqual(services.calls, []);
  assert.deepEqual(services.logs, []);
  assert.equal(services.users.get("alice").exists, true);
  assert.equal(services.users.get("alice").bookmarks.size, 1);
});

test("authentication within five minutes, including the boundary, permits deletion", async () => {
  for (const authTime of [NOW_SECONDS, NOW_SECONDS - 299, NOW_SECONDS - 300]) {
    const services = fakeServices(1);
    assert.deepEqual(await services.handler({
      auth: { uid: "alice", token: { auth_time: authTime } },
    }), { deleted: true });
    assert.equal(services.users.get("alice").exists, false);
    assert.deepEqual(services.calls.at(-1), ["auth", "alice"]);
  }
});

test("authentication expires immediately after five minutes", async () => {
  const services = fakeServices(1, () => NOW_MS + 1);
  await assert.rejects(services.handler({
    auth: { uid: "alice", token: { auth_time: NOW_SECONDS - 300 } },
  }), isReauthenticationRequired);
  assert.deepEqual(services.calls, []);
});

test("deletes every bookmark in bounded batches before user document and auth", async () => {
  const services = fakeServices(1205);
  assert.deepEqual(await services.handler(request), { deleted: true });
  assert.equal(services.users.get("alice").bookmarks.size, 0);
  assert.deepEqual(services.calls.filter(([name]) => name === "batch"), [
    ["batch", 400], ["batch", 400], ["batch", 400], ["batch", 5],
  ]);
  assert.equal(services.calls.filter(([name]) => name === "query").length, 5);
  assert.ok(services.calls.filter(([name]) => name === "limit")
    .every(([, , size]) => size === _internals.DELETE_BOOKMARK_BATCH_SIZE));
  assert.deepEqual(services.calls.slice(-2), [["user", "alice"], ["auth", "alice"]]);
});

for (const stage of ["query", "batch", "user", "auth"]) {
  test(`${stage} failure surfaces an onCall error and remains retryable`, async () => {
    const services = fakeServices(3);
    const cause = new Error(`private ${stage} failure`);
    services.failures[stage] = cause;
    // Use an actual onCall-wrapped handler to exercise its callable handler entry point.
    const callable = onCall(services.handler);
    await assert.rejects(callable.run(request), (error) => {
      assert.ok(isInternal(error));
      assert.equal(error.message, "Account deletion failed. Please retry.");
      return true;
    });
    assert.equal(services.logs[0][1], cause);
    if (stage !== "auth") {
      assert.equal(services.calls.some(([name]) => name === "auth"), false);
    }
    assert.deepEqual(await callable.run(request), { deleted: true });
    assert.equal(services.users.get("alice").bookmarks.size, 0);
    assert.equal(services.users.get("alice").exists, false);
  });
}

test("a failed later batch leaves earlier work deleted and retry completes the rest", async () => {
  const services = fakeServices(401);
  const originalBatch = services.db.batch;
  let commits = 0;
  services.db.batch = () => {
    const batch = originalBatch();
    const commit = batch.commit;
    batch.commit = async () => {
      if (++commits === 2) throw new Error("second batch failed");
      await commit();
    };
    return batch;
  };
  await assert.rejects(services.handler(request), isInternal);
  assert.equal(services.users.get("alice").bookmarks.size, 1);
  assert.equal(services.users.get("alice").exists, true);
  assert.equal(services.calls.some(([name]) => name === "auth"), false);
  assert.deepEqual(await services.handler(request), { deleted: true });
  assert.equal(services.users.get("alice").bookmarks.size, 0);
});

test("re-queries from the beginning when a bookmark appears between batches", async () => {
  const services = fakeServices(401);
  const originalBatch = services.db.batch;
  let first = true;
  services.db.batch = () => {
    const batch = originalBatch();
    const commit = batch.commit;
    batch.commit = async () => {
      await commit();
      if (first) {
        first = false;
        services.users.get("alice").bookmarks.set("new-bookmark", {});
      }
    };
    return batch;
  };
  assert.deepEqual(await services.handler(request), { deleted: true });
  assert.equal(services.users.get("alice").bookmarks.size, 0);
  assert.deepEqual(services.calls.filter(([name]) => name === "batch"), [
    ["batch", 400], ["batch", 2],
  ]);
});

test("already deleted auth account is accepted only after Firestore cleanup", async () => {
  const services = fakeServices(1);
  services.failures.auth = Object.assign(new Error("not found"), { code: "auth/user-not-found" });
  assert.deepEqual(await services.handler(request), { deleted: true });
  assert.equal(services.users.get("alice").bookmarks.size, 0);
  assert.deepEqual(services.calls.slice(-2), [["user", "alice"], ["auth", "alice"]]);
});

test("Admin Auth USER_NOT_FOUND is accepted after Firestore cleanup", async (t) => {
  const requests = [];
  const server = http.createServer((req, res) => {
    let body = "";
    req.on("data", (chunk) => { body += chunk; });
    req.on("end", () => {
      requests.push({ url: req.url, body: JSON.parse(body) });
      res.writeHead(400, { "content-type": "application/json" });
      res.end(JSON.stringify({ error: { code: 400, message: "USER_NOT_FOUND" } }));
    });
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  t.after(() => new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve())));

  const previousHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  process.env.FIREBASE_AUTH_EMULATOR_HOST = `127.0.0.1:${server.address().port}`;
  let app;
  let auth;
  try {
    app = initializeApp({ projectId: "demo-admin-auth-test" }, "delete-account-auth-test");
    auth = getAuth(app);
  } finally {
    if (previousHost === undefined) delete process.env.FIREBASE_AUTH_EMULATOR_HOST;
    else process.env.FIREBASE_AUTH_EMULATOR_HOST = previousHost;
  }
  t.after(() => deleteApp(app));

  await assert.rejects(auth.deleteUser("alice"), (error) => error.code === "auth/user-not-found");
  const services = fakeServices(1);
  const handler = _internals.createDeleteAccountHandler({
    db: services.db, auth, logger: services.logger, now: () => NOW_MS, enabled: true,
  });
  assert.deepEqual(await handler(request), { deleted: true });
  assert.equal(services.users.get("alice").bookmarks.size, 0);
  assert.equal(services.users.get("alice").exists, false);
  assert.equal(requests.length, 2);
  assert.ok(requests.every(({ url, body }) =>
    url.endsWith("/accounts:delete") && body.localId === "alice"));
});

test("does not resolve successfully while auth deletion is pending", async () => {
  const services = fakeServices();
  let release;
  const pending = new Promise((resolve) => { release = resolve; });
  services.auth.deleteUser = () => pending;
  let settled = false;
  const deletion = services.handler(request).then((result) => {
    settled = true;
    return result;
  });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(settled, false);
  release();
  assert.deepEqual(await deletion, { deleted: true });
});

test("export is a callable that keeps deletion unavailable", async () => {
  assert.deepEqual(deleteAccount.__endpoint.callableTrigger, {});
  assert.deepEqual(deleteAccount.__endpoint.region, ["us-central1"]);
  await assert.rejects(
    deleteAccount.run({ data: { uid: "alice" } }),
    (error) => error instanceof HttpsError && error.code === "unauthenticated",
  );
  await assert.rejects(
    deleteAccount.run({ auth: { uid: "alice" }, data: { auth_time: NOW_SECONDS } }),
    (error) => error instanceof HttpsError && error.code === "unavailable",
  );
  await assert.rejects(
    deleteAccount.run({ auth: request.auth }),
    (error) => error instanceof HttpsError && error.code === "unavailable",
  );
});

async function invokeHttp(callable) {
  const headers = { "content-type": "application/json" };
  const req = {
    method: "POST",
    headers,
    body: { data: {} },
    header: (name) => headers[name.toLowerCase()],
  };
  const res = new EventEmitter();
  res.setHeader = () => {};
  res.getHeader = () => undefined;
  res.status = (status) => { res.statusCode = status; return res; };
  res.send = (body) => { res.body = body; res.emit("finish"); return res; };
  await callable(req, res);
  return res;
}

test("onCall serializes unauthenticated and operational failures as errors", async () => {
  const unauthenticated = await invokeHttp(deleteAccount);
  assert.equal(unauthenticated.statusCode, 401);
  assert.equal(unauthenticated.body.error.status, "UNAUTHENTICATED");
  assert.equal(unauthenticated.body.result, undefined);

  const services = fakeServices(1);
  services.failures.batch = new Error("private backend details");
  // Inject a verified identity at the handler boundary; token verification is
  // Firebase's responsibility and is not emulated by this test.
  const callable = onCall({ cors: false }, (req) => services.handler({
    ...req, auth: request.auth,
  }));
  const failed = await invokeHttp(callable);
  assert.equal(failed.statusCode, 500);
  assert.deepEqual(failed.body, {
    error: { status: "INTERNAL", message: "Account deletion failed. Please retry." },
  });
  const succeeded = await invokeHttp(callable);
  assert.equal(succeeded.statusCode, 200);
  assert.deepEqual(succeeded.body, { result: { deleted: true } });
});

test("onCall serializes the reauthentication requirement without deleting data", async () => {
  const services = fakeServices(1);
  const callable = onCall({ cors: false }, (req) => services.handler({
    ...req, auth: { uid: "alice", token: { auth_time: NOW_SECONDS - 301 } },
  }));
  const response = await invokeHttp(callable);
  assert.equal(response.statusCode, 400);
  assert.deepEqual(response.body, {
    error: { status: "FAILED_PRECONDITION", message: REAUTH_MESSAGE },
  });
  assert.deepEqual(services.calls, []);
  assert.equal(services.users.get("alice").bookmarks.size, 1);
});
