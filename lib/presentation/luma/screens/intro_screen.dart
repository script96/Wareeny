import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/luma/luma_controller.dart';
import 'package:wareeny/presentation/luma/luma_strings.dart';
import 'package:wareeny/presentation/luma/widgets/luma_components.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({
    required this.controller,
    required this.onStart,
    super.key,
  });

  final LumaController controller;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    LumaStrings.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    LumaStrings.tagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Icon(Icons.visibility_rounded, size: 72),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    LumaStrings.introMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  LargeActionButton(
                    label: LumaStrings.start,
                    icon: Icons.arrow_forward_rounded,
                    supportingText: 'Start the accessibility-first assistant',
                    onPressed: onStart,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
