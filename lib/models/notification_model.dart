import 'timestamp_parsing.dart';

/// Where tapping a notification should take the user.
enum NotificationTarget { guild, requests, achievements, none }

/// A server-written in-app notification from the `notifications` collection.
class AppNotification {
  final String id;
  final String type;
  final String text;
  final String? buildingId;
  final NotificationTarget target;
  final DateTime? createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.text,
    this.buildingId,
    this.target = NotificationTarget.guild,
    this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      type: map['type'] ?? '',
      text: map['text'] ?? '',
      buildingId: map['buildingId'],
      target: NotificationTarget.values.firstWhere(
        (t) => t.name == map['target'],
        orElse: () => NotificationTarget.guild,
      ),
      createdAt: parseTimestamp(map['createdAt']),
      readAt: parseTimestamp(map['readAt']),
    );
  }

  String get emoji {
    switch (type) {
      case 'join_request':
        return '📩';
      case 'request_approved':
      case 'member_joined':
        return '👋';
      case 'request_rejected':
        return '✉️';
      case 'member_left':
        return '🚪';
      case 'fish_deposited':
        return '🐟';
      case 'achievement_unlocked':
        return '🏆';
      case 'leadership_changed':
        return '⭐';
      default:
        return '🔔';
    }
  }
}
