import 'package:flutter/material.dart';

/// Kategori bahan makanan yang diminati UMKM (preferensi matchmaking).
enum FoodCategory {
  sayur('Sayur', Icons.grass_outlined),
  buah('Buah', Icons.apple_outlined),
  roti('Roti & Kue', Icons.bakery_dining_outlined),
  dagingIkan('Daging & Ikan', Icons.set_meal_outlined),
  susuOlahan('Susu & Olahan', Icons.egg_outlined),
  bahanKering('Bahan Kering', Icons.inventory_2_outlined),
  makananJadi('Makanan Jadi', Icons.lunch_dining_outlined);

  const FoodCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Mengurai string "sayur,buah" dari database. Nilai tak dikenal diabaikan.
  static Set<FoodCategory> parseList(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final names = raw.split(',');
    return values.where((v) => names.contains(v.name)).toSet();
  }

  static String encodeList(Iterable<FoodCategory> categories) =>
      categories.map((c) => c.name).join(',');
}
