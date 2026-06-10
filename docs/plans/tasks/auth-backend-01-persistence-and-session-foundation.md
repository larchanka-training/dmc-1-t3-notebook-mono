# T3/BTF -> BACK: Подготовить auth persistence и session foundation

## Status

- `planned`

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
- добавить auth-related settings для OTP TTL, session TTL, cookie name и cookie flags в shared config
- реализовать repository/service-level primitives для поиска и хранения auth session без привязки к конкретному endpoint
- реализовать shared helpers/dependencies для `current user` и `optional current user`
- централизовать создание и очистку auth session cookie
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

- [ ] В кодовой базе существуют persistence-модели и миграции для `users`, `otp_challenges` и `sessions`, совместимые с `api/docs/auth.md`
- [ ] В `api/app/core/config.py` или эквивалентном shared config добавлены настройки для OTP/session TTL и cookie policy без hardcoded environment-specific значений в handlers
- [ ] Реализованы shared helpers/dependencies для чтения session cookie, получения active session и optional/current user flow
- [ ] Создание и очистка session cookie централизованы и могут переиспользоваться из verify/logout/Google OAuth handlers
- [ ] Базовый auth foundation не ломает существующие integration tests для system health

## Verification

- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/system/test_health.py -q`
- [ ] применить Alembic migration в integration DB и проверить, что auth tables создаются без ручных правок

## Dependencies

- `None`

## Documentation impact

- `Required:`
- `api/docs/auth.md`
- `api/docs/api_architecture.md`
- `docs/system_architecture.md`

## Риски / заметки

- в текущем inspected state Alembic tree не был подтверждён; naming/baseline migration strategy нужно сверить до реализации
- cookie flags должны учитывать local HTTPS/proxy режим, иначе дальнейшие auth задачи будут проверяться в искусственной конфигурации

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговая persistence/session модель, cookie policy или auth dependencies изменили зафиксированное поведение или архитектурные границы
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
