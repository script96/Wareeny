import 'package:flutter/widgets.dart';

import 'package:wareeny/app/wareny_app.dart';
import 'package:wareeny/core/config/app_config.dart';
import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/di/service_registry.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final services = await ServiceRegistry.createAsync(config);

  // Eagerly initialize TTS for Arabic speech.
  await services.audioHapticsBridge.init();

  runApp(AppScope(services: services, child: WareenyApp(settings: services.settings)));
}

