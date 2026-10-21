import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Renders a subtle, high-end ambient mesh gradient behind screens
/// so that frosted glass containers have rich depth, refraction, and vibrance.
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        // Base solid background
        Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          ),
        ),

        // Top-left primary ambient glow (Teal/Emerald)
        Positioned(
          top: -80,
          left: -60,
          width: 320,
          height: 320,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppConstants.primarySeedColor.withValues(alpha: isDark ? 0.22 : 0.16),
                  AppConstants.primarySeedColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // Mid-right cyan/sky ambient glow
        Positioned(
          top: 220,
          right: -80,
          width: 280,
          height: 280,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.18 : 0.12),
                  const Color(0xFF0EA5E9).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // Bottom-left violet/indigo subtle glow
        Positioned(
          bottom: 40,
          left: -40,
          width: 260,
          height: 260,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: isDark ? 0.12 : 0.08),
                  const Color(0xFF6366F1).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // Foreground content
        Positioned.fill(child: child),
      ],
    );
  }
}
