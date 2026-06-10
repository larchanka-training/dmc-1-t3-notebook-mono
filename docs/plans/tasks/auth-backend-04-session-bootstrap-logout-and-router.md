# T3/BTF -> BACK: Реализовать session bootstrap, logout и подключение auth router

## Status

- `planned`

## Цель

Дать frontend и downstream backend features стабильный способ читать текущее auth state и завершать session, а также официально подключить auth feature в `/api/v1` router tree без нарушения существующих health endpoints.

## Контекст

- `docs/plans/01-auth-backend-plan.md`
- `api/docs/auth.md`
- `api/docs/api_architecture.md`
- `docs/requirements.md`
- verify task: `docs/plans/tasks/auth-backend-03-email-otp-verify-and-session-issuance.md`
- current router state: `api/app/api/v1/router.py`
- current placeholder auth files: `api/app/features/auth/__init__.py`, `api/app/api/v1/routes/auth/__init__.py`

## Scope

- реализовать `GET /api/v1/auth/session`
- реализовать `POST /api/v1/auth/logout`
- подключить auth router в `api/app/api/v1/router.py` под canonical `/api/v1/auth` prefix
- использовать shared current-user/session helpers для anonymous vs authenticated flow
- очищать cookie и инвалидировать active session при logout
- зафиксировать reusable pattern для будущих protected notebook endpoints

## Out of scope

- Google OAuth flow
- notebook CRUD/sync auth enforcement implementation
- frontend auth store и login screen
- новые auth transports кроме session cookie

## Технические ограничения

- API must remain under `/api/v1`
- existing `/api/v1/health` и `/api/v1/system/health` не должны регрессировать
- anonymous session bootstrap должен возвращать `200 OK`, а не `401`
- logout должен инвалидировать server-side session и очищать cookie через centralized cookie helper

## Acceptance criteria

- [ ] `GET /api/v1/auth/session` возвращает `{ "authenticated": false, "user": null }` для anonymous request
- [ ] `GET /api/v1/auth/session` возвращает `{ "authenticated": true, "user": ... }` при наличии valid active session
- [ ] `POST /api/v1/auth/logout` инвалидирует текущую session server-side и очищает auth cookie в response
- [ ] Auth router подключён в `api/app/api/v1/router.py` и доступен под `/api/v1/auth/*`
- [ ] После подключения auth router существующие health endpoints продолжают проходить integration tests

## Verification

- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/auth/test_session.py -q`
- [ ] `cd api && pytest tests/integration/system/test_health.py -q`
- [ ] вручную проверить сценарий `verify-otp -> GET /auth/session -> logout -> GET /auth/session`

## Dependencies

- `Depends on T3/BTF -> BACK: Реализовать verify OTP и выдачу auth session`

## Documentation impact

- `Required:`
- `api/docs/auth.md`
- `api/docs/api_architecture.md`
- `docs/requirements.md`

## Риски / заметки

- если downstream notebook routes начнут реализовываться параллельно, им нельзя обходить shared auth dependencies прямым чтением cookie из handlers

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговые session/bootstrap/logout semantics, router wiring или protected-route reuse pattern изменили зафиксированное поведение
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
