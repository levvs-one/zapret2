import 'package:path/path.dart' as p;

import 'strategies.dart';

/// Inputs for one winws2 launch.
class WinwsLaunch {
  const WinwsLaunch({
    required this.engineDir,
    required this.stateDir,
    required this.networkKey,
    required this.youtube,
    required this.discord,
  });

  /// Directory with winws2.exe, lua/, lists/ and windivert/.
  final String engineDir;

  /// Writable directory for strategy memory.
  final String stateDir;

  /// Identifies the current network, [A-Za-z0-9] only.
  final String networkKey;

  final bool youtube;
  final bool discord;

  bool get isEmpty => !youtube && !discord;
}

/// Builds the winws2 command line. Pure function, see test/winws_args_test.dart.
List<String> buildWinwsArgs(WinwsLaunch l) {
  if (l.isEmpty) {
    throw ArgumentError('nothing to unblock');
  }
  final path = p.windows;
  String engine(String a, [String? b]) => path.join(l.engineDir, a, b);

  final hostlists = [
    if (l.youtube) '--hostlist=${engine('lists', 'youtube.txt')}',
    if (l.discord) '--hostlist=${engine('lists', 'discord.txt')}',
  ];
  final memo = 'v${strategyCatalogVersion}_${l.networkKey}';

  final args = <String>[
    '--wf-tcp-out=80,443',
    '--wf-udp-out=443',
    if (l.discord) ...[
      '--wf-raw-part=@${engine('windivert', 'windivert_part.discord_media.txt')}',
      '--wf-raw-part=@${engine('windivert', 'windivert_part.stun.txt')}',
    ],
    '--writable=${l.stateDir}',
    for (final lua in [
      'zapret-lib.lua',
      'zapret-antidpi.lua',
      'zapret-auto.lua',
      'prosvet.lua',
    ])
      '--lua-init=@${engine('lua', lua)}',

    // TLS: rotate strategies per registrable domain until one gets through.
    '--name=tls',
    '--filter-tcp=443',
    '--filter-l7=tls',
    ...hostlists,
    '--out-range=-s34228',
    '--in-range=-s5556',
    '--lua-desync=prosvet_circular:fails=3:nld=2:memo=$memo',
    '--in-range=x',
    '--payload=tls_client_hello',
    for (var i = 0; i < tlsStrategies.length; i++)
      for (final action in tlsStrategies[i])
        '--lua-desync=$action:strategy=${i + 1}',

    '--new=http',
    '--filter-tcp=80',
    '--filter-l7=http',
    ...hostlists,
    '--payload=http_req',
    '--lua-desync=fake:blob=fake_default_http:tcp_md5',
    '--lua-desync=multisplit:pos=method+2',

    '--new=quic',
    '--filter-udp=443',
    '--filter-l7=quic',
    ...hostlists,
    '--payload=quic_initial',
    '--lua-desync=fake:blob=fake_default_quic:repeats=6',

    if (l.discord) ...[
      '--new=discord_voice',
      '--filter-l7=discord,stun',
      '--payload=stun,discord_ip_discovery',
      '--lua-desync=fake:blob=0x00000000000000000000000000000000:repeats=6',
    ],
  ];
  return args;
}
