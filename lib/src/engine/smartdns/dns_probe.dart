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

/// Asks [server] directly for [name]. True if it answered with at least one
/// record within [timeout].
Future<bool> probeDnsServer(
  String server,
  String name, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  RawDatagramSocket? socket;
  StreamSubscription<RawSocketEvent>? sub;
  try {
    final id = Random.secure().nextInt(0xffff);
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final done = Completer<bool>();
    sub = socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final d = socket?.receive();
        if (d == null) return;
        final n = dnsAnswerCount(d.data, id);
        if (n != null && !done.isCompleted) done.complete(n > 0);
      },
      onError: (_) {
        if (!done.isCompleted) done.complete(false);
      },
    );
    socket.send(buildDnsQuery(name, id), InternetAddress(server), 53);
    return await done.future.timeout(timeout, onTimeout: () => false);
  } catch (_) {
    return false;
  } finally {
    await sub?.cancel();
    socket?.close();
  }
}
