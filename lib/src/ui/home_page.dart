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
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
                children: [
                  _PowerPanel(controller: c),
                  if (c.unsupported != null || c.error != null) ...[
                    const SizedBox(height: 14),
                    _Notice(text: c.unsupported ?? c.error!),
                  ],
                  const SizedBox(height: 22),
                  Section(
                    label: 'Сервисы',
                    children: [
                      for (final service in Catalog.all)
                        _ServiceTile(service: service, controller: c),
                    ],
                  ),
                  if (c.power == Power.on &&
                      c.isEnabled(Catalog.telegram) &&
                      c.telegramLink != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: c.openTelegram,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Подключить Telegram Desktop'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PowerPanel extends StatelessWidget {
  const _PowerPanel({required this.controller});

  final Controller controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;
    final checking = c.health.values.contains(Health.checking);
    final failing = c.health.values.any((h) => h == Health.failing);

    final status = switch (c.power) {
      Power.off => 'Выключено',
      Power.starting => 'Включаю…',
      Power.stopping => 'Выключаю…',
      Power.on when checking => 'Проверяю сервисы…',
      Power.on when failing => 'Есть проблемы',
      Power.on => 'Включено',
    };

    final detail = switch (c.power) {
      Power.off => 'Системные правила не применены',
      Power.starting => 'Настраиваю только выбранные сервисы',
      Power.stopping => 'Возвращаю сетевые настройки',
      Power.on when checking => 'Проверяю доступность',
      Power.on when failing => 'Откройте сервисы ниже, чтобы увидеть состояние',
      Power.on => 'Остальной трафик идёт напрямую',
    };

    final statusColor = c.power == Power.on && !checking && !failing
        ? theme.colorScheme.positive
        : failing
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          children: [
            PowerButton(
              power: c.power,
              onPressed: c.unsupported == null ? c.toggle : null,
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                status,
                key: ValueKey(status),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(color: statusColor),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: SelectableText(
                text,
                style: TextStyle(color: colors.onErrorContainer, height: 1.35),
                maxLines: 6,
              ),
            ),
          ],
        ),
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
    final theme = Theme.of(context);
    final c = controller;
    final enabled = c.isEnabled(service);
    final health = c.health[service.id]!;

    final color = switch (health) {
      Health.idle => theme.colorScheme.outlineVariant,
      Health.checking => theme.colorScheme.primary,
      Health.ok => theme.colorScheme.positive,
      Health.failing => theme.colorScheme.error,
    };

    final tooltip = switch (health) {
      Health.idle => 'Не проверено',
      Health.checking => 'Проверяю',
      Health.ok => 'Работает',
      Health.failing => 'Не отвечает',
    };

    return ListTile(
      title: Text(service.title),
      subtitle: Text(service.caption),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (health != Health.idle) ...[
            Tooltip(
              message: tooltip,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Switch(
            value: enabled,
            onChanged: (value) => c.setEnabled(service, value),
          ),
        ],
      ),
      onTap: () => c.setEnabled(service, !enabled),
    );
  }
}
