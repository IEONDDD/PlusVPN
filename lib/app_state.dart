import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'services/subscription_service.dart';
import 'services/vpn_engine.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({VpnEngine? engine, SubscriptionService? subscriptions})
    : engine = engine ?? VpnEngine(),
      subscriptionsService = subscriptions ?? SubscriptionService();
  final VpnEngine engine;
  final SubscriptionService subscriptionsService;
  AppSettings settings = AppSettings();
  List<ServerProfile> servers = [];
  List<Subscription> subscriptions = [];
  String? selectedId, activeSubscriptionId, error;
  String connection = 'DISCONNECTED', duration = '00:00:00';
  int tab = 0, uploadSpeed = 0, downloadSpeed = 0;
  bool busy = false,
      pinging = false,
      sortByPing = false,
      _polling = false,
      _disposed = false;
  Timer? _timer;
  Future<void> _writes = Future.value();
  ServerProfile? get selected =>
      servers.where((s) => s.id == selectedId).firstOrNull;
  Subscription? get activeSubscription =>
      subscriptions.where((s) => s.id == activeSubscriptionId).firstOrNull;
  bool get connected => connection == 'CONNECTED';
  bool get transitioning =>
      connection == 'CONNECTING' || connection == 'DISCONNECTING';
  List<ServerProfile> get visibleServers {
    final list = servers
        .where(
          (s) =>
              activeSubscriptionId == null ||
              s.subscriptionId == activeSubscriptionId,
        )
        .toList();
    list.sort(
      (a, b) => sortByPing
          ? _pingRank(a).compareTo(_pingRank(b))
          : a.name.compareTo(b.name),
    );
    return list;
  }

  int _pingRank(ServerProfile s) =>
      s.ping == null || s.ping! < 0 ? 1 << 30 : s.ping!;
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    final prefs = await SharedPreferences.getInstance();
    try {
      final saved = prefs.getString('app_state');
      if (saved != null) {
        final j = jsonDecode(saved) as Map<String, dynamic>;
        settings = AppSettings.fromJson(j['settings']);
        servers = (j['servers'] as List)
            .map((e) => ServerProfile.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        subscriptions = (j['subscriptions'] as List)
            .map((e) => Subscription.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        selectedId = j['selectedId'];
        activeSubscriptionId = j['activeSubscriptionId'];
        if (settings.wallpaper != null &&
            !File(settings.wallpaper!).existsSync()) {
          settings.wallpaper = null;
        }
      }
    } catch (_) {
      error = 'Не удалось прочитать сохранённые данные';
    }
    selectedId = selected?.id ?? servers.firstOrNull?.id;
    await _poll();
    await engine.save(selected, settings);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_poll());
  }

  Future<void> _poll() async {
    if (_polling || _disposed) return;
    _polling = true;
    try {
      final s = await engine.snapshot();
      if (_disposed) return;
      connection = s['state'] ?? 'DISCONNECTED';
      duration = s['duration'] ?? '00:00:00';
      uploadSpeed = (s['uploadSpeed'] as num? ?? 0).toInt();
      downloadSpeed = (s['downloadSpeed'] as num? ?? 0).toInt();
      if (s['error'] case final String e when e.isNotEmpty) error = e;
      notifyListeners();
    } catch (_) {
      if (!_disposed) {
        error = 'Нет связи с Android VPN-сервисом';
        notifyListeners();
      }
    } finally {
      _polling = false;
    }
  }

  void setTab(int value) {
    tab = value;
    notifyListeners();
  }

  void setFilter(String? id) {
    activeSubscriptionId = id;
    notifyListeners();
  }

  void clearError() {
    error = null;
  }

  Future<void> persist() {
    final data = jsonEncode({
      'settings': settings.toJson(),
      'servers': servers.map((e) => e.toJson()).toList(),
      'subscriptions': subscriptions.map((e) => e.toJson()).toList(),
      'selectedId': selectedId,
      'activeSubscriptionId': activeSubscriptionId,
    });
    final profile = selected;
    final options = AppSettings.fromJson(settings.toJson());
    _writes = _writes.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('app_state', data)) {
        throw const FileSystemException('Не удалось сохранить настройки');
      }
      await engine.save(profile, options);
    });
    return _writes;
  }

  Future<void> updateSettings(void Function(AppSettings) change) async {
    change(settings);
    notifyListeners();
    try {
      await persist();
    } catch (_) {
      error = 'Не удалось сохранить настройки';
      notifyListeners();
    }
  }

  Future<T?> run<T>(Future<T> Function() operation) async {
    if (busy || transitioning) return null;
    busy = true;
    notifyListeners();
    try {
      return await operation();
    } catch (e) {
      error = e is FormatException
          ? e.message
          : e is SocketException
          ? 'Нет доступа к сети'
          : 'Операция не выполнена: $e';
      return null;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<int?> importText(String text) => run(() async {
    final result = await subscriptionsService.import(text);
    final sub = result.subscription;
    final previousSelected = selected;
    if (sub != null) {
      subscriptions.removeWhere((s) => s.id == sub.id);
      subscriptions.add(sub);
      final oldIds = servers
          .where((s) => s.subscriptionId == sub.id)
          .map((s) => s.id)
          .toSet();
      servers.removeWhere((s) => oldIds.contains(s.id));
      if (oldIds.contains(selectedId) &&
          !result.servers.any((s) => s.id == selectedId)) {
        final equivalent = result.servers
            .where(
              (s) =>
                  s.host == previousSelected?.host &&
                  s.port == previousSelected?.port &&
                  s.name == previousSelected?.name,
            )
            .firstOrNull;
        selectedId = equivalent?.id ?? result.servers.first.id;
      }
      activeSubscriptionId = sub.id;
    } else {
      activeSubscriptionId = null;
    }
    final existing = servers.map((s) => s.id).toSet();
    servers.addAll(result.servers.where((s) => !existing.contains(s.id)));
    selectedId ??= servers.first.id;
    final reconnect = connected && previousSelected?.id != selectedId;
    if (reconnect) await _disconnect();
    await persist();
    if (reconnect) await _connect();
    if (result.skipped > 0) {
      error =
          'Импортировано ${result.servers.length}; пропущено строк: ${result.skipped}';
    }
    return result.servers.length;
  });
  Future<void> select(ServerProfile profile) async {
    await run(() async {
      if (selectedId == profile.id) return;
      final reconnect = connected;
      if (reconnect) await _disconnect();
      selectedId = profile.id;
      await persist();
      if (reconnect) await _connect();
    });
  }

  Future<void> removeServer(ServerProfile profile) async {
    await run(() async {
      if (profile.id == selectedId && connected) await _disconnect();
      servers.removeWhere((s) => s.id == profile.id);
      selectedId = selected?.id ?? servers.firstOrNull?.id;
      await persist();
    });
  }

  Future<void> removeSubscription(Subscription sub) async {
    await run(() async {
      if (selected?.subscriptionId == sub.id && connected) await _disconnect();
      servers.removeWhere((s) => s.subscriptionId == sub.id);
      subscriptions.removeWhere((s) => s.id == sub.id);
      selectedId = selected?.id ?? servers.firstOrNull?.id;
      if (activeSubscriptionId == sub.id) activeSubscriptionId = null;
      await persist();
    });
  }

  Future<void> toggle() async {
    await run(() async {
      if (connected) {
        await _disconnect();
      } else {
        await _connect();
      }
    });
  }

  Future<void> _connect() async {
    if (selected == null) {
      throw const FormatException('Сначала добавьте сервер');
    }
    if (settings.perApp &&
        settings.appRoutingMode == AppRoutingMode.include &&
        settings.includedApps.isEmpty) {
      throw const FormatException('Выберите хотя бы одно приложение для VPN');
    }
    if (!await engine.prepare()) {
      throw const FormatException('Разрешение на VPN не получено');
    }
    await persist();
    await engine.start();
    connection = 'CONNECTING';
    notifyListeners();
    await _awaitState('CONNECTED');
  }

  Future<void> _disconnect() async {
    await engine.stop();
    connection = 'DISCONNECTING';
    notifyListeners();
    await _awaitState('DISCONNECTED');
  }

  Future<void> _awaitState(String expected) async {
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final snapshot = await engine.snapshot();
      if (snapshot['error'] case final String message when message.isNotEmpty) {
        throw FormatException(message);
      }
      if (snapshot['state'] == expected) {
        await _poll();
        return;
      }
      if (expected == 'CONNECTED' &&
          i > 4 &&
          snapshot['state'] == 'DISCONNECTED') {
        throw const FormatException(
          'Ядро не запустилось. Проверьте параметры сервера',
        );
      }
    }
    if (expected == 'CONNECTED') await engine.stop();
    await _poll();
    throw const FormatException('Сервис не ответил за 15 секунд');
  }

  Future<void> pingAll() async {
    if (pinging) return;
    pinging = true;
    notifyListeners();
    final queue = visibleServers.toList();
    var cursor = 0;
    Future<void> worker() async {
      while (cursor < queue.length && !_disposed) {
        final s = queue[cursor++];
        final ping = await VpnEngine.tcpPing(s);
        final index = servers.indexWhere((e) => e.id == s.id);
        if (index >= 0) servers[index] = servers[index].copyWith(ping: ping);
        if (!_disposed) notifyListeners();
      }
    }

    try {
      await Future.wait(List.generate(6, (_) => worker()));
    } finally {
      pinging = false;
      if (!_disposed) notifyListeners();
    }
  }

  void toggleSort() {
    sortByPing = !sortByPing;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    subscriptionsService.dispose();
    super.dispose();
  }
}
