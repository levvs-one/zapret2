import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:prosvet/src/engine/smartdns/dns_probe.dart';
import 'package:prosvet/src/engine/telegram/msg_splitter.dart';
import 'package:prosvet/src/engine/telegram/obfuscated2.dart';
import 'package:prosvet/src/engine/telegram/ws_client.dart';

Uint8List _bytes(int n, Random r) =>
    Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));

/// Client side of obfuscated2 with a proxy secret, as Telegram Desktop does.
({Uint8List init, AesCtr enc, AesCtr dec}) _client(
  Uint8List secret,
  ProtoTag proto,
  int dcIdx,
  Random r,
) {
  final init = generateRelayInit(proto, dcIdx, r);
  final prekey = init.sublist(8, 40);
  final iv = init.sublist(40, 56);
  AesCtr stream(Uint8List pk, Uint8List iv) {
    final key = Uint8List.fromList([...pk, ...secret]);
    return AesCtr(_sha(key), iv);
  }

  final enc = stream(prekey, iv);
  final plain = enc.process(Uint8List(64));
  // Rebuild the packet so the secret-keyed stream decrypts the tag and dc.
  final tail = Uint8List(8)
    ..setAll(0, proto.bytes)
    ..buffer.asByteData().setInt16(4, dcIdx, Endian.little);
  for (var i = 0; i < 8; i++) {
    init[56 + i] = tail[i] ^ plain[56 + i];
  }
  final rev = Uint8List.fromList(init.sublist(8, 56).reversed.toList());
  return (
    init: init,
    enc: enc,
    dec: stream(rev.sublist(0, 32), rev.sublist(32)),
  );
}

Uint8List _sha(Uint8List b) => SHA256Digest().process(b);

void main() {
  final r = Random(1);

  test('proxy decodes client init and relays both directions', () {
    final secret = _bytes(16, r);
    final c = _client(secret, ProtoTag.intermediate, -4, r);
    final parsed = parseClientInit(c.init, secret)!;
    expect(parsed.dc, 4);
    expect(parsed.isMedia, isTrue);
    expect(parsed.proto, ProtoTag.intermediate);
    expect(parseClientInit(c.init, _bytes(16, r)), isNull);

    final relayInit = generateRelayInit(parsed.proto, parsed.dcIdx, r);
    final ctx = CryptoCtx.create(parsed.prekeyAndIv, secret, relayInit);

    // What Telegram sees: standard obfuscation keyed by relayInit.
    final tgDec = AesCtr(relayInit.sublist(8, 40), relayInit.sublist(40, 56))
      ..skip(64);
    final rr = Uint8List.fromList(relayInit.sublist(8, 56).reversed.toList());
    final tgEnc = AesCtr(rr.sublist(0, 32), rr.sublist(32));

    final msg = _bytes(100, r);
    final up = ctx.up(c.enc.process(msg));
    expect(tgDec.process(up), msg);

    final reply = _bytes(70, r);
    final down = ctx.down(tgEnc.process(reply));
    expect(c.dec.process(down), reply);
  });

  test('relay init tag decrypts to protocol and dc', () {
    final init = generateRelayInit(ProtoTag.abridged, 2, r);
    final ks = AesCtr(
      init.sublist(8, 40),
      init.sublist(40, 56),
    ).process(Uint8List(64));
    final plain = Uint8List.fromList([
      for (var i = 0; i < 64; i++) init[i] ^ ks[i],
    ]);
    expect(ProtoTag.parse(plain, 56), ProtoTag.abridged);
    expect(ByteData.sublistView(plain).getInt16(60, Endian.little), 2);
  });

  test('splitter emits whole intermediate packets', () {
    final init = generateRelayInit(ProtoTag.intermediate, 2, r);
    final enc = AesCtr(init.sublist(8, 40), init.sublist(40, 56))..skip(64);
    Uint8List packet(int n) {
      final b = Uint8List(4 + n)
        ..buffer.asByteData().setUint32(0, n, Endian.little);
      return b;
    }

    final stream = enc.process(
      Uint8List.fromList([...packet(8), ...packet(16)]),
    );
    final s = MsgSplitter(init, ProtoTag.intermediate);
    final parts = [
      ...s.split(stream.sublist(0, 5)),
      ...s.split(stream.sublist(5, 20)),
      ...s.split(stream.sublist(20)),
    ];
    expect(parts.map((p) => p.length), [12, 20]);
    expect(s.flush(), isNull);
  });

  test('websocket client frames are masked and retain payload length', () {
    final payload = _bytes(70000, r);
    final frame = WsClient.encodeFrame(0x2, payload, Random(7));
    expect(frame[0], 0x82);
    expect(frame[1] & 0x80, isNonZero);
    expect(frame[1] & 0x7f, 127);

    final length = ByteData.sublistView(frame, 2, 10).getUint64(0);
    expect(length, payload.length);
    final mask = frame.sublist(10, 14);
    final decoded = Uint8List(payload.length);
    for (var i = 0; i < payload.length; i++) {
      decoded[i] = frame[14 + i] ^ mask[i & 3];
    }
    expect(decoded, payload);
  });

  test('dns query and A-answer parsing', () {
    final q = buildDnsQuery('claude.ai', 0x1234);
    expect(q.sublist(0, 2), [0x12, 0x34]);
    expect(q.sublist(12, 19), [6, ...'claude'.codeUnits]);

    final answer = Uint8List.fromList([
      0x12,
      0x34,
      0x81,
      0x80,
      0,
      1,
      0,
      1,
      0,
      0,
      0,
      0,
      6,
      ...'claude'.codeUnits,
      2,
      ...'ai'.codeUnits,
      0,
      0,
      1,
      0,
      1,
      0xc0,
      0x0c,
      0,
      1,
      0,
      1,
      0,
      0,
      0,
      60,
      0,
      4,
      203,
      0,
      113,
      42,
    ]);
    expect(dnsAnswerCount(answer, 0x1234), 1);
    expect(dnsAAnswers(answer, 0x1234), {'203.0.113.42'});
    expect(dnsAAnswers(answer, 0x1235), isNull);
  });
}
