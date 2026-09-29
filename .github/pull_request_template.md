## Что меняется

Коротко: что увидит пользователь и зачем это нужно.

## Инварианты / риск

Какие части lifecycle, networking, packaging или UI затронуты. Если системные инварианты не затронуты — так и напишите.

## Проверка

- [ ] `dart format --output=none --set-exit-if-changed lib test tool tools`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `tools/verify-engine-args.sh` — если затронут zapret2
- [ ] Windows smoke — если затронут installer/lifecycle/networking
