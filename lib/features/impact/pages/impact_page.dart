import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../model/activity_entry.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/section_title.dart';
import '../impact_calculator.dart';
import '../transaction_controller.dart';
import '../widgets/activity_tile.dart';
import '../widgets/impact_bar_chart.dart';

/// Dashboard dampak penyelamatan + riwayat aktivitas.
class ImpactPage extends StatefulWidget {
  const ImpactPage({super.key, this.showHistory = false});

  /// Buka langsung di tab Riwayat.
  final bool showHistory;

  @override
  State<ImpactPage> createState() => _ImpactPageState();
}

class _ImpactPageState extends State<ImpactPage> {
  late bool _showHistory = widget.showHistory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TransactionScope.read(context).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactions = TransactionScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dampak & Riwayat',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Dampak'),
                    icon: Icon(Icons.eco_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Riwayat'),
                    icon: Icon(Icons.history),
                  ),
                ],
                selected: {_showHistory},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _showHistory = value.first),
              ),
              const SizedBox(height: 20),
              if (_showHistory)
                ..._history(transactions.entries)
              else
                ..._impact(transactions.summary),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _impact(ImpactSummary summary) {
    final change = summary.monthlyChangePercent;
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF047857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kerugian Terselamatkan',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              formatRupiah(summary.savedValue),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              monthlyChangeLabel(summary),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: change != null && change < 0
                    ? const Color(0xFFFECACA)
                    : Colors.white,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: [
          _StatTile(
            icon: Icons.delete_outline,
            label: 'Limbah Dicegah',
            value: '${formatQuantity(summary.wasteKg)} kg',
          ),
          _StatTile(
            icon: Icons.people_outline,
            label: 'UMKM Terbantu',
            value: '${summary.partnersHelped}',
          ),
          _StatTile(
            icon: Icons.cloud_outlined,
            label: 'Emisi Dicegah',
            value: '${formatQuantity(summary.co2Kg)} kg CO₂e',
          ),
          _StatTile(
            icon: Icons.receipt_long_outlined,
            label: 'Transaksi Selesai',
            value: '${summary.transactionCount}',
          ),
        ],
      ),
      const SizedBox(height: 24),
      const SectionTitle('Nilai Terselamatkan per Bulan'),
      AppCard(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: ImpactBarChart(months: summary.months),
      ),
      if (summary.countByKind.isNotEmpty) ...[
        const SizedBox(height: 24),
        const SectionTitle('Rincian Aktivitas'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final kind in ActivityKind.values)
                if (summary.countByKind[kind] != null)
                  _BreakdownRow(kind: kind, count: summary.countByKind[kind]!),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      const Text(
        'Berat limbah memakai perkiraan per satuan (mis. 1 pcs ≈ 0,2 kg) dan '
        'emisi memakai faktor 2,5 kg CO₂e per kg sampah makanan. Angka ini '
        'perkiraan, bukan pengukuran.',
        style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.4),
      ),
    ];
  }

  List<Widget> _history(List<ActivityEntry> entries) {
    if (entries.isEmpty) {
      return const [
        AppCard(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Icon(Icons.history, size: 40, color: AppColors.mutedLight),
              SizedBox(height: 12),
              Text(
                'Belum ada aktivitas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Transaksi pasar dan barter yang sudah selesai akan tercatat '
                'di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    String? currentDate;
    for (final entry in entries) {
      final date = formatDate(entry.createdAt);
      if (date != currentDate) {
        currentDate = date;
        widgets.add(Padding(
          padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 12, bottom: 8),
          child: Text(
            date,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.muted,
            ),
          ),
        ));
      }
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ActivityTile(entry: entry),
      ));
    }
    return widgets;
  }
}

/// Teks perubahan bulan ini untuk kartu ringkasan.
String monthlyChangeLabel(ImpactSummary summary) {
  final change = summary.monthlyChangePercent;
  if (change != null) {
    final rounded = change.round();
    return '${rounded >= 0 ? '+' : ''}$rounded% dibanding bulan lalu';
  }
  if (summary.savedThisMonth > 0) {
    return '+${formatRupiah(summary.savedThisMonth)} bulan ini';
  }
  return 'Belum ada transaksi bulan ini';
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.kind, required this.count});

  final ActivityKind kind;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(activityIcon(kind), size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              kind.label,
              style: const TextStyle(fontSize: 13, color: AppColors.text),
            ),
          ),
          Text(
            '$count×',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
