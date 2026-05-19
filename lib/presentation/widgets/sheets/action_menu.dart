import 'package:flutter/material.dart';

import '../../../services/object_finder_types.dart';
import '../../../services/speech_service.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../reusable/app_action_tile.dart';
import '../reusable/app_bottom_sheet.dart';

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

Future<ActionMenuResult?> showWareneActionMenu(
  BuildContext context, {
  required WareneMode currentMode,
}) async {
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
    return AppBottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppBottomSheetHeader(
            title: 'القائمة',
            style: AppTextStyles.sheetTitle,
            centerTitle: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          ..._buildOptions(context),
        ],
      ),
    );
  }

  List<Widget> _buildOptions(BuildContext context) {
    final options = <Widget>[];

    void addOption({
      required IconData icon,
      required String label,
      required Color color,
      required String semanticsLabel,
      required ActionMenuResult result,
    }) {
      options.add(
        AppActionTile(
          icon: icon,
          label: label,
          color: color,
          semanticsLabel: semanticsLabel,
          onTap: () => Navigator.pop(context, result),
        ),
      );
      options.add(const SizedBox(height: AppSpacing.sm));
    }

    if (currentMode == WareneMode.documentQa) {
      addOption(
        icon: Icons.document_scanner_rounded,
        label: 'اسأل عن نص جديد',
        color: Colors.tealAccent,
        semanticsLabel: 'اسأل عن نص جديد',
        result: ActionMenuResult.rescanDocumentQa,
      );
      addOption(
        icon: Icons.close_rounded,
        label: 'إنهاء سؤال النص',
        color: Colors.redAccent,
        semanticsLabel: 'إنهاء سؤال النص',
        result: ActionMenuResult.exitDocumentQa,
      );
    }

    if (currentMode != WareneMode.generalObjects) {
      addOption(
        icon: Icons.visibility_rounded,
        label: 'أشياء',
        color: Colors.blueAccent,
        semanticsLabel: 'وضع الأشياء',
        result: ActionMenuResult.generalObjects,
      );
    }

    if (currentMode != WareneMode.currency) {
      addOption(
        icon: Icons.attach_money_rounded,
        label: 'فلوس',
        color: Colors.amber,
        semanticsLabel: 'وضع الفلوس',
        result: ActionMenuResult.currency,
      );
    }

    addOption(
      icon: Icons.search_rounded,
      label: 'البحث عن شيء',
      color: Colors.orangeAccent,
      semanticsLabel: 'البحث عن شيء',
      result: ActionMenuResult.findObject,
    );

    if (currentMode != WareneMode.color) {
      addOption(
        icon: Icons.palette_rounded,
        label: 'وضع الألوان',
        color: Colors.purpleAccent,
        semanticsLabel: 'وضع الألوان',
        result: ActionMenuResult.colorMode,
      );
    }

    addOption(
      icon: Icons.menu_book_rounded,
      label: 'قراءة نص',
      color: Colors.cyanAccent,
      semanticsLabel: 'قراءة نص',
      result: ActionMenuResult.readText,
    );

    if (currentMode != WareneMode.documentQa) {
      addOption(
        icon: Icons.quiz_rounded,
        label: 'اسأل عن نص',
        color: Colors.tealAccent,
        semanticsLabel: 'وضع سؤال وجواب عن نص',
        result: ActionMenuResult.documentQa,
      );
    }

    addOption(
      icon: Icons.image_rounded,
      label: 'وصف المشهد',
      color: Colors.tealAccent,
      semanticsLabel: 'وصف المشهد',
      result: ActionMenuResult.describeScene,
    );

    return options..removeLast();
  }
}
