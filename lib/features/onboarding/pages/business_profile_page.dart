import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../model/business_profile.dart';
import '../../../model/food_category.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../widgets/food_category_selector.dart';
import '../widgets/form_section.dart';

/// Pengisian profil & preferensi usaha.
///
/// Dipakai sebagai langkah onboarding setelah pilih peran, dan sebagai
/// halaman edit dari menu Profil ([isEditing] = true).
class BusinessProfilePage extends StatefulWidget {
  const BusinessProfilePage({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();
  Set<FoodCategory> _categories = {};
  int _radiusKm = 5;
  bool _notifyExpiry = true;
  int _notifyDaysBefore = 2;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    // Isi form dengan profil yang sudah ada (mode edit).
    final profile = SessionScope.read(context).profile;
    if (profile != null) {
      _nameController.text = profile.businessName;
      _whatsappController.text = '0${profile.whatsapp.substring(2)}';
      _categories = {...profile.preferredCategories};
      _radiusKm = profile.radiusKm;
      _notifyExpiry = profile.notifyExpiry;
      _notifyDaysBefore = profile.notifyDaysBefore;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Nama usaha wajib diisi.');
      return;
    }
    final whatsapp = BusinessProfile.normalizeWhatsapp(_whatsappController.text);
    if (whatsapp == null) {
      _showMessage('Nomor WhatsApp tidak valid. Contoh: 081234567890');
      return;
    }
    if (_categories.isEmpty) {
      _showMessage('Pilih minimal satu kategori bahan.');
      return;
    }

    final session = SessionScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final user = session.currentUser;
    if (user == null) {
      navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await session.saveProfile(
        BusinessProfile(
          userId: user.id!,
          businessName: name,
          whatsapp: whatsapp,
          preferredCategories: _categories,
          radiusKm: _radiusKm,
          notifyExpiry: _notifyExpiry,
          notifyDaysBefore: _notifyDaysBefore,
          updatedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      if (widget.isEditing) {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Profil usaha disimpan.')),
        );
      } else {
        AppRoutes.goHome(navigator, session);
      }
    } catch (error) {
      debugPrint('Gagal menyimpan profil: $error');
      _showMessage('Gagal menyimpan profil. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isEditing
          ? AppBar(
              title: const Text(
                'Informasi Toko',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              foregroundColor: AppColors.text,
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            widget.isEditing ? 20 : 40,
            20,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isEditing) ...[
                const Text(
                  'Lengkapi Profil Usaha',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Langkah terakhir! Data ini dipakai untuk mencocokkan Anda '
                  'dengan UMKM terdekat dan mengatur peringatan stok.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.text.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              FormSection(
                title: 'Identitas Usaha',
                icon: Icons.storefront_outlined,
                child: Column(
                  children: [
                    AppTextField(
                      controller: _nameController,
                      hint: 'Nama Usaha / Toko',
                      icon: Icons.store_outlined,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _whatsappController,
                      hint: 'Nomor WhatsApp (08xx)',
                      icon: Icons.chat_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FormSection(
                title: 'Bahan yang Diminati',
                subtitle: 'Pilih minimal satu. Dipakai untuk rekomendasi '
                    'dan matchmaking B2B.',
                icon: Icons.category_outlined,
                child: FoodCategorySelector(
                  selected: _categories,
                  onChanged: (value) => setState(() => _categories = value),
                ),
              ),
              const SizedBox(height: 16),
              FormSection(
                title: 'Radius Jangkauan',
                subtitle: 'Tampilkan mitra UMKM dalam jarak ini dari lokasi '
                    'usaha Anda.',
                icon: Icons.radar_outlined,
                child: _RadiusSlider(
                  value: _radiusKm,
                  onChanged: (value) => setState(() => _radiusKm = value),
                ),
              ),
              const SizedBox(height: 16),
              FormSection(
                title: 'Notifikasi Kedaluwarsa',
                icon: Icons.notifications_active_outlined,
                child: _ExpiryNotificationSetting(
                  enabled: _notifyExpiry,
                  daysBefore: _notifyDaysBefore,
                  onEnabledChanged: (v) => setState(() => _notifyExpiry = v),
                  onDaysChanged: (v) => setState(() => _notifyDaysBefore = v),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isSaving
                    ? 'Menyimpan...'
                    : widget.isEditing
                        ? 'Simpan Perubahan'
                        : 'Simpan & Lanjutkan',
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadiusSlider extends StatelessWidget {
  const _RadiusSlider({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const min = BusinessProfile.minRadiusKm;
    const max = BusinessProfile.maxRadiusKm;

    return Column(
      children: [
        Text(
          '$value km',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value km',
          activeColor: AppColors.primary,
          onChanged: (v) => onChanged(v.round()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$min km', style: _hintStyle),
              Text('$max km', style: _hintStyle),
            ],
          ),
        ),
      ],
    );
  }

  static const _hintStyle = TextStyle(fontSize: 12, color: AppColors.muted);
}

class _ExpiryNotificationSetting extends StatelessWidget {
  const _ExpiryNotificationSetting({
    required this.enabled,
    required this.daysBefore,
    required this.onEnabledChanged,
    required this.onDaysChanged,
  });

  final bool enabled;
  final int daysBefore;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onDaysChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Ingatkan saya sebelum stok kedaluwarsa',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.text.withValues(alpha: 0.8),
                ),
              ),
            ),
            Switch(
              value: enabled,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primary,
              onChanged: onEnabledChanged,
            ),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: [
              for (final days in BusinessProfile.notifyDayOptions)
                ButtonSegment(value: days, label: Text('H-$days')),
            ],
            selected: {daysBefore},
            showSelectedIcon: false,
            onSelectionChanged: (value) => onDaysChanged(value.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.greenBadge,
              selectedForegroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.divider),
            ),
          ),
        ],
      ],
    );
  }
}
