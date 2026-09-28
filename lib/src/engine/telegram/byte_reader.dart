import 'dart:async';
import 'dart:typed_data';

/// Pull-style reader over a byte stream.
class ByteReader {
  ByteReader(Stream<Uint8List> source) : _it = StreamIterator(source);

  final StreamIterator<Uint8List> _it;
  final _buf = BytesBuilder(copy: false);

  /// Reads exactly [n] bytes or returns null if the stream ended first.
  Future<Uint8List?> read(int n) async {
    while (_buf.length < n) {
      if (!await _it.moveNext()) return null;
      _buf.add(_it.current);
    }
    final all = _buf.takeBytes();
    if (all.length > n) _buf.add(Uint8List.sublistView(all, n));
    return Uint8List.sublistView(all, 0, n);
  }

  /// Reads up to and including [delimiter], at most [limit] bytes.
  Future<Uint8List?> readUntil(List<int> delimiter, {int limit = 16384}) async {
    var scanned = 0;
    while (true) {
      final all = _buf.takeBytes();
      _buf.add(all);
      for (var i = scanned; i + delimiter.length <= all.length; i++) {
        var match = true;
        for (var j = 0; j < delimiter.length; j++) {
          if (all[i + j] != delimiter[j]) {
            match = false;
            break;
          }
        }
        if (match) return read(i + delimiter.length);
      }
      scanned = all.length < delimiter.length
          ? 0
          : all.length - delimiter.length + 1;
      if (all.length > limit) return null;
      if (!await _it.moveNext()) return null;
      _buf.add(_it.current);
    }
  }

  /// Everything buffered and everything that arrives later.
  Stream<Uint8List> rest() async* {
    final pending = _buf.takeBytes();
    if (pending.isNotEmpty) yield pending;
    while (await _it.moveNext()) {
      yield _it.current;
    }
  }

  Future<void> cancel() => _it.cancel();
}
