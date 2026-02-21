import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// Banner for displaying error messages.
///
/// **Design tokens:**
/// - Background: error at 10% alpha
/// - Border: error color, radius 8px
/// - Icon: error_outline
class PulseErrorBanner extends StatelessWidget {
  final String message;

  const PulseErrorBanner({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
