import 'dart:async';

import 'package:flutter/foundation.dart';

import '../catalog/services.dart';
import '../engine/smartdns/provider.dart';
import 'backend.dart';
import 'settings.dart';

enum Power { off, starting, on, stopping }

enum Health { idle, checking, ok, failing }

/// Single source of truth for the UI.
///
/// Backend mutations are serialized so start/stop/service changes cannot race
/// each other and leave Windows in a state that disagrees with the UI.
class Controller extends ChangeNotifier {
  Controller({
    required this.backend,
    required this.settings,
    required this.saveSettings,
    this.probeAttempts = 6,
    this.probeInterval = const Duration(milliseconds: 1200),
  }) {
    _faultSub = backend.faults.listen((message) {
      unawaited(_failAndShutdown(message));
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

  // OS mutations must never overlap. The lifecycle generation cancels queued
  // work after stop/fault; the health generation only invalidates old probes.
  Future<void> _operations = Future<void>.value();
  var _lifecycleGeneration = 0;
  var _healthGeneration = 0;

  SmartDnsProvider get dnsProvider =>
      SmartDnsProvider.byId(settings.dnsProvider);

  Iterable<Service> _enabled(Mechanism m) =>
      Catalog.all.where((s) => s.mechanism == m && settings.isOn(s));

  bool isEnabled(Service s) => settings.isOn(s);

  String? get telegramLink => backend.telegramLink;

  Future<void> init({required bool connect}) async {
    unsupported = await backend.unsupportedReason();
    if (unsupported == null) {
      // Leftovers after a crash or a forced shutdown. Single-instance
      // enforcement in the Windows runner makes this safe for a live session.
      await _exclusive(() => _guard(backend.clearSmartDns));
    }
    notifyListeners();
    if (unsupported == null && connect) await start();
  }

  Future<void> toggle() => power == Power.off ? start() : stop();

  Future<void> start() async {
    if (power != Power.off || unsupported != null) return;

    final lifecycleGen = ++_lifecycleGeneration;
    final healthGen = ++_healthGeneration;
    error = null;
    power = Power.starting;
    notifyListeners();

    try {
      final started = await _exclusive(() async {
        if (lifecycleGen != _lifecycleGeneration) return false;
        await _applyAll(lifecycleGen);
        if (lifecycleGen != _lifecycleGeneration) return false;
        power = Power.on;
        notifyListeners();
        return true;
      });
      if (!started) return;
      await _checkAll(healthGen);
    } catch (e) {
      if (lifecycleGen != _lifecycleGeneration) return;
      error = _describe(e);
      ++_lifecycleGeneration;
      ++_healthGeneration;
      power = Power.stopping;
      notifyListeners();
      await _exclusive(_shutdown);
    }
  }

  Future<void> stop() async {
    if (power == Power.off) return;
    if (power == Power.stopping) {
      // Callers such as the tray "Exit" action need a completion barrier, not
      // a no-op. Otherwise the process can exit while NRPT cleanup is still
      // running.
      await _operations;
      return;
    }
    ++_lifecycleGeneration;
    ++_healthGeneration;
    power = Power.stopping;
    notifyListeners();
    await _exclusive(_shutdown);
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
    if (power == Power.off || power == Power.stopping) return;

    // If a toggle happens while start() owns the operation queue, enqueue the
    // mechanism reconciliation behind it. When this action runs, startup has
    // either reached Power.on or invalidated the lifecycle generation.
    final lifecycleGen = _lifecycleGeneration;
    final healthGen = ++_healthGeneration;
    try {
      final applied = await _exclusive(() async {
        if (power != Power.on || lifecycleGen != _lifecycleGeneration) {
          return false;
        }
        await _applyMechanism(s.mechanism);
        return power == Power.on && lifecycleGen == _lifecycleGeneration;
      });
      if (applied) await _checkAll(healthGen);
    } catch (e) {
      if (lifecycleGen != _lifecycleGeneration) return;
      error = _describe(e);
      ++_lifecycleGeneration;
      ++_healthGeneration;
      power = Power.stopping;
      notifyListeners();
      await _exclusive(_shutdown);
    }
  }

  Future<void> setConnectOnLaunch(bool on) async {
    settings.connectOnLaunch = on;
    saveSettings(settings);
    notifyListeners();
  }

  Future<void> recheck() async {
    if (power != Power.on) return;
    await _checkAll(++_healthGeneration);
  }

  Future<void> openTelegram() => backend.openTelegramLink();

  Future<void> _applyAll(int lifecycleGen) async {
    for (final m in Mechanism.values) {
      if (lifecycleGen != _lifecycleGeneration) return;
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
    if (gen != _healthGeneration) return;
    for (final s in services) {
      health[s.id] = Health.checking;
    }
    notifyListeners();

    await Future.wait(
      services.map((s) async {
        for (var i = 0; i < probeAttempts; i++) {
          if (gen != _healthGeneration) return;
          if (await backend.probe(s, dnsProvider.servers)) {
            if (gen == _healthGeneration) {
              health[s.id] = Health.ok;
              notifyListeners();
            }
            return;
          }
          // Only DPI profiles improve by retrying: zapret2 rotates strategies.
          if (s.mechanism != Mechanism.dpi) break;
          await Future<void>.delayed(probeInterval);
        }
        if (gen == _healthGeneration) {
          health[s.id] = Health.failing;
          notifyListeners();
        }
      }),
    );
  }

  Future<void> _failAndShutdown(String message) async {
    if (power == Power.off) return;
    error = message;
    ++_lifecycleGeneration;
    ++_healthGeneration;
    if (power != Power.off) {
      power = Power.stopping;
      notifyListeners();
    }
    await _exclusive(_shutdown);
  }

  Future<void> _shutdown() async {
    await _guard(backend.stopDpi);
    await _guard(backend.clearSmartDns);
    await _guard(backend.stopTelegram);
    for (final k in health.keys) {
      health[k] = Health.idle;
    }
    power = Power.off;
    notifyListeners();
  }

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final done = Completer<T>();
    _operations = _operations.then((_) async {
      try {
        done.complete(await action());
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
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
