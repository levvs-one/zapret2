# Architecture

Просвет специально разделён на UI, state/lifecycle и привилегированный backend.

## State flow

`Controller` — единственный источник состояния для UI.

Он хранит:

- `Power`: off / starting / on / stopping;
- health каждого сервиса;
- пользовательские settings;
- текущую ошибку/unsupported reason.

Все backend mutations проходят через одну future-очередь. Это не даёт start, stop и переключению сервиса одновременно менять NRPT, winws2 и Telegram proxy.

Lifecycle generation инвалидирует устаревшую работу после stop или fault. Health generation отдельно отменяет старые проверки доступности.

## Backend boundary

UI не вызывает PowerShell, WinDivert или процессы напрямую.

`Backend` задаёт операции:

- start/stop DPI;
- apply/clear Smart DNS;
- start/stop Telegram proxy;
- network identity;
- probes;
- fault stream.

На Windows используется `WindowsBackend`; в demo/tests — отдельные backend implementations.

## DPI

DPI layer строит аргументы winws2 из каталога и списка стратегий. Командная строка проверяется в CI через dry-run parser upstream zapret2.

Загружаемый upstream engine не хранится целиком в git. `tools/fetch-engine.ps1` скачивает закреплённый release, проверяет SHA-256 и собирает bundle вместе с локальными списками/Lua extensions.

## Smart DNS

Smart DNS реализован через Windows NRPT. Правила создаются только для доменов включённых сервисов и получают comment `Prosvet`, чтобы cleanup работал только с собственными правилами.

## Telegram

Telegram mechanism — локальный MTProto proxy на loopback. Secret создаётся криптографическим RNG и сохраняется при первом запуске, чтобы restart не менял уже настроенный proxy автоматически.

## Windows desktop shell

Native runner отвечает за две вещи, которые нельзя надёжно оставить только Flutter layer:

- single-instance coordination;
- Job Object с `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`.

Tray и hide-on-close находятся в Flutter app shell.

## Data

Настройки и log живут в `%LOCALAPPDATA%\Prosvet`. Installer удаляет локальные данные при штатном uninstall.

## Testing

Тесты разделены по уровням:

- controller/lifecycle;
- NRPT argument construction;
- Telegram protocol pieces;
- autostart;
- UI;
- winws2 argument parser compatibility;
- Windows build + installer install/uninstall smoke;
- deterministic README screenshots.
