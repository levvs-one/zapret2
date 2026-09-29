import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Builds a DNS query for an A record.
Uint8List buildDnsQuery(String name, int id) {
  final b = BytesBuilder();
  b.add([id >> 8 & 0xff, id & 0xff, 0x01, 0x00, 0, 1, 0, 0, 0, 0, 0, 0]);
  for (final label in name.split('.')) {
    b.addByte(label.length);
    b.add(label.codeUnits);
  }
  b.add([0, 0, 1, 0, 1]);
  return b.toBytes();
}

/// Number of answers in a response that matches [id], or null if the
/// response is not a successful answer to that query.
int? dnsAnswerCount(Uint8List r, int id) {
  if (r.length < 12) return null;
  if ((r[0] << 8 | r[1]) != id) return null;
  final isResponse = r[2] & 0x80 != 0;
  final rcode = r[3] & 0x0f;
  if (!isResponse || rcode != 0) return null;
  return r[6] << 8 | r[7];
}

int? _skipName(Uint8List packet, int offset) {
  while (offset < packet.length) {
    final n = packet[offset];
    if (n == 0) return offset + 1;
    if (n & 0xc0 == 0xc0) {
      return offset + 2 <= packet.length ? offset + 2 : null;
    }
    if (n & 0xc0 != 0 || n > 63) return null;
    offset += 1 + n;
  }
  return null;
}

/// IPv4 A records from a successful matching DNS response.
///
/// CNAME and other answer types are skipped; any A records in the answer
/// section are returned regardless of whether names are compressed.
Set<String>? dnsAAnswers(Uint8List r, int id) {
  final answerCount = dnsAnswerCount(r, id);
  if (answerCount == null) return null;

  final qdCount = r[4] << 8 | r[5];
  var offset = 12;
  for (var i = 0; i < qdCount; i++) {
    offset = _skipName(r, offset) ?? -1;
    if (offset < 0 || offset + 4 > r.length) return null;
    offset += 4;
  }

  final result = <String>{};
  for (var i = 0; i < answerCount; i++) {
    offset = _skipName(r, offset) ?? -1;
    if (offset < 0 || offset + 10 > r.length) return null;

    final type = r[offset] << 8 | r[offset + 1];
    final klass = r[offset + 2] << 8 | r[offset + 3];
    final rdLength = r[offset + 8] << 8 | r[offset + 9];
    offset += 10;
    if (offset + rdLength > r.length) return null;

    if (type == 1 && klass == 1 && rdLength == 4) {
      result.add(
        '${r[offset]}.${r[offset + 1]}.${r[offset + 2]}.${r[offset + 3]}',
      );
    }
    offset += rdLength;
  }
  return result;
}

/// Asks [server] directly for A records for [name].
///
/// Returns null on timeout/protocol/socket failure and a (possibly empty) set
/// for a valid DNS response.
Future<Set<String>?> queryDnsServer(
  String server,
  String name, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  RawDatagramSocket? socket;
  StreamSubscription<RawSocketEvent>? sub;
  try {
    final id = Random.secure().nextInt(0x10000);
    final expectedServer = InternetAddress(server);
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final done = Completer<Set<String>?>();
    sub = socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final d = socket?.receive();
        if (d == null || d.address.address != expectedServer.address) return;
        final answers = dnsAAnswers(d.data, id);
        if (answers != null && !done.isCompleted) done.complete(answers);
      },
      onError: (_) {
        if (!done.isCompleted) done.complete(null);
      },
    );
    socket.send(buildDnsQuery(name, id), expectedServer, 53);
    return await done.future.timeout(timeout, onTimeout: () => null);
  } catch (_) {
    return null;
  } finally {
    await sub?.cancel();
    socket?.close();
  }
}

/// True when [server] returns at least one A record for [name].
Future<bool> probeDnsServer(
  String server,
  String name, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final answers = await queryDnsServer(server, name, timeout: timeout);
  return answers?.isNotEmpty ?? false;
}
