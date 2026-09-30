<div align="center">

<img src="assets/icon.png" width="96" alt="Просвет">

# Просвет

**Точечный доступ к нужным сервисам на Windows — без общего VPN-туннеля и ручной сборки сетевых правил.**

[![Release](https://img.shields.io/github/v/release/levvs-one/zapret2?style=flat-square&label=release)](https://github.com/levvs-one/zapret2/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/levvs-one/zapret2/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/levvs-one/zapret2/actions/workflows/ci.yml)
[![Windows](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D4?style=flat-square)](#системные-требования)
[![License](https://img.shields.io/github/license/levvs-one/zapret2?style=flat-square)](LICENSE)

[Скачать](https://github.com/levvs-one/zapret2/releases/latest) ·
[Установка](docs/getting-started.md) ·
[Чем отличается от zapret2](docs/prosvet-vs-zapret2.md) ·
[Диагностика](docs/troubleshooting.md) ·
[FAQ](docs/faq.md) ·
[Документация](docs/README.md)

</div>

---

## Скачать

Для обычной установки используйте **Setup.exe**. Portable-сборка нужна только если вы не хотите устанавливать приложение.

| Вариант | Для кого | Файл |
| --- | --- | --- |
| **Setup — рекомендуется** | обычная установка, меню Пуск, корректный uninstall | `Prosvet-<version>-Setup.exe` |
| **Portable** | запуск из отдельной папки без установки | `Prosvet-<version>-windows-x64.zip` |
| **Контрольные суммы** | проверка целостности скачанного файла | `SHA256SUMS.txt` |

**[Открыть последний GitHub Release →](https://github.com/levvs-one/zapret2/releases/latest)**

> Текущие Windows-бинарники не подписаны коммерческим Authenticode-сертификатом. SmartScreen может показать «Неизвестный издатель». Скачивайте сборки только из GitHub Releases и при необходимости сверяйте SHA-256.

## Что такое Просвет

Просвет — это Windows-приложение, которое **автоматически выбирает и управляет разными сетевыми механизмами для разных сервисов**.

Он не строит один глобальный туннель для всего трафика.

| Сценарий | Что использует Просвет |
| --- | --- |
| YouTube, Discord | zapret2 + WinDivert для DPI-сценариев |
| ChatGPT, Gemini, Claude, Copilot, Spotify | Windows NRPT + Smart DNS только для нужных доменов |
| Telegram Desktop | локальный MTProto-over-WebSocket proxy |

Остальной трафик не отправляется через общий VPN.

## Чем это отличается от обычного zapret2

**zapret2 — низкоуровневый anti-DPI engine. Просвет — готовый пользовательский продукт вокруг нескольких механизмов, где zapret2 является только одним из backend-компонентов.**

| | Просвет | zapret2 напрямую |
| --- | --- | --- |
| Windows GUI | **Да** | Не основная задача проекта |
| Установка / uninstall | **Setup + cleanup** | Требует собственной обвязки |
| One-click start/stop | **Да** | Конфигурация вручную |
| Готовый каталог сервисов | **Да** | Hostlist/filters настраивает пользователь |
| Память рабочей DPI-стратегии по сети | **Да** | Пользователь управляет стратегиями сам |
| Проверка доступности сервисов | **Да** | Внешняя логика |
| Smart DNS для региональных сервисов | **Да** | Нет |
| Telegram local proxy | **Да** | Нет |
| Tray / autostart / single-instance | **Да** | Внешняя обвязка |
| Полный контроль Lua/filters/hostlists | Ограниченно | **Да** |
| Linux / OpenWRT / BSD | Нет | **Да** |

Если нужен полный контроль над zapret2 — используйте zapret2 напрямую. Если нужен **готовый Windows-клиент для поддерживаемых сценариев**, Просвет убирает ручную настройку, lifecycle и cleanup из пользовательского процесса.

Подробно: **[Просвет vs zapret2](docs/prosvet-vs-zapret2.md)**.

## Интерфейс

<table>
  <tr>
    <td width="50%" align="center">
      <img src="docs/off.png" alt="Главный экран Просвета — выключено"><br>
      <sub>Выключено: системные правила не применены</sub>
    </td>
    <td width="50%" align="center">
      <img src="docs/on.png" alt="Главный экран Просвета — включено"><br>
      <sub>Включено: выбранные сервисы активны и проверены</sub>
    </td>
  </tr>
</table>

<p align="center">
  <img src="docs/settings.png" width="460" alt="Настройки Просвета">
</p>

Скриншоты генерируются детерминированно и проверяются CI как отдельный job.

## Как начать

1. Откройте **[последний релиз](https://github.com/levvs-one/zapret2/releases/latest)**.
2. Скачайте `Prosvet-<version>-Setup.exe`.
3. При желании сверьте SHA-256 по `SHA256SUMS.txt`.
4. Установите приложение и запустите его с требуемыми правами.
5. Оставьте включёнными только нужные сервисы и нажмите кнопку питания.
6. Для Telegram один раз нажмите **«Подключить Telegram Desktop»**.

Полная инструкция, включая SmartScreen, portable, обновление, автозапуск и удаление: **[Установка и первый запуск](docs/getting-started.md)**.

## Поддерживаемые сервисы

| Группа | Сервисы | Механизм |
| --- | --- | --- |
| DPI | YouTube, Discord | zapret2 / WinDivert |
| Smart DNS | ChatGPT, Gemini, AI Studio, NotebookLM, Claude, Copilot, Spotify | Windows NRPT |
| Telegram | Telegram Desktop | локальный MTProto-over-WebSocket proxy |

Поддержка сервиса означает, что в приложении есть готовая конфигурация и lifecycle для него. Это не обещание, что любой провайдер и любая сеть будут вести себя одинаково.

## Что Просвет делает с Windows

При включении приложение может:

- запустить `winws2.exe` / WinDivert для выбранных DPI-сервисов;
- создать собственные NRPT-правила для доменов выбранных Smart DNS-сервисов;
- запустить локальный Telegram proxy;
- при включённом автозапуске создать задачу Task Scheduler `Prosvet`.

При выключении Просвет останавливает свои дочерние процессы и удаляет свои NRPT-правила. После аварийного завершения startup cleanup пытается убрать собственные leftovers на следующем запуске.

Просвет **не устанавливает собственный root CA**, **не расшифровывает HTTPS** и **не создаёт общий системный VPN-туннель**.

## Системные требования

- Windows 10 или Windows 11, x64;
- права администратора для системных сетевых механизмов;
- доступ в интернет для самих сервисов;
- для Smart DNS браузерный Secure DNS / DoH не должен обходить Windows NRPT.

## Безопасность и доверие

Просвет работает с системным сетевым состоянием, поэтому release-процесс специально сделан строгим:

- версия zapret2 зафиксирована;
- архив движка проверяется по SHA-256;
- CI проверяет format, analyzer и tests;
- сформированные аргументы проверяются парсером самого zapret2;
- Windows release build собирается в CI;
- Setup проходит автоматическую установку и удаление;
- release публикуется вместе с `SHA256SUMS.txt`;
- релизные GitHub Actions закреплены по commit SHA.

Подробнее:

- **[Security model](SECURITY.md)**
- **[Privacy](PRIVACY.md)**
- **[Third-party notices](THIRD_PARTY_NOTICES.md)**

## Если что-то не работает

Не начинайте с переустановки Windows и отключения антивируса.

Сначала откройте **[Диагностику](docs/troubleshooting.md)**. Там разобраны:

- Secure DNS / DoH;
- конфликт со вторым VPN, zapret или WinDivert-клиентом;
- регион аккаунта у AI-сервисов;
- Telegram proxy;
- остаточные NRPT-правила;
- предупреждения антивируса.

Если проблема остаётся, создайте **[Issue](https://github.com/levvs-one/zapret2/issues/new/choose)**. Шаблон подскажет, какие данные приложить.

## Документация

| Документ | Что внутри |
| --- | --- |
| **[Установка и первый запуск](docs/getting-started.md)** | Setup, portable, SHA-256, SmartScreen, Telegram, autostart, update, uninstall |
| **[Просвет vs zapret2](docs/prosvet-vs-zapret2.md)** | зачем существует проект и когда лучше использовать raw zapret2 |
| **[FAQ](docs/faq.md)** | VPN, IP, права администратора, телеметрия, Smart DNS |
| **[Диагностика](docs/troubleshooting.md)** | типовые проблемы и данные для issue |
| **[Архитектура](docs/architecture.md)** | Controller, backend-механизмы и lifecycle invariants |
| **[Release process](docs/releasing.md)** | VERSION, CI, Windows smoke-test и публикация |
| **[Contributing](CONTRIBUTING.md)** | сервисы, стратегии, проверки и правила PR |
| **[Changelog](CHANGELOG.md)** | изменения по версиям |

## Архитектура в одном экране

```text
                      ┌──────────────────────┐
                      │      Flutter UI      │
                      └──────────┬───────────┘
                                 │
                      ┌──────────▼───────────┐
                      │      Controller      │
                      │ serialized lifecycle │
                      └──────┬─────┬─────┬───┘
                             │     │     │
                 ┌───────────┘     │     └─────────────┐
                 ▼                 ▼                   ▼
        zapret2 / WinDivert   Windows NRPT      Telegram proxy
             DPI              Smart DNS       MTProto over WS
```

`Controller` сериализует системные изменения: start, stop и изменение сервисов не должны одновременно менять Windows и оставлять систему в промежуточном состоянии.

Подробнее: **[Архитектура](docs/architecture.md)**.

## Разработка

<details>
<summary><strong>Локальная разработка и проверки</strong></summary>

Нужен Flutter stable. Для production Windows build нужна Windows-машина.

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool tools
flutter analyze
flutter test
```

UI без системного движка:

```bash
flutter run -d linux -- --demo
```

Windows release build:

```powershell
./tools/fetch-engine.ps1
flutter build windows --release
```

`tools/fetch-engine.ps1` скачивает фиксированную версию zapret2 и проверяет SHA-256.  
`tools/verify-engine-args.sh` проверяет сформированные аргументы через parser zapret2.

Перед PR прочитайте **[CONTRIBUTING.md](CONTRIBUTING.md)**.

</details>

## Структура репозитория

```text
lib/src/
  catalog/            каталог сервисов и доменов
  core/               lifecycle, settings, probes, backend
  engine/zapret/      стратегии и процесс winws2
  engine/smartdns/    NRPT и Smart DNS
  engine/telegram/    локальный Telegram proxy
  platform/           Windows shell, autostart, paths
  ui/                 desktop UI

engine/               интеграция с zapret2
installer/            Inno Setup
docs/                 пользовательская и техническая документация
test/                 unit, widget и lifecycle tests
tool/                 deterministic UI snapshot rendering
tools/                build и engine verification helpers
```

## Проект и лицензии

Просвет использует и интегрирует сторонние open-source компоненты:

- [bol-van/zapret2](https://github.com/bol-van/zapret2) — DPI engine;
- [Flowseal/tg-ws-proxy](https://github.com/Flowseal/tg-ws-proxy) — основа Telegram-over-WebSocket логики;
- WinDivert и Cygwin runtime — как зависимости zapret2.

Подробности и лицензии: **[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)**.

Код Просвета распространяется по лицензии **[MIT](LICENSE)**.

---

<div align="center">

**Просвет** — небольшой Windows-клиент с ограниченной поверхностью, понятным lifecycle и несколькими сетевыми механизмами вместо одного универсального туннеля.

[Скачать](https://github.com/levvs-one/zapret2/releases/latest) ·
[Документация](docs/README.md) ·
[Сообщить о проблеме](https://github.com/levvs-one/zapret2/issues/new/choose)

</div>
