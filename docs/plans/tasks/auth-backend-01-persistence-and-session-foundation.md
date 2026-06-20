# T3/BTF -> BACK: Подготовить auth persistence и session foundation

## Status

- `done`

## Цель

Подготовить backend-основу для auth feature, чтобы следующие auth-задачи могли опираться на фиксированную persistence-модель, конфигурацию session cookie и переиспользуемые session/current-user helpers без архитектурных догадок.

## Контекст

- `docs/plans/01-auth-backend-plan.md`
- `docs/requirements.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `api/docs/api_architecture.md`
- `api/docs/auth.md`
- текущий backend skeleton: `api/app/features/auth/__init__.py`, `api/app/api/v1/routes/auth/__init__.py`
- текущая DB/session инфраструктура: `api/app/db/session.py`, `api/app/core/config.py`

## Scope

- добавить auth persistence entities для `users`, `otp_challenges`, `sessions` и подготовить optional support для `oauth_accounts`
- добавить shared SQLAlchemy declarative base / metadata wiring для новых auth models, чтобы Alembic мог строить migration tree из application models без ручного списка table definitions
- добавить auth-related settings для OTP TTL, session TTL, cookie name и cookie flags в shared config
- реализовать repository/service-level primitives для поиска, создания, отзыва и чтения active auth session без привязки к конкретному endpoint
- реализовать shared helpers/dependencies для чтения session cookie из request, разрешения active session, `current user` и `optional current user`
- централизовать создание и очистку auth session cookie
- зафиксировать единый source of truth для cookie attributes и session validity checks, чтобы verify/session/logout handlers не расходились по поведению
- подготовить Alembic migration(s) для auth tables и constraints

## Out of scope

- `POST /api/v1/auth/request-otp`
- `POST /api/v1/auth/verify-otp`
- `GET /api/v1/auth/session`
- `POST /api/v1/auth/logout`
- Google OAuth endpoints
- frontend auth integration

## Технические ограничения

- backend architecture должна остаться `feature-driven with internal layers`
- API contract остаётся session-cookie based; bearer token flow добавлять нельзя
- API routes должны оставаться под `/api/v1`
- новые зависимости не добавлять без явного одобрения
- использовать текущий shared DB access pattern через `api/app/db/session.py`

## Acceptance criteria

- [x] В кодовой базе существуют persistence-модели, shared ORM metadata wiring и миграции для `users`, `otp_challenges` и `sessions`, совместимые с `api/docs/auth.md`
- [x] Решение по `oauth_accounts` зафиксировано явно: support отложен до Google OAuth slice; полуготовые persistence artifacts не добавлялись
- [x] В `api/app/core/config.py` или эквивалентном shared config добавлены настройки для OTP/session TTL и cookie policy без hardcoded environment-specific значений в handlers
- [x] Реализованы shared helpers/dependencies для чтения session cookie, разрешения active session, а также `current user` и `optional current user` flow
- [x] Создание и очистка session cookie централизованы и могут переиспользоваться из verify/logout/Google OAuth handlers, при этом default cookie policy согласована с `api/docs/auth.md` (`HttpOnly`, `Path=/`, `SameSite=Lax` или строже, environment-gated `Secure`)
- [x] Shared session resolution path детерминированно обрабатывает missing, revoked и expired session как anonymous/no-active-session result без endpoint-specific развилок в handlers
- [x] Базовый auth foundation не ломает существующие integration tests для system health

## Verification

- [x] `cd api && .venv/bin/python -m pytest tests/unit -q`
- [x] `cd api && .venv/bin/python -m pytest -m integration tests/integration/system/test_health.py -q`
- [x] применить Alembic migration в integration DB и проверить, что auth tables создаются без ручных правок

## Dependencies

- `None`

## Files likely to change

- `api/app/core/config.py`
- `api/app/db/`
- `api/app/features/auth/`
- `api/alembic/env.py`
- `api/alembic/versions/*`
- `api/tests/unit/`
- `api/tests/integration/`

## Documentation impact

- `Conditional:`
- `api/docs/auth.md`
- `Optional if implementation clarifies behavior beyond current target contract:`
- `api/docs/api_architecture.md`
- `docs/system_architecture.md`

## Риски / заметки

- в текущем inspected state Alembic tree ещё не подключён к application metadata (`target_metadata` пока не указывает на ORM models); baseline wiring нужно сверить до реализации
- cookie flags должны учитывать local HTTPS/proxy режим, иначе дальнейшие auth задачи будут проверяться в искусственной конфигурации
- не оставлять полуготовую persistence-схему для `oauth_accounts`: частично созданная таблица без usage contract усложнит Google OAuth slice

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговая persistence/session модель, cookie policy или auth dependencies изменили зафиксированное поведение или архитектурные границы
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции

Фактический результат:
- реализованы shared auth models/repository/service/dependencies, cookie helpers, config settings и Alembic wiring/migration
- `oauth_accounts` сознательно не добавлялись; support оставлен для Google OAuth slice без промежуточной схемы
- verification пройдена через `api/.venv` и локальную integration DB `notebook_test`
- документация не обновлялась: итоговая реализация осталась в пределах текущего target contract
