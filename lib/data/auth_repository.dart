import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';

import '../model/auth_user.dart';
import 'local_database.dart';

abstract interface class AuthRepository {
  Future<AuthUser> register({
    required String fullName,
    required String email,
    required String password,
    required String businessType,
    required String address,
  });

  Future<AuthUser> login({required String email, required String password});

  /// User dari sesi tersimpan ("Remember me"), atau null.
  Future<AuthUser?> restoreSession();

  Future<void> saveSession(int userId);

  Future<void> clearSession();

  /// Menyimpan peran (nama enum `UserRole`) dan mengembalikan user terbaru.
  Future<AuthUser> updateRole(int userId, String role);
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SqliteAuthRepository implements AuthRepository {
  const SqliteAuthRepository();

  static final _passwordHasher = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );

  @override
  Future<AuthUser> register({
    required String fullName,
    required String email,
    required String password,
    required String businessType,
    required String address,
  }) async {
    final database = await LocalDatabase.instance.database;
    final normalizedEmail = email.trim().toLowerCase();
    final existing = await database.query(
      'users',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw const AuthException('Email sudah terdaftar.');
    }

    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final passwordHash = await _hashPassword(password, salt);
    final createdAt = DateTime.now();
    final user = AuthUser(
      fullName: fullName.trim(),
      email: normalizedEmail,
      businessType: businessType,
      address: address.trim(),
      createdAt: createdAt,
    );

    try {
      final id = await database.insert('users', {
        ...user.toMap(),
        'password_hash': base64Encode(passwordHash),
        'password_salt': base64Encode(salt),
      });
      return user.copyWith(id: id);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const AuthException('Email sudah terdaftar.');
      }
      rethrow;
    }
  }

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final database = await LocalDatabase.instance.database;
    final rows = await database.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AuthException('Email atau password salah.');
    }

    final row = rows.first;
    final salt = base64Decode(row['password_salt']! as String);
    final expectedHash = base64Decode(row['password_hash']! as String);
    final actualHash = await _hashPassword(password, salt);
    if (!_matches(actualHash, expectedHash)) {
      throw const AuthException('Email atau password salah.');
    }

    return AuthUser.fromMap(row);
  }

  @override
  Future<AuthUser?> restoreSession() async {
    final database = await LocalDatabase.instance.database;
    final rows = await database.rawQuery('''
      SELECT u.* FROM app_session s
      JOIN users u ON u.id = s.user_id
      WHERE s.id = 1
      LIMIT 1
    ''');
    return rows.isEmpty ? null : AuthUser.fromMap(rows.first);
  }

  @override
  Future<void> saveSession(int userId) async {
    final database = await LocalDatabase.instance.database;
    await database.insert(
      'app_session',
      {'id': 1, 'user_id': userId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clearSession() async {
    final database = await LocalDatabase.instance.database;
    await database.delete('app_session');
  }

  @override
  Future<AuthUser> updateRole(int userId, String role) async {
    final database = await LocalDatabase.instance.database;
    await database.update(
      'users',
      {'role': role},
      where: 'id = ?',
      whereArgs: [userId],
    );
    final rows = await database.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) throw const AuthException('Akun tidak ditemukan.');
    return AuthUser.fromMap(rows.first);
  }

  Future<List<int>> _hashPassword(String password, List<int> salt) async {
    final key = await _passwordHasher.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  bool _matches(List<int> actual, List<int> expected) {
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var index = 0; index < actual.length; index++) {
      difference |= actual[index] ^ expected[index];
    }
    return difference == 0;
  }
}
