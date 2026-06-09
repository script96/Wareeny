import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:wareny/core/detection/target_labels.dart';
import 'package:wareny/core/theme/app_spacing.dart';

class TargetSelectorSheet extends StatefulWidget {
  const TargetSelectorSheet({
    this.options = TargetLabels.common,
    this.selectedLabel,
    super.key,
  });

  final List<TargetLabel> options;
  final String? selectedLabel;

  static Future<TargetLabel?> show(
    BuildContext context, {
    List<TargetLabel> options = TargetLabels.common,
    String? selectedLabel,
  }) {
    return showModalBottomSheet<TargetLabel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return TargetSelectorSheet(
          options: options,
          selectedLabel: selectedLabel,
        );
      },
    );
  }

  @override
  State<TargetSelectorSheet> createState() => _TargetSelectorSheetState();
}

class _TargetSelectorSheetState extends State<TargetSelectorSheet> {
  var _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !MediaQuery.supportsAnnounceOf(context)) {
        return;
      }
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Choose the object to find',
        TextDirection.ltr,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = _filteredLabels;

    return FractionallySizedBox(
      heightFactor: 0.72,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Semantics(
            namesRoute: true,
            label: 'Choose the object to find',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose object',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_outlined),
                    hintText: 'Search objects',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() => _query = value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: GridView.builder(
                    itemCount: labels.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 160,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 2.8,
                        ),
                    itemBuilder: (context, index) {
                      final item = labels[index];
                      final selected = item.label == widget.selectedLabel;

                      return Semantics(
                        button: true,
                        selected: selected,
                        label: 'Find ${item.displayName}',
                        child: FilterChip(
                          selected: selected,
                          avatar: Icon(item.icon, size: 18),
                          label: Text(
                            item.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onSelected: (_) {
                            Navigator.of(context).pop(item);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<TargetLabel> get _filteredLabels {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.options;
    }

    return widget.options
        .where((item) {
          return item.displayName.toLowerCase().contains(query) ||
              item.label.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }
}
