import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import 'auth_provider.dart';

/// The user's 50 most recent in-app notifications, newest first.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref
      .watch(firestoreInstanceProvider)
      .collection('notifications')
      .where('recipientUid', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => AppNotification.fromMap(d.id, d.data()))
            .toList(),
      );
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).value ?? const [];
  return notifications.where((n) => !n.isRead).length;
});

class NotificationsNotifier {
  final Ref _ref;
  NotificationsNotifier(this._ref);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _ref.read(firestoreInstanceProvider).collection('notifications');

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    await _collection.doc(notification.id).update({
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllRead(List<AppNotification> notifications) async {
    final unread = notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    final batch = _ref.read(firestoreInstanceProvider).batch();
    for (final n in unread) {
      batch.update(_collection.doc(n.id), {
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

final notificationsNotifierProvider = Provider<NotificationsNotifier>(
  (ref) => NotificationsNotifier(ref),
);
