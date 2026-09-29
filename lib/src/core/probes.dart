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

Future<bool> _smartDnsActive(Service s, List<String> dnsServers) async {
  if (s.domains.isEmpty) return false;
  final domain = s.domains.first;

  // First ask the provider directly, then resolve the same name through the
  // operating system. NRPT is only considered active when the system resolver
  // returns at least one address supplied by the configured Smart DNS.
  for (final server in dnsServers) {
    final providerAnswers = await queryDnsServer(server, domain);
    if (providerAnswers == null || providerAnswers.isEmpty) continue;
    try {
      final systemAnswers = await InternetAddress.lookup(
        domain,
        type: InternetAddressType.IPv4,
      ).timeout(const Duration(seconds: 5));
      if (systemAnswers.any((a) => providerAnswers.contains(a.address))) {
        return true;
      }
    } catch (_) {
      // Try the next provider address.
    }
  }
  return false;
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
      return _smartDnsActive(s, dnsServers);
    case Mechanism.telegram:
      return telegramRunning();
  }
}
