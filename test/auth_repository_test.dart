import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operin/data/auth_repository.dart';
import 'package:operin/data/local_database.dart';

void main() {
  test('register stores user and login verifies password', () async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final repository = SqliteAuthRepository();
    final email = 'auth-${DateTime.now().microsecondsSinceEpoch}@operin.test';

    try {
      final registeredUser = await repository.register(
        fullName: 'Test User',
        email: email,
        password: 'password123',
        businessType: 'usaha1',
        address: 'Jakarta',
      );
      final loggedInUser = await repository.login(
        email: email,
        password: 'password123',
      );

      expect(loggedInUser.id, registeredUser.id);
      expect(loggedInUser.email, email);
      await expectLater(
        repository.login(email: email, password: 'wrong-password'),
        throwsA(isA<AuthException>()),
      );
    } finally {
      final database = await LocalDatabase.instance.database;
      await database.delete('users', where: 'email = ?', whereArgs: [email]);
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  test('session save/restore/clear and role update', () async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final repository = SqliteAuthRepository();
    final email = 'session-${DateTime.now().microsecondsSinceEpoch}@operin.test';

    try {
      final user = await repository.register(
        fullName: 'Session User',
        email: email,
        password: 'password123',
        businessType: 'usaha2',
        address: 'Padang',
      );
      expect(user.role, isNull);

      await repository.saveSession(user.id!);
      final restored = await repository.restoreSession();
      expect(restored?.id, user.id);
      expect(restored?.email, email);

      final updated = await repository.updateRole(user.id!, 'buyer');
      expect(updated.role, 'buyer');
      expect((await repository.restoreSession())?.role, 'buyer');

      await repository.clearSession();
      expect(await repository.restoreSession(), isNull);
    } finally {
      final database = await LocalDatabase.instance.database;
      await database.delete('app_session');
      await database.delete('users', where: 'email = ?', whereArgs: [email]);
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });
}