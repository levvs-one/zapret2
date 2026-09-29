import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prosvet/src/app.dart';
import 'package:prosvet/src/core/controller.dart';
import 'package:prosvet/src/core/settings.dart';

import 'controller_test.dart' show FakeBackend;

void main() {
  testWidgets('power button turns everything on', (tester) async {
    final c = Controller(
      backend: FakeBackend(),
      settings: Settings.defaults(),
      saveSettings: (_) {},
      probeInterval: Duration.zero,
    );
    await c.init(connect: false);
    await tester.pumpWidget(
      ProsvetApp(
        controller: c,
        autostart: null,
        logPath: '',
        version: 't',
        desktopShell: false,
      ),
    );

    expect(find.text('Выключено'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Без замедления'), findsNothing);
    expect(find.text('Закрытые для России'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Включить'));
    await tester.pumpAndSettle();
    expect(c.power, Power.on);
    expect(find.text('Включено'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Spotify'), 200);
    expect(find.byType(Switch), findsWidgets);
  });

  testWidgets('settings keep secondary controls in submenus', (tester) async {
    final c = Controller(
      backend: FakeBackend(),
      settings: Settings.defaults(),
      saveSettings: (_) {},
      probeInterval: Duration.zero,
    );
    await c.init(connect: false);
    await tester.pumpWidget(
      ProsvetApp(
        controller: c,
        autostart: null,
        logPath: '',
        version: 't',
        desktopShell: false,
      ),
    );

    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();

    expect(find.text('Запуск'), findsOneWidget);
    expect(find.text('Сеть'), findsOneWidget);
    expect(find.text('О программе'), findsOneWidget);
    expect(find.text('Включать сразу'), findsNothing);

    await tester.tap(find.text('Запуск'));
    await tester.pumpAndSettle();
    expect(find.text('Включать сразу'), findsOneWidget);
  });
}
