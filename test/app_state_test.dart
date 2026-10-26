import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plus_vpn/app_state.dart';
import 'package:plus_vpn/models.dart';
import 'package:plus_vpn/services/subscription_service.dart';
import 'package:plus_vpn/services/vpn_engine.dart';

class MemoryEngine extends VpnEngine {
  String current = 'DISCONNECTED';
  int starts = 0, stops = 0;
  String? saved;
  @override
  Future<Map<String, dynamic>> snapshot() async => {'state': current};
  @override
  Future<void> save(ServerProfile? server, AppSettings settings) async {
    saved = server?.id;
  }

  @override
  Future<bool> prepare() async => true;
  @override
  Future<void> start() async {
    current = 'CONNECTED';
    starts++;
  }

  @override
  Future<void> stop() async {
    current = 'DISCONNECTED';
    stops++;
  }
}

const first =
    'vless://aabbccdd-1234-4567-89ab-aabbccddeeff@a.example:443#Finland';
const second = 'trojan://password@b.example:443#Germany';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Import persists; switching a live server stops before restarting',
    () async {
      final engine = MemoryEngine();
      final state = AppState(engine: engine);
      await state.initialize();
      try {
        expect(await state.importText('$first\n$second'), 2);
        await state.toggle();
        expect(state.connected, isTrue);
        await state.select(state.servers.last);
        expect(engine.starts, 2);
        expect(engine.stops, 1);
        expect(state.selected!.host, 'b.example');
        final prefs = await SharedPreferences.getInstance();
        expect(
          jsonDecode(prefs.getString('app_state')!)['selectedId'],
          state.selectedId,
        );
        await state.removeServer(state.selected!);
        expect(engine.current, 'DISCONNECTED');
        expect(state.servers, hasLength(1));
        expect(engine.saved, state.servers.first.id);
      } finally {
        state.dispose();
      }
    },
  );
  test(
    'Subscription refresh replaces only that subscription; failed refresh preserves data',
    () async {
      var body = first;
      var status = 200;
      final service = SubscriptionService(
        client: MockClient((_) async => http.Response(body, status)),
      );
      final state = AppState(engine: MemoryEngine(), subscriptions: service);
      await state.initialize();
      try {
        await state.importText(second);
        await state.importText('https://sub.example/token');
        expect(state.servers, hasLength(2));
        body = '$first\n$second';
        await state.importText('https://sub.example/token');
        expect(state.servers, hasLength(3));
        expect(state.subscriptions, hasLength(1));
        status = 503;
        await state.importText('https://sub.example/token');
        expect(state.servers, hasLength(3));
        expect(state.error, contains('503'));
        await state.removeSubscription(state.subscriptions.single);
        expect(state.servers.single.subscriptionId, isNull);
      } finally {
        state.dispose();
      }
    },
  );
}
