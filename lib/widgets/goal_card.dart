import 'package:flutter/material.dart';
import '../models/goal_model.dart';

enum GoalAction { edit, share, archive, restore, delete }

class GoalCard extends StatelessWidget {
  final GoalModel goal;
  final VoidCallback onComplete;

  /// True while the completion request is in flight: the checkbox is
  /// replaced by a spinner and further taps are ignored.
  final bool isPending;

  /// Message from a failed completion request, shown with a retry hint.
  final String? errorText;
  final ValueChanged<GoalAction>? onAction;

  const GoalCard({
    super.key,
    required this.goal,
    required this.onComplete,
    this.isPending = false,
    this.errorText,
    this.onAction,
  });

  String get _streakUnit => switch (goal.frequency) {
    GoalFrequency.daily => 'day',
    GoalFrequency.weekly => 'week',
    GoalFrequency.monthly => 'month',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmart = goal.type == GoalType.smart;
    final done = goal.isCompletedToday;
    final canComplete = !done && !isPending && !goal.archived;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: done || goal.archived ? 1 : 3,
      color: done || goal.archived
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: [
            // Completion control
            SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: isPending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          semanticsLabel: 'Completing goal',
                        ),
                      )
                    : Transform.scale(
                        scale: 1.2,
                        child: Checkbox(
                          value: done,
                          activeColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          semanticLabel: done
                              ? '${goal.displayText}, completed'
                              : 'Complete ${goal.displayText}',
                          onChanged: canComplete ? (_) => onComplete() : null,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),

            // Goal Title & Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Tag(
                        label: isSmart
                            ? 'SMART · ${goal.frequency.name.toUpperCase()}'
                            : goal.frequency.name.toUpperCase(),
                        color: isSmart ? Colors.purple : Colors.blue,
                      ),
                      if (goal.archived)
                        const _Tag(label: 'ARCHIVED', color: Colors.grey),
                      if (goal.currentStreak > 0)
                        Text(
                          '🔥 ${goal.currentStreak} $_streakUnit streak',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    goal.displayText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? Colors.grey : Colors.black87,
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$errorText Tap the box to try again.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Fish Reward Badge
            if (!goal.archived)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Text(
                  done ? '✓ 🐟' : '🐟 +10',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),

            if (onAction != null)
              PopupMenuButton<GoalAction>(
                tooltip: 'Goal options',
                onSelected: onAction,
                itemBuilder: (_) => [
                  if (!goal.archived) ...[
                    const PopupMenuItem(
                      value: GoalAction.edit,
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem(
                      value: GoalAction.share,
                      child: Text('Share to bulletin…'),
                    ),
                    const PopupMenuItem(
                      value: GoalAction.archive,
                      child: Text('Archive'),
                    ),
                  ] else
                    const PopupMenuItem(
                      value: GoalAction.restore,
                      child: Text('Restore'),
                    ),
                  const PopupMenuItem(
                    value: GoalAction.delete,
                    child: Text('Delete'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final MaterialColor color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color.shade800,
        ),
      ),
    );
  }
}
