import 'package:flutter/widgets.dart';

import 'package:wareny/core/config/app_config.dart';
import 'package:wareny/core/di/service_registry.dart';

class AppScope extends InheritedWidget {
  const AppScope({required this.services, required super.child, super.key});

  final ServiceRegistry services;

  AppConfig get config => services.config;

  static ServiceRegistry of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found above this context.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return services != oldWidget.services;
  }
}
