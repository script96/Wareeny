import 'package:flutter/material.dart';

import 'package:wareeny/presentation/luma/luma_controller.dart';
import 'package:wareeny/presentation/luma/luma_models.dart';
import 'package:wareeny/presentation/luma/screens/active_object_detection_screen.dart';
import 'package:wareeny/presentation/luma/screens/active_reading_screen.dart';

Future<void> openModeScreen(
  BuildContext context, {
  required LumaController controller,
  required LumaModeDefinition mode,
}) {
  final route = MaterialPageRoute<void>(
    builder: (_) => switch (mode.screenType) {
      ActiveScreenType.objectDetection =>
        ActiveObjectDetectionScreen(controller: controller, mode: mode),
      ActiveScreenType.reading =>
        ActiveReadingScreen(controller: controller, mode: mode),
    },
  );

  return Navigator.of(context).push(route);
}
