import 'dart:async';

import '../catalog/services.dart';
import 'backend.dart';

/// Simulated backend for UI work on any OS: `flutter run -- --demo`.
class DemoBackend implements Backend {
  final _faults = StreamController<String>.broadcast();
  bool _telegram = false;
  var _probes = 0;

  @override
  Stream<String> get faults => _faults.stream;

  @override
  Future<String?> unsupportedReason() async => null;

  @override
  Future<String> networkKey() async => 'demo';

  Future<void> _work([int ms = 500]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  @override
  Future<void> startDpi({
    required String networkKey,
    required bool youtube,
    required bool discord,
  }) => _work(700);

  @override
  Future<void> stopDpi() => _work(200);

  @override
  Future<void> applySmartDns(List<String> domains, List<String> servers) =>
      _work(300);

  @override
  Future<void> clearSmartDns() => _work(150);

  @override
  Future<void> startTelegram({
    required int port,
    required String secretHex,
  }) async {
    await _work(100);
    _telegram = true;
  }

  @override
  Future<void> stopTelegram() async => _telegram = false;

  @override
  String? get telegramLink =>
      _telegram ? 'tg://proxy?server=127.0.0.1&port=1443&secret=dd00' : null;

  @override
  Future<void> openTelegramLink() async {}

  @override
  Future<bool> probe(Service service, List<String> dnsServers) async {
    await _work(600);
    // Discord needs one strategy rotation in the demo.
    if (service.id == 'discord') return ++_probes % 3 == 0;
    return true;
  }
}
