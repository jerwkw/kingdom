import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/store_config.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

final ownedItemIdsProvider = StreamProvider<Set<String>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value({});

  final firestore = ref.watch(firestoreInstanceProvider);
  return firestore
      .collection('inventory')
      .doc(user.uid)
      .collection('items')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.id).toSet());
});

class StoreNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  StoreNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Returns an error message, or null on success. Prices are decided by the
  /// server; only the item id is sent.
  Future<String?> purchaseItem(StoreItemConfig item) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(apiClientProvider).post('purchaseItem', {
        'itemId': item.id,
      });
      state = const AsyncValue.data(null);
      return null;
    } on ApiException catch (e, st) {
      state = AsyncValue.error(e, st);
      return e.message;
    }
  }

  /// Toggles an owned item in its avatar slot. Ownership is verified
  /// server-side; clients cannot write premium slots directly.
  Future<String?> equipItem(StoreItemConfig item) async {
    try {
      await _ref.read(apiClientProvider).post('equipItem', {'itemId': item.id});
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}

final storeNotifierProvider =
    StateNotifierProvider<StoreNotifier, AsyncValue<void>>((ref) {
      return StoreNotifier(ref);
    });
