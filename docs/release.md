# Release process

Release pipeline построен так, чтобы tag сам по себе не мог случайно выпустить версию с несогласованными metadata.

## Source of truth

Версия продукта берётся из `pubspec.yaml`.

Для релиза `X.Y.Z` должны одновременно существовать:

- `version: X.Y.Z+...` в `pubspec.yaml`;
- секция `## X.Y.Z` в `CHANGELOG.md`;
- git tag `vX.Y.Z`.

Release workflow проверяет соответствие до Windows build.

## Перед тегом

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool tools
flutter analyze
flutter test
tools/verify-engine-args.sh
```

Также дождитесь зелёного CI на `main`.

Если менялся UI, CI должен подтвердить, что `docs/off.png`, `docs/on.png` и `docs/settings.png` соответствуют реальному widget rendering.

## Windows smoke

Для release-sensitive изменений вручную проверьте:

- install поверх чистой папки;
- запуск и single-instance;
- несколько быстрых ON → OFF;
- отсутствие winws2/proxy/NRPT после OFF;
- crash GUI во включённом состоянии — дочерний winws2 должен завершиться;
- повторный старт после crash — старые NRPT rules очищаются;
- автозапуск;
- занятый Telegram port;
- uninstall — нет задачи `Prosvet`, NRPT rules и `%LOCALAPPDATA%\Prosvet`.

## Создание релиза

После merge:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

GitHub Actions:

1. валидирует tag/version/changelog;
2. запускает format/analyze/tests и winws2 parser check;
3. скачивает pinned zapret2 и сверяет его SHA-256;
4. собирает Windows release;
5. собирает Setup.exe;
6. выполняет install/uninstall smoke;
7. создаёт portable ZIP;
8. создаёт `BUILD_INFO.txt`;
9. вычисляет единый `SHA256SUMS.txt`;
10. создаёт или обновляет GitHub Release.

Workflow сделан повторно запускаемым: если release уже существует, assets загружаются с `--clobber`.
