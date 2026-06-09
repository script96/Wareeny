import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/luma/luma_strings.dart';

Future<bool> showPrivacyAlertDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text(LumaStrings.privateInfoTitle),
        content: const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(LumaStrings.privateInfoMessage),
              SizedBox(height: AppSpacing.md),
              Text('Sensitive examples:'),
              SizedBox(height: AppSpacing.xs),
              Text('Phone number'),
              Text('Address'),
              Text('ID'),
              Text('Payment card'),
              Text('Personal name'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Read Anyway'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
