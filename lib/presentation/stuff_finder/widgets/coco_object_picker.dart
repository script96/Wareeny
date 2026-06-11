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
  static const _searchAliases = <String, List<String>>{
    'bottle': ['bottel', 'bottles', 'water bottle'],
    'cell phone': ['phone', 'mobile', 'mobile phone', 'smartphone'],
    'remote': ['remotes', 'controller', 'tv remote'],
    'backpack': ['bag', 'school bag'],
    'handbag': ['bag', 'purse'],
    'refrigerator': ['fridge'],
    'couch': ['sofa'],
    'tv': ['television'],
    'hair drier': ['hair dryer'],
    'dining table': ['table'],
  };

  var _query = '';

  @override
  Widget build(BuildContext context) {
    final filteredClasses = stuffFinderClasses
        .where((label) => _matchesQuery(label, _query))
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
                hintText: 'Search ${stuffFinderClasses.length} objects',
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
                      subtitle: Text(
                        isCustomStuffFinderClass(label)
                            ? 'Custom Stuff Finder model'
                            : isPopularStuffFinderClass(label)
                            ? 'Everyday COCO object'
                            : 'COCO object',
                        style: const TextStyle(color: Colors.white54),
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

  bool _matchesQuery(String label, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    if (label.contains(normalizedQuery)) return true;
    if (normalizedQuery.endsWith('s') &&
        label == normalizedQuery.substring(0, normalizedQuery.length - 1)) {
      return true;
    }
    return _searchAliases[label]?.any(
          (alias) => alias.contains(normalizedQuery),
        ) ??
        false;
  }
}
