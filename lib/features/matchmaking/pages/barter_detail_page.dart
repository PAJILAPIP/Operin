import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/match_repository.dart';
import '../../../data/transaction_repository.dart';
import '../../impact/transaction_controller.dart';
import '../../../model/barter.dart';
import '../../../widgets/app_card.dart';
import '../match_controller.dart';
import '../widgets/barter_tile.dart';

/// Detail barter: ringkasan pertukaran, riwayat negosiasi, dan aksi
/// (terima / tolak / tawar balik / batalkan / kirim pesan).
class BarterDetailPage extends StatefulWidget {
  const BarterDetailPage({super.key, required this.barterId});

  final int barterId;

  @override
  State<BarterDetailPage> createState() => _BarterDetailPageState();
}

class _BarterDetailPageState extends State<BarterDetailPage> {
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) MatchScope.read(context).loadMessages(widget.barterId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, [String? done]) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (done != null) {
        messenger.showSnackBar(SnackBar(content: Text(done)));
      }
    } on BarterException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on TransactionException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      debugPrint('Aksi barter gagal: $error');
      messenger.showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan. Coba lagi.')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await _run(() => MatchScope.read(context).sendMessage(widget.barterId, text));
  }

  Future<void> _confirmComplete(Barter barter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selesaikan transaksi?'),
        content: const Text(
          'Tandai selesai setelah barang benar-benar diserahkan. Stok kedua '
          'pihak akan diperbarui otomatis dan tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, Selesai'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => TransactionScope.read(context).completeBarter(barter.id!),
      'Transaksi selesai. Stok & dampak diperbarui.',
    );
  }

  Future<void> _counterOffer(Barter barter) async {
    final result = await showDialog<_Counter>(
      context: context,
      builder: (_) => _CounterDialog(barter: barter),
    );
    if (result == null || !mounted) return;
    await _run(
      () => MatchScope.read(context).counterOffer(
        widget.barterId,
        offeredQuantity: result.offered,
        requestedQuantity: result.requested,
        message: result.message,
      ),
      'Tawaran balik dikirim.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final match = MatchScope.of(context);
    final barter = match.barterById(widget.barterId);
    final me = match.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          barter?.type == BarterType.donation ? 'Penyaluran' : 'Negosiasi Barter',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
      ),
      body: barter == null || me == null
          ? const Center(child: Text('Barter tidak ditemukan.'))
          : _buildBody(barter, me, match),
    );
  }

  Widget _buildBody(Barter barter, int me, MatchController match) {
    final summary = barterSummary(barter, me);
    final awaitingMe = barter.awaitingResponseFrom(me);
    final messages = match.messagesOf(barter.id!);

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              barter.otherPartyNameOf(me) ?? 'Mitra',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          BarterStatusBadge(status: barter.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Exchange(label: 'Anda beri', value: summary.give),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Icon(Icons.swap_vert,
                            color: AppColors.mutedLight, size: 20),
                      ),
                      _Exchange(label: 'Anda terima', value: summary.get),
                      if (barter.status.isOpen) ...[
                        const SizedBox(height: 12),
                        Text(
                          awaitingMe
                              ? 'Giliran Anda menjawab.'
                              : 'Menunggu jawaban ${barter.otherPartyNameOf(me) ?? 'mitra'}.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: awaitingMe
                                ? const Color(0xFFB45309)
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (awaitingMe) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _run(
                            () => match.respond(barter.id!, accept: false),
                            'Penawaran ditolak.',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.warning,
                          ),
                          child: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _counterOffer(barter),
                          child: const Text('Tawar Balik'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _run(
                            () => match.respond(barter.id!, accept: true),
                            'Kesepakatan tercapai!',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: const Text('Terima'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (barter.status == BarterStatus.accepted) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _confirmComplete(barter),
                    icon: const Icon(Icons.task_alt, size: 18),
                    label: Text(
                      barter.type == BarterType.donation
                          ? 'Selesaikan Penyaluran'
                          : 'Selesaikan Barter',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
                if (barter.status.isOpen && barter.proposerId == me)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _run(
                        () => match.cancel(barter.id!),
                        'Penawaran dibatalkan.',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.warning,
                      ),
                      child: const Text('Batalkan Penawaran'),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Riwayat Negosiasi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 10),
                for (final message in messages)
                  _MessageBubble(
                    message: message,
                    mine: message.senderId == me,
                    barter: barter,
                  ),
              ],
            ),
          ),
          if (barter.status.isOpen)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Tulis pesan...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kirim',
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: AppColors.primary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Exchange extends StatelessWidget {
  const _Exchange({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.barter,
  });

  final BarterMessage message;
  final bool mine;
  final Barter barter;

  @override
  Widget build(BuildContext context) {
    final offeredUnit = barter.offeredUnit?.label ?? '';
    final requestedUnit = barter.requestedUnit?.label ?? '';

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? AppColors.greenBadge : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: mine ? AppColors.greenBadge : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mine ? 'Anda' : (message.senderName ?? 'Mitra'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.text,
              style: const TextStyle(fontSize: 13, color: AppColors.text),
            ),
            if (message.isCounterOffer) ...[
              const SizedBox(height: 6),
              Text(
                [
                  '${barter.offeredStockName ?? 'Stok'}: '
                      '${formatQuantity(message.offeredQuantity!)} $offeredUnit',
                  if (message.requestedQuantity != null)
                    '${barter.requestedStockName ?? 'Stok'}: '
                        '${formatQuantity(message.requestedQuantity!)} $requestedUnit',
                ].join('  ⇄  '),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blueText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Counter {
  const _Counter(this.offered, this.requested, this.message);

  final double offered;
  final double? requested;
  final String? message;
}

class _CounterDialog extends StatefulWidget {
  const _CounterDialog({required this.barter});

  final Barter barter;

  @override
  State<_CounterDialog> createState() => _CounterDialogState();
}

class _CounterDialogState extends State<_CounterDialog> {
  late final _offered = TextEditingController(
    text: formatQuantity(widget.barter.offeredQuantity),
  );
  late final _requested = TextEditingController(
    text: widget.barter.requestedQuantity == null
        ? ''
        : formatQuantity(widget.barter.requestedQuantity!),
  );
  final _message = TextEditingController();
  String? _error;

  bool get _hasRequestedStock => widget.barter.requestedStockId != null;

  @override
  void dispose() {
    _offered.dispose();
    _requested.dispose();
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    final offered = parseQuantity(_offered.text);
    final requested = _hasRequestedStock ? parseQuantity(_requested.text) : null;
    if (offered == null ||
        offered <= 0 ||
        (_hasRequestedStock && (requested == null || requested <= 0))) {
      setState(() => _error = 'Jumlah harus lebih dari 0.');
      return;
    }
    Navigator.of(context).pop(_Counter(offered, requested, _message.text));
  }

  @override
  Widget build(BuildContext context) {
    final barter = widget.barter;
    return AlertDialog(
      title: const Text('Tawar Balik'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _offered,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '${barter.offeredStockName ?? 'Stok ditawarkan'} '
                    '(${barter.offeredUnit?.label ?? ''})',
              ),
            ),
            if (_hasRequestedStock) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _requested,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${barter.requestedStockName ?? 'Stok diminta'} '
                      '(${barter.requestedUnit?.label ?? ''})',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              decoration: const InputDecoration(labelText: 'Pesan (opsional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.warning)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Kirim Tawaran')),
      ],
    );
  }
}
