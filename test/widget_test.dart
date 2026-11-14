import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operin/app.dart';
import 'package:operin/data/auth_repository.dart';
import 'package:operin/model/auth_user.dart';

void main() {
  testWidgets('Alur login -> survey -> dashboard', (tester) async {
    final authRepository = _FakeAuthRepository();
    await tester.pumpWidget(OperinApp(authRepository: authRepository));

    // Halaman login
    expect(find.text('Operin'), findsOneWidget);
    expect(
      find.text('Welcome back please login to your account'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(0), 'user@operin.test');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Peran Anda'), findsOneWidget);

    // Pilih peran -> Dashboard
    await tester.tap(find.text('Jual Stok Surplus'));
    await tester.pump();
    await tester.tap(find.text('Lanjutkan ke Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Dampak Bisnis Anda'.toUpperCase()), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    if (email != 'user@operin.test' || password != 'password123') {
      throw const AuthException('Email atau password salah.');
    }
    return AuthUser(
      id: 1,
      fullName: 'Operin User',
      email: email,
      businessType: 'usaha1',
      address: 'Jakarta',
      createdAt: DateTime(2026),
    );
  }

  @override
  Future<AuthUser> register({
    required String fullName,
    required String email,
    required String password,
    required String businessType,
    required String address,
  }) async => AuthUser(
    fullName: fullName,
    email: email,
    businessType: businessType,
    address: address,
    createdAt: DateTime(2026),
  );
}
