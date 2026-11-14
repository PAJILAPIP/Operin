import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/market_repository.dart';
import '../../../data/transaction_repository.dart';
import '../../impact/transaction_controller.dart';
import '../../../model/catalog_item.dart';
import '../../../model/market_listing.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/section_title.dart';
import '../../market/market_controller.dart';
import '../../market/widgets/catalog_item_card.dart';
import '../../market/widgets/market_listing_card.dart';
import '../../market/widgets/order_tile.dart';

enum _MarketSection { flashSale, sale, catalog, offers }

/// Tab "Pasar B2B": promo surplus & katalog stok UMKM lain + pengajuan
/// pembelian.
class MarketTab extends StatefulWidget {
  const MarketTab({super.key});

  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab> {
  _MarketSection _section = _MarketSection.flashSale;
  String _query = '';
  bool _withinRadius = true;

  @override
  void initState() {
    super.initState();
    // Muat ulang setiap kali tab dibuka agar promo terbaru tampil.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) MarketScope.read(context).load();
    });
  }

  Future<void> _runAction(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on MarketException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on TransactionException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      debugPrint('Aksi pasar gagal: $error');
      messenger.showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan. Coba lagi.')),
      );
    }
  }

  List<MarketListing> _filtered(MarketController market, bool flashSale) {
    final query = _query.trim().toLowerCase();
    final radius = market.radiusKm;
    final list = market.listings.where((listing) {
      if (listing.isFlashSale != flashSale) return false;
      if (query.isNotEmpty &&
          !listing.stockName.toLowerCase().contains(query) &&
          !listing.sellerName.toLowerCase().contains(query)) {
        return false;
      }
      // Listing tanpa jarak (koordinat belum ada) tetap ditampilkan.
      if (_withinRadius && radius != null && listing.distanceKm != null) {
        return listing.distanceKm! <= radius;
      }
      return true;
    }).toList();

    // Flash sale: yang paling cepat berakhir. Sale: yang paling dekat.
    list.sort((a, b) {
      if (flashSale) return a.promotion.endsAt.compareTo(b.promotion.endsAt);
      return (a.distanceKm ?? double.infinity).compareTo(
        b.distanceKm ?? double.infinity,
      );
    });
    return list;
  }

  List<CatalogItem> _filteredCatalog(MarketController market) {
    final query = _query.trim().toLowerCase();
    final radius = market.radiusKm;
    final list = market.catalog.where((item) {
      if (query.isNotEmpty &&
          !item.name.toLowerCase().contains(query) &&
          !item.sellerName.toLowerCase().contains(query)) {
        return false;
      }
      if (_withinRadius && radius != null && item.distanceKm != null) {
        return item.distanceKm! <= radius;
      }
      return true;
    }).toList();
    // Yang paling dekat lebih dulu, lalu yang lebih cepat kedaluwarsa.
    list.sort((a, b) {
      final distance = (a.distanceKm ?? double.infinity).compareTo(
        b.distanceKm ?? double.infinity,
      );
      if (distance != 0) return distance;
      return a.stock.expiryDate.compareTo(b.stock.expiryDate);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final market = MarketScope.of(context);
    final flash = _filtered(market, true);
    final sale = _filtered(market, false);
    final catalog = _filteredCatalog(market);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Pasar B2B',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: market.isLoading ? null : market.load,
              icon: const Icon(Icons.refresh, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _SectionChip(
              label: 'Flash Sale',
              count: flash.length,
              icon: Icons.flash_on,
              selected: _section == _MarketSection.flashSale,
              onTap: () => setState(() => _section = _MarketSection.flashSale),
            ),
            _SectionChip(
              label: 'Sale',
              count: sale.length,
              icon: Icons.sell_outlined,
              selected: _section == _MarketSection.sale,
              onTap: () => setState(() => _section = _MarketSection.sale),
            ),
            _SectionChip(
              label: 'Katalog',
              count: catalog.length,
              icon: Icons.menu_book_outlined,
              selected: _section == _MarketSection.catalog,
              onTap: () => setState(() => _section = _MarketSection.catalog),
            ),
            _SectionChip(
              label: 'Penawaran',
              count: market.pendingIncomingCount,
              highlightCount: market.pendingIncomingCount > 0,
              icon: Icons.swap_horiz,
              selected: _section == _MarketSection.offers,
              onTap: () => setState(() => _section = _MarketSection.offers),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_section == _MarketSection.offers)
          ..._buildOffers(market)
        else if (_section == _MarketSection.catalog)
          ..._buildCatalog(market, catalog)
        else
          ..._buildListings(
            market,
            _section == _MarketSection.flashSale ? flash : sale,
          ),
      ],
    );
  }

  /// Kolom pencarian + filter radius, dipakai bersama promo & katalog.
  List<Widget> _buildFilters(MarketController market, String hint) {
    final radius = market.radiusKm;
    return [
      AppTextField(
        hint: hint,
        icon: Icons.search,
        onChanged: (value) => setState(() => _query = value),
      ),
      if (radius != null) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: Text('Dalam radius $radius km'),
            selected: _withinRadius,
            onSelected: (value) => setState(() => _withinRadius = value),
            selectedColor: AppColors.greenBadge,
            checkmarkColor: AppColors.primary,
          ),
        ),
      ],
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _buildCatalog(MarketController market, List<CatalogItem> items) {
    return [
      ..._buildFilters(market, 'Cari bahan atau nama toko'),
      if (market.isLoading && market.catalog.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (items.isEmpty)
        const _Empty(
          icon: Icons.menu_book_outlined,
          title: 'Katalog masih kosong',
          message:
              'Stok layak jual dari UMKM lain akan muncul di sini, '
              'bisa dibeli dengan harga normal.',
        )
      else
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CatalogItemCard(
              item: item,
              now: market.now,
              onTap: () => Navigator.of(context)
                  .pushNamed(AppRoutes.catalogDetail, arguments: item.stockId),
            ),
          ),
    ];
  }

  List<Widget> _buildListings(
    MarketController market,
    List<MarketListing> listings,
  ) {
    return [
      ..._buildFilters(market, 'Cari bahan atau nama toko'),
      if (market.isLoading && market.listings.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (listings.isEmpty)
        _Empty(
          icon: _section == _MarketSection.flashSale
              ? Icons.flash_off
              : Icons.storefront_outlined,
          title: _section == _MarketSection.flashSale
              ? 'Belum ada flash sale'
              : 'Belum ada sale',
          message: 'Promo surplus dari UMKM lain akan muncul di sini.',
        )
      else
        for (final listing in listings)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MarketListingCard(
              listing: listing,
              now: market.now,
              onTap: () => Navigator.of(context).pushNamed(
                AppRoutes.listingDetail,
                arguments: listing.promotionId,
              ),
            ),
          ),
    ];
  }

  List<Widget> _buildOffers(MarketController market) {
    final incoming = market.incomingOrders;
    final outgoing = market.outgoingOrders;

    return [
      SectionTitle('Masuk (${incoming.length})'),
      if (incoming.isEmpty)
        const _Empty(
          icon: Icons.inbox_outlined,
          title: 'Belum ada pengajuan masuk',
          message: 'Pengajuan pembelian atas promo Anda akan muncul di sini.',
        )
      else
        for (final order in incoming)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OrderTile(
              order: order,
              incoming: true,
              onAccept: () => _runAction(
                () => market.respond(order.id!, accept: true),
                'Pengajuan diterima.',
              ),
              onReject: () => _runAction(
                () => market.respond(order.id!, accept: false),
                'Pengajuan ditolak.',
              ),
              onComplete: () => _runAction(
                () => TransactionScope.read(context).completeOrder(order.id!),
                'Transaksi selesai. Stok & dampak diperbarui.',
              ),
            ),
          ),
      const SizedBox(height: 16),
      SectionTitle('Keluar (${outgoing.length})'),
      if (outgoing.isEmpty)
        const _Empty(
          icon: Icons.outbox_outlined,
          title: 'Belum ada pengajuan',
          message: 'Ajukan pembelian dari tab Flash Sale atau Sale.',
        )
      else
        for (final order in outgoing)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OrderTile(
              order: order,
              incoming: false,
              onCancel: () => _runAction(
                () => market.cancel(order.id!),
                'Pengajuan dibatalkan.',
              ),
            ),
          ),
    ];
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.highlightCount = false,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool highlightCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.text;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Column(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: highlightCount && !selected
                          ? AppColors.warning
                          : color.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
