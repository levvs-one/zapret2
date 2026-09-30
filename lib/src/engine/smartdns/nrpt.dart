/// Windows Name Resolution Policy Table rules.
///
/// NRPT sends queries for selected namespaces to selected DNS servers and
/// leaves the rest of the system resolver untouched. Rules created by
/// Prosvet are tagged with [nrptComment], so they can always be found and
/// removed, including after a crash.
library;

const nrptComment = 'Prosvet';

String _psQuote(String s) => "'${s.replaceAll("'", "''")}'";

String _psArray(Iterable<String> items) =>
    '@(${items.map(_psQuote).join(',')})';

final _domainRe = RegExp(r'^(?!-)[a-z0-9-]{1,63}(\.[a-z0-9-]{1,63})+$');
final _ipv4Re = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');

/// Every domain becomes two namespaces: the domain itself and `.domain`,
/// which matches all of its subdomains.
List<String> nrptNamespaces(Iterable<String> domains) {
  final out = <String>{};
  for (final raw in domains) {
    final d = raw.trim().toLowerCase();
    if (!_domainRe.hasMatch(d)) {
      throw ArgumentError.value(raw, 'domain');
    }
    out
      ..add(d)
      ..add('.$d');
  }
  return out.toList()..sort();
}

String nrptRemoveScript() =>
    'Get-DnsClientNrptRule | Where-Object { \$_.Comment -eq ${_psQuote(nrptComment)} } '
    '| ForEach-Object { Remove-DnsClientNrptRule -Name \$_.Name -Force }';

String nrptApplyScript({
  required Iterable<String> domains,
  required List<String> servers,
}) {
  for (final s in servers) {
    final m = _ipv4Re.firstMatch(s);
    if (m == null || m.groups([1, 2, 3, 4]).any((g) => int.parse(g!) > 255)) {
      throw ArgumentError.value(s, 'server');
    }
  }
  final namespaces = nrptNamespaces(domains);
  return [
    r"$ErrorActionPreference = 'Stop'",
    nrptRemoveScript(),
    if (namespaces.isNotEmpty)
      'Add-DnsClientNrptRule -Namespace ${_psArray(namespaces)} '
          '-NameServers ${_psArray(servers)} -Comment ${_psQuote(nrptComment)} | Out-Null',
    'Clear-DnsClientCache',
  ].join('\n');
}

String nrptClearScript() => [
  r"$ErrorActionPreference = 'Stop'",
  nrptRemoveScript(),
  'Clear-DnsClientCache',
].join('\n');
