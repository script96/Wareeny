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

  testWidgets('opens common objects followed by the COCO target menu', (
    tester,
  ) async {
    // Tall surface so the whole shortlist + "More objects" fit without
    // scrolling, keeping the screen-reader picker assertions deterministic.
    await tester.binding.setSurfaceSize(const Size(500, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    // The picker is screen-reader friendly: no text field to type into.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('What do you want to find?'), findsOneWidget);

    // A short list of common objects is shown first, names only (no category
    // subtitles that a screen reader would read out for every item).
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Glasses'), findsOneWidget);
    expect(find.text('Keys'), findsOneWidget);
    expect(find.text('Bottle'), findsOneWidget);
    expect(find.text('Custom Stuff Finder model'), findsNothing);
    expect(find.text('Everyday COCO object'), findsNothing);

    // Uncommon objects stay hidden behind the "More objects" action.
    expect(find.text('Suitcase'), findsNothing);
    expect(find.text('More objects'), findsOneWidget);

    // Revealing the full catalogue replaces the "More objects" action and
    // exposes objects outside the shortlist.
    await tester.tap(find.text('More objects'));
    await tester.pump();
    expect(find.text('More objects'), findsNothing);
    expect(find.text('Suitcase'), findsOneWidget);
  });
}

void _noop() {}

void _noopIndex(int _) {}
