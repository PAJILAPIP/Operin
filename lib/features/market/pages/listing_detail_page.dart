import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../data/market_repository.dart';
import '../../../model/market_listing.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../market_controller.dart';

/// Detail promo di Pasar B2B dan form pengajuan pembelian.
class ListingDetailPage extends StatefulWidget {
  const ListingDetailPage({super.key, required this.promotionId});

  final int promotionId;

  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  bool _initialized = false;
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final listing = MarketScope.read(context).listingById(widget.promotionId);
    if (listing != null) {
      _quantityController.text = formatQuantity(listing.availableQuantity);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit(MarketListing listing) async {
    final quantity = parseQuantity(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      return _showMessage('Jumlah harus lebih dari 0.');
    }
    if (quantity > listing.availableQuantity) {
      return _showMessage(
        'Jumlah melebihi yang tersedia '
        '(${formatQuantity(listing.availableQuantity)} ${listing.unit.label}).',
      );
    }

    final market = MarketScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final note = _noteController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      await market.requestPurchase(
        listing,
        quantity: quantity,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Pengajuan dikirim ke ${listing.sellerName}. '
            'Pantau statusnya di tab Penawaran.',
          ),
        ),
      );
    } on MarketException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      debugPrint('Gagal mengajukan pembelian: $error');
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
    final listing = market.listingById(widget.promotionId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detail Penawaran',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
      ),
      body: listing == null
          ? const Center(child: Text('Penawaran sudah tidak tersedia.'))
          : _buildBody(listing, market),
    );
  }

  Widget _buildBody(MarketListing listing, MarketController market) {
    final promo = listing.promotion;
    final accent = listing.isFlashSale ? AppColors.warning : AppColors.blue;
    final unit = listing.unit.label;
    final pending = market.pendingOrderFor(listing.promotionId);
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
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${promo.type.label} -${promo.discountPercent}% · '
                      '${formatTimeLeft(promo.endsAt, market.now)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Icon(listing.category.icon, size: 40, color: accent),
                  const SizedBox(height: 8),
                  Text(
                    listing.stockName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    listing.category.label,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    formatRupiah(promo.originalPrice),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedLight,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    '${formatRupiah(promo.promoPrice)} /$unit',
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
                  _Info(
                    icon: Icons.inventory_2_outlined,
                    label: 'Tersedia',
                    value: listing.isSoldOut
                        ? 'Habis'
                        : '${formatQuantity(listing.availableQuantity)} $unit',
                  ),
                  _Info(
                    icon: Icons.event_outlined,
                    label: 'Kedaluwarsa',
                    value: formatDate(listing.expiryDate),
                  ),
                  _Info(
                    icon: Icons.storefront_outlined,
                    label: 'Penjual',
                    value: listing.sellerName,
                  ),
                  _Info(
                    icon: Icons.location_on_outlined,
                    label: 'Alamat',
                    value: listing.distanceKm == null
                        ? listing.sellerAddress
                        : '${listing.sellerAddress}\n'
                            '${formatDistance(listing.distanceKm!)} dari Anda',
                  ),
                  if (listing.sellerWhatsapp != null)
                    _Info(
                      icon: Icons.chat_outlined,
                      label: 'WhatsApp',
                      value: '+${listing.sellerWhatsapp}',
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
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Anda sudah mengajukan ${formatQuantity(pending.quantity)} '
                  '$unit dan sedang menunggu jawaban penjual.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else if (!listing.isSoldOut) ...[
              AppTextField(
                controller: _quantityController,
                label: 'Jumlah dibeli ($unit)',
                hint: formatQuantity(listing.availableQuantity),
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
                'Total: ${formatRupiah((quantity * promo.promoPrice).round())}',
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
                onPressed: _isSubmitting ? null : () => _submit(listing),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.mutedLight),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
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
