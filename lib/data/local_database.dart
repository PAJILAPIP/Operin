import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart' as web;

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();
  Database? _database;
  static bool _ffiFactoryInitialized = false;

  Future<Database> get database async {
    if (_database != null) return _database!;

    if (kIsWeb) {
      databaseFactory = web.databaseFactoryFfiWeb;
    }

    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (isDesktop && !_ffiFactoryInitialized) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
      _ffiFactoryInitialized = true;
    }

    final databasePath = kIsWeb
        ? 'operin.db'
        : path.join(await getDatabasesPath(), 'operin.db');
    _database = await openDatabase(
      databasePath,
      version: 3,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name TEXT NOT NULL,
            email TEXT NOT NULL COLLATE NOCASE UNIQUE,
            password_hash TEXT NOT NULL,
            password_salt TEXT NOT NULL,
            business_type TEXT NOT NULL,
            address TEXT NOT NULL,
            created_at TEXT NOT NULL,
            role TEXT,
            latitude REAL,
            longitude REAL
          )
        ''');
        await _createSessionTable(database);
        await _createBusinessProfileTable(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('ALTER TABLE users ADD COLUMN role TEXT');
          await _createSessionTable(database);
        }
        if (oldVersion < 3) {
          await database.execute('ALTER TABLE users ADD COLUMN latitude REAL');
          await database.execute('ALTER TABLE users ADD COLUMN longitude REAL');
          await _createBusinessProfileTable(database);
          // Jenis usaha lama ("usaha1".."usaha5") → nama enum BusinessCategory.
          const legacy = {
            'usaha1': 'warungMakan',
            'usaha2': 'katering',
            'usaha3': 'tokoBuahSayur',
            'usaha4': 'supermarket',
            'usaha5': 'distributor',
          };
          for (final entry in legacy.entries) {
            await database.update(
              'users',
              {'business_type': entry.value},
              where: 'business_type = ?',
              whereArgs: [entry.key],
            );
          }
        }
      },
    );
    return _database!;
  }

  /// Profil & preferensi usaha (satu baris per user).
  static Future<void> _createBusinessProfileTable(DatabaseExecutor database) {
    return database.execute('''
      CREATE TABLE business_profiles (
        user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        business_name TEXT NOT NULL,
        whatsapp TEXT NOT NULL,
        preferred_categories TEXT NOT NULL,
        radius_km INTEGER NOT NULL,
        notify_expiry INTEGER NOT NULL,
        notify_days_before INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// Menyimpan user yang sedang login ("Remember me"). Maksimal satu baris.
  static Future<void> _createSessionTable(DatabaseExecutor database) {
    return database.execute('''
      CREATE TABLE app_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }
}
