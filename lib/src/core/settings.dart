import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../catalog/services.dart';
import '../engine/smartdns/provider.dart';

class Settings {
  Settings({
    required this.enabled,
    required this.dnsProvider,
    required this.telegramPort,
    required this.telegramSecret,
    required this.connectOnLaunch,
  });

  factory Settings.defaults() => Settings(
    enabled: {for (final s in Catalog.all) s.id},
    dnsProvider: SmartDnsProvider.xboxDns.id,
    telegramPort: 1443,
    telegramSecret: _randomSecret(),
    connectOnLaunch: false,
  );

  final Set<String> enabled;
  String dnsProvider;
  int telegramPort;
  String telegramSecret;
  bool connectOnLaunch;

  bool isOn(Service s) => enabled.contains(s.id);

  static bool _validSecret(Object? value) =>
      value is String && RegExp(r'^[0-9a-f]{32}$').hasMatch(value);

  static String _randomSecret() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Map<String, Object> toJson() => {
    'enabled': enabled.toList()..sort(),
    'dnsProvider': dnsProvider,
    'telegramPort': telegramPort,
    'telegramSecret': telegramSecret,
    'connectOnLaunch': connectOnLaunch,
  };

  static Settings fromJson(Map<String, Object?> j) {
    final d = Settings.defaults();
    final secret = j['telegramSecret'];
    final known = {for (final s in Catalog.all) s.id};
    return Settings(
      enabled: j['enabled'] is List
          ? {
              for (final e in j['enabled']! as List)
                if (known.contains(e)) e as String,
            }
          : d.enabled,
      dnsProvider: j['dnsProvider'] as String? ?? d.dnsProvider,
      telegramPort: j['telegramPort'] as int? ?? d.telegramPort,
      telegramSecret: _validSecret(secret)\n          ? secret as String\n          : d.telegramSecret,
      connectOnLaunch: j['connectOnLaunch'] as bool? ?? d.connectOnLaunch,
    );
  }

  static Settings load(String file) {
    try {
      final j = jsonDecode(File(file).readAsStringSync());
      if (j is Map<String, Object?>) {
        final settings = fromJson(j);
        if (!_validSecret(j['telegramSecret'])) {
          try {
            settings.save(file);
          } catch (_) {}
        }
        return settings;
      }
    } catch (_) {}

    // The Telegram proxy secret is part of the client configuration. Persist a
    // generated default immediately so a restart cannot silently rotate it.
    final defaults = Settings.defaults();
    try {
      defaults.save(file);
    } catch (_) {
      // Startup must still work if the settings directory is temporarily
      // unwritable. A later explicit settings change will retry the save.
    }
    return defaults;
  }

  void save(String file) {
    final tmp = File('$file.tmp')
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(toJson()));
    tmp.renameSync(file);
  }
}
