# RoundTableZoo — навигатор проекта

Трекер настроения (эмодзи-шкала + дневник + график) с AI-реакциями зверей за круглым столом.
Flutter, Android + iOS в коде, **публикуется пока только Android** (Google Play).

Это индекс, не источник истины — детали читать в файлах ниже, здесь только куда идти.

## Стек и неизменные решения
- State management — **Cubit** (не Bloc-события, не Riverpod).
- Архитектура — **слои, не фичи**: `domain/`/`data/` плоские на всё приложение (один небольшой
  связный домен), `presentation/` делится по экрану (`table`/`diary`/`settings`/`onboarding`).
  Обоснование — `project/architecture/architecture-brief.md`.
- БД — Drift (локально). Миграции между версиями схемы **не нужны до первого релиза** в Store.
- AI — Gemini API **только через backend-прокси** (Cloud Functions + Firestore + Play Integrity),
  ключ никогда не в клиенте.
- Уведомления — `flutter_local_notifications` как сервис в `core/`, **не WorkManager**.
- Время — только через `AppClock`, никогда напрямую `DateTime.now()` в бизнес-логике.
- График — `fl_chart`, строится по `day_entries.moodScore` (эмодзи-шкала), не по тону AI-реакций.

## Where to look — вопрос → требования → реализация

| Вопрос | Требования (что делаем) | Реализация (как делаем) |
|---|---|---|
| Обзор проекта, цели, метрики | `project/prd/00-overview.md` | — |
| Пользовательские сценарии | `project/prd/01-user-scenarios.md` | — |
| Экран «Стол» | `project/prd/02-requirements-table.md` | `project/architecture/architecture-full.md` (`TableCubit`) |
| AI/персонажи/промпты | `project/prd/03-ai-integration.md` | `project/architecture/backend-proxy.md` |
| Дневник/график/CSV | `project/prd/04-requirements-diary.md` | `project/architecture/architecture-full.md` (fl_chart, CSV) |
| Настройки | `project/prd/05-requirements-settings.md` | `project/architecture/database-tables.md` (`user_settings`) |
| Уведомления | `project/prd/06-requirements-notifications.md` | `project/architecture/architecture-full.md` (раздел «Уведомления») |
| Нефункциональные требования | `project/prd/07-non-functional.md` | — |
| Скоуп MVP, acceptance | `project/prd/08-mvp-scope.md` | — |
| Риски, открытые вопросы | `project/prd/09-risks-open-questions.md` | — |
| Публикация в Google Play | `project/prd/10-publishing-play-store.md` | — |
| Раскладка папок, шаблон Cubit, DI, тесты | — | `project/architecture/architecture-brief.md` (чеклист) → `architecture-full.md` (подробно) |
| В каком порядке всё это реализовывать | — | `project/architecture/build-order.md` |
| Таблицы БД | — | `project/architecture/database-tables.md` |
| Схема backend-прокси к Gemini | — | `project/architecture/backend-proxy.md` |
| Чек-лист код-ревью (KISS/DRY/SOLID/null-safety) | — | `project/process/code-quality.md` |
| Реальные грабли этого проекта (пополняется по ходу разработки) | — | `project/process/lessons-learned.md` |

## Чеклист: добавляю новый экран или бизнес-правило
См. `project/architecture/architecture-brief.md` — пошагово (entity → repository → usecase → Cubit →
route → тест), не дублирую здесь.

## Уже решено, не пересматривать без явной причины
- Cubit вместо Riverpod/Bloc-событий.
- Слои (`domain/`/`data/` плоские), не Feature-First — домен слишком маленький и связный, чтобы
  дробить его по фичам; к Feature-First не возвращаемся.
- `moodScore` обязателен, явная шкала эмодзи (не выводится из тона AI-реакций).
- AI-проверка «эмодзи vs тон текста» — не закладывается (см. `project/prd/09-risks-open-questions.md`).
- Ключ Gemini — только за прокси, никогда в клиентском коде.
- WorkManager не используется.
- Миграции БД не нужны до первого релиза в Store — после релиза обязательны.
