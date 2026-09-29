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
                icon: const Icon(Icons.tune_rounded),
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
                  const SizedBox(height: 18),
                  Center(
                    child: PowerButton(
                      power: c.power,
                      onPressed: c.unsupported == null ? c.toggle : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Status(controller: c),
                  if (c.unsupported != null || c.error != null) ...[
                    const SizedBox(height: 18),
                    _Notice(text: c.unsupported ?? c.error!),
                  ],
                  const SizedBox(height: 30),
                  Section(
                    children: [
                      for (final s in Catalog.all)
                        _ServiceTile(service: s, controller: c),
                    ],
                  ),
                  if (c.power == Power.on &&
                      c.isEnabled(Catalog.telegram) &&
                      c.telegramLink != null) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: c.openTelegram,
                      icon: const Icon(Icons.open_in_new_rounded, size: 19),
                      label: const Text('Подключить Telegram Desktop'),
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

class _Status extends StatelessWidget {
  const _Status({required this.controller});

  final Controller controller;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = controller;
    final checking = c.health.values.contains(Health.checking);
    final failing = c.health.values.any((h) => h == Health.failing);
    final status = switch (c.power) {
      Power.off => 'Выключено',
      Power.starting => 'Включаю…',
      Power.stopping => 'Выключаю…',
      Power.on when checking => 'Проверяю…',
      Power.on when failing => 'Есть проблемы',
      Power.on => 'Включено',
    };
    final color = c.power == Power.on && !checking && !failing
        ? t.colorScheme.positive
        : failing
        ? t.colorScheme.error
        : t.colorScheme.onSurfaceVariant;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Text(
        status,
        key: ValueKey(status),
        textAlign: TextAlign.center,
        style: t.textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
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
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.errorContainer,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: c.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: SelectableText(
                text,
                style: TextStyle(color: c.onErrorContainer, height: 1.35),
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
    final t = Theme.of(context);
    final c = controller;
    final enabled = c.isEnabled(service);
    final health = c.health[service.id]!;
    final color = switch (health) {
      Health.idle => t.colorScheme.outlineVariant,
      Health.checking => t.colorScheme.primary,
      Health.ok => t.colorScheme.positive,
      Health.failing => t.colorScheme.error,
    };
    final tooltip = switch (health) {
      Health.idle => 'Не проверено',
      Health.checking => 'Проверяю',
      Health.ok => 'Работает',
      Health.failing => 'Не отвечает',
    };

    return ListTile(
      title: Text(service.title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (health != Health.idle) ...[
            Tooltip(
              message: tooltip,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 14),
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
