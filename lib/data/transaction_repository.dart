import '../model/activity_entry.dart';
import 'supabase_support.dart';

class TransactionException implements Exception {
  const TransactionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Penyelesaian transaksi (memindahkan stok) dan riwayat aktivitas.
abstract interface class TransactionRepository {
  /// Riwayat aktivitas milik [userId], terbaru lebih dulu.
  Future<List<ActivityEntry>> listActivity(int userId);

  /// Penjual menandai pesanan yang sudah diterima sebagai selesai:
  /// stok penjual berkurang, pembeli mendapat stok baru, riwayat dicatat.
  Future<void> completeOrder(
    int orderId, {
    required int actorId,
    required DateTime now,
  });

  /// Salah satu pihak menyelesaikan barter/donasi yang sudah disepakati:
  /// stok berpindah di kedua sisi, riwayat dicatat.
  Future<void> completeBarter(
    int barterId, {
    required int actorId,
    required DateTime now,
  });
}

/// Penyelesaian transaksi lewat RPC `complete_order` / `complete_barter`
/// (satu transaksi database; stok tidak dihapus walau habis).
class SupabaseTransactionRepository implements TransactionRepository {
  const SupabaseTransactionRepository();

  @override
  Future<List<ActivityEntry>> listActivity(int userId) => guardDb(() async {
    final rows = await supabase
        .from('activity_log')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .order('id', ascending: false);
    return rows.map(ActivityEntry.fromMap).toList();
  }, TransactionException.new);

  @override
  Future<void> completeOrder(
    int orderId, {
    required int actorId,
    required DateTime now,
  }) => guardDb(
    () => supabase.rpc('complete_order', params: {'p_order_id': orderId}),
    TransactionException.new,
  );

  @override
  Future<void> completeBarter(
    int barterId, {
    required int actorId,
    required DateTime now,
  }) => guardDb(
    () => supabase.rpc('complete_barter', params: {'p_barter_id': barterId}),
    TransactionException.new,
  );
}
