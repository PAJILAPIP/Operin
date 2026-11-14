import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Judul seksi huruf kapital kecil, opsional dengan widget di kanan.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppColors.text.withValues(alpha: 0.8),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: trailing == null
          ? title
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Flexible(child: title), trailing!],
            ),
    );
  }
}
