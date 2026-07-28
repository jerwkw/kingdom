import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/building_provider.dart';
import '../models/building_model.dart';
import '../config/roles_config.dart';
import '../widgets/avatar_renderer.dart';
import '../widgets/create_building_dialog.dart';
import 'bulletin_board_screen.dart';

class NeighbourhoodTab extends ConsumerWidget {
  const NeighbourhoodTab({super.key});

  void _showCreateBuildingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const CreateBuildingDialog(),
    );
  }

  void _showJoinBuildingDialog(BuildContext context, WidgetRef ref) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Join Neighbourhood Guild'),
        content: TextField(
          controller: codeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Invite Code',
            hintText: 'e.g. GUILD2026',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.vpn_key),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                final err = await ref
                    .read(buildingNotifierProvider.notifier)
                    .joinBuilding(code);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  if (err != null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err)));
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('📩 Join request submitted! Waiting for admin approval.'),
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveBuilding(BuildContext context, WidgetRef ref, BuildingModel building) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Neighbourhood?'),
        content: Text('Are you sure you want to leave "${building.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await ref
                  .read(buildingNotifierProvider.notifier)
                  .leaveBuilding(building.id);
              if (context.mounted && err != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final user = userProfileAsync.value;
    final buildingDocAsync = ref.watch(currentBuildingDocProvider);
    final memberStatsAsync = ref.watch(buildingMemberStatsProvider);

    final hasBuilding = user != null && user.buildingId != null && user.buildingId!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Neighbourhood Guild', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (hasBuilding) ...[
            IconButton(
              icon: const Icon(Icons.forum_outlined),
              tooltip: 'Bulletin Board',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BulletinBoardScreen()),
                );
              },
            ),
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'leave') {
                  final building = buildingDocAsync.value;
                  if (building != null) {
                    _confirmLeaveBuilding(context, ref, building);
                  }
                } else if (val == 'join') {
                  _showJoinBuildingDialog(context, ref);
                } else if (val == 'create') {
                  _showCreateBuildingDialog(context);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'create',
                  child: Row(
                    children: [
                      Icon(Icons.add_business, color: Colors.teal),
                      SizedBox(width: 8),
                      Text('Create New Guild'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'join',
                  child: Row(
                    children: [
                      Icon(Icons.group_add, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Join Another Guild'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Leave Current Guild'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: !hasBuilding
          ? _buildEmptyState(context, ref)
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Building Header & Shared Expansion Fund
                  buildingDocAsync.when(
                    data: (building) {
                      if (building == null) {
                        return const SizedBox();
                      }

                      final groupFund = building.groupFund;
                      const expansionTarget = 500;
                      final progress = (groupFund / expansionTarget).clamp(0.0, 1.0);
                      final isUserAdmin = building.isAdmin(user.uid);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.teal.shade700, Colors.green.shade900],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('🏰', style: TextStyle(fontSize: 32)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            building.name,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (building.description.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              building.description,
                                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white24,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Invite Code: ${building.inviteCode}',
                                              style: const TextStyle(
                                                color: Colors.amberAccent,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const BulletinBoardScreen()),
                                        );
                                      },
                                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                      label: const Text('Bulletin'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.teal.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Group Expansion Progress
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      '🌳 Community Playground Expansion',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    Text(
                                      '$groupFund / $expansionTarget 🐟',
                                      style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 10,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Pending Join Requests (Admin Only)
                          if (isUserAdmin && building.pendingJoinRequests.isNotEmpty) ...[
                            _buildPendingRequestsSection(context, ref, building),
                          ],
                        ],
                      );
                    },
                    loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error loading building: $err', style: const TextStyle(color: Colors.red)),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Guild Members & Consistency',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // Members List
                  memberStatsAsync.when(
                    data: (members) {
                      final building = buildingDocAsync.value;
                      if (members.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(child: Text('No members found in neighbourhood.')),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final role = RolesConfig.getRoleById(member.role);
                          final isLeader = building != null && building.isLeader(member.uid);
                          final isAdmin = building != null && building.isAdmin(member.uid);
                          final isCurrentUserLeader = building != null && building.isLeader(user.uid);

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  AvatarRenderer(
                                    roleId: member.role,
                                    avatarConfig: member.avatarConfig,
                                    size: 54,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              member.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                            const SizedBox(width: 6),
                                            if (isLeader) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade100,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text('👑 Leader', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                                              ),
                                            ] else if (isAdmin) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text('⭐ Admin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(role.emoji, style: const TextStyle(fontSize: 12)),
                                            const SizedBox(width: 4),
                                            Text(
                                              role.title,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: role.color,
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Promote to Admin option for Leader
                                        if (isCurrentUserLeader && !isAdmin && member.uid != user.uid) ...[
                                          TextButton.icon(
                                            onPressed: () async {
                                              final err = await ref
                                                  .read(buildingNotifierProvider.notifier)
                                                  .promoteAdmin(building.id, member.uid);
                                              if (context.mounted && err != null) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                              }
                                            },
                                            icon: const Icon(Icons.star_outline, size: 14),
                                            label: const Text('Promote to Admin', style: TextStyle(fontSize: 11)),
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(50, 24),
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Aggregated Completion Rate Gauge
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${member.completionPercent}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: member.completionPercent >= 80
                                              ? Colors.green.shade700
                                              : Colors.amber.shade800,
                                        ),
                                      ),
                                      const Text(
                                        '7-day consistency',
                                        style: TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error loading member stats: $err', style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              shape: BoxShape.circle,
            ),
            child: const Text('🏰', style: TextStyle(fontSize: 64)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Welcome to Neighbourhood Guilds',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Join a cell group guild or start your own! Share spiritual goals, encourage each other on the bulletin board, and build community together.',
            style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showCreateBuildingDialog(context),
              icon: const Icon(Icons.add_business),
              label: const Text('Create a Neighbourhood', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _showJoinBuildingDialog(context, ref),
              icon: const Icon(Icons.vpn_key),
              label: const Text('Join with Invite Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal.shade800,
                side: BorderSide(color: Colors.teal.shade700, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsSection(BuildContext context, WidgetRef ref, BuildingModel building) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.amber.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pending_actions, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Pending Join Requests (${building.pendingJoinRequests.length})',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber.shade900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...building.pendingJoinRequests.map((req) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    AvatarRenderer(
                      roleId: 'gardener',
                      avatarConfig: req.avatarConfig,
                      size: 38,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        req.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                      tooltip: 'Approve',
                      onPressed: () async {
                        final err = await ref
                            .read(buildingNotifierProvider.notifier)
                            .approveJoinRequest(building.id, req.uid);
                        if (context.mounted && err != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                      tooltip: 'Reject',
                      onPressed: () async {
                        final err = await ref
                            .read(buildingNotifierProvider.notifier)
                            .rejectJoinRequest(building.id, req.uid);
                        if (context.mounted && err != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        }
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
