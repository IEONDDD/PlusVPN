import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plus_vpn/app_state.dart';
import 'package:plus_vpn/main.dart';
import 'package:plus_vpn/models.dart';
import 'package:plus_vpn/services/vpn_engine.dart';
import 'package:plus_vpn/tabs/settings_tab.dart';
import 'package:plus_vpn/widgets/common.dart';

class UiEngine extends VpnEngine {
  bool picked = false;
  @override
  Future<String?> pickConfigFile() async {
    picked = true;
    return 'trojan://secret@vpn.example:443#File%20import';
  }

  @override
  Future<void> save(ServerProfile? server, AppSettings settings) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final style in InterfaceStyle.values) {
    for (final size in [const Size(360, 800), const Size(320, 568)]) {
      testWidgets(
        '$style at $size: tabs, rounded sheets and dialogs match the selected style',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final state = AppState(engine: UiEngine());
          state.settings.interfaceStyle = style;
          state.settings.dynamicColors = false;
          await tester.pumpWidget(PlusVpnApp(state: state));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('brand-wordmark')), findsOneWidget);
          expect(
            find.byType(BackdropFilter),
            style == InterfaceStyle.liquidGlass ? findsWidgets : findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Серверы'));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(SelectionField<String>));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(find.text('Все серверы'), findsNWidgets(2));
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Закрыть'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Добавить'));
          await tester.pumpAndSettle();
          expect(find.byType(PlusDialog), findsOneWidget);
          expect(find.text('JSON-файл'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Отмена'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Настройки'));
          await tester.pumpAndSettle();
          final themeField = find.byType(SelectionField<ThemeMode>);
          await tester.ensureVisible(themeField);
          await tester.tap(themeField);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(find.text('Светлая'), findsOneWidget);
          expect(
            find.byType(BackdropFilter),
            style == InterfaceStyle.liquidGlass ? findsWidgets : findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Светлая'));
          await tester.pumpAndSettle();
          expect(state.settings.theme, ThemeMode.light);
          final dnsField = find.byType(SelectionField<String>);
          await tester.scrollUntilVisible(
            dnsField,
            300,
            scrollable: find
                .descendant(
                  of: find.byType(SettingsTab),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await Scrollable.ensureVisible(
            tester.element(dnsField),
            alignment: .4,
          );
          await tester.pumpAndSettle();
          await tester.tap(dnsField);
          await tester.pumpAndSettle();
          expect(find.text('Google · 8.8.8.8'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Google · 8.8.8.8'));
          await tester.pumpAndSettle();
          expect(state.settings.dns, '8.8.8.8');
          expect(state.settings.useProfileDns, isFalse);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          state.dispose();
        },
      );
    }
  }
  testWidgets(
    'Changing interface style changes all surfaces and persists the selection',
    (tester) async {
      final state = AppState(engine: UiEngine());
      state.tab = 2;
      await tester.pumpWidget(PlusVpnApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SelectionField<InterfaceStyle>));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Material You'),
        ),
      );
      await tester.pumpAndSettle();
      expect(state.settings.interfaceStyle, InterfaceStyle.materialYou);
      expect(state.settings.dynamicColors, isTrue);
      expect(find.byType(BackdropFilter), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_state'), contains('materialYou'));
      await tester.tap(find.byType(SelectionField<InterfaceStyle>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Liquid Glass'));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
  testWidgets(
    'Import file action passes selected document content to the parser',
    (tester) async {
      final engine = UiEngine();
      final state = AppState(engine: engine)..tab = 1;
      await tester.pumpWidget(PlusVpnApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Добавить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JSON-файл'));
      await tester.pumpAndSettle();
      expect(engine.picked, isTrue);
      expect(state.servers.single.name, 'File import');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
}
