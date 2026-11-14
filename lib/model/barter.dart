import '../core/utils/db_codec.dart';
import 'stock_item.dart';

enum BarterType {
  /// Tukar stok dengan stok/bahan milik mitra.
  barter('Barter'),

  /// Stok tak layak jual disalurkan ke mitra daur ulang tanpa imbalan.
  donation('Salurkan Daur Ulang');

  const BarterType(this.label);

  final String label;

  static BarterType fromName(String? name) =>
      name == donation.name ? donation : barter;
}

enum BarterStatus {
  pending('Menunggu'),
  negotiating('Negosiasi'),
  accepted('Disepakati'),
  rejected('Ditolak'),
  cancelled('Dibatalkan'),

  /// Diisi saat penyelesaian transaksi (Tahap 11).
  completed('Selesai');

  const BarterStatus(this.label);

  final String label;

  /// Masih bisa ditawar / dijawab.
  bool get isOpen => this == pending || this == negotiating;

  static BarterStatus fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return pending;
  }
}

/// Penawaran barter (atau donasi) antara dua UMKM.
class Barter {
  const Barter({
    this.id,
    required this.type,
    required this.proposerId,
    required this.receiverId,
    required this.offeredStockId,
    required this.offeredQuantity,
    this.requestedStockId,
    this.requestedQuantity,
    this.requestedNote,
    this.status = BarterStatus.pending,
    required this.lastActorId,
    required this.createdAt,
    required this.updatedAt,
    this.proposerName,
    this.receiverName,
    this.offeredStockName,
    this.offeredUnit,
    this.requestedStockName,
    this.requestedUnit,
  });

  final int? id;
  final BarterType type;
  final int proposerId;
  final int receiverId;

  /// Stok milik pengaju yang ditawarkan.
  final int offeredStockId;
  final double offeredQuantity;

  /// Stok milik penerima yang diminta (null = tidak spesifik / donasi).
  final int? requestedStockId;
  final double? requestedQuantity;

  /// Kebutuhan dalam bentuk teks bebas, mis. "Gula pasir 2 kg".
  final String? requestedNote;
  final BarterStatus status;

  /// Pihak yang terakhir mengajukan/menawar; giliran menjawab ada di pihak
  /// lain.
  final int lastActorId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Data tampilan hasil join.
  final String? proposerName;
  final String? receiverName;
  final String? offeredStockName;
  final StockUnit? offeredUnit;
  final String? requestedStockName;
  final StockUnit? requestedUnit;

  /// true jika [userId] perlu menjawab (terima / tolak / tawar).
  bool awaitingResponseFrom(int userId) =>
      status.isOpen &&
      lastActorId != userId &&
      (userId == proposerId || userId == receiverId);

  int otherPartyOf(int userId) =>
      userId == proposerId ? receiverId : proposerId;

  String? otherPartyNameOf(int userId) =>
      userId == proposerId ? receiverName : proposerName;

  factory Barter.fromMap(Map<String, Object?> map) => Barter(
    id: map['id'] as int?,
    type: BarterType.fromName(map['type'] as String?),
    proposerId: map['proposer_id']! as int,
    receiverId: map['receiver_id']! as int,
    offeredStockId: map['offered_stock_id']! as int,
    offeredQuantity: (map['offered_quantity']! as num).toDouble(),
    requestedStockId: map['requested_stock_id'] as int?,
    requestedQuantity: (map['requested_quantity'] as num?)?.toDouble(),
    requestedNote: map['requested_note'] as String?,
    status: BarterStatus.fromName(map['status'] as String?),
    lastActorId: map['last_actor_id']! as int,
    createdAt: decodeTime(map['created_at']),
    updatedAt: decodeTime(map['updated_at']),
    proposerName: map['proposer_name'] as String?,
    receiverName: map['receiver_name'] as String?,
    offeredStockName: map['offered_stock_name'] as String?,
    offeredUnit: map['offered_unit'] == null
        ? null
        : StockUnit.fromName(map['offered_unit'] as String?),
    requestedStockName: map['requested_stock_name'] as String?,
    requestedUnit: map['requested_unit'] == null
        ? null
        : StockUnit.fromName(map['requested_unit'] as String?),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'type': type.name,
    'proposer_id': proposerId,
    'receiver_id': receiverId,
    'offered_stock_id': offeredStockId,
    'offered_quantity': offeredQuantity,
    'requested_stock_id': requestedStockId,
    'requested_quantity': requestedQuantity,
    'requested_note': requestedNote,
    'status': status.name,
    'last_actor_id': lastActorId,
    'created_at': encodeTime(createdAt),
    'updated_at': encodeTime(updatedAt),
  };

  Barter copyWith({
    int? id,
    double? offeredQuantity,
    double? requestedQuantity,
    BarterStatus? status,
    int? lastActorId,
    DateTime? updatedAt,
  }) => Barter(
    id: id ?? this.id,
    type: type,
    proposerId: proposerId,
    receiverId: receiverId,
    offeredStockId: offeredStockId,
    offeredQuantity: offeredQuantity ?? this.offeredQuantity,
    requestedStockId: requestedStockId,
    requestedQuantity: requestedQuantity ?? this.requestedQuantity,
    requestedNote: requestedNote,
    status: status ?? this.status,
    lastActorId: lastActorId ?? this.lastActorId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    proposerName: proposerName,
    receiverName: receiverName,
    offeredStockName: offeredStockName,
    offeredUnit: offeredUnit,
    requestedStockName: requestedStockName,
    requestedUnit: requestedUnit,
  );
}

/// Pesan dalam negosiasi. Jika [offeredQuantity]/[requestedQuantity] terisi,
/// pesan ini adalah tawaran balik (counter-offer).
class BarterMessage {
  const BarterMessage({
    this.id,
    required this.barterId,
    required this.senderId,
    required this.text,
    this.offeredQuantity,
    this.requestedQuantity,
    required this.createdAt,
    this.senderName,
  });

  final int? id;
  final int barterId;
  final int senderId;
  final String text;
  final double? offeredQuantity;
  final double? requestedQuantity;
  final DateTime createdAt;
  final String? senderName;

  bool get isCounterOffer => offeredQuantity != null;

  factory BarterMessage.fromMap(Map<String, Object?> map) => BarterMessage(
    id: map['id'] as int?,
    barterId: map['barter_id']! as int,
    senderId: map['sender_id']! as int,
    text: map['text']! as String,
    offeredQuantity: (map['offered_quantity'] as num?)?.toDouble(),
    requestedQuantity: (map['requested_quantity'] as num?)?.toDouble(),
    createdAt: decodeTime(map['created_at']),
    senderName: map['sender_name'] as String?,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'barter_id': barterId,
    'sender_id': senderId,
    'text': text,
    'offered_quantity': offeredQuantity,
    'requested_quantity': requestedQuantity,
    'created_at': encodeTime(createdAt),
  };
}
