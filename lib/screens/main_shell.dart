import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/building_provider.dart';
import '../providers/navigation_provider.dart';
import 'avatar_tab.dart';
import 'neighbourhood_tab.dart';
import 'tasks_tab.dart';
import 'store_tab.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const List<Widget> _tabs = [
    AvatarTab(),
    NeighbourhoodTab(),
    TasksTab(),
    StoreTab(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(shellTabProvider).index;
    void select(int idx) =>
        ref.read(shellTabProvider.notifier).state = ShellTab.values[idx];
    final mediaWidth = MediaQuery.of(context).size.width;
    final isWideScreen = mediaWidth >= 700;
    final buildingDocAsync = ref.watch(currentBuildingDocProvider);
    final pendingCount =
        buildingDocAsync.value?.pendingJoinRequests.length ?? 0;

    Widget neighbourhoodIcon = pendingCount > 0
        ? Badge(
            label: Text('$pendingCount'),
            child: const Icon(Icons.location_city_outlined),
          )
        : const Icon(Icons.location_city_outlined);

    Widget selectedNeighbourhoodIcon = pendingCount > 0
        ? Badge(
            label: Text('$pendingCount'),
            child: const Icon(Icons.location_city),
          )
        : const Icon(Icons.location_city);

    if (isWideScreen) {
      // Desktop / Web Side Rail Layout
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('🏰', style: TextStyle(fontSize: 32)),
              ),
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Avatar'),
                ),
                NavigationRailDestination(
                  icon: neighbourhoodIcon,
                  selectedIcon: selectedNeighbourhoodIcon,
                  label: const Text('Neighbourhood'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.task_alt_outlined),
                  selectedIcon: Icon(Icons.task_alt),
                  label: Text('Tasks'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: Text('Store'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _tabs[currentIndex]),
          ],
        ),
      );
    }

    // Mobile Bottom Navigation Bar Layout
    return Scaffold(
      body: _tabs[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: select,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Avatar',
          ),
          NavigationDestination(
            icon: neighbourhoodIcon,
            selectedIcon: selectedNeighbourhoodIcon,
            label: 'Neighbourhood',
          ),
          const NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Tasks',
          ),
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Store',
          ),
        ],
      ),
    );
  }
}
