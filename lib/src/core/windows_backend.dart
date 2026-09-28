import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../catalog/services.dart';
import '../engine/smartdns/nrpt.dart';
import '../engine/telegram/proxy.dart';
import '../engine/zapret/winws_args.dart';
import '../engine/zapret/winws_process.dart';
import '../platform/network_id.dart';
import '../platform/paths.dart';
import '../platform/shell.dart';
import 'backend.dart';
import 'log.dart';
import 'probes.dart';

class WindowsBackend implements Backend {
  WindowsBackend(this.paths, this.shell, this.log)
    : _winws = WinwsProcess(executable: paths.winws, onLog: log.write) {
    _winws.unexpectedExit.listen(
      (code) => _faults.add('Движок остановился (код $code)\n${_winws.tail}'),
    );
  }

  final AppPaths paths;
  final Shell shell;
  final Log log;
  final WinwsProcess _winws;
  final _faults = StreamController<String>.broadcast();
  TelegramProxy? _telegram;

  @override
  Stream<String> get faults => _faults.stream;

  @override
  Future<String?> unsupportedReason() async {
    if (!Platform.isWindows) return 'Prosvet работает в Windows 10 и 11.';
    if (!File(paths.winws).existsSync()) {
      return 'Не найдена папка engine рядом с программой. Переустановите Prosvet.';
    }
    final admin = await shell.run('net.exe', ['session']);
    if (!admin.ok) return 'Запустите Prosvet от имени администратора.';
    return null;
  }

  @override
  Future<String> networkKey() => currentNetworkKey(shell);

  @override
  Future<void> startDpi({
    required String networkKey,
    required bool youtube,
    required bool discord,
  }) async {
    await stopDpi();
    final args = buildWinwsArgs(
      WinwsLaunch(
        engineDir: paths.engineDir,
        stateDir: paths.stateDir,
        networkKey: networkKey,
        youtube: youtube,
        discord: discord,
      ),
    );
    log.write('winws2 ${args.join(' ')}');
    await _winws.start(args, workingDirectory: paths.engineDir);
  }

  @override
  Future<void> stopDpi() => _winws.stop();

  Future<void> _ps(String script) async {
    final r = await shell.powershell(script);
    if (!r.ok) throw StateError(r.stderr.trim());
  }

  @override
  Future<void> applySmartDns(List<String> domains, List<String> servers) =>
      _ps(nrptApplyScript(domains: domains, servers: servers));

  @override
  Future<void> clearSmartDns() => _ps(nrptClearScript());

  @override
  Future<void> startTelegram({
    required int port,
    required String secretHex,
  }) async {
    await stopTelegram();
    final secret = Uint8List.fromList([
      for (var i = 0; i < secretHex.length; i += 2)
        int.parse(secretHex.substring(i, i + 2), radix: 16),
    ]);
    final proxy = TelegramProxy(port: port, secret: secret, onLog: log.write);
    await proxy.start();
    _telegram = proxy;
  }

  @override
  Future<void> stopTelegram() async {
    await _telegram?.stop();
    _telegram = null;
  }

  @override
  String? get telegramLink => _telegram?.link;

  @override
  Future<void> openTelegramLink() async {
    final link = telegramLink;
    if (link == null) return;
    await shell.run('rundll32.exe', ['url.dll,FileProtocolHandler', link]);
  }

  @override
  Future<bool> probe(Service service, List<String> dnsServers) => probeService(
    service,
    dnsServers: dnsServers,
    telegramRunning: () => _telegram?.isRunning ?? false,
  );
}
