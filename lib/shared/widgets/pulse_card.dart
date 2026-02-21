import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// Standard card following design tokens.
///
/// **Design tokens:**
/// - Background: white, Border: 1px solid slate-200
/// - Border Radius: 12px, Padding: 24px
/// - Shadow: md (0 4px 6px rgba(0,0,0,0.1))
class PulseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const PulseCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Glassmorphism card following design tokens.
///
/// **Design tokens:**
/// - Background: rgba(255, 255, 255, 0.1)
/// - Backdrop blur: 16px
/// - Border: 1px solid rgba(255, 255, 255, 0.2)
/// - Border Radius: 16px, Padding: 24px
/// - Shadow: glass (0 8px 32px rgba(31, 38, 135, 0.15))
class PulseGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const PulseGlassCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x261F2687),
                blurRadius: 32,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
