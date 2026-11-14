import '../model/business_profile.dart';
import 'supabase_support.dart';

/// Penyimpanan profil & preferensi usaha (satu baris per user).
abstract interface class ProfileRepository {
  /// Profil milik [userId], atau null jika onboarding profil belum selesai.
  Future<BusinessProfile?> getProfile(int userId);

  /// Membuat atau memperbarui profil usaha.
  Future<BusinessProfile> saveProfile(BusinessProfile profile);
}

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository();

  @override
  Future<BusinessProfile?> getProfile(int userId) => guardDb(() async {
    final row = await supabase
        .from('business_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : BusinessProfile.fromMap(row);
  }, DataException.new);

  @override
  Future<BusinessProfile> saveProfile(BusinessProfile profile) =>
      guardDb(() async {
        final row = await supabase
            .from('business_profiles')
            .upsert(profile.toMap())
            .select()
            .single();
        return BusinessProfile.fromMap(row);
      }, DataException.new);
}
