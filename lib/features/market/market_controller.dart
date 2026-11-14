import 'package:flutter/widgets.dart';

import '../../core/session/session_controller.dart';
import '../../data/market_repository.dart';
import '../../model/market_listing.dart';
import '../../model/market_order.dart';

/// Data Pasar B2B untuk user yang sedang login: listing promo UMKM lain
/// serta pengajuan pembelian masuk & keluar.
class MarketController extends ChangeNotifier {
  MarketController({
    required this.repository,
    required this.session,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  final MarketRepository repository;
  final SessionController session;
  final DateTime Function() _clock;

  int? _userId;
  List<MarketListing> _listings = const [];
  List<MarketOrder> _orders = const [];
  bool _loading = false;
  Object? _error;

  List<MarketListing> get listings => _listings;
  bool get isLoading => _loading;
  Object? get error => _error;
  DateTime get now => _clock();

  /// Radius preferensi dari profil usaha (km), null jika belum diatur.
  int? get radiusKm => session.profile?.radiusKm;

  /// Pengajuan dari pembeli untuk promo milik user ini.
  List<MarketOrder> get incomingOrders =>
      _orders.where((o) => o.sellerId == _userId).toList();

  /// Pengajuan yang dibuat user ini ke penjual lain.
  List<MarketOrder> get outgoingOrders =>
      _orders.where((o) => o.buyerId == _userId).toList();

  int get pendingIncomingCount => incomingOrders
      .where((order) => order.status == OrderStatus.pending)
      .length;

  MarketListing? listingById(int promotionId) {
    for (final listing in _listings) {
      if (listing.promotionId == promotionId) return listing;
    }
    return null;
  }

  /// Pengajuan user ini yang masih menunggu untuk promo tertentu.
  MarketOrder? pendingOrderFor(int promotionId) {
    for (final order in outgoingOrders) {
      if (order.promotionId == promotionId &&
          order.status == OrderStatus.pending) {
        return order;
      }
    }
    return null;
  }

  void _onSessionChanged() {
    final userId = session.currentUser?.id;
    if (userId == _userId) {
      notifyListeners(); // radius/profil mungkin berubah
      return;
    }
    _userId = userId;
    _listings = const [];
    _orders = const [];
    _error = null;
    if (userId == null) {
      notifyListeners();
    } else {
      load();
    }
  }

  Future<void> load() async {
    final user = session.currentUser;
    if (user == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        repository.listListings(viewer: user, now: now),
        repository.listOrders(user.id!),
      ]);
      if (user.id != _userId) return;
      _listings = results[0] as List<MarketListing>;
      _orders = results[1] as List<MarketOrder>;
    } catch (error) {
      debugPrint('Gagal memuat pasar: $error');
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> requestPurchase(
    MarketListing listing, {
    required double quantity,
    String? note,
  }) async {
    final user = session.currentUser;
    if (user == null) return;
    await repository.createOrder(
      promotionId: listing.promotionId,
      buyerId: user.id!,
      quantity: quantity,
      note: note,
      now: now,
    );
    await load();
  }

  Future<void> respond(int orderId, {required bool accept}) async {
    await repository.updateOrderStatus(
      orderId,
      accept ? OrderStatus.accepted : OrderStatus.rejected,
      now: now,
    );
    await load();
  }

  Future<void> cancel(int orderId) async {
    await repository.updateOrderStatus(
      orderId,
      OrderStatus.cancelled,
      now: now,
    );
    await load();
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    super.dispose();
  }
}

class MarketScope extends InheritedNotifier<MarketController> {
  const MarketScope({
    super.key,
    required MarketController controller,
    required super.child,
  }) : super(notifier: controller);

  static MarketController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MarketScope>();
    assert(scope != null, 'MarketScope tidak ditemukan di atas widget ini.');
    return scope!.notifier!;
  }

  static MarketController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MarketScope>();
    assert(scope != null, 'MarketScope tidak ditemukan di atas widget ini.');
    return scope!.notifier!;
  }
}
