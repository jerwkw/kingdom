import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bulletin_model.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

const bulletinPageSize = 20;

/// How many posts the bulletin currently shows; "Load more" raises it.
final bulletinPostLimitProvider = StateProvider<int>((ref) => bulletinPageSize);

final buildingBulletinPostsProvider = StreamProvider<List<BulletinPost>>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile == null || userProfile.buildingId == null) {
    return Stream.value([]);
  }

  final firestore = ref.watch(firestoreInstanceProvider);
  final limit = ref.watch(bulletinPostLimitProvider);
  return firestore
      .collection('bulletinPosts')
      .where('buildingId', isEqualTo: userProfile.buildingId)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => BulletinPost.fromMap(doc.id, doc.data()))
            .toList(),
      );
});

class BulletinNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  BulletinNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Creates a post through the API (rate limited, server-verified author).
  /// Returns an error message, or null on success.
  Future<String?> createPost({
    required BulletinType type,
    required String text,
  }) async {
    try {
      await _ref.read(apiClientProvider).post('createBulletinPost', {
        'type': type.name,
        'text': text.trim(),
      });
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> editPost(String postId, String text) async {
    await _ref
        .read(firestoreInstanceProvider)
        .collection('bulletinPosts')
        .doc(postId)
        .update({
          'text': text.trim(),
          'editedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> deletePost(String postId) async {
    await _ref
        .read(firestoreInstanceProvider)
        .collection('bulletinPosts')
        .doc(postId)
        .delete();
  }

  Future<void> toggleReaction(String postId, String emoji) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;

    final firestore = _ref.read(firestoreInstanceProvider);
    final postRef = firestore.collection('bulletinPosts').doc(postId);

    await firestore.runTransaction((transaction) async {
      final doc = await transaction.get(postRef);
      if (!doc.exists) return;

      final currentReactions = Map<String, String>.from(
        doc.data()?['reactions'] ?? {},
      );
      transaction.update(postRef, {
        'reactions': BulletinPost.toggledReactions(
          currentReactions,
          user.uid,
          emoji,
        ),
      });
    });
  }
}

final bulletinNotifierProvider =
    StateNotifierProvider<BulletinNotifier, AsyncValue<void>>((ref) {
      return BulletinNotifier(ref);
    });
