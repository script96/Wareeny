import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

import 'package:wareeny/core/emergency/emergency_contact.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';

/// Maximum number of emergency contacts the user can save.
const _maxContacts = 3;

/// A settings sub-screen to manage up to 3 emergency contacts.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({required this.settings, super.key});

  final SettingsController settings;

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  late List<EmergencyContact> _contacts;
  late bool _shareLocation;

  @override
  void initState() {
    super.initState();
    _contacts = List.of(widget.settings.emergencyContacts);
    _shareLocation = widget.settings.shareLocationWithEmergencyContacts;
  }

  Future<void> _save() async {
    await widget.settings.setEmergencyContacts(_contacts);
  }

  Future<void> _setShareLocation(bool enabled) async {
    setState(() => _shareLocation = enabled);
    await widget.settings.setShareLocationWithEmergencyContacts(enabled);
  }

  void _addContact() {
    if (_contacts.length >= _maxContacts) return;
    _showEditDialog(null, null);
  }

  void _editContact(int index) {
    _showEditDialog(index, _contacts[index]);
  }

  Future<void> _deleteContact(int index) async {
    setState(() => _contacts.removeAt(index));
    await _save();
  }

  Future<void> _showEditDialog(int? index, EmergencyContact? existing) async {
    final isAr = AppLocalizations.of(context).isArabic;

    final result = await showDialog<EmergencyContact>(
      context: context,
      builder: (ctx) => _ContactEditDialog(existing: existing, isArabic: isAr),
    );

    if (result != null && mounted) {
      setState(() {
        if (index == null) {
          _contacts.add(result);
        } else {
          _contacts[index] = result;
        }
      });
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isArabic;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Semantics(
          header: true,
          child: Text(
            isAr ? 'جهات الطوارئ' : 'Emergency Contacts',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        leading: Semantics(
          button: true,
          label: isAr ? 'رجوع' : 'Back',
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.electricGreen,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Info banner ───────────────────────────────────────────────
              _InfoBanner(isArabic: isAr),
              const SizedBox(height: AppSpacing.md),
              _LocationSharingSwitch(
                isArabic: isAr,
                value: _shareLocation,
                onChanged: _setShareLocation,
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Contact list ──────────────────────────────────────────────
              Expanded(
                child: _contacts.isEmpty
                    ? _EmptyState(isArabic: isAr, onAdd: _addContact)
                    : ListView.separated(
                        itemCount: _contacts.length,
                        separatorBuilder: (ctx, i) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          return _ContactTile(
                            contact: _contacts[index],
                            index: index,
                            isArabic: isAr,
                            onEdit: () => _editContact(index),
                            onDelete: () => _deleteContact(index),
                          );
                        },
                      ),
              ),

              // ── Add button ────────────────────────────────────────────────
              if (_contacts.length < _maxContacts) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  button: true,
                  label: isAr
                      ? 'إضافة جهة اتصال للطوارئ'
                      : 'Add emergency contact',
                  child: GestureDetector(
                    onTap: _addContact,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.red.shade700,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.red.withAlpha(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            color: Colors.redAccent,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isAr ? 'إضافة جهة اتصال' : 'Add Contact',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info Banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.isArabic});
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withAlpha(80)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isArabic
                      ? 'هزّ الهاتف لتشغيل وضع الطوارئ. سيتم الاتصال بأول جهة اتصال، ويمكنك اختيار مشاركة موقعك أدناه.'
                      : 'Shake the phone to trigger emergency mode. Your first contact will be called, and you can choose whether to share your location below.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationSharingSwitch extends StatelessWidget {
  const _LocationSharingSwitch({
    required this.isArabic,
    required this.value,
    required this.onChanged,
  });

  final bool isArabic;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: isArabic
          ? 'مشاركة موقعي مع جهات اتصال الطوارئ'
          : 'Share my location with emergency contacts',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.glassWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: SwitchListTile.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.electricGreen,
            title: Text(
              isArabic ? 'مشاركة موقعي' : 'Share my location',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              isArabic
                  ? 'إضافة رابط خرائط Google إلى رسالة الطوارئ'
                  : 'Include a Google Maps link in the emergency message',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Contact Tile ──────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.index,
    required this.isArabic,
    required this.onEdit,
    required this.onDelete,
  });

  final EmergencyContact contact;
  final int index;
  final bool isArabic;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isPrimary = index == 0;
    return Semantics(
      label: isArabic
          ? '${contact.name}، ${contact.phone}${isPrimary ? '، جهة الاتصال الأولى' : ''}'
          : '${contact.name}, ${contact.phone}${isPrimary ? ', primary contact' : ''}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPrimary
                    ? Colors.red.withAlpha(120)
                    : AppColors.glassBorder,
              ),
            ),
            child: Row(
              children: [
                // Avatar circle with initial.
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPrimary
                        ? Colors.red.withAlpha(60)
                        : Colors.white.withAlpha(15),
                    border: Border.all(
                      color: isPrimary ? Colors.redAccent : Colors.white24,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      contact.name.isNotEmpty
                          ? contact.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: isPrimary ? Colors.redAccent : Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            contact.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isPrimary) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isArabic ? 'أول' : 'PRIMARY',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contact.phone,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Edit button.
                Semantics(
                  button: true,
                  label: isArabic
                      ? 'تعديل ${contact.name}'
                      : 'Edit ${contact.name}',
                  child: IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: onEdit,
                  ),
                ),
                // Delete button.
                Semantics(
                  button: true,
                  label: isArabic
                      ? 'حذف ${contact.name}'
                      : 'Delete ${contact.name}',
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isArabic, required this.onAdd});
  final bool isArabic;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contact_emergency_outlined,
            size: 64,
            color: Colors.red.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic
                ? 'لا توجد جهات اتصال للطوارئ'
                : 'No emergency contacts yet',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'أضف شخصاً موثوقاً سيُتصل به عند الطوارئ'
                : 'Add a trusted person to call in an emergency',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Edit / Add Dialog ─────────────────────────────────────────────────────────

class _ContactEditDialog extends StatefulWidget {
  const _ContactEditDialog({required this.existing, required this.isArabic});

  final EmergencyContact? existing;
  final bool isArabic;

  @override
  State<_ContactEditDialog> createState() => _ContactEditDialogState();
}

class _ContactEditDialogState extends State<_ContactEditDialog> {
  final FlutterNativeContactPicker _contactPicker =
      FlutterNativeContactPicker();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  bool get _isArabic => widget.isArabic;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _phoneController = TextEditingController(
      text: widget.existing?.phone ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    try {
      final contact = await _contactPicker.selectPhoneNumber();
      if (!mounted || contact == null) return;

      final phone =
          contact.selectedPhoneNumber ??
          contact.phoneNumbers?.firstOrNull ??
          '';
      if (phone.isEmpty) return;

      _phoneController.text = phone;
      final name = contact.fullName?.trim() ?? '';
      if (name.isNotEmpty) _nameController.text = name;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'تعذّر فتح جهات الاتصال. يمكنك كتابة الرقم يدوياً.'
                : 'Could not open contacts. You can enter the number manually.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isArabic ? 'جهة اتصال الطوارئ' : 'Emergency Contact',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: _isArabic
                  ? 'اختيار جهة اتصال من الهاتف'
                  : 'Choose a contact from this phone',
              child: OutlinedButton.icon(
                onPressed: _pickContact,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(color: Colors.red.withAlpha(120)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.contacts_outlined, size: 20),
                label: Text(
                  _isArabic ? 'اختيار من جهات الاتصال' : 'Choose from contacts',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _Field(
              controller: _nameController,
              label: _isArabic ? 'الاسم' : 'Name',
              hint: _isArabic ? 'مثال: أمي' : 'e.g. Mom',
              icon: Icons.person_outline_rounded,
              isArabic: _isArabic,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _phoneController,
              label: _isArabic ? 'رقم الهاتف' : 'Phone number',
              hint: '+201234567890',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              isArabic: _isArabic,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: _isArabic ? 'إلغاء' : 'Cancel',
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        _isArabic ? 'إلغاء' : 'Cancel',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: _isArabic ? 'حفظ' : 'Save',
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final name = _nameController.text.trim();
                        final phone = _phoneController.text.trim();
                        if (name.isEmpty || phone.isEmpty) return;
                        Navigator.of(
                          context,
                        ).pop(EmergencyContact(name: name, phone: phone));
                      },
                      child: Text(
                        _isArabic ? 'حفظ' : 'Save',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isArabic,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isArabic;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: Icon(icon, color: Colors.redAccent, size: 20),
            filled: true,
            fillColor: Colors.white.withAlpha(10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(25)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(25)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
