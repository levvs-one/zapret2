/// MTProto "obfuscated2" transport: the 64-byte init packet and the four
/// AES-256-CTR streams a relaying proxy needs.
///
/// Ported from Flowseal/tg-ws-proxy (MIT).
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

const handshakeLen = 64;
const _skipLen = 8;
const _prekeyLen = 32;
const _ivLen = 16;
const _protoTagPos = 56;
const _dcIdxPos = 60;

enum ProtoTag {
  abridged(0xef),
  intermediate(0xee),
  paddedIntermediate(0xdd);

  const ProtoTag(this.byte);
  final int byte;

  Uint8List get bytes => Uint8List.fromList([byte, byte, byte, byte]);

  static ProtoTag? parse(Uint8List b, int offset) {
    for (final t in values) {
      if (b[offset] == t.byte &&
          b[offset + 1] == t.byte &&
          b[offset + 2] == t.byte &&
          b[offset + 3] == t.byte) {
        return t;
      }
    }
    return null;
  }
}

class AesCtr {
  AesCtr(Uint8List key, Uint8List iv)
    : _c = CTRStreamCipher(AESEngine())
        ..init(true, ParametersWithIV(KeyParameter(key), iv));

  final CTRStreamCipher _c;

  Uint8List process(Uint8List data) => _c.process(data);

  void skip(int n) => _c.process(Uint8List(n));
}

Uint8List _sha256(List<int> a, List<int> b) =>
    SHA256Digest().process(Uint8List.fromList([...a, ...b]));

Uint8List _reversed(Uint8List b) => Uint8List.fromList(b.reversed.toList());

class ClientInit {
  const ClientInit({
    required this.dc,
    required this.isMedia,
    required this.isTest,
    required this.proto,
    required this.prekeyAndIv,
  });

  final int dc;
  final bool isMedia;
  final bool isTest;
  final ProtoTag proto;
  final Uint8List prekeyAndIv;

  int get dcIdx => isMedia ? -dc : dc;
}

/// Decrypts a client init packet made for a proxy with [secret].
/// Returns null if the secret or the protocol does not match.
ClientInit? parseClientInit(Uint8List handshake, Uint8List secret) {
  if (handshake.length != handshakeLen) return null;
  final prekeyAndIv = Uint8List.sublistView(
    handshake,
    _skipLen,
    _skipLen + _prekeyLen + _ivLen,
  );
  final key = _sha256(prekeyAndIv.sublist(0, _prekeyLen), secret);
  final iv = prekeyAndIv.sublist(_prekeyLen);
  final plain = AesCtr(key, iv).process(handshake);
  final proto = ProtoTag.parse(plain, _protoTagPos);
  if (proto == null) return null;
  var dc = ByteData.sublistView(plain).getInt16(_dcIdxPos, Endian.little);
  final isMedia = dc < 0;
  dc = dc.abs();
  final isTest = dc >= 10000;
  if (isTest) dc -= 10000;
  return ClientInit(
    dc: dc,
    isMedia: isMedia,
    isTest: isTest,
    proto: proto,
    prekeyAndIv: Uint8List.fromList(prekeyAndIv),
  );
}

const _reservedFirst = 0xef;
const _reservedStarts = [
  [0x48, 0x45, 0x41, 0x44],
  [0x50, 0x4f, 0x53, 0x54],
  [0x47, 0x45, 0x54, 0x20],
  [0xee, 0xee, 0xee, 0xee],
  [0xdd, 0xdd, 0xdd, 0xdd],
  [0x16, 0x03, 0x01, 0x02],
];

bool _isReserved(Uint8List r) {
  if (r[0] == _reservedFirst) return true;
  for (final s in _reservedStarts) {
    if (r[0] == s[0] && r[1] == s[1] && r[2] == s[2] && r[3] == s[3]) {
      return true;
    }
  }
  return r[4] == 0 && r[5] == 0 && r[6] == 0 && r[7] == 0;
}

/// Init packet the proxy sends to Telegram, standard obfuscation without a
/// secret.
Uint8List generateRelayInit(ProtoTag proto, int dcIdx, Random rnd) {
  final r = Uint8List(handshakeLen);
  do {
    for (var i = 0; i < handshakeLen; i++) {
      r[i] = rnd.nextInt(256);
    }
  } while (_isReserved(r));

  final key = r.sublist(_skipLen, _skipLen + _prekeyLen);
  final iv = r.sublist(_skipLen + _prekeyLen, _skipLen + _prekeyLen + _ivLen);
  final keystream = AesCtr(key, iv).process(Uint8List(handshakeLen));

  final tail = Uint8List(8)
    ..setAll(0, proto.bytes)
    ..buffer.asByteData().setInt16(4, dcIdx, Endian.little)
    ..[6] = rnd.nextInt(256)
    ..[7] = rnd.nextInt(256);
  for (var i = 0; i < 8; i++) {
    r[_protoTagPos + i] = tail[i] ^ keystream[_protoTagPos + i];
  }
  return r;
}

/// The four cipher streams of a relayed connection.
class CryptoCtx {
  CryptoCtx._(this.clientDec, this.clientEnc, this.tgEnc, this.tgDec);

  factory CryptoCtx.create(
    Uint8List clientPrekeyAndIv,
    Uint8List secret,
    Uint8List relayInit,
  ) {
    final cDecKey = _sha256(clientPrekeyAndIv.sublist(0, _prekeyLen), secret);
    final cDecIv = clientPrekeyAndIv.sublist(_prekeyLen);
    final rev = _reversed(clientPrekeyAndIv);
    final cEncKey = _sha256(rev.sublist(0, _prekeyLen), secret);
    final cEncIv = rev.sublist(_prekeyLen);

    final relay = relayInit.sublist(_skipLen, _skipLen + _prekeyLen + _ivLen);
    final relayRev = _reversed(relay);

    final ctx = CryptoCtx._(
      AesCtr(cDecKey, cDecIv),
      AesCtr(cEncKey, cEncIv),
      AesCtr(relay.sublist(0, _prekeyLen), relay.sublist(_prekeyLen)),
      AesCtr(relayRev.sublist(0, _prekeyLen), relayRev.sublist(_prekeyLen)),
    );
    ctx.clientDec.skip(handshakeLen);
    ctx.tgEnc.skip(handshakeLen);
    return ctx;
  }

  /// Decrypts data from the client.
  final AesCtr clientDec;

  /// Encrypts data to the client.
  final AesCtr clientEnc;

  /// Encrypts data to Telegram.
  final AesCtr tgEnc;

  /// Decrypts data from Telegram.
  final AesCtr tgDec;

  Uint8List up(Uint8List fromClient) =>
      tgEnc.process(clientDec.process(fromClient));

  Uint8List down(Uint8List fromTelegram) =>
      clientEnc.process(tgDec.process(fromTelegram));
}
