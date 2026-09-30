// Prints the winws2 command line for tools/verify-engine-args.sh.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prosvet/src/engine/zapret/winws_args.dart';

void main() {
  test('dump winws2 arguments', () {
    final dir = Platform.environment['ENGINE_DIR']!;
    final args = buildWinwsArgs(
      WinwsLaunch(
        engineDir: dir,
        stateDir: '$dir/state',
        networkKey: 'ci',
        youtube: true,
        discord: true,
      ),
    );
    print('ARGS\t${args.join('\t')}');
  });
}
