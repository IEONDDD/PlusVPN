import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';

String decodeBase64Text(String input) => utf8.decode(
  base64.decode(base64.normalize(input.replaceAll(RegExp(r'\s'), ''))),
);

class ImportResult {
  const ImportResult(this.servers, {this.subscription, this.skipped = 0});
  final List<ServerProfile> servers;
  final Subscription? subscription;
  final int skipped;
}

class SubscriptionService {
  SubscriptionService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  void dispose() => _client.close();

  Future<ImportResult> import(String text) async {
    text = text.trim();
    if (text.isEmpty) {
      throw const FormatException(
        'Вставьте ключ, JSON или HTTPS-ссылку подписки',
      );
    }
    final uri = Uri.tryParse(text);
    if (uri?.scheme == 'http') {
      throw const FormatException('Для подписок требуется HTTPS');
    }
    if (uri?.scheme != 'https') return parseList(text);
    if (uri!.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const FormatException('Некорректная ссылка подписки');
    }
    // Follow redirects ourselves so an HTTPS subscription cannot downgrade to HTTP.
    var target = uri;
    http.StreamedResponse? response;
    for (var i = 0; i < 6; i++) {
      final request = http.Request('GET', target)..followRedirects = false;
      request.headers.addAll({
        'User-Agent': 'PlusVPN/1.1',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Charset': 'utf-8',
      });
      response = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers['location'];
        await response.stream.drain<void>().timeout(
          const Duration(seconds: 10),
        );
        if (location == null) {
          throw const FormatException('Пустой адрес перенаправления');
        }
        target = target.resolve(location);
        if (target.scheme != 'https' || target.userInfo.isNotEmpty) {
          throw const FormatException('Небезопасное перенаправление подписки');
        }
        response = null;
        continue;
      }
      break;
    }
    if (response == null) {
      throw const FormatException('Слишком много перенаправлений');
    }
    if (response.statusCode != 200) {
      await response.stream.drain<void>().timeout(const Duration(seconds: 10));
      throw FormatException(
        'Сервер подписки вернул HTTP ${response.statusCode}',
      );
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      bytes.addAll(chunk);
      if (bytes.length > 4 * 1024 * 1024) {
        throw const FormatException('Подписка больше 4 МБ');
      }
    }
    final id = stableId(text);
    final parsed = parseList(utf8.decode(bytes), subscriptionId: id);
    final headers = response.headers;
    var title = headers['profile-title'] ?? uri.host;
    if (title.startsWith('base64:')) {
      try {
        title = decodeBase64Text(title.substring(7));
      } on FormatException {
        title = uri.host;
      }
    } else {
      // Header bytes are ISO-8859-1; UTF-8 titles are common in subscription servers.
      try {
        title = utf8.decode(latin1.encode(title));
      } on ArgumentError {
        /* The HTTP client already returned a Unicode title. */
      } on FormatException {
        /* Already decoded. */
      }
    }
    final info = <String, int>{};
    for (final part in (headers['subscription-userinfo'] ?? '').split(';')) {
      final pair = part.trim().split('=');
      if (pair.length == 2) {
        info[pair[0].trim().toLowerCase()] = int.tryParse(pair[1].trim()) ?? 0;
      }
    }
    final expiration = info['expire'] ?? 0;
    return ImportResult(
      parsed.servers,
      skipped: parsed.skipped,
      subscription: Subscription(
        id: id,
        url: text,
        title: title,
        upload: (info['upload'] ?? 0).clamp(0, 1 << 62),
        download: (info['download'] ?? 0).clamp(0, 1 << 62),
        total: (info['total'] ?? 0).clamp(0, 1 << 62),
        expires: expiration > 0 && expiration < 8640000000000
            ? DateTime.fromMillisecondsSinceEpoch(expiration * 1000)
            : null,
        updated: DateTime.now(),
      ),
    );
  }

  static ImportResult parseList(String text, {String? subscriptionId}) {
    text = text.trim().replaceFirst('\ufeff', '');
    if (text.startsWith('{') || text.startsWith('[')) {
      return parseJson(text, subscriptionId: subscriptionId);
    }
    if (!RegExp(
      r'^(vless|vmess|ss|trojan)://',
      multiLine: true,
      caseSensitive: false,
    ).hasMatch(text)) {
      try {
        text = decodeBase64Text(text);
      } on FormatException {
        throw const FormatException(
          'Нужен URI-ключ, JSON Xray или Base64-подписка',
        );
      }
    }
    text = text.trim().replaceFirst('\ufeff', '');
    if (text.startsWith('{') || text.startsWith('[')) {
      return parseJson(text, subscriptionId: subscriptionId);
    }
    final profiles = <String, ServerProfile>{};
    var skipped = 0;
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      if (line.trim().isEmpty || line.trim().startsWith('#')) continue;
      try {
        final profile = parseKey(line.trim(), subscriptionId: subscriptionId);
        profiles[profile.id] = profile;
      } on FormatException {
        skipped++;
      }
    }
    if (profiles.isEmpty) {
      throw const FormatException(
        'Не найдено подключений. Поддерживаются VLESS, VMess, SS, Trojan и JSON Xray',
      );
    }
    return ImportResult(profiles.values.toList(), skipped: skipped);
  }

  static ImportResult parseJson(String text, {String? subscriptionId}) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException(
        'Некорректный JSON: проверьте скобки и запятые',
      );
    }
    final List<dynamic> entries;
    if (decoded is List) {
      entries = decoded;
    } else if (decoded is Map<String, dynamic> &&
        decoded['outbounds'] is List) {
      entries = [decoded];
    } else if (decoded is Map<String, dynamic> && decoded['profiles'] is List) {
      entries = decoded['profiles'];
    } else {
      throw const FormatException(
        'Ожидается профиль Xray с outbounds или массив таких профилей',
      );
    }
    final servers = <String, ServerProfile>{};
    var skipped = 0;
    for (var index = 0; index < entries.length; index++) {
      try {
        if (entries[index] is! Map<String, dynamic>) {
          throw const FormatException('Не объект');
        }
        final config = entries[index] as Map<String, dynamic>;
        final profile = _profileFromJson(
          config,
          subscriptionId: subscriptionId,
          index: index,
        );
        servers[profile.id] = profile;
      } on FormatException {
        skipped++;
      }
    }
    if (servers.isEmpty) {
      throw const FormatException('В JSON нет поддерживаемых профилей Xray');
    }
    return ImportResult(servers.values.toList(), skipped: skipped);
  }

  static ServerProfile _profileFromJson(
    Map<String, dynamic> config, {
    String? subscriptionId,
    required int index,
  }) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) throw const FormatException('Нет outbounds');
    final proxies = outbounds
        .whereType<Map<String, dynamic>>()
        .where(
          (o) => [
            'vless',
            'vmess',
            'trojan',
            'shadowsocks',
          ].contains(o['protocol']),
        )
        .toList();
    if (proxies.isEmpty) {
      throw const FormatException('Нет поддерживаемого proxy outbound');
    }
    // Validate every proxy while retaining all native fields, including XHTTP extra.
    for (final outbound in proxies) {
      final settings = outbound['settings'];
      if (settings is! Map) {
        throw const FormatException('Нет настроек outbound');
      }
      final endpoints = settings['vnext'] ?? settings['servers'];
      if (endpoints is! List || endpoints.isEmpty) {
        throw const FormatException('Нет адреса сервера');
      }
      for (final endpoint in endpoints) {
        if (endpoint is! Map ||
            endpoint['address'] is! String ||
            (endpoint['address'] as String).isEmpty) {
          throw const FormatException('Нет адреса сервера');
        }
        final port = int.tryParse('${endpoint['port']}') ?? 0;
        if (port < 1 || port > 65535) {
          throw const FormatException('Некорректный порт');
        }
      }
      final stream = outbound['streamSettings'];
      if (stream is Map &&
          stream['tlsSettings'] is Map &&
          [
            true,
            1,
            '1',
            'true',
          ].contains(stream['tlsSettings']['allowInsecure'])) {
        throw const FormatException('Ядро не поддерживает allowInsecure');
      }
    }
    final primary = proxies.first;
    final configSettings = primary['settings'] as Map;
    final endpoint =
        ((configSettings['vnext'] ?? configSettings['servers']) as List).first
            as Map;
    final stream = primary['streamSettings'] is Map
        ? primary['streamSettings'] as Map
        : const {};
    final users = endpoint['users'];
    final user = users is List && users.isNotEmpty && users.first is Map
        ? users.first as Map
        : const {};
    final candidates = [
      config['remarks'],
      config['ps'],
      config['name'],
      config['tag'],
    ];
    final name =
        candidates
            .whereType<String>()
            .where((n) => n.trim().isNotEmpty)
            .firstOrNull ??
        'Профиль ${index + 1}';
    final options = <String, String>{
      'type': '${stream['network'] ?? 'tcp'}',
      'security': '${stream['security'] ?? 'none'}',
    };
    return ServerProfile(
      id: stableId(
        '${subscriptionId ?? 'local-json'}:${_canonicalJson(config)}',
      ),
      name: name,
      host: endpoint['address'],
      port: int.parse('${endpoint['port']}'),
      protocol: primary['protocol'] == 'shadowsocks'
          ? 'ss'
          : primary['protocol'],
      credentials: '${user['id'] ?? endpoint['password'] ?? ''}',
      options: options,
      subscriptionId: subscriptionId,
      xrayConfig: jsonDecode(jsonEncode(config)) as Map<String, dynamic>,
    );
  }

  static String _canonicalJson(dynamic value) {
    dynamic sorted(dynamic node) {
      if (node is Map<String, dynamic>) {
        final keys = node.keys.toList()..sort();
        return {for (final key in keys) key: sorted(node[key])};
      }
      if (node is List) return node.map(sorted).toList();
      return node;
    }

    return jsonEncode(sorted(value));
  }

  static ServerProfile parseKey(String key, {String? subscriptionId}) {
    final scheme = key.split('://').first.toLowerCase();
    if (!['vless', 'vmess', 'ss', 'trojan'].contains(scheme)) {
      throw const FormatException('Неизвестный протокол');
    }
    String host, name, credentials;
    int port;
    Map<String, String> options;
    if (scheme == 'vmess') {
      try {
        final j =
            jsonDecode(decodeBase64Text(key.substring(8)))
                as Map<String, dynamic>;
        host = '${j['add'] ?? ''}';
        port = int.tryParse('${j['port']}') ?? 0;
        name = '${j['ps'] ?? host}';
        credentials = '${j['id'] ?? ''}';
        options = {
          'type': '${j['net'] ?? 'tcp'}',
          'security': j['tls'] == 'tls' ? 'tls' : 'none',
          'sni': '${j['sni'] ?? j['host'] ?? host}',
          'host': '${j['host'] ?? ''}',
          'path': '${j['path'] ?? '/'}',
          'serviceName': '${j['path'] ?? ''}',
          'aid': '${j['aid'] ?? 0}',
          'cipher': '${j['scy'] ?? 'auto'}',
          'headerType': '${j['type'] ?? 'none'}',
          'fp': '${j['fp'] ?? ''}',
          'alpn': '${j['alpn'] ?? ''}',
        };
      } catch (_) {
        throw const FormatException('Некорректный VMess JSON');
      }
    } else if (scheme == 'ss') {
      // SIP002 and the legacy whole-payload Base64 format, including IPv6.
      var payload = key.substring(5);
      final hash = payload.indexOf('#');
      name = hash < 0 ? '' : Uri.decodeComponent(payload.substring(hash + 1));
      payload = hash < 0 ? payload : payload.substring(0, hash);
      if (!payload.contains('@')) payload = decodeBase64Text(payload);
      final uri = Uri.parse('ss://$payload');
      if (uri.queryParameters['plugin']?.isNotEmpty ?? false) {
        throw const FormatException('SS plugins не поддерживаются');
      }
      var auth = Uri.decodeComponent(uri.userInfo);
      if (!auth.contains(':')) auth = decodeBase64Text(auth);
      final colon = auth.indexOf(':');
      if (colon < 1) throw const FormatException('Некорректные SS credentials');
      host = uri.host;
      port = uri.hasPort ? uri.port : 8388;
      credentials = auth.substring(colon + 1);
      options = {
        'method': auth.substring(0, colon),
        'type': 'tcp',
        'security': 'none',
      };
    } else {
      final uri = Uri.parse(key);
      host = uri.host;
      port = uri.hasPort ? uri.port : 443;
      name = Uri.decodeComponent(uri.fragment);
      credentials = Uri.decodeComponent(uri.userInfo);
      options = Map<String, String>.from(uri.queryParameters);
      options['type'] ??= 'tcp';
      options['security'] ??= scheme == 'trojan' ? 'tls' : 'none';
      if (options['allowInsecure'] == '1' ||
          options['allowInsecure'] == 'true') {
        throw const FormatException(
          'Ключ требует отключения проверки TLS, что не поддерживается этим ядром',
        );
      }
    }
    if (host.isEmpty || port < 1 || port > 65535 || credentials.isEmpty) {
      throw const FormatException('Отсутствует адрес, порт или пароль');
    }
    if (['vless', 'vmess'].contains(scheme) &&
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(credentials)) {
      throw const FormatException('Требуется корректный UUID');
    }
    if (options['type'] == 'raw') options['type'] = 'tcp';
    if (!['tcp', 'ws', 'grpc', 'xhttp'].contains(options['type'])) {
      throw FormatException('Транспорт ${options['type']} не поддерживается');
    }
    if (!['none', 'tls', 'reality'].contains(options['security'])) {
      throw const FormatException('Неизвестный тип TLS');
    }
    if (options['security'] == 'reality' && (options['pbk'] ?? '').isEmpty) {
      throw const FormatException('Reality: отсутствует pbk');
    }
    if (scheme == 'vmess' && (int.tryParse(options['aid'] ?? '') ?? -1) != 0) {
      throw const FormatException(
        'Устаревший VMess alterId не поддерживается Xray',
      );
    }
    return ServerProfile(
      id: stableId('${subscriptionId ?? 'local'}:$key'),
      name: name.isEmpty ? host : name,
      host: host,
      port: port,
      protocol: scheme,
      credentials: credentials,
      options: options,
      subscriptionId: subscriptionId,
    );
  }
}
