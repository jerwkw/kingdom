import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/goals_provider.dart';
import '../widgets/challenge_card.dart';
import '../widgets/goal_card.dart';

class TasksTab extends ConsumerWidget {
  const TasksTab({super.key});

  void _showAddGoalDialog(BuildContext context, WidgetRef ref) {
    String goalType = 'templated';
    String selectedTask = 'Read Bible';
    String selectedFrequency = 'daily';
    final smartTextController = TextEditingController();

    const templatedTasks = [
      'Read Bible',
      'Pray',
      'Journal',
      'Attend Church',
      'Share Testimony',
      'Pray for someone',
      'Talk to someone in church'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Spiritual Goal'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'templated', label: Text('Templated')),
                      ButtonSegment(value: 'smart', label: Text('SMART Goal')),
                    ],
                    selected: {goalType},
                    onSelectionChanged: (val) => setState(() => goalType = val.first),
                  ),
                  const SizedBox(height: 16),
                  if (goalType == 'templated') ...[
                    DropdownButtonFormField<String>(
                      value: selectedTask,
                      decoration: const InputDecoration(labelText: 'Task'),
                      items: templatedTasks
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) => setState(() => selectedTask = val!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedFrequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                      ],
                      onChanged: (val) => setState(() => selectedFrequency = val!),
                    ),
                  ] else ...[
                    TextField(
                      controller: smartTextController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Specific Goal Text (Private)',
                        hintText: 'e.g., Pray for 15 minutes every night before sleep',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (goalType == 'templated') {
                    ref.read(goalsNotifierProvider.notifier).addTemplatedGoal(
                          task: selectedTask,
                          frequency: selectedFrequency,
                        );
                  } else {
                    if (smartTextController.text.trim().isNotEmpty) {
                      ref.read(goalsNotifierProvider.notifier).addSmartGoal(
                            goalText: smartTextController.text,
                          );
                    }
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Add Goal'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(userGoalsProvider);
    final challengeAsync = ref.watch(todayDailyChallengeProvider);
    final isChallengeCompleted = ref.watch(isChallengeCompletedTodayProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks & Daily Reflection', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            tooltip: 'Add Goal',
            onPressed: () => _showAddGoalDialog(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Challenge Section
            challengeAsync.when(
              data: (data) {
                final prompt = data?['promptText'] ?? 'What is one verse or word that encouraged your heart today?';
                return ChallengeCard(
                  promptText: prompt,
                  isCompleted: isChallengeCompleted,
                  onComplete: () async {
                    final msg = await ref.read(goalsNotifierProvider.notifier).completeDailyChallenge();
                    if (msg != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                    }
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16.0),
                child: LinearProgressIndicator(),
              ),
              error: (_, __) => const SizedBox(),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'My Personal Goals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            // User Goals List
            goalsAsync.when(
              data: (goals) {
                if (goals.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          const Text('🎯', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          const Text(
                            'No personal goals active.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _showAddGoalDialog(context, ref),
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Goal'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    return GoalCard(
                      goal: goal,
                      onToggleComplete: (_) async {
                        final msg = await ref.read(goalsNotifierProvider.notifier).completeGoal(goal.id);
                        if (msg != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Padding(padding: EdgeInsets.all(32.0), child: Center(child: CircularProgressIndicator())),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading goals: $err', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Goal'),
      ),
    );
  }
}
