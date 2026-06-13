# T3/BTF -> BACK: Реализовать notebook create и list endpoints

## Status

- `planned`

## Цель

Дать authenticated users первый реальный notebook persistence flow: создание notebook и получение списка только своих notebook summaries. Это открывает переход frontend от mock notebook list к реальному backend-backed list flow.

## Контекст

- `docs/plans/02-notebook-persistence-plan.md`
- `api/docs/persistence.md`
- `api/docs/api_architecture.md`
- `docs/qa_plan.md`
- auth dependency: `docs/plans/01-auth-backend-plan.md`
- prerequisite specs:
  - `docs/plans/tasks/notebook-persistence-01-model-and-migration-baseline.md`
  - `docs/plans/tasks/notebook-persistence-02-schemas-and-snapshot-validation.md`

## Scope

- реализовать `POST /api/v1/notebooks`
- реализовать `GET /api/v1/notebooks`
- использовать shared auth current-user dependency для owner-scoped access
- создавать notebook с canonical initial snapshot и `revision = 1`
- возвращать только notebook summaries текущего пользователя в list response
- определить стабильное list ordering для response

## Out of scope

- `GET /api/v1/notebooks/{notebook_id}`
- `PATCH /api/v1/notebooks/{notebook_id}`
- `DELETE /api/v1/notebooks/{notebook_id}`
- `/sync` endpoint
- frontend query integration

## Технические ограничения

- все notebook endpoints требуют authenticated session cookie
- anonymous request должен получать `401 Unauthorized`
- create/list behavior должен использовать repository/service layer, а не прямой DB access в router
- initial notebook snapshot должен соответствовать Version 1 notebook schema и включать `tags: []`

## Acceptance criteria

- [ ] `POST /api/v1/notebooks` создаёт notebook текущего пользователя и возвращает contract-stable notebook response
- [ ] Новый notebook стартует с `revision = 1`, canonical initial `content_snapshot` и пустым notebook-level `tags`
- [ ] `GET /api/v1/notebooks` возвращает только notebook summaries текущего пользователя
- [ ] Anonymous requests к create/list endpoints получают `401 Unauthorized`
- [ ] Integration coverage подтверждает, что notebooks разных users не смешиваются в list response

## Verification

- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/notebooks/test_collection.py -q`
- [ ] вручную проверить сценарий `login -> create notebook -> list notebooks`

## Dependencies

- `Depends on T3/BTF -> BACK: Добавить shared auth session и current-user dependencies`
- `Depends on T3/BTF -> BACK: Зафиксировать notebook schemas и snapshot validation rules`

## Documentation impact

- `Required:`
- `api/docs/persistence.md`
- `docs/qa_plan.md`

## Риски / заметки

- если list ordering не будет явно зафиксирован сейчас, frontend tests позже могут зацементировать случайное поведение
- initial snapshot не должен включать runtime placeholders или local-only metadata и не должен пропускать обязательное поле `tags`

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговый create/list contract или ordering semantics изменили зафиксированное поведение
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
