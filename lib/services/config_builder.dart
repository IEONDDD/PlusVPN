import 'dart:convert';
import '../models.dart';

class ConfigBuilder {
  static String build(ServerProfile server, AppSettings settings) =>
      jsonEncode(buildMap(server, settings));
  static Map<String, dynamic> buildMap(ServerProfile s, AppSettings settings) {
    if (s.xrayConfig != null) return _imported(s.xrayConfig!, settings);
    final p = s.options;
    final security = p['security'] ?? 'none';
    final transport = p['type'] ?? 'tcp';
    final stream = <String, dynamic>{
      'network': transport,
      'security': security,
    };
    if (security == 'tls' || security == 'reality') {
      final tls = <String, dynamic>{
        'serverName': p['sni']?.isNotEmpty == true
            ? p['sni']
            : (p['peer'] ?? s.host),
        if (p['fp']?.isNotEmpty == true || security == 'reality')
          'fingerprint': p['fp']?.isNotEmpty == true ? p['fp'] : 'chrome',
      };
      if (security == 'reality') {
        tls.addAll({
          'publicKey': p['pbk'],
          'shortId': p['sid'] ?? '',
          'spiderX': p['spx'] ?? '/',
        });
      } else {
        if (p['alpn']?.isNotEmpty == true) tls['alpn'] = p['alpn']!.split(',');
        if (p['pcs']?.isNotEmpty == true) {
          tls['pinnedPeerCertSha256'] = p['pcs']!.split(',');
        }
        if (p['vcn']?.isNotEmpty == true) {
          tls['verifyPeerCertByName'] = p['vcn']!.split(',');
        }
      }
      stream[security == 'reality' ? 'realitySettings' : 'tlsSettings'] = tls;
    }
    if (transport == 'ws') {
      stream['wsSettings'] = {
        'path': p['path']?.isNotEmpty == true ? p['path'] : '/',
        'headers': {if (p['host']?.isNotEmpty == true) 'Host': p['host']},
      };
    } else if (transport == 'grpc') {
      stream['grpcSettings'] = {
        'serviceName': p['serviceName'] ?? '',
        'multiMode': p['mode'] == 'multi',
        if (p['authority']?.isNotEmpty == true) 'authority': p['authority'],
      };
    } else if (transport == 'xhttp') {
      stream['xhttpSettings'] = {
        'path': p['path'] ?? '/',
        'host': p['host'] ?? '',
        'mode': p['mode'] ?? 'auto',
        if (p['extra']?.isNotEmpty == true) 'extra': jsonDecode(p['extra']!),
      };
    } else if (p['headerType'] == 'http') {
      stream['tcpSettings'] = {
        'header': {
          'type': 'http',
          'request': {
            'path': (p['path'] ?? '/').split(','),
            'headers': {'Host': (p['host'] ?? s.host).split(',')},
          },
        },
      };
    }
    late Map<String, dynamic> proxySettings;
    if (s.protocol == 'vless' || s.protocol == 'vmess') {
      proxySettings = {
        'vnext': [
          {
            'address': s.host,
            'port': s.port,
            'users': [
              {
                'id': s.credentials,
                if (s.protocol == 'vless') ...{
                  'encryption': p['encryption'] ?? 'none',
                  if (p['flow']?.isNotEmpty == true) 'flow': p['flow'],
                },
                if (s.protocol == 'vmess') ...{
                  'alterId': 0,
                  'security': p['cipher'] ?? 'auto',
                },
              },
            ],
          },
        ],
      };
    } else {
      proxySettings = {
        'servers': [
          {
            'address': s.host,
            'port': s.port,
            'password': s.credentials,
            if (s.protocol == 'ss') 'method': p['method'],
          },
        ],
      };
    }
    return {
      'log': {'loglevel': 'warning'},
      'dns': {
        'servers': [settings.dns],
        'queryStrategy': 'UseIPv4',
      },
      'inbounds': [
        {
          'tag': 'socks',
          'listen': '127.0.0.1',
          'port': 10808,
          'protocol': 'socks',
          'settings': {'auth': 'noauth', 'udp': true},
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls'],
          },
        },
      ],
      'outbounds': [
        {
          'tag': 'proxy',
          'protocol': s.protocol == 'ss' ? 'shadowsocks' : s.protocol,
          'settings': proxySettings,
          'streamSettings': stream,
        },
        {
          'tag': 'direct',
          'protocol': 'freedom',
          'settings': <String, dynamic>{},
        },
        {
          'tag': 'block',
          'protocol': 'blackhole',
          'settings': <String, dynamic>{},
        },
      ],
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'rules': [
          if (settings.bypassLan)
            {
              'type': 'field',
              'ip': [
                '10.0.0.0/8',
                '172.16.0.0/12',
                '192.168.0.0/16',
                '127.0.0.0/8',
                '169.254.0.0/16',
                '::1/128',
                'fc00::/7',
                'fe80::/10',
              ],
              'outboundTag': 'direct',
            },
        ],
      },
    };
  }

  static Map<String, dynamic> _imported(
    Map<String, dynamic> original,
    AppSettings settings,
  ) {
    final config = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
    final originalInbounds = (config['inbounds'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    // The Android engine owns the TUN. Keep local listeners private and use stable ports.
    config['inbounds'] = [
      for (final entry in [const ('socks', 10808), const ('http', 10809)])
        {
          ...?originalInbounds
              .where((i) => i['protocol'] == entry.$1)
              .firstOrNull,
          'tag':
              originalInbounds
                  .where((i) => i['protocol'] == entry.$1)
                  .firstOrNull?['tag'] ??
              entry.$1,
          'protocol': entry.$1,
          'listen': '127.0.0.1',
          'port': entry.$2,
          'settings': {'auth': 'noauth', if (entry.$1 == 'socks') 'udp': true},
        },
    ];
    if (!settings.useProfileDns || config['dns'] == null) {
      config['dns'] = {
        'servers': [settings.dns],
        'queryStrategy': 'UseIPv4',
      };
    }
    final outbounds = config['outbounds'] as List;
    // The native plugin reads endpoint information from the first outbound.
    // If reordering is required, explicitly retain the original default route.
    final proxyIndex = outbounds.indexWhere(
      (o) =>
          o is Map &&
          ['vless', 'vmess', 'shadowsocks', 'trojan'].contains(o['protocol']),
    );
    if (proxyIndex > 0) {
      final originalDefault = outbounds.first as Map<String, dynamic>;
      if (originalDefault['tag'] == null) {
        final tags = outbounds.whereType<Map>().map((o) => o['tag']).toSet();
        var defaultTag = 'plusvpn-original-default';
        while (tags.contains(defaultTag)) {
          defaultTag = '$defaultTag-1';
        }
        originalDefault['tag'] = defaultTag;
      }
      final routing = config['routing'] ??= <String, dynamic>{};
      final rules = routing['rules'] ??= <dynamic>[];
      (rules as List).add({
        'type': 'field',
        'network': 'tcp,udp',
        'outboundTag': originalDefault['tag'],
      });
      outbounds.insert(0, outbounds.removeAt(proxyIndex));
    }
    if (settings.bypassLan) {
      var direct = outbounds
          .whereType<Map<String, dynamic>>()
          .where((o) => o['protocol'] == 'freedom' && o['tag'] is String)
          .firstOrNull;
      if (direct == null) {
        final existingTags = outbounds
            .whereType<Map>()
            .map((o) => o['tag'])
            .toSet();
        var tag = 'plusvpn-direct';
        while (existingTags.contains(tag)) {
          tag = '$tag-1';
        }
        direct = {
          'tag': tag,
          'protocol': 'freedom',
          'settings': <String, dynamic>{},
        };
        outbounds.add(direct);
      }
      final routing = config['routing'] ??= <String, dynamic>{};
      final rules = routing['rules'] ??= <dynamic>[];
      (rules as List).insert(0, {
        'type': 'field',
        'ip': [
          '10.0.0.0/8',
          '172.16.0.0/12',
          '192.168.0.0/16',
          '127.0.0.0/8',
          '169.254.0.0/16',
          '::1/128',
          'fc00::/7',
          'fe80::/10',
        ],
        'outboundTag': direct['tag'],
      });
    }
    for (final key in ['remarks', 'ps', 'name', 'tag']) {
      config.remove(key);
    }
    return config;
  }
}
