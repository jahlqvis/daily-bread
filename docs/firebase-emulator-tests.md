# Firebase emulator checks

Run only with project ID `demo-dailybread`. The config binds the emulators to
loopback but **does not enforce a project ID**: Firebase selects the project via
the CLI, and `singleProjectMode` only warns about mismatches. Always use the
explicit `--project demo-dailybread` below. The check independently requires
`GCLOUD_PROJECT=demo-dailybread` and explicit loopback emulator hosts.

Tested with Node 22.22.1, Firebase CLI 15.35.0, Temurin JDK 21.0.13+9,
Firestore emulator 1.22.0, and the existing `functions/node_modules` containing
Firebase Admin 14.5.0. The CLI may download emulator binaries on first run.
Make sure the configured ports are free. No Firebase login or credentials are
needed; do not use this config to deploy.

From the repository root, set `NODE_BIN` to the absolute directory containing
Node 22, `JAVA_HOME` to the JDK home, and `FIREBASE_BIN` to the absolute path
of the Firebase CLI executable. Then run:

```sh
ROOT="$PWD"
RUN="$(mktemp -d "${TMPDIR:-/tmp}/dailybread-emulators.XXXXXXXX")"
mkdir -p "$RUN/home" "$RUN/project/functions"
cp firebase.emulator.json firestore.rules "$RUN/project/"
cp functions/index.js functions/package.json functions/emulator-check.cjs "$RUN/project/functions/"
ln -s "$ROOT/functions/node_modules" "$RUN/project/functions/node_modules"
cd "$RUN/project"

env -i \
  HOME="$RUN/home" XDG_CONFIG_HOME="$RUN/home/config" XDG_CACHE_HOME="$RUN/home/cache" \
  PATH="$NODE_BIN:$JAVA_HOME/bin:/usr/bin:/bin:/usr/sbin:/sbin" JAVA_HOME="$JAVA_HOME" \
  FIREBASE_CLI_DISABLE_USAGE_REPORTING=true CI=true \
  GCLOUD_PROJECT=demo-dailybread \
  FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:19099 \
  FIRESTORE_EMULATOR_HOST=127.0.0.1:18080 \
  FUNCTIONS_EMULATOR_HOST=127.0.0.1:15001 \
  "$FIREBASE_BIN" --config firebase.emulator.json --project demo-dailybread \
  emulators:exec --only auth,firestore,functions 'node functions/emulator-check.cjs'
```

The isolated home avoids existing Firebase credentials and configuration. The
temporary project is a snapshot: repeat the copy after changing source or rules.
The check creates unique emulator users and data without clearing existing data;
`emulators:exec` stops the emulators afterward. It verifies authenticated
user-isolated sync, Firestore rules, and disabled account deletion. It is not
part of the default `npm test`.
