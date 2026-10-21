import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable, premium glassmorphism container featuring Apple visionOS/iOS
/// style backdrop blur, specular hairline border gradients, and an interactive
/// spring-scale bounce animation on press.
class GlassContainer extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Color? tintColor;
  final double opacity;
  final Border? border;
  final Gradient? gradient;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;
  final Clip clipBehavior;
  final bool interactive;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.blur = 18,
    this.tintColor,
    this.opacity = 0.65,
    this.border,
    this.gradient,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.shadows,
    this.clipBehavior = Clip.antiAlias,
    this.interactive = true,
  });

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null && widget.interactive) {
      HapticFeedback.lightImpact();
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap != null && widget.interactive) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null && widget.interactive) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBorder = widget.border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.65),
          width: 1.0,
        );

    final defaultGradient = widget.gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  (widget.tintColor ?? theme.colorScheme.surfaceContainerHighest)
                      .withValues(alpha: widget.opacity),
                  (widget.tintColor ?? theme.colorScheme.surface)
                      .withValues(alpha: (widget.opacity * 0.7).clamp(0.0, 1.0)),
                ]
              : [
                  Colors.white.withValues(alpha: (widget.opacity + 0.18).clamp(0.0, 1.0)),
                  (widget.tintColor ?? theme.colorScheme.surfaceContainerHighest)
                      .withValues(alpha: widget.opacity * 0.65),
                ],
        );

    final defaultShadows = widget.shadows ??
        [
          BoxShadow(
            color: (widget.tintColor ?? theme.colorScheme.shadow)
                .withValues(alpha: isDark ? 0.28 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.45),
            blurRadius: 2,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ];

    Widget content = Container(
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        gradient: defaultGradient,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: defaultBorder,
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: content,
      );
    }

    Widget glass = Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: defaultShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        clipBehavior: widget.clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: content,
        ),
      ),
    );

    if (widget.onTap != null && widget.interactive) {
      return AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: glass,
      );
    }

    return glass;
  }
}

