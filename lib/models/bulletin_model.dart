import 'package:cloud_firestore/cloud_firestore.dart';

enum BulletinType { prayer, thanksgiving, sharing }

class BulletinPost {
  final String id;
  final String userId;
  final String authorName;
  final String authorRole;
  final String buildingId;
  final BulletinType type;
  final String text;
  final Map<String, String> reactions; // userId -> emoji
  final DateTime? createdAt;

  BulletinPost({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.authorRole,
    required this.buildingId,
    required this.type,
    required this.text,
    required this.reactions,
    this.createdAt,
  });

  factory BulletinPost.fromMap(String id, Map<String, dynamic> map) {
    final rawReactions = map['reactions'];
    Map<String, String> parsedReactions = {};
    if (rawReactions is Map) {
      rawReactions.forEach((k, v) {
        parsedReactions[k.toString()] = v.toString();
      });
    }

    DateTime? parsedCreatedAt;
    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      parsedCreatedAt = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
    }

    return BulletinPost(
      id: id,
      userId: map['userId'] ?? '',
      authorName: map['authorName'] ?? 'Church Member',
      authorRole: map['authorRole'] ?? 'gardener',
      buildingId: map['buildingId'] ?? '',
      type: _parseType(map['type']),
      text: map['text'] ?? '',
      reactions: parsedReactions,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'authorName': authorName,
      'authorRole': authorRole,
      'buildingId': buildingId,
      'type': type.name,
      'text': text,
      'reactions': reactions,
      'createdAt': createdAt,
    };
  }

  static BulletinType _parseType(String? typeStr) {
    switch (typeStr) {
      case 'thanksgiving':
        return BulletinType.thanksgiving;
      case 'sharing':
        return BulletinType.sharing;
      default:
        return BulletinType.prayer;
    }
  }
}
