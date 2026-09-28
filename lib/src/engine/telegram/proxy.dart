import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'byte_reader.dart';
import 'msg_splitter.dart';
import 'obfuscated2.dart';
import 'ws_client.dart';

/// Telegram data centers reachable over TCP directly.
const dcAddresses = <int, String>{
  1: '149.154.175.50',
  2: '149.154.167.51',
  3: '149.154.175.100',
  4: '149.154.167.91',
  5: '149.154.171.5',
  203: '91.105.192.100',
};

/// Front for Telegram's WebSocket endpoints kws{N}.web.telegram.org.
const wsFrontIp = '149.154.167.220';

/// DCs whose WebSocket endpoints are served by [wsFrontIp].
const wsDcs = {2, 4};

List<String> wsDomains(int dc, bool isMedia) {
  if (dc == 203) dc = 2;
  final main = 'kws$dc.web.telegram.org';
  final alt = 'kws$dc-1.web.telegram.org';
  return isMedia ? [alt, main] : [main, alt];
}

class TelegramProxyStats {
  int active = 0;
  int total = 0;
  int viaWebSocket = 0;
  int viaTcp = 0;
  int failed = 0;
  DateTime? lastSuccess;
}

/// Local MTProto proxy for Telegram Desktop. Every connection is re-encrypted
/// and sent to Telegram through its WebSocket endpoint, falling back to plain
/// TCP when WebSocket is unavailable.
///
/// Design follows Flowseal/tg-ws-proxy (MIT).
class TelegramProxy {
  TelegramProxy({required this.port, required this.secret, this.onLog});

  final int port;

  /// 16-byte proxy secret shared with Telegram Desktop.
  final Uint8List secret;
  final void Function(String)? onLog;
  final stats = TelegramProxyStats();

  final _rnd = Random.secure();
  final _sockets = <Socket>{};
  final _wsBroken = <String>{};
  ServerSocket? _server;

  bool get isRunning => _server != null;

  String get link {
    final hex = secret.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'tg://proxy?server=127.0.0.1&port=$port&secret=dd$hex';
  }

  Future<void> start() async {
    if (_server != null) return;
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    server.listen(
      (s) => unawaited(_handle(s)),
      onError: (Object e) => onLog?.call('telegram: listener error $e'),
    );
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close();
    for (final s in _sockets.toList()) {
      s.destroy();
    }
    _sockets.clear();
  }

  Future<void> _handle(Socket client) async {
    _sockets.add(client);
    stats
      ..active += 1
      ..total += 1;
    client.setOption(SocketOption.tcpNoDelay, true);
    final reader = ByteReader(client);
    try {
      final hs = await reader
          .read(handshakeLen)
          .timeout(const Duration(seconds: 10));
      if (hs == null) return;
      final init = parseClientInit(hs, secret);
      if (init == null) {
        onLog?.call('telegram: wrong secret or protocol');
        return;
      }
      final relayInit = generateRelayInit(init.proto, init.dcIdx, _rnd);
      final ctx = CryptoCtx.create(init.prekeyAndIv, secret, relayInit);

      final ws = init.isTest ? null : await _connectWs(init);
      if (ws != null) {
        stats
          ..viaWebSocket += 1
          ..lastSuccess = DateTime.now();
        ws.send(relayInit);
        await _bridgeWs(
          reader,
          client,
          ws,
          ctx,
          MsgSplitter(relayInit, init.proto),
        );
        return;
      }

      final ip = dcAddresses[init.dc];
      if (ip == null || init.isTest) {
        stats.failed += 1;
        return;
      }
      final upstream = await Socket.connect(
        ip,
        443,
        timeout: const Duration(seconds: 8),
      );
      stats
        ..viaTcp += 1
        ..lastSuccess = DateTime.now();
      upstream.add(relayInit);
      await _bridgeTcp(reader, client, upstream, ctx);
    } catch (e) {
      stats.failed += 1;
      onLog?.call('telegram: $e');
    } finally {
      stats.active -= 1;
      _sockets.remove(client);
      client.destroy();
    }
  }

  Future<WsClient?> _connectWs(ClientInit init) async {
    if (!wsDcs.contains(init.dc == 203 ? 2 : init.dc)) return null;
    final key = '${init.dc}${init.isMedia ? 'm' : ''}';
    if (_wsBroken.contains(key)) return null;
    var allRedirects = true;
    for (final domain in wsDomains(init.dc, init.isMedia)) {
      try {
        return await WsClient.connect(ip: wsFrontIp, domain: domain);
      } on WsHandshakeException catch (e) {
        if (!e.isRedirect) allRedirects = false;
        onLog?.call('telegram: $domain $e');
      } catch (e) {
        allRedirects = false;
        onLog?.call('telegram: $domain $e');
        break;
      }
    }
    if (allRedirects) _wsBroken.add(key);
    return null;
  }

  Future<void> _bridgeWs(
    ByteReader client,
    Socket clientSocket,
    WsClient ws,
    CryptoCtx ctx,
    MsgSplitter splitter,
  ) async {
    Future<void> up() async {
      await for (final chunk in client.rest()) {
        for (final part in splitter.split(ctx.up(chunk))) {
          ws.send(part);
        }
      }
      final tail = splitter.flush();
      if (tail != null) ws.send(tail);
    }

    Future<void> down() async {
      await for (final msg in ws.messages()) {
        clientSocket.add(ctx.down(msg));
      }
    }

    try {
      await Future.any([up(), down()]);
    } finally {
      await ws.close();
      await client.cancel();
    }
  }

  Future<void> _bridgeTcp(
    ByteReader client,
    Socket clientSocket,
    Socket upstream,
    CryptoCtx ctx,
  ) async {
    _sockets.add(upstream);
    Future<void> up() async {
      await for (final chunk in client.rest()) {
        upstream.add(ctx.up(chunk));
      }
    }

    Future<void> down() async {
      await for (final chunk in upstream) {
        clientSocket.add(ctx.down(chunk));
      }
    }

    try {
      await Future.any([up(), down()]);
    } finally {
      _sockets.remove(upstream);
      upstream.destroy();
      await client.cancel();
    }
  }
}
