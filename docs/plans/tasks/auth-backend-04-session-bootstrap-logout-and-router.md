# T3/BTF -> BACK: Реализовать session bootstrap и logout для auth

## Status

- `done`

## Цель

Дать frontend и downstream backend features стабильный способ читать текущее auth state и завершать session через backend-managed session cookie, не меняя утверждённый `/api/v1` auth contract и не ломая существующие health endpoints.

## Контекст

- `docs/plans/01-auth-backend-plan.md`
- `api/docs/auth.md`
- `api/docs/api_architecture.md`
- `docs/requirements.md`
- verify task: `docs/plans/tasks/auth-backend-03-email-otp-verify-and-session-issuance.md`
- current auth router state: `api/app/api/v1/router.py`
- shared auth dependencies and cookie helpers: `api/app/features/auth/dependencies.py`, `api/app/features/auth/cookies.py`
- expected code areas: `api/app/features/auth/router.py`, `service.py`, `schemas.py`, `repository.py`, `api/tests/integration/auth/test_session.py`

## Scope

- реализовать `GET /api/v1/auth/session`
- реализовать `POST /api/v1/auth/logout`
- использовать shared current-user/session helpers для anonymous vs authenticated flow
- очищать auth session cookie через centralized helper и инвалидировать active session при logout
- зафиксировать reusable pattern для будущих protected notebook endpoints
- определить безопасное и предсказуемое поведение `logout` для anonymous request и уже невалидной session
- сохранить canonical доступность auth endpoints под `/api/v1/auth/*` и проверить, что существующий router wiring не регрессировал

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
- `GET /api/v1/auth/session` не должен продлевать session lifetime побочным эффектом, если такое поведение явно не предусмотрено общим auth contract
- `POST /api/v1/auth/logout` должен оставаться безопасным для повторного вызова и не раскрывать, была ли session валидной до запроса
- `POST /api/v1/auth/logout` должен возвращать `200 OK` с body `{ "logged_out": true }` согласно `api/docs/auth.md`

## Acceptance criteria

- [ ] `GET /api/v1/auth/session` возвращает `{ "authenticated": false, "user": null }` для anonymous request
- [ ] `GET /api/v1/auth/session` возвращает `{ "authenticated": true, "user": ... }` при наличии valid active session
- [ ] `GET /api/v1/auth/session` не создаёт новую session и не меняет auth state для anonymous request
- [ ] `POST /api/v1/auth/logout` возвращает `200 OK` с body `{ "logged_out": true }`
- [ ] `POST /api/v1/auth/logout` инвалидирует текущую session server-side и очищает auth cookie в response через centralized helper
- [ ] Logout response очищает cookie с согласованными атрибутами как минимум по `Path`, `HttpOnly`, `Secure` и `SameSite`, чтобы браузер действительно удалял auth cookie
- [ ] `POST /api/v1/auth/logout` для anonymous request или уже невалидной session остаётся controlled и idempotent response без утечки внутреннего session state
- [ ] Существующий auth router остаётся доступен под `/api/v1/auth/*`, а task не вводит дублирующий или обходной router path
- [ ] Существующие health endpoints продолжают проходить integration tests после добавления session/logout handlers
- [ ] Reusable auth dependency pattern задокументирован или зафиксирован в кодовой структуре так, чтобы downstream protected endpoints использовали shared current-user/session helpers, а не прямое чтение cookie в handlers

## Verification

- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/auth/test_session.py -q`
- [ ] `cd api && pytest tests/integration/system/test_health.py -q`
- [ ] integration tests покрывают как минимум authenticated bootstrap, anonymous bootstrap, logout after valid session, repeated logout и logout with missing/invalid cookie
- [ ] вручную проверить сценарий `verify-otp -> GET /auth/session -> logout -> GET /auth/session` и убедиться, что logout response очищает cookie с ожидаемыми атрибутами удаления

## Dependencies

- `Depends on T3/BTF -> BACK: Реализовать verify OTP и выдачу auth session`

## Documentation impact

- `Conditional:`
- `api/docs/auth.md`
- `api/docs/api_architecture.md` only if protected-route reuse pattern or auth feature responsibilities change
- `docs/requirements.md` only if task reveals mismatch with project-level auth/session requirements

## Риски / заметки

- если downstream notebook routes начнут реализовываться параллельно, им нельзя обходить shared auth dependencies прямым чтением cookie из handlers
- если `logout` будет реализован как `204 No Content` или иной success status вместо `200 OK`, это нужно заранее сверить с frontend expectations и при необходимости явно зафиксировать в `api/docs/auth.md`

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговые session/bootstrap/logout semantics, router wiring или protected-route reuse pattern изменили зафиксированное поведение
- реализация выполнена; `Status` обновлён на `done`
- дополнительные doc changes в `api/docs/auth.md`, `api/docs/api_architecture.md` и `docs/requirements.md` для этого task не потребовались
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
