import '../model/promotion.dart';
import 'supabase_support.dart';

abstract interface class PromotionRepository {
  /// Semua promo milik [userId], terbaru lebih dulu.
  Future<List<Promotion>> listByUser(int userId);

  Future<Promotion> insert(Promotion promotion);

  Future<void> updateStatus(int id, PromotionStatus status);
}

class SupabasePromotionRepository implements PromotionRepository {
  const SupabasePromotionRepository();

  static const _table = 'promotions';

  @override
  Future<List<Promotion>> listByUser(int userId) => guardDb(() async {
    final rows = await supabase
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map(Promotion.fromMap).toList();
  }, DataException.new);

  @override
  Future<Promotion> insert(Promotion promotion) => guardDb(() async {
    final row = await supabase
        .from(_table)
        .insert(promotion.toMap()..remove('id'))
        .select()
        .single();
    return Promotion.fromMap(row);
  }, DataException.new);

  @override
  Future<void> updateStatus(int id, PromotionStatus status) => guardDb(
    () => supabase.from(_table).update({'status': status.name}).eq('id', id),
    DataException.new,
  );
}
