import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/shared/emergency/emergency_contact.dart';
import 'package:wareeny/shared/emergency/phone_number_normalizer.dart';

class EmergencyContactSetupScreen extends StatefulWidget {
  const EmergencyContactSetupScreen({
    required this.onSaved,
    required this.onCancel,
    required this.canCancel,
    this.existingContact,
    super.key,
  });

  final EmergencyContact? existingContact;
  final Future<void> Function(EmergencyContact contact) onSaved;
  final VoidCallback onCancel;
  final bool canCancel;

  @override
  State<EmergencyContactSetupScreen> createState() =>
      _EmergencyContactSetupScreenState();
}

class _EmergencyContactSetupScreenState
    extends State<EmergencyContactSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _normalizer = const PhoneNumberNormalizer();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _relationshipController;
  var _source = EmergencyContactSource.manual;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final contact = widget.existingContact;
    _nameController = TextEditingController(text: contact?.name);
    _phoneController = TextEditingController(text: contact?.phoneNumber);
    _relationshipController = TextEditingController(
      text: contact?.relationship,
    );
    _source = contact?.source ?? EmergencyContactSource.manual;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: widget.canCancel,
        leading: widget.canCancel
            ? IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(l10n.emergencyContactTitle),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                Icons.health_and_safety,
                size: 64,
                color: AppColors.electricGreen,
                semanticLabel: l10n.emergencyContactTitle,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.emergencyContactExplanation,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _pickContact,
                icon: const Icon(Icons.contacts),
                label: Text(l10n.chooseFromContacts),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration(l10n.contactName),
                onChanged: (_) => _source = EmergencyContactSource.manual,
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.fieldRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration(l10n.contactPhone),
                onChanged: (_) => _source = EmergencyContactSource.manual,
                validator: (value) => _normalizer.normalize(value ?? '') == null
                    ? l10n.invalidPhoneNumber
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _relationshipController,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration(l10n.contactRelationship),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _testCall,
                icon: const Icon(Icons.phone),
                label: Text(l10n.testCall),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(l10n.confirmEmergencyContact),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white38),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.electricGreen),
    ),
  );

  Future<void> _pickContact() async {
    final l10n = AppLocalizations.of(context);
    final permission = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (permission != PermissionStatus.granted) {
      _showMessage(l10n.contactsPermissionDenied);
      return;
    }

    final selected = await FlutterContacts.native.showPicker(
      properties: {ContactProperty.phone},
    );
    if (selected == null) return;
    if (selected.phones.isEmpty) {
      _showMessage(l10n.contactHasNoPhone);
      return;
    }

    final phone = selected.phones.length == 1
        ? selected.phones.first
        : await _selectPhone(selected.phones);
    if (phone == null || !mounted) return;

    setState(() {
      _nameController.text = selected.displayName ?? '';
      _phoneController.text = phone.normalizedNumber ?? phone.number;
      _source = EmergencyContactSource.deviceContact;
    });
  }

  Future<Phone?> _selectPhone(List<Phone> phones) {
    return showModalBottomSheet<Phone>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: phones
              .map(
                (phone) => ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(phone.number),
                  subtitle: Text(phone.label.toString()),
                  onTap: () => Navigator.pop(context, phone),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Future<void> _testCall() async {
    final normalized = _normalizer.normalize(_phoneController.text);
    if (normalized == null) {
      _showMessage(AppLocalizations.of(context).invalidPhoneNumber);
      return;
    }
    await AppScope.of(context).emergencyCallBridge.call(normalized);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final saveError = AppLocalizations.of(context).unableToSaveContact;
    setState(() => _saving = true);
    final contact = EmergencyContact(
      name: _nameController.text.trim(),
      phoneNumber: _normalizer.normalize(_phoneController.text)!,
      relationship: _relationshipController.text.trim(),
      source: _source,
      verified: true,
    );
    try {
      await widget.onSaved(contact);
    } catch (_) {
      _showMessage(saveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
