import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/core/backend.dart';
import 'src/core/controller.dart';
import 'src/core/demo_backend.dart';
import 'src/core/log.dart';
import 'src/core/settings.dart';
import 'src/core/windows_backend.dart';
import 'src/platform/autostart.dart';
import 'src/platform/paths.dart';
import 'src/platform/shell.dart';

const version = String.fromEnvironment(
  'PROSVET_VERSION',
  defaultValue: '0.2.0',
);

bool shouldConnectAtStartup(Settings settings) => settings.connectOnLaunch;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerLicenses();

  final demo = args.contains('--demo');
  final background = args.contains('--background');
  final paths = AppPaths.resolve();
  final log = Log(paths.logFile);
  const shell = SystemShell();
  final settings = Settings.load(paths.settingsFile);

  final Backend backend = demo
      ? DemoBackend()
      : WindowsBackend(paths, shell, log);
  final controller = Controller(
    backend: backend,
    settings: settings,
    saveSettings: (s) => s.save(paths.settingsFile),
  );

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Просвет',
      size: Size(460, 760),
      minimumSize: Size(400, 600),
      center: true,
    ),
    () async {
      if (!background) {
        await windowManager.show();
        await windowManager.focus();
      }
    },
  );

  runApp(
    ProsvetApp(
      controller: controller,
      autostart: Platform.isWindows && !demo
          ? Autostart(shell, Platform.resolvedExecutable)
          : null,
      logPath: paths.logFile,
      version: version,
      desktopShell: true,
    ),
  );

  await controller.init(connect: shouldConnectAtStartup(settings));
}

void _registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (pkg, file) in [
      ('zapret2 (bol-van)', 'zapret2'),
      ('tg-ws-proxy (Flowseal)', 'tg-ws-proxy'),
    ]) {
      final text = await rootBundle.loadString('assets/licenses/$file.txt');
      yield LicenseEntryWithLineBreaks([pkg], text);
    }
  });
}
