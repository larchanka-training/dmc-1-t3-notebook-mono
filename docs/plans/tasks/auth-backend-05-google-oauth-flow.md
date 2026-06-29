# T3/BTF -> BACK: Реализовать Google OAuth flow для auth

## Status

- `done`

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
- зафиксировать backend-controlled redirect contract для success/error callback outcomes
- валидировать `state` через signed short-lived state contract с backend-issued cookie и single-use semantics
- создавать или линковать internal user через `oauth_accounts` mapping layer с explicit verified-email linking policy
- создавать authenticated backend session через ту же shared session issuance logic, что используется в OTP flow
- реализовать controlled error outcomes для provider denial, invalid state, exchange failures и identity/linking conflicts

## Out of scope

- frontend OAuth button behavior
- UI redirects/route guards beyond what already требуется backend callback flow
- расширенная account linking UX
- другие OAuth providers

## Технические ограничения

- auth contract должен оставаться session-cookie based
- Google flow не должен дублировать separate session implementation; reuse shared session issuance path
- callback behavior должен работать как backend-controlled auth flow, а не как frontend token exchange
- `GET /api/v1/auth/google/callback` должен завершаться redirect response, а не public JSON success contract
- success/error redirect targets должны браться из backend config; dynamic `next`/`return_to` без allowlist или signed contract не допускается
- OAuth `state` должен иметь TTL, проверку подписи, сравнение с backend-issued cookie и single-use semantics
- account linking допускается только для Google identity с `email_verified=true`
- primary external identity key должен быть `(provider, provider_subject)`; email можно использовать только как secondary lookup для auto-link/create policy
- secrets/provider config не должны утекать в logs или API responses
- этот task optional для текущего `OTP-only` delivery и не должен блокировать hardening для Email + OTP

## Redirect contract

- `GET /api/v1/auth/google/start` должен:
  - генерировать backend-owned `state`
  - устанавливать short-lived OAuth state cookie
  - возвращать `302` redirect на Google authorize URL
- `GET /api/v1/auth/google/callback` при успешной обработке должен:
  - валидировать `state`
  - выполнить provider code exchange
  - создать или разрешить internal user
  - создать backend auth session cookie
  - очистить temporary OAuth state cookie
  - вернуть `302` redirect на configured frontend success URL
- `GET /api/v1/auth/google/callback` при ошибке должен:
  - не создавать active session
  - очистить temporary OAuth state cookie
  - вернуть `302` redirect на configured frontend error URL с коротким стабильным `code` в query string

## State model

- backend должен генерировать cryptographically random `nonce` для каждого `/google/start`
- `state` должен быть signed backend payload с минимумом полей:
  - `nonce`
  - `iat` или equivalent issued-at timestamp
  - `flow` или equivalent flow marker
  - optional signed `return_path`, только если этот behavior явно добавлен в scope
- backend должен устанавливать отдельный short-lived cookie для state validation:
  - `HttpOnly`
  - `Secure`
  - `SameSite=Lax`
  - path-scoped к Google OAuth auth routes или более узкому auth callback path
- callback validation должна включать:
  - наличие query `state`
  - наличие backend-issued state cookie
  - проверку подписи payload
  - проверку TTL
  - сравнение `nonce` из query payload и cookie-backed state
  - проверку single-use semantics без повторного успешного consume
- after success и after failure state artifacts должны очищаться

## Account linking policy

- backend должен искать existing OAuth link по `(provider, provider_subject)` before any email-based resolution
- если existing OAuth link найден, backend должен аутентифицировать связанного internal user
- если existing OAuth link не найден и provider identity не содержит verified email, backend должен завершать flow controlled auth error без создания user или session
- если existing OAuth link не найден и `email_verified=true`:
  - backend должен искать existing internal user по normalized email
  - если user найден, backend должен автоматически создать OAuth link к этому user
  - если user не найден, backend должен создать new internal user и затем создать OAuth link
- linking policy не должна создавать duplicate internal users для одного normalized email
- uniqueness constraints для `users.email` и `(provider, provider_subject)` должны учитываться как часть expected persistence contract

## Error codes / responses

- provider-facing callback flow должен использовать stable frontend-facing error codes через redirect query param, а не раскрывать raw provider details
- минимум должны поддерживаться следующие error codes:
  - `oauth_state_missing`
  - `oauth_state_invalid`
  - `oauth_state_expired`
  - `oauth_access_denied`
  - `oauth_provider_error`
  - `oauth_exchange_failed`
  - `oauth_identity_unverified`
  - `oauth_account_conflict`
- `oauth_access_denied` должен использоваться для user/provider denial path
- `oauth_provider_error` должен использоваться для other provider-returned OAuth errors
- `oauth_exchange_failed` должен использоваться для token exchange failure, malformed provider callback result или userinfo fetch failure
- `oauth_identity_unverified` должен использоваться, если provider identity не даёт verified email, достаточный для create/link policy
- `oauth_account_conflict` должен использоваться для deterministic persistence/linking conflicts, при которых session не должна создаваться
- backend logs могут содержать internal diagnostic details, но redirect-visible error code должен оставаться коротким и stable

## Acceptance criteria

- [ ] `GET /api/v1/auth/google/start` инициирует `302` provider redirect с backend-owned signed `state` и short-lived OAuth state cookie
- [ ] `GET /api/v1/auth/google/callback` при success path валидирует callback, создаёт или линкует internal user, устанавливает backend auth session cookie и возвращает `302` на configured frontend success URL
- [ ] Google-authenticated user затем успешно читается через `GET /api/v1/auth/session`
- [ ] Invalid, missing или expired `state` обрабатывается как controlled auth error, без unhandled exception, с cleanup temporary state artifacts и stable frontend-facing error code
- [ ] Provider denial/error path обрабатывается predictably через configured error redirect и не создаёт active session
- [ ] Existing OAuth link ищется по `(provider, provider_subject)`; automatic email-based link/create допускается только для Google identity с `email_verified=true`
- [ ] Callback flow не допускает duplicate internal users для одного normalized email при success path

## Verification

- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/auth/test_google_oauth.py -q`
- [ ] integration coverage включает success, provider denial, invalid state, expired state, exchange failure и existing-user auto-link paths
- [ ] пройти manual callback scenario на deterministic test/double provider или controlled stub и проверить `302` redirect targets, `Set-Cookie`, state cleanup и session bootstrap

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

- `Status` updated to `done`
- updated `api/docs/auth.md` with signed state, callback redirect, and stable frontend-facing error-code semantics
- updated `api/docs/api_architecture.md` to reflect OAuth state validation and verified-email linking responsibility in the `auth` feature
- `docs/system_architecture.md` did not require changes because it already captured Google OAuth as a backend-controlled auth flow at the system boundary
- implementation stayed within the original task scope; no scope delta to record
