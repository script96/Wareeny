import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/luma/luma_controller.dart';
import 'package:wareeny/presentation/luma/luma_models.dart';
import 'package:wareeny/presentation/luma/screens/danger_mode_screen.dart';
import 'package:wareeny/presentation/luma/widgets/luma_components.dart';
import 'package:wareeny/presentation/luma/widgets/privacy_alert_dialog.dart';

class ActiveReadingScreen extends StatefulWidget {
  const ActiveReadingScreen({
    required this.controller,
    required this.mode,
    super.key,
  });

  final LumaController controller;
  final LumaModeDefinition mode;

  @override
  State<ActiveReadingScreen> createState() => _ActiveReadingScreenState();
}

class _ActiveReadingScreenState extends State<ActiveReadingScreen> {
  final TextEditingController _questionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.startCameraMode(widget.mode);
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode.title),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final snapshot = controller.readingSnapshot;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              MainStatusBanner(
                state: controller.uiState,
                title: widget.mode.title,
                message: controller.assistantMessage,
              ),
              const SizedBox(height: AppSpacing.md),
              const CameraPreviewPlaceholder(
                label: 'OCR and reading preview',
                overlays: [Alignment.center],
              ),
              const SizedBox(height: AppSpacing.md),
              AssistantSpeechOutput(
                title: 'Main spoken output',
                message: snapshot.summary,
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OCR result',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(snapshot.resultText),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  StatusInfoChip(label: 'Framing guidance', value: snapshot.framingCue),
                  const SizedBox(width: AppSpacing.sm),
                  const StatusInfoChip(label: 'TTS chunks', value: 'Ready'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                value: controller.privacyModeEnabled,
                onChanged: controller.togglePrivacyMode,
                title: const Text('Privacy Mode'),
                subtitle: const Text(
                  'Suppress sensitive text unless the user confirms.',
                ),
              ),
              if (widget.mode.kind == LumaModeKind.qaMode) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _questionController,
                  decoration: const InputDecoration(
                    labelText: 'Ask about detected text',
                    hintText: 'Example: What floor is this?',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    final text = _questionController.text.trim();
                    controller.speak(
                      text.isEmpty
                          ? 'Ask a question about the detected text.'
                          : 'Placeholder answer for: $text',
                    );
                  },
                  icon: const Icon(Icons.quiz_rounded),
                  label: const Text('Ask'),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton(
                    onPressed: () => _scanWithPrivacyCheck(context),
                    child: const Text('Scan'),
                  ),
                  OutlinedButton(
                    onPressed: controller.pauseReading,
                    child: const Text('Pause'),
                  ),
                  OutlinedButton(
                    onPressed: controller.repeatLastMessage,
                    child: const Text('Repeat'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      controller.speak('Skip placeholder invoked.');
                    },
                    child: const Text('Skip'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      controller.speak('Cancel placeholder invoked.');
                    },
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      await controller.stopCameraMode();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Stop'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DangerModeScreen(controller: controller),
                      ),
                    ),
                    child: const Text('Danger'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _scanWithPrivacyCheck(BuildContext context) async {
    final controller = widget.controller;
    if (controller.privacyModeEnabled && controller.askBeforeSensitiveText) {
      final confirmed = await showPrivacyAlertDialog(context);
      if (!confirmed) {
        await controller.speak('Private text was not read aloud.');
        return;
      }
    }
    await controller.scanText();
  }
}
