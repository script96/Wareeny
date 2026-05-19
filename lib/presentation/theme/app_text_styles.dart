import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const TextStyle loadingMessage = TextStyle(
    color: AppColors.secondaryText,
    fontSize: 16,
  );

  static const TextStyle permissionMessage = TextStyle(
    color: AppColors.primaryText,
    fontSize: 18,
  );

  static const TextStyle permissionSecondaryAction = TextStyle(
    color: AppColors.primaryAccent,
  );

  static const TextStyle sheetTitle = TextStyle(
    color: AppColors.primaryText,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle pickerTitle = TextStyle(
    color: AppColors.primaryText,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle statusText = TextStyle(
    color: AppColors.primaryText,
    fontSize: 16,
  );

  static const TextStyle badgeText = TextStyle(
    color: AppColors.primaryText,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );
}
