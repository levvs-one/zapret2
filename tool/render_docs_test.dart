import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prosvet/src/app.dart';
import 'package:prosvet/src/catalog/services.dart';
import 'package:prosvet/src/core/backend.dart';
import 'package:prosvet/src/core/controller.dart';
import 'package:prosvet/src/core/settings.dart';

class _SnapshotBackend implements Backend {
  bool _telegram = false;

  @override
  Stream<String> get faults => const Stream.empty();

  @override
  Future<String?> unsupportedReason() async => null;

  @override
  Future<String> networkKey() async => 'snapshot';

  @override
  Future<void> startDpi({
    required String networkKey,
    required bool youtube,
    required bool discord,
  }) async {}

  @override
  Future<void> stopDpi() async {}

  @override
  Future<void> applySmartDns(
    List<String> domains,
    List<String> servers,
  ) async {}

  @override
  Future<void> clearSmartDns() async {}

  @override
  Future<void> startTelegram({
    required int port,
    required String secretHex,
  }) async {
    _telegram = true;
  }

  @override
  Future<void> stopTelegram() async {
    _telegram = false;
  }

  @override
  String? get telegramLink => _telegram
      ? 'tg://proxy?server=127.0.0.1&port=1443&secret=dd00'
      : null;

  @override
  Future<void> openTelegramLink() async {}

  @override
  Future<bool> probe(Service service, List<String> dnsServers) async => true;
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String path, {
  double pixelRatio = 2,
}) async {
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Could not encode UI snapshot');
    File(path).writeAsBytesSync(
      Uint8List.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
    );
  });
}

void main() {
  testWidgets('render README screenshots from the real app', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(440, 780);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = Controller(
      backend: _SnapshotBackend(),
      settings: Settings.defaults(),
      saveSettings: (_) {},
      probeInterval: Duration.zero,
      probeAttempts: 1,
    );
    await controller.init(connect: false);
    addTearDown(controller.dispose);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: ProsvetApp(
          controller: controller,
          autostart: null,
          logPath: '',
          version: '0.1.0',
          desktopShell: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _capture(tester, boundaryKey, 'docs/off.png');

    await controller.start();
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, 'docs/on.png');

    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, 'docs/settings.png');
  });
}
