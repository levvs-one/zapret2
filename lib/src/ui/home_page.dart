import 'package:flutter/material.dart';

import '../catalog/services.dart';
import '../core/controller.dart';
import 'power_button.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'widgets.dart';

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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: PowerButton(
                      power: c.power,
                      onPressed: c.unsupported == null ? c.toggle : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Status(controller: c),
                  if (c.unsupported != null || c.error != null) ...[
                    const SizedBox(height: 20),
                    _Notice(text: c.unsupported ?? c.error!),
                  ],
                  const SizedBox(height: 36),
                  Section(
                    title: 'Без замедления',
                    children: [
                      for (final s in [Catalog.youtube, Catalog.discord])
                        _ServiceTile(service: s, controller: c),
                      _ServiceTile(service: Catalog.telegram, controller: c),
                      if (c.power == Power.on &&
                          c.isEnabled(Catalog.telegram) &&
                          c.telegramLink != null)
                        _TelegramConnect(onTap: c.openTelegram),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Section(
                    title: 'Закрытые для России',
                    footer:
                        'Эти сервисы открываются через ${c.dnsProvider.title}, '
                        'остальной интернет идёт как обычно. Аккаунт должен '
                        'быть зарегистрирован в стране, где сервис работает.',
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
    final failing = c.health.values.where((h) => h == Health.failing).length;
    final (title, subtitle) = switch (c.power) {
      Power.off => ('Выключено', 'Нажмите, чтобы включить'),
      Power.starting => ('Включаю', 'Это займёт пару секунд'),
      Power.stopping => ('Выключаю', 'Возвращаю сеть как было'),
      Power.on when checking => ('Включено', 'Подбираю способ для вашей сети'),
      Power.on when failing > 0 => (
        'Включено',
        failing == 1
            ? 'Один сервис не отвечает'
            : 'Не отвечает сервисов: $failing',
      ),
      Power.on => (
        'Всё работает',
        'Окно можно закрыть, Просвет останется в трее',
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Column(
        key: ValueKey('$title$subtitle'),
        children: [
          Text(
            title,
            style: t.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: c.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              text,
              style: TextStyle(color: c.onErrorContainer, height: 1.4),
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
    final t = Theme.of(context);
    final c = controller;
    final on = c.isEnabled(service);
    final (status, color) = switch (c.health[service.id]!) {
      Health.idle => (service.caption, t.colorScheme.onSurfaceVariant),
      Health.checking => ('Проверяю', t.colorScheme.onSurfaceVariant),
      Health.ok => ('Работает', t.colorScheme.positive),
      Health.failing => ('Не отвечает', t.colorScheme.error),
    };
    return ListTile(
      title: Text(service.title),
      subtitle: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, ?current],
        ),
        child: Text(
          status,
          key: ValueKey(status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color),
        ),
      ),
      trailing: Switch(value: on, onChanged: (v) => c.setEnabled(service, v)),
      onTap: () => c.setEnabled(service, !on),
    );
  }
}

class _TelegramConnect extends StatelessWidget {
  const _TelegramConnect({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(
        'Подключить Telegram Desktop',
        style: TextStyle(color: c.primary),
      ),
      subtitle: const Text('Один раз: Telegram сам добавит прокси'),
      trailing: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Icon(Icons.open_in_new_rounded, size: 20, color: c.primary),
      ),
      onTap: onTap,
    );
  }
}
