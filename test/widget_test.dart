import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kingdom/models/goal_model.dart';
import 'package:kingdom/widgets/goal_card.dart';

GoalModel _goal({bool completed = false, bool archived = false}) => GoalModel(
  id: 'goal',
  userId: 'user',
  type: GoalType.templated,
  task: 'Read Bible',
  text: '',
  frequency: GoalFrequency.daily,
  currentStreak: 0,
  sharedToBulletin: false,
  archived: archived,
  isCompletedToday: completed,
);

Future<int> _pump(
  WidgetTester tester,
  GoalModel goal, {
  bool isPending = false,
  String? errorText,
}) async {
  var taps = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GoalCard(
          goal: goal,
          isPending: isPending,
          errorText: errorText,
          onComplete: () => taps++,
        ),
      ),
    ),
  );
  if (find.byType(Checkbox).evaluate().isNotEmpty) {
    await tester.tap(find.byType(Checkbox));
  }
  return taps;
}

void main() {
  testWidgets('goal card renders without Firebase', (tester) async {
    await _pump(tester, _goal());
    expect(find.text('Read Bible'), findsOneWidget);
    expect(find.text('🐟 +10'), findsOneWidget);
  });

  testWidgets('unchecked goal completes on tap', (tester) async {
    final taps = await _pump(tester, _goal());
    expect(taps, 1);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });

  testWidgets('pending goal shows progress and ignores taps', (tester) async {
    final taps = await _pump(tester, _goal(), isPending: true);
    expect(taps, 0);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('failed goal shows an actionable error and can retry', (
    tester,
  ) async {
    final taps = await _pump(
      tester,
      _goal(),
      errorText: 'Could not reach the server.',
    );
    expect(find.textContaining('Tap the box to try again'), findsOneWidget);
    expect(taps, 1);
  });

  testWidgets('completed goal is checked, struck through and disabled', (
    tester,
  ) async {
    final taps = await _pump(tester, _goal(completed: true));
    expect(taps, 0);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
    expect(checkbox.onChanged, isNull);
    final text = tester.widget<Text>(find.text('Read Bible'));
    expect(text.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('archived goal cannot be completed', (tester) async {
    final taps = await _pump(tester, _goal(archived: true));
    expect(taps, 0);
    expect(find.text('ARCHIVED'), findsOneWidget);
  });
}
