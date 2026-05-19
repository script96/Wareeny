import 'package:flutter/material.dart';

import '../../../services/object_finder_types.dart';
import '../../../services/speech_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../reusable/app_bottom_sheet.dart';
import '../reusable/app_option_chip.dart';
import '../reusable/app_section_header.dart';

Future<ObjectFinderTarget?> showTargetPicker(BuildContext context) async {
  SpeechService().speak(
    'اختار الشيء الذي تريد البحث عنه',
    force: true,
    throttle: false,
  );

  return showModalBottomSheet<ObjectFinderTarget>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _TargetPickerSheet(),
  );
}

class _TargetPickerSheet extends StatefulWidget {
  const _TargetPickerSheet();

  @override
  State<_TargetPickerSheet> createState() => _TargetPickerSheetState();
}

class _TargetPickerSheetState extends State<_TargetPickerSheet> {
  final _customController = TextEditingController();
  bool _customHasText = false;

  @override
  void initState() {
    super.initState();
    _customController.addListener(_syncCustomState);
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _syncCustomState() {
    final hasText = _customController.text.trim().isNotEmpty;
    if (hasText != _customHasText) {
      setState(() => _customHasText = hasText);
    }
  }

  void _selectPreset(String label) {
    final target = ObjectFinderRegistry.resolve(label);
    Navigator.pop(context, target);
  }

  void _selectCustom() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, ObjectFinderRegistry.fromCustomText(text));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return AppBottomSheet(
          padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, 32),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              const AppBottomSheetHeader(
                title: 'البحث عن شيء',
                style: AppTextStyles.pickerTitle,
                centerTitle: true,
              ),
              const SizedBox(height: AppSpacing.xl),
              _TargetSection(
                icon: Icons.bolt_rounded,
                title: 'بحث سريع ⚡',
                color: Colors.greenAccent,
                labels: ObjectFinderRegistry.fastTargets,
                onSelect: _selectPreset,
              ),
              const SizedBox(height: 28),
              _TargetSection(
                icon: Icons.psychology_rounded,
                title: 'بحث ذكي 🧠',
                color: Colors.orangeAccent,
                labels: ObjectFinderRegistry.smartTargets,
                onSelect: _selectPreset,
              ),
              const SizedBox(height: 28),
              _CustomTargetInput(
                controller: _customController,
                hasText: _customHasText,
                onSubmit: _selectCustom,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TargetSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Map<String, String> labels;
  final ValueChanged<String> onSelect;

  const _TargetSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.labels,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(icon: icon, label: title, color: color),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: labels.entries
              .map(
                (entry) => AppOptionChip(
                  label: entry.value,
                  color: color,
                  onTap: () => onSelect(entry.key),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _CustomTargetInput extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final VoidCallback onSubmit;

  const _CustomTargetInput({
    required this.controller,
    required this.hasText,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          icon: Icons.edit_rounded,
          label: 'بحث مخصص',
          color: Colors.cyanAccent,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              child: Semantics(
                label: 'اكتب اسم الشيء',
                child: TextField(
                  controller: controller,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 18,
                  ),
                  decoration: InputDecoration(
                    hintText: 'اكتب الشيء الذي تبحث عنه',
                    hintStyle: TextStyle(
                      color: Colors.white.withAlpha(80),
                      fontSize: 16,
                    ),
                    filled: true,
                    fillColor: Colors.white.withAlpha(15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Semantics(
              label: 'ابدأ البحث',
              button: true,
              child: Material(
                color: hasText ? Colors.cyanAccent : Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: hasText ? onSubmit : null,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Icon(
                      Icons.search_rounded,
                      color: hasText ? Colors.black : Colors.white38,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
