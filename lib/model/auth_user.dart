import '../core/utils/db_codec.dart';
class AuthUser {
  const AuthUser({
    this.id,
    required this.fullName,
    required this.email,
    required this.businessType,
    required this.address,
    required this.createdAt,
    this.role,
    this.latitude,
    this.longitude,
  });

  final int? id;
  final String fullName;
  final String email;

  /// Nama enum `BusinessCategory`.
  final String businessType;
  final String address;
  final DateTime createdAt;

  /// Nama enum `UserRole` yang dipilih di survey; null jika belum memilih.
  final String? role;

  /// Titik lokasi usaha dari peta; null untuk akun lama yang belum menandai.
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  factory AuthUser.fromMap(Map<String, Object?> map) => AuthUser(
    id: map['id'] as int?,
    fullName: map['full_name']! as String,
    email: map['email']! as String,
    businessType: map['business_type']! as String,
    address: map['address']! as String,
    createdAt: decodeTime(map['created_at']),
    role: map['role'] as String?,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'business_type': businessType,
    'address': address,
    'created_at': encodeTime(createdAt),
    'role': role,
    'latitude': latitude,
    'longitude': longitude,
  };

  AuthUser copyWith({int? id, String? role}) => AuthUser(
    id: id ?? this.id,
    fullName: fullName,
    email: email,
    businessType: businessType,
    address: address,
    createdAt: createdAt,
    role: role ?? this.role,
    latitude: latitude,
    longitude: longitude,
  );
}
