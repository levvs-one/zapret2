import 'dart:async';
import 'dart:io';

import '../catalog/services.dart';
import '../engine/smartdns/dns_probe.dart';

/// Endpoints that answer quickly and without authentication.
const _httpProbes = <String, List<String>>{
  'youtube': [
    'https://www.youtube.com/generate_204',
    'https://redirector.googlevideo.com/report_mapping',
  ],
  'discord': [
    'https://discord.com/api/v10/gateway',
    'https://gateway.discord.gg/',
  ],
};

Future<bool> _httpOk(HttpClient client, String url) async {
  try {
    final req = await client.getUrl(Uri.parse(url));
    req.followRedirects = false;
    final res = await req.close().timeout(const Duration(seconds: 6));
    await res.drain<void>();
    // Any HTTP answer means the TLS handshake got through DPI.
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> probeService(
  Service s, {
  required List<String> dnsServers,
  required bool Function() telegramRunning,
}) async {
  switch (s.mechanism) {
    case Mechanism.dpi:
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5)
        ..userAgent = 'Mozilla/5.0';
      try {
        final r = await Future.wait(
          _httpProbes[s.id]!.map((u) => _httpOk(client, u)),
        );
        return r.every((ok) => ok);
      } finally {
        client.close(force: true);
      }
    case Mechanism.smartDns:
      for (final server in dnsServers) {
        if (await probeDnsServer(server, s.domains.first)) return true;
      }
      return false;
    case Mechanism.telegram:
      return telegramRunning();
  }
}
