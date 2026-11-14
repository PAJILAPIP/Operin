import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../model/stock_item.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_text_field.dart';
import '../../stock/stock_controller.dart';
import '../../stock/widgets/stock_list_tile.dart';
import '../../stock/widgets/stock_status_badge.dart';

/// Tab "Stok": daftar stok dengan pencarian dan filter status.
class StockTab extends StatefulWidget {
  const StockTab({super.key});

  @override
  State<StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<StockTab> {
  String _query = '';

  /// null = semua status.
  StockStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final stock = StockScope.of(context);
    final now = stock.now;

    final counts = {for (final status in StockStatus.values) status: 0};
    for (final item in stock.items) {
      counts.update(stock.statusOf(item), (count) => count + 1);
    }

    final query = _query.trim().toLowerCase();
    final visible = stock.items.where((item) {
      if (_filter != null && stock.statusOf(item) != _filter) return false;
      return query.isEmpty || item.name.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Stok Saya',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ),
            Text(
              '${stock.items.length} item',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          hint: 'Cari nama bahan',
          icon: Icons.search,
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'Semua',
                count: stock.items.length,
                selected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              for (final status in StockStatus.values)
                _FilterChip(
                  label: status.label,
                  count: counts[status]!,
                  color: status.foreground,
                  selected: _filter == status,
                  onTap: () => setState(
                    () => _filter = _filter == status ? null : status,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (stock.isLoading && stock.items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (stock.error != null && stock.items.isEmpty)
          _EmptyState(
            icon: Icons.error_outline,
            title: 'Gagal memuat stok',
            message: 'Periksa penyimpanan perangkat lalu coba lagi.',
            action: TextButton(
              onPressed: stock.load,
              child: const Text('Coba lagi'),
            ),
          )
        else if (stock.items.isEmpty)
          const _EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Belum ada stok',
            message: 'Tekan "Tambah Stok" untuk mencatat bahan pertama Anda.',
          )
        else if (visible.isEmpty)
          const _EmptyState(
            icon: Icons.search_off,
            title: 'Tidak ada yang cocok',
            message: 'Ubah kata kunci atau filter status.',
          )
        else
          for (final item in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StockListTile(
                item: item,
                status: stock.statusOf(item),
                now: now,
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.stockDetail,
                  arguments: item.id,
                ),
              ),
            ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label ($count)'),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: color.withValues(alpha: 0.12),
        side: BorderSide(color: selected ? color : AppColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? color : AppColors.text,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.mutedLight),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}
