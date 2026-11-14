import 'package:flutter/material.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../model/food_category.dart';
import '../../../model/stock_item.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../stock_controller.dart';

/// Form tambah stok baru, atau edit jika [initial] diisi.
class StockFormPage extends StatefulWidget {
  const StockFormPage({super.key, this.initial});

  final StockItem? initial;

  bool get isEditing => initial != null;

  @override
  State<StockFormPage> createState() => _StockFormPageState();
}

class _StockFormPageState extends State<StockFormPage> {
  late final _nameController =
      TextEditingController(text: widget.initial?.name);
  late final _quantityController = TextEditingController(
    text: widget.initial == null
        ? null
        : formatQuantity(widget.initial!.quantity),
  );
  late final _priceController = TextEditingController(
    text: widget.initial?.pricePerUnit.toString(),
  );
  late final _notesController =
      TextEditingController(text: widget.initial?.notes);

  late FoodCategory? _category = widget.initial?.category;
  late StockUnit _unit = widget.initial?.unit ?? StockUnit.kg;
  late DateTime? _expiryDate = widget.initial?.expiryDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final now = StockScope.read(context).now;
    final today = DateTime(now.year, now.month, now.day);
    final initial = _expiryDate ?? today.add(const Duration(days: 3));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      // Boleh tanggal lampau untuk mencatat stok yang sudah kedaluwarsa.
      firstDate: (initial.isBefore(today) ? initial : today)
          .subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365 * 3)),
      helpText: 'Tanggal kedaluwarsa',
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final quantity = parseQuantity(_quantityController.text);
    final price = parseRupiah(_priceController.text);
    final notes = _notesController.text.trim();
    final category = _category;
    final expiryDate = _expiryDate;

    if (name.isEmpty) return _showMessage('Nama bahan wajib diisi.');
    if (category == null) return _showMessage('Pilih kategori bahan.');
    if (quantity == null || quantity <= 0) {
      return _showMessage('Jumlah harus lebih dari 0.');
    }
    if (price == null) return _showMessage('Harga per satuan wajib diisi.');
    if (expiryDate == null) {
      return _showMessage('Pilih tanggal kedaluwarsa.');
    }

    final stock = StockScope.read(context);
    final user = SessionScope.read(context).currentUser;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final now = stock.now;
      final initial = widget.initial;
      if (initial == null) {
        await stock.add(
          StockItem(
            userId: user.id!,
            name: name,
            category: category,
            quantity: quantity,
            unit: _unit,
            pricePerUnit: price,
            expiryDate: expiryDate,
            notes: notes.isEmpty ? null : notes,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await stock.update(
          StockItem(
            id: initial.id,
            userId: initial.userId,
            name: name,
            category: category,
            quantity: quantity,
            unit: _unit,
            pricePerUnit: price,
            expiryDate: expiryDate,
            notes: notes.isEmpty ? null : notes,
            createdAt: initial.createdAt,
            updatedAt: now,
          ),
        );
      }
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing ? 'Stok diperbarui.' : 'Stok "$name" ditambahkan.',
          ),
        ),
      );
    } catch (error) {
      debugPrint('Gagal menyimpan stok: $error');
      _showMessage('Gagal menyimpan stok. Coba lagi.');
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
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Stok' : 'Tambah Stok',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _nameController,
                label: 'Nama Bahan',
                hint: 'Contoh: Tomat Ceri',
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<FoodCategory>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Kategori'),
                hint: const Text('Pilih kategori'),
                borderRadius: BorderRadius.circular(12),
                dropdownColor: Colors.white,
                items: [
                  for (final category in FoodCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(category.icon,
                              size: 18, color: AppColors.muted),
                          const SizedBox(width: 10),
                          Text(category.label),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: AppTextField(
                      controller: _quantityController,
                      label: 'Jumlah',
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<StockUnit>(
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Satuan'),
                      borderRadius: BorderRadius.circular(12),
                      dropdownColor: Colors.white,
                      items: [
                        for (final unit in StockUnit.values)
                          DropdownMenuItem(
                            value: unit,
                            child: Text(unit.label),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _unit = value ?? _unit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _priceController,
                label: 'Harga per Satuan (Rp)',
                hint: 'Contoh: 15000',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _DateField(
                value: _expiryDate,
                onTap: _pickExpiryDate,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _notesController,
                label: 'Catatan (opsional)',
                hint: 'Contoh: Grade B, simpan di chiller',
                maxLines: 3,
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: _isSaving
                    ? 'Menyimpan...'
                    : widget.isEditing
                        ? 'Simpan Perubahan'
                        : 'Simpan Stok',
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Tanggal Kedaluwarsa',
          suffixIcon: Icon(Icons.event_outlined, size: 20),
        ),
        isEmpty: value == null,
        child: Text(
          value == null ? '' : formatDate(value!),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}
