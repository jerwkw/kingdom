import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/limits.dart';
import '../models/bulletin_model.dart';
import '../providers/auth_provider.dart';
import '../providers/bulletin_provider.dart';
import '../widgets/bulletin_card.dart';

/// Shown wherever members write posts.
const bulletinPrivacyNote =
    'Posts are visible to everyone in your neighbourhood. Please don\'t share '
    'someone else\'s private details (health, family or personal struggles) '
    'without their permission.';

class BulletinBoardScreen extends ConsumerWidget {
  const BulletinBoardScreen({super.key});

  void _showPostDialog(
    BuildContext context,
    WidgetRef ref, {
    BulletinPost? existing,
  }) {
    BulletinType selectedType = existing?.type ?? BulletinType.prayer;
    final textController = TextEditingController(text: existing?.text ?? '');
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              existing == null ? 'Post to Bulletin Board' : 'Edit Post',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (existing == null) ...[
                    SegmentedButton<BulletinType>(
                      segments: const [
                        ButtonSegment(
                          value: BulletinType.prayer,
                          label: Text('Prayer'),
                        ),
                        ButtonSegment(
                          value: BulletinType.thanksgiving,
                          label: Text('Thanks'),
                        ),
                        ButtonSegment(
                          value: BulletinType.sharing,
                          label: Text('Sharing'),
                        ),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (val) =>
                          setState(() => selectedType = val.first),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    maxLength: TextLimits.bulletinText,
                    decoration: const InputDecoration(
                      hintText:
                          'Share a prayer request, praise item, or reflection...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Text(
                    bulletinPrivacyNote,
                    style: TextStyle(fontSize: 11, color: Colors.black54),
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
                onPressed: submitting
                    ? null
                    : () async {
                        final text = textController.text.trim();
                        if (text.isEmpty) return;
                        setState(() => submitting = true);
                        final notifier = ref.read(
                          bulletinNotifierProvider.notifier,
                        );
                        String? err;
                        if (existing == null) {
                          err = await notifier.createPost(
                            type: selectedType,
                            text: text,
                          );
                        } else {
                          try {
                            await notifier.editPost(existing.id, text);
                          } catch (_) {
                            err = 'Could not save your edit. Please try again.';
                          }
                        }
                        if (!ctx.mounted) return;
                        if (err != null) {
                          setState(() => submitting = false);
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text(err)));
                        } else {
                          Navigator.pop(ctx);
                        }
                      },
                child: Text(existing == null ? 'Post' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, BulletinPost post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text(
          'This removes the post and its reactions for everyone.',
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
              ref.read(bulletinNotifierProvider.notifier).deletePost(post.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(buildingBulletinPostsProvider);
    final limit = ref.watch(bulletinPostLimitProvider);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cell Group Bulletin Board',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: postsAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('📌', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text(
                      'No bulletin posts yet.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showPostDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Create First Post'),
                    ),
                  ],
                ),
              ),
            );
          }

          // A full page suggests more posts may exist.
          final mayHaveMore = posts.length >= limit;
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            itemCount: posts.length + (mayHaveMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == posts.length) {
                return Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.read(bulletinPostLimitProvider.notifier).state +=
                            bulletinPageSize,
                    child: const Text('Load older posts'),
                  ),
                );
              }
              final post = posts[index];
              final isMine = user != null && post.userId == user.uid;
              return BulletinCard(
                post: post,
                currentUid: user?.uid ?? '',
                onReactionToggle: (emoji) {
                  ref
                      .read(bulletinNotifierProvider.notifier)
                      .toggleReaction(post.id, emoji);
                },
                onEdit: isMine
                    ? () => _showPostDialog(context, ref, existing: post)
                    : null,
                onDelete: isMine
                    ? () => _confirmDelete(context, ref, post)
                    : null,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPostDialog(context, ref),
        icon: const Icon(Icons.add_comment),
        label: const Text('New Post'),
      ),
    );
  }
}
