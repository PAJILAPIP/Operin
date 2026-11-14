import 'package:flutter_test/flutter_test.dart';
import 'package:operin/core/utils/db_codec.dart';
import 'package:operin/data/auth_repository.dart';
import 'package:operin/data/market_repository.dart';
import 'package:operin/data/match_repository.dart';
import 'package:operin/data/supabase_scan_service.dart';
import 'package:operin/data/supabase_support.dart';
import 'package:operin/model/auth_user.dart';
import 'package:operin/model/business_profile.dart';
import 'package:operin/model/food_category.dart';
import 'package:operin/model/market_order.dart';
import 'package:operin/model/promotion.dart';
import 'package:operin/model/stock_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

final _viewer = AuthUser(
  id: 1,
  fullName: 'Ani',
  email: 'ani@operin.test',
  businessType: 'bakery',
  address: 'Jl A',
  createdAt: DateTime(2026, 11, 1),
  role: 'buyer',
  latitude: -6.2,
  longitude: 106.8,
);

void main() {
  group('db_codec', () {
    test('timestamptz UTC → waktu lokal, dan sebaliknya', () {
      final local = DateTime(2026, 11, 14, 9, 30);
      final encoded = encodeTime(local);
      expect(encoded, endsWith('Z'));
      expect(decodeTime(encoded), local);
      expect(decodeTime('2026-11-14T02:30:00+00:00'),
          DateTime.utc(2026, 11, 14, 2, 30).toLocal());
    });

    test('tanggal kedaluwarsa tidak bergeser hari', () {
      expect(encodeDate(DateTime(2026, 11, 17, 23, 59)), '2026-11-17');
      expect(decodeDate('2026-11-17'), DateTime(2026, 11, 17));
    });

    test('model memakai format Postgres', () {
      final stock = StockItem.fromMap({
        'id': 5,
        'user_id': 1,
        'name': 'Roti',
        'category': 'roti',
        'quantity': 10,
        'unit': 'pcs',
        'price_per_unit': 10000,
        'expiry_date': '2026-11-17',
        'notes': null,
        'created_at': '2026-11-14T02:00:00+00:00',
        'updated_at': '2026-11-14T02:00:00.123456+00:00',
      });
      expect(stock.expiryDate, DateTime(2026, 11, 17));
      expect(stock.toMap()['expiry_date'], '2026-11-17');
      expect(stock.toMap()['created_at'], '2026-11-14T02:00:00.000Z');

      final profile = BusinessProfile.fromMap({
        'user_id': 1,
        'business_name': 'Toko Ani',
        'whatsapp': '6281',
        'preferred_categories': 'roti,sayur',
        'radius_km': 10,
        'notify_expiry': true, // boolean Postgres
        'notify_days_before': 2,
        'updated_at': '2026-11-14T02:00:00+00:00',
      });
      expect(profile.notifyExpiry, isTrue);
      expect(profile.toMap()['notify_expiry'], isTrue);
    });
  });

  test('baris market_listings → MarketListing dengan jarak', () {
    final listing = SupabaseMarketRepository.listingFromRow({
      'id': 3,
      'user_id': 2,
      'stock_id': 5,
      'type': 'flashSale',
      'discount_percent': 40,
      'original_price': 10000,
      'quantity': 10,
      'created_at': '2026-11-14T02:00:00+00:00',
      'ends_at': '2026-11-15T02:00:00+00:00',
      'status': 'active',
      'stock_name': 'Roti',
      'stock_category': 'roti',
      'stock_unit': 'pcs',
      'stock_expiry': '2026-11-16',
      'seller_full_name': 'Budi',
      'seller_business_name': null,
      'seller_address': 'Jl B',
      'seller_lat': -6.21,
      'seller_lng': 106.8,
      'seller_whatsapp': null,
      'reserved': 4,
    }, _viewer);

    expect(listing.promotionId, 3);
    expect(listing.isFlashSale, isTrue);
    expect(listing.promotion.promoPrice, 6000);
    expect(listing.sellerName, 'Budi'); // fallback ke nama pemilik
    expect(listing.category, FoodCategory.roti);
    expect(listing.expiryDate, DateTime(2026, 11, 16));
    expect(listing.availableQuantity, 6);
    expect(listing.distanceKm, closeTo(1.11, 0.01));
  });

  test('baris catalog_items → CatalogItem', () {
    final item = SupabaseMarketRepository.catalogItemFromRow({
      'id': 50,
      'user_id': 2,
      'name': 'Beras',
      'category': 'bahanKering',
      'quantity': 20,
      'unit': 'kg',
      'price_per_unit': 12000,
      'expiry_date': '2026-12-30',
      'notes': null,
      'created_at': '2026-11-14T02:00:00+00:00',
      'updated_at': '2026-11-14T02:00:00+00:00',
      'seller_full_name': 'Budi',
      'seller_business_name': 'Dapur Budi',
      'seller_address': 'Jl B',
      'seller_lat': null,
      'seller_lng': null,
      'seller_whatsapp': '6282',
      'reserved': 5,
    }, _viewer);
    expect(item.stockId, 50);
    expect(item.sellerName, 'Dapur Budi');
    expect(item.price, 12000);
    expect(item.availableQuantity, 15);
    expect(item.distanceKm, isNull);
  });

  test('baris partner_profiles → PartnerProfile', () {    final partner = SupabaseMatchRepository.partnerFromRow(
      {
        'id': 2,
        'full_name': 'Budi',
        'role': 'waste',
        'business_type': 'katering',
        'address': 'Jl B',
        'latitude': null,
        'longitude': null,
        'business_name': 'Dapur Budi',
        'whatsapp': '6282',
        'preferred_categories': 'sayur',
      },
      _viewer,
      const {},
    );
    expect(partner.name, 'Dapur Budi');
    expect(partner.distanceKm, isNull); // mitra belum menandai lokasi
    expect(partner.preferredCategories, {FoodCategory.sayur});
    expect(partner.stocks, isEmpty);
  });

  test('hasil RPC create_order → MarketOrder', () {
    final order = MarketOrder.fromMap({
      'id': 9,
      'promotion_id': 3,
      'buyer_id': 1,
      'seller_id': 2,
      'quantity': 4,
      'unit_price': 6000,
      'status': 'pending',
      'note': null,
      'stock_id': 5,
      'created_at': '2026-11-14T02:00:00+00:00',
      'updated_at': '2026-11-14T02:00:00+00:00',
    });
    expect(order.status, OrderStatus.pending);
    expect(order.totalPrice, 24000);
    expect(order.stockId, 5);
    expect(order.isCatalogOrder, isFalse);
    expect(PromotionType.fromName('flashSale'), PromotionType.flashSale);
  });

  group('pesan error', () {
    test('error RPC (P0001) dipakai apa adanya', () {
      expect(
        friendlyDbMessage(const sb.PostgrestException(
          message: 'Tidak bisa membeli promo sendiri.',
          code: 'P0001',
        )),
        'Tidak bisa membeli promo sendiri.',
      );
      expect(
        friendlyDbMessage(const sb.PostgrestException(
          message: 'new row violates row-level security policy',
          code: '42501',
        )),
        'Akses ditolak.',
      );
      expect(
        friendlyDbMessage(const sb.PostgrestException(
          message: 'JWT expired',
          code: 'PGRST301',
        )),
        contains('Sesi berakhir'),
      );
    });

    test('guardDb membungkus ke exception domain', () async {
      await expectLater(
        guardDb<void>(
          () async => throw const sb.PostgrestException(
            message: 'Promo sudah berakhir.',
            code: 'P0001',
          ),
          MarketException.new,
        ),
        throwsA(isA<MarketException>()
            .having((e) => e.message, 'message', 'Promo sudah berakhir.')),
      );
    });

    test('Supabase Auth → bahasa Indonesia', () {
      String msg(String message, String? code) => SupabaseAuthRepository
          .authMessage(sb.AuthException(message, code: code));
      expect(msg('Invalid login credentials', 'invalid_credentials'),
          'Email atau password salah.');
      expect(msg('User already registered', 'user_already_exists'),
          'Email sudah terdaftar.');
      expect(msg('Email not confirmed', 'email_not_confirmed'),
          contains('belum dikonfirmasi'));
      expect(msg('Password should be at least 6 characters', 'weak_password'),
          contains('minimal 6'));
      expect(
        SupabaseAuthRepository.authMessage(
          sb.AuthRetryableFetchException(message: 'offline'),
        ),
        networkErrorMessage,
      );
    });

    test('Edge Function scan-food: status → pesan', () {
      expect(
        SupabaseScanService.functionErrorMessage(
          429,
          {'error': 'Batas pemakaian AI tercapai. Coba lagi beberapa saat.'},
        ),
        contains('Batas pemakaian'),
      );
      expect(SupabaseScanService.functionErrorMessage(404, null),
          contains('belum di-deploy'));
      expect(SupabaseScanService.functionErrorMessage(401, 'x'),
          contains('Sesi berakhir'));
    });
  });

  test('jawaban Edge Function scan-food → ScanResult', () {
    final result = SupabaseScanService.parseResponse({
      'choices': [
        {
          'message': {
            'content': '{"is_food": true, "items": [{"name": "Apel", '
                '"category": "buah", "quality": "A", "freshness_score": 90, '
                '"unit": "kg", "shelf_life_days": 7}]}',
          },
        },
      ],
    }, DateTime(2026, 11, 14));
    expect(result.items.single.name, 'Apel');
    expect(result.items.single.expiryDate, DateTime(2026, 11, 21));
  });
}
