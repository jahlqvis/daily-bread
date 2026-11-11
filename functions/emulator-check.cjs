// Run explicitly, outside the default unit tests, against locally running Auth,
// Firestore (with firestore.rules loaded), and Functions emulators:
// GCLOUD_PROJECT=demo-dailybread FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:19099 \
// FIRESTORE_EMULATOR_HOST=127.0.0.1:18080 FUNCTIONS_EMULATOR_HOST=127.0.0.1:15001 \
// node functions/emulator-check.cjs
// This creates unique emulator users and data and does not clear emulator state.
const assert = require("node:assert/strict");

const project = "demo-dailybread";
assert.equal(process.env.GCLOUD_PROJECT, project, "GCLOUD_PROJECT must be demo-dailybread");
for (const name of ["GOOGLE_CLOUD_PROJECT", "FIREBASE_PROJECT_ID"]) {
  assert.ok(!process.env[name] || process.env[name] === project, `${name} must match demo project`);
}
function emulatorHost(name) {
  const value = process.env[name];
  assert.match(value || "", /^127\.0\.0\.1:[0-9]{1,5}$/, `${name} must be an explicit 127.0.0.1:port`);
  const port = Number(value.split(":")[1]);
  assert.ok(port > 0 && port <= 65535, `${name} port is invalid`);
  return `http://${value}`;
}
const auth = emulatorHost("FIREBASE_AUTH_EMULATOR_HOST");
const firestore = emulatorHost("FIRESTORE_EMULATOR_HOST");
const functions = emulatorHost("FUNCTIONS_EMULATOR_HOST");
const documents = `${firestore}/v1/projects/${project}/databases/(default)/documents`;

async function request(url, { method = "GET", token, body } = {}) {
  const response = await fetch(url, {
    method,
    redirect: "error",
    headers: {
      ...(body !== undefined ? { "content-type": "application/json" } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
    signal: AbortSignal.timeout(30000),
  });
  const text = await response.text();
  return { status: response.status, data: text ? JSON.parse(text) : {} };
}

async function signUp() {
  const result = await request(`${auth}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-only`, {
    method: "POST", body: { returnSecureToken: true },
  });
  assert.equal(result.status, 200, JSON.stringify(result.data));
  assert.ok(result.data.localId && result.data.idToken);
  return { uid: result.data.localId, token: result.data.idToken };
}

async function callable(name, token, data) {
  return request(`${functions}/${project}/us-central1/${name}`, {
    method: "POST", token, body: { data },
  });
}

async function doc(path, options = {}) {
  return request(`${documents}/${path.split("/").map(encodeURIComponent).join("/")}`, options);
}

function expectStatus(result, status) {
  assert.equal(result.status, status, JSON.stringify(result.data));
}

async function main() {
  const [alice, bob] = await Promise.all([signUp(), signUp()]);
  assert.notEqual(alice.uid, bob.uid);
  const bookmark = {
    translationId: "web", book: "John", chapter: 3, verse: 16, note: "alice",
    createdAt: "2026-04-22T10:00:00.000Z", updatedAt: "2026-04-22T10:00:00.000Z",
  };
  const snapshot = { user: { totalXp: 37 }, bookmarks: [bookmark], tombstones: {} };
  const path = `users/${alice.uid}`;
  const bookmarkPath = `${path}/bookmarks/web|John|3|16`;

  const unauthenticated = await callable("syncUserState", null, { snapshot });
  expectStatus(unauthenticated, 401);
  assert.equal(unauthenticated.data.error.status, "UNAUTHENTICATED");
  const synced = await callable("syncUserState", alice.token, { uid: bob.uid, snapshot });
  expectStatus(synced, 200);
  assert.equal(synced.data.result.user.totalXp, 37);
  assert.equal(synced.data.result.bookmarks[0].note, "alice");
  const bobSync = await callable("syncUserState", bob.token, { snapshot: { user: { totalXp: 5 } } });
  expectStatus(bobSync, 200);
  assert.equal(bobSync.data.result.user.totalXp, 5);
  assert.deepEqual(bobSync.data.result.bookmarks, []);
  const aliceAgain = await callable("syncUserState", alice.token, { snapshot: {} });
  expectStatus(aliceAgain, 200);
  assert.equal(aliceAgain.data.result.user.totalXp, 37);
  assert.equal(aliceAgain.data.result.bookmarks[0].note, "alice");

  // REST requests carry real Auth emulator ID tokens, so these exercise rules.
  const ownerUser = await doc(path, { token: alice.token });
  const ownerBookmark = await doc(bookmarkPath, { token: alice.token });
  expectStatus(ownerUser, 200);
  expectStatus(ownerBookmark, 200);
  expectStatus(await doc(path), 403);
  expectStatus(await doc(path, { token: bob.token }), 403);
  expectStatus(await doc(bookmarkPath, { token: bob.token }), 403);
  expectStatus(await doc(path, { method: "PATCH", token: bob.token, body: ownerUser.data }), 403);
  expectStatus(await doc(bookmarkPath, { method: "PATCH", token: bob.token, body: { fields: ownerBookmark.data.fields } }), 403);
  expectStatus(await doc(path, { method: "PATCH", token: alice.token, body: { fields: { invalid: { booleanValue: true } } } }), 403);
  expectStatus(await doc(bookmarkPath, { method: "PATCH", token: alice.token, body: { fields: { invalid: { booleanValue: true } } } }), 403);
  expectStatus(await doc(path, { method: "PATCH", token: alice.token, body: { fields: ownerUser.data.fields } }), 200);
  expectStatus(await doc(bookmarkPath, { method: "PATCH", token: alice.token, body: { fields: ownerBookmark.data.fields } }), 200);
  expectStatus(await doc(path, { method: "DELETE", token: alice.token }), 403);
  expectStatus(await doc(bookmarkPath, { method: "DELETE", token: alice.token }), 403);

  const unauthenticatedDeletion = await callable("deleteAccount", null, {});
  expectStatus(unauthenticatedDeletion, 401);
  assert.equal(unauthenticatedDeletion.data.error.status, "UNAUTHENTICATED");
  const deletion = await callable("deleteAccount", alice.token, {});
  expectStatus(deletion, 503);
  assert.equal(deletion.data.error.status, "UNAVAILABLE");
  const userAfter = await doc(path, { token: alice.token });
  const bookmarkAfter = await doc(bookmarkPath, { token: alice.token });
  expectStatus(userAfter, 200);
  expectStatus(bookmarkAfter, 200);
  assert.deepEqual(userAfter.data.fields, ownerUser.data.fields);
  assert.deepEqual(bookmarkAfter.data.fields, ownerBookmark.data.fields);
  const account = await request(`${auth}/identitytoolkit.googleapis.com/v1/accounts:lookup?key=emulator-only`, {
    method: "POST", body: { idToken: alice.token },
  });
  expectStatus(account, 200);
  assert.equal(account.data.users[0].localId, alice.uid);
  console.log("PASS: authenticated isolated sync, emulated Firestore rules, and disabled deletion preserve account and data");
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
