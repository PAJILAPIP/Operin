import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/primary_button.dart';

/// Dialog peta dummy untuk memilih lokasi usaha.
///
/// Mengembalikan alamat (String) saat pengguna menekan "Konfirmasi Lokasi",
/// atau null jika ditutup.
class MapPickerDialog extends StatelessWidget {
  const MapPickerDialog({super.key});

  static const String _fullAddress =
      'Jl. Jend. Sudirman No. 123, Padang Barat, Kota Padang, Sumatera Barat 25114';

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const MapPickerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pin Lokasi Usaha',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close,
                        size: 20, color: AppColors.muted),
                  ),
                ],
              ),
            ),

            // Area peta dummy
            const _DummyMap(),

            // Alamat + tombol konfirmasi
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 20, color: AppColors.mutedLight),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _fullAddress,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Konfirmasi Lokasi',
                    verticalPadding: 14,
                    onPressed: () => Navigator.of(context).pop(_fullAddress),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DummyMap extends StatelessWidget {
  const _DummyMap();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 256,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DotGridPainter()),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Text(
                'Geser peta untuk menentukan titik',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              ),
            ),
          ),
          const Center(child: _BouncingPin()),
        ],
      ),
    );
  }
}

class _BouncingPin extends StatefulWidget {
  const _BouncingPin();

  @override
  State<_BouncingPin> createState() => _BouncingPinState();
}

class _BouncingPinState extends State<_BouncingPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat(reverse: true);

  late final Animation<double> _offset = Tween<double>(begin: 0, end: -12)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _offset,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _offset.value),
              child: child,
            ),
            child: const Icon(
              Icons.location_on,
              size: 48,
              color: AppColors.warning,
              shadows: [
                Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
          ),
          Container(
            width: 16,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.all(Radius.elliptical(16, 4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.divider,
    );
    final dot = Paint()..color = AppColors.border;
    const spacing = 24.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
