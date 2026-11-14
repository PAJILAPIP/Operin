import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operin/app.dart';
import 'package:operin/data/auth_repository.dart';
import 'package:operin/model/auth_user.dart';

void main() {
  testWidgets('Login -> survey -> dashboard -> logout', (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(OperinApp(authRepository: repository));
    await tester.pumpAndSettle();

    // Belum ada sesi → halaman login
    expect(
      find.text('Welcome back please login to your account'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(0), 'user@operin.test');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Peran Anda'), findsOneWidget);
    expect(repository.sessionUserId, 1, reason: 'Remember me aktif');

    // Pilih peran → Dashboard, peran tersimpan
    await tester.tap(find.text('Jual Stok Surplus'));
    await tester.pump();
    await tester.tap(find.text('Lanjutkan ke Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('DAMPAK BISNIS ANDA'), findsOneWidget);
    expect(repository.user.role, 'seller');

    // Profil menampilkan nama user yang login
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Operin User'), findsOneWidget);

    // Logout → sesi dihapus, kembali ke login
    await tester.ensureVisible(find.text('Keluar Akun'));
    await tester.tap(find.text('Keluar Akun'));
    await tester.pumpAndSettle();
    expect(repository.sessionUserId, isNull);
    expect(
      find.text('Welcome back please login to your account'),
      findsOneWidget,
    );
  });

  testWidgets('Sesi tersimpan dengan peran langsung ke dashboard',
      (tester) async {
    final repository = _FakeAuthRepository()
      ..user = _FakeAuthRepository.defaultUser.copyWith(role: 'buyer')
      ..sessionUserId = 1;

    await tester.pumpWidget(OperinApp(authRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('DAMPAK BISNIS ANDA'), findsOneWidget);
  });

  testWidgets('Sesi tersimpan tanpa peran diarahkan ke survey',
      (tester) async {
    final repository = _FakeAuthRepository()..sessionUserId = 1;

    await tester.pumpWidget(OperinApp(authRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Peran Anda'), findsOneWidget);
  });

  testWidgets('Login tanpa Remember me tidak menyimpan sesi', (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(OperinApp(authRepository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'user@operin.test');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Remember me'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Peran Anda'), findsOneWidget);
    expect(repository.sessionUserId, isNull);
  });
}

/// Repository in-memory dengan satu akun: user@operin.test / password123.
class _FakeAuthRepository implements AuthRepository {
  static final defaultUser = AuthUser(
    id: 1,
    fullName: 'Operin User',
    email: 'user@operin.test',
    businessType: 'usaha1',
    address: 'Jakarta',
    createdAt: DateTime(2026),
  );

  AuthUser user = defaultUser;
  int? sessionUserId;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    if (email != user.email || password != 'password123') {
      throw const AuthException('Email atau password salah.');
    }
    return user;
  }

  @override
  Future<AuthUser> register({
    required String fullName,
    required String email,
    required String password,
    required String businessType,
    required String address,
  }) async {
    user = AuthUser(
      id: 2,
      fullName: fullName,
      email: email,
      businessType: businessType,
      address: address,
      createdAt: DateTime(2026),
    );
    return user;
  }

  @override
  Future<AuthUser?> restoreSession() async =>
      sessionUserId == user.id ? user : null;

  @override
  Future<void> saveSession(int userId) async => sessionUserId = userId;

  @override
  Future<void> clearSession() async => sessionUserId = null;

  @override
  Future<AuthUser> updateRole(int userId, String role) async {
    user = user.copyWith(role: role);
    return user;
  }
}
