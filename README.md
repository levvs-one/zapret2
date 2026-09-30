<div align="center">

<img src="assets/icon.png" width="92" alt="zapret2">

# zapret2

**Точечный Windows-клиент для YouTube, Discord, Telegram и регионально ограниченных сервисов.**  
Без системного VPN, без аккаунта, без телеметрии.

[![CI](https://github.com/levvs-one/zapret2/actions/workflows/ci.yml/badge.svg)](https://github.com/levvs-one/zapret2/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/levvs-one/zapret2?display_name=tag)](https://github.com/levvs-one/zapret2/releases/latest)
[![Windows](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D4)](#установка)
[![License](https://img.shields.io/badge/license-MIT-111111)](LICENSE)

[Скачать](https://github.com/levvs-one/zapret2/releases/latest) ·
[Диагностика](docs/troubleshooting.md) ·
[Архитектура](docs/architecture.md) ·
[Безопасность](SECURITY.md) ·
[Изменения](CHANGELOG.md)

</div>

---

## Зачем

`zapret2` решает разные типы сетевых ограничений разными механизмами и не отправляет весь трафик в один туннель.

| Сценарий | Механизм | Область действия |
| --- | --- | --- |
| YouTube, Discord | upstream [zapret2](https://github.com/bol-van/zapret2) + WinDivert | только выбранные DPI-домены |
| Gemini, ChatGPT, Claude, Copilot, Spotify | Windows NRPT + Smart DNS | только домены выбранных сервисов |
| Telegram Desktop | локальный MTProto-over-WebSocket proxy | только Telegram Desktop |

Остальной трафик идёт напрямую.

> **Важно:** этот репозиторий — самостоятельный Windows desktop client. DPI-движок берётся из upstream-проекта [bol-van/zapret2](https://github.com/bol-van/zapret2), фиксируется по версии и проверяется по SHA-256.

## Интерфейс

<table>
<tr>
<td width="33%" align="center"><img src="docs/off.png" alt="zapret2 выключен"><br><sub>Система не изменена</sub></td>
<td width="33%" align="center"><img src="docs/on.png" alt="zapret2 включён"><br><sub>Выбранные механизмы активны</sub></td>
<td width="33%" align="center"><img src="docs/settings.png" alt="Настройки zapret2"><br><sub>Запуск, сеть и диагностика</sub></td>
</tr>
</table>

Интерфейс намеренно маленький: питание, состояние сервисов и настройки. Стратегии DPI подбираются автоматически и запоминаются отдельно для каждой сети.

## Установка

1. Откройте [Latest Release](https://github.com/levvs-one/zapret2/releases/latest).
2. Скачайте `zapret2-<version>-Setup.exe`.
3. Сверьте SHA-256 по `SHA256SUMS.txt`.
4. Установите приложение и нажмите кнопку питания.

Portable-сборка публикуется рядом: `zapret2-<version>-windows-x64.zip`.

Бинарники пока не подписаны коммерческим Authenticode-сертификатом, поэтому Windows SmartScreen может показывать предупреждение для новой версии.

## Поведение и границы

- DPI-стратегия запоминается отдельно для каждой сети;
- каждый сервис включается независимо;
- stop является lifecycle-барьером: дочерние процессы останавливаются, собственные NRPT-правила удаляются;
- после аварийного завершения stale NRPT rules очищаются на следующем запуске;
- автозапуск использует Task Scheduler;
- корневые сертификаты, браузерные расширения и системные службы не устанавливаются;
- Smart DNS не меняет регион аккаунта, платёжный профиль или номер телефона;
- браузерный Secure DNS / DoH может обходить Windows NRPT.

Подробно: [docs/troubleshooting.md](docs/troubleshooting.md).

## Архитектура

```text
UI
 └─ Controller
    ├─ DPI        → winws2 / WinDivert
    ├─ Smart DNS  → Windows NRPT
    └─ Telegram   → local MTProto-over-WebSocket proxy
```

`Controller` — единая точка управления системным состоянием. Start, stop и изменение сервисов сериализуются, чтобы параллельные операции не оставляли Windows в промежуточном состоянии.

Полная схема и lifecycle-инварианты: [docs/architecture.md](docs/architecture.md).

## Release discipline

Каждый PR и push в `main` проходят:

```text
format
  ↓
analyze
  ↓
tests ───────────────┐
  ↓                  │
zapret parser dry-run│
                     ↓
             Windows release build
                     ↓
             Inno Setup build
                     ↓
          install / uninstall smoke-test
                     ↓
       portable ZIP + Setup + SHA256SUMS
```

Release workflow идемпотентен: повторный push с уже опубликованной версией не создаёт второй релиз.

## Разработка

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool tools
flutter analyze
flutter test
```

UI без системного движка:

```bash
flutter run -d windows -- --demo
```

Windows release build:

```powershell
./tools/fetch-engine.ps1
flutter build windows --release
```

`tools/fetch-engine.ps1` скачивает фиксированную версию upstream zapret2 и проверяет её SHA-256.  
`tools/verify-engine-args.sh` прогоняет сформированную командную строку через parser самого zapret2.

## Структура репозитория

```text
lib/src/
  catalog/            сервисы и домены
  core/               lifecycle, settings, probes, backend
  engine/zapret/      стратегии и процесс winws2
  engine/smartdns/    NRPT и DNS
  engine/telegram/    локальный Telegram proxy
  platform/           Windows shell, autostart, paths
  ui/                 Material 3 desktop UI

engine/               интеграция с upstream zapret2
installer/            Inno Setup
test/                 unit / widget / lifecycle tests
tool/                 deterministic UI snapshots
tools/                build and verification helpers
```

## Совместимость

Начиная с 0.3 публичное имя проекта — **zapret2**. Несколько внутренних Windows-идентификаторов прежнего namespace `Prosvet` сохранены намеренно, чтобы обновление не теряло настройки, Task Scheduler state и cleanup markers.

## Contributing

Перед PR прочитайте [CONTRIBUTING.md](CONTRIBUTING.md). Для сетевого ядра особенно важны отрицательные сценарии: crash, cancel/stop, stale rules, competing operations и malformed input.

## Credits

- [bol-van/zapret2](https://github.com/bol-van/zapret2) — DPI engine.
- [Flowseal/tg-ws-proxy](https://github.com/Flowseal/tg-ws-proxy) — идея Telegram-over-WebSocket.
- [Xbox DNS](https://xbox-dns.ru) — Smart DNS provider.

MIT License · [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
