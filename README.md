# RoundTableZoo

Мобильное приложение.

![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.13+-0175C2?logo=dart&logoColor=white)
![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2B%20BLoC-4CAF50)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Скриншоты

## Возможности

## Технологии

| Категория | Пакеты |
|---|---|
| Состояние | `flutter_bloc`, `bloc_concurrency` |
| DI | `get_it`, `injectable` |
| Модели | `freezed`, `json_serializable` |
| Навигация | `go_router` |
| Уведомления | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Разрешения | `permission_handler`, `app_settings`, `device_info_plus` |
| Тесты | `bloc_test`, `mocktail` |

Собственный `Result<T>` вместо `dartz`/`rxdart`/`either_dart`.

## Архитектура

## Быстрый старт

```bash
git clone https://github.com/KsArt-IT/RoundTableZoo-Flutter.git
cd RoundTableZoo-Flutter/app

flutter pub get
dart run build_runner build # freezed / injectable / drift / l10n
flutter analyze
flutter test
flutter run
```

Требования: Flutter stable (Dart SDK ^3.12), Xcode (для iOS) или Android SDK.

## Структура проекта

```
app/lib/
├── core/       # DI, роутер, тема, Result<T>, ошибки, утилиты
├── shared/     # переиспользуемое между фичами: энумы, общие виджеты
├── app/        # оболочка: MultiBlocProvider, RootBlocListener, shell (навигация)
└── features/   # table · history · settings · notifications · onboarding — каждая со своими data/domain/presentation
```

## Документация

## License

MIT license. See the [LICENSE](https://github.com/KsArt-IT/RoundTableZoo-Flutter?tab=MIT-1-ov-file) file for details.
