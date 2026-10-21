import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bulletin_model.dart';

const _reactionLabels = {
  '❤️': 'Amen',
  '🙏': 'Praying',
  '🙌': 'Praise',
  '💡': 'Inspired',
};

class BulletinCard extends StatelessWidget {
  final BulletinPost post;
  final String currentUid;
  final Function(String emoji) onReactionToggle;

  /// Shown only on the current user's own posts.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const BulletinCard({
    super.key,
    required this.post,
    required this.currentUid,
    required this.onReactionToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
                  backgroundColor: badgeColor.withValues(alpha: 0.15),
                  child: Icon(Icons.person, color: badgeColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (post.createdAt != null)
                        Text(
                          '${DateFormat('d MMM, h:mm a').format(post.createdAt!.toLocal())}'
                          '${post.isEdited ? ' · edited' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
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
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    tooltip: 'Post options',
                    onSelected: (value) =>
                        value == 'edit' ? onEdit?.call() : onDelete?.call(),
                    itemBuilder: (_) => [
                      if (onEdit != null)
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Post Text
            Text(
              post.text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Colors.black87,
              ),
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
                    selectedColor: badgeColor.withValues(alpha: 0.3),
                    onSelected: (_) => onReactionToggle(emoji),
                  );
                }),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.add_reaction_outlined,
                    size: 20,
                    color: Colors.grey,
                  ),
                  onSelected: onReactionToggle,
                  tooltip: 'Add reaction',
                  itemBuilder: (context) => [
                    for (final emoji in BulletinPost.allowedReactions)
                      PopupMenuItem(
                        value: emoji,
                        child: Text('$emoji ${_reactionLabels[emoji]}'),
                      ),
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
