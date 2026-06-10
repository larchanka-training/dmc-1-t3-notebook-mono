# T3/BTF -> BACK: Реализовать verify OTP и выдачу auth session

## Status

- `planned`

## Цель

Завершить основной Email + OTP login flow: по валидному challenge backend должен создать или найти internal user, выдать backend-managed authenticated session и установить secure `HTTP-only` session cookie.

## Контекст

- `docs/plans/01-auth-backend-plan.md`
- `api/docs/auth.md`
- `api/docs/api_architecture.md`
- `docs/system_architecture.md`
- foundation task: `docs/plans/tasks/auth-backend-01-persistence-and-session-foundation.md`
- request task: `docs/plans/tasks/auth-backend-02-email-otp-request.md`
- ожидаемые code areas: `api/app/features/auth/router.py`, `service.py`, `repository.py`, `models.py`

## Scope

- реализовать `POST /api/v1/auth/verify-otp`
- валидировать `challenge_id` и `otp_code`
- обрабатывать success, expired, consumed, replaced и attempt-limit scenarios
- создавать или переиспользовать internal `user` по normalized email из challenge
- инвалидировать успешно использованный OTP challenge
- создавать active backend session и устанавливать auth session cookie
- возвращать `user` и `authenticated_at` в success response
- зафиксировать contract-aligned mapping для `401 Unauthorized` vs `409 Conflict` для no-longer-valid challenge states
- обеспечить детерминированное поведение при повторном или конкурентном `verify-otp` для одного challenge

## Out of scope

- `GET /api/v1/auth/session`
- `POST /api/v1/auth/logout`
- Google OAuth flow
- notebook access protection в downstream features
- frontend login UI

## Технические ограничения

- внешний auth contract должен оставаться cookie-based; frontend-readable bearer token добавлять нельзя
- cookie flags должны выставляться через centralized helper из foundation task
- session issuance logic должна переиспользоваться later by Google OAuth, без OTP-specific coupling
- error status behavior должен оставаться совместимым с `api/docs/auth.md` (`401`, `409`, `429`)
- `otp_challenge_not_found` для отсутствующего или нераспознаваемого `challenge_id` должен возвращаться как controlled `401 Unauthorized`, а не как `409 Conflict`
- повторная или конкурентная верификация одного и того же valid challenge должна завершаться максимум одним successful session issuance

## Acceptance criteria

- [ ] `POST /api/v1/auth/verify-otp` при валидном challenge создаёт или находит user по normalized email challenge, инвалидирует challenge и создаёт active backend session
- [ ] Success response устанавливает backend-managed auth session cookie и возвращает `user` плюс `authenticated_at`
- [ ] Session cookie выставляется через centralized helper и верифицируется как минимум по `HttpOnly`, `Secure`, `SameSite`, `Path` и configured lifetime attributes
- [ ] Invalid or expired OTP возвращает controlled `401 Unauthorized`
- [ ] Unknown `challenge_id` / `otp_challenge_not_found` возвращает controlled `401 Unauthorized`
- [ ] Already consumed, replaced or otherwise no-longer-valid challenge возвращает controlled `409 Conflict`, когда это применимо по contract
- [ ] Attempt exhaustion / throttle path возвращает controlled `429` response
- [ ] Для двух почти одновременных `verify-otp` запросов по одному valid challenge не возникает двойной выдачи session: ровно один запрос может завершиться success, остальные получают controlled non-200 response

## Verification

- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/auth/test_verify_otp.py -q`
- [ ] integration tests покрывают как минимум `otp_invalid`, `otp_expired`, `otp_challenge_not_found`, `otp_attempt_limit_exceeded`, `consumed/replaced challenge` и successful user reuse by normalized email
- [ ] вручную пройти сценарий `request-otp -> verify-otp` и проверить `Set-Cookie` для auth session c `HttpOnly`, `Secure`, `SameSite`, `Path` и expected lifetime attributes

## Dependencies

- `Depends on T3/BTF -> BACK: Подготовить auth persistence и session foundation`
- `Depends on T3/BTF -> BACK: Реализовать request OTP для email auth`

## Documentation impact

- `Conditional:`
- `api/docs/auth.md`
- `api/docs/api_architecture.md` only if session issuance responsibilities or auth route boundaries change
- `docs/system_architecture.md` only if high-level auth/session architecture changes

## Риски / заметки

- эта задача security-sensitive: нельзя логировать raw OTP values или session secrets
- если user creation/linking policy для повторного login ещё не описана в code, её нужно реализовать минимально и детерминированно через lookup по normalized email, не расширяя scope до profile management
- при реализации важно не допустить race condition между mark-as-consumed challenge и session issuance

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговая verify/session issuance logic, cookie behavior или error semantics изменили зафиксированный contract или архитектурные ожидания
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
