import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.settings, super.key});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: AnimatedBuilder(
            animation: settings,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ─────────────────────────────────────────────
                  _SettingsHeader(title: l10n.settingsTitle),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Language ───────────────────────────────────────────
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(
                          icon: Icons.language_outlined,
                          label: l10n.settingsLanguage,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _LanguageSelector(
                          settings: settings,
                          l10n: l10n,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Speech Rate ────────────────────────────────────────
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(
                          icon: Icons.record_voice_over_outlined,
                          label: l10n.settingsSpeechRate,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SpeechRateSlider(settings: settings, l10n: l10n),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Haptic Feedback ────────────────────────────────────
                  _GlassCard(
                    child: _HapticsToggle(settings: settings, l10n: l10n),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'WARE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const TextSpan(
                text: 'ENY',
                style: TextStyle(
                  color: AppColors.electricGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ── Glass Card ────────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.electricGreen, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.electricGreen,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

// ── Language Selector ─────────────────────────────────────────────────────────

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.settings, required this.l10n});

  final SettingsController settings;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: l10n.settingsLanguageHint,
      child: Row(
        children: [
          _LangPill(
            label: 'EN — ${l10n.settingsLanguageEn}',
            active: !settings.isArabic,
            onTap: () {
              settings.setLocale(const Locale('en'));
              SemanticsService.announce(
                'English selected',
                TextDirection.ltr,
              );
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          _LangPill(
            label: 'AR — ${l10n.settingsLanguageAr}',
            active: settings.isArabic,
            onTap: () {
              settings.setLocale(const Locale('ar'));
              SemanticsService.announce(
                'تم اختيار العربية',
                TextDirection.rtl,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  const _LangPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: active ? AppColors.electricGreenDim : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.electricGreen : AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppColors.electricGreen : Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Speech Rate Slider ────────────────────────────────────────────────────────

class _SpeechRateSlider extends StatelessWidget {
  const _SpeechRateSlider({required this.settings, required this.l10n});

  final SettingsController settings;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          slider: true,
          label: l10n.settingsSpeechRate,
          value: '${(settings.speechRate * 100).round()}%',
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.electricGreen,
              inactiveTrackColor: AppColors.glassBorder,
              thumbColor: AppColors.electricGreen,
              overlayColor: AppColors.electricGreenDim,
              trackHeight: 3,
            ),
            child: Slider(
              value: settings.speechRate,
              min: 0.1,
              max: 1.0,
              divisions: 18,
              onChanged: (val) => settings.setSpeechRate(val),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.settingsSpeechRateSlow,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(settings.speechRate * 100).round()}%',
              style: const TextStyle(
                color: AppColors.electricGreen,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              l10n.settingsSpeechRateFast,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Haptics Toggle ────────────────────────────────────────────────────────────

class _HapticsToggle extends StatelessWidget {
  const _HapticsToggle({required this.settings, required this.l10n});

  final SettingsController settings;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: settings.hapticsEnabled,
      label: l10n.settingsHaptics,
      hint: l10n.settingsHapticsHint,
      child: Row(
        children: [
          _SectionLabel(
            icon: Icons.vibration_outlined,
            label: l10n.settingsHaptics,
          ),
          const Spacer(),
          Switch(
            value: settings.hapticsEnabled,
            onChanged: (val) => settings.setHapticsEnabled(val),
            activeColor: AppColors.electricGreen,
            activeTrackColor: AppColors.electricGreenDim,
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: AppColors.glassBorder,
          ),
        ],
      ),
    );
  }
}
