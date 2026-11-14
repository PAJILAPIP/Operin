class AuthUser {
  const AuthUser({
    this.id,
    required this.fullName,
    required this.email,
    required this.businessType,
    required this.address,
    required this.createdAt,
    this.role,
  });

  final int? id;
  final String fullName;
  final String email;
  final String businessType;
  final String address;
  final DateTime createdAt;

  /// Nama enum `UserRole` yang dipilih di survey; null jika belum memilih.
  final String? role;

  factory AuthUser.fromMap(Map<String, Object?> map) => AuthUser(
    id: map['id'] as int?,
    fullName: map['full_name']! as String,
    email: map['email']! as String,
    businessType: map['business_type']! as String,
    address: map['address']! as String,
    createdAt: DateTime.parse(map['created_at']! as String),
    role: map['role'] as String?,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'business_type': businessType,
    'address': address,
    'created_at': createdAt.toIso8601String(),
    'role': role,
  };

  AuthUser copyWith({int? id, String? role}) => AuthUser(
    id: id ?? this.id,
    fullName: fullName,
    email: email,
    businessType: businessType,
    address: address,
    createdAt: createdAt,
    role: role ?? this.role,
  );
}
