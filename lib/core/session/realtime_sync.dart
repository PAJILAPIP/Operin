import 'package:flutter/foundation.dart';

import '../../data/realtime_service.dart';
import '../../features/impact/transaction_controller.dart';
import '../../features/market/market_controller.dart';
import '../../features/matchmaking/match_controller.dart';
import '../../features/stock/stock_controller.dart';
import 'session_controller.dart';

/// Selama user login, berlangganan perubahan pesanan, promo, barter, dan
/// chat di server; saat ada perubahan (dari HP lain), data terkait dimuat
/// ulang sehingga tampil tanpa menekan tombol muat ulang.
class RealtimeSync {
  RealtimeSync({
    required this.service,
    required this.session,
    required this.stock,
    required this.market,
    required this.match,
    required this.transactions,
  }) {
    session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  static const tables = ['orders', 'promotions', 'barters', 'barter_messages'];

  final RealtimeService service;
  final SessionController session;
  final StockController stock;
  final MarketController market;
  final MatchController match;
  final TransactionController transactions;

  int? _userId;
  VoidCallback? _stop;

  void _onSessionChanged() {
    final userId = session.currentUser?.id;
    if (userId == _userId) return;
    _userId = userId;
    _stop?.call();
    _stop = userId == null ? null : service.watch(tables, _refresh);
  }

  void _refresh() {
    if (session.currentUser == null) return;
    // Pesanan/barter selesai di HP lain juga mengubah stok & riwayat.
    stock.load();
    market.load();
    match.load();
    match.reloadOpenMessages();
    transactions.load();
  }

  void dispose() {
    session.removeListener(_onSessionChanged);
    _stop?.call();
  }
}
