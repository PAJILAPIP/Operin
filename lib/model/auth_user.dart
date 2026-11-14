class AuthUser {
  const AuthUser({
    this.id,
    required this.fullName,
    required this.email,
    required this.businessType,
    required this.address,
    required this.createdAt,
  });

  final int? id;
  final String fullName;
  final String email;
  final String businessType;
  final String address;
  final DateTime createdAt;

  factory AuthUser.fromMap(Map<String, Object?> map) => AuthUser(
    id: map['id'] as int?,
    fullName: map['full_name']! as String,
    email: map['email']! as String,
    businessType: map['business_type']! as String,
    address: map['address']! as String,
    createdAt: DateTime.parse(map['created_at']! as String),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'business_type': businessType,
    'address': address,
    'created_at': createdAt.toIso8601String(),
  };
}
