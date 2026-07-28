class BuildingMemberStat {
  final String uid;
  final String name;
  final String role;
  final Map<String, String> avatarConfig;
  final int completionPercent;

  BuildingMemberStat({
    required this.uid,
    required this.name,
    required this.role,
    required this.avatarConfig,
    required this.completionPercent,
  });

  factory BuildingMemberStat.fromMap(Map<String, dynamic> map) {
    final rawAvatar = map['avatarConfig'];
    Map<String, String> parsedAvatar = {};
    if (rawAvatar is Map) {
      rawAvatar.forEach((k, v) {
        parsedAvatar[k.toString()] = v.toString();
      });
    }

    return BuildingMemberStat(
      uid: map['uid'] ?? '',
      name: map['name'] ?? 'Member',
      role: map['role'] ?? 'gardener',
      avatarConfig: parsedAvatar,
      completionPercent: (map['completionPercent'] as num?)?.toInt() ?? 0,
    );
  }
}

class PendingJoinRequest {
  final String uid;
  final String name;
  final Map<String, String> avatarConfig;
  final String? requestedAt;

  PendingJoinRequest({
    required this.uid,
    required this.name,
    required this.avatarConfig,
    this.requestedAt,
  });

  factory PendingJoinRequest.fromMap(Map<String, dynamic> map) {
    final rawAvatar = map['avatarConfig'];
    Map<String, String> parsedAvatar = {};
    if (rawAvatar is Map) {
      rawAvatar.forEach((k, v) {
        parsedAvatar[k.toString()] = v.toString();
      });
    }

    return PendingJoinRequest(
      uid: map['uid'] ?? '',
      name: map['name'] ?? 'Member',
      avatarConfig: parsedAvatar,
      requestedAt: map['requestedAt']?.toString(),
    );
  }
}

class BuildingModel {
  final String id;
  final String name;
  final String description;
  final String inviteCode;
  final String creatorUid;
  final String leaderUid;
  final List<String> adminUids;
  final List<String> memberIds;
  final List<PendingJoinRequest> pendingJoinRequests;
  final int groupFund;
  final List<BuildingMemberStat> memberStats;

  BuildingModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.inviteCode,
    this.creatorUid = '',
    this.leaderUid = '',
    this.adminUids = const [],
    required this.memberIds,
    this.pendingJoinRequests = const [],
    required this.groupFund,
    this.memberStats = const [],
  });

  factory BuildingModel.fromMap(String id, Map<String, dynamic> map, {List<BuildingMemberStat> stats = const []}) {
    final rawPending = map['pendingJoinRequests'];
    List<PendingJoinRequest> parsedPending = [];
    if (rawPending is List) {
      parsedPending = rawPending
          .whereType<Map>()
          .map((item) => PendingJoinRequest.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    return BuildingModel(
      id: id,
      name: map['name'] ?? 'Cell Group',
      description: map['description'] ?? '',
      inviteCode: map['inviteCode'] ?? '',
      creatorUid: map['creatorUid'] ?? '',
      leaderUid: map['leaderUid'] ?? '',
      adminUids: List<String>.from(map['adminUids'] ?? []),
      memberIds: List<String>.from(map['memberIds'] ?? []),
      pendingJoinRequests: parsedPending,
      groupFund: (map['groupFund'] as num?)?.toInt() ?? 0,
      memberStats: stats,
    );
  }

  bool isAdmin(String uid) => adminUids.contains(uid) || leaderUid == uid;
  bool isLeader(String uid) => leaderUid == uid;
}
