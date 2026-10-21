import 'package:intl/intl.dart';
import '../models/goal_model.dart';

// Business-day policy: all period keys are UTC, matching getPeriodKey in
// functions/lib/domain.js (daily YYYY-MM-DD, weekly ISO YYYY-Www, monthly
// YYYY-MM). Both are tested against functions/test/fixtures/period-keys.json.
String periodKey(GoalFrequency frequency, DateTime instant) {
  final utc = instant.toUtc();
  final date = DateTime.utc(utc.year, utc.month, utc.day);
  switch (frequency) {
    case GoalFrequency.monthly:
      return DateFormat('yyyy-MM').format(date);
    case GoalFrequency.weekly:
      final thursday = date.add(Duration(days: 4 - date.weekday));
      final yearStart = DateTime.utc(thursday.year, 1, 1);
      final week = ((thursday.difference(yearStart).inDays + 1) / 7).ceil();
      return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
    case GoalFrequency.daily:
      return DateFormat('yyyy-MM-dd').format(date);
  }
}

String todayKeyUtc([DateTime? now]) =>
    periodKey(GoalFrequency.daily, now ?? DateTime.now());
