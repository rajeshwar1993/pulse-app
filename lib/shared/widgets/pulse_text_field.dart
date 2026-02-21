import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// Design-token-aligned text input field.
///
/// **Design tokens:**
/// - Background: white, Border: 1px solid slate-300
/// - Focus border: teal-300
/// - Padding: 12px 16px, Border Radius: 8px
class PulseTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? suffixText;
  final String? counterText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const PulseTextField({
    super.key,
    this.controller,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.suffixText,
    this.counterText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
        suffixText: suffixText,
        counterText: counterText ?? '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.slate300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.slate300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.teal, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      enabled: enabled,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

/// Password text field with built-in visibility toggle.
class PulsePasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final TextInputAction? textInputAction;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  const PulsePasswordField({
    super.key,
    this.controller,
    this.hintText,
    this.textInputAction,
    this.enabled = true,
    this.onSubmitted,
  });

  @override
  State<PulsePasswordField> createState() => _PulsePasswordFieldState();
}

class _PulsePasswordFieldState extends State<PulsePasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return PulseTextField(
      controller: widget.controller,
      hintText: widget.hintText,
      prefixIcon: Icons.lock_outlined,
      suffixIcon: IconButton(
        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      enabled: widget.enabled,
      onSubmitted: widget.onSubmitted,
    );
  }
}
