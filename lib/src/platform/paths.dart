import 'dart:io';

import 'package:path/path.dart' as p;

class AppPaths {
  const AppPaths({required this.engineDir, required this.stateDir});

  /// Bundled next to the executable by the installer or CI.
  final String engineDir;

  /// %LOCALAPPDATA%\Prosvet: settings, strategy memory, logs.
  final String stateDir;

  String get settingsFile => p.join(stateDir, 'settings.json');
  String get logFile => p.join(stateDir, 'prosvet.log');
  String get winws => p.join(engineDir, 'winws2.exe');

  static AppPaths resolve() {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final base =
        Platform.environment['LOCALAPPDATA'] ??
        p.join(Platform.environment['HOME'] ?? exeDir, '.local', 'share');
    final state = p.join(base, 'Prosvet');
    Directory(state).createSync(recursive: true);
    return AppPaths(engineDir: p.join(exeDir, 'engine'), stateDir: state);
  }
}
