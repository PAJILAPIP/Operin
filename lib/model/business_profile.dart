import '../core/utils/db_codec.dart';
import 'food_category.dart';

/// Profil & preferensi usaha, diisi saat onboarding setelah pilih peran.
class BusinessProfile {
  const BusinessProfile({
    required this.userId,
    required this.businessName,
    required this.whatsapp,
    required this.preferredCategories,
    required this.radiusKm,
    required this.notifyExpiry,
    required this.notifyDaysBefore,
    required this.updatedAt,
  });

  static const int minRadiusKm = 1;
  static const int maxRadiusKm = 20;
  static const List<int> notifyDayOptions = [1, 2, 3];

  final int userId;
  final String businessName;

  /// Nomor WhatsApp yang sudah dinormalisasi ke format 62xxxxxxxxx.
  final String whatsapp;
  final Set<FoodCategory> preferredCategories;
  final int radiusKm;
  final bool notifyExpiry;

  /// Berapa hari sebelum kedaluwarsa peringatan dikirim (H-1/H-2/H-3).
  final int notifyDaysBefore;
  final DateTime updatedAt;

  factory BusinessProfile.fromMap(Map<String, Object?> map) => BusinessProfile(
    userId: map['user_id']! as int,
    businessName: map['business_name']! as String,
    whatsapp: map['whatsapp']! as String,
    preferredCategories:
        FoodCategory.parseList(map['preferred_categories'] as String?),
    radiusKm: map['radius_km']! as int,
    notifyExpiry: decodeBool(map['notify_expiry']),
    notifyDaysBefore: map['notify_days_before']! as int,
    updatedAt: decodeTime(map['updated_at']),
  );

  Map<String, Object?> toMap() => {
    'user_id': userId,
    'business_name': businessName,
    'whatsapp': whatsapp,
    'preferred_categories': FoodCategory.encodeList(preferredCategories),
    'radius_km': radiusKm,
    'notify_expiry': notifyExpiry,
    'notify_days_before': notifyDaysBefore,
    'updated_at': encodeTime(updatedAt),
  };

  /// Mengubah input "0812-3456 7890", "+62 812..." menjadi "6281234567890".
  /// Mengembalikan null jika bukan nomor ponsel Indonesia yang valid.
  static String? normalizeWhatsapp(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    } else if (digits.startsWith('8')) {
      digits = '62$digits';
    }
    return RegExp(r'^628[0-9]{7,11}$').hasMatch(digits) ? digits : null;
  }
}
