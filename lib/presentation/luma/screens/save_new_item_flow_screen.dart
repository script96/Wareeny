import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/luma/luma_controller.dart';
import 'package:wareeny/presentation/luma/luma_strings.dart';
import 'package:wareeny/presentation/luma/widgets/luma_components.dart';

class SaveNewItemFlowScreen extends StatefulWidget {
  const SaveNewItemFlowScreen({
    required this.controller,
    super.key,
  });

  final LumaController controller;

  @override
  State<SaveNewItemFlowScreen> createState() => _SaveNewItemFlowScreenState();
}

class _SaveNewItemFlowScreenState extends State<SaveNewItemFlowScreen> {
  final TextEditingController _nameController = TextEditingController(
    text: 'My black wallet',
  );
  int _step = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Save New Item')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          MainStatusBanner(
            state: widget.controller.uiState,
            title: 'Save item flow',
            message: 'Step ${_step + 1} of 3',
          ),
          const SizedBox(height: AppSpacing.md),
          if (_step == 0) ...[
            const CameraPreviewPlaceholder(label: 'Item capture preview'),
            const SizedBox(height: AppSpacing.md),
            const AssistantSpeechOutput(
              title: 'Step 1',
              message: 'Place the item in front of the camera.',
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Capture Item'),
            ),
          ],
          if (_step == 1) ...[
            const AssistantSpeechOutput(
              title: 'Step 2',
              message: 'What should I call this item?',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item name',
                hintText: 'Example: My black wallet',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () {
                widget.controller.speak('Voice naming placeholder activated.');
              },
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Use Voice Input'),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () {
                widget.controller.saveItem(_nameController.text.trim());
                setState(() => _step = 2);
              },
              child: const Text('Save Item'),
            ),
          ],
          if (_step == 2) ...[
            const AssistantSpeechOutput(
              title: 'Step 3',
              message: LumaStrings.saveItemDone,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Saved Items'),
            ),
          ],
        ],
      ),
    );
  }
}
