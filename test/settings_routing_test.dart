import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plus_vpn/app_state.dart';
import 'package:plus_vpn/main.dart';
import 'package:plus_vpn/models.dart';
import 'package:plus_vpn/services/subscription_service.dart';
import 'package:plus_vpn/services/vpn_engine.dart';
import 'package:plus_vpn/tabs/settings_tab.dart';
import 'package:plus_vpn/widgets/common.dart';
import 'package:plus_vpn/widgets/interface_scale.dart';

class SettingsEngine extends VpnEngine {
  int permissionCalls = 0;
  @override
  Future<void> save(ServerProfile? server, AppSettings settings) async {}
  @override
  Future<bool> prepare() async {
    permissionCalls++;
    return true;
  }

  @override
  Future<List<Map<String, String>>> installedApps() async => [
    {'package': 'chat.example', 'label': 'Чат'},
    {'package': 'browser.example', 'label': 'Браузер'},
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    for (final entry in {
      'PlusInter': [
        'Inter-400',
        'Inter-500',
        'Inter-600',
        'Inter-700',
        'Inter-800',
      ],
      'PlusNunito': ['Nunito-400', 'Nunito-600', 'Nunito-800'],
      'PlusRubikOne': ['RubikOne-400'],
      'PlusDynaPuff': ['DynaPuff-400', 'DynaPuff-700'],
      'PlusComfortaa': ['Comfortaa-400', 'Comfortaa-600', 'Comfortaa-700'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$file.ttf'));
      }
      await loader.load();
    }
  });
  test(
    'New defaults and older settings use Material You, system colors, Inter, 90% and hidden word',
    () {
      for (final settings in [AppSettings(), AppSettings.fromJson({})]) {
        expect(settings.interfaceStyle, InterfaceStyle.materialYou);
        expect(settings.dynamicColors, isTrue);
        expect(settings.font, AppFont.inter);
        expect(settings.uiScale, .9);
        expect(settings.showWord, isFalse);
      }
      final previous = AppSettings.fromJson({
        'interfaceStyle': 'liquidGlass',
        'dynamicColors': false,
        'showWord': true,
        'perApp': true,
        'excludedApps': ['chat.example'],
      });
      expect(previous.interfaceStyle, InterfaceStyle.liquidGlass);
      expect(previous.showWord, isTrue);
      expect(previous.appRoutingMode, AppRoutingMode.exclude);
      expect(previous.excludedApps, ['chat.example']);
    },
  );
  test('Font, scale and independent app lists survive persistence', () {
    final settings = AppSettings()
      ..font = AppFont.rubikOne
      ..uiScale = 1.1
      ..perApp = true
      ..appRoutingMode = AppRoutingMode.include
      ..includedApps = ['chat.example']
      ..excludedApps = ['browser.example'];
    final restored = AppSettings.fromJson(
      jsonDecode(jsonEncode(settings.toJson())),
    );
    expect(restored.font, AppFont.rubikOne);
    expect(restored.uiScale, 1.1);
    expect(restored.includedApps, ['chat.example']);
    expect(restored.excludedApps, ['browser.example']);
    expect(restored.appRoutingMode, AppRoutingMode.include);
  });
  test('Native payload contains only the active app-routing list', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final payloads = <Map>[];
    messenger.setMockMethodCallHandler(VpnEngine.channel, (call) async {
      payloads.add(call.arguments as Map);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(VpnEngine.channel, null),
    );
    final settings = AppSettings()
      ..perApp = true
      ..includedApps = ['chat.example']
      ..excludedApps = ['browser.example'];
    final engine = VpnEngine();
    await engine.save(null, settings);
    expect(payloads.last['includeOnly'], false);
    expect(payloads.last['excludedApps'], ['browser.example']);
    expect(payloads.last['includedApps'], isEmpty);
    settings.appRoutingMode = AppRoutingMode.include;
    await engine.save(null, settings);
    expect(payloads.last['includeOnly'], true);
    expect(payloads.last['includedApps'], ['chat.example']);
    expect(payloads.last['excludedApps'], isEmpty);
    settings.perApp = false;
    await engine.save(null, settings);
    expect(payloads.last['includeOnly'], false);
    expect(payloads.last['includedApps'], isEmpty);
    expect(payloads.last['excludedApps'], isEmpty);
  });
  test(
    'Empty include mode cannot start a tunnel or request VPN consent',
    () async {
      final engine = SettingsEngine();
      final state = AppState(engine: engine);
      state.servers = [
        SubscriptionService.parseKey('trojan://pw@vpn.example:443#Test'),
      ];
      state.selectedId = state.servers.first.id;
      state.settings.perApp = true;
      state.settings.appRoutingMode = AppRoutingMode.include;
      await state.toggle();
      expect(engine.permissionCalls, 0);
      expect(state.error, contains('хотя бы одно'));
      state.dispose();
    },
  );
  testWidgets(
    'Material You displays wallpaper without glass surfaces and enables its gallery controls',
    (tester) async {
      final state = AppState(engine: SettingsEngine());
      state.settings.wallpaper = File(
        'branding/plusvpn-icon.png',
      ).absolute.path;
      await tester.pumpWidget(PlusVpnApp(state: state));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is FileImage,
        ),
        findsOneWidget,
      );
      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('breathe'), findsNothing);
      await tester.tap(find.text('Настройки'));
      await tester.pumpAndSettle();
      final gallery = find.widgetWithText(FilledButton, 'Из галереи');
      await tester.scrollUntilVisible(
        gallery,
        300,
        scrollable: find
            .descendant(
              of: find.byType(SettingsTab),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.widget<FilledButton>(gallery).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
  testWidgets(
    'Font choice is previewed, applied to the wordmark and persisted globally',
    (tester) async {
      final state = AppState(engine: SettingsEngine())..tab = 2;
      await tester.pumpWidget(PlusVpnApp(state: state));
      await tester.pumpAndSettle();
      final field = find.byType(SelectionField<AppFont>);
      await tester.scrollUntilVisible(
        field,
        250,
        scrollable: find
            .descendant(
              of: find.byType(SettingsTab),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await Scrollable.ensureVisible(tester.element(field), alignment: .35);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pumpAndSettle();
      final chunky = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(AppFont.rubikOne.label),
      );
      expect(
        tester.widget<Text>(chunky).style!.fontFamily,
        AppFont.rubikOne.family,
      );
      await tester.tap(chunky);
      await tester.pumpAndSettle();
      expect(state.settings.font, AppFont.rubikOne);
      await tester.tap(find.text('Главная'));
      await tester.pumpAndSettle();
      final wordmark = find.byKey(const Key('brand-wordmark'));
      expect(
        tester.widget<Text>(wordmark).style!.fontFamily,
        AppFont.rubikOne.family,
      );
      expect(
        Theme.of(tester.element(wordmark)).textTheme.bodyMedium!.fontFamily,
        AppFont.rubikOne.family,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_state'), contains('rubikOne'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
  testWidgets('Whole-interface scale includes routes and keyboard insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(engine: SettingsEngine());
    await tester.pumpWidget(PlusVpnApp(state: state));
    await tester.pumpAndSettle();
    final brand = find.byKey(const Key('brand-wordmark'));
    expect(
      tester.widget<InterfaceScale>(find.byType(InterfaceScale)).scale,
      .9,
    );
    expect(MediaQuery.sizeOf(tester.element(brand)).width, closeTo(400, .01));
    await state.updateSettings((s) => s.uiScale = 1.2);
    await tester.pumpAndSettle();
    expect(MediaQuery.sizeOf(tester.element(brand)).width, closeTo(300, .01));
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(
      MediaQuery.viewInsetsOf(tester.element(find.byType(Navigator))).bottom,
      closeTo(150, .01),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  testWidgets('Included app selection is separate from excluded apps', (
    tester,
  ) async {
    final state = AppState(engine: SettingsEngine())..tab = 2;
    state.settings.perApp = true;
    state.settings.appRoutingMode = AppRoutingMode.include;
    state.settings.excludedApps = ['browser.example'];
    await tester.pumpWidget(PlusVpnApp(state: state));
    await tester.pumpAndSettle();
    final apps = find.widgetWithText(ListTile, 'Приложения через VPN');
    await tester.scrollUntilVisible(
      apps,
      300,
      scrollable: find
          .descendant(
            of: find.byType(SettingsTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(tester.element(apps), alignment: .35);
    await tester.pumpAndSettle();
    await tester.tap(apps);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Чат'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(state.settings.includedApps, ['chat.example']);
    expect(state.settings.excludedApps, ['browser.example']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets(
    'Every bundled font fits narrow screens at the largest UI scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final font in AppFont.values) {
        for (final style in InterfaceStyle.values) {
          final state = AppState(engine: SettingsEngine());
          state.settings.font = font;
          state.settings.interfaceStyle = style;
          state.settings.uiScale = 1.2;
          state.settings.showWord = true;
          await tester.pumpWidget(PlusVpnApp(state: state));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$font / $style home');
          for (final title in ['Серверы', 'Настройки']) {
            await tester.tap(find.text(title).last);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$font / $style / $title',
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
          state.dispose();
        }
      }
    },
  );
}
