# T3/BTF -> BACK: Довести OTP/session integration coverage и test fixtures

## Status

- `planned`

## Цель

Закрыть `Email + OTP` auth slice до reusable состояния: integration tests должны покрывать основные success/error paths для OTP и session endpoints, а test infrastructure должна уметь получать реальный authenticated client для последующих protected backend features без зависимости от Google OAuth.

## Контекст

- `docs/plans/01-auth-backend-plan.md`
- `docs/qa_plan.md`
- `api/docs/auth.md`
- `api/tests/conftest.py`
- session task: `docs/plans/tasks/auth-backend-04-session-bootstrap-logout-and-router.md`
- verify task: `docs/plans/tasks/auth-backend-03-email-otp-verify-and-session-issuance.md`

## Scope

- добавить integration coverage для request OTP, verify OTP, session bootstrap и logout success/error paths
- заменить или дополнить текущий `authenticated_client` stub в `api/tests/conftest.py` реальным session issuance path
- подготовить reusable auth-related fixtures/factories для downstream protected endpoint tests
- актуализировать implementation-facing docs, если во время реализации auth feature появились согласованные отклонения от `api/docs/auth.md`
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
- docs updates должны выравнивать contract/code, а не silently менять утверждённый external behavior

## Acceptance criteria

- [ ] В `api/tests/integration/auth/` или эквивалентной структуре есть integration tests для OTP request, OTP verify, session bootstrap и logout
- [ ] `authenticated_client` fixture больше не является permanent skip stub и может использоваться в protected backend feature tests
- [ ] Auth tests не ломают existing unit/integration marker split
- [ ] Если реализация auth feature отличается от текущего `api/docs/auth.md`, различия явно отражены в docs и не оставлены implicit
- [ ] Полный OTP/session integration suite проходит без ручных monkeypatches вне стандартной test infrastructure

## Verification

- [ ] `cd api && pytest -q`
- [ ] `cd api && pytest -m integration -q`
- [ ] отдельно прогнать OTP/session-focused suite и убедиться, что она может быть baseline для notebook protected-route tasks

## Dependencies

- `Depends on T3/BTF -> BACK: Реализовать session bootstrap, logout и подключение auth router`

## Documentation impact

- `Required:`
- `docs/qa_plan.md`
- `api/docs/auth.md`
- `api/tests/conftest.py`

## Риски / заметки

- если позже в release scope вернётся обязательный Google OAuth, для него нужен отдельный follow-up hardening task, а не скрытое расширение этой задачи

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговые auth test fixtures, verification flow или contract-alignment notes изменили текущую implementation-facing guidance
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
