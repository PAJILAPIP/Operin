import 'package:sqflite/sqflite.dart';

import '../model/business_profile.dart';
import 'local_database.dart';

abstract interface class ProfileRepository {
  /// Profil usaha milik [userId], atau null jika onboarding belum selesai.
  Future<BusinessProfile?> getProfile(int userId);

  /// Membuat atau memperbarui profil usaha.
  Future<BusinessProfile> saveProfile(BusinessProfile profile);
}

class SqliteProfileRepository implements ProfileRepository {
  const SqliteProfileRepository();

  @override
  Future<BusinessProfile?> getProfile(int userId) async {
    final database = await LocalDatabase.instance.database;
    final rows = await database.query(
      'business_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : BusinessProfile.fromMap(rows.first);
  }

  @override
  Future<BusinessProfile> saveProfile(BusinessProfile profile) async {
    final database = await LocalDatabase.instance.database;
    await database.insert(
      'business_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return profile;
  }
}
