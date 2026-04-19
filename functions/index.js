const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

admin.initializeApp();

const db = admin.firestore();

exports.syncUserState = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const uid = request.auth.uid;
  const payload = toObject(request.data);
  const incoming = parseSnapshot(payload.snapshot);

  const remote = await loadRemoteSnapshot(uid);
  const merged = mergeSnapshots(incoming, remote);
  const serverNow = admin.firestore.Timestamp.now();

  await saveRemoteSnapshot(uid, merged, serverNow);

  return {
    syncedAt: serverNow.toDate().toISOString(),
    user: merged.user,
    bookmarks: merged.bookmarks,
    tombstones: timestampMapToIsoMap(merged.tombstones),
  };
});

function parseSnapshot(rawSnapshot) {
  const snapshot = toObject(rawSnapshot);
  const user = toObject(snapshot.user);
  const bookmarks = Array.isArray(snapshot.bookmarks)
    ? snapshot.bookmarks
        .map((bookmark) => parseBookmark(bookmark))
        .filter((bookmark) => bookmark !== null)
    : [];

  const tombstones = parseIsoMap(snapshot.tombstones);

  return {
    user,
    bookmarks,
    tombstones,
  };
}

function parseBookmark(rawBookmark) {
  const bookmark = toObject(rawBookmark);
  if (!bookmark.book || !bookmark.translationId) {
    return null;
  }

  const chapter = toNumber(bookmark.chapter);
  const verse = toNumber(bookmark.verse);
  if (chapter <= 0 || verse <= 0) {
    return null;
  }

  const createdAt = parseDate(bookmark.createdAt);
  const updatedAt = parseDate(bookmark.updatedAt) || createdAt;
  if (!createdAt || !updatedAt) {
    return null;
  }

  return {
    translationId: String(bookmark.translationId),
    book: String(bookmark.book),
    chapter,
    verse,
    note: typeof bookmark.note === "string" ? bookmark.note : null,
    createdAt,
    updatedAt,
    id: buildBookmarkId(
      String(bookmark.translationId),
      String(bookmark.book),
      chapter,
      verse,
    ),
  };
}

async function loadRemoteSnapshot(uid) {
  const userDoc = await db.collection("users").doc(uid).get();
  const userData = toObject(userDoc.data());
  const user = toObject(userData.user);

  const bookmarksSnapshot = await db
    .collection("users")
    .doc(uid)
    .collection("bookmarks")
    .get();

  const bookmarks = [];
  const tombstones = {};

  for (const doc of bookmarksSnapshot.docs) {
    const data = toObject(doc.data());
    const deletedAt = toDate(data.deletedAt);
    const updatedAt = toDate(data.updatedAt);

    if (deletedAt) {
      tombstones[doc.id] = deletedAt;
      continue;
    }

    const createdAt = parseDate(data.createdAt);
    if (!createdAt || !updatedAt) {
      continue;
    }

    bookmarks.push({
      translationId: String(data.translationId || ""),
      book: String(data.book || ""),
      chapter: toNumber(data.chapter),
      verse: toNumber(data.verse),
      note: typeof data.note === "string" ? data.note : null,
      createdAt,
      updatedAt,
      id: doc.id,
    });
  }

  return {
    user,
    bookmarks,
    tombstones,
  };
}

function mergeSnapshots(local, remote) {
  return {
    user: mergeUsers(local.user, remote.user),
    ...mergeBookmarks(local.bookmarks, remote.bookmarks, local.tombstones, remote.tombstones),
  };
}

function mergeUsers(localUser, remoteUser) {
  const local = toObject(localUser);
  const remote = toObject(remoteUser);
  const localLastRead = parseDate(local.lastReadDate);
  const remoteLastRead = parseDate(remote.lastReadDate);
  const remoteIsNewer = isRemoteNewer(localLastRead, remoteLastRead);

  const mergedProgress = {};
  mergeProgress(mergedProgress, local.readingProgress);
  mergeProgress(mergedProgress, remote.readingProgress);

  const mergedBadges = [
    ...new Set([...(toStringList(local.badges)), ...(toStringList(remote.badges))]),
  ].sort();

  return {
    currentStreak: remoteIsNewer
      ? toNumber(remote.currentStreak)
      : toNumber(local.currentStreak),
    longestStreak: Math.max(
      toNumber(local.longestStreak),
      toNumber(remote.longestStreak),
    ),
    totalXp: Math.max(toNumber(local.totalXp), toNumber(remote.totalXp)),
    level: Math.max(toNumber(local.level), toNumber(remote.level)),
    badges: mergedBadges,
    lastReadDate: dateToIso(maxDate(localLastRead, remoteLastRead)),
    readingProgress: mergedProgress,
    streakFreezes: remoteIsNewer
      ? toNumber(remote.streakFreezes)
      : toNumber(local.streakFreezes),
  };
}

function mergeBookmarks(localBookmarks, remoteBookmarks, localTombstones, remoteTombstones) {
  const localById = Object.fromEntries(localBookmarks.map((bookmark) => [bookmark.id, bookmark]));
  const remoteById = Object.fromEntries(remoteBookmarks.map((bookmark) => [bookmark.id, bookmark]));

  const allIds = new Set([
    ...Object.keys(localById),
    ...Object.keys(remoteById),
    ...Object.keys(localTombstones),
    ...Object.keys(remoteTombstones),
  ]);

  const mergedBookmarks = [];
  const mergedTombstones = {};

  for (const id of allIds) {
    const winner = pickBookmarkWinner(
      localById[id],
      remoteById[id],
      localTombstones[id],
      remoteTombstones[id],
    );

    if (winner.bookmark) {
      mergedBookmarks.push(winner.bookmark);
      continue;
    }
    if (winner.deletedAt) {
      mergedTombstones[id] = winner.deletedAt;
    }
  }

  mergedBookmarks.sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
  return {
    bookmarks: mergedBookmarks,
    tombstones: mergedTombstones,
  };
}

function pickBookmarkWinner(localBookmark, remoteBookmark, localDeletedAt, remoteDeletedAt) {
  const localEvent = resolveBookmarkEvent(localBookmark, localDeletedAt);
  const remoteEvent = resolveBookmarkEvent(remoteBookmark, remoteDeletedAt);

  if (localEvent.timestamp > remoteEvent.timestamp) {
    return localEvent;
  }
  if (remoteEvent.timestamp > localEvent.timestamp) {
    return remoteEvent;
  }
  if (localEvent.deletedAt || remoteEvent.deletedAt) {
    return localEvent.deletedAt ? localEvent : remoteEvent;
  }
  return localEvent;
}

function resolveBookmarkEvent(bookmark, deletedAt) {
  if (!bookmark && !deletedAt) {
    return {
      bookmark: null,
      deletedAt: new Date(0),
      timestamp: 0,
    };
  }

  if (!bookmark && deletedAt) {
    return {
      bookmark: null,
      deletedAt,
      timestamp: deletedAt.getTime(),
    };
  }

  if (!deletedAt) {
    return {
      bookmark,
      deletedAt: null,
      timestamp: bookmark.updatedAt.getTime(),
    };
  }

  if (deletedAt.getTime() >= bookmark.updatedAt.getTime()) {
    return {
      bookmark: null,
      deletedAt,
      timestamp: deletedAt.getTime(),
    };
  }

  return {
    bookmark,
    deletedAt: null,
    timestamp: bookmark.updatedAt.getTime(),
  };
}

async function saveRemoteSnapshot(uid, snapshot, serverNow) {
  const userRef = db.collection("users").doc(uid);
  const batch = db.batch();
  batch.set(
    userRef,
    {
      user: snapshot.user,
      lastClientSyncAt: serverNow,
      updatedAt: serverNow,
    },
    { merge: true },
  );

  for (const bookmark of snapshot.bookmarks) {
    const bookmarkRef = userRef.collection("bookmarks").doc(bookmark.id);
    batch.set(
      bookmarkRef,
      {
        translationId: bookmark.translationId,
        book: bookmark.book,
        chapter: bookmark.chapter,
        verse: bookmark.verse,
        note: bookmark.note,
        createdAt: dateToIso(bookmark.createdAt),
        updatedAt: admin.firestore.Timestamp.fromDate(bookmark.updatedAt),
        deletedAt: null,
      },
      { merge: true },
    );
  }

  for (const [id, deletedAt] of Object.entries(snapshot.tombstones)) {
    const bookmarkRef = userRef.collection("bookmarks").doc(id);
    const decomposed = decomposeBookmarkId(id);
    batch.set(
      bookmarkRef,
      {
        ...(decomposed || {}),
        updatedAt: admin.firestore.Timestamp.fromDate(deletedAt),
        deletedAt: admin.firestore.Timestamp.fromDate(deletedAt),
      },
      { merge: true },
    );
  }

  await batch.commit();
}

function decomposeBookmarkId(id) {
  const parts = String(id).split("|");
  if (parts.length !== 4) {
    return null;
  }

  return {
    translationId: parts[0],
    book: parts[1],
    chapter: toNumber(parts[2]),
    verse: toNumber(parts[3]),
    createdAt: new Date(0).toISOString(),
  };
}

function mergeProgress(target, rawProgress) {
  const progress = toObject(rawProgress);
  Object.entries(progress).forEach(([book, chapters]) => {
    const normalized = new Set([...(target[book] || []), ...toNumberList(chapters)]);
    target[book] = [...normalized].sort((a, b) => a - b);
  });
}

function parseIsoMap(rawMap) {
  const map = toObject(rawMap);
  const parsed = {};
  Object.entries(map).forEach(([key, value]) => {
    const date = parseDate(value);
    if (date) {
      parsed[key] = date;
    }
  });
  return parsed;
}

function timestampMapToIsoMap(map) {
  const output = {};
  Object.entries(map).forEach(([key, value]) => {
    output[key] = dateToIso(value);
  });
  return output;
}

function toObject(value) {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value;
  }
  return {};
}

function toNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  const parsed = Number.parseInt(String(value), 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

function toNumberList(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map((item) => toNumber(item)).filter((item) => item > 0);
}

function toStringList(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .filter((item) => typeof item === "string")
    .map((item) => String(item));
}

function toDate(value) {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value;
  }
  return null;
}

function parseDate(value) {
  const fromTimestamp = toDate(value);
  if (fromTimestamp) {
    return fromTimestamp;
  }

  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }

  return null;
}

function dateToIso(value) {
  if (!(value instanceof Date)) {
    return null;
  }
  return value.toISOString();
}

function maxDate(a, b) {
  if (!a) {
    return b;
  }
  if (!b) {
    return a;
  }
  return a.getTime() >= b.getTime() ? a : b;
}

function isRemoteNewer(local, remote) {
  if (!remote) {
    return false;
  }
  if (!local) {
    return true;
  }
  return remote.getTime() > local.getTime();
}

function buildBookmarkId(translationId, book, chapter, verse) {
  return `${translationId}|${book}|${chapter}|${verse}`;
}
