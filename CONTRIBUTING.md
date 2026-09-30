# Contributing

Просвет — небольшой системный Windows-клиент. Для него важнее предсказуемый lifecycle и воспроизводимые проверки, чем количество функций.

## С чего начать

Перед изменением посмотрите:

- [архитектуру](docs/architecture.md);
- [диагностику](docs/troubleshooting.md);
- [сравнение с zapret2](docs/prosvet-vs-zapret2.md);
- [release flow](docs/releasing.md).

## Главные инварианты

Изменение не должно ломать следующие свойства:

1. системные start/stop/service mutations не гоняются параллельно;
2. OFF означает завершённый cleanup;
3. приложение не оставляет собственные NRPT-правила после штатного выключения;
4. дочерний `winws2.exe` не должен переживать аварийное завершение GUI;
5. второй экземпляр не должен независимо управлять системным состоянием;
6. uninstall удаляет собственный autostart, NRPT и локальные данные.

## Добавить сервис

### DPI

Если сервис режет провайдер:

- добавьте домены в `engine/lists/`;
- добавьте запись в `lib/src/catalog/services.dart` с `Mechanism.dpi`;
- добавьте/обновите тесты;
- укажите в PR провайдера и наблюдаемое поведение.

### Smart DNS

Если сервис сам ограничивает регион:

- добавьте `Mechanism.smartDns`;
- укажите минимальный список доменов;
- проверьте, что системный DNS flow действительно меняет результат.

Не добавляйте широкие wildcard-наборы «на всякий случай».

## Добавить DPI-стратегию

Стратегии находятся в `lib/src/engine/zapret/strategies.dart`.

Новый вариант добавляйте в конец списка: сохранённые индексы стратегий у существующих пользователей не должны внезапно означать другое поведение.

Аргументы должны проходить parser dry-run:

```bash
tools/verify-engine-args.sh
```

## Перед PR

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool tools
flutter analyze
flutter test
tools/verify-engine-args.sh
```

UI без реальных системных изменений:

```bash
flutter run -d windows -- --demo
```

## Windows / installer changes

Если изменение затрагивает WinDivert, NRPT, Task Scheduler, single-instance, tray, installer или cleanup, одной unit-проверки недостаточно.

Минимальный ручной smoke-test:

- чистая установка;
- включение/выключение механизмов;
- несколько быстрых циклов ON → OFF;
- отсутствие `winws2.exe` после OFF;
- отсутствие NRPT-правил Просвета после OFF;
- принудительное завершение GUI во включённом состоянии;
- повторный запуск после crash;
- single-instance;
- autostart после нового входа в Windows;
- Telegram proxy после перезапуска;
- сценарий занятого локального порта;
- uninstall через Windows Settings.

Проверка NRPT:

```powershell
Get-DnsClientNrptRule | Where-Object { $_.Comment -eq 'Prosvet' }
```

После штатного OFF правил Просвета быть не должно.

## Pull request

PR должен объяснять:

- что меняется для пользователя;
- зачем это нужно;
- какие системные механизмы затрагиваются;
- чем изменение проверено;
- какой провайдер/сеть использовались, если это DPI-изменение.

Не отключайте analyzer/test ради зелёного CI без отдельного технического обоснования.

## Release

Release-процесс описан отдельно: [docs/releasing.md](docs/releasing.md).
