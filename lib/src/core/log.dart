import 'dart:io';

/// Append-only diagnostic log, trimmed on start.
class Log {
  Log(this.path) {
    final f = File(path);
    if (f.existsSync() && f.lengthSync() > 1 << 20) f.deleteSync();
  }

  final String path;

  void write(String line) {
    final t = DateTime.now().toIso8601String().substring(0, 19);
    try {
      File(path)
          .writeAsStringSync('$t $line\n', mode: FileMode.append, flush: false);
    } catch (_) {}
  }
}
