import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// Design-token-aligned button with primary and secondary variants.
///
/// **Design tokens:**
/// - Primary: bg teal-300, text white, hover teal-400
/// - Secondary: bg transparent, border teal-300, text teal-300
/// - Padding: 12px 24px, Border Radius: 8px
class PulseButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final _PulseButtonVariant _variant;
  final int flex;

  const PulseButton.primary({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.flex = 0,
  }) : _variant = _PulseButtonVariant.primary;

  const PulseButton.secondary({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.flex = 0,
  }) : _variant = _PulseButtonVariant.secondary;

  const PulseButton.outline({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.flex = 0,
  }) : _variant = _PulseButtonVariant.outline;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: double.infinity,
      height: 56,
      child: switch (_variant) {
        _PulseButtonVariant.primary => _buildPrimary(),
        _PulseButtonVariant.secondary => _buildSecondary(),
        _PulseButtonVariant.outline => _buildOutline(),
      },
    );

    if (flex > 0) {
      return Expanded(flex: flex, child: child);
    }
    return child;
  }

  Widget _buildPrimary() {
    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading ? const SizedBox.shrink() : Icon(icon, color: Colors.white),
        label: _buildLabel(Colors.white),
        style: _primaryStyle(),
      );
    }
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: _primaryStyle(),
      child: _buildLabel(Colors.white),
    );
  }

  Widget _buildSecondary() {
    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading ? const SizedBox.shrink() : Icon(icon, color: AppColors.slate900),
        label: _buildLabel(AppColors.slate900),
        style: _secondaryStyle(),
      );
    }
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: _secondaryStyle(),
      child: _buildLabel(AppColors.slate900),
    );
  }

  Widget _buildOutline() {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: const BorderSide(color: AppColors.teal),
      ),
      child: _buildLabel(AppColors.teal),
    );
  }

  Widget _buildLabel(Color textColor) {
    if (isLoading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: textColor,
          strokeWidth: 2,
        ),
      );
    }
    return Text(
      label,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );
  }

  ButtonStyle _primaryStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.teal,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.slate200,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  ButtonStyle _secondaryStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.slate900,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.slate300),
      ),
    );
  }
}

enum _PulseButtonVariant { primary, secondary, outline }
