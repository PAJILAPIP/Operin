import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../widgets/market_item_cards.dart';

/// Tab "Pasar B2B": flash sale & barter antar UMKM.
class MarketTab extends StatelessWidget {
  const MarketTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pasar B2B (Matchmaking)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        SizedBox(height: 16),
        FlashSaleCard(
          title: 'Sayur Campur Segar (5kg)',
          storeName: 'UMKM Warung Berkah',
          timeLeft: 'Sisa 2 Jam',
          originalPrice: 'Rp 50.000',
          price: 'Rp 20.000',
        ),
        SizedBox(height: 16),
        BarterCard(
          title: 'Minyak Goreng 2L',
          storeName: 'Kedai Makmur',
          wanted: 'Telur Ayam 1kg atau Gula Pasir 2kg.',
        ),
      ],
    );
  }
}
