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
    widget.autostart?.isEnabled().then((value) {
      if (mounted) setState(() => _autostart = value);
    });
  }

  Future<void> _setAutostart(bool value) async {
    final autostart = widget.autostart;
    if (autostart == null) return;
    setState(() => _autostart = value);
    try {
      await autostart.setEnabled(value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _autostart = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить автозапуск: $e')),
      );
    }
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Section(
                children: [
                  _MenuTile(
                    icon: Icons.power_settings_new_rounded,
                    title: 'Запуск',
                    onTap: () => _open(
                      _StartupPage(
                        controller: c,
                        autostart: widget.autostart,
                        autostartValue: _autostart,
                        setAutostart: _setAutostart,
                      ),
                    ),
                  ),
                  _MenuTile(
                    icon: Icons.language_rounded,
                    title: 'Сеть',
                    onTap: () => _open(_NetworkPage(controller: c)),
                  ),
                  _MenuTile(
                    icon: Icons.info_outline_rounded,
                    title: 'О программе',
                    onTap: () => _open(
                      _AboutPage(
                        version: widget.version,
                        openLog: widget.openLog,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colors.onSurfaceVariant),
      title: Text(title),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

class _StartupPage extends StatelessWidget {
  const _StartupPage({
    required this.controller,
    required this.autostart,
    required this.autostartValue,
    required this.setAutostart,
  });

  final Controller controller;
  final Autostart? autostart;
  final bool? autostartValue;
  final ValueChanged<bool> setAutostart;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _SettingsScaffold(
        title: 'Запуск',
        child: Section(
          children: [
            SwitchListTile(
              title: const Text('Вместе с Windows'),
              value: autostartValue ?? false,
              onChanged: autostart == null || autostartValue == null
                  ? null
                  : setAutostart,
            ),
            SwitchListTile(
              title: const Text('Включать сразу'),
              value: controller.settings.connectOnLaunch,
              onChanged: controller.setConnectOnLaunch,
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkPage extends StatelessWidget {
  const _NetworkPage({required this.controller});

  final Controller controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _SettingsScaffold(
        title: 'Сеть',
        child: Column(
          children: [
            Section(
              children: [
                ListTile(
                  title: const Text('Smart DNS'),
                  trailing: Text(
                    controller.dnsProvider.title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: controller.power == Power.on
                    ? controller.recheck
                    : null,
                child: const Text('Проверить сервисы'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage({required this.version, required this.openLog});

  final String version;
  final VoidCallback openLog;

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'О программе',
      child: Section(
        children: [
          ListTile(title: const Text('Версия'), trailing: Text(version)),
          ListTile(
            title: const Text('Журнал'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: openLog,
          ),
          ListTile(
            title: const Text('Лицензии'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Просвет',
              applicationVersion: version,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [child],
          ),
        ),
      ),
    );
  }
}
