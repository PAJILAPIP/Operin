import 'package:flutter/widgets.dart';

import '../../core/session/session_controller.dart';
import '../../data/stock_repository.dart';
import '../../model/stock_item.dart';

/// Daftar stok milik user yang sedang login.
///
/// Mengikuti [SessionController]: memuat ulang saat user berganti dan
/// mengosongkan daftar saat logout.
class StockController extends ChangeNotifier {
  StockController({
    required this.repository,
    required this.session,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  final StockRepository repository;
  final SessionController session;
  final DateTime Function() _clock;

  int? _userId;
  List<StockItem> _items = const [];
  bool _loading = false;
  Object? _error;

  /// Stok yang masih ada (jumlah > 0), urut dari yang paling cepat
  /// kedaluwarsa. Stok yang habis lewat transaksi tetap disimpan di database
  /// (dirujuk riwayat order/barter) tetapi tidak ditampilkan.
  List<StockItem> get items =>
      _items.where((item) => item.quantity > 0).toList();
  bool get isLoading => _loading;
  Object? get error => _error;
  DateTime get now => _clock();

  /// Ambang status "Kritis" mengikuti pengaturan notifikasi di profil usaha.
  int get criticalDays =>
      session.profile?.notifyDaysBefore ?? StockItem.defaultCriticalDays;

  StockStatus statusOf(StockItem item) =>
      item.statusAt(now, criticalDays: criticalDays);

  /// Stok kedaluwarsa atau kritis.
  List<StockItem> get urgentItems =>
      items.where((item) => statusOf(item).needsAction).toList();

  StockItem? byId(int id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _onSessionChanged() {
    final userId = session.currentUser?.id;
    if (userId == _userId) {
      // Profil (ambang kritis) mungkin berubah.
      notifyListeners();
      return;
    }
    _userId = userId;
    _items = const [];
    _error = null;
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
    _error = null;
    notifyListeners();
    try {
      final items = await repository.listByUser(userId);
      if (userId != _userId) return; // user sudah berganti
      _items = items;
    } catch (error) {
      debugPrint('Gagal memuat stok: $error');
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<StockItem> add(StockItem item) async {
    final saved = await repository.insert(item);
    _items = _sorted([..._items, saved]);
    notifyListeners();
    return saved;
  }

  Future<StockItem> update(StockItem item) async {
    final saved = await repository.update(item);
    _items = _sorted([
      for (final existing in _items)
        if (existing.id == saved.id) saved else existing,
    ]);
    notifyListeners();
    return saved;
  }

  Future<void> delete(int id) async {
    await repository.delete(id);
    _items = _items.where((item) => item.id != id).toList();
    notifyListeners();
  }

  static List<StockItem> _sorted(List<StockItem> items) => items
    ..sort((a, b) {
      final byDate = a.expiryDate.compareTo(b.expiryDate);
      return byDate != 0
          ? byDate
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    super.dispose();
  }
}

class StockScope extends InheritedNotifier<StockController> {
  const StockScope({
    super.key,
    required StockController controller,
    required super.child,
  }) : super(notifier: controller);

  static StockController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StockScope>();
    assert(scope != null, 'StockScope tidak ditemukan di atas widget ini.');
    return scope!.notifier!;
  }

  static StockController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<StockScope>();
    assert(scope != null, 'StockScope tidak ditemukan di atas widget ini.');
    return scope!.notifier!;
  }
}
