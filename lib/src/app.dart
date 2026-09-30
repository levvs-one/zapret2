import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import 'core/controller.dart';
import 'platform/autostart.dart';
import 'ui/home_page.dart';
import 'ui/settings_page.dart';
import 'ui/theme.dart';

class ProsvetApp extends StatefulWidget {
  const ProsvetApp({
    super.key,
    required this.controller,
    required this.autostart,
    required this.logPath,
    required this.version,
    required this.desktopShell,
  });

  final Controller controller;
  final Autostart? autostart;
  final String logPath;
  final String version;

  /// Tray icon and hide-on-close. Off in widget tests.
  final bool desktopShell;

  @override
  State<ProsvetApp> createState() => _ProsvetAppState();
}

class _ProsvetAppState extends State<ProsvetApp> with WindowListener {
  Controller get c => widget.controller;
  bool _quitting = false;

  tray.TrayIcon? _tray;
  tray.MenuItem? _toggleItem;
  Power? _trayPower;

  @override
  void initState() {
    super.initState();
    if (widget.desktopShell) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
      _createTray();
      c.addListener(_syncTray);
    }
  }

  @override
  void dispose() {
    if (widget.desktopShell) {
      c.removeListener(_syncTray);
      windowManager.removeListener(this);
      _tray?.dispose();
    }
    super.dispose();
  }

  tray.MenuItem _item(String label, VoidCallback onClick) {
    final item = tray.MenuItem.createWithLabelAndType(
      label,
      tray.MenuItemType.normal,
    )!;
    item.addListener((e) {
      if (e is tray.MenuItemClickedEvent) onClick();
    });
    return item;
  }

  void _createTray() {
    final icon = tray.TrayIcon.create();
    if (icon == null) return;
    final menu = tray.Menu.create()!;
    _toggleItem = _item('Включить', c.toggle);
    menu
      ..addItem(_item('Открыть', _show))
      ..addItem(_toggleItem!)
      ..addSeparator()
      ..addItem(_item('Выйти', _quit));
    icon
      ..setContextMenu(menu)
      ..setContextMenuTrigger(tray.ContextMenuTrigger.rightClicked)
      ..addListener((e) {
        if (e is tray.TrayIconClickedEvent) _show();
      });
    _tray = icon;
    _syncTray();
    icon.setVisible(true);
  }

  void _syncTray() {
    final icon = _tray;
    if (icon == null || _trayPower == c.power) return;
    _trayPower = c.power;
    final on = c.power == Power.on;
    icon
      ..icon = tray.ImageAsset.fromAsset(
        on ? 'assets/tray_on.ico' : 'assets/tray_off.ico',
      )
      ..setTooltip(on ? 'Просвет: включено' : 'Просвет: выключено');
    _toggleItem
      ?..label = on ? 'Выключить' : 'Включить'
      ..isEnabled = c.power == Power.on || c.power == Power.off;
  }

  Future<void> _show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    if (_quitting) return;
    _quitting = true;
    await c.stop();
    _tray?.dispose();
    _tray = null;
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    if (c.power == Power.off) {
      _quit();
    } else {
      windowManager.hide();
    }
  }

  SettingsPage _settings() => SettingsPage(
    controller: c,
    autostart: widget.autostart,
    version: widget.version,
    openLog: () {
      if (Platform.isWindows) Process.run('notepad.exe', [widget.logPath]);
    },
    openIssues: () {
      if (Platform.isWindows) {
        Process.run('rundll32.exe', [
          'url.dll,FileProtocolHandler',
          'https://github.com/levvs-one/zapret2/issues/new/choose',
        ]);
      }
    },
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Просвет',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: HomePage(controller: c, settingsPage: _settings),
    );
  }
}
