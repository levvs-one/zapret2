# Безопасность

`zapret2` работает с системным сетевым состоянием Windows: WinDivert, NRPT и Task Scheduler. Поэтому release pipeline рассматривает install/uninstall и cleanup как часть безопасности, а не как упаковку после сборки.

## Release integrity

- версия upstream zapret2 зафиксирована;
- скачанный engine archive проверяется по SHA-256;
- CI запускает format, analyzer, tests и parser dry-run командной строки zapret2;
- Windows release build собирается в чистом GitHub Actions runner;
- Setup проходит автоматический silent install/uninstall smoke-test;
- релиз содержит Setup, portable ZIP и единый `SHA256SUMS.txt`;
- дочерний `winws2.exe` привязан к kill-on-close Windows Job Object;
- приложение использует single-instance guard;
- собственные NRPT rules удаляются при stop, startup cleanup и uninstall.

## Compatibility identifiers

Публичное имя проекта — `zapret2`. Несколько старых системных идентификаторов `Prosvet` пока сохраняются намеренно: scheduled task, NRPT comment и local state namespace. Это позволяет обновляться поверх 0.2 без потери cleanup state и настроек.

## Сообщить об уязвимости

Не публикуйте рабочий exploit или чувствительные данные в обычном issue. Передайте владельцу репозитория минимальное воспроизводимое описание: версия zapret2, версия Windows, затронутый компонент, влияние и шаги воспроизведения.

Для обычных багов используйте Issues.
