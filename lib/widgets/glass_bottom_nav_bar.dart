import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import 'glass_container.dart';

class GlassNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const GlassNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// A floating, frosted glass bottom navigation bar with Apple-style animated
/// capsule indicators, tactile haptic feedback, and smooth spring micro-interactions.
class GlassBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final List<GlassNavItem> items;

  const GlassBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16.0,
        0,
        16.0,
        MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 4
            : 16.0,
      ),
      child: GlassContainer(
        borderRadius: 30,
        blur: 24,
        opacity: isDark ? 0.75 : 0.82,
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = index == currentIndex;

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!isSelected) {
                    HapticFeedback.selectionClick();
                    onTabSelected(index);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppConstants.primarySeedColor.withValues(
                                alpha: isDark ? 0.32 : 0.18,
                              ),
                              const Color(0xFF0EA5E9).withValues(
                                alpha: isDark ? 0.20 : 0.10,
                              ),
                            ],
                          )
                        : null,
                    border: isSelected
                        ? Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.16)
                                : Colors.white.withValues(alpha: 0.8),
                            width: 1.0,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppConstants.primarySeedColor.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        scale: isSelected ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          color: isSelected
                              ? AppConstants.primarySeedColor
                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          letterSpacing: -0.2,
                          color: isSelected
                              ? AppConstants.primarySeedColor
                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

