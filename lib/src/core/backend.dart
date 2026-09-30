import 'dart:async';

import '../catalog/services.dart';

/// Everything the controller needs from the operating system.
abstract interface class Backend {
  /// Whether the engine can run here at all (Windows, bundled files, admin).
  Future<String?> unsupportedReason();

  Future<String> networkKey();

  Future<void> startDpi({
    required String networkKey,
    required bool youtube,
    required bool discord,
  });
  Future<void> stopDpi();

  Future<void> applySmartDns(List<String> domains, List<String> servers);
  Future<void> clearSmartDns();

  Future<void> startTelegram({required int port, required String secretHex});
  Future<void> stopTelegram();
  String? get telegramLink;
  Future<void> openTelegramLink();

  /// True if the service is reachable right now.
  Future<bool> probe(Service service, List<String> dnsServers);

  /// Fires when a running component stops on its own.
  Stream<String> get faults;
}
