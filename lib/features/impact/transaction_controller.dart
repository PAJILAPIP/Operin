import 'package:flutter/widgets.dart';

import '../../core/session/session_controller.dart';
import '../../data/transaction_repository.dart';
import '../../model/activity_entry.dart';
import '../market/market_controller.dart';
import '../matchmaking/match_controller.dart';
import '../stock/stock_controller.dart';
import 'impact_calculator.dart';

/// Penyelesaian transaksi + riwayat aktivitas + ringkasan dampak user.
class TransactionController extends ChangeNotifier {
  TransactionController({
    required this.repository,
    required this.session,
    required this.stock,
    required this.market,
    required this.match,
    this.calculator = const ImpactCalculator(),
  }) {
    session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  final TransactionRepository repository;
  final SessionController session;
  final StockController stock;
  final MarketController market;
  final MatchController match;
  final ImpactCalculator calculator;

  int? _userId;
  List<ActivityEntry> _entries = const [];
  ImpactSummary? _summary;
  bool _loading = false;

  bool get isLoading => _loading;
  DateTime get now => stock.now;

  /// Riwayat aktivitas, terbaru lebih dulu.
  List<ActivityEntry> get entries => _entries;

  ImpactSummary get summary =>
      _summary ??= calculator.compute(_entries, now);

  void _onSessionChanged() {
    final userId = session.currentUser?.id;
    if (userId == _userId) return;
    _userId = userId;
    _entries = const [];
    _summary = null;
    if (userId == null) {
      notifyListeners();
    } else {
      load();
    }
  }

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;
    _loading = true;
    notifyListeners();
    try {
      final entries = await repository.listActivity(userId);
      if (userId != _userId) return;
      _entries = entries;
      _summary = null;
    } catch (error) {
      debugPrint('Gagal memuat riwayat: $error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Penjual menyelesaikan pesanan pasar yang sudah diterima.
  Future<void> completeOrder(int orderId) async {
    await repository.completeOrder(orderId, actorId: _userId!, now: now);
    await _refreshAll();
  }

  /// Salah satu pihak menyelesaikan barter/donasi yang sudah disepakati.
  Future<void> completeBarter(int barterId) async {
    await repository.completeBarter(barterId, actorId: _userId!, now: now);
    await _refreshAll();
    await match.loadMessages(barterId);
  }

  Future<void> _refreshAll() => Future.wait([
    load(),
    stock.load(),
    market.load(),
    match.load(),
  ]);

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    super.dispose();
  }
}

class TransactionScope extends InheritedNotifier<TransactionController> {
  const TransactionScope({
    super.key,
    required TransactionController controller,
    required super.child,
  }) : super(notifier: controller);

  static TransactionController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<TransactionScope>();
    assert(scope != null, 'TransactionScope tidak ditemukan di atas widget ini.');
    return scope!.notifier!;
  }

  static TransactionController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<TransactionScope>();
    assert(scope != null, 'TransactionScope tidak ditemukan di atas widget ini.');
    return scope!.notifier!;
  }
}
