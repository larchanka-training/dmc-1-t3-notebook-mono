# T3/BTF -> BACK: Реализовать request OTP для email auth

## Status

- `done`

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
- генерировать OTP code по auth contract и сохранять challenge без хранения OTP в plain text
- вернуть `challenge_id` и `expires_in_seconds` в success response
- в `local/dev` вернуть `dev_otp`, если это явно разрешено config
- провести OTP delivery через integration boundary/stubbed delivery path без смешивания transport details с router logic
- подготовить controlled error path для invalid payload и throttle/rate-limit conditions
- определить предсказуемое поведение для повторного `request-otp` по тому же normalized email, включая replacement existing challenge или explicit throttle path
- не допускать user enumeration через различающееся поведение для existing vs new email

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
- OTP должен храниться только в hashed/derived form или эквивалентном non-plain representation
- для этого slice достаточно минимальной throttle policy, но она должна быть зафиксирована явно в коде и тестах; silent no-op throttling не допускается
- error semantics должны оставаться пригодными для frontend handling (`422`, `429`)
- success/error semantics не должны позволять определить, существует ли internal user для переданного email

## Acceptance criteria

- [x] `POST /api/v1/auth/request-otp` принимает JSON payload с email и возвращает `200 OK` с `challenge_id` и `expires_in_seconds`
- [x] Email нормализуется и валидируется до создания challenge; invalid payload получает `422 Unprocessable Entity`
- [x] Созданный challenge сохраняет email в нормализованном виде, bounded expiration и OTP в non-plain representation, пригодную для последующего verify step
- [x] В dev-разрешённой конфигурации response может содержать `dev_otp`, в остальных конфигурациях это поле отсутствует
- [x] OTP delivery вызывается через integration boundary или dev-safe stub path без provider-specific логики в router
- [x] Challenge сохраняется через auth persistence layer и может быть использован последующим verify step
- [x] Rate-limit/throttle path возвращает controlled `429` response с stable error handling semantics, а выбранная минимальная throttle policy явно зафиксирована в реализации и тестах
- [x] Повторный `request-otp` по тому же normalized email обрабатывается детерминированно по зафиксированному правилу: existing challenge либо заменяется с обновлением validity state, либо запрос получает explicit throttle response
- [x] Response behavior не различает existing vs new email таким образом, чтобы frontend или внешний клиент мог сделать вывод о наличии internal user

## Verification

- [x] `cd api && .venv/bin/python -m pytest tests/unit -q`
- [x] `cd api && .venv/bin/python -m pytest -m integration tests/integration/auth/test_request_otp.py -q`
- [x] проверить различие response по наличию `dev_otp` в dev-разрешённой и production-like config через automated integration verification
- [x] automated integration verification покрывает повторный `request-otp` по тому же email и подтверждает зафиксированное replacement/throttle behavior
- [x] automated verification подтверждает, что endpoint не меняет observable response semantics в зависимости от того, существует ли internal user для email

## Dependencies

- `Depends on T3/BTF -> BACK: Подготовить auth persistence и session foundation`

## Documentation impact

- `Conditional:`
- `api/docs/auth.md`
- `Optional if implementation fixes currently unspecified throttle/dev behavior:`
- `docs/qa_plan.md`

## Риски / заметки

- если throttle policy пока не финализована, минимум нужно зафиксировать один простой rule set для V1 slice, иначе `429` останется недопределённым для frontend и тестов
- email delivery integration должна оставаться provider boundary; не надо смешивать transport details с router logic
- dev-only возврат `dev_otp` должен контролироваться отдельным config flag, а не только общим `ENVIRONMENT`, чтобы поведение было явно тестируемым
- replacement/throttle policy для повторного запроса challenge должна быть совместима с verify step: downstream `verify-otp` должен уметь отличать active vs replaced challenge без неоднозначности

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговый request-otp flow, error semantics или dev-only behavior изменили зафиксированный contract или implementation guidance
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции

Фактический результат:
- реализован `POST /api/v1/auth/request-otp` с email normalization, OTP hashing, dev-only `dev_otp`, stubbed delivery boundary и простой throttle policy по активному challenge/cooldown
- verification пройдена через `api/.venv` и integration DB `notebook_test`
- документация не обновлялась: итоговый flow не вышел за пределы текущего target contract
