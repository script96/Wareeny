import 'package:flutter/material.dart';
import '../../services/speech_service.dart';
import '../../services/object_finder_types.dart';

/// Result from the action menu bottom sheet.
enum ActionMenuResult {
  generalObjects,
  currency,
  findObject,
  colorMode,
  readText,
  documentQa,
  exitDocumentQa,
  rescanDocumentQa,
  describeScene,
}

/// Show the Warene action menu as a bottom sheet.
///
/// Returns the selected action, or null if the sheet is dismissed.
/// [currentMode] controls which items are shown/hidden.
Future<ActionMenuResult?> showWareneActionMenu(
  BuildContext context, {
  required WareneMode currentMode,
}) async {
  // Announce menu opening for blind users
  SpeechService().speak('اختار من القائمة', force: true, throttle: false);

  return showModalBottomSheet<ActionMenuResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ActionMenuSheet(currentMode: currentMode),
  );
}

class _ActionMenuSheet extends StatelessWidget {
  final WareneMode currentMode;

  const _ActionMenuSheet({required this.currentMode});

  @override
  Widget build(BuildContext context) {
    final isNonGeneral = currentMode != WareneMode.generalObjects;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              const Text(
                'القائمة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // ── QA specific actions ──
              if (currentMode == WareneMode.documentQa) ...[
                _ActionTile(
                  icon: Icons.document_scanner_rounded,
                  label: 'اسأل عن نص جديد',
                  color: Colors.tealAccent,
                  semanticsLabel: 'اسأل عن نص جديد',
                  onTap: () =>
                      Navigator.pop(context, ActionMenuResult.rescanDocumentQa),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.close_rounded,
                  label: 'إنهاء سؤال النص',
                  color: Colors.redAccent,
                  semanticsLabel: 'إنهاء سؤال النص',
                  onTap: () =>
                      Navigator.pop(context, ActionMenuResult.exitDocumentQa),
                ),
                const SizedBox(height: 12),
              ],

              // ── Mode switches ──

              // General Objects — show when not already in general
              if (isNonGeneral) ...[
                _ActionTile(
                  icon: Icons.visibility_rounded,
                  label: 'أشياء',
                  color: Colors.blueAccent,
                  semanticsLabel: 'وضع الأشياء',
                  onTap: () =>
                      Navigator.pop(context, ActionMenuResult.generalObjects),
                ),
                const SizedBox(height: 12),
              ],

              // Currency — show when not already in currency
              if (currentMode != WareneMode.currency) ...[
                _ActionTile(
                  icon: Icons.attach_money_rounded,
                  label: 'فلوس',
                  color: Colors.amber,
                  semanticsLabel: 'وضع الفلوس',
                  onTap: () =>
                      Navigator.pop(context, ActionMenuResult.currency),
                ),
                const SizedBox(height: 12),
              ],

              // Find Object
              _ActionTile(
                icon: Icons.search_rounded,
                label: 'البحث عن شيء',
                color: Colors.orangeAccent,
                semanticsLabel: 'البحث عن شيء',
                onTap: () =>
                    Navigator.pop(context, ActionMenuResult.findObject),
              ),
              const SizedBox(height: 12),

              // Color Mode — show when not already in color
              if (currentMode != WareneMode.color) ...[
                _ActionTile(
                  icon: Icons.palette_rounded,
                  label: 'وضع الألوان',
                  color: Colors.purpleAccent,
                  semanticsLabel: 'وضع الألوان',
                  onTap: () =>
                      Navigator.pop(context, ActionMenuResult.colorMode),
                ),
                const SizedBox(height: 12),
              ],

              // ── One-shot actions ──

              _ActionTile(
                icon: Icons.menu_book_rounded,
                label: 'قراءة نص',
                color: Colors.cyanAccent,
                semanticsLabel: 'قراءة نص',
                onTap: () =>
                    Navigator.pop(context, ActionMenuResult.readText),
              ),
              const SizedBox(height: 12),

              if (currentMode != WareneMode.documentQa) ...[
                _ActionTile(
                  icon: Icons.quiz_rounded,
                  label: 'اسأل عن نص',
                  color: Colors.tealAccent,
                  semanticsLabel: 'وضع سؤال وجواب عن نص',
                  onTap: () =>
                      Navigator.pop(context, ActionMenuResult.documentQa),
                ),
                const SizedBox(height: 12),
              ],

              _ActionTile(
                icon: Icons.image_rounded,
                label: 'وصف المشهد',
                color: Colors.tealAccent,
                semanticsLabel: 'وصف المشهد',
                onTap: () =>
                    Navigator.pop(context, ActionMenuResult.describeScene),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String semanticsLabel;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Material(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withAlpha(230),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
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
