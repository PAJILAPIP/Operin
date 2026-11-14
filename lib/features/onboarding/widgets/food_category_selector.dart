import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../model/food_category.dart';

/// Pilihan multi kategori bahan dalam bentuk chip.
class FoodCategorySelector extends StatelessWidget {
  const FoodCategorySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<FoodCategory> selected;
  final ValueChanged<Set<FoodCategory>> onChanged;

  void _toggle(FoodCategory category, bool value) {
    final next = {...selected};
    value ? next.add(category) : next.remove(category);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in FoodCategory.values)
          FilterChip(
            label: Text(category.label),
            avatar: Icon(
              category.icon,
              size: 18,
              color: selected.contains(category)
                  ? AppColors.primary
                  : AppColors.muted,
            ),
            showCheckmark: false,
            selected: selected.contains(category),
            onSelected: (value) => _toggle(category, value),
            selectedColor: AppColors.greenBadge,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected.contains(category)
                  ? AppColors.primary
                  : AppColors.divider,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected.contains(category)
                  ? AppColors.primary
                  : AppColors.text,
            ),
          ),
      ],
    );
  }
}
