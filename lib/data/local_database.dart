import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();
  Database? _database;
  static bool _ffiFactoryInitialized = false;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (isDesktop && !_ffiFactoryInitialized) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
      _ffiFactoryInitialized = true;
    }

    final databasePath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(databasePath, 'operin.db'),
      version: 1,
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
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }
}
