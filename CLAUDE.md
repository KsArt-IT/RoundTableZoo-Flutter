# RoundTableZoo — навигатор проекта

Трекер настроения (эмодзи-шкала + дневник + график) с AI-реакциями зверей за круглым столом.
Flutter, Android + iOS в коде, **публикуется пока только Android** (Google Play).

Это индекс, не источник истины — детали читать в файлах ниже, здесь только куда идти.

## Карта репозитория

| Папка | Что там |
|---|---|
| `app/` | **Сам Flutter-проект** — `lib/`, `test/`, `pubspec.yaml`. Все команды (`flutter`, `dart run build_runner`) запускать отсюда, не из корня. |
| `proxy/` | Служба-посредник к Gemini на Cloudflare Workers (TypeScript) — единственное место, где живёт ключ Gemini. Команды `npm`, `wrangler` запускать отсюда, не из корня. |
| `project/` | Продуктовая и архитектурная документация (`prd/`, `architecture/`, `process/`). **В git не хранится** (`.gitignore`), живёт только локально. |
| `specs/` | Спеки по фичам в формате spec-kit: `spec.md` → `plan.md` → `tasks.md` + `contracts/`. Нумерация = порядок реализации. |
| `.specify/`, `.claude/skills/speckit-*` | Инструментарий spec-kit (шаблоны, скрипты, скиллы `/speckit-*`). |
| `tools/` | Служебные скрипты. `kanban.py` собирает доску прогресса из чекбоксов `specs/*/tasks.md` в `project/kanban.html` (`python3 tools/kanban.py --open`). |

`project/` и `specs/` не дублируют друг друга: `project/` отвечает на «почему так решено» и
«как устроено приложение в целом», `specs/` — на «что именно делаем в этой фиче и какими шагами».
При расхождении между ними побеждает `specs/` соответствующей фичи, если она уже реализована.

### Реализованные фичи

| Спека | Что дала |
|---|---|
| `specs/001-app-foundation` | DI, `Result<T>`/`AppFailure`, роутер, l10n, `AppClock`, схема БД |
| `specs/002-settings-and-reminders` | `SettingsRepository`, тема/язык, `installId`, уведомления |
| `specs/003-onboarding` | Экран онбординга, `hasSeenOnboarding` |
| `specs/004-table-screen` | Экран «Стол»: раскладка по кругу, 4 состояния персонажа, баблы, AI-вызов |
| `specs/005-diary-screen` | Дневник: пагинация, график `fl_chart`, экспорт CSV |
| `specs/006-table-surface-render` | Поверхность стола: `tableSurfaceRect` + `TableSurfacePainter` внутри `RoundTableLayout`. Код готов, открыта только T007 — ручной прогон `quickstart.md` на устройстве |
| `specs/007-ai-proxy` | AI-прокси `proxy/` на Cloudflare Workers: ключ Gemini на сервере, Play Integrity, суточные лимиты, kill switch, ротация якорей промпта. Клиент получает настоящие реплики через `POST /react` |
| `specs/008-character-voice-tts` | Озвучка реплик персонажей через `flutter_tts` (полностью офлайн): `core/speech/` (`SpeechSynthesizer`, `SilentModeProbe`), `TableVoiceCubit` (очередь, стоп-условия), тембр персонажа в `characters.json` (`CharacterVoice`), управление тумблером в Настройках |

**Перед началом любой задачи по фиче** — прочитай
[project/process/lessons-learned.md](project/process/lessons-learned.md) целиком (он короткий).
Это не архивная документация, а актуальный список того, что реально ломалось в прошлых сессиях
этого проекта (DRY-нарушения, Flutter API-семантика, mocktail, freezed, координация Cubit↔Cubit,
тесты, ломающиеся от новых глобальных Bloc-ов) — экономит именно те переписывания, которые ты
иначе повторишь.

## Стек и неизменные решения
- State management — **Cubit** (не Bloc-события, не Riverpod).
- Архитектура — **слои, не фичи**: `domain/`/`data/` плоские на всё приложение (один небольшой
  связный домен), `presentation/` делится по экрану (`table`/`diary`/`settings`/`onboarding`).
  Обоснование — `project/architecture/architecture-brief.md`.
- БД — Drift (локально). Миграции между версиями схемы **не нужны до первого релиза** в Store.
- AI — Gemini API **только через backend-прокси** `proxy/` на **Cloudflare Workers**
  (D1 — счётчики лимитов, KV — конфиг/kill switch и кэш OAuth-токена, Play Integrity — допуск
  клиента). Ключ Gemini никогда не в клиенте. Cloud Functions + Firestore рассматривались и
  **отвергнуты** (требуют плана Blaze с картой) — `project/architecture/backend-proxy.md` v0.2.
- Уведомления — `flutter_local_notifications` как сервис в `core/`, **не WorkManager**.
  Расписание — `AndroidScheduleMode.inexactAllowWhileIdle`, точные будильники не запрашиваем.
- Озвучка реплик — `flutter_tts`, **полностью офлайн**, `core/speech/` + `TableVoiceCubit`.
- Время — только через `AppClock`, никогда напрямую `DateTime.now()` в бизнес-логике.
- График — `fl_chart`, строится по `day_entries.moodScore` (эмодзи-шкала), не по тону AI-реакций.
**Не используем:** `dartz`, `rxdart`, `either_dart` — используем собственный `Result<T>`.

### Исходники pub-пакетов

Не искать по всему диску (`find /`). Исходники уже скачаны в `~/.pub-cache/hosted/pub.dev/`,
по одной папке на `<пакет>-<версия>`. Версию брать из `app/pubspec.lock`:

```bash
grep -A2 "^  <package>:" app/pubspec.lock   # находит установленную версию
ls ~/.pub-cache/hosted/pub.dev/<package>-<версия>/
```
### DRY и бритва Оккама

Перед тем как завести новую сущность (класс, entity, DTO, usecase, extension), проверь: не
существует ли уже тип с таким же составом полей/смыслом в другом слое или фиче. Если существует —
переиспользуй его напрямую, не оборачивай в почти-дубликат. Если новый тип действительно нужен —
он должен добавлять поле/поведение, которого не было, а не копировать существующее.

То же для структуры данных: не разносите одни и те же поля по двум местам (например, поле,
которое уже лежит внутри `X`, не должно ещё раз плоско дублироваться в `Y`, где можно просто
хранить `X` как значение). Одна причина для существования — один тип, который её выражает.

## Where to look — вопрос → требования → реализация

| Вопрос | Требования (что делаем) | Реализация (как делаем) |
|---|---|---|
| Обзор проекта, цели, метрики | `project/prd/00-overview.md` | — |
| Пользовательские сценарии | `project/prd/01-user-scenarios.md` | — |
| Экран «Стол» | `project/prd/02-requirements-table.md` | `project/architecture/architecture-full.md` (`TableCubit`), `specs/004-table-screen/` |
| AI/персонажи/промпты | `project/prd/03-ai-integration.md` | `project/architecture/backend-proxy.md`, `specs/007-ai-proxy/`, код прокси — `proxy/src/` |
| Озвучка реплик (TTS) | `project/prd/03-ai-integration.md` | `specs/008-character-voice-tts/`, `app/lib/core/speech/` |
| Дневник/график/CSV | `project/prd/04-requirements-diary.md` | `project/architecture/architecture-full.md` (fl_chart, CSV), `specs/005-diary-screen/` |
| Настройки | `project/prd/05-requirements-settings.md` | `project/architecture/database-tables.md` (`user_settings`) |
| Уведомления | `project/prd/06-requirements-notifications.md` | `project/architecture/architecture-full.md` (раздел «Уведомления») |
| Нефункциональные требования | `project/prd/07-non-functional.md` | — |
| Скоуп MVP, acceptance | `project/prd/08-mvp-scope.md` | — |
| Риски, открытые вопросы | `project/prd/09-risks-open-questions.md` | — |
| Публикация в Google Play | `project/prd/10-publishing-play-store.md` | — |
| Раскладка папок, шаблон Cubit, DI, тесты | — | `project/architecture/architecture-brief.md` (чеклист) → `architecture-full.md` (подробно) |
| В каком порядке всё это реализовывать | — | `project/architecture/build-order.md` |
| Таблицы БД | — | `project/architecture/database-tables.md` |
| Схема backend-прокси к Gemini | — | `project/architecture/backend-proxy.md` (v0.2, Cloudflare Workers) |
| Имя приложения и локализация ярлыка | — | раздел «Имя приложения» ниже |
| Анимация персонажей, состояния места за столом, поверхность стола | `project/prd/02-requirements-table.md` | `project/architecture/character-animation.md` → `specs/004-table-screen/`, `specs/006-table-surface-render/` |
| Чек-лист код-ревью (KISS/DRY/SOLID/null-safety) | — | `project/process/code-quality.md` |
| Реальные грабли этого проекта (пополняется по ходу разработки) | — | `project/process/lessons-learned.md` |

## Чеклист: добавляю новый экран или бизнес-правило
См. `project/architecture/architecture-brief.md` — пошагово (entity → repository → usecase → Cubit →
route → тест), не дублирую здесь.

## Имя приложения

Одно имя в трёх местах, и все три обязаны совпадать:

| Где | Файл |
|---|---|
| Внутри приложения | `app/lib/l10n/intl_{en,ru,uk}.arb` → `appTitle` — **источник правды** |
| Ярлык Android | `app/android/app/src/main/res/values{,-ru,-uk}/strings.xml` → `app_name`, манифест ссылается `@string/app_name` |
| Ярлык iOS | `app/ios/Runner/InfoPlist.xcstrings` → `CFBundleDisplayName` (String Catalog) |

Сейчас: `Round Table` / `Круглый стол` / `Круглий стіл`.

Совпадение не косметическое: строка `settingsReminderPermissionDenied` просит пользователя найти
приложение в системных настройках именно под `appTitle` — разъедется, и подсказка начнёт врать.

Две ловушки:
- Ярлык следует **системной** локали, а не языку, выбранному в Настройках приложения. Это штатное
  поведение; обойти можно только per-app language (Android 13+, `res/xml/locales_config.xml`).
- В `ios/Runner.xcodeproj/project.pbxproj` в `knownRegions` должны быть `ru` и `uk` — String
  Catalog компилируется по ним. Если их нет, локализованное имя может работать локально из
  `DerivedData` и пропасть на чистой сборке.

## Открытые вопросы — не считать решёнными

- **Чем анимировать персонажей.** `lottie: 3.5.1` подключён, ветка `Lottie.asset` в
  `CharacterAvatar` написана и покрыта тестами, но **ассетов нет ни одного** и в
  `assets/characters/characters.json` нет полей `idleAnimation`/`talkAnimation`.
  Выбран и реализован **вариант A — анимация кодом**: поле `face` в конфиге +
  `AnimalFacePainter` (один painter на всех) + `AnimalShape` (вся геометрия зверя как данные) +
  `TalkPose`/`TalkPoseDriver` («слоговая речь»: рот открывается рывками в такт слогам, амплитуда =
  `CharacterReaction.intensity`). Нарисованы кот (лежит на боку), пёс (сидит) и крокодил
  (лежит плашмя); бегемот остаётся на эмодзи-аватаре, пока ему не добавят `FaceShape` и
  `AnimalShape`. У крокодила рот — не эллипс, а нижняя челюсть на шарнире, и её углы
  **отрицательные**: морда смотрит влево, положительный поворот поднимал бы челюсть в череп.
  **Новый зверь = запись в `AnimalShape`, а не новый painter.**
  Это не закрывает вопрос: реализацию можно заменить, граница
  `TableCubit → CharacterVisualState → CharacterAvatar` для этого и держится.
  **Не выпиливать Lottie и не добавлять Rive без явного решения.** Разбор —
  `project/architecture/character-animation.md`, `project/prd/09-risks-open-questions.md`
  (вопрос 8).
  Ключевое ограничение, которое нельзя нарушать: **idle-место не анимируется вовсе**, и любое
  движение обязано само останавливаться. Постоянно запланированный кадр валит
  `pumpAndSettle()` во всех widget-тестах Стола.
- Остальные открытые вопросы — `project/prd/09-risks-open-questions.md`.

## Уже решено, не пересматривать без явной причины
- Cubit вместо Riverpod/Bloc-событий.
- Слои (`domain/`/`data/` плоские), не Feature-First — домен слишком маленький и связный, чтобы
  дробить его по фичам; к Feature-First не возвращаемся.
- `moodScore` обязателен, явная шкала эмодзи (не выводится из тона AI-реакций).
- AI-проверка «эмодзи vs тон текста» — не закладывается (см. `project/prd/09-risks-open-questions.md`).
- Ключ Gemini — только за прокси, никогда в клиентском коде.
- WorkManager не используется.
- Миграции БД не нужны до первого релиза в Store — после релиза обязательны.
