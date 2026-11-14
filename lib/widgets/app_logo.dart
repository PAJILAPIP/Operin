import 'package:flutter/material.dart';

/// Logo Operin (gambar sudah memuat tulisan "Operin") untuk halaman splash,
/// login, dan daftar.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 132});

  static const String asset = 'assets/images/logo.png';

  /// Tinggi logo.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Operin',
    );
  }
}
