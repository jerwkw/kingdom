import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/store_config.dart';
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

  Future<String?> purchaseItem(StoreItemConfig item) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return 'Not authenticated';

    state = const AsyncValue.loading();
    try {
      final token = await user.getIdToken();
      final baseUrl = _ref.read(piServerBaseUrlProvider);

      final response = await http.post(
        Uri.parse('$baseUrl/purchaseItem'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'itemId': item.id,
          'cost': item.cost,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        state = const AsyncValue.data(null);
        _ref.invalidate(userProfileProvider);
        _ref.invalidate(ownedItemIdsProvider);
        return null; // Success
      } else {
        final errorMsg = data['error'] ?? 'Purchase failed';
        state = AsyncValue.error(errorMsg, StackTrace.current);
        return errorMsg;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 'Connection error reaching server.';
    }
  }

  Future<void> equipItem(StoreItemConfig item) async {
    final user = _ref.read(authStateProvider).value;
    final userProfile = _ref.read(userProfileProvider).value;
    if (user == null || userProfile == null) return;

    final firestore = _ref.read(firestoreInstanceProvider);
    final updatedConfig = Map<String, String>.from(userProfile.avatarConfig);

    final categoryKey = item.category.name;
    if (updatedConfig[categoryKey] == item.id) {
      // Unequip if already equipped
      updatedConfig.remove(categoryKey);
    } else {
      // Equip item
      updatedConfig[categoryKey] = item.id;
    }

    await firestore.collection('users').doc(user.uid).update({
      'avatarConfig': updatedConfig,
    });
  }
}

final storeNotifierProvider = StateNotifierProvider<StoreNotifier, AsyncValue<void>>((ref) {
  return StoreNotifier(ref);
});
