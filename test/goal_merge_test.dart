import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom/providers/goals_provider.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8, 12);
  GoalDoc goal(String id, String frequency, {bool archived = false}) => (
    id: id,
    data: {
      'userId': 'u',
      'type': 'templated',
      'task': id,
      'frequency': frequency,
      'currentStreak': 0,
      'archived': archived,
    },
  );

  test('matches completions by refType, refId and current period key', () {
    final goals = mergeGoalsWithCompletions(
      [
        goal('daily', 'daily'),
        goal('weekly', 'weekly'),
        goal('monthly', 'monthly'),
      ],
      [
        {'refType': 'goal', 'refId': 'daily', 'periodKey': '2026-09-08'},
        {'refType': 'goal', 'refId': 'weekly', 'periodKey': '2026-W36'},
        {
          'refType': 'dailyChallenge',
          'refId': 'monthly',
          'periodKey': '2026-09',
        },
      ],
      now,
    );
    expect(goals.map((g) => g.isCompletedToday), [true, false, false]);
  });

  test('legacy completions without periodKey fall back to date', () {
    final goals = mergeGoalsWithCompletions(
      [goal('daily', 'daily')],
      [
        {'refType': 'goal', 'refId': 'daily', 'date': '2026-09-08'},
      ],
      now,
    );
    expect(goals.single.isCompletedToday, isTrue);
  });

  test(
    'server-confirmed completions check the box before the stream arrives',
    () {
      final goals = mergeGoalsWithCompletions(
        [goal('weekly', 'weekly'), goal('other', 'daily')],
        const [],
        now,
        confirmedPeriods: {'weekly': '2026-W37', 'other': '2026-09-07'},
      );
      expect(goals.map((g) => g.isCompletedToday), [true, false]);
    },
  );

  test('keeps archived state', () {
    final goals = mergeGoalsWithCompletions(
      [goal('a', 'daily', archived: true)],
      const [],
      now,
    );
    expect(goals.single.archived, isTrue);
  });

  test('completion status reports pending and failed requests', () {
    const status = GoalCompletionStatus(
      requests: {
        'a': (phase: GoalRequestPhase.pending, error: null),
        'b': (phase: GoalRequestPhase.failed, error: 'Nope'),
      },
    );
    expect(status.isPending('a'), isTrue);
    expect(status.errorFor('a'), isNull);
    expect(status.isPending('b'), isFalse);
    expect(status.errorFor('b'), 'Nope');
    expect(status.isPending('c'), isFalse);
  });
}
