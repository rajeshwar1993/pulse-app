import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// Network-loaded avatar with loading and error states.
///
/// Use [PulseAvatar.selectable] for gallery-style selection.
class PulseAvatar extends StatelessWidget {
  final String imageUrl;
  final double size;
  final double borderRadius;
  final bool selected;
  final VoidCallback? onTap;

  const PulseAvatar({
    super.key,
    required this.imageUrl,
    this.size = 64,
    this.borderRadius = 12,
    this.selected = false,
    this.onTap,
  });

  /// Gallery-style selectable avatar (smaller, with selection border).
  const PulseAvatar.selectable({
    super.key,
    required this.imageUrl,
    required this.selected,
    this.onTap,
    this.size = 64,
  }) : borderRadius = 12;

  /// Large preview avatar (120px, prominent border).
  const PulseAvatar.preview({
    super.key,
    required this.imageUrl,
  })  : size = 120,
        borderRadius = 16,
        selected = true,
        onTap = null;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(
          color: selected ? AppColors.teal : AppColors.slate200,
          width: selected ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 2),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.error_outline, size: 24),
            );
          },
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}
