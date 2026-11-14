/// Peran pengguna yang dipilih di halaman survey.
enum UserRole {
  seller(
    title: 'Jual Stok Surplus',
    description: 'Jual cepat sisa bahan sebelum masa simpannya habis.',
    accountLabel: 'Akun Penjual Surplus',
  ),
  buyer(
    title: 'Cari Bahan Baku',
    description: 'Dapatkan bahan layak pakai dengan harga jauh lebih hemat.',
    accountLabel: 'Akun Pembeli Bahan Baku',
  ),
  waste(
    title: 'Mitra Daur Ulang',
    description:
        'Tampung sisa bahan tak layak konsumsi untuk kompos atau pakan.',
    accountLabel: 'Akun Mitra Daur Ulang',
  );

  const UserRole({
    required this.title,
    required this.description,
    required this.accountLabel,
  });

  final String title;
  final String description;
  final String accountLabel;
}
