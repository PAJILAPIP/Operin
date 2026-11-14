import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import 'location_service.dart';

/// Dialog peta OpenStreetMap untuk menandai lokasi usaha.
///
/// User menggeser peta sehingga pin di tengah berada di titik usaha, atau
/// menekan tombol "lokasi saya". Mengembalikan [LatLng] atau null jika ditutup.
class LocationPickerDialog extends StatefulWidget {
  const LocationPickerDialog({
    super.key,
    this.initial,
    this.locationService = const LocationService(),
  });

  final LatLng? initial;
  final LocationService locationService;

  static Future<LatLng?> show(BuildContext context, {LatLng? initial}) {
    return showDialog<LatLng>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => LocationPickerDialog(initial: initial),
    );
  }

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  static const double _zoom = 16;

  final _mapController = MapController();
  late LatLng _center = widget.initial ?? LocationService.defaultCenter;
  bool _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Belum ada titik tersimpan → langsung coba lokasi perangkat.
    if (widget.initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _useMyLocation());
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final position = await widget.locationService.currentPosition();
      if (!mounted) return;
      _mapController.move(position, _zoom);
      setState(() => _center = position);
    } on LocationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      debugPrint('Gagal mengambil lokasi: $error');
      if (mounted) {
        setState(() => _error = 'Lokasi tidak dapat diambil. Geser peta manual.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
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
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            SizedBox(height: 340, child: _buildMap()),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CoordinateBox(center: _center),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Konfirmasi Lokasi',
                    verticalPadding: 14,
                    onPressed: () => Navigator.of(context).pop(_center),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
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
              color: AppColors.text,
            ),
          ),
          IconButton(
            tooltip: 'Tutup',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: _zoom,
            minZoom: 4,
            maxZoom: 19,
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture) setState(() => _center = camera.center);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.operin',
            ),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
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
                color: AppColors.text,
              ),
            ),
          ),
        ),
        // Pin tetap di tengah; ujung bawah ikon tepat di titik pusat peta.
        const IgnorePointer(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 44),
              child: Icon(
                Icons.location_on,
                size: 44,
                color: AppColors.warning,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 28,
          child: FloatingActionButton.small(
            heroTag: null,
            tooltip: 'Gunakan lokasi saya',
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            onPressed: _locating ? null : _useMyLocation,
            child: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}

class _CoordinateBox extends StatelessWidget {
  const _CoordinateBox({required this.center});

  final LatLng center;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined,
              size: 20, color: AppColors.mutedLight),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              formatLatLng(center),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Format koordinat untuk ditampilkan, mis. "-0.94710, 100.41720".
String formatLatLng(LatLng point) =>
    '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
