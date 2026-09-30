## Что меняется

<!-- Что увидит пользователь или разработчик? Без пересказа diff. -->

## Зачем

<!-- Какую проблему решает изменение? -->

## Риск / системное состояние

<!-- Что затрагивается: WinDivert, NRPT, Telegram proxy, Task Scheduler, installer, ничего из перечисленного. -->

## Проверка

- [ ] `dart format --output=none --set-exit-if-changed lib test tool tools`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] Для изменений zapret2: `tools/verify-engine-args.sh`
- [ ] Для Windows lifecycle/install: проверен релевантный smoke-test

Провайдер / сеть / сервисы, если это сетевое изменение:

<!-- Например: Ростелеком, домашний; YouTube/Discord. -->
