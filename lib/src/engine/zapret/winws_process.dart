import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Owns one winws2.exe process.
class WinwsProcess {
  WinwsProcess({required this.executable, this.onLog});

  final String executable;
  final void Function(String)? onLog;

  Process? _process;
  final _tail = <String>[];
  final _exited = StreamController<int>.broadcast();

  bool get isRunning => _process != null;

  /// Fires with the exit code when the process stops on its own.
  Stream<int> get unexpectedExit => _exited.stream;

  /// Last lines of output, for error messages.
  String get tail => _tail.join('\n');

  Future<void> start(
    List<String> args, {
    required String workingDirectory,
  }) async {
    if (_process != null) return;
    if (!File(executable).existsSync()) {
      throw StateError('Не найден движок: $executable');
    }
    _tail.clear();
    final p = await Process.start(
      executable,
      args,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.normal,
    );
    _process = p;
    void collect(String line) {
      _tail.add(line);
      if (_tail.length > 40) _tail.removeAt(0);
      onLog?.call('winws2: $line');
    }

    p.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(collect);
    p.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(collect);

    final early = await p.exitCode.timeout(
      const Duration(milliseconds: 1500),
      onTimeout: () => -1,
    );
    if (early != -1) {
      _process = null;
      throw StateError('Движок завершился с кодом $early\n$tail');
    }
    unawaited(
      p.exitCode.then((code) {
        if (identical(_process, p)) {
          _process = null;
          _exited.add(code);
        }
      }),
    );
  }

  Future<void> stop() async {
    final p = _process;
    _process = null;
    if (p == null) return;
    p.kill();
    await p.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        p.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  }
}
