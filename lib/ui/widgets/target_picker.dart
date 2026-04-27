import 'package:flutter/material.dart';
import '../../services/speech_service.dart';
import '../../services/object_finder_types.dart';

/// Show the Object Finder target picker.
///
/// Returns the selected [ObjectFinderTarget], or null if dismissed.
Future<ObjectFinderTarget?> showTargetPicker(BuildContext context) async {
  // Announce picker opening for blind users
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
    _customController.addListener(() {
      final hasText = _customController.text.trim().isNotEmpty;
      if (hasText != _customHasText) {
        setState(() => _customHasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _selectFast(String label) {
    final target = ObjectFinderRegistry.resolve(label);
    Navigator.pop(context, target);
  }

  void _selectSmart(String label) {
    final target = ObjectFinderRegistry.resolve(label);
    Navigator.pop(context, target);
  }

  void _selectCustom() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    final target = ObjectFinderRegistry.fromCustomText(text);
    Navigator.pop(context, target);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              const Center(
                child: Text(
                  'البحث عن شيء',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Fast Finder presets ──
              _SectionHeader(
                icon: Icons.bolt_rounded,
                label: 'بحث سريع ⚡',
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: ObjectFinderRegistry.fastTargets.entries
                    .map((e) => _TargetChip(
                          label: e.value,
                          color: Colors.greenAccent,
                          onTap: () => _selectFast(e.key),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 28),

              // ── Smart Finder presets ──
              _SectionHeader(
                icon: Icons.psychology_rounded,
                label: 'بحث ذكي 🧠',
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: ObjectFinderRegistry.smartTargets.entries
                    .map((e) => _TargetChip(
                          label: e.value,
                          color: Colors.orangeAccent,
                          onTap: () => _selectSmart(e.key),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 28),

              // ── Custom text input ──
              _SectionHeader(
                icon: Icons.edit_rounded,
                label: 'بحث مخصص',
                color: Colors.cyanAccent,
              ),
              const SizedBox(height: 12),
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'اكتب اسم الشيء',
                      child: TextField(
                        controller: _customController,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.white,
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
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    label: 'ابدأ البحث',
                    button: true,
                    child: Material(
                      color: _customHasText
                          ? Colors.cyanAccent
                          : Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _customHasText ? _selectCustom : null,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          child: Icon(
                            Icons.search_rounded,
                            color: _customHasText
                                ? Colors.black
                                : Colors.white38,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Helper widgets ──

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _TargetChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TargetChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withAlpha(220),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
