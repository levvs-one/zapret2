import 'dart:async';
import 'dart:io';

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
  Completer<void>? smartDnsGate;
  Completer<void>? stopDpiGate;

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
  Future<void> stopDpi() async {
    calls.add('stopDpi');
    await stopDpiGate?.future;
  }

  @override
  Future<void> applySmartDns(List<String> domains, List<String> servers) async {
    calls.add('dns ${domains.length}');
    await smartDnsGate?.future;
  }

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
  Future<void> stopTelegram() async {
    telegram = false;
    calls.add('stopTg');
  }

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

  test('stop during start cannot leave later mechanisms running', () async {
    await c.init(connect: false);
    backend.calls.clear();
    backend.smartDnsGate = Completer<void>();

    final starting = c.start();
    await pumpEventQueue(times: 10);
    final dnsDomains = Catalog.all
        .where((s) => s.mechanism == Mechanism.smartDns)
        .fold<int>(0, (n, s) => n + s.domains.length);
    expect(backend.calls, contains('dns $dnsDomains'));
    expect(c.power, Power.starting);

    final stopping = c.stop();
    backend.smartDnsGate!.complete();
    await Future.wait([starting, stopping]);

    expect(c.power, Power.off);
    expect(backend.telegram, isFalse);
    expect(backend.calls, isNot(contains('tg')));
    expect(
      backend.calls,
      containsAllInOrder(['dns $dnsDomains', 'stopDpi', 'clearDns', 'stopTg']),
    );
  });

  test('service toggle during startup is reconciled after start', () async {
    await c.init(connect: false);
    backend.calls.clear();
    backend.smartDnsGate = Completer<void>();

    final starting = c.start();
    await pumpEventQueue(times: 10);
    expect(c.power, Power.starting);
    expect(backend.calls, contains('dpi yt=true dc=true'));

    final disabling = c.setEnabled(Catalog.youtube, false);
    backend.smartDnsGate!.complete();

    await Future.wait([starting, disabling]);

    expect(c.power, Power.on);
    expect(c.isEnabled(Catalog.youtube), isFalse);
    expect(
      backend.calls,
      containsAllInOrder(['dpi yt=true dc=true', 'dpi yt=false dc=true']),
    );
  });

  test('a second stop waits for the in-flight shutdown', () async {
    await c.init(connect: false);
    await c.start();
    backend.stopDpiGate = Completer<void>();

    final first = c.stop();
    await pumpEventQueue();
    expect(c.power, Power.stopping);

    var secondReturned = false;
    final second = c.stop().then((_) => secondReturned = true);
    await pumpEventQueue();
    expect(secondReturned, isFalse);

    backend.stopDpiGate!.complete();
    await Future.wait([first, second]);

    expect(secondReturned, isTrue);
    expect(c.power, Power.off);
  });

  test('late backend fault while off is ignored', () async {
    await c.init(connect: false);
    backend.calls.clear();

    backend.faultsCtl.add('late exit');
    await pumpEventQueue();

    expect(c.power, Power.off);
    expect(c.error, isNull);
    expect(backend.calls, isEmpty);
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

  test('first settings load persists the generated Telegram secret', () {
    final dir = Directory.systemTemp.createTempSync('prosvet-settings-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = '${dir.path}${Platform.pathSeparator}settings.json';

    final first = Settings.load(file);
    expect(File(file).existsSync(), isTrue);

    final second = Settings.load(file);
    expect(second.telegramSecret, first.telegramSecret);
  });

  test('older settings without a Telegram secret are migrated once', () {
    final dir = Directory.systemTemp.createTempSync('prosvet-migrate-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = '${dir.path}${Platform.pathSeparator}settings.json';
    File(file).writeAsStringSync(
      '{"enabled":[],"dnsProvider":"xbox-dns","telegramPort":1443,'
      '"connectOnLaunch":false}',
    );

    final first = Settings.load(file);
    final second = Settings.load(file);

    expect(first.telegramSecret, hasLength(32));
    expect(second.telegramSecret, first.telegramSecret);
  });

  test('invalid existing settings are preserved instead of overwritten', () {
    final dir = Directory.systemTemp.createTempSync('prosvet-corrupt-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = '${dir.path}${Platform.pathSeparator}settings.json';
    const original = '{"dnsProvider":123}';
    File(file).writeAsStringSync(original);

    final loaded = Settings.load(file);

    expect(loaded.telegramSecret, hasLength(32));
    expect(File(file).readAsStringSync(), original);
  });
}
