import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prosvet/src/platform/autostart.dart';
import 'package:prosvet/src/platform/shell.dart';

class _FakeShell implements Shell {
  final calls = <({String executable, List<String> args})>[];
  final Map<String, ShellResult> results = {};

  @override
  Future<ShellResult> run(String executable, List<String> args) async {
    calls.add((executable: executable, args: List.of(args)));
    return results['$executable ${args.join(' ')}'] ??
        const ShellResult(0, '', '');
  }

  @override
  Future<ShellResult> powershell(String script) async {
    throw UnimplementedError();
  }
}

class _BlockingShell extends _FakeShell {
  final gates = <Completer<void>>[];

  @override
  Future<ShellResult> run(String executable, List<String> args) async {
    calls.add((executable: executable, args: List.of(args)));
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return const ShellResult(0, '', '');
  }
}

void main() {
  test(
    'autostart creates one elevated background task with quoted exe',
    () async {
      final shell = _FakeShell();
      const exe = r'C:\Program Files\Prosvet\prosvet.exe';
      final autostart = Autostart(shell, exe);

      await autostart.setEnabled(true);

      expect(shell.calls, hasLength(1));
      expect(shell.calls.single.executable, 'schtasks.exe');
      expect(shell.calls.single.args, [
        '/Create',
        '/TN',
        'Prosvet',
        '/TR',
        '"$exe" --background',
        '/SC',
        'ONLOGON',
        '/RL',
        'HIGHEST',
        '/F',
      ]);
    },
  );

  test('autostart writes are serialized in click order', () async {
    final shell = _BlockingShell();
    final autostart = Autostart(shell, r'C:\Prosvet\prosvet.exe');

    final enable = autostart.setEnabled(true);
    await pumpEventQueue();
    expect(shell.calls, hasLength(1));

    final disable = autostart.setEnabled(false);
    await pumpEventQueue();
    expect(shell.calls, hasLength(1));

    shell.gates[0].complete();
    await pumpEventQueue();
    expect(shell.calls, hasLength(2));
    expect(shell.calls[1].args, ['/Delete', '/TN', 'Prosvet', '/F']);

    shell.gates[1].complete();
    await Future.wait([enable, disable]);
  });

  test('autostart deletion removes the same scheduled task', () async {
    final shell = _FakeShell();
    final autostart = Autostart(shell, r'C:\Prosvet\prosvet.exe');

    await autostart.setEnabled(false);

    expect(shell.calls.single.executable, 'schtasks.exe');
    expect(shell.calls.single.args, ['/Delete', '/TN', 'Prosvet', '/F']);
  });

  test('autostart surfaces Task Scheduler errors', () async {
    final shell = _FakeShell();
    shell.results['schtasks.exe /Delete /TN Prosvet /F'] = const ShellResult(
      1,
      '',
      'access denied',
    );
    final autostart = Autostart(shell, r'C:\Prosvet\prosvet.exe');

    expect(
      () => autostart.setEnabled(false),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', 'access denied'),
      ),
    );
  });
}
