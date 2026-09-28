import 'dart:typed_data';

import 'obfuscated2.dart';

/// Splits the encrypted upstream byte stream into whole MTProto transport
/// packets so each one travels in its own WebSocket frame, as Telegram's
/// WebSocket endpoint expects.
///
/// Ported from Flowseal/tg-ws-proxy (MIT).
class MsgSplitter {
  MsgSplitter(Uint8List relayInit, this._proto)
    : _dec = AesCtr(relayInit.sublist(8, 40), relayInit.sublist(40, 56))
        ..skip(handshakeLen);

  static const maxPacketBytes = 16 * 1024 * 1024;

  final AesCtr _dec;
  final ProtoTag _proto;
  final _cipher = BytesBuilder(copy: false);
  final _plain = BytesBuilder(copy: false);
  bool _disabled = false;

  List<Uint8List> split(Uint8List chunk) {
    if (chunk.isEmpty) return const [];
    if (_disabled) return [chunk];
    _cipher.add(chunk);
    _plain.add(_dec.process(chunk));

    final cipher = _cipher.takeBytes();
    final plain = _plain.takeBytes();
    final parts = <Uint8List>[];
    var offset = 0;
    while (offset < cipher.length) {
      final len = _nextLen(plain, offset, cipher.length - offset);
      if (len == null) break;
      if (len <= 0) {
        parts.add(Uint8List.sublistView(cipher, offset));
        offset = cipher.length;
        _disabled = true;
        break;
      }
      parts.add(Uint8List.sublistView(cipher, offset, offset + len));
      offset += len;
    }
    if (offset < cipher.length) {
      final remaining = cipher.length - offset;
      if (remaining > maxPacketBytes + 4) {
        throw StateError('MTProto packet exceeds safety limit');
      }
      _cipher.add(Uint8List.sublistView(cipher, offset));
      _plain.add(Uint8List.sublistView(plain, offset));
    }
    return parts;
  }

  Uint8List? flush() {
    _plain.clear();
    final tail = _cipher.takeBytes();
    return tail.isEmpty ? null : tail;
  }

  int? _nextLen(Uint8List p, int o, int avail) {
    if (avail <= 0) return null;
    switch (_proto) {
      case ProtoTag.abridged:
        final first = p[o];
        int payload;
        int header;
        if (first == 0x7f || first == 0xff) {
          if (avail < 4) return null;
          payload = (p[o + 1] | p[o + 2] << 8 | p[o + 3] << 16) * 4;
          header = 4;
        } else {
          payload = (first & 0x7f) * 4;
          header = 1;
        }
        if (payload <= 0) return 0;
        if (payload > maxPacketBytes) {
          throw StateError('MTProto packet exceeds safety limit');
        }
        return avail < header + payload ? null : header + payload;
      case ProtoTag.intermediate:
      case ProtoTag.paddedIntermediate:
        if (avail < 4) return null;
        final payload =
            (p[o] | p[o + 1] << 8 | p[o + 2] << 16 | p[o + 3] << 24) &
            0x7fffffff;
        if (payload <= 0) return 0;
        if (payload > maxPacketBytes) {
          throw StateError('MTProto packet exceeds safety limit');
        }
        return avail < 4 + payload ? null : 4 + payload;
    }
  }
}
