import 'package:flutter/material.dart';

class ChurchRole {
  final String id;
  final String title;
  final String emoji;
  final IconData icon;
  final Color color;
  final String description;

  const ChurchRole({
    required this.id,
    required this.title,
    required this.emoji,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class RolesConfig {
  static const List<ChurchRole> allRoles = [
    ChurchRole(
      id: 'gardener',
      title: 'Gardener',
      emoji: '🌱',
      icon: Icons.eco,
      color: Colors.green,
      description: 'Nurtures spiritual growth, waters faith in others, and encourages patience.',
    ),
    ChurchRole(
      id: 'electrician',
      title: 'Electrician',
      emoji: '⚡',
      icon: Icons.flash_on,
      color: Colors.amber,
      description: 'Brings spiritual power, enthusiasm, and lights up worship and fellowship.',
    ),
    ChurchRole(
      id: 'cleaner',
      title: 'Cleaner',
      emoji: '✨',
      icon: Icons.cleaning_services,
      color: Colors.cyan,
      description: 'Clears distractions, maintains a peaceful environment, and keeps hearts focused.',
    ),
    ChurchRole(
      id: 'plumber',
      title: 'Plumber',
      emoji: '💧',
      icon: Icons.water_drop,
      color: Colors.blue,
      description: 'Ensures living water flows, clears spiritual blockages, and brings refreshment.',
    ),
    ChurchRole(
      id: 'painter',
      title: 'Painter',
      emoji: '🎨',
      icon: Icons.palette,
      color: Colors.purple,
      description: 'Adds color to community life, expresses gratitude, and highlights God’s beauty.',
    ),
  ];

  static ChurchRole getRoleById(String roleId) {
    return allRoles.firstWhere(
      (r) => r.id == roleId.toLowerCase(),
      orElse: () => allRoles[0], // Default to Gardener
    );
  }
}
