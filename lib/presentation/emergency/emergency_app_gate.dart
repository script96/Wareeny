import 'dart:async';

import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/di/service_registry.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/presentation/emergency/emergency_contact_setup_screen.dart';
import 'package:wareeny/presentation/emergency/emergency_experience.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';

class EmergencyAppGate extends StatelessWidget {
  const EmergencyAppGate({required this.settings, super.key});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    if (!services.config.clerkEnabled) {
      return _LocalContactGate(settings: settings);
    }

    return ClerkErrorListener(
      child: ClerkAuthBuilder(
        signedOutBuilder: (_, _) => const _SignedOutSafetyGate(),
        signedInBuilder: (context, authState) {
          return _SignedInGate(settings: settings, authState: authState);
        },
      ),
    );
  }
}

class _SignedInGate extends StatefulWidget {
  const _SignedInGate({required this.settings, required this.authState});

  final SettingsController settings;
  final ClerkAuthState authState;

  @override
  State<_SignedInGate> createState() => _SignedInGateState();
}

class _SignedInGateState extends State<_SignedInGate> {
  var _connected = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_connected) return;
    _connected = true;
    final services = AppScope.of(context);
    final sync = services.emergencySyncService;
    sync.setTokenProvider(() async {
      return (await widget.authState.sessionToken()).jwt;
    });
    unawaited(() async {
      await sync.onSignedIn();
      await services.emergencyController.restoreContactFromCloud();
    }());
  }

  @override
  Widget build(BuildContext context) {
    return _LocalContactGate(settings: widget.settings);
  }
}

class _SignedOutSafetyGate extends StatefulWidget {
  const _SignedOutSafetyGate();

  @override
  State<_SignedOutSafetyGate> createState() => _SignedOutSafetyGateState();
}

class _SignedOutSafetyGateState extends State<_SignedOutSafetyGate> {
  var _showAuthentication = false;
  var _editingContact = false;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    services.emergencySyncService.setTokenProvider(null);
    final controller = services.emergencyController;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _buildContent(context, services),
    );
  }

  Widget _buildContent(BuildContext context, ServiceRegistry services) {
    final controller = services.emergencyController;
    if (_editingContact && controller.contact != null) {
      return EmergencyContactSetupScreen(
        existingContact: controller.contact,
        canCancel: true,
        onCancel: () => setState(() => _editingContact = false),
        onSaved: (contact) async {
          await controller.saveContact(contact);
          if (mounted) setState(() => _editingContact = false);
        },
      );
    }
    if (controller.contact == null || _showAuthentication) {
      return Scaffold(
        appBar: _showAuthentication && controller.contact != null
            ? AppBar(
                leading: IconButton(
                  onPressed: () => setState(() => _showAuthentication = false),
                  icon: const Icon(Icons.arrow_back),
                ),
              )
            : null,
        body: const SafeArea(child: ClerkAuthentication()),
      );
    }

    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        EmergencyExperience(
          settings: services.settings,
          controller: controller,
          onManageContact: () => setState(() => _editingContact = true),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Material(
              color: Colors.amber.shade900,
              child: ListTile(
                title: Text(
                  l10n.sessionExpired,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: TextButton(
                  onPressed: () => setState(() => _showAuthentication = true),
                  child: Text(
                    l10n.signInForSync,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocalContactGate extends StatefulWidget {
  const _LocalContactGate({required this.settings});

  final SettingsController settings;

  @override
  State<_LocalContactGate> createState() => _LocalContactGateState();
}

class _LocalContactGateState extends State<_LocalContactGate> {
  var _editingContact = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).emergencyController;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.contact == null || _editingContact) {
          return EmergencyContactSetupScreen(
            existingContact: controller.contact,
            canCancel: controller.contact != null,
            onCancel: () => setState(() => _editingContact = false),
            onSaved: (contact) async {
              await controller.saveContact(contact);
              if (mounted) setState(() => _editingContact = false);
            },
          );
        }

        return EmergencyExperience(
          settings: widget.settings,
          controller: controller,
          onManageContact: () => setState(() => _editingContact = true),
        );
      },
    );
  }
}
