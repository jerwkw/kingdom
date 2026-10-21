import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom/models/goal_model.dart';
import 'package:kingdom/utils/period_keys.dart';

// Shares fixtures with functions/test/domain.test.js so the Dart and
// JavaScript period keys cannot drift apart.
void main() {
  final fixtures =
      jsonDecode(
            File('functions/test/fixtures/period-keys.json').readAsStringSync(),
          )['cases']
          as List;

  test('Dart period keys match the shared UTC fixtures', () {
    for (final c in fixtures.cast<Map<String, dynamic>>()) {
      final instant = DateTime.parse(c['instant']);
      for (final frequency in GoalFrequency.values) {
        expect(
          periodKey(frequency, instant),
          c[frequency.name],
          reason: '${frequency.name} @ ${c['instant']}',
        );
      }
    }
  });

  test('local times are converted to UTC before keying', () {
    final utcMidnight = DateTime.utc(2026, 9, 9);
    expect(periodKey(GoalFrequency.daily, utcMidnight.toLocal()), '2026-09-09');
    expect(
      periodKey(
        GoalFrequency.daily,
        utcMidnight.subtract(const Duration(seconds: 1)).toLocal(),
      ),
      '2026-09-08',
    );
  });
}
