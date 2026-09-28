import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../platform/autostart.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.autostart,
    required this.openLog,
    required this.version,
  });

  final Controller controller;
  final Autostart? autostart;
  final VoidCallback openLog;
  final String version;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? _autostart;

  @override
  void initState() {
    super.initState();
    widget.autostart?.isEnabled().then((v) {
      if (mounted) setState(() => _autostart = v);
    });
  }

  Future<void> _setAutostart(bool v) async {
    final a = widget.autostart;
    if (a == null) return;
    setState(() => _autostart = v);
    try {
      await a.setEnabled(v);
    } catch (e) {
      if (!mounted) return;
      setState(() => _autostart = !v);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить автозапуск: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: const Text('Настройки'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Section(
                  title: 'Запуск',
                  children: [
                    SwitchListTile(
                      secondary: const TileIcon(Icons.login_rounded),
                      title: const Text('Запускать вместе с Windows'),
                      subtitle: const Text('Без запроса прав при каждом входе'),
                      value: _autostart ?? false,
                      onChanged: widget.autostart == null || _autostart == null
                          ? null
                          : _setAutostart,
                    ),
                    SwitchListTile(
                      secondary: const TileIcon(Icons.bolt_rounded),
                      title: const Text('Включать сразу'),
                      subtitle: const Text('Не ждать нажатия кнопки'),
                      value: c.settings.connectOnLaunch,
                      onChanged: c.setConnectOnLaunch,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Section(
                  title: 'Сеть',
                  children: [
                    ListTile(
                      leading: const TileIcon(Icons.dns_outlined),
                      title: Text(c.dnsProvider.title),
                      subtitle: Text(c.dnsProvider.servers.join(', ')),
                    ),
                    ListTile(
                      leading: const TileIcon(Icons.refresh_rounded),
                      title: const Text('Проверить сервисы'),
                      enabled: c.power == Power.on,
                      onTap: c.recheck,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Section(
                  title: 'О программе',
                  children: [
                    ListTile(
                      leading: const TileIcon(Icons.info_outline_rounded),
                      title: const Text('Просвет'),
                      subtitle: Text('Версия ${widget.version}'),
                    ),
                    ListTile(
                      leading: const TileIcon(Icons.description_outlined),
                      title: const Text('Журнал'),
                      subtitle: const Text(
                        'Пригодится, если что-то не работает',
                      ),
                      onTap: widget.openLog,
                    ),
                    ListTile(
                      leading: const TileIcon(Icons.gavel_rounded),
                      title: const Text('Лицензии'),
                      subtitle: const Text('zapret2, tg-ws-proxy и библиотеки'),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'Просвет',
                        applicationVersion: widget.version,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
