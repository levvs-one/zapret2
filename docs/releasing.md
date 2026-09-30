# Выпуск новой версии

Этот документ описывает release flow Просвета. Цель — чтобы релиз можно было повторить без ручной магии.

## 1. Подготовить версию

Обновите:

- `VERSION`;
- `version:` в `pubspec.yaml`;
- секцию новой версии в `CHANGELOG.md`.

CI проверяет, что `VERSION` совпадает с version name из `pubspec.yaml`.

## 2. Проверить локально

Минимум:

```bash
dart format --output=none --set-exit-if-changed lib test tool tools
flutter analyze
flutter test
tools/verify-engine-args.sh
```

На Windows:

```powershell
./tools/fetch-engine.ps1
flutter build windows --release
```

## 3. Проверить системный lifecycle

Автоматический CI проверяет build и installer, но перед значимым релизом нужен ручной Windows smoke-test.

Проверьте:

- чистую установку Setup;
- start / stop всех механизмов;
- отсутствие `winws2.exe` после OFF;
- отсутствие NRPT leftovers после OFF;
- crash + следующий запуск;
- single-instance;
- tray;
- автозапуск;
- Telegram proxy;
- uninstall cleanup.

Подробный список есть в [CONTRIBUTING.md](../CONTRIBUTING.md).

## 4. Pull request

Release-изменения должны пройти обычный PR в `main`.

Перед merge убедитесь, что зелёные:

- format;
- analyzer;
- tests;
- zapret2 parser dry-run;
- UI snapshots;
- Windows build;
- installer install/uninstall smoke-test.

## 5. Merge в main

Release workflow запускается на push в `main`.

Он читает версию из `VERSION`.

Если release с таким тегом уже существует, workflow завершается без создания дубликата.

## 6. Что публикуется

GitHub Release содержит:

- `Prosvet-<version>-Setup.exe`;
- `Prosvet-<version>-windows-x64.zip`;
- `SHA256SUMS.txt`.

Release notes извлекаются из соответствующей секции `CHANGELOG.md`.

## 7. После релиза

Проверьте:

1. release не draft;
2. assets скачиваются;
3. SHA-256 совпадает;
4. Setup устанавливается;
5. portable ZIP запускается после распаковки;
6. README ведёт на актуальный latest release.

Не меняйте уже опубликованный бинарник под тем же номером версии. Если нужен исправленный build — выпускайте новую patch-версию.
