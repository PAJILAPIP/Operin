import '../model/stock_item.dart';
import 'local_database.dart';

abstract interface class StockRepository {
  /// Semua stok milik [userId], urut dari yang paling cepat kedaluwarsa.
  Future<List<StockItem>> listByUser(int userId);

  /// Menyimpan stok baru dan mengembalikannya beserta id.
  Future<StockItem> insert(StockItem item);

  Future<StockItem> update(StockItem item);

  Future<void> delete(int id);
}

class SqliteStockRepository implements StockRepository {
  const SqliteStockRepository();

  @override
  Future<List<StockItem>> listByUser(int userId) async {
    final database = await LocalDatabase.instance.database;
    final rows = await database.query(
      'stock_items',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'expiry_date ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(StockItem.fromMap).toList();
  }

  @override
  Future<StockItem> insert(StockItem item) async {
    final database = await LocalDatabase.instance.database;
    final map = item.toMap()..remove('id');
    final id = await database.insert('stock_items', map);
    return item.copyWith(id: id);
  }

  @override
  Future<StockItem> update(StockItem item) async {
    final id = item.id;
    if (id == null) throw ArgumentError('Stok belum memiliki id.');
    final database = await LocalDatabase.instance.database;
    final count = await database.update(
      'stock_items',
      item.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) throw StateError('Stok #$id tidak ditemukan.');
    return item;
  }

  @override
  Future<void> delete(int id) async {
    final database = await LocalDatabase.instance.database;
    await database.delete('stock_items', where: 'id = ?', whereArgs: [id]);
  }
}
