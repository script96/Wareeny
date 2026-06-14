import 'dart:async';

import 'package:flutter/material.dart';

import 'package:wareeny/app/wareny_app.dart';
import 'package:wareeny/core/config/app_config.dart';
import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/di/service_registry.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  runApp(_BootstrapLoader(config: config));
}

class _BootstrapLoader extends StatefulWidget {
  const _BootstrapLoader({required this.config});

  final AppConfig config;

  @override
  State<_BootstrapLoader> createState() => _BootstrapLoaderState();
}

class _BootstrapLoaderState extends State<_BootstrapLoader> {
  late final Future<ServiceRegistry> _services = ServiceRegistry.createAsync(
    widget.config,
  );
  bool _audioInitialized = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ServiceRegistry>(
      future: _services,
      builder: (context, snapshot) {
        final services = snapshot.data;
        if (services == null) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Color(0xFF210A1C),
              body: Center(
                child: Text(
                  'Wareeny',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          );
        }
        if (!_audioInitialized) {
          _audioInitialized = true;
          unawaited(services.audioHapticsBridge.init());
        }
        return AppScope(
          services: services,
          child: WareenyApp(settings: services.settings),
        );
      },
    );
  }
}
