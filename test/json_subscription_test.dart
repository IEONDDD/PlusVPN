import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plus_vpn/models.dart';
import 'package:plus_vpn/services/config_builder.dart';
import 'package:plus_vpn/services/subscription_service.dart';

Map<String, dynamic> profile({
  bool automatic = false,
  String network = 'tcp',
}) => {
  'remarks': automatic ? '⚡ Автовыбор' : '🇫🇮 Финляндия',
  'dns': {
    'servers': ['https://dns.example/dns-query'],
    'queryStrategy': 'UseIPv4',
  },
  'inbounds': [
    {
      'tag': 'socks',
      'port': 1080,
      'listen': '0.0.0.0',
      'protocol': 'socks',
      'settings': {'udp': true},
    },
  ],
  'outbounds': [
    {
      'tag': automatic ? 'proxy-1' : 'proxy',
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': 'vpn.example',
            'port': 443,
            'users': [
              {
                'id': 'aabbccdd-1234-4567-89ab-aabbccddeeff',
                'encryption': 'none',
                'flow': network == 'tcp' ? 'xtls-rprx-vision' : '',
              },
            ],
          },
        ],
      },
      'streamSettings': {
        'network': network,
        'security': 'reality',
        'realitySettings': {
          'serverName': 'tls.example',
          'publicKey': 'test-public-key',
          'shortId': 'abcd',
          'fingerprint': 'firefox',
          'spiderX': '/',
        },
        'sockopt': {'tcpFastOpen': true, 'tcpKeepAliveInterval': 30},
        if (network == 'xhttp')
          'xhttpSettings': {
            'mode': 'auto',
            'host': 'cdn.example',
            'path': '/tunnel',
            'extra': {'noGRPCHeader': true},
          },
      },
    },
    {'tag': 'direct', 'protocol': 'freedom'},
    {'tag': 'block', 'protocol': 'blackhole'},
  ],
  'routing': {
    'domainStrategy': 'IPIfNonMatch',
    'rules': [
      {
        'protocol': ['bittorrent'],
        'outboundTag': 'block',
      },
      {
        'type': 'field',
        'network': 'tcp,udp',
        if (automatic) 'balancerTag': 'auto-best' else 'outboundTag': 'proxy',
      },
    ],
    if (automatic)
      'balancers': [
        {
          'tag': 'auto-best',
          'selector': ['proxy-'],
          'strategy': {'type': 'leastPing'},
        },
      ],
  },
  if (automatic)
    'observatory': {
      'subjectSelector': ['proxy-'],
      'probeURL': 'https://probe.example',
      'probeInterval': '30s',
      'enableConcurrency': true,
    },
};

void main() {
  test(
    'Xray array keeps XHTTP Reality, sockopt and automatic routing intact',
    () {
      final raw = [profile(automatic: true), profile(network: 'xhttp')];
      final result = SubscriptionService.parseList(jsonEncode(raw));
      expect(result.servers, hasLength(2));
      expect(result.skipped, 0);
      expect(result.servers.first.isAutomatic, isTrue);
      expect(result.servers.last.protocolLabel, contains('XHTTP'));
      expect(result.servers.last.label, '🇫🇮 Финляндия');
      for (var i = 0; i < raw.length; i++) {
        final server = result.servers[i];
        final settings = AppSettings();
        final generated = ConfigBuilder.buildMap(server, settings);
        expect(generated['outbounds'], raw[i]['outbounds']);
        expect(generated['dns'], raw[i]['dns']);
        expect(
          generated['routing']['balancers'],
          raw[i]['routing']['balancers'],
        );
        expect(generated['observatory'], raw[i]['observatory']);
        expect(
          generated['routing']['rules'].skip(1).toList(),
          raw[i]['routing']['rules'],
        );
        expect(generated['inbounds'][0]['listen'], '127.0.0.1');
        expect(generated['inbounds'][0]['port'], 10808);
        expect(server.xrayConfig, raw[i]);
        final restored = ServerProfile.fromJson(
          jsonDecode(jsonEncode(server.toJson())),
        );
        expect(restored.xrayConfig, raw[i]);
      }
    },
  );
  test('Single JSON, profiles wrapper and Base64 JSON all import', () {
    final raw = profile();
    for (final source in [
      jsonEncode(raw),
      jsonEncode({
        'profiles': [raw],
      }),
      base64.encode(utf8.encode(jsonEncode([raw]))),
    ]) {
      expect(SubscriptionService.parseList(source).servers, hasLength(1));
    }
    final reversed = Map<String, dynamic>.fromEntries(
      raw.entries.toList().reversed,
    );
    expect(
      SubscriptionService.parseList(jsonEncode(raw)).servers.single.id,
      SubscriptionService.parseList(jsonEncode(reversed)).servers.single.id,
    );
  });
  test(
    'HTTPS subscriptions accept JSON with the same metadata and stable IDs',
    () async {
      final service = SubscriptionService(
        client: MockClient((request) async {
          expect(request.headers['Accept'], contains('application/json'));
          expect(request.headers['User-Agent'], startsWith('PlusVPN'));
          return http.Response(
            jsonEncode([profile(automatic: true), profile(network: 'xhttp')]),
            200,
            headers: {
              'content-type': 'application/json; charset=utf-8',
              'profile-title': 'Plus test',
              'subscription-userinfo': 'upload=1; download=2; total=10',
            },
          );
        }),
      );
      addTearDown(service.dispose);
      final result = await service.import(
        'https://subscription.example/secret',
      );
      expect(result.servers, hasLength(2));
      expect(result.subscription!.used, 3);
      expect(result.servers.first.subscriptionId, result.subscription!.id);
      final refresh = await service.import(
        'https://subscription.example/secret',
      );
      expect(refresh.servers.map((s) => s.id), result.servers.map((s) => s.id));
    },
  );
  test(
    'Manual DNS override and LAN toggle do not destroy provider routing',
    () {
      final raw = profile(automatic: true);
      final server = SubscriptionService.parseList(
        jsonEncode(raw),
      ).servers.single;
      final settings = AppSettings()
        ..bypassLan = false
        ..useProfileDns = false
        ..dns = '8.8.8.8';
      final result = ConfigBuilder.buildMap(server, settings);
      expect(result['dns']['servers'], ['8.8.8.8']);
      expect(result['routing'], raw['routing']);
      expect(result['outbounds'], raw['outbounds']);
    },
  );
  test(
    'A direct first outbound retains its default route after engine normalization',
    () {
      final raw = profile();
      final outbounds = raw['outbounds'] as List;
      outbounds.insert(0, outbounds.removeAt(1));
      final server = SubscriptionService.parseList(
        jsonEncode(raw),
      ).servers.single;
      final built = ConfigBuilder.buildMap(
        server,
        AppSettings()..bypassLan = false,
      );
      expect(built['outbounds'][0]['protocol'], 'vless');
      expect(built['routing']['rules'].last['outboundTag'], 'direct');
      expect(server.xrayConfig!['outbounds'][0]['protocol'], 'freedom');
    },
  );
  test('JSON import isolates bad entries and rejects unrelated JSON', () {
    final result = SubscriptionService.parseList(
      jsonEncode([
        profile(),
        {'outbounds': []},
        'broken',
      ]),
    );
    expect(result.servers, hasLength(1));
    expect(result.skipped, 2);
    for (final text in ['{}', '[]', '[1]', '{broken']) {
      expect(() => SubscriptionService.parseList(text), throwsFormatException);
    }
  });
  final privatePath = Platform.environment['PLUSVPN_TEST_CONFIG_PATH'];
  test(
    'User-provided Xray subscription preserves every complete configuration',
    () {
      final originals =
          jsonDecode(File(privatePath!).readAsStringSync()) as List;
      final result = SubscriptionService.parseList(jsonEncode(originals));
      expect(result.servers, hasLength(originals.length));
      expect(result.skipped, 0);
      for (var i = 0; i < originals.length; i++) {
        final generated = ConfigBuilder.buildMap(
          result.servers[i],
          AppSettings()..bypassLan = false,
        );
        for (final key in ['outbounds', 'routing', 'observatory', 'dns']) {
          expect(
            generated[key],
            originals[i][key],
            reason: 'Profile ${i + 1}: $key must be retained',
          );
        }
      }
    },
    skip: privatePath == null
        ? 'Set PLUSVPN_TEST_CONFIG_PATH to check a private JSON without copying it into the repository'
        : false,
  );
}
