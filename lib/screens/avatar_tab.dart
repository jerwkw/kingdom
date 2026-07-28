import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/roles_config.dart';
import '../providers/auth_provider.dart';
import '../widgets/avatar_renderer.dart';

class AvatarTab extends ConsumerWidget {
  const AvatarTab({super.key});

  void _showServerConfigDialog(BuildContext context, WidgetRef ref) {
    final currentUrl = ref.read(backendBaseUrlProvider);
    final urlController = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend API Connection URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Default is "/api" (Firebase Cloud Functions via Hosting rewrite). You can set custom URL for testing.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Backend Base URL',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(backendBaseUrlProvider.notifier).state = urlController.text.trim();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backend URL updated!')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Identity & Role', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.dns),
            tooltip: 'Server Settings',
            onPressed: () => _showServerConfigDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      body: userProfileAsync.when(
        data: (userProfile) {
          if (userProfile == null) return const Center(child: CircularProgressIndicator());

          final role = RolesConfig.getRoleById(userProfile.role);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar Visual Representation
                AvatarRenderer(
                  roleId: userProfile.role,
                  avatarConfig: userProfile.avatarConfig,
                  size: 130,
                ),
                const SizedBox(height: 16),

                // Name & Role
                Text(
                  userProfile.name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: role.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: role.color.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(role.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        role.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: role.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    role.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                  ),
                ),
                const SizedBox(height: 32),

                // Spiritual Badges Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Spiritual Milestone Badges',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildBadgeCard('📖', 'Word Faithful', '7-day Bible Habit', Colors.amber),
                    _buildBadgeCard('🕊️', 'Prayer Warrior', '14 Daily Prayers', Colors.blue),
                    _buildBadgeCard('🏰', 'Pillar of Building', '50 Group Contributions', Colors.green),
                  ],
                ),

                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => _showServerConfigDialog(context, ref),
                  icon: const Icon(Icons.settings),
                  label: const Text('Configure Pi Server Connection'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildBadgeCard(String emoji, String title, String subtitle, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color.withOpacity(0.9)),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
