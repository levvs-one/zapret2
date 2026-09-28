import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'byte_reader.dart';

class WsHandshakeException implements Exception {
  WsHandshakeException(this.status, this.statusLine);
  final int status;
  final String statusLine;

  bool get isRedirect => status >= 300 && status < 400;

  @override
  String toString() => 'WebSocket handshake failed: $statusLine';
}

/// Minimal binary WebSocket client (RFC 6455) over a socket we own. It lets
/// us connect to a fixed IP while sending the real domain in SNI and Host.
class WsClient {
  WsClient._(this._socket, this._reader, this._rnd);

  final Socket _socket;
  final ByteReader _reader;
  final Random _rnd;
  bool _closed = false;

  static Future<WsClient> connect({
    required String ip,
    required String domain,
    String path = '/apiws',
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final raw = await Socket.connect(ip, 443, timeout: timeout);
    raw.setOption(SocketOption.tcpNoDelay, true);
    final SecureSocket tls;
    try {
      tls = await SecureSocket.secure(raw, host: domain).timeout(timeout);
    } catch (_) {
      raw.destroy();
      rethrow;
    }
    final rnd = Random.secure();
    final key = base64.encode(List.generate(16, (_) => rnd.nextInt(256)));
    tls.add(
      ascii.encode(
        'GET $path HTTP/1.1\r\n'
        'Host: $domain\r\n'
        'Upgrade: websocket\r\n'
        'Connection: Upgrade\r\n'
        'Sec-WebSocket-Key: $key\r\n'
        'Sec-WebSocket-Version: 13\r\n'
        'Sec-WebSocket-Protocol: binary\r\n'
        '\r\n',
      ),
    );
    final reader = ByteReader(tls);
    try {
      final head = await reader
          .readUntil(const [13, 10, 13, 10])
          .timeout(timeout);
      if (head == null) throw WsHandshakeException(0, 'no response');
      final statusLine = latin1.decode(head).split('\r\n').first;
      final status =
          int.tryParse(statusLine.split(' ').elementAtOrNull(1) ?? '') ?? 0;
      if (status != 101) throw WsHandshakeException(status, statusLine);
    } catch (_) {
      tls.destroy();
      rethrow;
    }
    return WsClient._(tls, reader, rnd);
  }

  static const _opCont = 0x0;
  static const _opBinary = 0x2;
  static const _opClose = 0x8;
  static const _opPing = 0x9;
  static const _opPong = 0xa;

  void send(Uint8List payload) {
    if (_closed) throw const SocketException('WebSocket closed');
    _socket.add(encodeFrame(_opBinary, payload, _rnd));
  }

  /// Binary messages until the peer closes the connection.
  Stream<Uint8List> messages() async* {
    final fragments = BytesBuilder(copy: false);
    while (!_closed) {
      final h = await _reader.read(2);
      if (h == null) break;
      final fin = h[0] & 0x80 != 0;
      final op = h[0] & 0x0f;
      var len = h[1] & 0x7f;
      if (len == 126) {
        final e = await _reader.read(2);
        if (e == null) break;
        len = e[0] << 8 | e[1];
      } else if (len == 127) {
        final e = await _reader.read(8);
        if (e == null) break;
        len = ByteData.sublistView(e).getUint64(0);
      }
      Uint8List? mask;
      if (h[1] & 0x80 != 0) {
        mask = await _reader.read(4);
        if (mask == null) break;
      }
      final payload = len == 0 ? Uint8List(0) : await _reader.read(len);
      if (payload == null) break;
      if (mask != null) {
        final data = Uint8List.fromList(payload);
        for (var i = 0; i < data.length; i++) {
          data[i] ^= mask[i & 3];
        }
        yield* _handle(op, fin, data, fragments);
      } else {
        yield* _handle(op, fin, payload, fragments);
      }
    }
    await close();
  }

  Stream<Uint8List> _handle(
    int op,
    bool fin,
    Uint8List data,
    BytesBuilder fragments,
  ) async* {
    switch (op) {
      case _opClose:
        if (!_closed) {
          _socket.add(
            encodeFrame(
              _opClose,
              data.length >= 2 ? data.sublist(0, 2) : Uint8List(0),
              _rnd,
            ),
          );
        }
        _closed = true;
      case _opPing:
        _socket.add(encodeFrame(_opPong, data, _rnd));
      case _opPong:
        break;
      case _opBinary:
      case _opCont:
      default:
        fragments.add(data);
        if (fin) yield fragments.takeBytes();
    }
  }

  Future<void> close() async {
    _closed = true;
    try {
      await _socket.close();
    } catch (_) {}
    _socket.destroy();
  }

  /// Client frame, always masked.
  static Uint8List encodeFrame(int op, Uint8List payload, Random rnd) {
    final len = payload.length;
    final b = BytesBuilder(copy: false)..addByte(0x80 | op);
    if (len < 126) {
      b.addByte(0x80 | len);
    } else if (len < 65536) {
      b.add([0x80 | 126, len >> 8, len & 0xff]);
    } else {
      final e = ByteData(8)..setUint64(0, len);
      b
        ..addByte(0x80 | 127)
        ..add(e.buffer.asUint8List());
    }
    final mask = Uint8List.fromList(List.generate(4, (_) => rnd.nextInt(256)));
    b.add(mask);
    final masked = Uint8List(len);
    for (var i = 0; i < len; i++) {
      masked[i] = payload[i] ^ mask[i & 3];
    }
    b.add(masked);
    return b.toBytes();
  }
}
