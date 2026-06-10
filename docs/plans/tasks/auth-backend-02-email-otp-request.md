# T3/BTF -> BACK: Реализовать request OTP для email auth

## Status

- `planned`

## Цель

Добавить первый user-visible auth endpoint для Email + OTP, чтобы frontend мог запросить OTP challenge для нормализованного email и получить contract-stable ответ для следующего шага login flow.

## Контекст

- `docs/plans/01-auth-backend-plan.md`
- `api/docs/auth.md`
- `api/docs/api_architecture.md`
- `docs/qa_plan.md`
- foundation task: `docs/plans/tasks/auth-backend-01-persistence-and-session-foundation.md`
- ожидаемые code areas: `api/app/features/auth/router.py`, `schemas.py`, `service.py`, `repository.py`, `api/app/integrations/`

## Scope

- реализовать `POST /api/v1/auth/request-otp`
- нормализовать и валидировать email payload по contract rules
- создавать OTP challenge через auth persistence layer
- вернуть `challenge_id` и `expires_in_seconds` в success response
- в `local/dev` вернуть `dev_otp`, если это явно разрешено config
- подготовить controlled error path для invalid payload и throttle/rate-limit conditions

## Out of scope

- проверка OTP и создание authenticated session
- `GET /api/v1/auth/session`
- `POST /api/v1/auth/logout`
- Google OAuth flow
- реальная production email provider provisioning

## Технические ограничения

- endpoint должен оставаться `POST /api/v1/auth/request-otp`
- production-like response не должен раскрывать `dev_otp`
- auth behavior должен использовать foundation primitives, а не дублировать session/persistence logic в router
- error semantics должны оставаться пригодными для frontend handling (`422`, `429`)

## Acceptance criteria

- [ ] `POST /api/v1/auth/request-otp` принимает JSON payload с email и возвращает `200 OK` с `challenge_id` и `expires_in_seconds`
- [ ] Email нормализуется и валидируется до создания challenge; invalid payload получает `422 Unprocessable Entity`
- [ ] В dev-разрешённой конфигурации response может содержать `dev_otp`, в остальных конфигурациях это поле отсутствует
- [ ] Challenge сохраняется через auth persistence layer и может быть использован последующим verify step
- [ ] Rate-limit/throttle path возвращает controlled `429` response с stable error handling semantics

## Verification

- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/auth/test_request_otp.py -q`
- [ ] вручную вызвать `POST /api/v1/auth/request-otp` в dev config и проверить различие response между dev и non-dev cookie/email settings

## Dependencies

- `Depends on T3/BTF -> BACK: Подготовить auth persistence и session foundation`

## Documentation impact

- `Required:`
- `api/docs/auth.md`
- `api/docs/api_architecture.md`
- `docs/qa_plan.md`

## Риски / заметки

- если throttle policy пока не финализована, минимум нужно зафиксировать stable error surface без silent fallback
- email delivery integration должна оставаться provider boundary; не надо смешивать transport details с router logic

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговый request-otp flow, error semantics или dev-only behavior изменили зафиксированный contract или implementation guidance
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
