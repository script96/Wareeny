import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/stuff_finder/stuff_finder_items.dart';

class StuffFinderItemPicker extends StatelessWidget {
  const StuffFinderItemPicker({required this.selectedTarget, super.key});

  final String? selectedTarget;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
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
              'عايز تدور على إيه؟',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'اختار عنصر من الحاجات المتاحة',
              textDirection: TextDirection.rtl,
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: GridView.builder(
                itemCount: stuffFinderItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisExtent: 116,
                ),
                itemBuilder: (context, index) {
                  final item = stuffFinderItems[index];
                  final selected = item.detectorLabel == selectedTarget;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: 'البحث عن ${item.arabicLabel}',
                    child: Material(
                      key: ValueKey('stuff-finder-${item.detectorLabel}'),
                      color: selected
                          ? AppColors.electricGreenDim
                          : Colors.white10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: selected
                              ? AppColors.electricGreen
                              : Colors.white24,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop(item.detectorLabel);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                item.icon,
                                size: 38,
                                color: AppColors.electricGreen,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                item.arabicLabel,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
}
