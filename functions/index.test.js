const test = require("node:test");
const assert = require("node:assert/strict");

const { HttpsError } = require("firebase-functions/v2/https");
const { _internals } = require("./index");

test("mergeSnapshots keeps newer tombstone over stale edit", () => {
  const bookmarkId = "web|John|3|16";
  const local = {
    user: {},
    bookmarks: [
      {
        id: bookmarkId,
        translationId: "web",
        book: "John",
        chapter: 3,
        verse: 16,
        note: "stale",
        createdAt: new Date("2026-04-22T10:00:00.000Z"),
        updatedAt: new Date("2026-04-22T10:30:00.000Z"),
      },
    ],
    tombstones: {},
  };
  const remote = {
    user: {},
    bookmarks: [],
    tombstones: {
      [bookmarkId]: new Date("2026-04-22T11:00:00.000Z"),
    },
  };

  const merged = _internals.mergeSnapshots(local, remote);
  assert.equal(merged.bookmarks.length, 0);
  assert.equal(
    merged.tombstones[bookmarkId].toISOString(),
    "2026-04-22T11:00:00.000Z",
  );
});

test("validateSnapshot rejects oversized note", () => {
  const oversizedNote = "a".repeat(_internals.MAX_NOTE_LENGTH + 1);
  const snapshot = {
    user: {},
    bookmarks: [
      {
        id: "web|John|3|16",
        translationId: "web",
        book: "John",
        chapter: 3,
        verse: 16,
        note: oversizedNote,
        createdAt: new Date("2026-04-22T10:00:00.000Z"),
        updatedAt: new Date("2026-04-22T10:00:00.000Z"),
      },
    ],
    tombstones: {},
  };

  assert.throws(
    () => _internals.validateSnapshot(snapshot),
    (error) => error instanceof HttpsError && error.code === "invalid-argument",
  );
});

test("validateSnapshot rejects unsupported user keys", () => {
  const snapshot = {
    user: { totalXp: 10, forbidden: true },
    bookmarks: [],
    tombstones: {},
  };

  assert.throws(
    () => _internals.validateSnapshot(snapshot),
    (error) => error instanceof HttpsError && error.code === "invalid-argument",
  );
});
