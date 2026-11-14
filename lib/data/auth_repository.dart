import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../model/auth_user.dart';
import 'supabase_support.dart';

abstract interface class AuthRepository {
  Future<AuthUser> register({
    required String fullName,
    required String email,
    required String password,
    required String businessType,
    required String address,
    double? latitude,
    double? longitude,
  });

  Future<AuthUser> login({required String email, required String password});

  /// User dari sesi tersimpan ("Remember me"), atau null.
  Future<AuthUser?> restoreSession();

  /// Sesi tetap login setelah app ditutup.
  Future<void> saveSession(int userId);

  /// Sesi hanya untuk pemakaian kali ini (tidak diingat saat app dibuka lagi).
  Future<void> clearSession();

  /// Keluar dari akun.
  Future<void> signOut();

  /// Menyimpan peran (nama enum `UserRole`) dan mengembalikan user terbaru.
  Future<AuthUser> updateRole(int userId, String role);
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Login/daftar lewat Supabase Auth (email & password). Data akun disimpan
/// di tabel `public.users` yang dibuat otomatis oleh trigger saat daftar.
class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository();

  static const _rememberKey = 'operin.remember_session';

  @override
  Future<AuthUser> register({
    required String fullName,
    required String email,
    required String password,
    required String businessType,
    required String address,
    double? latitude,
    double? longitude,
  }) => _guard(() async {
    final response = await supabase.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'business_type': businessType,
        'address': address.trim(),
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
      },
    );
    if (response.session == null) {
      throw const AuthException(
        'Akun dibuat. Konfirmasi email Anda terlebih dahulu, lalu login.',
      );
    }
    return _currentUserRow();
  });

  @override
  Future<AuthUser> login({required String email, required String password}) =>
      _guard(() async {
        await supabase.auth.signInWithPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );
        return _currentUserRow();
      });

  @override
  Future<AuthUser?> restoreSession() async {
    if (supabase.auth.currentSession == null) return null;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_rememberKey) == false) {
      // Login terakhir tanpa "Remember me" → minta login ulang.
      await signOut();
      return null;
    }
    try {
      return await _currentUserRow();
    } catch (error) {
      debugPrint('Gagal memulihkan sesi: $error');
      return null;
    }
  }

  @override
  Future<void> saveSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, true);
  }

  @override
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, false);
  }

  @override
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (error) {
      // Tetap keluar secara lokal walau server tidak terjangkau.
      debugPrint('Sign out server gagal: $error');
      await supabase.auth.signOut(scope: sb.SignOutScope.local);
    }
  }

  @override
  Future<AuthUser> updateRole(int userId, String role) => _guard(() async {
    final row = await supabase
        .from('users')
        .update({'role': role})
        .eq('id', userId)
        .select()
        .maybeSingle();
    if (row == null) throw const AuthException('Akun tidak ditemukan.');
    return _toUser(row);
  });

  Future<AuthUser> _currentUserRow() async {
    final authUser = supabase.auth.currentUser;
    if (authUser == null) throw const AuthException('Sesi berakhir.');
    final row = await supabase
        .from('users')
        .select()
        .eq('auth_id', authUser.id)
        .maybeSingle();
    if (row == null) throw const AuthException('Akun tidak ditemukan.');
    return _toUser(row);
  }

  AuthUser _toUser(Map<String, dynamic> row) => AuthUser.fromMap({
    ...row,
    'email': supabase.auth.currentUser?.email ?? '',
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await guardDb(action, AuthException.new);
    } on sb.AuthException catch (error) {
      debugPrint('Auth error ${error.code}: ${error.message}');
      throw AuthException(authMessage(error));
    } on http.ClientException {
      throw const AuthException(networkErrorMessage);
    }
  }

  /// Pesan Supabase Auth → bahasa Indonesia.
  @visibleForTesting
  static String authMessage(sb.AuthException error) {
    if (error is sb.AuthRetryableFetchException) return networkErrorMessage;
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    if (code == 'invalid_credentials' || message.contains('invalid login')) {
      return 'Email atau password salah.';
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        message.contains('already registered')) {
      return 'Email sudah terdaftar.';
    }
    if (code == 'email_not_confirmed') {
      return 'Email belum dikonfirmasi. Cek kotak masuk Anda.';
    }
    if (code == 'weak_password' || message.contains('password should')) {
      return 'Password terlalu lemah (minimal 6 karakter).';
    }
    if (code == 'email_address_invalid' || message.contains('invalid email')) {
      return 'Format email tidak valid.';
    }
    if (code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit') {
      return 'Terlalu banyak percobaan. Coba lagi beberapa saat.';
    }
    return 'Autentikasi gagal. Coba lagi.';
  }
}
