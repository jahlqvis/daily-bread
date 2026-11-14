import 'dart:convert';

import 'package:daily_bread/data/datasources/profile_transition_journal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> preferences([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    return SharedPreferences.getInstance();
  }

  test(
    'explicit account decisions survive restart; later import is separate',
    () async {
      final prefs = await preferences({'user_data': 'ambiguous legacy'});
      var journal = ProfileTransitionJournal(prefs);
      expect(await journal.read(), isNull);
      var state = await journal.begin(
        id: 'one',
        uid: 'alice',
        kind: ProfileTransitionKind.account,
      );
      expect(state.choice, isNull);
      expect(state.status, ProfileTransitionStatus.pending);
      await expectLater(
        journal.commit(id: 'one', uid: 'alice'),
        throwsStateError,
      );
      state = await journal.choose(
        id: 'one',
        uid: 'alice',
        choice: ProfileTransitionChoice.keepSeparate,
      );
      expect(state.choice, ProfileTransitionChoice.keepSeparate);
      SharedPreferences.resetStatic();
      journal = ProfileTransitionJournal(await SharedPreferences.getInstance());
      state = (await journal.read())!;
      expect(state.uid, 'alice');
      expect(state.id, 'one');
      expect(state.status, ProfileTransitionStatus.pending);
      expect(state.choice, ProfileTransitionChoice.keepSeparate);
      await journal.commit(id: 'one', uid: 'alice');
      SharedPreferences.resetStatic();
      journal = ProfileTransitionJournal(await SharedPreferences.getInstance());
      expect((await journal.read())!.status, ProfileTransitionStatus.committed);
      await journal.begin(
        id: 'two',
        uid: 'alice',
        kind: ProfileTransitionKind.account,
      );
      expect((await journal.read())!.choice, isNull);
      await journal.choose(
        id: 'two',
        uid: 'alice',
        choice: ProfileTransitionChoice.importLocal,
      );
      await journal.commit(id: 'two', uid: 'alice');
      expect(prefs.getString('user_data'), 'ambiguous legacy');
      expect(prefs.getKeys(), {
        'user_data',
        ProfileTransitionJournal.storageKey,
      });
    },
  );

  for (final choice in [
    ProfileTransitionChoice.keepCopy,
    ProfileTransitionChoice.removeCopy,
  ]) {
    test('sign-out $choice survives interruption and completion', () async {
      final prefs = await preferences({'user_data': 'untouched'});
      var journal = ProfileTransitionJournal(prefs);
      await journal.begin(
        id: 'out',
        uid: 'alice',
        kind: ProfileTransitionKind.signOut,
      );
      await journal.choose(id: 'out', uid: 'alice', choice: choice);
      SharedPreferences.resetStatic();
      journal = ProfileTransitionJournal(await SharedPreferences.getInstance());
      final recovered = (await journal.read())!;
      expect(recovered.uid, 'alice');
      expect(recovered.kind, ProfileTransitionKind.signOut);
      expect(recovered.status, ProfileTransitionStatus.pending);
      expect(recovered.choice, choice);
      await journal.commit(id: 'out', uid: 'alice');
      expect((await journal.read())!.status, ProfileTransitionStatus.committed);
      expect(prefs.getString('user_data'), 'untouched');
    });
  }

  test(
    'rejects mismatches, invalid choices, changing choices and stale retries',
    () async {
      final journal = ProfileTransitionJournal(await preferences());
      await expectLater(
        journal.begin(
          id: '',
          uid: 'alice',
          kind: ProfileTransitionKind.account,
        ),
        throwsArgumentError,
      );
      await expectLater(
        journal.begin(id: 'a', uid: '', kind: ProfileTransitionKind.account),
        throwsArgumentError,
      );
      await expectLater(
        journal.commit(id: 'a', uid: 'alice'),
        throwsStateError,
      );
      await journal.begin(
        id: 'a',
        uid: 'alice',
        kind: ProfileTransitionKind.account,
      );
      await expectLater(
        journal.begin(id: 'a', uid: 'bob', kind: ProfileTransitionKind.account),
        throwsStateError,
      );
      await expectLater(
        journal.begin(
          id: 'a',
          uid: 'alice',
          kind: ProfileTransitionKind.signOut,
        ),
        throwsStateError,
      );
      await expectLater(
        journal.begin(id: 'b', uid: 'bob', kind: ProfileTransitionKind.account),
        throwsStateError,
      );
      await expectLater(
        journal.choose(
          id: 'a',
          uid: 'bob',
          choice: ProfileTransitionChoice.importLocal,
        ),
        throwsStateError,
      );
      await expectLater(
        journal.choose(
          id: 'a',
          uid: 'alice',
          choice: ProfileTransitionChoice.removeCopy,
        ),
        throwsStateError,
      );
      await journal.choose(
        id: 'a',
        uid: 'alice',
        choice: ProfileTransitionChoice.importLocal,
      );
      await expectLater(
        journal.choose(
          id: 'a',
          uid: 'alice',
          choice: ProfileTransitionChoice.keepSeparate,
        ),
        throwsStateError,
      );
      await expectLater(journal.commit(id: 'a', uid: 'bob'), throwsStateError);
      await journal.commit(id: 'a', uid: 'alice');
      await expectLater(
        journal.choose(
          id: 'a',
          uid: 'alice',
          choice: ProfileTransitionChoice.importLocal,
        ),
        throwsStateError,
      );
      await expectLater(
        journal.begin(
          id: 'a',
          uid: 'alice',
          kind: ProfileTransitionKind.account,
        ),
        throwsStateError,
      );
      await journal.begin(
        id: 'b',
        uid: 'bob',
        kind: ProfileTransitionKind.signOut,
      );
      await expectLater(
        journal.commit(id: 'a', uid: 'alice'),
        throwsStateError,
      );
      await expectLater(
        journal.choose(
          id: 'b',
          uid: 'bob',
          choice: ProfileTransitionChoice.keepSeparate,
        ),
        throwsStateError,
      );
      await journal.choose(
        id: 'b',
        uid: 'bob',
        choice: ProfileTransitionChoice.keepCopy,
      );
      await journal.commit(id: 'b', uid: 'bob');
      await expectLater(
        journal.begin(
          id: 'a',
          uid: 'alice',
          kind: ProfileTransitionKind.account,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'serializes competing instances and permits only safe retries',
    () async {
      final prefs = await preferences();
      final first = ProfileTransitionJournal(prefs);
      final second = ProfileTransitionJournal(prefs);
      await Future.wait([
        first.begin(id: 'a', uid: 'alice', kind: ProfileTransitionKind.account),
        second.begin(
          id: 'a',
          uid: 'alice',
          kind: ProfileTransitionKind.account,
        ),
      ]);
      await Future.wait([
        first.choose(
          id: 'a',
          uid: 'alice',
          choice: ProfileTransitionChoice.importLocal,
        ),
        second.choose(
          id: 'a',
          uid: 'alice',
          choice: ProfileTransitionChoice.importLocal,
        ),
      ]);
      await Future.wait([
        first.commit(id: 'a', uid: 'alice'),
        second.commit(id: 'a', uid: 'alice'),
      ]);
      expect((await first.read())!.status, ProfileTransitionStatus.committed);
    },
  );

  test(
    'conflicting concurrent decisions cannot replace the first choice',
    () async {
      final prefs = await preferences();
      final first = ProfileTransitionJournal(prefs);
      final second = ProfileTransitionJournal(prefs);
      await first.begin(
        id: 'a',
        uid: 'alice',
        kind: ProfileTransitionKind.account,
      );
      final chosen = first.choose(
        id: 'a',
        uid: 'alice',
        choice: ProfileTransitionChoice.keepSeparate,
      );
      final conflicting = second.choose(
        id: 'a',
        uid: 'alice',
        choice: ProfileTransitionChoice.importLocal,
      );
      await expectLater(conflicting, throwsStateError);
      await chosen;
      expect(
        (await second.read())!.choice,
        ProfileTransitionChoice.keepSeparate,
      );
    },
  );

  test('corrupt and unknown data is never overwritten', () async {
    final valid = <String, Object?>{
      'version': 1,
      'id': 'a',
      'uid': 'alice',
      'kind': 'account',
      'status': 'pending',
      'choice': null,
    };
    final invalid = <Object>[
      3,
      '{',
      'null',
      '{}',
      jsonEncode({...valid, 'version': 2}),
      jsonEncode({...valid, 'version': 1.0}),
      jsonEncode({...valid, 'extra': true}),
      jsonEncode({...valid, 'id': ''}),
      jsonEncode({...valid, 'uid': ''}),
      jsonEncode({...valid, 'kind': 'other'}),
      jsonEncode({...valid, 'status': 'other'}),
      jsonEncode({...valid, 'choice': 'other'}),
      jsonEncode({...valid, 'choice': 'keepCopy'}),
      jsonEncode({...valid, 'status': 'committed'}),
      '{"version":1,"id":"a","id":"b","uid":"alice","kind":"account","status":"pending","choice":null}',
    ];
    for (final raw in invalid) {
      final prefs = await preferences({
        ProfileTransitionJournal.storageKey: raw,
      });
      final journal = ProfileTransitionJournal(prefs);
      await expectLater(journal.read(), throwsFormatException, reason: '$raw');
      await expectLater(
        journal.begin(
          id: 'new',
          uid: 'bob',
          kind: ProfileTransitionKind.account,
        ),
        throwsFormatException,
        reason: '$raw',
      );
      await expectLater(
        journal.choose(
          id: 'a',
          uid: 'alice',
          choice: ProfileTransitionChoice.importLocal,
        ),
        throwsFormatException,
      );
      await expectLater(
        journal.commit(id: 'a', uid: 'alice'),
        throwsFormatException,
      );
      expect(prefs.get(ProfileTransitionJournal.storageKey), raw);
    }
  });
}
