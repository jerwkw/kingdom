import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../providers/navigation_provider.dart';
import '../providers/notifications_provider.dart';
import 'guild_achievements_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static final _dateFormat = DateFormat('d MMM, h:mm a');

  void _open(BuildContext context, WidgetRef ref, AppNotification n) {
    ref.read(notificationsNotifierProvider).markRead(n);
    if (n.target == NotificationTarget.none) return;

    ref.read(shellTabProvider.notifier).state = ShellTab.neighbourhood;
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    if (n.target == NotificationTarget.achievements) {
      navigator.push(
        MaterialPageRoute(builder: (_) => const GuildAchievementsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => ref
                  .read(notificationsNotifierProvider)
                  .markAllRead(notificationsAsync.value ?? const []),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('Could not load notifications: $err')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🔔', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 12),
                    Text(
                      'No notifications yet.\nGuild activity like join requests, deposits and achievements will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final n = notifications[index];
              return ListTile(
                tileColor: n.isRead ? null : Colors.indigo.shade50,
                leading: Text(n.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(
                  n.text,
                  style: TextStyle(
                    fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  n.createdAt == null
                      ? 'Just now'
                      : _dateFormat.format(n.createdAt!.toLocal()),
                ),
                trailing: n.isRead
                    ? null
                    : const Icon(
                        Icons.circle,
                        size: 10,
                        color: Colors.indigo,
                        semanticLabel: 'Unread',
                      ),
                onTap: () => _open(context, ref, n),
              );
            },
          );
        },
      ),
    );
  }
}
