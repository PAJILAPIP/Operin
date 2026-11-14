import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/match_repository.dart';
import '../../../model/barter.dart';
import '../../../model/stock_item.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../../stock/stock_controller.dart';
import '../match_controller.dart';
import '../widgets/partner_match_card.dart';

class BarterFormArgs {
  const BarterFormArgs({
    required this.partnerId,
    required this.type,
    this.offeredStockId,
    this.requestedStockId,
  });

  final int partnerId;
  final BarterType type;
  final int? offeredStockId;
  final int? requestedStockId;
}

/// Form mengajukan barter (atau menyalurkan stok ke mitra daur ulang).
class BarterFormPage extends StatefulWidget {
  const BarterFormPage({super.key, required this.args});

  final BarterFormArgs args;

  @override
  State<BarterFormPage> createState() => _BarterFormPageState();
}

class _BarterFormPageState extends State<BarterFormPage> {
  /// Nilai dropdown "minta bahan lain (tulis sendiri)".
  static const int _customRequest = -1;

  final _offeredQtyController = TextEditingController();
  final _requestedQtyController = TextEditingController();
  final _requestedNoteController = TextEditingController();
  final _messageController = TextEditingController();
  int? _offeredStockId;
  int? _requestedStockId;
  bool _initialized = false;
  bool _isSubmitting = false;

  bool get _isDonation => widget.args.type == BarterType.donation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final mine = _myStocks(StockScope.read(context));
    final partner = MatchScope.read(context).partnerById(widget.args.partnerId);
    final theirs = partner == null ? <StockItem>[] : _theirStocks(partner.stocks);

    final offered = mine.where((s) => s.id == widget.args.offeredStockId);
    _selectOffered(offered.isNotEmpty ? offered.first : mine.firstOrNull);

    if (!_isDonation) {
      final requested = theirs.where((s) => s.id == widget.args.requestedStockId);
      _selectRequested(
        requested.isNotEmpty
            ? requested.first
            : theirs.firstOrNull,
      );
      _requestedStockId ??= _customRequest;
    }
  }

  @override
  void dispose() {
    _offeredQtyController.dispose();
    _requestedQtyController.dispose();
    _requestedNoteController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Barter: stok yang belum kedaluwarsa. Donasi: stok kedaluwarsa (atau
  /// stok yang dipilih dari halaman penyelamatan).
  List<StockItem> _myStocks(StockController stock) {
    final now = stock.now;
    return stock.items.where((item) {
      if (item.id == widget.args.offeredStockId) return true;
      final expired = item.daysUntilExpiry(now) < 0;
      return _isDonation ? expired : !expired;
    }).toList();
  }

  List<StockItem> _theirStocks(List<StockItem> stocks) {
    final now = StockScope.read(context).now;
    return stocks.where((s) => s.daysUntilExpiry(now) >= 0).toList();
  }

  void _selectOffered(StockItem? item) {
    _offeredStockId = item?.id;
    _offeredQtyController.text =
        item == null ? '' : formatQuantity(item.quantity);
  }

  void _selectRequested(StockItem? item) {
    _requestedStockId = item?.id;
    _requestedQtyController.text =
        item == null ? '' : formatQuantity(item.quantity);
  }

  Future<void> _submit() async {
    final match = MatchScope.read(context);
    final me = match.userId;
    final offeredId = _offeredStockId;
    if (me == null) return;
    if (offeredId == null) return _showMessage('Pilih stok yang Anda tawarkan.');

    final offeredQty = parseQuantity(_offeredQtyController.text);
    if (offeredQty == null || offeredQty <= 0) {
      return _showMessage('Jumlah yang ditawarkan harus lebih dari 0.');
    }

    int? requestedId;
    double? requestedQty;
    String? requestedNote;
    if (!_isDonation) {
      if (_requestedStockId == _customRequest) {
        requestedNote = _requestedNoteController.text.trim();
        if (requestedNote.isEmpty) {
          return _showMessage('Tulis bahan yang Anda minta.');
        }
      } else {
        requestedId = _requestedStockId;
        requestedQty = parseQuantity(_requestedQtyController.text);
        if (requestedQty == null || requestedQty <= 0) {
          return _showMessage('Jumlah yang diminta harus lebih dari 0.');
        }
      }
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final now = match.now;
    setState(() => _isSubmitting = true);
    try {
      await match.propose(
        Barter(
          type: widget.args.type,
          proposerId: me,
          receiverId: widget.args.partnerId,
          offeredStockId: offeredId,
          offeredQuantity: offeredQty,
          requestedStockId: requestedId,
          requestedQuantity: requestedQty,
          requestedNote: requestedNote,
          lastActorId: me,
          createdAt: now,
          updatedAt: now,
        ),
        message: _messageController.text,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isDonation
                ? 'Penyaluran diajukan. Tunggu konfirmasi mitra.'
                : 'Penawaran barter dikirim. Pantau di tab Barter.',
          ),
        ),
      );
    } on BarterException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      debugPrint('Gagal mengajukan barter: $error');
      _showMessage('Gagal mengirim penawaran. Coba lagi.');
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
    final stock = StockScope.of(context);
    final partner = MatchScope.of(context).partnerById(widget.args.partnerId);
    final mine = _myStocks(stock);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isDonation ? 'Salurkan Stok' : 'Ajukan Barter',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
      ),
      body: partner == null
          ? const Center(child: Text('Mitra tidak ditemukan.'))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_outlined,
                              color: AppColors.purple),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  partner.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text,
                                  ),
                                ),
                                Text(
                                  '${roleLabel(partner.role)} · ${partner.address}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _Heading('Anda tawarkan'),
                    if (mine.isEmpty)
                      Text(
                        _isDonation
                            ? 'Tidak ada stok kedaluwarsa untuk disalurkan.'
                            : 'Belum ada stok yang bisa ditawarkan.',
                        style: const TextStyle(color: AppColors.muted),
                      )
                    else ...[
                      _StockDropdown(
                        label: 'Stok Anda',
                        items: mine,
                        value: _offeredStockId,
                        onChanged: (id) => setState(() => _selectOffered(
                              mine.firstWhere((s) => s.id == id),
                            )),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _offeredQtyController,
                        label: 'Jumlah ditawarkan',
                        hint: '0',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                    if (!_isDonation) ...[
                      const SizedBox(height: 20),
                      const _Heading('Anda minta'),
                      _StockDropdown(
                        label: 'Stok mitra',
                        items: _theirStocks(partner.stocks),
                        value: _requestedStockId,
                        customOptionLabel: 'Bahan lain (tulis sendiri)',
                        customValue: _customRequest,
                        onChanged: (id) => setState(() {
                          if (id == _customRequest) {
                            _requestedStockId = _customRequest;
                          } else {
                            _selectRequested(partner.stocks
                                .firstWhere((s) => s.id == id));
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
                      if (_requestedStockId == _customRequest)
                        AppTextField(
                          controller: _requestedNoteController,
                          label: 'Bahan yang diminta',
                          hint: 'Contoh: Gula pasir 2 kg',
                        )
                      else
                        AppTextField(
                          controller: _requestedQtyController,
                          label: 'Jumlah diminta',
                          hint: '0',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                    ],
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: _messageController,
                      label: 'Pesan (opsional)',
                      hint: _isDonation
                          ? 'Contoh: Bisa diambil sore ini'
                          : 'Contoh: Bisa kirim besok pagi',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: _isSubmitting
                          ? 'Mengirim...'
                          : _isDonation
                              ? 'Ajukan Penyaluran'
                              : 'Kirim Penawaran',
                      color: _isDonation ? AppColors.primary : AppColors.purple,
                      onPressed:
                          _isSubmitting || mine.isEmpty ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
      ),
    );
  }
}

class _StockDropdown extends StatelessWidget {
  const _StockDropdown({
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.customOptionLabel,
    this.customValue,
  });

  final String label;
  final List<StockItem> items;
  final int? value;
  final ValueChanged<int> onChanged;
  final String? customOptionLabel;
  final int? customValue;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      borderRadius: BorderRadius.circular(12),
      dropdownColor: Colors.white,
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item.id,
            child: Text(
              '${item.name} (${formatQuantity(item.quantity)} ${item.unit.label})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (customOptionLabel != null)
          DropdownMenuItem(value: customValue, child: Text(customOptionLabel!)),
      ],
      onChanged: (id) {
        if (id != null) onChanged(id);
      },
    );
  }
}
