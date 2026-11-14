import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Logo besar Operin (ikon daun + nama) untuk halaman Login & Signup.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Icon(Icons.eco, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 12),
        const Text(
          'Operin',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}
