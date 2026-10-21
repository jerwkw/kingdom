import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalType { smart, templated }

enum GoalFrequency { daily, weekly, monthly }

class GoalModel {
  final String id;
  final String userId;
  final GoalType type;
  final String task;
  final String text; // For SMART goals
  final GoalFrequency frequency;
  final int currentStreak;
  final bool sharedToBulletin;
  final bool archived;
  final DateTime? createdAt;
  final bool isCompletedToday; // Derived: completed in the current period

  GoalModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.task,
    required this.text,
    required this.frequency,
    required this.currentStreak,
    required this.sharedToBulletin,
    this.archived = false,
    this.createdAt,
    this.isCompletedToday = false,
  });

  factory GoalModel.fromMap(
    String id,
    Map<String, dynamic> map, {
    bool isCompletedToday = false,
  }) {
    DateTime? parsedCreatedAt;
    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      parsedCreatedAt = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
    }

    return GoalModel(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] == 'smart' ? GoalType.smart : GoalType.templated,
      task: map['task'] ?? '',
      text: map['text'] ?? '',
      frequency: _parseFrequency(map['frequency']),
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      sharedToBulletin: map['sharedToBulletin'] ?? false,
      archived: map['archived'] == true,
      createdAt: parsedCreatedAt,
      isCompletedToday: isCompletedToday,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type == GoalType.smart ? 'smart' : 'templated',
      'task': task,
      'text': text,
      'frequency': frequency.name,
      'currentStreak': currentStreak,
      'sharedToBulletin': sharedToBulletin,
      'archived': archived,
      'createdAt': createdAt,
    };
  }

  static GoalFrequency _parseFrequency(String? freqStr) {
    switch (freqStr) {
      case 'weekly':
        return GoalFrequency.weekly;
      case 'monthly':
        return GoalFrequency.monthly;
      default:
        return GoalFrequency.daily;
    }
  }

  /// The text shown on the card: SMART goals show their private text.
  String get displayText => type == GoalType.smart ? text : task;

  GoalModel copyWith({
    int? currentStreak,
    bool? sharedToBulletin,
    bool? archived,
    bool? isCompletedToday,
  }) {
    return GoalModel(
      id: id,
      userId: userId,
      type: type,
      task: task,
      text: text,
      frequency: frequency,
      currentStreak: currentStreak ?? this.currentStreak,
      sharedToBulletin: sharedToBulletin ?? this.sharedToBulletin,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
    );
  }
}
