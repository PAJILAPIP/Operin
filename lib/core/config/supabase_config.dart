/// Koneksi ke project Supabase Operin.
///
/// Isi dari Supabase Dashboard → Project Settings → API:
/// - Project URL
/// - Publishable key (`sb_publishable_...`) atau anon key lama — aman berada
///   di aplikasi; data dilindungi Row Level Security di database.
///
/// Bisa ditimpa saat build: `--dart-define=SUPABASE_URL=...`
/// `--dart-define=SUPABASE_KEY=...`
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ISI-PROJECT-REF.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'ISI-PUBLISHABLE-KEY',
  );

  /// False selama URL/key masih placeholder.
  static bool get isConfigured =>
      !url.contains('ISI-PROJECT-REF') && !publishableKey.startsWith('ISI-');
}
