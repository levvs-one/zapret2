import 'dart:async';

import 'shell.dart';

/// Starts Prosvet at logon with administrator rights through Task Scheduler,
/// so there is no UAC prompt on every boot.
class Autostart {
  Autostart(this._shell, this._exe);

  final Shell _shell;
  final String _exe;
  Future<void> _writes = Future<void>.value();

  static const taskName = 'Prosvet';

  Future<bool> isEnabled() async =>
      (await _shell.run('schtasks.exe', ['/Query', '/TN', taskName])).ok;

  Future<void> setEnabled(bool on) {
    final done = Completer<void>();
    _writes = _writes.then((_) async {
      try {
        await _setEnabledNow(on);
        done.complete();
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  Future<void> _setEnabledNow(bool on) async {
    final r = on
        ? await _shell.run('schtasks.exe', [
            '/Create',
            '/TN',
            taskName,
            '/TR',
            '"$_exe" --background',
            '/SC',
            'ONLOGON',
            '/RL',
            'HIGHEST',
            '/F',
          ])
        : await _shell.run('schtasks.exe', ['/Delete', '/TN', taskName, '/F']);
    if (!r.ok) {
      throw StateError(
        r.stderr.trim().isEmpty ? r.stdout.trim() : r.stderr.trim(),
      );
    }
  }
}
