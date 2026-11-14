import '../model/promotion.dart';
import 'local_database.dart';

abstract interface class PromotionRepository {
  /// Semua promo milik [userId], terbaru lebih dulu.
  Future<List<Promotion>> listByUser(int userId);

  Future<Promotion> insert(Promotion promotion);

  Future<void> updateStatus(int id, PromotionStatus status);
}

class SqlitePromotionRepository implements PromotionRepository {
  const SqlitePromotionRepository();

  @override
  Future<List<Promotion>> listByUser(int userId) async {
    final database = await LocalDatabase.instance.database;
    final rows = await database.query(
      'promotions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Promotion.fromMap).toList();
  }

  @override
  Future<Promotion> insert(Promotion promotion) async {
    final database = await LocalDatabase.instance.database;
    final id = await database.insert(
      'promotions',
      promotion.toMap()..remove('id'),
    );
    return promotion.copyWith(id: id);
  }

  @override
  Future<void> updateStatus(int id, PromotionStatus status) async {
    final database = await LocalDatabase.instance.database;
    await database.update(
      'promotions',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
