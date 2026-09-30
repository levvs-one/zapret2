<div align="center">

<img src="assets/icon.png" width="86" alt="Просвет">

# Просвет

**Точечный доступ к YouTube, Discord, Telegram и регионально ограниченным сервисам — без системного VPN.**

[![CI](https://github.com/levvs-one/zapret2/actions/workflows/ci.yml/badge.svg)](https://github.com/levvs-one/zapret2/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/levvs-one/zapret2)](https://github.com/levvs-one/zapret2/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

Windows 10/11 · локально · без аккаунта · без телеметрии

</div>

## Что это

Просвет включает только тот механизм, который нужен конкретному сервису:

| Задача | Механизм |
| --- | --- |
| YouTube / Discord | zapret2 + WinDivert, точечно по нужным доменам |
| Gemini / ChatGPT / Claude / Copilot / Spotify | Windows NRPT + Smart DNS |
| Telegram Desktop | локальный MTProto proxy поверх WebSocket |

Остальной трафик не отправляется в общий туннель.

## Установка

1. Откройте [последний релиз](https://github.com/levvs-one/zapret2/releases/latest).
2. Скачайте `Prosvet-<version>-Setup.exe`.
3. Сверьте SHA-256 по `SHA256SUMS.txt`.
4. Установите, запустите и нажмите кнопку питания.

Portable-сборка лежит рядом: `Prosvet-<version>-windows-x64.zip`.

> Бинарники пока не подписаны коммерческим Authenticode-сертификатом. Windows SmartScreen может показать предупреждение о неизвестном издателе.

## Поведение

- рабочая DPI-стратегия запоминается для каждой сети;
- сервисы включаются независимо;
- после выключения Просвет останавливает дочерние процессы и убирает собственные NRPT-правила;
- после сбоя leftovers очищаются на следующем запуске;
- автозапуск реализован одной задачей Task Scheduler;
- корневые сертификаты, браузерные расширения и системные службы не устанавливаются.

Для Telegram после первого включения нажмите **«Подключить Telegram Desktop»**.

## Что нового в 0.2

- новый спокойный Material 3 интерфейс без декоративного шума;
- более компактная главная панель и понятные подписи сервисов;
- переработанная структура настроек и диагностики;
- единый источник версии `VERSION`;
- автоматический release pipeline из `main`;
- Setup + portable ZIP + общий `SHA256SUMS.txt`;
- Dependabot, CODEOWNERS, architecture/troubleshooting docs;
- CI отдельно проверяет формат, analyzer, тесты, parser dry-run zapret2, Windows build и install/uninstall.

История изменений: [CHANGELOG.md](CHANGELOG.md).

## Как устроено

Коротко:

```text
UI
 └─ Controller
    ├─ DPI        → winws2 / WinDivert
    ├─ Smart DNS  → Windows NRPT
    └─ Telegram   → local MTProto-over-WebSocket proxy
```

`Controller` сериализует системные изменения, поэтому start/stop/service toggle не должны гоняться друг с другом и оставлять Windows в промежуточном состоянии.

Подробнее: [docs/architecture.md](docs/architecture.md).

## Если что-то не работает

Основные случаи собраны в [docs/troubleshooting.md](docs/troubleshooting.md).

Короткая версия:

- браузерный Secure DNS / DoH может обходить NRPT;
- второй VPN/zapret/WinDivert-клиент может конфликтовать с Просветом;
- Smart DNS не меняет регион аккаунта;
- при проблемах приложите журнал из **Настройки → О программе → Журнал**.

## Что Просвет меняет в Windows

- запускает `winws2.exe`/WinDivert только для DPI-механизма;
- создаёт NRPT-правила только для выбранных Smart DNS доменов;
- при автозапуске создаёт задачу Task Scheduler `Prosvet`;
- хранит настройки и журнал в `%LOCALAPPDATA%\Prosvet`.

Конфиденциальность: [PRIVACY.md](PRIVACY.md)  
Модель безопасности: [SECURITY.md](SECURITY.md)

## Разработка

Нужен Flutter stable на Windows для production build.

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool tools
flutter analyze
flutter test
```

UI можно запускать без системного движка:

```bash
flutter run -d linux -- --demo
```

Windows build:

```powershell
./tools/fetch-engine.ps1
flutter build windows --release
```

`tools/fetch-engine.ps1` скачивает фиксированную версию zapret2 и проверяет SHA-256.  
`tools/verify-engine-args.sh` прогоняет сформированную командную строку через parser самого zapret2.

## Структура

```text
lib/src/
  catalog/            сервисы и домены
  core/               lifecycle, settings, probes, backend
  engine/zapret/      стратегии и процесс winws2
  engine/smartdns/    NRPT и DNS
  engine/telegram/    локальный Telegram proxy
  platform/           Windows shell/autostart/paths
  ui/                 Material 3 desktop UI

engine/               интеграция с zapret2
installer/            Inno Setup
test/                 unit/widget/lifecycle tests
tool/                 deterministic docs rendering
tools/                build/engine verification helpers
```

## Вклад

Перед изменениями прочитайте [CONTRIBUTING.md](CONTRIBUTING.md). Для сетевого ядра особенно важны отрицательные сценарии: crash, cancel/stop, stale rules, competing operations и malformed input.

## Благодарности

- [bol-van/zapret2](https://github.com/bol-van/zapret2) — DPI engine.
- [Flowseal/tg-ws-proxy](https://github.com/Flowseal/tg-ws-proxy) — идея Telegram-over-WebSocket.
- [Xbox DNS](https://xbox-dns.ru) — Smart DNS provider.

Лицензия проекта: [MIT](LICENSE). Сторонние компоненты: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
