<div align="center">

<img src="assets/icon.png" width="88" alt="Просвет">

# Просвет

**Точечный Windows-клиент для YouTube, Discord, Telegram и выбранных сервисов — без полного VPN-туннеля.**

[![CI](https://github.com/levvs-one/zapret2/actions/workflows/ci.yml/badge.svg)](https://github.com/levvs-one/zapret2/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/levvs-one/zapret2)](https://github.com/levvs-one/zapret2/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

<img src="docs/off.png" width="250" alt="Просвет выключен">&nbsp;&nbsp;<img src="docs/on.png" width="250" alt="Просвет включен">&nbsp;&nbsp;<img src="docs/settings.png" width="250" alt="Настройки Просвета">

</div>

---

Просвет включает только механизм, который нужен выбранному сервису. Остальной трафик не отправляется в общий VPN-туннель.

- **YouTube и Discord** — DPI-обход через закреплённую версию [zapret2](https://github.com/bol-van/zapret2).
- **Telegram Desktop** — локальный MTProto-прокси через WebSocket.
- **Gemini, ChatGPT, Claude, Copilot, Spotify и другие выбранные домены** — Smart DNS через Windows NRPT.
- Рабочая DPI-стратегия запоминается отдельно для каждой сети.
- Каждый сервис можно включить или выключить отдельно.
- При выключении приложение останавливает дочерние процессы и удаляет созданные им NRPT-правила.

## Скачать

Откройте [последний релиз](https://github.com/levvs-one/zapret2/releases/latest).

Для Windows 10/11 x64 публикуются:

- `Prosvet-<version>-Setup.exe` — обычная установка;
- `Prosvet-<version>-windows-x64.zip` — portable-сборка;
- `SHA256SUMS.txt` — SHA-256 обоих артефактов.

Бинарники пока не подписаны коммерческим Authenticode-сертификатом, поэтому SmartScreen может показать предупреждение о неизвестном издателе. Проверяйте, что файл скачан именно из GitHub Releases, и сверяйте SHA-256.

```powershell
Get-FileHash .\Prosvet-0.1.0-Setup.exe -Algorithm SHA256
```

## Использование

1. Установите или распакуйте Просвет.
2. Запустите приложение с подтверждением UAC.
3. Оставьте включёнными только нужные сервисы.
4. Нажмите большую кнопку питания.

Для Telegram после первого включения нажмите **«Подключить Telegram Desktop»**. В настройках можно включить автозапуск и автоматическое применение выбранных правил.

## Что меняется в Windows

Просвет работает с системными сетевыми механизмами, поэтому ему нужны права администратора.

Он может:

- запускать `winws2.exe` и WinDivert, пока активен DPI-обход;
- создавать NRPT-правила только для выбранных Smart DNS-доменов;
- слушать `127.0.0.1:1443` для локального Telegram-прокси;
- создать одну задачу Task Scheduler `Prosvet`, если включён автозапуск;
- хранить настройки и журнал в `%LOCALAPPDATA%\Prosvet`.

Он **не** устанавливает корневые сертификаты, браузерные расширения или постоянную Windows-службу и не собирает телеметрию.

Подробнее: [PRIVACY.md](PRIVACY.md) и [SECURITY.md](SECURITY.md).

## Надёжность

Системные изменения сериализуются одним контроллером: start/stop, переключение сервиса и аварийное выключение не должны выполняться одновременно.

Windows runner дополнительно обеспечивает:

- единственный экземпляр приложения;
- Job Object с `KILL_ON_JOB_CLOSE`, чтобы дочерний `winws2.exe` завершался вместе с GUI;
- очистку старых NRPT-правил при следующем старте после сбоя;
- install/uninstall smoke-test в CI;
- закреплённую версию zapret2 с проверкой SHA-256 перед сборкой.

Архитектура и границы компонентов: [docs/architecture.md](docs/architecture.md).

## Если что-то не работает

Короткая версия:

- сервис красный → **Настройки → Сеть → Проверить сервисы**;
- Smart DNS не влияет на браузер → проверьте, не включён ли в браузере собственный DNS-over-HTTPS;
- одновременно работает другой VPN/zapret/перехватчик → временно отключите его для диагностики;
- антивирус ругается на WinDivert → не отключайте защиту вслепую, сначала проверьте источник и SHA-256 релиза.

Полная диагностика: [docs/troubleshooting.md](docs/troubleshooting.md).

## Разработка

Нужен актуальный Flutter stable.

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool tools
flutter analyze
flutter test
```

Интерфейс можно запускать без системного движка:

```bash
flutter run -d linux -- --demo
# или
flutter run -d windows -- --demo
```

Windows release build:

```powershell
./tools/fetch-engine.ps1
flutter build windows --release
```

CI отдельно проверяет синтаксис аргументов winws2 парсером самого zapret2, собирает Windows-приложение и Setup.exe, устанавливает его в временную папку и выполняет штатный uninstall.

## Структура

```text
lib/src/
  catalog/            каталог сервисов и доменов
  core/               состояние, lifecycle и backend boundary
  engine/zapret/      стратегии и запуск winws2
  engine/smartdns/    NRPT и DNS-проверки
  engine/telegram/    локальный MTProto/WebSocket proxy
  platform/           Windows shell, paths, autostart
  ui/                 presentation layer

engine/               локальные Lua/list extensions для zapret2
installer/            Inno Setup
test/                 unit/widget/lifecycle tests
tool/                 screenshot tooling
tools/                build/engine verification scripts
```

Как вносить изменения: [CONTRIBUTING.md](CONTRIBUTING.md).  
Как устроен релиз: [docs/release.md](docs/release.md).  
История изменений: [CHANGELOG.md](CHANGELOG.md).  
Сторонние компоненты: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Лицензия

MIT. См. [LICENSE](LICENSE).
