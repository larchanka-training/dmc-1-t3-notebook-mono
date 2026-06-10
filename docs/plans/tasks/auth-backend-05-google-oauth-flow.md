# T3/BTF -> BACK: Реализовать Google OAuth flow для auth

## Status

- `planned`

## Цель

Подготовить optional follow-up task для альтернативного sign-in flow через Google OAuth, который должен использовать тот же internal user model и тот же backend-managed session cookie contract, что и Email + OTP auth, если этот способ входа войдёт в scope отдельной итерации.

## Контекст

- `docs/plans/01-auth-backend-plan.md`
- `api/docs/auth.md`
- `api/docs/api_architecture.md`
- `docs/system_architecture.md`
- session task: `docs/plans/tasks/auth-backend-04-session-bootstrap-logout-and-router.md`
- ожидаемые areas: `api/app/features/auth/router.py`, `service.py`, `repository.py`, `api/app/integrations/`

## Scope

- реализовать `GET /api/v1/auth/google/start`
- реализовать `GET /api/v1/auth/google/callback`
- добавить provider-facing integration boundary для Google OAuth exchange
- валидировать `state` и provider callback result
- создавать или линковать internal user через `oauth_accounts` или эквивалентный mapping layer
- создавать authenticated backend session через ту же shared session issuance logic, что используется в OTP flow
- реализовать controlled error outcomes для provider denial, invalid state и callback failures

## Out of scope

- frontend OAuth button behavior
- UI redirects/route guards beyond what already требуется backend callback flow
- расширенная account linking UX
- другие OAuth providers

## Технические ограничения

- auth contract должен оставаться session-cookie based
- Google flow не должен дублировать separate session implementation; reuse shared session issuance path
- callback behavior должен работать как backend-controlled auth flow, а не как frontend token exchange
- secrets/provider config не должны утекать в logs или API responses
- этот task optional для текущего `OTP-only` delivery и не должен блокировать hardening для Email + OTP

## Acceptance criteria

- [ ] `GET /api/v1/auth/google/start` инициирует provider redirect с backend-owned `state`
- [ ] `GET /api/v1/auth/google/callback` валидирует callback, создаёт или линкует internal user и устанавливает backend auth session cookie
- [ ] Google-authenticated user затем успешно читается через `GET /api/v1/auth/session`
- [ ] Invalid or missing `state` обрабатывается как controlled auth error, без unhandled exception
- [ ] Provider denial/error path обрабатывается predictably и не создаёт active session

## Verification

- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/auth/test_google_oauth.py -q`
- [ ] пройти manual callback scenario на test/double provider или controlled stub и проверить `Set-Cookie` + session bootstrap

## Dependencies

- `Depends on T3/BTF -> BACK: Реализовать session bootstrap, logout и подключение auth router`

## Documentation impact

- `Required:`
- `api/docs/auth.md`
- `api/docs/api_architecture.md`
- `docs/system_architecture.md`

## Риски / заметки

- task отложен, если текущий delivery scope ограничен `Email + OTP`
- это самый integration-sensitive auth slice: callback URL, proxy/HTTPS и cookie policy нужно валидировать вместе
- если полноценный provider stub пока не готов, минимум нужен deterministic test double для callback exchange

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговый Google OAuth flow, callback semantics или account-linking contract изменили зафиксированное поведение или архитектурные ожидания
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
