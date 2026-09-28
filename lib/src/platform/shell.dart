import 'dart:convert';
import 'dart:io';

/// Result of a finished command.
class ShellResult {
  const ShellResult(this.exitCode, this.stdout, this.stderr);
  final int exitCode;
  final String stdout;
  final String stderr;

  bool get ok => exitCode == 0;
}

/// Runs system commands. Replaced by a fake in tests.
abstract interface class Shell {
  Future<ShellResult> run(String executable, List<String> args);

  Future<ShellResult> powershell(String script);
}

class SystemShell implements Shell {
  const SystemShell();

  @override
  Future<ShellResult> run(String executable, List<String> args) async {
    final r = await Process.run(
      executable,
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    return ShellResult(r.exitCode, r.stdout as String, r.stderr as String);
  }

  @override
  Future<ShellResult> powershell(String script) {
    // -EncodedCommand avoids every quoting problem of -Command.
    final bytes = <int>[];
    for (final unit in script.codeUnits) {
      bytes
        ..add(unit & 0xff)
        ..add(unit >> 8);
    }
    return run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-EncodedCommand',
      base64.encode(bytes),
    ]);
  }
}
