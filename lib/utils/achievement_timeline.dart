import '../config/achievements_config.dart';
import '../models/building_model.dart';

class AchievementTimelineEntry {
  final AchievementDefinition definition;
  final AchievementUnlock? unlock;

  /// 0..1 progress of the current fund toward a locked milestone.
  final double progress;

  const AchievementTimelineEntry(this.definition, this.unlock, this.progress);

  bool get isUnlocked => unlock != null;
}

/// Unlocked achievements in chronological order (backfilled ones with unknown
/// dates first, unlocks whose server timestamp is still pending last), then
/// locked milestones by threshold with progress toward each.
List<AchievementTimelineEntry> buildAchievementTimeline(
  List<AchievementUnlock> unlocks,
  int groupFund,
) {
  final byId = {for (final u in unlocks) u.achievementId: u};

  int rank(AchievementUnlock u) =>
      u.unlockedAt != null ? 1 : (u.backfilled ? 0 : 2);

  final unlocked =
      AchievementsConfig.all.where((d) => byId.containsKey(d.id)).toList()
        ..sort((a, b) {
          final ua = byId[a.id]!, ub = byId[b.id]!;
          final byRank = rank(ua).compareTo(rank(ub));
          if (byRank != 0) return byRank;
          if (ua.unlockedAt != null && ub.unlockedAt != null) {
            final byTime = ua.unlockedAt!.compareTo(ub.unlockedAt!);
            if (byTime != 0) return byTime;
          }
          return a.threshold.compareTo(b.threshold);
        });

  final locked =
      AchievementsConfig.all.where((d) => !byId.containsKey(d.id)).toList()
        ..sort((a, b) => a.threshold.compareTo(b.threshold));

  return [
    for (final d in unlocked) AchievementTimelineEntry(d, byId[d.id], 1),
    for (final d in locked)
      AchievementTimelineEntry(
        d,
        null,
        d.threshold <= 0 ? 0 : (groupFund / d.threshold).clamp(0.0, 1.0),
      ),
  ];
}
