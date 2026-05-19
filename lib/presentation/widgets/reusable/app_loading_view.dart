import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class AppLoadingView extends StatelessWidget {
  final String message;

  const AppLoadingView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AppColors.primaryAccent),
        const SizedBox(height: AppSpacing.xl),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.loadingMessage,
        ),
      ],
    );
  }
}
