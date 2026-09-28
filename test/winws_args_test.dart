import 'package:flutter_test/flutter_test.dart';
import 'package:prosvet/src/engine/zapret/strategies.dart';
import 'package:prosvet/src/engine/zapret/winws_args.dart';

void main() {
  const launch = WinwsLaunch(
    engineDir: r'C:\Prosvet\engine',
    stateDir: r'C:\Users\u\AppData\Local\Prosvet',
    networkKey: 'abc123',
    youtube: true,
    discord: true,
  );

  test('strategies are numbered from 1 without gaps', () {
    final args = buildWinwsArgs(launch);
    final numbers = {
      for (final a in args)
        if (RegExp(r':strategy=(\d+)$').firstMatch(a) case final m?)
          int.parse(m[1]!),
    };
    expect(numbers, {for (var i = 1; i <= tlsStrategies.length; i++) i});
  });

  test('uses engine paths and per-network memory', () {
    final args = buildWinwsArgs(launch);
    expect(args, contains(r'--hostlist=C:\Prosvet\engine\lists\youtube.txt'));
    expect(args, contains(r'--lua-init=@C:\Prosvet\engine\lua\prosvet.lua'));
    expect(
      args,
      contains(
        '--lua-desync=prosvet_circular:fails=3:nld=2:memo=v${strategyCatalogVersion}_abc123',
      ),
    );
    expect(args.where((a) => a.startsWith('--new')), hasLength(3));
  });

  test('discord voice profile only with discord', () {
    final yt = buildWinwsArgs(
      const WinwsLaunch(
        engineDir: 'e',
        stateDir: 's',
        networkKey: 'k',
        youtube: true,
        discord: false,
      ),
    );
    expect(yt.any((a) => a.contains('discord')), isFalse);
  });

  test('refuses an empty launch', () {
    expect(
      () => buildWinwsArgs(
        const WinwsLaunch(
          engineDir: 'e',
          stateDir: 's',
          networkKey: 'k',
          youtube: false,
          discord: false,
        ),
      ),
      throwsArgumentError,
    );
  });
}
