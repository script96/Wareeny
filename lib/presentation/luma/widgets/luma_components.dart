import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/luma/luma_models.dart';

class MainStatusBanner extends StatelessWidget {
  const MainStatusBanner({
    required this.state,
    required this.title,
    required this.message,
    super.key,
  });

  final AssistantUiState state;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyleFor(state);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: style.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, color: style.foreground, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: style.foreground,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: style.foreground.withValues(alpha: 0.92),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LargeActionButton extends StatelessWidget {
  const LargeActionButton({
    required this.label,
    required this.icon,
    this.supportingText,
    this.onPressed,
    this.onLongPressStart,
    this.onLongPressEnd,
    super.key,
  });

  final String label;
  final String? supportingText;
  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      hint: supportingText,
      child: GestureDetector(
        onLongPressStart: (_) => onLongPressStart?.call(),
        onLongPressEnd: (_) => onLongPressEnd?.call(),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(110),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.lg),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (supportingText != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  supportingText!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.86),
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ModeCard extends StatelessWidget {
  const ModeCard({
    required this.mode,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final LumaModeDefinition mode;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: Icon(mode.icon, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mode.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: enabled
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          mode.description,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _InfoChip(label: mode.category.label),
                  if (!enabled)
                    const _InfoChip(
                      label: 'Not available in current environment',
                      color: AppColors.warningAmber,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CameraPreviewPlaceholder extends StatelessWidget {
  const CameraPreviewPlaceholder({
    required this.label,
    this.overlays = const [],
    super.key,
  });

  final String label;
  final List<Alignment> overlays;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surfaceAlt, AppColors.surfaceMuted],
          ),
          border: Border.all(color: AppColors.outline),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                    border: Border.all(
                      color: AppColors.textPrimary.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
            ),
            for (final overlay in overlays)
              Align(
                alignment: overlay,
                child: Container(
                  width: 90,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                    border: Border.all(
                      color: AppColors.focusRing,
                      width: 2,
                    ),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.videocam_rounded,
                    size: 40,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Camera preview for testing and sighted helpers',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AssistantSpeechOutput extends StatelessWidget {
  const AssistantSpeechOutput({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class DangerShortcutButton extends StatelessWidget {
  const DangerShortcutButton({
    required this.onPressed,
    super.key,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppColors.dangerRed,
      foregroundColor: AppColors.textPrimary,
      icon: const Icon(Icons.sos_rounded),
      label: const Text('Danger'),
    );
  }
}

class LumaBottomNavigation extends StatelessWidget {
  const LumaBottomNavigation({
    required this.currentSection,
    required this.onSelect,
    super.key,
  });

  final LumaSection currentSection;
  final ValueChanged<LumaSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentSection.index,
      onDestinationSelected: (index) => onSelect(LumaSection.values[index]),
      destinations: [
        for (final section in LumaSection.values)
          NavigationDestination(
            icon: Icon(section.icon),
            label: section.label,
          ),
      ],
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class SavedItemCard extends StatelessWidget {
  const SavedItemCard({
    required this.item,
    required this.onFind,
    required this.onRename,
    required this.onDelete,
    super.key,
  });

  final SavedItemEntry item;
  final VoidCallback onFind;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Label: ${item.label}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reference image: ${item.referenceImagePath}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Created: ${_formatDate(item.createdDate)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            Text(
              'Last found: ${item.lastFoundDate == null ? 'Never' : _formatDate(item.lastFoundDate!)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton(
                  onPressed: onFind,
                  child: const Text('Find Item'),
                ),
                OutlinedButton(
                  onPressed: onRename,
                  child: const Text('Rename'),
                ),
                OutlinedButton(
                  onPressed: onDelete,
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? AppColors.calmBlue;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: resolved.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class StatusInfoChip extends StatelessWidget {
  const StatusInfoChip({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LumaStatusStyle {
  const LumaStatusStyle({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;
}

LumaStatusStyle _statusStyleFor(AssistantUiState state) {
  return switch (state) {
    AssistantUiState.idle => const LumaStatusStyle(
        background: AppColors.surfaceAlt,
        border: AppColors.outline,
        foreground: AppColors.textPrimary,
        icon: Icons.waving_hand_rounded,
      ),
    AssistantUiState.listening => const LumaStatusStyle(
        background: AppColors.listeningBlue,
        border: AppColors.focusRing,
        foreground: AppColors.textPrimary,
        icon: Icons.mic_rounded,
      ),
    AssistantUiState.scanning => const LumaStatusStyle(
        background: AppColors.scanningTeal,
        border: AppColors.guardianGreen,
        foreground: AppColors.textPrimary,
        icon: Icons.document_scanner_rounded,
      ),
    AssistantUiState.guiding => const LumaStatusStyle(
        background: AppColors.guardianGreen,
        border: AppColors.calmBlue,
        foreground: AppColors.textPrimary,
        icon: Icons.assistant_navigation_rounded,
      ),
    AssistantUiState.reading => const LumaStatusStyle(
        background: AppColors.surfaceMuted,
        border: AppColors.calmBlue,
        foreground: AppColors.textPrimary,
        icon: Icons.record_voice_over_rounded,
      ),
    AssistantUiState.warning => const LumaStatusStyle(
        background: AppColors.warningAmber,
        border: AppColors.signalAmber,
        foreground: AppColors.ink,
        icon: Icons.priority_high_rounded,
      ),
    AssistantUiState.danger => const LumaStatusStyle(
        background: AppColors.dangerRed,
        border: AppColors.alertRed,
        foreground: AppColors.textPrimary,
        icon: Icons.warning_rounded,
      ),
    AssistantUiState.emergency => const LumaStatusStyle(
        background: AppColors.emergencyCrimson,
        border: AppColors.dangerRed,
        foreground: AppColors.textPrimary,
        icon: Icons.call_rounded,
      ),
  };
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
