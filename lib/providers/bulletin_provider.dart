import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bulletin_model.dart';
import 'auth_provider.dart';

final buildingBulletinPostsProvider = StreamProvider<List<BulletinPost>>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile == null || userProfile.buildingId == null) {
    return Stream.value([]);
  }

  final firestore = ref.watch(firestoreInstanceProvider);
  return firestore
      .collection('bulletinPosts')
      .where('buildingId', isEqualTo: userProfile.buildingId)
      .snapshots()
      .map((snap) {
    final posts = snap.docs.map((doc) => BulletinPost.fromMap(doc.id, doc.data())).toList();
    posts.sort((a, b) {
      if (a.createdAt == null || b.createdAt == null) return 0;
      return b.createdAt!.compareTo(a.createdAt!);
    });
    return posts;
  });
});

class BulletinNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  BulletinNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> createPost({
    required BulletinType type,
    required String text,
  }) async {
    final user = _ref.read(authStateProvider).value;
    final userProfile = _ref.read(userProfileProvider).value;
    if (user == null || userProfile == null || userProfile.buildingId == null) return;

    final firestore = _ref.read(firestoreInstanceProvider);
    await firestore.collection('bulletinPosts').add({
      'userId': user.uid,
      'authorName': userProfile.name,
      'authorRole': userProfile.role,
      'buildingId': userProfile.buildingId,
      'type': type.name,
      'text': text.trim(),
      'reactions': {},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleReaction(String postId, String emoji) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return;

    final firestore = _ref.read(firestoreInstanceProvider);
    final postRef = firestore.collection('bulletinPosts').doc(postId);

    await firestore.runTransaction((transaction) async {
      final doc = await transaction.get(postRef);
      if (!doc.exists) return;

      final currentReactions = Map<String, String>.from(doc.data()?['reactions'] ?? {});
      if (currentReactions[user.uid] == emoji) {
        currentReactions.remove(user.uid);
      } else {
        currentReactions[user.uid] = emoji;
      }

      transaction.update(postRef, {'reactions': currentReactions});
    });
  }
}

final bulletinNotifierProvider = StateNotifierProvider<BulletinNotifier, AsyncValue<void>>((ref) {
  return BulletinNotifier(ref);
});
