import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const AppBottomSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      20,
      AppSpacing.sm,
      20,
      AppSpacing.xl,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.sheetBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AppBottomSheetHeader extends StatelessWidget {
  final String title;
  final TextStyle style;
  final bool centerTitle;

  const AppBottomSheetHeader({
    super.key,
    required this.title,
    required this.style,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(title, style: style);

    return Column(
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.dragHandle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        if (centerTitle) Center(child: titleWidget) else titleWidget,
      ],
    );
  }
}
