import 'shell.dart';

/// FNV-1a, stable across runs and platforms.
String stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

/// Identifies the network behind the default route: interface alias and
/// gateway MAC. Changes when the user moves to another Wi-Fi or provider.
Future<String> currentNetworkKey(Shell shell) async {
  const script = r'''
$r = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
  Sort-Object { $_.RouteMetric + $_.InterfaceMetric } | Select-Object -First 1
if ($r) {
  $n = Get-NetNeighbor -IPAddress $r.NextHop -ErrorAction SilentlyContinue | Select-Object -First 1
  "$($r.InterfaceAlias)|$($r.NextHop)|$($n.LinkLayerAddress)"
}
''';
  final r = await shell.powershell(script);
  final id = r.stdout.trim();
  return stableHash(id.isEmpty ? 'unknown' : id);
}
