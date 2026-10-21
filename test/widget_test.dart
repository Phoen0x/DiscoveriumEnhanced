import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obtainium/main.dart';
import 'package:obtainium/pages/apps.dart';
import 'package:obtainium/pages/settings.dart';
import 'package:obtainium/providers/apps_provider.dart';
import 'package:obtainium/providers/logs_provider.dart';
import 'package:obtainium/providers/notifications_provider.dart';
import 'package:obtainium/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// FR// État des applis et services natifs simulés ; widgets, navigation et réglages réels.
// EN// App state and native services are faked; widgets, navigation and settings remain real.
class TestAppsProvider extends ChangeNotifier implements AppsProvider {
  @override
  final Map<String, AppInMemory> apps = {};
  @override
  bool get loadingApps => false;
  @override
  bool get gettingUpdates => false;
  @override
  Iterable<AppInMemory> getAppValues() => apps.values;
  @override
  List<String> findExistingUpdates({
    bool installedOnly = false,
    bool nonInstalledOnly = false,
  }) => [];
  @override
  bool areDownloadsRunning() => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestLogsProvider extends Fake implements LogsProvider {}

class TestNotificationsProvider extends Fake implements NotificationsProvider {
  @override
  Future<void> checkLaunchByNotif() async {}
}

class TestAssetLoader extends AssetLoader {
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/en.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'firstRun': false,
      'welcomeShown': true,
      'googleVerificationWarningShown': true,
      'updateInterval': 0,
      'forcedLocale': 'en',
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
      'com.transistorsoft/flutter_background_fetch/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel(
        'com.transistorsoft/flutter_background_fetch/methods',
      ),
      (_) async => 0,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_foreground_task/methods'),
      (call) async => switch (call.method) {
        'checkNotificationPermission' || 'requestNotificationPermission' => 0,
        'isIgnoringBatteryOptimizations' => true,
        'isRunningService' => false,
        _ => null,
      },
    );
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final settings = SettingsProvider();
    settings.prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<AppsProvider>(
            create: (_) => TestAppsProvider(),
          ),
          Provider<LogsProvider>(create: (_) => TestLogsProvider()),
          Provider<NotificationsProvider>(
            create: (_) => TestNotificationsProvider(),
          ),
        ],
        child: EasyLocalization(
          supportedLocales: supportedLocales.map((entry) => entry.key).toList(),
          path: localeDir,
          assetLoader: TestAssetLoader(),
          fallbackLocale: fallbackLocale,
          startLocale: fallbackLocale,
          useOnlyLangCode: false,
          child: const Obtainium(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(settings.dispose);
  }

  testWidgets('Starts with the app list and required providers', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(AppsPage), findsOneWidget);
    expect(find.text(tr('noApps')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Opens settings from the real navigation', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings).last);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
