import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../model/barter.dart';
import '../../../widgets/app_card.dart';
import '../../stock/stock_controller.dart';
import '../match_controller.dart';
import '../widgets/barter_tile.dart';
import '../widgets/partner_match_card.dart';
import 'barter_form_page.dart';

/// Matchmaking B2B: rekomendasi mitra + daftar barter.
///
/// Jika [recycleStockId] diisi, halaman hanya menampilkan mitra daur ulang
/// untuk menyalurkan stok kedaluwarsa tersebut.
class MatchmakingPage extends StatefulWidget {
  const MatchmakingPage({super.key, this.recycleStockId});

  final int? recycleStockId;

  @override
  State<MatchmakingPage> createState() => _MatchmakingPageState();
}

class _MatchmakingPageState extends State<MatchmakingPage> {
  bool _showBarters = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) MatchScope.read(context).load();
    });
  }

  void _openForm(BarterFormArgs args) =>
      Navigator.of(context).pushNamed(AppRoutes.barterForm, arguments: args);

  @override
  Widget build(BuildContext context) {
    final match = MatchScope.of(context);
    final stock = StockScope.of(context);
    final recycleItem = widget.recycleStockId == null
        ? null
        : stock.byId(widget.recycleStockId!);
    final hasSellable =
        stock.items.any((item) => item.daysUntilExpiry(match.now) >= 0);

    final matches = recycleItem == null
        ? match.matches
        : match.matches.where((m) => m.partner.isRecyclePartner).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          recycleItem == null ? 'Matchmaking B2B' : 'Salurkan ke Daur Ulang',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (recycleItem != null)
                _Banner(
                  icon: Icons.recycling,
                  text: 'Pilih mitra daur ulang untuk menyalurkan '
                      '"${recycleItem.name}". Stok ini tidak layak jual, '
                      'tetapi masih berguna untuk kompos atau pakan.',
                )
              else
                SegmentedButton<bool>(
                  segments: [
                    const ButtonSegment(
                      value: false,
                      label: Text('Rekomendasi'),
                      icon: Icon(Icons.handshake_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(
                        match.awaitingMeCount > 0
                            ? 'Barter (${match.awaitingMeCount})'
                            : 'Barter',
                      ),
                      icon: const Icon(Icons.swap_horiz),
                    ),
                  ],
                  selected: {_showBarters},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _showBarters = value.first),
                ),
              const SizedBox(height: 16),
              if (match.isLoading && match.matches.isEmpty && !_showBarters)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_showBarters && recycleItem == null)
                ..._buildBarters(match)
              else if (matches.isEmpty)
                _Empty(
                  icon: Icons.travel_explore,
                  title: recycleItem == null
                      ? 'Belum ada mitra yang cocok'
                      : 'Belum ada mitra daur ulang',
                  message: recycleItem == null
                      ? 'Lengkapi kategori bahan di profil usaha dan catat '
                          'stok Anda agar rekomendasi muncul.'
                      : 'Belum ada mitra daur ulang terdaftar dalam radius '
                          'Anda.',
                )
              else
                for (final m in matches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PartnerMatchCard(
                      match: m,
                      now: match.now,
                      onRecycle: m.partner.isRecyclePartner &&
                              (recycleItem != null || m.recyclable.isNotEmpty)
                          ? () => _openForm(BarterFormArgs(
                                partnerId: m.partner.userId,
                                type: BarterType.donation,
                                offeredStockId: recycleItem?.id ??
                                    m.recyclable.first.id,
                              ))
                          : null,
                      onBarter: recycleItem == null && hasSellable
                          ? () => _openForm(BarterFormArgs(
                                partnerId: m.partner.userId,
                                type: BarterType.barter,
                                offeredStockId: m.theyNeed.firstOrNull?.id,
                                requestedStockId: m.theyHave.firstOrNull?.id,
                              ))
                          : null,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBarters(MatchController match) {
    final viewer = match.userId;
    if (viewer == null) return const [];
    if (match.barters.isEmpty) {
      return const [
        _Empty(
          icon: Icons.swap_horiz,
          title: 'Belum ada barter',
          message: 'Ajukan barter dari tab Rekomendasi.',
        ),
      ];
    }
    return [
      for (final barter in match.barters)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: BarterTile(
            barter: barter,
            viewerId: viewer,
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.barterDetail,
              arguments: barter.id,
            ),
          ),
        ),
    ];
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.mutedLight),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
