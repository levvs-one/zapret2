# Changelog

## 0.1.0

Первый публичный релиз Просвета.

### Added

- Единый Windows-интерфейс для выбранных сервисов без полного VPN-туннеля.
- DPI-механизм на закреплённой версии zapret2 для YouTube и Discord.
- Smart DNS через NRPT только для выбранных доменов.
- Локальный Telegram Desktop proxy через WebSocket.
- Автозапуск через Task Scheduler и работа из системного трея.
- Запоминание рабочей DPI-стратегии отдельно для каждой сети.

### Reliability

- Сериализация системных изменений в одном controller lifecycle.
- Cleanup NRPT и дочерних процессов при выключении и после аварийного завершения.
- Windows Job Object с kill-on-close для дочерних процессов.
- Single-instance desktop shell.
- Проверка SHA-256 закреплённого zapret2 перед сборкой.
- Unit, widget, lifecycle и protocol tests.
- CI-сборка Windows portable и Setup.exe с install/uninstall smoke-test.

### Repository

- Воспроизводимый release pipeline с проверкой версии тега.
- Portable и Setup артефакты плюс единый `SHA256SUMS.txt`.
- Security, privacy, architecture, troubleshooting и release documentation.
- Автоматически проверяемые screenshots README.
