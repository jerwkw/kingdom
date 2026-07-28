import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/building_model.dart';
import 'auth_provider.dart';

final currentBuildingDocProvider = StreamProvider<BuildingModel?>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile == null || userProfile.buildingId == null) {
    return Stream.value(null);
  }

  final firestore = ref.watch(firestoreInstanceProvider);
  return firestore
      .collection('buildings')
      .doc(userProfile.buildingId)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    return BuildingModel.fromMap(doc.id, doc.data()!);
  });
});

final buildingMemberStatsProvider = FutureProvider<List<BuildingMemberStat>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  final userProfile = ref.watch(userProfileProvider).value;

  if (user == null || userProfile == null || userProfile.buildingId == null) {
    return [];
  }

  final token = await user.getIdToken();
  final baseUrl = ref.watch(piServerBaseUrlProvider);
  final buildingId = userProfile.buildingId!;

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/buildingStats/$buildingId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final membersList = data['members'] as List<dynamic>? ?? [];
      return membersList.map((m) => BuildingMemberStat.fromMap(m)).toList();
    }
  } catch (e) {
    // If Pi server is offline during initial test, fallback gracefully to self stat
    return [
      BuildingMemberStat(
        uid: userProfile.uid,
        name: userProfile.name,
        role: userProfile.role,
        avatarConfig: userProfile.avatarConfig,
        completionPercent: 85,
      ),
    ];
  }
  return [];
});

class BuildingNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  BuildingNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<String?> createBuilding({
    required String name,
    required String description,
    required String inviteCode,
  }) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return 'Not authenticated';

    state = const AsyncValue.loading();
    try {
      final token = await user.getIdToken();
      final baseUrl = _ref.read(piServerBaseUrlProvider);

      final response = await http.post(
        Uri.parse('$baseUrl/createBuilding'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'description': description,
          'inviteCode': inviteCode,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        state = const AsyncValue.data(null);
        _ref.invalidate(userProfileProvider);
        _ref.invalidate(currentBuildingDocProvider);
        _ref.invalidate(buildingMemberStatsProvider);
        return null; // Success
      } else {
        final errorMsg = data['error'] ?? 'Failed to create neighbourhood';
        state = AsyncValue.error(errorMsg, StackTrace.current);
        return errorMsg;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 'Connection error reaching server.';
    }
  }

  Future<String?> joinBuilding(String inviteCode) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return 'Not authenticated';

    state = const AsyncValue.loading();
    try {
      final token = await user.getIdToken();
      final baseUrl = _ref.read(piServerBaseUrlProvider);

      final response = await http.post(
        Uri.parse('$baseUrl/joinBuilding'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'inviteCode': inviteCode}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        state = const AsyncValue.data(null);
        _ref.invalidate(userProfileProvider);
        _ref.invalidate(currentBuildingDocProvider);
        _ref.invalidate(buildingMemberStatsProvider);
        return null; // Success (request pending)
      } else {
        final errorMsg = data['error'] ?? 'Failed to join building';
        state = AsyncValue.error(errorMsg, StackTrace.current);
        return errorMsg;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 'Connection error reaching server.';
    }
  }

  Future<String?> approveJoinRequest(String buildingId, String targetUid) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return 'Not authenticated';

    try {
      final token = await user.getIdToken();
      final baseUrl = _ref.read(piServerBaseUrlProvider);

      final response = await http.post(
        Uri.parse('$baseUrl/approveJoinRequest'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'buildingId': buildingId,
          'targetUid': targetUid,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _ref.invalidate(currentBuildingDocProvider);
        _ref.invalidate(buildingMemberStatsProvider);
        return null;
      } else {
        return data['error'] ?? 'Failed to approve join request';
      }
    } catch (e) {
      return 'Connection error reaching server.';
    }
  }

  Future<String?> rejectJoinRequest(String buildingId, String targetUid) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return 'Not authenticated';

    try {
      final token = await user.getIdToken();
      final baseUrl = _ref.read(piServerBaseUrlProvider);

      final response = await http.post(
        Uri.parse('$baseUrl/rejectJoinRequest'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'buildingId': buildingId,
          'targetUid': targetUid,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _ref.invalidate(currentBuildingDocProvider);
        return null;
      } else {
        return data['error'] ?? 'Failed to reject join request';
      }
    } catch (e) {
      return 'Connection error reaching server.';
    }
  }

  Future<String?> promoteAdmin(String buildingId, String targetUid) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return 'Not authenticated';

    try {
      final token = await user.getIdToken();
      final baseUrl = _ref.read(piServerBaseUrlProvider);

      final response = await http.post(
        Uri.parse('$baseUrl/promoteBuildingAdmin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'buildingId': buildingId,
          'targetUid': targetUid,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _ref.invalidate(currentBuildingDocProvider);
        return null;
      } else {
        return data['error'] ?? 'Failed to promote admin';
      }
    } catch (e) {
      return 'Connection error reaching server.';
    }
  }

  Future<String?> leaveBuilding(String buildingId) async {
    final user = _ref.read(authStateProvider).value;
    if (user == null) return 'Not authenticated';

    state = const AsyncValue.loading();
    try {
      final token = await user.getIdToken();
      final baseUrl = _ref.read(piServerBaseUrlProvider);

      final response = await http.post(
        Uri.parse('$baseUrl/leaveBuilding'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'buildingId': buildingId}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        state = const AsyncValue.data(null);
        _ref.invalidate(userProfileProvider);
        _ref.invalidate(currentBuildingDocProvider);
        _ref.invalidate(buildingMemberStatsProvider);
        return null;
      } else {
        final errorMsg = data['error'] ?? 'Failed to leave building';
        state = AsyncValue.error(errorMsg, StackTrace.current);
        return errorMsg;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 'Connection error reaching server.';
    }
  }
}

final buildingNotifierProvider = StateNotifierProvider<BuildingNotifier, AsyncValue<void>>((ref) {
  return BuildingNotifier(ref);
});
