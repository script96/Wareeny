import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wareeny/app/wareny_app.dart';
import 'package:wareeny/core/config/app_config.dart';
import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/di/service_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets('requires an emergency contact before opening the shell', (
    WidgetTester tester,
  ) async {
    final services = await ServiceRegistry.createAsync(AppConfig.dev());

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: WareenyApp(settings: services.settings),
      ),
    );
    await tester.pump();

    expect(find.text('Emergency contact'), findsOneWidget);
    expect(find.text('Choose from contacts'), findsOneWidget);
    expect(find.text('Confirm emergency contact'), findsOneWidget);
  });
}
