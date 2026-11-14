import 'package:flutter/widgets.dart';

import '../../data/scan_service.dart';
import 'scan_image_service.dart';

/// Menyediakan layanan AI scanner (analisis + kamera) ke widget di bawahnya.
class ScannerScope extends InheritedWidget {
  const ScannerScope({
    super.key,
    required this.scanService,
    required this.imageService,
    required super.child,
  });

  final StockScanService scanService;
  final ScanImageService imageService;

  static ScannerScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ScannerScope>();
    assert(scope != null, 'ScannerScope tidak ditemukan di atas widget ini.');
    return scope!;
  }

  @override
  bool updateShouldNotify(ScannerScope oldWidget) =>
      scanService != oldWidget.scanService ||
      imageService != oldWidget.imageService;
}
