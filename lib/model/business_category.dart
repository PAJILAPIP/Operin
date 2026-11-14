import 'package:flutter/material.dart';

/// Jenis usaha UMKM, disimpan di `users.business_type` sebagai [name].
enum BusinessCategory {
  warungMakan('Warung Makan', Icons.ramen_dining_outlined),
  restoran('Restoran', Icons.restaurant_outlined),
  kafe('Kafe / Kedai Kopi', Icons.local_cafe_outlined),
  katering('Katering', Icons.room_service_outlined),
  bakery('Toko Roti / Bakery', Icons.bakery_dining_outlined),
  tokoBuahSayur('Toko Buah & Sayur', Icons.eco_outlined),
  supermarket('Supermarket / Minimarket', Icons.local_grocery_store_outlined),
  distributor('Distributor / Grosir', Icons.local_shipping_outlined),
  lainnya('Lainnya', Icons.storefront_outlined);

  const BusinessCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Mengembalikan kategori dari nama tersimpan, atau [lainnya] jika tidak
  /// dikenal.
  static BusinessCategory fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return lainnya;
  }
}
