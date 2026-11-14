import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../model/market_order.dart';
import '../../../widgets/app_card.dart';

/// Kartu pengajuan pembelian. [incoming] true = dilihat oleh penjual.
class OrderTile extends StatelessWidget {
  const OrderTile({
    super.key,
    required this.order,
    required this.incoming,
    this.onAccept,
    this.onReject,
    this.onCancel,
    this.onComplete,
  });

  final MarketOrder order;
  final bool incoming;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  /// Penjual menandai pesanan yang sudah diterima sebagai selesai.
  final VoidCallback? onComplete;

  static Color statusColor(OrderStatus status) => switch (status) {
    OrderStatus.pending => const Color(0xFFB45309),
    OrderStatus.accepted || OrderStatus.completed => AppColors.primary,
    OrderStatus.rejected || OrderStatus.cancelled => AppColors.muted,
  };

  @override
  Widget build(BuildContext context) {
    final unit = order.unit?.label ?? '';
    final counterpart = incoming
        ? 'Dari ${order.buyerName ?? 'Pembeli'}'
        : 'Ke ${order.sellerName ?? 'Penjual'}';
    final color = statusColor(order.status);
    final isPending = order.status == OrderStatus.pending;

    return AppCard(
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.stockName ?? 'Promo #${order.promotionId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$counterpart · ${formatDate(order.createdAt)}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatQuantity(order.quantity)} $unit × '
            '${formatRupiah(order.unitPrice)} = ${formatRupiah(order.totalPrice)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          if (order.note != null && order.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"${order.note}"',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.text.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (isPending && incoming) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.redSoft),
                    ),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Terima'),
                  ),
                ),
              ],
            ),
          ],
          if (order.status == OrderStatus.accepted) ...[
            const SizedBox(height: 10),
            if (incoming && onComplete != null)
              FilledButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.task_alt, size: 18),
                label: const Text('Tandai Selesai'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              )
            else
              Text(
                incoming
                    ? 'Serahkan barang lalu tandai selesai.'
                    : 'Disetujui. Menunggu penjual menyelesaikan transaksi.',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
          ],
          if (isPending && !incoming && onCancel != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(foregroundColor: AppColors.warning),
                child: const Text('Batalkan Pengajuan'),
              ),
            ),
        ],
      ),
    );
  }
}
