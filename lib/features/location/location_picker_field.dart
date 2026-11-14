import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import 'location_picker_dialog.dart';

/// Field form yang membuka [LocationPickerDialog] dan menampilkan titik
/// yang sudah dipilih.
class LocationPickerField extends StatelessWidget {
  const LocationPickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final LatLng? value;
  final ValueChanged<LatLng> onChanged;

  Future<void> _pick(BuildContext context) async {
    final result = await LocationPickerDialog.show(context, initial: value);
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final picked = value != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: picked ? AppColors.primary : AppColors.border,
            ),
            color: picked ? AppColors.greenSoft : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                picked ? Icons.check_circle : Icons.map_outlined,
                size: 20,
                color: picked
                    ? AppColors.primary
                    : AppColors.text.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      picked ? 'Lokasi ditandai' : 'Tandai lokasi di peta',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: picked
                            ? AppColors.text
                            : AppColors.text.withValues(alpha: 0.5),
                      ),
                    ),
                    if (picked)
                      Text(
                        formatLatLng(value!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.text.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
