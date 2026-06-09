import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/luma/luma_controller.dart';
import 'package:wareeny/presentation/luma/luma_data.dart';
import 'package:wareeny/presentation/luma/luma_models.dart';
import 'package:wareeny/presentation/luma/luma_routes.dart';
import 'package:wareeny/presentation/luma/luma_strings.dart';
import 'package:wareeny/presentation/luma/screens/save_new_item_flow_screen.dart';
import 'package:wareeny/presentation/luma/widgets/luma_components.dart';

class SavedItemsScreen extends StatelessWidget {
  const SavedItemsScreen({
    required this.controller,
    super.key,
  });

  final LumaController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SectionHeader(
          title: 'Saved Items',
          subtitle: 'Store personal items and find them again later.',
        ),
        const SizedBox(height: AppSpacing.md),
        if (controller.savedItems.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const Icon(Icons.bookmark_border_rounded, size: 40),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    LumaStrings.noSavedItems,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          )
        else
          ...controller.savedItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: SavedItemCard(
                item: item,
                onFind: () async {
                  controller.markItemFound(item);
                  final mode = lumaModes
                      .where((entry) => entry.kind == LumaModeKind.savedItemFinder)
                      .first;
                  await controller.switchMode(mode);
                  if (!context.mounted) {
                    return;
                  }
                  await openModeScreen(
                    context,
                    controller: controller,
                    mode: mode,
                  );
                },
                onRename: () => _showRenameDialog(context, item),
                onDelete: () => controller.deleteItem(item),
              ),
            ),
          ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SaveNewItemFlowScreen(controller: controller),
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add New Item'),
        ),
      ],
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    SavedItemEntry item,
  ) async {
    final controllerText = TextEditingController(text: item.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename item'),
          content: TextField(
            controller: controllerText,
            decoration: const InputDecoration(
              labelText: 'Item name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controllerText.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controllerText.dispose();
    if (newName == null || newName.isEmpty) {
      return;
    }
    controller.renameItem(item, newName);
  }
}
