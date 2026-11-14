import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Tombol utama full-width. Jika [onPressed] null, tombol tampil disabled
/// (opacity 50%).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.primary,
    this.verticalPadding = 16,
    this.fontSize = 16,
    this.radius = 12,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double verticalPadding;
  final double fontSize;
  final double radius;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white,
        elevation: onPressed == null ? 0 : 4,
        shadowColor: color.withValues(alpha: 0.4),
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding,
          horizontal: 20,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        textStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Text(label),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
