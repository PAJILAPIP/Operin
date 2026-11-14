import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../data/market_repository.dart';
import '../../../model/catalog_item.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../market_controller.dart';
import '../widgets/market_info_row.dart';

/// Detail stok Katalog (harga normal) dan form pengajuan pembelian.
class CatalogDetailPage extends StatefulWidget {
  const CatalogDetailPage({super.key, required this.stockId});

  final int stockId;

  @override
  State<CatalogDetailPage> createState() => _CatalogDetailPageState();
}

class _CatalogDetailPageState extends State<CatalogDetailPage> {
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit(CatalogItem item) async {
    final quantity = parseQuantity(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      return _showMessage('Jumlah harus lebih dari 0.');
    }
    if (quantity > item.availableQuantity) {
      return _showMessage(
        'Jumlah melebihi yang tersedia '
        '(${formatQuantity(item.availableQuantity)} ${item.stock.unit.label}).',
      );
    }

    final market = MarketScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final note = _noteController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      await market.requestStockPurchase(
        item,
        quantity: quantity,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Pengajuan dikirim ke ${item.sellerName}. '
            'Pantau statusnya di tab Penawaran.',
          ),
        ),
      );
    } on MarketException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      debugPrint('Gagal mengajukan pembelian katalog: $error');
      _showMessage('Gagal mengirim pengajuan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final market = MarketScope.of(context);
    final item = market.catalogItemById(widget.stockId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detail Katalog',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
      ),
      body: item == null
          ? const Center(child: Text('Stok sudah tidak tersedia.'))
          : _buildBody(item, market),
    );
  }

  Widget _buildBody(CatalogItem item, MarketController market) {
    final stock = item.stock;
    final unit = stock.unit.label;
    final pending = market.pendingOrderForStock(item.stockId);
    final quantity = parseQuantity(_quantityController.text) ?? 0;

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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.greenBadge,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Katalog · Harga normal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Icon(stock.category.icon, size: 40, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text(
                    stock.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    stock.category.label,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${formatRupiah(item.price)} /$unit',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  MarketInfoRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'Tersedia',
                    value: item.isSoldOut
                        ? 'Habis'
                        : '${formatQuantity(item.availableQuantity)} $unit',
                  ),
                  MarketInfoRow(
                    icon: Icons.event_outlined,
                    label: 'Kedaluwarsa',
                    value: '${formatDate(stock.expiryDate)} '
                        '(${stock.expiryLabel(market.now)})',
                  ),
                  if (stock.notes != null && stock.notes!.isNotEmpty)
                    MarketInfoRow(
                      icon: Icons.notes_outlined,
                      label: 'Catatan',
                      value: stock.notes!,
                    ),
                  MarketInfoRow(
                    icon: Icons.storefront_outlined,
                    label: 'Penjual',
                    value: item.sellerName,
                  ),
                  MarketInfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Alamat',
                    value: item.distanceKm == null
                        ? item.sellerAddress
                        : '${item.sellerAddress}\n'
                            '${formatDistance(item.distanceKm!)} dari Anda',
                  ),
                  if (item.sellerWhatsapp != null)
                    MarketInfoRow(
                      icon: Icons.chat_outlined,
                      label: 'WhatsApp',
                      value: '+${item.sellerWhatsapp}',
                      last: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (pending != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amberSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Anda sudah mengajukan ${formatQuantity(pending.quantity)} '
                  '$unit dan sedang menunggu jawaban penjual.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.amberText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else if (!item.isSoldOut) ...[
              AppTextField(
                controller: _quantityController,
                label: 'Jumlah dibeli ($unit)',
                hint: formatQuantity(item.availableQuantity),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _noteController,
                label: 'Catatan untuk penjual (opsional)',
                hint: 'Contoh: Ambil jam 4 sore',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Text(
                'Total: ${formatRupiah((quantity * item.price).round())}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: _isSubmitting ? 'Mengirim...' : 'Ajukan Pembelian',
                onPressed: _isSubmitting ? null : () => _submit(item),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
