import 'package:flutter/material.dart';

import '../catalog/services.dart';
import '../core/controller.dart';
import 'power_button.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'widgets.dart';

const _icons = <String, IconData>{
  'youtube': Icons.smart_display_outlined,
  'discord': Icons.headset_mic_outlined,
  'telegram': Icons.send_outlined,
  'gemini': Icons.auto_awesome_outlined,
  'chatgpt': Icons.chat_bubble_outline_rounded,
  'claude': Icons.edit_note_rounded,
  'copilot': Icons.code_rounded,
  'spotify': Icons.music_note_outlined,
};

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.settingsPage,
  });

  final Controller controller;
  final SettingsPage Function() settingsPage;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            scrolledUnderElevation: 0,
            title: const Text('Просвет'),
            actions: [
              IconButton(
                tooltip: 'Настройки',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => settingsPage())),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: PowerButton(
                      power: c.power,
                      onPressed: c.unsupported == null ? c.toggle : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Status(controller: c),
                  if (c.unsupported != null || c.error != null) ...[
                    const SizedBox(height: 20),
                    _Notice(text: c.unsupported ?? c.error!),
                  ],
                  const SizedBox(height: 32),
                  Section(
                    title: 'Без замедления',
                    footer:
                        'Трафик идёт напрямую, Просвет только мешает провайдеру '
                        'его распознать.',
                    children: [
                      for (final s in [
                        Catalog.youtube,
                        Catalog.discord,
                        Catalog.telegram,
                      ])
                        _ServiceTile(service: s, controller: c),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Section(
                    title: 'Недоступные из России',
                    footer:
                        'Запросы к этим сервисам разрешаются через ${c.dnsProvider.title}: '
                        'они идут через зарубежный шлюз, остальной интернет не меняется. '
                        'Нужен аккаунт с регионом, где сервис работает.',
                    children: [
                      for (final s in Catalog.all.where(
                        (s) => s.mechanism == Mechanism.smartDns,
                      ))
                        _ServiceTile(service: s, controller: c),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.controller});

  final Controller controller;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = controller;
    final checking = c.health.values.contains(Health.checking);
    final failing = c.health.values.contains(Health.failing);
    final (title, subtitle) = switch (c.power) {
      Power.off => ('Выключено', 'Нажмите, чтобы включить'),
      Power.starting => ('Включаю', 'Запускаю движок'),
      Power.stopping => ('Выключаю', 'Возвращаю настройки сети'),
      Power.on when checking => ('Включено', 'Подбираю способ для вашей сети'),
      Power.on when failing => ('Включено', 'Часть сервисов пока недоступна'),
      Power.on => ('Всё работает', 'Можно свернуть окно'),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Column(
        key: ValueKey('$title$subtitle'),
        children: [
          Text(title, style: t.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: t.textTheme.bodyMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: c.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              text,
              style: TextStyle(color: c.onErrorContainer),
              maxLines: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.controller});

  final Service service;
  final Controller controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final on = c.isEnabled(service);
    final health = c.health[service.id]!;
    final showConnect =
        service.mechanism == Mechanism.telegram &&
        c.power == Power.on &&
        on &&
        c.telegramLink != null;
    return Column(
      children: [
        ListTile(
          leading: TileIcon(_icons[service.id]!, active: on),
          title: Text(service.title),
          subtitle: Text(service.caption),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HealthMark(health: health),
              const SizedBox(width: 12),
              Switch(value: on, onChanged: (v) => c.setEnabled(service, v)),
            ],
          ),
          onTap: () => c.setEnabled(service, !on),
        ),
        if (showConnect)
          Padding(
            padding: const EdgeInsets.fromLTRB(68, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: c.openTelegram,
                child: const Text('Подключить Telegram Desktop'),
              ),
            ),
          ),
      ],
    );
  }
}

class _HealthMark extends StatelessWidget {
  const _HealthMark({required this.health});

  final Health health;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final Widget child = switch (health) {
      Health.idle => const SizedBox.square(
        key: ValueKey('idle'),
        dimension: 16,
      ),
      Health.checking => SizedBox.square(
        key: const ValueKey('checking'),
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
      ),
      Health.ok => Tooltip(
        key: const ValueKey('ok'),
        message: 'Работает',
        child: Icon(Icons.check_circle_rounded, size: 18, color: c.positive),
      ),
      Health.failing => Tooltip(
        key: const ValueKey('failing'),
        message: 'Не отвечает',
        child: Icon(Icons.error_rounded, size: 18, color: c.error),
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: child,
    );
  }
}
