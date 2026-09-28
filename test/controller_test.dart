import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prosvet/src/catalog/services.dart';
import 'package:prosvet/src/core/backend.dart';
import 'package:prosvet/src/core/controller.dart';
import 'package:prosvet/src/core/settings.dart';

class FakeBackend implements Backend {
  final calls = <String>[];
  final faultsCtl = StreamController<String>.broadcast();
  String? unsupported;
  Object? dpiError;
  final Map<String, List<bool>> answers = {};
  bool telegram = false;

  @override
  Stream<String> get faults => faultsCtl.stream;

  @override
  Future<String?> unsupportedReason() async => unsupported;

  @override
  Future<String> networkKey() async => 'net';

  @override
  Future<void> startDpi({
    required String networkKey,
    required bool youtube,
    required bool discord,
  }) async {
    calls.add('dpi yt=$youtube dc=$discord');
    if (dpiError != null) throw dpiError!;
  }

  @override
  Future<void> stopDpi() async => calls.add('stopDpi');

  @override
  Future<void> applySmartDns(
    List<String> domains,
    List<String> servers,
  ) async => calls.add('dns ${domains.length}');

  @override
  Future<void> clearSmartDns() async => calls.add('clearDns');

  @override
  Future<void> startTelegram({
    required int port,
    required String secretHex,
  }) async {
    telegram = true;
    calls.add('tg');
  }

  @override
  Future<void> stopTelegram() async => telegram = false;

  @override
  String? get telegramLink => telegram ? 'tg://proxy' : null;

  @override
  Future<void> openTelegramLink() async {}

  @override
  Future<bool> probe(Service service, List<String> dnsServers) async {
    final a = answers[service.id];
    if (a == null || a.isEmpty) return true;
    return a.removeAt(0);
  }
}

void main() {
  late FakeBackend backend;
  late Controller c;

  setUp(() {
    backend = FakeBackend();
    c = Controller(
      backend: backend,
      settings: Settings.defaults(),
      saveSettings: (_) {},
      probeInterval: Duration.zero,
      probeAttempts: 3,
    );
  });

  test('start applies every mechanism and checks services', () async {
    await c.init(connect: false);
    expect(backend.calls, ['clearDns']);
    backend.answers['discord'] = [false, false, true];
    backend.answers['claude'] = [false];
    await c.start();
    expect(c.power, Power.on);
    final dnsDomains = Catalog.all.fold<int>(0, (n, s) => n + s.domains.length);
    expect(
      backend.calls,
      containsAllInOrder(['dpi yt=true dc=true', 'dns $dnsDomains', 'tg']),
    );
    expect(c.health['youtube'], Health.ok);
    expect(
      c.health['discord'],
      Health.ok,
      reason: 'retries while zapret2 rotates',
    );
    expect(c.health['claude'], Health.failing, reason: 'dns is not retried');
  });

  test('failure while starting rolls everything back', () async {
    backend.dpiError = StateError('WinDivert: access denied');
    await c.init(connect: false);
    await c.start();
    expect(c.power, Power.off);
    expect(c.error, 'WinDivert: access denied');
    expect(backend.calls, containsAll(['stopDpi', 'clearDns']));
  });

  test('engine crash turns the app off', () async {
    await c.init(connect: false);
    await c.start();
    backend.faultsCtl.add('Движок остановился');
    await pumpEventQueue();
    expect(c.power, Power.off);
    expect(c.error, 'Движок остановился');
  });

  test('toggling a service while on restarts only its mechanism', () async {
    await c.init(connect: false);
    await c.start();
    backend.calls.clear();
    await c.setEnabled(Catalog.youtube, false);
    expect(backend.calls, ['dpi yt=false dc=true']);
    expect(c.health['youtube'], Health.idle);
  });

  test('unsupported environment never starts', () async {
    backend.unsupported = 'Запустите от имени администратора.';
    await c.init(connect: true);
    await c.start();
    expect(c.power, Power.off);
    expect(backend.calls, isEmpty);
  });

  test('settings survive a json round trip and drop unknown services', () {
    final s = Settings.defaults()..enabled.remove('spotify');
    final j = s.toJson()
      ..['enabled'] = [...(s.toJson()['enabled']! as List), 'nope'];
    final back = Settings.fromJson(j);
    expect(back.enabled, s.enabled);
    expect(back.telegramSecret, s.telegramSecret);
  });
}
