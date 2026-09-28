# Как помочь

Больше всего Просвету нужны отчёты «у меня провайдер X, и способ Y работает / не работает». Способы обхода устаревают, и без таких отчётов их не обновить. Открывайте [issue](../../issues/new/choose), шаблон подскажет, что написать.

## Добавить сервис

- Сервис режет провайдер: домены в `engine/lists/`, запись в `lib/src/catalog/services.dart` с `Mechanism.dpi`.
- Сервис не пускает из России: запись с `Mechanism.smartDns` и списком доменов. Поддомены подключаются сами.

Проверьте, что сервис действительно открывается через Xbox DNS: `nslookup gemini.google.com 111.88.96.50` должен вернуть адрес, отличный от обычного.

## Добавить способ обхода

Способы лежат в `lib/src/engine/zapret/strategies.dart`, синтаксис как у `--lua-desync` в [zapret2](https://github.com/bol-van/zapret2/blob/master/docs/manual.md). Новый способ добавляйте в конец списка: номера сохранённых способов у пользователей не должны сдвигаться. В PR напишите, у какого провайдера он помог.

## Перед PR

```bash
dart format lib test
flutter analyze
flutter test
tools/verify-engine-args.sh
```

Интерфейс без движка: `flutter run -d linux -- --demo` или `-d windows -- --demo`.
