import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/scan_service.dart';
import '../../../model/scan_result.dart';
import '../../../widgets/app_card.dart';
import '../../scanner/scan_image_service.dart';
import '../../scanner/scanner_scope.dart';
import '../../scanner/widgets/scanned_item_card.dart';
import '../../stock/stock_controller.dart';

/// Tab "Scan AI": foto bahan baku → AI (Groq/Grok) menilai grade kualitas, kesegaran,
/// dan tanggal kedaluwarsa → hasil bisa langsung dicatat sebagai stok.
class ScanTab extends StatefulWidget {
  const ScanTab({super.key});

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> {
  static const _supportedTypes = {'image/jpeg', 'image/jpg', 'image/png'};

  PickedImage? _image;
  ScanResult? _result;
  String? _error;
  bool _isAnalyzing = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Alur izin kamera: jelaskan dulu → minta izin sistem → jika ditolak
  /// permanen, arahkan ke Pengaturan.
  Future<void> _takePhoto() async {
    final images = ScannerScope.of(context).imageService;
    var access = await images.cameraStatus();
    if (!mounted) return;

    if (access == CameraAccess.unsupported) {
      return _showMessage(
        'Kamera tidak tersedia di perangkat ini. Gunakan Galeri.',
      );
    }
    if (access == CameraAccess.denied) {
      final allow = await _showCameraRationale();
      if (allow != true || !mounted) return;
      access = await images.requestCamera();
      if (!mounted) return;
    }
    if (access == CameraAccess.permanentlyDenied) {
      final open = await _showOpenSettings();
      if (open == true) await images.openSettings();
      return;
    }
    if (access == CameraAccess.granted) {
      await _pickAndAnalyze(ScanImageSource.camera);
    } else {
      _showMessage('Izin kamera ditolak. Anda masih bisa memakai Galeri.');
    }
  }

  Future<bool?> _showCameraRationale() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
      title: const Text('Izinkan akses kamera'),
      content: const Text(
        'Operin memakai kamera untuk memotret bahan baku, lalu AI menilai '
        'kualitas dan membaca tanggal kedaluwarsanya. Foto hanya dikirim '
        'untuk dianalisis.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Nanti'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Izinkan'),
        ),
      ],
    ),
  );

  Future<bool?> _showOpenSettings() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.no_photography_outlined, color: AppColors.warning),
      title: const Text('Akses kamera diblokir'),
      content: const Text(
        'Izin kamera sudah ditolak. Aktifkan lewat Pengaturan aplikasi > '
        'Izin > Kamera, atau pilih foto dari Galeri.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Buka Pengaturan'),
        ),
      ],
    ),
  );

  Future<void> _pickAndAnalyze(ScanImageSource source) async {
    final images = ScannerScope.of(context).imageService;

    final PickedImage? image;
    try {
      image = await images.pick(source);
    } catch (error) {
      debugPrint('Gagal mengambil foto: $error');
      _showMessage('Gagal membuka ${source == ScanImageSource.camera ? 'kamera' : 'galeri'}.');
      return;
    }
    if (image == null || !mounted) return;
    if (!_supportedTypes.contains(image.mimeType.toLowerCase())) {
      return _showMessage('Format foto tidak didukung. Gunakan JPG atau PNG.');
    }

    setState(() => _image = image);
    await _analyze(image);
  }

  Future<void> _analyze(PickedImage image) async {
    final scope = ScannerScope.of(context);
    final today = StockScope.read(context).now;
    setState(() {
      _result = null;
      _error = null;
      _isAnalyzing = true;
    });

    try {
      final result = await scope.scanService.analyze(
        image.bytes,
        mimeType: image.mimeType,
        today: today,
      );
      if (mounted) setState(() => _result = result);
    } on ScanException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      debugPrint('Scan AI gagal: $error');
      if (mounted) {
        setState(() => _error = 'Terjadi kesalahan saat menganalisis foto.');
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _reset() => setState(() {
    _image = null;
    _result = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final configured = ScannerScope.of(context).scanService.isConfigured;
    final result = _result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'AI Quality Scanner',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ),
            if (_image != null && !_isAnalyzing)
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Scan Ulang'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Foto buah, sayur, atau bahan kemasan. AI menilai grade kualitas '
          'dan tanggal kedaluwarsa.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        if (!configured) ...[
          const SizedBox(height: 12),
          const _NotConfiguredBanner(),
        ],
        const SizedBox(height: 16),
        _Preview(image: _image, isAnalyzing: _isAnalyzing),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _takePhoto,
                icon: const Icon(Icons.photo_camera_outlined, size: 20),
                label: const Text('Ambil Foto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isAnalyzing
                    ? null
                    : () => _pickAndAnalyze(ScanImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('Galeri'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorCard(
            message: _error!,
            onRetry: _image == null || _isAnalyzing
                ? null
                : () => _analyze(_image!),
          ),
        ],
        if (result != null) ...[
          const SizedBox(height: 20),
          ..._buildResult(result),
        ],
      ],
    );
  }

  List<Widget> _buildResult(ScanResult result) {
    if (!result.isFood || result.items.isEmpty) {
      return [
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.image_search,
                  size: 36, color: AppColors.mutedLight),
              const SizedBox(height: 8),
              const Text(
                'Tidak ada bahan makanan terdeteksi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                result.summary ??
                    'Coba foto lebih dekat dengan pencahayaan yang cukup.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      Text(
        'Hasil Analisis (${result.items.length} bahan)',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
      ),
      if (result.summary != null) ...[
        const SizedBox(height: 4),
        Text(
          result.summary!,
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
      ],
      const SizedBox(height: 12),
      for (final item in result.items)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ScannedItemCard(
            item: item,
            onAddToStock: () => Navigator.of(context).pushNamed(
              AppRoutes.stockForm,
              arguments: item.toDraft(),
            ),
          ),
        ),
      const Text(
        'Penilaian AI bersifat perkiraan. Tetap periksa bahan secara langsung.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: AppColors.mutedLight),
      ),
    ];
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.image, required this.isAnalyzing});

  final PickedImage? image;
  final bool isAnalyzing;

  @override
  Widget build(BuildContext context) {
    final picked = image;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: CustomPaint(
        foregroundPainter: picked == null
            ? _DashedBorderPainter(
                color: AppColors.primary,
                strokeWidth: 3,
                radius: 24,
              )
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF111827)),
              if (picked == null)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada foto',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                )
              else
                Image.memory(
                  picked.bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_outlined,
                        size: 48, color: Colors.white54),
                  ),
                ),
              if (isAnalyzing)
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 14),
                      Text(
                        'Menganalisis kualitas...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotConfiguredBanner extends StatelessWidget {
  const _NotConfiguredBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.key_off_outlined, size: 18, color: AppColors.amberText),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI belum aktif: API key belum diatur. Isi GROQ_API_KEY di '
              'env.json lalu jalankan dengan --dart-define-from-file=env.json',
              style: TextStyle(fontSize: 12, color: AppColors.amberText),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.redSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: AppColors.warning),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double radius;

  static const double _dash = 12;
  static const double _gap = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - strokeWidth,
          size.height - strokeWidth),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius;
}
