import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../platform/autostart.dart';
import 'theme.dart';
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
        children: [
          _MenuTile(
            icon: Icons.power_settings_new_rounded,
            title: 'Запуск',
            subtitle: 'Автозапуск и подключение при входе',
            onTap: () => _open(
              context,
              _StartupPage(controller: controller, autostart: autostart),
            ),
          ),
          _MenuTile(
            icon: Icons.language_rounded,
            title: 'Сеть',
            subtitle: 'Smart DNS и проверка сервисов',
            onTap: () => _open(context, _NetworkPage(controller: controller)),
          ),
          _MenuTile(
            icon: Icons.info_outline_rounded,
            title: 'О программе',
            subtitle: 'Версия, журнал, лицензии и поддержка',
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
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 21, color: colors.onSurfaceVariant),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colors.onSurfaceVariant,
      ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'При входе в Windows'),
            Section(
              children: [
                SwitchListTile(
                  title: const Text('Запускать Просвет'),
                  subtitle: const Text('Стартовать скрытым в системном трее'),
                  value: _autostart ?? false,
                  onChanged: widget.autostart == null || _autostart == null
                      ? null
                      : _setAutostart,
                ),
                SwitchListTile(
                  title: const Text('Включать сразу'),
                  subtitle: const Text(
                    'Применять выбранные правила после запуска приложения',
                  ),
                  value: widget.controller.settings.connectOnLaunch,
                  onChanged: widget.controller.setConnectOnLaunch,
                ),
              ],
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'DNS'),
            Section(
              children: [
                ListTile(
                  title: const Text('Smart DNS'),
                  subtitle: const Text('Только для выбранных доменов'),
                  trailing: Text(
                    controller.dnsProvider.title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _SettingsScaffold(
      title: 'О программе',
      child: Column(
        children: [
          Material(
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.section),
              side: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.22),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.light_mode_rounded,
                      color: colors.onPrimaryContainer,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Просвет',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Версия $version',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Section(
            children: [
              ListTile(
                title: const Text('Журнал'),
                subtitle: const Text('Открыть локальный диагностический лог'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: openLog,
              ),
              ListTile(
                title: const Text('Сообщить о проблеме'),
                subtitle: const Text('Открыть шаблоны GitHub Issues'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                onTap: openIssues,
              ),
              ListTile(
                title: const Text('Лицензии'),
                subtitle: const Text('Flutter и сторонние компоненты'),
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [child],
          ),
        ),
      ),
    );
  }
}
