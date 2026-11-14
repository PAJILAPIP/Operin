import 'package:flutter/widgets.dart';

import '../../core/session/session_controller.dart';
import '../../data/match_repository.dart';
import '../../model/barter.dart';
import '../../model/partner_profile.dart';
import '../stock/stock_controller.dart';
import 'matchmaking_engine.dart';

/// Rekomendasi mitra + daftar barter untuk user yang sedang login.
class MatchController extends ChangeNotifier {
  MatchController({
    required this.repository,
    required this.session,
    required this.stock,
    this.engine = const MatchmakingEngine(),
  }) {
    session.addListener(_onSessionChanged);
    stock.addListener(notifyListeners); // stok berubah → skor berubah
    _onSessionChanged();
  }

  final MatchRepository repository;
  final SessionController session;
  final StockController stock;
  final MatchmakingEngine engine;

  int? _userId;
  List<PartnerProfile> _partners = const [];
  List<Barter> _barters = const [];
  final Map<int, List<BarterMessage>> _messages = {};
  bool _loading = false;

  bool get isLoading => _loading;
  DateTime get now => stock.now;
  int? get userId => _userId;
  List<Barter> get barters => _barters;

  /// Mitra yang direkomendasikan, skor tertinggi lebih dulu.
  List<PartnerMatch> get matches => engine.match(
    partners: _partners,
    myStocks: stock.items,
    myPreferences: session.profile?.preferredCategories ?? const {},
    now: now,
    criticalDays: stock.criticalDays,
    radiusKm: session.profile?.radiusKm,
  );

  /// Barter yang menunggu jawaban saya.
  int get awaitingMeCount {
    final me = _userId;
    if (me == null) return 0;
    return _barters.where((b) => b.awaitingResponseFrom(me)).length;
  }

  PartnerProfile? partnerById(int userId) {
    for (final partner in _partners) {
      if (partner.userId == userId) return partner;
    }
    return null;
  }

  Barter? barterById(int id) {
    for (final barter in _barters) {
      if (barter.id == id) return barter;
    }
    return null;
  }

  List<BarterMessage> messagesOf(int barterId) =>
      _messages[barterId] ?? const [];

  void _onSessionChanged() {
    final userId = session.currentUser?.id;
    if (userId == _userId) {
      notifyListeners(); // preferensi/radius mungkin berubah
      return;
    }
    _userId = userId;
    _partners = const [];
    _barters = const [];
    _messages.clear();
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
    notifyListeners();
    try {
      final partners = await repository.listPartners(viewer: user);
      final barters = await repository.listBarters(user.id!);
      if (user.id != _userId) return;
      _partners = partners;
      _barters = barters;
    } catch (error) {
      debugPrint('Gagal memuat matchmaking: $error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(int barterId) async {
    _messages[barterId] = await repository.listMessages(barterId);
    notifyListeners();
  }

  /// Muat ulang chat barter yang pernah dibuka (dipanggil saat realtime).
  Future<void> reloadOpenMessages() async {
    for (final barterId in _messages.keys.toList()) {
      try {
        _messages[barterId] = await repository.listMessages(barterId);
      } catch (error) {
        debugPrint('Gagal memuat chat barter $barterId: $error');
      }
    }
    notifyListeners();
  }

  Future<Barter> propose(Barter barter, {String? message}) async {
    final saved = await repository.createBarter(barter, message: message);
    await load();
    return saved;
  }

  Future<void> counterOffer(
    int barterId, {
    required double offeredQuantity,
    double? requestedQuantity,
    String? message,
  }) async {
    await repository.counterOffer(
      barterId,
      actorId: _userId!,
      offeredQuantity: offeredQuantity,
      requestedQuantity: requestedQuantity,
      message: message,
      now: now,
    );
    await _refresh(barterId);
  }

  Future<void> respond(int barterId, {required bool accept}) async {
    await repository.respond(
      barterId,
      actorId: _userId!,
      accept: accept,
      now: now,
    );
    await _refresh(barterId);
  }

  Future<void> cancel(int barterId) async {
    await repository.cancel(barterId, actorId: _userId!, now: now);
    await _refresh(barterId);
  }

  Future<void> sendMessage(int barterId, String text) async {
    await repository.sendMessage(
      barterId,
      senderId: _userId!,
      text: text,
      now: now,
    );
    await _refresh(barterId);
  }

  Future<void> _refresh(int barterId) async {
    await load();
    await loadMessages(barterId);
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    stock.removeListener(notifyListeners);
    super.dispose();
  }
}

class MatchScope extends InheritedNotifier<MatchController> {
  const MatchScope({
    super.key,
    required MatchController controller,
    required super.child,
  }) : super(notifier: controller);

  static MatchController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MatchScope>();
    assert(scope != null, 'MatchScope tidak ditemukan di atas widget ini.');
    return scope!.notifier!;
  }

  static MatchController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MatchScope>();
    assert(scope != null, 'MatchScope tidak ditemukan di atas widget ini.');
    return scope!.notifier!;
  }
}
