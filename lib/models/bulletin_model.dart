import 'timestamp_parsing.dart';

enum BulletinType { prayer, thanksgiving, sharing }

class BulletinPost {
  final String id;
  final String userId;
  final String authorName;
  final String buildingId;
  final BulletinType type;
  final String text;
  final Map<String, String> reactions; // userId -> emoji
  final DateTime? createdAt;
  final DateTime? editedAt;

  BulletinPost({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.buildingId,
    required this.type,
    required this.text,
    required this.reactions,
    this.createdAt,
    this.editedAt,
  });

  factory BulletinPost.fromMap(String id, Map<String, dynamic> map) {
    final rawReactions = map['reactions'];
    Map<String, String> parsedReactions = {};
    if (rawReactions is Map) {
      rawReactions.forEach((k, v) {
        parsedReactions[k.toString()] = v.toString();
      });
    }

    return BulletinPost(
      id: id,
      userId: map['userId'] ?? '',
      authorName: map['authorName'] ?? 'Church Member',
      buildingId: map['buildingId'] ?? '',
      type: _parseType(map['type']),
      text: map['text'] ?? '',
      reactions: parsedReactions,
      createdAt: parseTimestamp(map['createdAt']),
      editedAt: parseTimestamp(map['editedAt']),
    );
  }

  bool get isEdited => editedAt != null;

  /// Reactions after [uid] taps [emoji]: tapping the current reaction clears
  /// it, any other emoji replaces it. Only [uid]'s entry changes, matching
  /// firestore.rules.
  static Map<String, String> toggledReactions(
    Map<String, String> reactions,
    String uid,
    String emoji,
  ) {
    final updated = Map<String, String>.from(reactions);
    if (updated[uid] == emoji) {
      updated.remove(uid);
    } else {
      updated[uid] = emoji;
    }
    return updated;
  }

  static const allowedReactions = ['❤️', '🙏', '🙌', '💡'];

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
