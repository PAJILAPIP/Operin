import 'package:flutter/material.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../model/promotion.dart';
import '../../../model/stock_item.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../../stock/stock_controller.dart';
import '../../stock/widgets/stock_status_badge.dart';
import '../promotion_controller.dart';
import '../rescue_advisor.dart';

/// Form menerbitkan promo (diskon / flash sale) untuk satu stok, terisi
/// otomatis dengan rekomendasi [RescueAdvisor].
class PromotionFormPage extends StatefulWidget {
  const PromotionFormPage({super.key, required this.stockId});

  final int stockId;

  static const List<int> flashSaleHourOptions = [2, 4, 6, 12];

  @override
  State<PromotionFormPage> createState() => _PromotionFormPageState();
}

class _PromotionFormPageState extends State<PromotionFormPage> {
  final _quantityController = TextEditingController();
  late int _discount;
  late PromotionType _type;
  int _flashHours = 4;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final item = StockScope.read(context).byId(widget.stockId);
    if (item == null) return;
    final rec = PromotionScope.read(context).recommend(item);
    _discount = rec.discountPercent
        .clamp(Promotion.minDiscount, Promotion.maxDiscount);
    _type = rec.action == RescueAction.flashSale
        ? PromotionType.flashSale
        : PromotionType.discount;
    _quantityController.text = formatQuantity(item.quantity);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  /// Promo berakhir paling lambat di akhir hari kedaluwarsa.
  DateTime _endsAt(StockItem item, DateTime now) {
    final endOfExpiry = DateTime(
      item.expiryDate.year,
      item.expiryDate.month,
      item.expiryDate.day + 1,
    );
    if (_type == PromotionType.discount) return endOfExpiry;
    final flashEnd = now.add(Duration(hours: _flashHours));
    return flashEnd.isBefore(endOfExpiry) ? flashEnd : endOfExpiry;
  }

  Future<void> _submit(StockItem item) async {
    final quantity = parseQuantity(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      return _showMessage('Jumlah promo harus lebih dari 0.');
    }
    if (quantity > item.quantity) {
      return _showMessage(
        'Jumlah promo melebihi stok '
        '(${formatQuantity(item.quantity)} ${item.unit.label}).',
      );
    }

    final promotions = PromotionScope.read(context);
    final user = SessionScope.read(context).currentUser;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (user == null) return;

    final now = promotions.now;
    setState(() => _isSaving = true);
    try {
      await promotions.create(
        Promotion(
          userId: user.id!,
          stockId: item.id!,
          type: _type,
          discountPercent: _discount,
          originalPrice: item.pricePerUnit,
          quantity: quantity,
          createdAt: now,
          endsAt: _endsAt(item, now),
        ),
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${_type.label} -$_discount% untuk "${item.name}" diterbitkan.',
          ),
        ),
      );
    } catch (error) {
      debugPrint('Gagal membuat promo: $error');
      _showMessage('Gagal menerbitkan promo. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final stock = StockScope.of(context);
    final promotions = PromotionScope.of(context);
    final item = stock.byId(widget.stockId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Buat Promo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
      ),
      body: item == null
          ? const Center(child: Text('Stok tidak ditemukan.'))
          : _buildForm(item, promotions.recommend(item), promotions.now),
    );
  }

  Widget _buildForm(StockItem item, RescueRecommendation rec, DateTime now) {
    final canPromote = item.daysUntilExpiry(now) >= 0;
    final quantity = parseQuantity(_quantityController.text) ?? 0;
    final promoPrice =
        Promotion.priceAfterDiscount(item.pricePerUnit, _discount);
    final endsAt = _endsAt(item, now);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Row(
                children: [
                  Icon(item.category.icon, color: rec.status.foreground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          '${formatQuantity(item.quantity)} ${item.unit.label}'
                          ' · ${formatRupiah(item.pricePerUnit)}/${item.unit.label}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StockStatusBadge(
                    status: rec.status,
                    label: item.expiryLabel(now),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.blueSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 18, color: AppColors.blueText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      canPromote
                          ? 'Rekomendasi: ${rec.action.label} '
                              '${rec.discountPercent}%. ${rec.reason}'
                          : rec.reason,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.blueText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (canPromote) ...[
              const SizedBox(height: 20),
              const _Label('Jenis Promo'),
              SegmentedButton<PromotionType>(
                segments: [
                  for (final type in PromotionType.values)
                    ButtonSegment(value: type, label: Text(type.label)),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _type = value.first),
              ),
              if (_type == PromotionType.flashSale) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final hours in PromotionFormPage.flashSaleHourOptions)
                      ChoiceChip(
                        label: Text('$hours jam'),
                        selected: _flashHours == hours,
                        onSelected: (_) => setState(() => _flashHours = hours),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              _Label('Diskon: $_discount%'),
              Slider(
                value: _discount.toDouble(),
                min: Promotion.minDiscount.toDouble(),
                max: Promotion.maxDiscount.toDouble(),
                divisions: (Promotion.maxDiscount - Promotion.minDiscount) ~/ 5,
                label: '$_discount%',
                activeColor: AppColors.primary,
                onChanged: (value) =>
                    setState(() => _discount = value.round()),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: _quantityController,
                label: 'Jumlah dipromosikan (${item.unit.label})',
                hint: formatQuantity(item.quantity),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _PreviewCard(
                originalPrice: item.pricePerUnit,
                promoPrice: promoPrice,
                unit: item.unit.label,
                income: (quantity * promoPrice).round(),
                lossIfWasted: (quantity * item.pricePerUnit).round(),
                endsAt: endsAt,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isSaving ? 'Menerbitkan...' : 'Terbitkan Promo',
                onPressed: _isSaving ? null : () => _submit(item),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.originalPrice,
    required this.promoPrice,
    required this.unit,
    required this.income,
    required this.lossIfWasted,
    required this.endsAt,
  });

  final int originalPrice;
  final int promoPrice;
  final String unit;
  final int income;
  final int lossIfWasted;
  final DateTime endsAt;

  @override
  Widget build(BuildContext context) {
    final time =
        '${endsAt.hour.toString().padLeft(2, '0')}:${endsAt.minute.toString().padLeft(2, '0')}';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pratinjau',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text.rich(
                TextSpan(
                  text: formatRupiah(promoPrice),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  children: [
                    TextSpan(
                      text: ' /$unit',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatRupiah(originalPrice),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedLight,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _row('Pemasukan jika habis terjual', formatRupiah(income),
              AppColors.primary),
          const SizedBox(height: 6),
          _row('Kerugian jika terbuang', formatRupiah(lossIfWasted),
              AppColors.warning),
          const SizedBox(height: 6),
          _row('Berakhir', '${formatDate(endsAt)} $time', AppColors.text),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    ],
  );
}
