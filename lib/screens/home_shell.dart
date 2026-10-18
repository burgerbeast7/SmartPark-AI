import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/parking_provider.dart';
import 'active_screen.dart';
import 'dashboard_screen.dart';
import 'entry_screen.dart';
import 'exit_screen.dart';
import 'history_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParkingProvider>();
    final currentIndex = provider.currentTabIndex;

    final screens = const [
      DashboardScreen(),
      EntryScreen(),
      ExitScreen(),
      ActiveScreen(),
      HistoryScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          provider.setTabIndex(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: 'Entry',
          ),
          NavigationDestination(
            icon: Icon(Icons.exit_to_app_outlined),
            selectedIcon: Icon(Icons.exit_to_app_rounded),
            label: 'Exit',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_parking_outlined),
            selectedIcon: Icon(Icons.local_parking_rounded),
            label: 'Active',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
