import '../core/utils/geo.dart';
import '../model/auth_user.dart';
import '../model/barter.dart';
import '../model/business_category.dart';
import '../model/food_category.dart';
import '../model/partner_profile.dart';
import '../model/stock_item.dart';
import 'supabase_support.dart';

class BarterException implements Exception {
  const BarterException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sumber data matchmaking & barter.
abstract interface class MatchRepository {
  /// UMKM lain yang sudah menyelesaikan onboarding, beserta stoknya.
  Future<List<PartnerProfile>> listPartners({required AuthUser viewer});

  /// Barter yang melibatkan [userId], terbaru diperbarui lebih dulu.
  Future<List<Barter>> listBarters(int userId);

  Future<List<BarterMessage>> listMessages(int barterId);

  Future<Barter> createBarter(Barter barter, {String? message});

  /// Tawaran balik oleh [actorId] (harus pihak yang sedang ditunggu).
  Future<void> counterOffer(
    int barterId, {
    required int actorId,
    required double offeredQuantity,
    double? requestedQuantity,
    String? message,
    required DateTime now,
  });

  /// Terima / tolak oleh pihak yang sedang ditunggu.
  Future<void> respond(
    int barterId, {
    required int actorId,
    required bool accept,
    required DateTime now,
  });

  /// Dibatalkan oleh pengaju selama masih terbuka.
  Future<void> cancel(int barterId, {required int actorId, required DateTime now});

  Future<void> sendMessage(
    int barterId, {
    required int senderId,
    required String text,
    required DateTime now,
  });
}

/// Matchmaking & barter di Supabase. Aturan giliran, validasi stok, dan
/// pesan otomatis dijalankan fungsi RPC (`create_barter`, `counter_offer`,
/// `respond_barter`, `cancel_barter`, `send_barter_message`). Pelaku diambil
/// dari sesi login di server, bukan dari parameter `actorId`.
class SupabaseMatchRepository implements MatchRepository {
  const SupabaseMatchRepository();

  @override
  Future<List<PartnerProfile>> listPartners({required AuthUser viewer}) =>
      guardDb(() async {
        final users = await supabase
            .from('partner_profiles')
            .select()
            .neq('id', viewer.id!);
        if (users.isEmpty) return const <PartnerProfile>[];

        final ids = users.map((row) => row['id']! as int).toList();
        final stockRows = await supabase
            .from('stock_items')
            .select()
            .inFilter('user_id', ids)
            .order('expiry_date');
        final stocksByUser = <int, List<StockItem>>{};
        for (final row in stockRows) {
          final item = StockItem.fromMap(row);
          stocksByUser.putIfAbsent(item.userId, () => []).add(item);
        }
        return users
            .map((row) => partnerFromRow(row, viewer, stocksByUser))
            .toList();
      }, BarterException.new);

  @override
  Future<List<Barter>> listBarters(int userId) => guardDb(() async {
    final rows = await supabase
        .from('barter_details')
        .select()
        .or('proposer_id.eq.$userId,receiver_id.eq.$userId')
        .order('updated_at', ascending: false)
        .order('id', ascending: false);
    return rows.map(Barter.fromMap).toList();
  }, BarterException.new);

  @override
  Future<List<BarterMessage>> listMessages(int barterId) => guardDb(() async {
    final rows = await supabase
        .from('barter_message_details')
        .select()
        .eq('barter_id', barterId)
        .order('id');
    return rows.map(BarterMessage.fromMap).toList();
  }, BarterException.new);

  @override
  Future<Barter> createBarter(Barter barter, {String? message}) {
    if (barter.proposerId == barter.receiverId) {
      throw const BarterException('Tidak bisa barter dengan diri sendiri.');
    }
    return guardDb(() async {
      final row = await supabase.rpc(
        'create_barter',
        params: {
          'p_type': barter.type.name,
          'p_receiver_id': barter.receiverId,
          'p_offered_stock_id': barter.offeredStockId,
          'p_offered_quantity': barter.offeredQuantity,
          'p_requested_stock_id': barter.requestedStockId,
          'p_requested_quantity': barter.requestedQuantity,
          'p_requested_note': barter.requestedNote,
          'p_message': message,
        },
      );
      return Barter.fromMap(Map<String, Object?>.from(row as Map));
    }, BarterException.new);
  }

  @override
  Future<void> counterOffer(
    int barterId, {
    required int actorId,
    required double offeredQuantity,
    double? requestedQuantity,
    String? message,
    required DateTime now,
  }) => _rpc('counter_offer', {
    'p_barter_id': barterId,
    'p_offered_quantity': offeredQuantity,
    'p_requested_quantity': requestedQuantity,
    'p_message': message,
  });

  @override
  Future<void> respond(
    int barterId, {
    required int actorId,
    required bool accept,
    required DateTime now,
  }) => _rpc('respond_barter', {'p_barter_id': barterId, 'p_accept': accept});

  @override
  Future<void> cancel(
    int barterId, {
    required int actorId,
    required DateTime now,
  }) => _rpc('cancel_barter', {'p_barter_id': barterId});

  @override
  Future<void> sendMessage(
    int barterId, {
    required int senderId,
    required String text,
    required DateTime now,
  }) async {
    if (text.trim().isEmpty) return;
    await _rpc('send_barter_message', {
      'p_barter_id': barterId,
      'p_text': text.trim(),
    });
  }

  Future<void> _rpc(String function, Map<String, Object?> params) =>
      guardDb(() => supabase.rpc(function, params: params), BarterException.new);

  /// Baris view `partner_profiles` → [PartnerProfile].
  static PartnerProfile partnerFromRow(
    Map<String, Object?> row,
    AuthUser viewer,
    Map<int, List<StockItem>> stocksByUser,
  ) {
    final id = row['id']! as int;
    final lat = (row['latitude'] as num?)?.toDouble();
    final lng = (row['longitude'] as num?)?.toDouble();
    return PartnerProfile(
      userId: id,
      name: row['business_name']! as String,
      role: row['role']! as String,
      businessCategory: BusinessCategory.fromName(row['business_type'] as String?),
      address: row['address']! as String,
      whatsapp: row['whatsapp'] as String?,
      distanceKm: viewer.hasLocation && lat != null && lng != null
          ? distanceKm(viewer.latitude!, viewer.longitude!, lat, lng)
          : null,
      preferredCategories:
          FoodCategory.parseList(row['preferred_categories'] as String?),
      stocks: stocksByUser[id] ?? const [],
    );
  }
}
