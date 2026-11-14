import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operin/core/utils/formatters.dart';
import 'package:operin/core/utils/geo.dart';
import 'package:operin/data/auth_repository.dart';
import 'package:operin/data/local_database.dart';
import 'package:operin/data/market_repository.dart';
import 'package:operin/data/promotion_repository.dart';
import 'package:operin/data/stock_repository.dart';
import 'package:operin/model/food_category.dart';
import 'package:operin/model/market_order.dart';
import 'package:operin/model/promotion.dart';
import 'package:operin/model/stock_item.dart';

void main() {
  group('geo', () {
    test('jarak haversine', () {
      expect(distanceKm(-0.95, 100.35, -0.95, 100.35), 0);
      // 0,01° lintang ≈ 1,11 km
      expect(distanceKm(-0.95, 100.35, -0.94, 100.35), closeTo(1.11, 0.01));
      // Padang → Bukittinggi ± 70 km garis lurus
      expect(distanceKm(-0.9471, 100.4172, -0.3056, 100.3692),
          closeTo(71, 2));
    });

    test('format jarak & sisa waktu', () {
      expect(formatDistance(0.35), '350 m');
      expect(formatDistance(2.46), '2,5 km');
      final now = DateTime(2026, 11, 14, 10);
      expect(formatTimeLeft(now.add(const Duration(minutes: 30)), now),
          'Sisa 30 menit');
      expect(formatTimeLeft(now.add(const Duration(hours: 3)), now),
          'Sisa 3 jam');
      expect(formatTimeLeft(now.add(const Duration(days: 2)), now),
          'Sisa 2 hari');
      expect(formatTimeLeft(now.subtract(const Duration(minutes: 1)), now),
          'Berakhir');
    });
  });

  test('SqliteMarketRepository: listing, pengajuan, dan validasi stok',
      () async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const auth = SqliteAuthRepository();
    const stocks = SqliteStockRepository();
    const promotions = SqlitePromotionRepository();
    const market = SqliteMarketRepository();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final emails = ['seller-$stamp@operin.test', 'buyer-$stamp@operin.test'];
    final now = DateTime(2026, 11, 14, 10);

    try {
      final seller = await auth.register(
        fullName: 'Penjual',
        email: emails[0],
        password: 'password123',
        businessType: 'bakery',
        address: 'Jl. A',
        latitude: -0.95,
        longitude: 100.35,
      );
      final buyer = await auth.register(
        fullName: 'Pembeli',
        email: emails[1],
        password: 'password123',
        businessType: 'katering',
        address: 'Jl. B',
        latitude: -0.94,
        longitude: 100.35,
      );
      final stock = await stocks.insert(StockItem(
        userId: seller.id!,
        name: 'Roti Gandum',
        category: FoodCategory.roti,
        quantity: 20,
        unit: StockUnit.pcs,
        pricePerUnit: 10000,
        expiryDate: DateTime(2026, 11, 15),
        createdAt: now,
        updatedAt: now,
      ));
      final promo = await promotions.insert(Promotion(
        userId: seller.id!,
        stockId: stock.id!,
        type: PromotionType.discount,
        discountPercent: 50,
        originalPrice: 10000,
        quantity: 10,
        createdAt: now,
        endsAt: DateTime(2026, 11, 16),
      ));

      // Pembeli melihat promo penjual, lengkap dengan jarak
      final listings = await market.listListings(viewer: buyer, now: now);
      final listing = listings.singleWhere((l) => l.promotionId == promo.id);
      expect(listing.stockName, 'Roti Gandum');
      expect(listing.sellerName, 'Penjual'); // belum ada profil usaha
      expect(listing.distanceKm, closeTo(1.11, 0.01));
      expect(listing.availableQuantity, 10);
      // Penjual tidak melihat promonya sendiri
      final own = await market.listListings(viewer: seller, now: now);
      expect(own.where((l) => l.promotionId == promo.id), isEmpty);

      // Validasi pengajuan
      Future<MarketOrder> order(double qty, {int? buyerId, DateTime? at}) =>
          market.createOrder(
            promotionId: promo.id!,
            buyerId: buyerId ?? buyer.id!,
            quantity: qty,
            now: at ?? now,
          );
      await expectLater(order(11), throwsA(isA<MarketException>()));
      await expectLater(
        order(1, buyerId: seller.id),
        throwsA(isA<MarketException>()),
      );
      await expectLater(
        order(1, at: DateTime(2026, 11, 16, 1)),
        throwsA(isA<MarketException>()),
      );

      final first = await order(4);
      expect(first.unitPrice, 5000);
      expect(first.sellerId, seller.id);

      // Diterima → mengurangi jumlah tersedia
      await market.updateOrderStatus(first.id!, OrderStatus.accepted, now: now);
      final after = await market.listListings(viewer: buyer, now: now);
      expect(
        after.singleWhere((l) => l.promotionId == promo.id).availableQuantity,
        6,
      );
      await expectLater(order(7), throwsA(isA<MarketException>()));

      // Status final tidak bisa diubah lagi
      final second = await order(6);
      await market.updateOrderStatus(second.id!, OrderStatus.cancelled,
          now: now);
      await expectLater(
        market.updateOrderStatus(second.id!, OrderStatus.accepted, now: now),
        throwsA(isA<MarketException>()),
      );

      // Daftar pengajuan untuk penjual berisi nama stok & pembeli
      final sellerOrders = await market.listOrders(seller.id!);
      expect(sellerOrders, hasLength(2));
      expect(sellerOrders.first.stockName, 'Roti Gandum');
      expect(sellerOrders.first.buyerName, 'Pembeli');
      expect(sellerOrders.first.unit, StockUnit.pcs);
    } finally {
      final database = await LocalDatabase.instance.database;
      for (final email in emails) {
        await database.delete('users', where: 'email = ?', whereArgs: [email]);
      }
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });
}
