import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plus_vpn/models.dart';
import 'package:plus_vpn/services/config_builder.dart';
import 'package:plus_vpn/services/subscription_service.dart';
import 'package:plus_vpn/services/vpn_engine.dart';

const uuid = 'aabbccdd-1234-4567-89ab-aabbccddeeff';
const vless =
    'vless://$uuid@vpn.example:443?security=reality&pbk=public-key&fp=chrome&sni=example.com&sid=abcd&spx=%2Fhello&flow=xtls-rprx-vision#Финляндия%20%231';
String b64(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');
void main() {
  test('VLESS Reality retains every security field and flow', () {
    final s = SubscriptionService.parseKey(vless);
    final c = ConfigBuilder.buildMap(s, AppSettings());
    final outbound = (c['outbounds'] as List).first as Map;
    final reality = outbound['streamSettings']['realitySettings'] as Map;
    expect(s.flag, '🇫🇮');
    expect(s.name, 'Финляндия #1');
    expect(reality, {
      'serverName': 'example.com',
      'fingerprint': 'chrome',
      'publicKey': 'public-key',
      'shortId': 'abcd',
      'spiderX': '/hello',
    });
    expect(
      outbound['settings']['vnext'][0]['users'][0]['flow'],
      'xtls-rprx-vision',
    );
    expect(jsonDecode(ConfigBuilder.build(s, AppSettings())), isA<Map>());
  });
  test('VMess Base64 JSON produces WS TLS config', () {
    final s = SubscriptionService.parseKey(
      'vmess://${b64(jsonEncode({'add': 'vm.example', 'port': '8443', 'id': uuid, 'ps': 'Germany', 'net': 'ws', 'tls': 'tls', 'host': 'cdn.example', 'path': '/socket', 'aid': 0}))}',
    );
    final stream = ConfigBuilder.buildMap(
      s,
      AppSettings(),
    )['outbounds'][0]['streamSettings'];
    expect(s.flag, '🇩🇪');
    expect(stream['wsSettings'], {
      'path': '/socket',
      'headers': {'Host': 'cdn.example'},
    });
    expect(stream['tlsSettings']['serverName'], 'cdn.example');
  });
  test('Trojan grpc keeps percent-encoded password and authority', () {
    final s = SubscriptionService.parseKey(
      'trojan://a%40b%3Ac@vpn.example:443?type=grpc&serviceName=tunnel&authority=edge.example#NL',
    );
    final out = ConfigBuilder.buildMap(s, AppSettings())['outbounds'][0];
    expect(s.credentials, 'a@b:c');
    expect(out['streamSettings']['grpcSettings']['serviceName'], 'tunnel');
    expect(out['streamSettings']['grpcSettings']['authority'], 'edge.example');
    expect(out['settings']['servers'][0]['password'], 'a@b:c');
  });
  test('Shadowsocks SIP002, legacy and IPv6', () {
    for (final key in [
      'ss://${b64('aes-256-gcm:p:ass')}@ss.example:8388#Japan',
      'ss://${b64('aes-256-gcm:p:ass@ss.example:8388')}#Japan',
    ]) {
      final s = SubscriptionService.parseKey(key);
      expect(s.credentials, 'p:ass');
      expect(s.host, 'ss.example');
      expect(
        ConfigBuilder.buildMap(s, AppSettings())['outbounds'][0]['protocol'],
        'shadowsocks',
      );
    }
    final s = SubscriptionService.parseKey(
      'ss://${b64('chacha20-ietf-poly1305:secret')}@[2001:db8::1]:443#US',
    );
    expect(s.port, 443);
    expect(s.host, contains('2001:db8::1'));
  });
  test('List import decodes Base64, deduplicates and counts invalid lines', () {
    final r = SubscriptionService.parseList(
      b64('$vless\n$vless\ninvalid://foo'),
    );
    expect(r.servers, hasLength(1));
    expect(r.skipped, 1);
    expect(
      SubscriptionService.parseKey(vless, subscriptionId: 'A').id,
      isNot(SubscriptionService.parseKey(vless, subscriptionId: 'B').id),
    );
  });
  test(
    'Unsupported transport, invalid port, insecure TLS and SS plugin are rejected',
    () {
      for (final key in [
        'vless://$uuid@a:99999',
        'vless://$uuid@a:443?type=kcp',
        'vless://not-a-uuid@a:443',
        'trojan://pw@a:443?allowInsecure=1',
        'ss://${b64('aes-256-gcm:pw')}@a:443?plugin=obfs-local',
      ]) {
        expect(() => SubscriptionService.parseKey(key), throwsFormatException);
      }
    },
  );
  test('HTTPS headers provide title, quota and expiry', () async {
    final service = SubscriptionService(
      client: MockClient(
        (request) async => http.Response(
          b64(vless),
          200,
          headers: {
            'profile-title': 'base64:${b64('Моя подписка')}',
            'subscription-userinfo':
                'upload=10; download=20; total=100; expire=1893456000',
          },
        ),
      ),
    );
    addTearDown(service.dispose);
    final r = await service.import('https://sub.example/token');
    expect(r.subscription!.title, 'Моя подписка');
    expect(r.subscription!.used, 30);
    expect(r.subscription!.progress, .3);
    expect(r.subscription!.expires!.year, 2030);
    expect(r.servers.single.subscriptionId, r.subscription!.id);
  });
  test(
    'Redirect downgrade and empty response fail without replacing state',
    () async {
      final service = SubscriptionService(
        client: MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {'location': 'http://insecure.example'},
          ),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.import('https://sub.example/token'),
        throwsFormatException,
      );
      await expectLater(
        service.import('http://sub.example/token'),
        throwsFormatException,
      );
    },
  );
  test('LAN bypass and DNS follow settings', () {
    final settings = AppSettings()
      ..dns = '8.8.8.8'
      ..bypassLan = false;
    final c = ConfigBuilder.buildMap(
      SubscriptionService.parseKey(vless),
      settings,
    );
    expect(c['dns']['servers'], ['8.8.8.8']);
    expect(c['routing']['rules'], isEmpty);
    settings.bypassLan = true;
    expect(
      ConfigBuilder.buildMap(
        SubscriptionService.parseKey(vless),
        settings,
      )['routing']['rules'],
      isNotEmpty,
    );
  });
  test('TCP ping opens a real socket', () async {
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final stream = listener.listen((socket) => socket.destroy());
    try {
      final s = ServerProfile(
        id: 'a',
        name: 'local',
        host: '127.0.0.1',
        port: listener.port,
        protocol: 'ss',
        credentials: 'pw',
      );
      expect(await VpnEngine.tcpPing(s), greaterThanOrEqualTo(0));
    } finally {
      await stream.cancel();
      await listener.close();
    }
  });
}
