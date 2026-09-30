import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../platform/autostart.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.autostart,
    required this.openLog,
    required this.openIssues,
    required this.version,
  });

  final Controller controller;
  final Autostart? autostart;
  final VoidCallback openLog;
  final VoidCallback openIssues;
  final String version;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Настройки',
      child: Section(
        label: 'Просвет',
        children: [
          _MenuTile(
            icon: Icons.power_settings_new_rounded,
            title: 'Запуск',
            subtitle: 'Автозапуск и включение при входе',
            onTap: () => _open(
              context,
              _StartupPage(controller: controller, autostart: autostart),
            ),
          ),
          _MenuTile(
            icon: Icons.language_rounded,
            title: 'Сеть',
            subtitle: 'Smart DNS и повторная проверка',
            onTap: () => _open(context, _NetworkPage(controller: controller)),
          ),
          _MenuTile(
            icon: Icons.info_outline_rounded,
            title: 'О программе',
            subtitle: 'Версия, журнал и лицензии',
            onTap: () => _open(
              context,
              _AboutPage(
                version: version,
                openLog: openLog,
                openIssues: openIssues,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colors.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right_rounded, color: colors.outline),
      onTap: onTap,
    );
  }
}

class _StartupPage extends StatefulWidget {
  const _StartupPage({required this.controller, required this.autostart});

  final Controller controller;
  final Autostart? autostart;

  @override
  State<_StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<_StartupPage> {
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _SettingsScaffold(
        title: 'Запуск',
        child: Section(
          label: 'Поведение',
          children: [
            SwitchListTile(
              title: const Text('Вместе с Windows'),
              subtitle: const Text('Запускать Просвет после входа в систему'),
              value: _autostart ?? false,
              onChanged: widget.autostart == null || _autostart == null
                  ? null
                  : _setAutostart,
            ),
            SwitchListTile(
              title: const Text('Включать сразу'),
              subtitle: const Text('Применять выбранные правила после запуска'),
              value: widget.controller.settings.connectOnLaunch,
              onChanged: widget.controller.setConnectOnLaunch,
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
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _SettingsScaffold(
        title: 'Сеть',
        child: Column(
          children: [
            Section(
              label: 'Разрешение имён',
              children: [
                ListTile(
                  title: const Text('Smart DNS'),
                  subtitle: const Text('Только для выбранных доменов'),
                  trailing: Text(
                    controller.dnsProvider.title,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: controller.power == Power.on
                    ? controller.recheck
                    : null,
                icon: const Icon(Icons.refresh_rounded, size: 19),
                label: const Text('Проверить сервисы'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage({
    required this.version,
    required this.openLog,
    required this.openIssues,
  });

  final String version;
  final VoidCallback openLog;
  final VoidCallback openIssues;

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'О программе',
      child: Column(
        children: [
          Section(
            label: 'Приложение',
            children: [
              ListTile(
                title: const Text('Просвет'),
                subtitle: const Text('Локальный Windows-клиент'),
                trailing: Text(version),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Section(
            label: 'Диагностика',
            children: [
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Журнал'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: openLog,
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Сообщить о проблеме'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                onTap: openIssues,
              ),
              ListTile(
                leading: const Icon(Icons.balance_outlined),
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
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
            children: [child],
          ),
        ),
      ),
    );
  }
}
