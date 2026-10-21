import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/limits.dart';
import '../models/goal_model.dart';
import '../providers/auth_provider.dart';
import '../providers/goals_provider.dart';
import '../widgets/challenge_card.dart';
import '../widgets/goal_card.dart';
import '../widgets/notification_bell.dart';

const _templatedTasks = [
  'Read Bible',
  'Pray',
  'Journal',
  'Attend Church',
  'Share Testimony',
  'Pray for someone',
  'Talk to someone in church',
];

const _frequencyItems = [
  DropdownMenuItem(value: GoalFrequency.daily, child: Text('Daily')),
  DropdownMenuItem(value: GoalFrequency.weekly, child: Text('Weekly')),
  DropdownMenuItem(value: GoalFrequency.monthly, child: Text('Monthly')),
];

class TasksTab extends ConsumerWidget {
  const TasksTab({super.key});

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Shared add/edit dialog. With [existing], edits that goal in place.
  void _showGoalDialog(
    BuildContext context,
    WidgetRef ref, {
    GoalModel? existing,
  }) {
    bool isSmart = existing?.type == GoalType.smart;
    String selectedTask =
        existing != null && existing.type == GoalType.templated
        ? existing.task
        : _templatedTasks.first;
    if (!_templatedTasks.contains(selectedTask)) {
      selectedTask = _templatedTasks.first;
    }
    GoalFrequency selectedFrequency =
        existing?.frequency ?? GoalFrequency.daily;
    final smartTextController = TextEditingController(
      text: existing?.type == GoalType.smart ? existing!.text : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(existing == null ? 'Add Spiritual Goal' : 'Edit Goal'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (existing == null) ...[
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Templated')),
                        ButtonSegment(value: true, label: Text('SMART Goal')),
                      ],
                      selected: {isSmart},
                      onSelectionChanged: (val) =>
                          setState(() => isSmart = val.first),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!isSmart)
                    DropdownButtonFormField<String>(
                      initialValue: selectedTask,
                      decoration: const InputDecoration(labelText: 'Task'),
                      items: _templatedTasks
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => selectedTask = val!),
                    )
                  else
                    TextField(
                      controller: smartTextController,
                      maxLines: 3,
                      maxLength: TextLimits.goalText,
                      decoration: const InputDecoration(
                        labelText: 'Specific Goal Text (Private)',
                        hintText:
                            'e.g., Pray for 15 minutes every night before sleep',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<GoalFrequency>(
                    initialValue: selectedFrequency,
                    decoration: const InputDecoration(labelText: 'Frequency'),
                    items: _frequencyItems,
                    onChanged: (val) =>
                        setState(() => selectedFrequency = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final text = smartTextController.text.trim();
                  if (isSmart && text.isEmpty) return;
                  Navigator.pop(ctx);
                  final notifier = ref.read(goalsNotifierProvider.notifier);
                  try {
                    if (existing != null) {
                      await notifier.updateGoal(
                        existing.id,
                        task: isSmart ? null : selectedTask,
                        text: isSmart ? text : null,
                        frequency: selectedFrequency,
                      );
                    } else if (isSmart) {
                      await notifier.addSmartGoal(
                        goalText: text,
                        frequency: selectedFrequency.name,
                      );
                    } else {
                      await notifier.addTemplatedGoal(
                        task: selectedTask,
                        frequency: selectedFrequency.name,
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      _showSnack(
                        context,
                        'Could not save the goal. Please try again.',
                      );
                    }
                  }
                },
                child: Text(existing == null ? 'Add Goal' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showShareDialog(BuildContext context, WidgetRef ref, GoalModel goal) {
    final controller = TextEditingController(text: goal.displayText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share to Bulletin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This posts a copy of the text below for your neighbourhood to see. '
              'Your private goal itself stays private. Edit anything you would rather not share.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: TextLimits.bulletinText,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              final err = await ref
                  .read(goalsNotifierProvider.notifier)
                  .shareToBulletin(goal, text);
              if (context.mounted) {
                _showSnack(context, err ?? 'Shared to the bulletin board.');
              }
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, GoalModel goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete goal?'),
        content: Text(
          '"${goal.displayText}" and its streak will be removed. Archive it instead if you may want it back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(goalsNotifierProvider.notifier).deleteGoal(goal.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    GoalModel goal,
    GoalAction action,
  ) {
    final notifier = ref.read(goalsNotifierProvider.notifier);
    switch (action) {
      case GoalAction.edit:
        _showGoalDialog(context, ref, existing: goal);
      case GoalAction.share:
        if (ref.read(userProfileProvider).value?.buildingId == null) {
          _showSnack(
            context,
            'Join a neighbourhood to share on its bulletin board.',
          );
        } else {
          _showShareDialog(context, ref, goal);
        }
      case GoalAction.archive:
        notifier.setArchived(goal.id, true);
      case GoalAction.restore:
        notifier.setArchived(goal.id, false);
      case GoalAction.delete:
        _confirmDelete(context, ref, goal);
    }
  }

  Widget _goalCard(
    BuildContext context,
    WidgetRef ref,
    GoalModel goal,
    GoalCompletionStatus status,
  ) {
    return GoalCard(
      key: ValueKey(goal.id),
      goal: goal,
      isPending: status.isPending(goal.id),
      errorText: status.errorFor(goal.id),
      onAction: (action) => _handleAction(context, ref, goal, action),
      onComplete: () async {
        final msg = await ref
            .read(goalCompletionStatusProvider.notifier)
            .completeGoal(goal.id);
        if (msg != null && context.mounted) _showSnack(context, msg);
      },
    );
  }

  Widget _buildChallenge(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(todayDailyChallengeProvider);
    final isChallengeCompleted =
        ref.watch(isChallengeCompletedTodayProvider).value ?? false;

    return challengeAsync.when(
      data: (data) {
        final prompt = data?['promptText'] as String?;
        if (prompt == null) {
          return _ChallengePlaceholder(
            message: "Today's reflection hasn't been published yet.",
            actionLabel: 'Load today\'s reflection',
            onAction: () async {
              final err = await ref
                  .read(goalsNotifierProvider.notifier)
                  .ensureDailyChallenge();
              if (err != null && context.mounted) _showSnack(context, err);
            },
          );
        }
        return ChallengeCard(
          promptText: prompt,
          isCompleted: isChallengeCompleted,
          onComplete: () async {
            final msg = await ref
                .read(goalsNotifierProvider.notifier)
                .completeDailyChallenge();
            if (msg != null && context.mounted) _showSnack(context, msg);
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16.0),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => _ChallengePlaceholder(
        message: "Couldn't load today's reflection.",
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(todayDailyChallengeProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(userGoalsProvider);
    final status = ref.watch(goalCompletionStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tasks & Daily Reflection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.add_task),
            tooltip: 'Add Goal',
            onPressed: () => _showGoalDialog(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChallenge(context, ref),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'My Personal Goals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            goalsAsync.when(
              data: (goals) {
                final active = goals.where((g) => !g.archived).toList();
                final archived = goals.where((g) => g.archived).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (active.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              const Text('🎯', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              const Text(
                                'No personal goals active.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _showGoalDialog(context, ref),
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Goal'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ...active.map((g) => _goalCard(context, ref, g, status)),
                    if (archived.isNotEmpty)
                      ExpansionTile(
                        title: Text('Archived goals (${archived.length})'),
                        children: archived
                            .map((g) => _goalCard(context, ref, g, status))
                            .toList(),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading goals: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGoalDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Goal'),
      ),
    );
  }
}

class _ChallengePlaceholder extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _ChallengePlaceholder({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DAILY REFLECTION',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
