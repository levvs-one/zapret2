import 'package:flutter_test/flutter_test.dart';
import 'package:prosvet/src/catalog/services.dart';
import 'package:prosvet/src/engine/smartdns/nrpt.dart';
import 'package:prosvet/src/engine/smartdns/provider.dart';

void main() {
  test('Xbox DNS endpoints match the published IPv4 pair', () {
    expect(SmartDnsProvider.xboxDns.servers, ['111.88.96.54', '111.88.96.55']);
  });

  test('every domain covers itself and subdomains', () {
    expect(nrptNamespaces(['Claude.ai ']), ['.claude.ai', 'claude.ai']);
  });

  test('catalog domains are valid', () {
    for (final s in Catalog.all.where(
      (s) => s.mechanism == Mechanism.smartDns,
    )) {
      expect(s.domains, isNotEmpty, reason: s.id);
      expect(() => nrptNamespaces(s.domains), returnsNormally, reason: s.id);
    }
  });

  test('rejects injection in domains and servers', () {
    expect(() => nrptNamespaces(["a.com'; rm"]), throwsArgumentError);
    expect(
      () => nrptApplyScript(domains: ['a.com'], servers: ['1.2.3.4; x']),
      throwsArgumentError,
    );
    expect(
      () => nrptApplyScript(domains: ['a.com'], servers: ['1.2.3.256']),
      throwsArgumentError,
    );
  });

  test('apply replaces tagged rules and flushes cache', () {
    final s = nrptApplyScript(domains: ['a.com'], servers: ['1.1.1.1']);
    final lines = s.split('\n');
    expect(lines[1], contains("Comment -eq 'Prosvet'"));
    expect(
      lines[2],
      "Add-DnsClientNrptRule -Namespace @('.a.com','a.com') -NameServers @('1.1.1.1') "
      "-Comment 'Prosvet' | Out-Null",
    );
    expect(lines.last, 'Clear-DnsClientCache');
  });
}
