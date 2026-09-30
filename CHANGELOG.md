# Что нового

## 0.2.0 — 2026-09-30

### Интерфейс

- Пересобран главный экран: компактная power-панель, спокойные поверхности и понятные состояния.
- Сервисы теперь показывают короткое описание прямо в списке.
- Настройки получили нормальную иерархию, подписи и отдельный диагностический блок.
- Радиусы, типографика, кнопки и snackbar приведены к одному Material 3 design system.

### Инженерия

- `VERSION` стал источником версии для release pipeline.
- CI проверяет format, analyzer, tests, parser dry-run zapret2, Windows build и installer smoke-test.
- Release из `main` публикует Setup, portable ZIP и единый `SHA256SUMS.txt`.
- Добавлены Dependabot, CODEOWNERS, architecture и troubleshooting docs.
- Формат docs screenshots остаётся детерминированным и проверяется отдельным тестом.

### Совместимость

- Существующие настройки и локальное состояние 0.1 сохраняются.
- Механизмы zapret2, NRPT и Telegram proxy не меняют пользовательский контракт.

## 0.1.0

Первая версия. Одна кнопка, которая возвращает доступ к выбранным сервисам.

- YouTube и Discord через zapret2.
- Telegram Desktop через локальный MTProto-over-WebSocket proxy.
- Gemini, AI Studio, NotebookLM, ChatGPT, Claude, Copilot и Spotify через Smart DNS.
- Tray, автозапуск, per-service toggles и cleanup системного состояния.
