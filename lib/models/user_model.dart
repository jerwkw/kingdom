import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String? buildingId;
  final int fishBalance;
  final Map<String, String> avatarConfig; // headpiece, shirt, pants, companion
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.name,
    this.buildingId,
    required this.fishBalance,
    required this.avatarConfig,
    this.createdAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    final rawAvatar = map['avatarConfig'];
    Map<String, String> parsedAvatar = {};
    if (rawAvatar is Map) {
      rawAvatar.forEach((k, v) {
        parsedAvatar[k.toString()] = v.toString();
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

    return UserModel(
      uid: uid,
      name: map['name'] ?? 'Church Member',
      buildingId: map['buildingId'],
      fishBalance: (map['fishBalance'] as num?)?.toInt() ?? 0,
      avatarConfig: parsedAvatar,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'buildingId': buildingId,
      'fishBalance': fishBalance,
      'avatarConfig': avatarConfig,
      'createdAt': createdAt,
    };
  }

  UserModel copyWith({
    String? name,
    String? buildingId,
    int? fishBalance,
    Map<String, String>? avatarConfig,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      buildingId: buildingId ?? this.buildingId,
      fishBalance: fishBalance ?? this.fishBalance,
      avatarConfig: avatarConfig ?? this.avatarConfig,
      createdAt: createdAt,
    );
  }
}
