import 'package:flutter/material.dart';

import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/settings/emergency_contacts_screen.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';

/// One-time onboarding screen shown on first launch to introduce the
/// emergency shake feature and prompt the user to add a contact.
///
/// Displayed by [NavigationShell] when
/// [SettingsController.hasSeenEmergencyOnboarding] is false.
class EmergencyOnboardingScreen extends StatelessWidget {
  const EmergencyOnboardingScreen({required this.settings, super.key});

  final SettingsController settings;

  Future<void> _proceed(BuildContext context, {required bool goToContacts}) async {
    await settings.markEmergencyOnboardingSeen();
    if (!context.mounted) return;
    if (goToContacts) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => EmergencyContactsScreen(settings: settings),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isArabic;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // ── Icon ──────────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.red.shade700, Colors.red.shade900],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withAlpha(80),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sos_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Title ─────────────────────────────────────────────────────
              Text(
                isAr ? 'وضع الطوارئ' : 'Emergency Mode',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),

              // ── Description steps ─────────────────────────────────────────
              _StepRow(
                number: '1',
                text: isAr
                    ? 'هزّ هاتفك بقوة في أي وضع'
                    : 'Shake your phone firmly in any mode',
                isArabic: isAr,
              ),
              const SizedBox(height: 12),
              _StepRow(
                number: '2',
                text: isAr
                    ? 'ستسمع العدّ التنازلي: 3، 2، 1...'
                    : 'You\'ll hear a countdown: 3, 2, 1...',
                isArabic: isAr,
              ),
              const SizedBox(height: 12),
              _StepRow(
                number: '3',
                text: isAr
                    ? 'يتم الاتصال بأول شخص موثوق وإرسال موقعك'
                    : 'Your trusted contact is called and location is shared',
                isArabic: isAr,
              ),
              const SizedBox(height: 12),
              _StepRow(
                number: '✕',
                text: isAr
                    ? 'اضغط على الشاشة خلال 3 ثوانٍ للإلغاء'
                    : 'Tap the screen within 3 seconds to cancel',
                isArabic: isAr,
                isCancel: true,
              ),

              const Spacer(),

              // ── CTA buttons ───────────────────────────────────────────────
              _PrimaryButton(
                label: isAr ? 'إضافة جهة اتصال للطوارئ' : 'Add Emergency Contact',
                icon: Icons.person_add_rounded,
                onTap: () => _proceed(context, goToContacts: true),
              ),
              const SizedBox(height: AppSpacing.sm),
              _SecondaryButton(
                label: isAr ? 'تخطّي الآن' : 'Skip for now',
                onTap: () => _proceed(context, goToContacts: false),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isAr
                    ? 'يمكنك إضافة جهات اتصال لاحقاً من الإعدادات'
                    : 'You can add contacts later from Settings',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step row ──────────────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.text,
    required this.isArabic,
    this.isCancel = false,
  });

  final String number;
  final String text;
  final bool isArabic;
  final bool isCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCancel
                ? Colors.white.withAlpha(15)
                : Colors.red.withAlpha(40),
            border: Border.all(
              color: isCancel ? Colors.white24 : Colors.red.withAlpha(80),
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: isCancel ? Colors.white38 : Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Buttons ───────────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.red.shade900],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withAlpha(60),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.electricGreen.withAlpha(200),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
