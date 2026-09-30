import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha1.dart';

import 'byte_reader.dart';

class WsHandshakeException implements Exception {
  WsHandshakeException(this.status, this.statusLine);
  final int status;
  final String statusLine;

  bool get isRedirect => status >= 300 && status < 400;

  @override
  String toString() => 'WebSocket handshake failed: $statusLine';
}

class WsProtocolException implements Exception {
  WsProtocolException(this.message);
  final String message;

  @override
  String toString() => 'WebSocket protocol error: $message';
}

/// Minimal binary WebSocket client (RFC 6455) over a socket we own. It lets
/// us connect to a fixed IP while sending the real domain in SNI and Host.
class WsClient {
  WsClient._(this._socket, this._reader, this._rnd);

  static const _guid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
  static const _maxFrameBytes = 16 * 1024 * 1024;

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

      final lines = latin1
          .decode(head)
          .split('\r\n')
          .where((line) => line.isNotEmpty)
          .toList();
      final statusLine = lines.isEmpty ? '' : lines.first;
      final status =
          int.tryParse(statusLine.split(' ').elementAtOrNull(1) ?? '') ?? 0;
      if (status != 101) throw WsHandshakeException(status, statusLine);

      final headers = <String, String>{};
      for (final line in lines.skip(1)) {
        final colon = line.indexOf(':');
        if (colon <= 0) continue;
        headers[line.substring(0, colon).trim().toLowerCase()] = line
            .substring(colon + 1)
            .trim();
      }

      final upgrade = headers['upgrade']?.toLowerCase();
      final connection = headers['connection']
          ?.toLowerCase()
          .split(',')
          .map((v) => v.trim());
      final accept = headers['sec-websocket-accept'];
      final protocol = headers['sec-websocket-protocol']?.toLowerCase();
      final expectedAccept = base64.encode(
        SHA1Digest().process(Uint8List.fromList(ascii.encode('$key$_guid'))),
      );
      if (upgrade != 'websocket' ||
          connection == null ||
          !connection.contains('upgrade') ||
          accept != expectedAccept ||
          (protocol != null && protocol != 'binary')) {
        throw WsHandshakeException(status, 'invalid WebSocket upgrade');
      }
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
    if (payload.length > _maxFrameBytes) {
      throw WsProtocolException('outgoing frame is too large');
    }
    _socket.add(encodeFrame(_opBinary, payload, _rnd));
  }

  /// Binary messages until the peer closes the connection.
  Stream<Uint8List> messages() async* {
    final fragments = BytesBuilder(copy: false);
    var fragmented = false;

    void addFragment(Uint8List payload) {
      if (fragments.length + payload.length > _maxFrameBytes) {
        throw WsProtocolException('fragmented message is too large');
      }
      fragments.add(payload);
    }

    try {
      while (!_closed) {
        final h = await _reader.read(2);
        if (h == null) break;

        final fin = h[0] & 0x80 != 0;
        final rsv = h[0] & 0x70;
        final op = h[0] & 0x0f;
        final masked = h[1] & 0x80 != 0;
        if (rsv != 0) throw WsProtocolException('unexpected RSV bits');
        if (masked) throw WsProtocolException('server frame is masked');

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
        if (len > _maxFrameBytes) {
          throw WsProtocolException('incoming frame is too large');
        }

        final isControl = op >= _opClose;
        if (isControl && (!fin || len > 125)) {
          throw WsProtocolException('invalid control frame');
        }
        if (op == _opCont && !fragmented) {
          throw WsProtocolException('unexpected continuation frame');
        }
        if (op == _opBinary && fragmented) {
          throw WsProtocolException('new data frame during fragmentation');
        }
        if (op != _opCont &&
            op != _opBinary &&
            op != _opClose &&
            op != _opPing &&
            op != _opPong) {
          throw WsProtocolException('unsupported opcode $op');
        }

        final payload = len == 0 ? Uint8List(0) : await _reader.read(len);
        if (payload == null) break;

        switch (op) {
          case _opClose:
            if (!_closed) {
              _socket.add(
                encodeFrame(
                  _opClose,
                  payload.length >= 2 ? payload.sublist(0, 2) : Uint8List(0),
                  _rnd,
                ),
              );
            }
            _closed = true;
          case _opPing:
            _socket.add(encodeFrame(_opPong, payload, _rnd));
          case _opPong:
            break;
          case _opBinary:
            if (fin) {
              yield payload;
            } else {
              addFragment(payload);
              fragmented = true;
            }
          case _opCont:
            addFragment(payload);
            if (fin) {
              fragmented = false;
              yield fragments.takeBytes();
            }
        }
      }
    } finally {
      await close();
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
