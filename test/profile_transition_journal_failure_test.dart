import 'package:daily_bread/data/datasources/profile_transition_journal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'write failures reload disk before retry, including ambiguous success',
    () async {
      const channel = MethodChannel('plugins.flutter.io/shared_preferences');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      for (final stage in [1, 2, 3]) {
        for (final writeReachedDisk in [false, true]) {
          final disk = <String, Object>{};
          var writes = 0;
          messenger.setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getAll') return Map<String, Object>.from(disk);
            if (call.method == 'setString') {
              writes++;
              final args = call.arguments as Map<Object?, Object?>;
              if (writes != stage || writeReachedDisk) {
                disk[args['key'] as String] = args['value'] as Object;
              }
              if (writes == stage) return false;
              return true;
            }
            throw StateError('Unexpected call ${call.method}');
          });
          SharedPreferences.resetStatic();
          final journal = ProfileTransitionJournal(
            await SharedPreferences.getInstance(),
          );
          Future<void> begin() async => journal.begin(
            id: 'a',
            uid: 'alice',
            kind: ProfileTransitionKind.account,
          );
          Future<void> choose() async => journal.choose(
            id: 'a',
            uid: 'alice',
            choice: ProfileTransitionChoice.importLocal,
          );
          Future<void> commit() async => journal.commit(id: 'a', uid: 'alice');
          final steps = [begin, choose, commit];
          for (var i = 0; i < steps.length; i++) {
            if (i + 1 == stage) {
              await expectLater(steps[i](), throwsStateError);
              SharedPreferences.resetStatic();
              final recovered = ProfileTransitionJournal(
                await SharedPreferences.getInstance(),
              );
              final state = await recovered.read();
              if (stage == 1 && !writeReachedDisk) {
                expect(state, isNull);
              } else {
                expect(state, isNotNull);
                expect(
                  state!.status,
                  stage == 3 && writeReachedDisk
                      ? ProfileTransitionStatus.committed
                      : ProfileTransitionStatus.pending,
                );
                expect(
                  state.choice,
                  stage == 1 || (stage == 2 && !writeReachedDisk)
                      ? isNull
                      : ProfileTransitionChoice.importLocal,
                );
              }
            }
            await steps[i]();
          }
          expect(
            (await journal.read())!.status,
            ProfileTransitionStatus.committed,
          );
          expect(disk.keys, ['flutter.${ProfileTransitionJournal.storageKey}']);
        }
      }
    },
  );

  test(
    'failed reload blocks cached reads and writes until it succeeds',
    () async {
      const channel = MethodChannel('plugins.flutter.io/shared_preferences');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final disk = <String, Object>{};
      var failWrite = true;
      var failReload = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getAll') {
          if (failReload) throw PlatformException(code: 'reload');
          return Map<String, Object>.from(disk);
        }
        if (call.method == 'setString') {
          if (failWrite) {
            failWrite = false;
            failReload = true;
            throw PlatformException(code: 'write');
          }
          final args = call.arguments as Map<Object?, Object?>;
          disk[args['key'] as String] = args['value'] as Object;
          return true;
        }
        throw StateError('Unexpected call ${call.method}');
      });
      SharedPreferences.resetStatic();
      final journal = ProfileTransitionJournal(
        await SharedPreferences.getInstance(),
      );
      await expectLater(
        journal.begin(
          id: 'a',
          uid: 'alice',
          kind: ProfileTransitionKind.account,
        ),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(journal.read(), throwsA(isA<PlatformException>()));
      await expectLater(
        journal.begin(id: 'b', uid: 'bob', kind: ProfileTransitionKind.account),
        throwsA(isA<PlatformException>()),
      );
      expect(disk, isEmpty);
      failReload = false;
      expect(await journal.read(), isNull);
      await journal.begin(
        id: 'a',
        uid: 'alice',
        kind: ProfileTransitionKind.account,
      );
      expect((await journal.read())!.uid, 'alice');
    },
  );
}
