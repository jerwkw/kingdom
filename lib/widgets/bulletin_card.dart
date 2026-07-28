import 'package:flutter/material.dart';
import '../models/bulletin_model.dart';
import '../config/roles_config.dart';

class BulletinCard extends StatelessWidget {
  final BulletinPost post;
  final String currentUid;
  final Function(String emoji) onReactionToggle;

  const BulletinCard({
    super.key,
    required this.post,
    required this.currentUid,
    required this.onReactionToggle,
  });

  @override
  Widget build(BuildContext context) {
    final role = RolesConfig.getRoleById(post.authorRole);

    Color badgeColor;
    String typeLabel;
    switch (post.type) {
      case BulletinType.thanksgiving:
        badgeColor = Colors.orange;
        typeLabel = '🙌 THANKSGIVING';
        break;
      case BulletinType.sharing:
        badgeColor = Colors.teal;
        typeLabel = '📖 SHARING';
        break;
      default:
        badgeColor = Colors.indigo;
        typeLabel = '🙏 PRAYER REQUEST';
    }

    // Aggregate reaction counts
    final reactionCounts = <String, int>{};
    post.reactions.forEach((uid, emoji) {
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    });

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author & Type Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: role.color.withOpacity(0.2),
                  child: Text(role.emoji, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      role.title,
                      style: TextStyle(fontSize: 12, color: role.color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Post Text
            Text(
              post.text,
              style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
            ),
            const SizedBox(height: 14),

            // Reactions Bar
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ...reactionCounts.entries.map((e) {
                  final emoji = e.key;
                  final count = e.value;
                  final hasReacted = post.reactions[currentUid] == emoji;

                  return ChoiceChip(
                    label: Text('$emoji $count'),
                    selected: hasReacted,
                    selectedColor: badgeColor.withOpacity(0.3),
                    onSelected: (_) => onReactionToggle(emoji),
                  );
                }),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add_reaction_outlined, size: 20, color: Colors.grey),
                  onSelected: onReactionToggle,
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: '❤️', child: Text('❤️ Amen')),
                    const PopupMenuItem(value: '🙏', child: Text('🙏 Praying')),
                    const PopupMenuItem(value: '🙌', child: Text('🙌 Praise')),
                    const PopupMenuItem(value: '💡', child: Text('💡 Inspired')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
