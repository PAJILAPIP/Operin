import 'package:flutter/widgets.dart';

import '../../data/auth_repository.dart';
import '../../data/profile_repository.dart';
import '../../model/auth_user.dart';
import '../../model/business_profile.dart';

/// Menyimpan user yang sedang login beserta profil usahanya, dan mengelola
/// sesi tersimpan.
class SessionController extends ChangeNotifier {
  SessionController({
    required this.repository,
    required this.profileRepository,
  });

  final AuthRepository repository;
  final ProfileRepository profileRepository;

  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  BusinessProfile? _profile;

  /// Profil usaha; null jika onboarding profil belum selesai.
  BusinessProfile? get profile => _profile;

  /// Memuat sesi tersimpan saat app dibuka. Mengembalikan user atau null.
  Future<AuthUser?> restore() async {
    final user = await repository.restoreSession();
    _currentUser = user;
    _profile = user == null ? null : await profileRepository.getProfile(user.id!);
    notifyListeners();
    return user;
  }

  /// [remember] true → sesi disimpan ke database sehingga user tetap login
  /// setelah app ditutup. false → sesi hanya ada di memori.
  Future<void> signIn(AuthUser user, {required bool remember}) async {
    if (remember) {
      await repository.saveSession(user.id!);
    } else {
      await repository.clearSession();
    }
    _currentUser = user;
    _profile = await profileRepository.getProfile(user.id!);
    notifyListeners();
  }

  Future<void> setRole(String role) async {
    final user = _currentUser;
    if (user == null) return;
    _currentUser = await repository.updateRole(user.id!, role);
    notifyListeners();
  }

  Future<void> saveProfile(BusinessProfile profile) async {
    _profile = await profileRepository.saveProfile(profile);
    notifyListeners();
  }

  Future<void> signOut() async {
    await repository.clearSession();
    _currentUser = null;
    _profile = null;
    notifyListeners();
  }
}

/// Menyediakan [SessionController] ke seluruh widget di bawahnya.
class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Membaca controller dan rebuild saat sesi berubah.
  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope tidak ditemukan di atas widget ini.');
    return scope!.notifier!;
  }

  /// Membaca controller tanpa rebuild (untuk callback/aksi).
  static SessionController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope tidak ditemukan di atas widget ini.');
    return scope!.notifier!;
  }
}
