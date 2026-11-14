import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/primary_button.dart';

/// Kartu produk flash sale di Pasar B2B.
class FlashSaleCard extends StatelessWidget {
  const FlashSaleCard({
    super.key,
    required this.title,
    required this.storeName,
    required this.timeLeft,
    required this.originalPrice,
    required this.price,
    this.onBuy,
  });

  final String title;
  final String storeName;
  final String timeLeft;
  final String originalPrice;
  final String price;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ItemHeader(
            title: title,
            storeName: storeName,
            tag: _Tag(
              label: timeLeft,
              background: AppColors.redSoft,
              foreground: AppColors.warning,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    originalPrice,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedLight,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              PrimaryButton(
                label: 'Beli Surplus',
                fullWidth: false,
                verticalPadding: 10,
                fontSize: 12,
                onPressed: onBuy ?? () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kartu barter di Pasar B2B.
class BarterCard extends StatelessWidget {
  const BarterCard({
    super.key,
    required this.title,
    required this.storeName,
    required this.wanted,
    this.onSubmit,
  });

  final String title;
  final String storeName;
  final String wanted;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ItemHeader(
            title: title,
            storeName: storeName,
            tag: const _Tag(
              label: 'Mode Barter',
              background: AppColors.blueSoft,
              foreground: AppColors.blueText,
              borderColor: Color(0xFFBFDBFE),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4B5563),
                ),
                children: [
                  const TextSpan(
                    text: 'Dicari: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: wanted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Ajukan Barter',
            color: AppColors.blue,
            verticalPadding: 10,
            fontSize: 12,
            onPressed: onSubmit ?? () {},
          ),
        ],
      ),
    );
  }
}

class _ItemHeader extends StatelessWidget {
  const _ItemHeader({
    required this.title,
    required this.storeName,
    required this.tag,
  });

  final String title;
  final String storeName;
  final Widget tag;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.storefront_outlined,
                      size: 12, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    storeName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        tag,
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.background,
    required this.foreground,
    this.borderColor,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }
}
