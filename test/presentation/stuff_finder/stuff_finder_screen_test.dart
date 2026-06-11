import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wareeny/core/config/app_config.dart';
import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/di/service_registry.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/stuff_finder/stuff_finder_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('opens the COCO target menu from Stuff Finder', (tester) async {
    final services = await ServiceRegistry.createAsync(AppConfig.dev());

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          home: Scaffold(
            body: StuffFinderScreen(
              previousMode: AppMode.navigation,
              nextMode: AppMode.read,
              onPrevious: _noop,
              onNext: _noop,
              onModeSelect: _noopIndex,
              settings: services.settings,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Choose object'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stuff-finder-target-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('What do you want to find?'), findsOneWidget);
    expect(find.text('Search 80 COCO objects'), findsOneWidget);
    expect(find.text('Person'), findsOneWidget);
  });
}

void _noop() {}

void _noopIndex(int _) {}
