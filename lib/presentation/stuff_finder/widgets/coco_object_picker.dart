import 'package:flutter/material.dart';

import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/stuff_finder/coco_classes.dart';

/// Bottom sheet that lets the user choose a Stuff Finder target.
///
/// Designed for screen-reader use: there is no text field to type into. The
/// list opens on a short shortlist of common objects so TalkBack/VoiceOver
/// users can swipe through a few items and double-tap to pick. A "More objects"
/// item at the end reveals the full catalogue when needed.
class CocoObjectPicker extends StatefulWidget {
  const CocoObjectPicker({required this.selectedTarget, super.key});

  final String? selectedTarget;

  @override
  State<CocoObjectPicker> createState() => _CocoObjectPickerState();
}

class _CocoObjectPickerState extends State<CocoObjectPicker> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Always make sure the currently selected target is visible even if it is
    // not part of the shortlist.
    final selected = widget.selectedTarget;
    final classes = _showAll
        ? stuffFinderClasses
        : <String>[
            ...commonStuffFinderClasses,
            if (selected != null && !commonStuffFinderClasses.contains(selected))
              selected,
          ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          top: AppSpacing.md,
          right: AppSpacing.md,
          bottom: AppSpacing.md,
        ),
        child: Column(
          children: [
            // Decorative drag handle — not useful to a screen reader.
            const ExcludeSemantics(
              child: _DragHandle(),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(
                l10n.sfPickerTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView.builder(
                itemCount: classes.length + (_showAll ? 0 : 1),
                itemBuilder: (context, index) {
                  if (!_showAll && index == classes.length) {
                    return _MoreObjectsTile(
                      label: l10n.sfMoreObjects,
                      onTap: () => setState(() => _showAll = true),
                    );
                  }
                  final label = classes[index];
                  return _ObjectTile(
                    label: label,
                    selected: label == widget.selectedTarget,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tiles ──────────────────────────────────────────────────────────────────────

class _ObjectTile extends StatelessWidget {
  const _ObjectTile({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // One clean node per object: the screen reader announces just the object
    // name (e.g. "Wallet") plus its button/selected role — no category subtitle
    // to read out. MergeSemantics keeps the name, selected flag, and tap action
    // as a single focusable item.
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        child: ListTile(
          key: ValueKey('coco-$label'),
          title: Text(
            _titleCase(label),
            style: const TextStyle(color: Colors.white),
          ),
          trailing: selected
              ? const Icon(Icons.check_circle, color: AppColors.electricGreen)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: () => Navigator.of(context).pop(label),
        ),
      ),
    );
  }
}

class _MoreObjectsTile extends StatelessWidget {
  const _MoreObjectsTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ListTile(
        key: const ValueKey('coco-more'),
        leading: const Icon(Icons.expand_more, color: AppColors.electricGreen),
        title: Text(
          label,
          style: const TextStyle(
            color: AppColors.electricGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white38,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

String _titleCase(String value) {
  return value
      .split(' ')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
