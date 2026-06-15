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

  testWidgets('opens the curated accessible Arabic object grid', (
    tester,
  ) async {
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

    expect(find.text('اختار حاجة'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stuff-finder-target-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('عايز تدور على إيه؟'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('محفظة'), findsOneWidget);
    expect(find.text('نظارة'), findsOneWidget);
    expect(find.text('موبايل'), findsOneWidget);
    expect(find.text('زجاجة'), findsOneWidget);
    expect(find.byKey(const ValueKey('stuff-finder-wallet')), findsOneWidget);
    expect(find.byKey(const ValueKey('stuff-finder-person')), findsNothing);

    await tester.drag(find.byType(GridView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('ميكروويف'), findsOneWidget);
  });
}

void _noop() {}

void _noopIndex(int _) {}
