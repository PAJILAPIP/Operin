import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../model/stock_item.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/primary_button.dart';
import '../stock_controller.dart';
import '../widgets/stock_status_badge.dart';

/// Detail satu stok dengan aksi edit & hapus.
class StockDetailPage extends StatelessWidget {
  const StockDetailPage({super.key, required this.stockId});

  final int stockId;

  Future<void> _confirmDelete(BuildContext context, StockItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus stok?'),
        content: Text('"${item.name}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final stock = StockScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await stock.delete(item.id!);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Stok "${item.name}" dihapus.')),
      );
    } catch (error) {
      debugPrint('Gagal menghapus stok: $error');
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menghapus stok. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = StockScope.of(context);
    final item = stock.byId(stockId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detail Stok',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
      ),
      body: item == null
          ? const Center(child: Text('Stok tidak ditemukan.'))
          : _DetailBody(
              item: item,
              status: stock.statusOf(item),
              now: stock.now,
              onEdit: () => Navigator.of(context).pushNamed(
                AppRoutes.stockForm,
                arguments: item,
              ),
              onDelete: () => _confirmDelete(context, item),
            ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.item,
    required this.status,
    required this.now,
    required this.onEdit,
    required this.onDelete,
  });

  final StockItem item;
  final StockStatus status;
  final DateTime now;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntilExpiry(now);
    final expiryText = days < 0
        ? 'Sudah lewat ${-days} hari'
        : days == 0
            ? 'Kedaluwarsa hari ini'
            : '$days hari lagi';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: status.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.category.icon,
                      size: 36,
                      color: status.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.category.label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StockStatusBadge(
                    status: status,
                    label: '${status.label} · ${item.expiryLabel(now)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.scale_outlined,
                    label: 'Jumlah',
                    value: '${formatQuantity(item.quantity)} ${item.unit.label}',
                  ),
                  _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Harga per ${item.unit.label}',
                    value: formatRupiah(item.pricePerUnit),
                  ),
                  _InfoRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Total nilai',
                    value: formatRupiah(item.totalValue),
                    emphasize: true,
                  ),
                  _InfoRow(
                    icon: Icons.event_outlined,
                    label: 'Kedaluwarsa',
                    value: '${formatDate(item.expiryDate)}\n$expiryText',
                    valueColor: status.foreground,
                  ),
                  if (item.notes != null)
                    _InfoRow(
                      icon: Icons.notes_outlined,
                      label: 'Catatan',
                      value: item.notes!,
                    ),
                  _InfoRow(
                    icon: Icons.update_outlined,
                    label: 'Diperbarui',
                    value: formatDate(item.updatedAt),
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Edit Stok', onPressed: onEdit),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hapus Stok'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.redSoft, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasize = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.borderLight))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.mutedLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: emphasize ? 15 : 13,
                fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
