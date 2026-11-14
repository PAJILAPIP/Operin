import '../model/stock_item.dart';
import 'supabase_support.dart';

abstract interface class StockRepository {
  /// Semua stok milik [userId], urut dari yang paling cepat kedaluwarsa.
  Future<List<StockItem>> listByUser(int userId);

  /// Menyimpan stok baru dan mengembalikannya beserta id.
  Future<StockItem> insert(StockItem item);

  Future<StockItem> update(StockItem item);

  Future<void> delete(int id);
}

class SupabaseStockRepository implements StockRepository {
  const SupabaseStockRepository();

  static const _table = 'stock_items';

  @override
  Future<List<StockItem>> listByUser(int userId) => guardDb(() async {
    final rows = await supabase
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('expiry_date')
        .order('name');
    return rows.map(StockItem.fromMap).toList();
  }, DataException.new);

  @override
  Future<StockItem> insert(StockItem item) => guardDb(() async {
    final row = await supabase
        .from(_table)
        .insert(item.toMap()..remove('id'))
        .select()
        .single();
    return StockItem.fromMap(row);
  }, DataException.new);

  @override
  Future<StockItem> update(StockItem item) {
    final id = item.id;
    if (id == null) throw ArgumentError('Stok belum memiliki id.');
    return guardDb(() async {
      final row = await supabase
          .from(_table)
          .update(item.toMap()..remove('id'))
          .eq('id', id)
          .select()
          .maybeSingle();
      if (row == null) throw StateError('Stok #$id tidak ditemukan.');
      return StockItem.fromMap(row);
    }, DataException.new);
  }

  @override
  Future<void> delete(int id) => guardDb(
    () => supabase.from(_table).delete().eq('id', id),
    DataException.new,
  );
}
