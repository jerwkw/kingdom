import 'package:flutter/material.dart';

enum CosmeticCategory { headpiece, shirt, pants, companion }

class StoreItemConfig {
  final String id;
  final String name;
  final CosmeticCategory category;
  final int cost;
  final String emoji;
  final IconData icon;
  final Color color;

  const StoreItemConfig({
    required this.id,
    required this.name,
    required this.category,
    required this.cost,
    required this.emoji,
    required this.icon,
    required this.color,
  });
}

class StoreConfig {
  static const List<StoreItemConfig> catalog = [
    // Headpieces
    StoreItemConfig(
      id: 'head_crown',
      name: 'Crown of Grace',
      category: CosmeticCategory.headpiece,
      cost: 30,
      emoji: '👑',
      icon: Icons.workspace_premium,
      color: Colors.amber,
    ),
    StoreItemConfig(
      id: 'head_halo',
      name: 'Gentle Halo',
      category: CosmeticCategory.headpiece,
      cost: 20,
      emoji: '😇',
      icon: Icons.wb_sunny,
      color: Colors.yellow,
    ),
    StoreItemConfig(
      id: 'head_cap',
      name: 'Worker Cap',
      category: CosmeticCategory.headpiece,
      cost: 15,
      emoji: '🧢',
      icon: Icons.hardware,
      color: Colors.blue,
    ),

    // Shirts
    StoreItemConfig(
      id: 'shirt_tunic',
      name: 'Linen Tunic',
      category: CosmeticCategory.shirt,
      cost: 25,
      emoji: '👕',
      icon: Icons.checkroom,
      color: Colors.teal,
    ),
    StoreItemConfig(
      id: 'shirt_armor',
      name: 'Armor of Light',
      category: CosmeticCategory.shirt,
      cost: 50,
      emoji: '🛡️',
      icon: Icons.security,
      color: Colors.indigo,
    ),

    // Pants
    StoreItemConfig(
      id: 'pants_joggers',
      name: 'Comfort Joggers',
      category: CosmeticCategory.pants,
      cost: 20,
      emoji: '👖',
      icon: Icons.directions_walk,
      color: Colors.deepOrange,
    ),

    // Companions
    StoreItemConfig(
      id: 'companion_dove',
      name: 'Peaceful Dove',
      category: CosmeticCategory.companion,
      cost: 40,
      emoji: '🕊️',
      icon: Icons.flutter_dash,
      color: Colors.lightBlue,
    ),
    StoreItemConfig(
      id: 'companion_lamb',
      name: 'Gentle Lamb',
      category: CosmeticCategory.companion,
      cost: 60,
      emoji: '🐑',
      icon: Icons.pets,
      color: Colors.pink,
    ),
  ];

  static StoreItemConfig? getItemById(String id) {
    try {
      return catalog.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}
