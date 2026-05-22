import 'package:flutter/widgets.dart';

import 'package:wareny/app/wareny_app.dart';
import 'package:wareny/core/config/app_config.dart';
import 'package:wareny/core/di/app_scope.dart';
import 'package:wareny/core/di/service_registry.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final services = ServiceRegistry.create(config);

  runApp(AppScope(services: services, child: const WareenyApp()));
}
