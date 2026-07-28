import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bulletin_model.dart';
import '../providers/auth_provider.dart';
import '../providers/bulletin_provider.dart';
import '../widgets/bulletin_card.dart';

class BulletinBoardScreen extends ConsumerWidget {
  const BulletinBoardScreen({super.key});

  void _showNewPostDialog(BuildContext context, WidgetRef ref) {
    BulletinType selectedType = BulletinType.prayer;
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Post to Bulletin Board'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<BulletinType>(
                    segments: const [
                      ButtonSegment(value: BulletinType.prayer, label: Text('Prayer')),
                      ButtonSegment(value: BulletinType.thanksgiving, label: Text('Thanks')),
                      ButtonSegment(value: BulletinType.sharing, label: Text('Sharing')),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (val) => setState(() => selectedType = val.first),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Share a prayer request, praise item, or reflection...',
                      border: OutlineInputBorder(),
                    ),
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
                onPressed: () {
                  if (textController.text.trim().isNotEmpty) {
                    ref.read(bulletinNotifierProvider.notifier).createPost(
                          type: selectedType,
                          text: textController.text,
                        );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Post'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(buildingBulletinPostsProvider);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cell Group Bulletin Board', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      onPressed: () => _showNewPostDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Create First Post'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return BulletinCard(
                post: post,
                currentUid: user?.uid ?? '',
                onReactionToggle: (emoji) {
                  ref.read(bulletinNotifierProvider.notifier).toggleReaction(post.id, emoji);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewPostDialog(context, ref),
        icon: const Icon(Icons.add_comment),
        label: const Text('New Post'),
      ),
    );
  }
}
