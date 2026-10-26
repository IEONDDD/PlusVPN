import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plus_vpn/app_state.dart';
import 'package:plus_vpn/main.dart';

void main() {
  for (final size in [const Size(360, 800), const Size(320, 568)]) {
    testWidgets('Three tabs fit $size without layout exceptions', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState();
      await tester.pumpWidget(PlusVpnApp(state: state));
      await tester.pumpAndSettle();
      expect(find.text('PLUSVPN'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Серверы'));
      await tester.pumpAndSettle();
      expect(find.text('Ваш следующий маршрут'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Настройки'));
      await tester.pumpAndSettle();
      expect(find.text('Оформление'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });
  }
}
