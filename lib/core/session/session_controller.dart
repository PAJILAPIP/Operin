import 'package:flutter/widgets.dart';

import '../../data/auth_repository.dart';
import '../../model/auth_user.dart';

/// Menyimpan user yang sedang login dan mengelola sesi tersimpan.
class SessionController extends ChangeNotifier {
  SessionController({required this.repository});

  final AuthRepository repository;

  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Memuat sesi tersimpan saat app dibuka. Mengembalikan user atau null.
  Future<AuthUser?> restore() async {
    _currentUser = await repository.restoreSession();
    notifyListeners();
    return _currentUser;
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
    notifyListeners();
  }

  Future<void> setRole(String role) async {
    final user = _currentUser;
    if (user == null) return;
    _currentUser = await repository.updateRole(user.id!, role);
    notifyListeners();
  }

  Future<void> signOut() async {
    await repository.clearSession();
    _currentUser = null;
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
