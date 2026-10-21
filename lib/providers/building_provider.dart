import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/building_model.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

final _currentBuildingIdProvider = Provider<String?>((ref) {
  final id = ref.watch(userProfileProvider.select((p) => p.value?.buildingId));
  return (id == null || id.isEmpty) ? null : id;
});

final currentBuildingDocProvider = StreamProvider<BuildingModel?>((ref) {
  final buildingId = ref.watch(_currentBuildingIdProvider);
  if (buildingId == null) return Stream.value(null);

  final firestore = ref.watch(firestoreInstanceProvider);
  return firestore.collection('buildings').doc(buildingId).snapshots().map((
    doc,
  ) {
    if (!doc.exists || doc.data() == null) return null;
    return BuildingModel.fromMap(doc.id, doc.data()!);
  });
});

final buildingMemberStatsProvider = FutureProvider<List<BuildingMemberStat>>((
  ref,
) async {
  final buildingId = ref.watch(_currentBuildingIdProvider);
  if (buildingId == null) return [];

  final data = await ref
      .read(apiClientProvider)
      .get('buildingStats/$buildingId');
  final membersList = data['members'] as List<dynamic>? ?? [];
  return membersList
      .map((m) => BuildingMemberStat.fromMap(Map<String, dynamic>.from(m)))
      .toList();
});

/// Server-recorded achievement unlocks for the current building.
final buildingAchievementsProvider = StreamProvider<List<AchievementUnlock>>((
  ref,
) {
  final buildingId = ref.watch(_currentBuildingIdProvider);
  if (buildingId == null) return Stream.value(const []);
  return ref
      .watch(firestoreInstanceProvider)
      .collection('buildings')
      .doc(buildingId)
      .collection('achievements')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => AchievementUnlock.fromMap(d.id, d.data()))
            .toList(),
      );
});

/// Most recent guild-fund contributions for the current building.
final buildingFundLedgerProvider = StreamProvider<List<FundLedgerEntry>>((ref) {
  final buildingId = ref.watch(_currentBuildingIdProvider);
  if (buildingId == null) return Stream.value(const []);
  return ref
      .watch(firestoreInstanceProvider)
      .collection('buildings')
      .doc(buildingId)
      .collection('fundLedger')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => FundLedgerEntry.fromMap(d.id, d.data()))
            .toList(),
      );
});

/// Membership and fund actions. Each returns an error message, or null on
/// success. Profile, building and fund values are live Firestore streams, so
/// only the request/response statistics need refreshing afterwards.
class BuildingNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  BuildingNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<String?> _call(
    String path,
    Map<String, dynamic> body, {
    bool tracksLoading = false,
    bool refreshesStats = true,
  }) async {
    if (tracksLoading) state = const AsyncValue.loading();
    try {
      await _ref.read(apiClientProvider).post(path, body);
      if (tracksLoading) state = const AsyncValue.data(null);
      if (refreshesStats) _ref.invalidate(buildingMemberStatsProvider);
      return null;
    } on ApiException catch (e, st) {
      if (tracksLoading) state = AsyncValue.error(e, st);
      return e.message;
    }
  }

  Future<String?> createBuilding({
    required String name,
    required String description,
    required String inviteCode,
  }) => _call('createBuilding', {
    'name': name,
    'description': description,
    'inviteCode': inviteCode,
  }, tracksLoading: true);

  Future<String?> joinBuilding(String inviteCode) =>
      _call('joinBuilding', {'inviteCode': inviteCode}, tracksLoading: true);

  Future<String?> approveJoinRequest(String buildingId, String targetUid) =>
      _call('approveJoinRequest', {
        'buildingId': buildingId,
        'targetUid': targetUid,
      });

  Future<String?> rejectJoinRequest(String buildingId, String targetUid) =>
      _call('rejectJoinRequest', {
        'buildingId': buildingId,
        'targetUid': targetUid,
      }, refreshesStats: false);

  Future<String?> promoteAdmin(String buildingId, String targetUid) => _call(
    'promoteBuildingAdmin',
    {'buildingId': buildingId, 'targetUid': targetUid},
    refreshesStats: false,
  );

  Future<String?> leaveBuilding(String buildingId) =>
      _call('leaveBuilding', {'buildingId': buildingId}, tracksLoading: true);

  Future<String?> depositFish(String buildingId, int amount) async {
    if (amount <= 0) return messageForApiError('INVALID_AMOUNT');
    final balance = _ref.read(userProfileProvider).value?.fishBalance ?? 0;
    if (balance < amount) return messageForApiError('INSUFFICIENT_FUNDS');
    return _call(
      'depositFish',
      {'buildingId': buildingId, 'amount': amount},
      tracksLoading: true,
      refreshesStats: false,
    );
  }
}

final buildingNotifierProvider =
    StateNotifierProvider<BuildingNotifier, AsyncValue<void>>((ref) {
      return BuildingNotifier(ref);
    });
