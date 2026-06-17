import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/presentation/voice/voice_interaction_controller.dart';

class VoiceListeningIndicator extends StatefulWidget {
  const VoiceListeningIndicator({required this.controller, super.key});

  final VoiceInteractionController controller;

  @override
  State<VoiceListeningIndicator> createState() =>
      _VoiceListeningIndicatorState();
}

class _VoiceListeningIndicatorState extends State<VoiceListeningIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathing;

  @override
  void initState() {
    super.initState();
    _breathing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(VoiceListeningIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final listening =
        widget.controller.state == VoiceInteractionState.listening ||
        widget.controller.state == VoiceInteractionState.hearingSpeech;
    if (listening && !_breathing.isAnimating) {
      _breathing.repeat(reverse: true);
    } else if (!listening && _breathing.isAnimating) {
      _breathing
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _breathing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    if (state == VoiceInteractionState.idle) {
      return const SizedBox.shrink();
    }

    if (state == VoiceInteractionState.prompting ||
        state == VoiceInteractionState.processing) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.electricGreen,
        ),
      );
    }

    if (state == VoiceInteractionState.error) {
      return const Icon(Icons.mic_off_outlined, color: AppColors.alertRed);
    }

    return AnimatedBuilder(
      animation: _breathing,
      builder: (context, child) {
        final scale = 0.9 + (_breathing.value * 0.16);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.electricGreen.withValues(
                    alpha: 0.16 + (_breathing.value * 0.16),
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: AppColors.electricGreen,
                  size: 18,
                ),
              ),
            ),
            if (state == VoiceInteractionState.hearingSpeech) ...[
              const SizedBox(width: 5),
              _SoundDots(
                level: widget.controller.soundLevel,
                phase: _breathing.value,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SoundDots extends StatelessWidget {
  const _SoundDots({required this.level, required this.phase});

  final double level;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final stagger = (phase + (index * 0.22)) % 1;
        final activity = (level * 0.75) + (stagger * 0.25);
        final size = 4.0 + (activity * 5);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.electricGreen.withValues(
                alpha: 0.55 + (activity * 0.45),
              ),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
