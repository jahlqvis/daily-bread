import 'package:daily_bread/data/models/user_model.dart';
import 'package:daily_bread/data/repositories/user_repository.dart';
import 'package:daily_bread/presentation/providers/user_provider.dart';
import 'package:daily_bread/presentation/screens/badges_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _UserRepository implements UserRepository {
  UserModel user = UserModel(badges: ['streak_7']);

  @override
  Future<UserModel> getUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _badges = <(String, String)>[
  ('Week Warrior', 'Maintain a 7-day streak'),
  ('Month Master', 'Maintain a 30-day streak'),
  ('Century Reader', 'Maintain a 100-day streak'),
  ('Rising Star', 'Reach level 5'),
  ('Scripture Scholar', 'Reach level 10'),
  ('First Steps', 'Read your first chapter'),
  ('Bookworm', 'Complete an entire book of the Bible'),
  ('XP Hunter', 'Earn 1000 XP'),
  ('Ice Breaker', 'Use a streak freeze to save your streak'),
];

Future<void> _pumpScreen(
  WidgetTester tester,
  UserProvider provider, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const BadgesScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('shows and announces earned and locked badge details', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = _UserRepository();
    final provider = UserProvider(repository);
    addTearDown(provider.dispose);
    await provider.loadUser();
    await _pumpScreen(tester, provider);

    expect(find.text('Week Warrior'), findsOneWidget);
    expect(find.text('Maintain a 7-day streak'), findsOneWidget);
    expect(find.text('Earned'), findsOneWidget);
    expect(find.text('Month Master'), findsOneWidget);
    expect(find.text('Maintain a 30-day streak'), findsOneWidget);
    expect(find.text('Locked'), findsWidgets);
    expect(
      find.bySemanticsLabel('Week Warrior, Maintain a 7-day streak, Earned'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Month Master, Maintain a 30-day streak, Locked'),
      findsOneWidget,
    );

    repository.user = UserModel(badges: ['streak_30']);
    await provider.loadUser();
    await tester.pump();
    expect(
      find.bySemanticsLabel('Week Warrior, Maintain a 7-day streak, Locked'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Month Master, Maintain a 30-day streak, Earned'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  for (final scale in [1.0, 2.0, 3.2]) {
    testWidgets('all badge details fit and are reachable at ${scale}x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = UserProvider(_UserRepository());
      addTearDown(provider.dispose);
      await provider.loadUser();
      await _pumpScreen(tester, provider, scale: scale);

      for (final (name, description) in _badges) {
        final status = name == 'Week Warrior' ? 'Earned' : 'Locked';
        final card = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == '$name, $description, $status',
          skipOffstage: false,
        );
        expect(card, findsOneWidget);
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        for (final text in [name, description, status]) {
          final textFinder = find.descendant(
            of: card,
            matching: find.text(text, skipOffstage: false),
            skipOffstage: false,
          );
          expect(textFinder, findsOneWidget);
          await tester.ensureVisible(textFinder);
          await tester.pumpAndSettle();
          final cardRect = tester.getRect(card);
          final textRect = tester.getRect(textFinder);
          expect(cardRect.contains(textRect.topLeft), isTrue);
          expect(
            cardRect.contains(textRect.bottomRight - const Offset(0.01, 0.01)),
            isTrue,
          );
          final viewport = tester.getRect(find.byType(ListView));
          expect(viewport.contains(textRect.topLeft), isTrue);
          expect(
            viewport.contains(textRect.bottomRight - const Offset(0.01, 0.01)),
            isTrue,
          );
        }
        expect(tester.takeException(), isNull);
      }
    });
  }
}
