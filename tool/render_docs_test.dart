import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prosvet/src/catalog/services.dart';
import 'package:prosvet/src/core/backend.dart';
import 'package:prosvet/src/core/controller.dart';
import 'package:prosvet/src/core/settings.dart';
import 'package:prosvet/src/ui/home_page.dart';
import 'package:prosvet/src/ui/settings_page.dart';
import 'package:prosvet/src/ui/theme.dart';

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
  String? get telegramLink =>
      _telegram ? 'tg://proxy?server=127.0.0.1&port=1443&secret=dd00' : null;

  @override
  Future<void> openTelegramLink() async {}

  @override
  Future<bool> probe(Service service, List<String> dnsServers) async => true;
}

Future<void> _loadFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  final loader = FontLoader(family)..addFont(Future.value(data));
  await loader.load();
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String path, {
  double pixelRatio = 2,
}) async {
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Could not encode UI snapshot');
    File(path).writeAsBytesSync(
      Uint8List.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
    );
  });
}

Widget _snapshotApp(Widget home) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(fontFamily: 'ProsvetDocs'),
    home: home,
  );
}

void main() {
  testWidgets('render README screenshots from the real app', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(440, 780);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final textFont = Platform.environment['PROSVET_DOC_FONT'];
    final iconFont = Platform.environment['PROSVET_ICON_FONT'];
    if (textFont == null || iconFont == null) {
      throw StateError('Snapshot font paths were not provided');
    }
    await tester.runAsync(() async {
      await _loadFont('ProsvetDocs', textFont);
      await _loadFont('MaterialIcons', iconFont);
    });

    final controller = Controller(
      backend: _SnapshotBackend(),
      settings: Settings.defaults(),
      saveSettings: (_) {},
      probeInterval: Duration.zero,
      probeAttempts: 1,
    );
    await controller.init(connect: false);
    addTearDown(controller.dispose);

    SettingsPage settings() => SettingsPage(
      controller: controller,
      autostart: null,
      openLog: () {},
      openIssues: () {},
      version: '0.2.0',
    );

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: _snapshotApp(
          HomePage(controller: controller, settingsPage: settings),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, 'docs/off.png');

    await controller.start();
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, 'docs/on.png');

    await tester.pumpWidget(
      RepaintBoundary(key: boundaryKey, child: _snapshotApp(settings())),
    );
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, 'docs/settings.png');
  });
}
