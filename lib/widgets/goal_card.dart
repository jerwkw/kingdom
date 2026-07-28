import 'package:flutter/material.dart';
import '../models/goal_model.dart';

class GoalCard extends StatelessWidget {
  final GoalModel goal;
  final ValueChanged<bool?> onToggleComplete;

  const GoalCard({
    super.key,
    required this.goal,
    required this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmart = goal.type == GoalType.smart;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: goal.isCompletedToday ? 1 : 3,
      color: goal.isCompletedToday
          ? theme.colorScheme.surfaceVariant.withOpacity(0.5)
          : theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Completion Checkbox
            Transform.scale(
              scale: 1.2,
              child: Checkbox(
                value: goal.isCompletedToday,
                activeColor: Colors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                onChanged: goal.isCompletedToday ? null : onToggleComplete,
              ),
            ),
            const SizedBox(width: 12),

            // Goal Title & Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSmart ? Colors.purple.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSmart ? Colors.purple.shade200 : Colors.blue.shade200,
                          ),
                        ),
                        child: Text(
                          isSmart ? 'SMART Goal' : goal.frequency.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSmart ? Colors.purple.shade800 : Colors.blue.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (goal.currentStreak > 0)
                        Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 2),
                            Text(
                              '${goal.currentStreak} day streak',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSmart ? goal.text : goal.task,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: goal.isCompletedToday ? TextDecoration.lineThrough : null,
                      color: goal.isCompletedToday ? Colors.grey : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Fish Reward Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Row(
                children: [
                  Text('🐟', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 4),
                  Text(
                    '+10',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
