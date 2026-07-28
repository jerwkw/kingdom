import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/store_config.dart';
import '../providers/auth_provider.dart';
import '../providers/store_provider.dart';
import '../widgets/avatar_renderer.dart';

class StoreTab extends ConsumerStatefulWidget {
  const StoreTab({super.key});

  @override
  ConsumerState<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends ConsumerState<StoreTab> {
  CosmeticCategory _selectedCategory = CosmeticCategory.headpiece;

  void _showFittingRoomModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final userProfile = ref.watch(userProfileProvider).value;
            final ownedItemIds = ref.watch(ownedItemIdsProvider).value ?? {};

            if (userProfile == null) return const SizedBox();

            final ownedItems = StoreConfig.catalog
                .where((item) => ownedItemIds.contains(item.id))
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Fitting Room',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  AvatarRenderer(
                    roleId: userProfile.role,
                    avatarConfig: userProfile.avatarConfig,
                    size: 110,
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Equip Owned Cosmetics',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ownedItems.isEmpty
                        ? const Center(
                            child: Text('No owned cosmetics yet. Earn fish by completing goals!'),
                          )
                        : ListView.builder(
                            itemCount: ownedItems.length,
                            itemBuilder: (context, index) {
                              final item = ownedItems[index];
                              final isEquipped = userProfile.avatarConfig[item.category.name] == item.id;

                              return ListTile(
                                leading: Text(item.emoji, style: const TextStyle(fontSize: 28)),
                                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(item.category.name.toUpperCase()),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    ref.read(storeNotifierProvider.notifier).equipItem(item);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isEquipped ? Colors.green : Colors.indigo,
                                  ),
                                  child: Text(isEquipped ? 'Equipped ✓' : 'Equip'),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider).value;
    final ownedItemIds = ref.watch(ownedItemIdsProvider).value ?? {};
    final isPurchasing = ref.watch(storeNotifierProvider).isLoading;

    final fishBalance = userProfile?.fishBalance ?? 0;
    final filteredCatalog = StoreConfig.catalog
        .where((item) => item.category == _selectedCategory)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cosmetic Store', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.checkroom),
            tooltip: 'Fitting Room',
            onPressed: () => _showFittingRoomModal(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Fish Balance Banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade700, Colors.orange.shade800],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('🐟', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fish Balance', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      '$fishBalance Fish',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showFittingRoomModal(context),
                  icon: const Icon(Icons.dry_cleaning, size: 16),
                  label: const Text('Fitting Room'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // Category Selector Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: CosmeticCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat.name.toUpperCase()),
                    selected: isSelected,
                    selectedColor: Colors.indigo,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Store Catalog Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: filteredCatalog.length,
              itemBuilder: (context, index) {
                final item = filteredCatalog[index];
                final isOwned = ownedItemIds.contains(item.id);

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item.emoji, style: const TextStyle(fontSize: 48)),
                        const SizedBox(height: 8),
                        Text(
                          item.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.cost} 🐟',
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (isOwned || isPurchasing)
                                ? null
                                : () async {
                                    final err = await ref
                                        .read(storeNotifierProvider.notifier)
                                        .purchaseItem(item);
                                    if (context.mounted) {
                                      if (err != null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(content: Text(err)));
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Purchased ${item.name}!')),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isOwned ? Colors.grey : Colors.indigo,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              isOwned ? 'Owned' : 'Buy Item',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
