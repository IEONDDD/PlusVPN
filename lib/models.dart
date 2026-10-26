import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

String stableId(String value) =>
    sha256.convert(utf8.encode(value)).toString().substring(0, 24);

class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    required this.credentials,
    this.options = const {},
    this.subscriptionId,
    this.ping,
    this.xrayConfig,
  });
  final String id, name, host, protocol, credentials;
  final int port;
  final Map<String, String> options;
  final String? subscriptionId;
  final int? ping;

  /// Complete imported profile, including balancers, routing and observatory.
  final Map<String, dynamic>? xrayConfig;
  String get flag => countryFlag(name);
  String get label => name.contains(flag) ? name : '$flag $name';
  String get protocolLabel =>
      '${protocol == 'ss' ? 'SS' : protocol.toUpperCase()}${options['security'] == 'reality' ? ' Reality' : ''}${options['type'] == 'xhttp' ? ' · XHTTP' : ''}${isAutomatic ? ' · Авто' : ''}';
  bool get isAutomatic =>
      (xrayConfig?['routing']?['balancers'] as List?)?.isNotEmpty ?? false;
  ServerProfile copyWith({String? subscriptionId, int? ping}) => ServerProfile(
    id: id,
    name: name,
    host: host,
    port: port,
    protocol: protocol,
    credentials: credentials,
    options: options,
    subscriptionId: subscriptionId ?? this.subscriptionId,
    ping: ping ?? this.ping,
    xrayConfig: xrayConfig,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'protocol': protocol,
    'credentials': credentials,
    'options': options,
    'subscriptionId': subscriptionId,
    if (xrayConfig != null) 'xrayConfig': xrayConfig,
  };
  factory ServerProfile.fromJson(Map<String, dynamic> j) => ServerProfile(
    id: j['id'],
    name: j['name'],
    host: j['host'],
    port: j['port'],
    protocol: j['protocol'],
    credentials: j['credentials'],
    options: Map<String, String>.from(j['options']),
    subscriptionId: j['subscriptionId'],
    xrayConfig: j['xrayConfig'] == null
        ? null
        : Map<String, dynamic>.from(j['xrayConfig']),
  );
}

String countryFlag(String name) {
  final existing = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}]{2}',
    unicode: true,
  ).firstMatch(name);
  if (existing != null) return existing.group(0)!;
  final n = name.toLowerCase();
  const countries = {
    'FI': ['финлян', 'finland', 'helsinki'],
    'DE': ['герман', 'germany', 'frankfurt'],
    'NL': ['нидерланд', 'netherlands', 'amsterdam', 'голланд'],
    'US': ['сша', 'united states', 'america', 'new york'],
    'GB': ['великобрит', 'united kingdom', 'london', 'англи'],
    'FR': ['франц', 'france', 'paris'],
    'SE': ['швец', 'sweden', 'stockholm'],
    'CH': ['швейцар', 'switzerland', 'zurich'],
    'PL': ['польш', 'poland', 'warsaw'],
    'TR': ['турц', 'turkey', 'istanbul'],
    'JP': ['япони', 'japan', 'tokyo'],
    'SG': ['сингап', 'singapore'],
    'RU': ['росси', 'russia', 'moscow'],
    'CA': ['канад', 'canada'],
    'EE': ['эстон', 'estonia'],
    'LV': ['латви', 'latvia'],
    'LT': ['литв', 'lithuania'],
    'NO': ['норвег', 'norway'],
    'AT': ['австр', 'austria'],
    'AU': ['австрал', 'australia'],
    'HK': ['гонконг', 'hong kong'],
  };
  for (final e in countries.entries) {
    if (e.value.any(n.contains) ||
        RegExp('(^|[^a-z])${e.key.toLowerCase()}([^a-z]|\$)').hasMatch(n)) {
      return String.fromCharCodes(e.key.codeUnits.map((c) => c + 127397));
    }
  }
  return '🌐';
}

class Subscription {
  const Subscription({
    required this.id,
    required this.url,
    required this.title,
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expires,
    this.updated,
  });
  final String id, url, title;
  final int upload, download, total;
  final DateTime? expires, updated;
  int get used => upload + download;
  double get progress => total > 0 ? (used / total).clamp(0, 1) : 0;
  int? get daysLeft => expires == null
      ? null
      : (expires!.difference(DateTime.now()).inSeconds / 86400).ceil();
  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'title': title,
    'upload': upload,
    'download': download,
    'total': total,
    'expires': expires?.toIso8601String(),
    'updated': updated?.toIso8601String(),
  };
  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
    id: j['id'],
    url: j['url'],
    title: j['title'],
    upload: j['upload'],
    download: j['download'],
    total: j['total'],
    expires: DateTime.tryParse(j['expires'] ?? ''),
    updated: DateTime.tryParse(j['updated'] ?? ''),
  );
}

enum InterfaceStyle { liquidGlass, materialYou }

class AppSettings {
  InterfaceStyle interfaceStyle = InterfaceStyle.liquidGlass;
  bool dynamicColors = true, wallpaperColors = false, showWord = true;
  bool perApp = false, bypassLan = true;
  int accent = 0xffc1e899;
  String subtitle = 'PlusVPN', greeting = '', word = 'breathe', dns = '1.1.1.1';
  bool useProfileDns = true;
  String? wallpaper;
  double blur = 12, opacity = .06;
  ThemeMode theme = ThemeMode.dark;
  List<String> excludedApps = [];
  Map<String, dynamic> toJson() => {
    'interfaceStyle': interfaceStyle.name,
    'dynamicColors': dynamicColors,
    'wallpaperColors': wallpaperColors,
    'showWord': showWord,
    'perApp': perApp,
    'bypassLan': bypassLan,
    'accent': accent,
    'subtitle': subtitle,
    'greeting': greeting,
    'word': word,
    'dns': dns,
    'useProfileDns': useProfileDns,
    'wallpaper': wallpaper,
    'blur': blur,
    'opacity': opacity,
    'theme': theme.name,
    'excludedApps': excludedApps,
  };
  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final s = AppSettings();
    s.interfaceStyle = InterfaceStyle.values.firstWhere(
      (e) => e.name == j['interfaceStyle'],
      orElse: () => InterfaceStyle.liquidGlass,
    );
    s.dynamicColors = j['dynamicColors'] ?? true;
    s.wallpaperColors = j['wallpaperColors'] ?? false;
    s.showWord = j['showWord'] ?? true;
    s.perApp = j['perApp'] ?? false;
    s.bypassLan = j['bypassLan'] ?? true;
    s.accent = j['accent'] ?? s.accent;
    s.subtitle = j['subtitle'] == 'Aurora'
        ? 'PlusVPN'
        : j['subtitle'] ?? s.subtitle;
    s.greeting = j['greeting'] ?? '';
    s.word = j['word'] ?? s.word;
    s.dns = j['dns'] ?? s.dns;
    s.useProfileDns = j['useProfileDns'] ?? true;
    s.wallpaper = j['wallpaper'];
    s.blur = (j['blur'] as num? ?? 12).toDouble().clamp(0, 40);
    s.opacity = (j['opacity'] as num? ?? .06).toDouble().clamp(.02, .20);
    s.theme = ThemeMode.values.firstWhere(
      (e) => e.name == j['theme'],
      orElse: () => ThemeMode.dark,
    );
    s.excludedApps = List<String>.from(j['excludedApps'] ?? []);
    return s;
  }
  AppSettings();
}
