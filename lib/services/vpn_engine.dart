import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models.dart';
import 'config_builder.dart';

class VpnEngine {
  static const channel = MethodChannel('com.plusvpn/control');
  Future<Map<String, dynamic>> snapshot() async => Map<String, dynamic>.from(
    await channel.invokeMapMethod<String, dynamic>('snapshot') ?? {},
  );
  Future<void> save(ServerProfile? server, AppSettings settings) =>
      channel.invokeMethod('saveProfile', {
        'id': server?.id,
        'label': server?.label ?? 'PlusVPN',
        'config': server == null ? '' : ConfigBuilder.build(server, settings),
        'excludedApps':
            settings.perApp && settings.appRoutingMode == AppRoutingMode.exclude
            ? settings.excludedApps
            : <String>[],
        'includeOnly':
            settings.perApp &&
            settings.appRoutingMode == AppRoutingMode.include,
        'includedApps':
            settings.perApp && settings.appRoutingMode == AppRoutingMode.include
            ? settings.includedApps
            : <String>[],
      });
  Future<bool> prepare() async =>
      await channel.invokeMethod<bool>('prepare') ?? false;
  Future<void> start() => channel.invokeMethod('start');
  Future<void> stop() => channel.invokeMethod('stop');
  Future<String?> pickConfigFile() =>
      channel.invokeMethod<String>('pickConfigFile');
  Future<List<Map<String, String>>> installedApps() async {
    final apps = await channel.invokeListMethod<dynamic>('installedApps') ?? [];
    return apps.map((e) => Map<String, String>.from(e)).toList();
  }

  // TCP connect latency includes DNS, and does not assert tunnel health.
  static Future<int> tcpPing(ServerProfile server) async {
    Socket? socket;
    final watch = Stopwatch()..start();
    try {
      socket = await Socket.connect(
        server.host,
        server.port,
        timeout: const Duration(seconds: 4),
      );
      return watch.elapsedMilliseconds;
    } on SocketException {
      return -1;
    } on TimeoutException {
      return -1;
    } finally {
      socket?.destroy();
    }
  }

  static Future<bool> openUrl(String url) async {
    try {
      return await channel.invokeMethod<bool>('openUrl', {'url': url}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      return await channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations') ?? false;
    } catch (_) {
      return false;
    }
  }
}
