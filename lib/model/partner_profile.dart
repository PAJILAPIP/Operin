import 'business_category.dart';
import 'food_category.dart';
import 'stock_item.dart';

/// UMKM lain yang bisa menjadi mitra matchmaking (read model).
class PartnerProfile {
  const PartnerProfile({
    required this.userId,
    required this.name,
    required this.role,
    required this.businessCategory,
    required this.address,
    this.whatsapp,
    this.distanceKm,
    required this.preferredCategories,
    required this.stocks,
  });

  final int userId;

  /// Nama usaha.
  final String name;

  /// Nama enum `UserRole` (seller / buyer / waste).
  final String role;
  final BusinessCategory businessCategory;
  final String address;
  final String? whatsapp;
  final double? distanceKm;
  final Set<FoodCategory> preferredCategories;

  /// Stok milik mitra.
  final List<StockItem> stocks;

  bool get isRecyclePartner => role == 'waste';
}
