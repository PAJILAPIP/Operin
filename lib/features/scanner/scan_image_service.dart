import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Status izin kamera yang relevan untuk UI.
enum CameraAccess {
  granted,

  /// Ditolak, tapi masih bisa diminta lagi.
  denied,

  /// Ditolak permanen / dibatasi → user harus membuka Pengaturan.
  permanentlyDenied,

  /// Perangkat/platform tidak punya kamera yang didukung (mis. desktop).
  unsupported,
}

enum ScanImageSource { camera, gallery }

/// Foto yang dipilih, siap dikirim ke AI.
class PickedImage {
  const PickedImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

/// Izin kamera + pengambilan foto. Diabstraksi agar bisa dipalsukan di test.
abstract class ScanImageService {
  /// Status izin kamera saat ini tanpa memunculkan dialog sistem.
  Future<CameraAccess> cameraStatus();

  /// Memunculkan dialog izin kamera dari sistem.
  Future<CameraAccess> requestCamera();

  /// Membuka halaman pengaturan aplikasi (untuk izin yang ditolak permanen).
  Future<bool> openSettings();

  /// Null jika user membatalkan.
  Future<PickedImage?> pick(ScanImageSource source);
}

/// Implementasi nyata: permission_handler (Android/iOS) + image_picker.
class DeviceScanImageService implements ScanImageService {
  DeviceScanImageService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Izin runtime kamera hanya ada di Android & iOS. Web memakai izin
  /// browser yang diminta otomatis oleh image_picker.
  bool get _needsRuntimePermission =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _cameraSupported =>
      _picker.supportsImageSource(ImageSource.camera);

  CameraAccess _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return CameraAccess.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraAccess.permanentlyDenied;
    }
    return CameraAccess.denied;
  }

  @override
  Future<CameraAccess> cameraStatus() async {
    if (!_cameraSupported) return CameraAccess.unsupported;
    if (!_needsRuntimePermission) return CameraAccess.granted;
    return _map(await Permission.camera.status);
  }

  @override
  Future<CameraAccess> requestCamera() async {
    if (!_cameraSupported) return CameraAccess.unsupported;
    if (!_needsRuntimePermission) return CameraAccess.granted;
    return _map(await Permission.camera.request());
  }

  @override
  Future<bool> openSettings() => openAppSettings();

  @override
  Future<PickedImage?> pick(ScanImageSource source) async {
    final file = await _picker.pickImage(
      source: source == ScanImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      // Cukup tajam untuk membaca label, tetap ringan untuk diunggah.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    final mime = file.mimeType ??
        (name.endsWith('.png') ? 'image/png' : 'image/jpeg');
    return PickedImage(bytes: bytes, mimeType: mime);
  }
}
