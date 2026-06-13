# T3/BTF -> BACK: Довести OTP/session integration coverage и test fixtures

## Status

- `done`

## Цель

Довести `Email + OTP` auth test infrastructure до reusable состояния: существующее integration coverage должно стать удобной базой для downstream protected backend features, а test fixtures должны уметь получать реальный authenticated client через стандартный backend auth flow без зависимости от Google OAuth.

## Контекст

- `docs/plans/01-auth-backend-plan.md`
- `docs/qa_plan.md`
- `api/docs/auth.md`
- `api/tests/conftest.py`
- current integration coverage: `api/tests/integration/auth/test_request_otp.py`, `api/tests/integration/auth/test_verify_otp.py`, `api/tests/integration/auth/test_session.py`
- session task: `docs/plans/tasks/auth-backend-04-session-bootstrap-logout-and-router.md`
- verify task: `docs/plans/tasks/auth-backend-03-email-otp-verify-and-session-issuance.md`

## Scope

- зафиксировать и при необходимости дорасширить уже существующее integration coverage для `request-otp -> verify-otp -> session -> logout` flow и связанных error/idempotency paths, не дублируя тесты без новой регрессионной ценности
- заменить текущий `authenticated_client` stub в `api/tests/conftest.py` реальным session issuance path через `request-otp -> verify-otp`
- подготовить минимальный reusable auth fixture API для downstream protected endpoint tests; как минимум должен существовать `authenticated_client`, а при необходимости дополнительные helpers вроде `authenticate(...)`, `auth_user` или `auth_session`
- вынести OTP/login boilerplate из отдельных test modules в shared fixtures/helpers там, где это уменьшает копипаст и не скрывает важную проверочную логику самих тестов
- актуализировать implementation-facing docs только если во время реализации auth feature появились согласованные отклонения от `api/docs/auth.md`
- убедиться, что auth tests интегрированы в существующий unit/integration split, а не запускаются через отдельную ad hoc test harness

## Out of scope

- Google OAuth flow
- новые auth capabilities поверх утверждённого `Email + OTP` contract
- frontend E2E auth сценарии
- notebook feature implementation
- смена общей testing strategy вне auth scope

## Технические ограничения

- default `pytest` run должен оставаться пригодным для unit-only execution без обязательной Postgres зависимости
- integration auth tests должны переиспользовать existing `get_db` override и rollback-scoped session pattern
- `authenticated_client` и related fixtures должны получать auth state через реальный backend session issuance path, а не через прямую запись cookie или bypass dependency overrides
- reusable auth fixtures не должны требовать от downstream tests знания `dev_otp`, прямой работы с challenge persistence или ручного чтения `Set-Cookie`
- docs updates должны выравнивать contract/code, а не silently менять утверждённый external behavior

## Acceptance criteria

- [ ] В `api/tests/integration/auth/` или эквивалентной структуре сохранено и при необходимости расширено regression-oriented integration coverage для полного OTP/session flow, включая session bootstrap и logout
- [ ] Integration tests продолжают покрывать как минимум authenticated bootstrap, anonymous bootstrap, logout after valid session, repeated logout и logout with missing/invalid cookie
- [ ] `authenticated_client` fixture больше не является permanent skip stub и может использоваться в protected backend feature tests
- [ ] Reusable auth fixture set позволяет downstream backend tests получать authenticated HTTP client и, где уместно, связанный user/session context без копирования OTP/login boilerplate в каждый test module
- [ ] Общий fixture/helper API зафиксирован в `api/tests/conftest.py` или соседнем shared test module так, чтобы было понятно, какой entry point использовать protected-route tests
- [ ] Auth tests не ломают existing unit/integration marker split
- [ ] Если реализация auth feature отличается от текущего `api/docs/auth.md`, различия явно отражены в docs и не оставлены implicit
- [ ] Полный OTP/session integration suite проходит без ручных monkeypatches вне стандартной test infrastructure

## Verification

- [ ] `cd api && pytest -q`
- [ ] `cd api && pytest -m integration -q`
- [ ] `cd api && pytest -m integration tests/integration/auth -q`
- [ ] `cd api && pytest -m integration tests/integration/auth/test_verify_otp.py tests/integration/auth/test_session.py -q`
- [ ] хотя бы один downstream-style integration test использует новый shared auth fixture entry point без локального OTP/login boilerplate

## Dependencies

- `Depends on T3/BTF -> BACK: Реализовать session bootstrap, logout и подключение auth router`

## Documentation impact

- `Conditional:`
- `docs/qa_plan.md`
- `api/docs/auth.md`
- `api/tests/conftest.py`
- shared auth test helper module рядом с `conftest.py`, если такой появится

## Риски / заметки

- если позже в release scope вернётся обязательный Google OAuth, для него нужен отдельный follow-up hardening task, а не скрытое расширение этой задачи
- не стоит превращать этот task в повторную реализацию auth handlers или массовый rewrite существующих integration tests; он должен фокусироваться на reusable test entry points, deduplication и фиксации регрессионного baseline для downstream protected routes

## Completion update

- `authenticated_client` переведён с `skip`-stub на реальный `request-otp -> verify-otp` flow через shared test helper
- добавлены shared auth test helpers и downstream-style integration test, использующий новый fixture entry point без локального OTP/login boilerplate
- существующее auth integration coverage сохранено; OTP/session boilerplate частично дедуплицирован между test modules
- contract-level docs (`api/docs/auth.md`, `docs/qa_plan.md`) не потребовали изменений; итоговые изменения ограничились task artifact и backend test infrastructure
- отклонений от исходного task scope нет
