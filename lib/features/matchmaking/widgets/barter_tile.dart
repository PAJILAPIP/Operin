import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../model/barter.dart';
import '../../../widgets/app_card.dart';

/// Warna badge per status barter.
Color barterStatusColor(BarterStatus status) => switch (status) {
  BarterStatus.pending => const Color(0xFFB45309),
  BarterStatus.negotiating => AppColors.blue,
  BarterStatus.accepted || BarterStatus.completed => AppColors.primary,
  BarterStatus.rejected || BarterStatus.cancelled => AppColors.muted,
};

/// Ringkasan "apa ditukar dengan apa" dari sudut pandang [viewerId].
({String give, String get}) barterSummary(Barter barter, int viewerId) {
  final offered = '${formatQuantity(barter.offeredQuantity)} '
      '${barter.offeredUnit?.label ?? ''} ${barter.offeredStockName ?? 'stok'}';
  final String requested;
  if (barter.type == BarterType.donation) {
    requested = 'Tanpa imbalan (daur ulang)';
  } else if (barter.requestedStockId != null &&
      barter.requestedQuantity != null) {
    requested = '${formatQuantity(barter.requestedQuantity!)} '
        '${barter.requestedUnit?.label ?? ''} '
        '${barter.requestedStockName ?? 'stok'}';
  } else {
    requested = barter.requestedNote ?? '-';
  }
  final iAmProposer = viewerId == barter.proposerId;
  return (
    give: iAmProposer ? offered : requested,
    get: iAmProposer ? requested : offered,
  );
}

class BarterStatusBadge extends StatelessWidget {
  const BarterStatusBadge({super.key, required this.status});

  final BarterStatus status;

  @override
  Widget build(BuildContext context) {
    final color = barterStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class BarterTile extends StatelessWidget {
  const BarterTile({
    super.key,
    required this.barter,
    required this.viewerId,
    required this.onTap,
  });

  final Barter barter;
  final int viewerId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = barterSummary(barter, viewerId);
    final awaiting = barter.awaitingResponseFrom(viewerId);

    return AppCard(
      onTap: onTap,
      radius: 14,
      padding: const EdgeInsets.all(14),
      borderColor: awaiting ? const Color(0xFFFDE68A) : AppColors.borderLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                barter.type == BarterType.donation
                    ? Icons.recycling
                    : Icons.swap_horiz,
                size: 18,
                color: AppColors.purple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  barter.otherPartyNameOf(viewerId) ?? 'Mitra',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ),
              BarterStatusBadge(status: barter.status),
            ],
          ),
          const SizedBox(height: 8),
          _Line(label: 'Anda beri', value: summary.give),
          _Line(label: 'Anda terima', value: summary.get),
          if (awaiting) ...[
            const SizedBox(height: 6),
            const Text(
              'Perlu jawaban Anda',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB45309),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
