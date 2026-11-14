import 'package:flutter/material.dart';

import 'core/routes/app_routes.dart';
import 'core/session/session_controller.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/auth_repository.dart';
import 'data/market_repository.dart';
import 'data/match_repository.dart';
import 'data/profile_repository.dart';
import 'data/promotion_repository.dart';
import 'data/stock_repository.dart';
import 'data/transaction_repository.dart';
import 'features/impact/transaction_controller.dart';
import 'features/market/market_controller.dart';
import 'features/matchmaking/match_controller.dart';
import 'features/rescue/promotion_controller.dart';
import 'features/stock/stock_controller.dart';

class OperinApp extends StatefulWidget {
  const OperinApp({
    super.key,
    this.authRepository = const SqliteAuthRepository(),
    this.profileRepository = const SqliteProfileRepository(),
    this.stockRepository = const SqliteStockRepository(),
    this.promotionRepository = const SqlitePromotionRepository(),
    this.marketRepository = const SqliteMarketRepository(),
    this.matchRepository = const SqliteMatchRepository(),
    this.transactionRepository = const SqliteTransactionRepository(),
    this.clock,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final StockRepository stockRepository;
  final PromotionRepository promotionRepository;
  final MarketRepository marketRepository;
  final MatchRepository matchRepository;
  final TransactionRepository transactionRepository;

  /// Sumber waktu "sekarang" (bisa diganti di test). Default: DateTime.now.
  final DateTime Function()? clock;

  /// Lebar maksimum tampilan (setara `max-w-md` di Tailwind).
  static const double maxContentWidth = 448;

  @override
  State<OperinApp> createState() => _OperinAppState();
}

class _OperinAppState extends State<OperinApp> {
  late final SessionController _session = SessionController(
    repository: widget.authRepository,
    profileRepository: widget.profileRepository,
  );
  late final StockController _stock = StockController(
    repository: widget.stockRepository,
    session: _session,
    clock: widget.clock,
  );
  late final PromotionController _promotions = PromotionController(
    repository: widget.promotionRepository,
    session: _session,
    stock: _stock,
  );
  late final MarketController _market = MarketController(
    repository: widget.marketRepository,
    session: _session,
    clock: widget.clock,
  );
  late final MatchController _match = MatchController(
    repository: widget.matchRepository,
    session: _session,
    stock: _stock,
  );
  late final TransactionController _transactions = TransactionController(
    repository: widget.transactionRepository,
    session: _session,
    stock: _stock,
    market: _market,
    match: _match,
  );

  @override
  void dispose() {
    _transactions.dispose();
    _match.dispose();
    _market.dispose();
    _promotions.dispose();
    _stock.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Operin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes(authRepository: widget.authRepository),
      // Mobile constraint wrapper: di layar lebar (web/desktop) konten
      // tetap selebar ponsel dan berada di tengah.
      builder: (context, child) => SessionScope(
        controller: _session,
        child: StockScope(
          controller: _stock,
          child: PromotionScope(
            controller: _promotions,
            child: MarketScope(
              controller: _market,
              child: MatchScope(
                controller: _match,
                child: TransactionScope(
                  controller: _transactions,
                  child: ColoredBox(
                    color: AppColors.outerBackground,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: OperinApp.maxContentWidth,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
