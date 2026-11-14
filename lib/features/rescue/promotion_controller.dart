import 'package:flutter/widgets.dart';

import '../../core/session/session_controller.dart';
import '../../data/promotion_repository.dart';
import '../../model/promotion.dart';
import '../../model/stock_item.dart';
import '../stock/stock_controller.dart';
import 'rescue_advisor.dart';

/// Promo milik user yang sedang login + rekomendasi penyelamatan stok.
class PromotionController extends ChangeNotifier {
  PromotionController({
    required this.repository,
    required this.session,
    required this.stock,
    this.advisor = const RescueAdvisor(),
  }) {
    session.addListener(_onSessionChanged);
    stock.addListener(_onStockChanged);
    _onSessionChanged();
  }

  final PromotionRepository repository;
  final SessionController session;
  final StockController stock;
  final RescueAdvisor advisor;

  int? _userId;
  List<Promotion> _promotions = const [];
  bool _loading = false;

  bool get isLoading => _loading;
  DateTime get now => stock.now;

  /// Promo yang masih berjalan, terbaru lebih dulu.
  List<Promotion> get activePromotions =>
      _promotions.where((promo) => promo.isActiveAt(now)).toList();

  Promotion? activeForStock(int stockId) {
    for (final promo in _promotions) {
      if (promo.stockId == stockId && promo.isActiveAt(now)) return promo;
    }
    return null;
  }

  RescueRecommendation recommend(StockItem item) =>
      advisor.recommend(item, now, criticalDays: stock.criticalDays);

  /// Rekomendasi untuk semua stok yang perlu diselamatkan.
  List<RescueRecommendation> get recommendations => advisor.recommendAll(
    stock.items,
    now,
    criticalDays: stock.criticalDays,
  );

  void _onSessionChanged() {
    final userId = session.currentUser?.id;
    if (userId == _userId) return;
    _userId = userId;
    _promotions = const [];
    if (userId == null) {
      notifyListeners();
    } else {
      load();
    }
  }

  /// Stok dihapus → promonya ikut hilang (di database lewat CASCADE).
  void _onStockChanged() {
    final stockIds = {for (final item in stock.items) item.id};
    final kept = _promotions.where((p) => stockIds.contains(p.stockId));
    if (!stock.isLoading && kept.length != _promotions.length) {
      _promotions = kept.toList();
    }
    notifyListeners();
  }

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;
    _loading = true;
    notifyListeners();
    try {
      final promotions = await repository.listByUser(userId);
      if (userId != _userId) return;
      _promotions = promotions;
    } catch (error) {
      debugPrint('Gagal memuat promo: $error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Menerbitkan promo baru. Promo aktif lain untuk stok yang sama
  /// dibatalkan agar satu stok hanya punya satu promo berjalan.
  Future<Promotion> create(Promotion promotion) async {
    final existing = activeForStock(promotion.stockId);
    if (existing != null) await cancel(existing.id!);
    final saved = await repository.insert(promotion);
    _promotions = [saved, ..._promotions];
    notifyListeners();
    return saved;
  }

  Future<void> cancel(int id) async {
    await repository.updateStatus(id, PromotionStatus.cancelled);
    _promotions = [
      for (final promo in _promotions)
        promo.id == id
            ? promo.copyWith(status: PromotionStatus.cancelled)
            : promo,
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    stock.removeListener(_onStockChanged);
    super.dispose();
  }
}

class PromotionScope extends InheritedNotifier<PromotionController> {
  const PromotionScope({
    super.key,
    required PromotionController controller,
    required super.child,
  }) : super(notifier: controller);

  static PromotionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PromotionScope>();
    assert(scope != null, 'PromotionScope tidak ditemukan di atas widget ini.');
    return scope!.notifier!;
  }

  static PromotionController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<PromotionScope>();
    assert(scope != null, 'PromotionScope tidak ditemukan di atas widget ini.');
    return scope!.notifier!;
  }
}
