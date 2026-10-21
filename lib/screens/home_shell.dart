import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/parking_provider.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_bottom_nav_bar.dart';
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

    const navItems = [
      GlassNavItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        label: 'Dashboard',
      ),
      GlassNavItem(
        icon: Icons.add_circle_outline_rounded,
        selectedIcon: Icons.add_circle_rounded,
        label: 'Entry',
      ),
      GlassNavItem(
        icon: Icons.exit_to_app_outlined,
        selectedIcon: Icons.exit_to_app_rounded,
        label: 'Exit',
      ),
      GlassNavItem(
        icon: Icons.local_parking_outlined,
        selectedIcon: Icons.local_parking_rounded,
        label: 'Active',
      ),
      GlassNavItem(
        icon: Icons.history_outlined,
        selectedIcon: Icons.history_rounded,
        label: 'History',
      ),
    ];

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.03),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(currentIndex),
            child: screens[currentIndex],
          ),
        ),
        bottomNavigationBar: GlassBottomNavBar(
          currentIndex: currentIndex,
          items: navItems,
          onTabSelected: (index) {
            provider.setTabIndex(index);
          },
        ),
      ),
    );
  }
}

