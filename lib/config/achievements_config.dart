/// Display copy for guild achievements. Ids and thresholds must match
/// functions/lib/achievements.json, which decides when they unlock;
/// test/catalog_parity_test.dart enforces this. Achievements are
/// display-only milestones and do not change gameplay.
class AchievementDefinition {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final int threshold;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.threshold,
  });
}

class AchievementsConfig {
  static const List<AchievementDefinition> all = [
    AchievementDefinition(
      id: 'founded',
      title: 'Guild Founded',
      emoji: '🏰',
      description: 'Established the neighbourhood guild.',
      threshold: 0,
    ),
    AchievementDefinition(
      id: 'first_fish',
      title: 'First Contribution',
      emoji: '🐟',
      description: 'Reached 10 fish in the Guild Fund.',
      threshold: 10,
    ),
    AchievementDefinition(
      id: 'playground',
      title: 'Community Playground',
      emoji: '🌳',
      description: 'Reached 50 fish in the Guild Fund.',
      threshold: 50,
    ),
    AchievementDefinition(
      id: 'fountain',
      title: 'Fountain of Faith',
      emoji: '⛲',
      description: 'Reached 100 fish in the Guild Fund.',
      threshold: 100,
    ),
    AchievementDefinition(
      id: 'sanctuary',
      title: 'Spiritual Sanctuary',
      emoji: '🕊️',
      description: 'Reached 250 fish in the Guild Fund.',
      threshold: 250,
    ),
    AchievementDefinition(
      id: 'citadel',
      title: 'Kingdom Citadel',
      emoji: '👑',
      description: 'Reached 500 fish in the Guild Fund.',
      threshold: 500,
    ),
  ];

  static AchievementDefinition? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
