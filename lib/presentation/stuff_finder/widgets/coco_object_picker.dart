import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/stuff_finder/coco_classes.dart';

class CocoObjectPicker extends StatefulWidget {
  const CocoObjectPicker({required this.selectedTarget, super.key});

  final String? selectedTarget;

  @override
  State<CocoObjectPicker> createState() => _CocoObjectPickerState();
}

class _CocoObjectPickerState extends State<CocoObjectPicker> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final filteredClasses = cocoClasses
        .where((label) => label.contains(_query.trim().toLowerCase()))
        .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          top: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'What do you want to find?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search 80 COCO objects',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView.builder(
                itemCount: filteredClasses.length,
                itemBuilder: (context, index) {
                  final label = filteredClasses[index];
                  final selected = label == widget.selectedTarget;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: 'Find $label',
                    child: ListTile(
                      key: ValueKey('coco-$label'),
                      title: Text(
                        _titleCase(label),
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.electricGreen,
                            )
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () => Navigator.of(context).pop(label),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
