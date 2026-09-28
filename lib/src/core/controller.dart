import 'dart:async';

import 'package:flutter/foundation.dart';

import '../catalog/services.dart';
import '../engine/smartdns/provider.dart';
import 'backend.dart';
import 'settings.dart';

enum Power { off, starting, on, stopping }

enum Health { idle, checking, ok, failing }

/// Single source of truth for the UI.
class Controller extends ChangeNotifier {
  Controller({
    required this.backend,
    required this.settings,
    required this.saveSettings,
    this.probeAttempts = 6,
    this.probeInterval = const Duration(milliseconds: 1200),
  }) {
    _faultSub = backend.faults.listen((message) async {
      error = message;
      await _shutdown();
    });
  }

  final Backend backend;
  final Settings settings;
  final void Function(Settings) saveSettings;

  /// Each failed probe feeds the zapret2 failure detector, which moves the
  /// blocked host to the next strategy. A few quick rounds are enough.
  final int probeAttempts;
  final Duration probeInterval;

  Power power = Power.off;
  String? error;
  String? unsupported;
  final Map<String, Health> health = {
    for (final s in Catalog.all) s.id: Health.idle,
  };

  late final StreamSubscription<String> _faultSub;
  var _generation = 0;

  SmartDnsProvider get dnsProvider =>
      SmartDnsProvider.byId(settings.dnsProvider);

  Iterable<Service> _enabled(Mechanism m) =>
      Catalog.all.where((s) => s.mechanism == m && settings.isOn(s));

  bool isEnabled(Service s) => settings.isOn(s);

  String? get telegramLink => backend.telegramLink;

  Future<void> init({required bool connect}) async {
    unsupported = await backend.unsupportedReason();
    if (unsupported == null) {
      // Leftovers after a crash or a forced shutdown.
      await _guard(backend.clearSmartDns);
    }
    notifyListeners();
    if (unsupported == null && connect) await start();
  }

  Future<void> toggle() => power == Power.off ? start() : stop();

  Future<void> start() async {
    if (power != Power.off || unsupported != null) return;
    final gen = ++_generation;
    error = null;
    power = Power.starting;
    notifyListeners();
    try {
      await _applyAll();
      if (gen != _generation) return;
      power = Power.on;
      notifyListeners();
      await _checkAll(gen);
    } catch (e) {
      error = _describe(e);
      await _shutdown();
    }
  }

  Future<void> stop() async {
    if (power == Power.off || power == Power.stopping) return;
    _generation++;
    power = Power.stopping;
    notifyListeners();
    await _shutdown();
  }

  Future<void> setEnabled(Service s, bool on) async {
    if (on) {
      settings.enabled.add(s.id);
    } else {
      settings.enabled.remove(s.id);
    }
    saveSettings(settings);
    health[s.id] = Health.idle;
    notifyListeners();
    if (power != Power.on) return;
    final gen = ++_generation;
    try {
      await _applyMechanism(s.mechanism);
      if (on) await _check([s], gen);
    } catch (e) {
      error = _describe(e);
      await _shutdown();
    }
  }

  Future<void> setConnectOnLaunch(bool on) async {
    settings.connectOnLaunch = on;
    saveSettings(settings);
    notifyListeners();
  }

  Future<void> recheck() async {
    if (power != Power.on) return;
    await _checkAll(++_generation);
  }

  Future<void> openTelegram() => backend.openTelegramLink();

  Future<void> _applyAll() async {
    for (final m in Mechanism.values) {
      await _applyMechanism(m);
    }
  }

  Future<void> _applyMechanism(Mechanism m) async {
    final services = _enabled(m).toList();
    switch (m) {
      case Mechanism.dpi:
        if (services.isEmpty) {
          await backend.stopDpi();
        } else {
          await backend.startDpi(
            networkKey: await backend.networkKey(),
            youtube: services.contains(Catalog.youtube),
            discord: services.contains(Catalog.discord),
          );
        }
      case Mechanism.smartDns:
        if (services.isEmpty) {
          await backend.clearSmartDns();
        } else {
          await backend.applySmartDns([
            for (final s in services) ...s.domains,
          ], dnsProvider.servers);
        }
      case Mechanism.telegram:
        if (services.isEmpty) {
          await backend.stopTelegram();
        } else {
          await backend.startTelegram(
            port: settings.telegramPort,
            secretHex: settings.telegramSecret,
          );
        }
    }
  }

  Future<void> _checkAll(int gen) =>
      _check(Catalog.all.where(settings.isOn).toList(), gen);

  Future<void> _check(List<Service> services, int gen) async {
    for (final s in services) {
      health[s.id] = Health.checking;
    }
    notifyListeners();
    await Future.wait(
      services.map((s) async {
        for (var i = 0; i < probeAttempts; i++) {
          if (gen != _generation) return;
          if (await backend.probe(s, dnsProvider.servers)) {
            if (gen == _generation) health[s.id] = Health.ok;
            notifyListeners();
            return;
          }
          // Only DPI profiles improve by retrying: zapret2 rotates strategies.
          if (s.mechanism != Mechanism.dpi) break;
          await Future<void>.delayed(probeInterval);
        }
        if (gen == _generation) health[s.id] = Health.failing;
        notifyListeners();
      }),
    );
  }

  Future<void> _shutdown() async {
    _generation++;
    await _guard(backend.stopDpi);
    await _guard(backend.clearSmartDns);
    await _guard(backend.stopTelegram);
    for (final k in health.keys) {
      health[k] = Health.idle;
    }
    power = Power.off;
    notifyListeners();
  }

  Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      error ??= _describe(e);
    }
  }

  static String _describe(Object e) {
    final s = e is StateError ? e.message : e.toString();
    return s.trim().isEmpty ? 'Неизвестная ошибка' : s.trim();
  }

  @override
  void dispose() {
    _faultSub.cancel();
    super.dispose();
  }
}
