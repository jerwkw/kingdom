import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/building_model.dart';
import '../providers/building_provider.dart';
import '../utils/achievement_timeline.dart';

/// Guild history: unlocked achievements in the order they happened, locked
/// milestones with progress, and recent fund contributions.
class GuildAchievementsScreen extends ConsumerWidget {
  const GuildAchievementsScreen({super.key});

  static final _dateFormat = DateFormat('d MMM yyyy, h:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final building = ref.watch(currentBuildingDocProvider).value;
    final unlocksAsync = ref.watch(buildingAchievementsProvider);
    final ledgerAsync = ref.watch(buildingFundLedgerProvider);
    final names = {
      for (final m
          in ref.watch(buildingMemberStatsProvider).value ??
              const <BuildingMemberStat>[])
        m.uid: m.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          building == null ? 'Guild History' : '${building.name} History',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: building == null
          ? const Center(child: Text('You are not in a neighbourhood.'))
          : unlocksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Could not load achievements: $err')),
              data: (unlocks) {
                final timeline = buildAchievementTimeline(
                  unlocks,
                  building.groupFund,
                );
                final unlockedCount = timeline
                    .where((e) => e.isUnlocked)
                    .length;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '$unlockedCount of ${timeline.length} unlocked · ${building.groupFund} 🐟 in the Guild Fund',
                      style: TextStyle(
                        color: Colors.teal.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...timeline.map(
                      (entry) => _AchievementTile(
                        entry: entry,
                        dateFormat: _dateFormat,
                      ),
                    ),
                    const Divider(height: 32),
                    const Text(
                      'Recent Contributions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ledgerAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) =>
                          Text('Could not load contributions: $err'),
                      data: (entries) => entries.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'No contributions recorded yet. Completing goals and depositing fish both add to the fund.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : Column(
                              children: entries
                                  .map(
                                    (e) => _LedgerTile(
                                      entry: e,
                                      name: names[e.uid],
                                      dateFormat: _dateFormat,
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final AchievementTimelineEntry entry;
  final DateFormat dateFormat;

  const _AchievementTile({required this.entry, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final unlock = entry.unlock;
    final def = entry.definition;
    final String status;
    if (unlock == null) {
      status = 'Locked · ${def.threshold} 🐟 needed';
    } else if (unlock.unlockedAt != null) {
      status = 'Unlocked ${dateFormat.format(unlock.unlockedAt!.toLocal())}';
    } else if (unlock.backfilled) {
      status = 'Unlocked · date unknown (recorded before history tracking)';
    } else {
      status = 'Unlocked just now';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: entry.isUnlocked
              ? Colors.amber.shade400
              : Colors.grey.shade300,
          width: entry.isUnlocked ? 1.5 : 1,
        ),
      ),
      color: entry.isUnlocked ? Colors.amber.shade50 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Opacity(
              opacity: entry.isUnlocked ? 1 : 0.4,
              child: Text(def.emoji, style: const TextStyle(fontSize: 32)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    def.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: entry.isUnlocked
                          ? Colors.black87
                          : Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    def.description,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(fontSize: 11, color: Colors.teal.shade800),
                  ),
                  if (!entry.isUnlocked) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: entry.progress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                      semanticsLabel: '${def.title} progress',
                      semanticsValue: '${(entry.progress * 100).round()}%',
                    ),
                  ],
                ],
              ),
            ),
            if (entry.isUnlocked)
              const Icon(
                Icons.check_circle,
                color: Colors.amber,
                semanticLabel: 'Unlocked',
              ),
          ],
        ),
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  final FundLedgerEntry entry;
  final String? name;
  final DateFormat dateFormat;

  const _LedgerTile({
    required this.entry,
    required this.name,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final who = name ?? 'A former member';
    final what = switch (entry.source) {
      'goal' => 'completed a goal',
      'dailyChallenge' => 'completed the daily reflection',
      _ => 'deposited fish',
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Text(
        entry.source == 'deposit' ? '🐟' : '✅',
        style: const TextStyle(fontSize: 20),
      ),
      title: Text('$who $what'),
      subtitle: Text(
        entry.createdAt == null
            ? 'Just now'
            : dateFormat.format(entry.createdAt!.toLocal()),
      ),
      trailing: Text(
        '+${entry.amount} → ${entry.balanceAfter}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
