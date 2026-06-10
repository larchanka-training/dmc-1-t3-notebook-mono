# T3/BTF -> BACK: Зафиксировать revision semantics и sync-ready notebook responses

## Status

- `planned`

## Цель

Подготовить notebook persistence contract к следующему sync этапу без реализации самого `/sync`: зафиксировать revision, timestamp и response semantics так, чтобы later sync work строился на стабильной CRUD-базе, а не пересобирал storage contract заново.

## Контекст

- `docs/plans/02-notebook-persistence-plan.md`
- `api/docs/persistence.md`
- `docs/system_architecture.md`
- `api/docs/api_architecture.md`
- prerequisite spec: `docs/plans/tasks/notebook-persistence-05-delete-and-router-wiring.md`

## Scope

- проверить и при необходимости доработать semantics для `revision`, `updated_at`, `created_at`, `last_synced_at`
- привести CRUD responses к sync-ready shape, ожидаемой следующими notebook stages
- задокументировать service/repository invariants, от которых позже будет зависеть `/sync`
- убедиться, что durable notebook records не включают runtime-only state

## Out of scope

- реализация `POST /api/v1/notebooks/{notebook_id}/sync`
- `409 Conflict` response path
- frontend sync store и conflict UX
- IndexedDB/local metadata

## Технические ограничения

- newly created notebook должен оставаться с `revision = 1`
- CRUD update paths не должны случайно эмулировать sync behavior через `base_revision`
- `last_synced_at` не должен получать misleading semantics до реального sync endpoint

## Acceptance criteria

- [ ] Создание и metadata update notebook сохраняют стабильные revision/timestamp semantics, совместимые с `api/docs/persistence.md`
- [ ] CRUD responses содержат поля, на которые later sync direction сможет опереться без изменения storage contract
- [ ] Durable notebook records не включают runtime outputs или execution session state
- [ ] В коде и документации зафиксированы invariants, достаточные для добавления `/sync` отдельной задачей

## Verification

- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/notebooks -q`

## Dependencies

- `Depends on T3/BTF -> BACK: Реализовать notebook deletion и подключение notebooks router`

## Documentation impact

- `Required:`
- `api/docs/persistence.md`
- `docs/system_architecture.md`

## Риски / заметки

- если `last_synced_at` начнёт обновляться в обычном CRUD path, later sync UX и backend semantics станут противоречивыми
- эту задачу нельзя использовать как повод заранее добавлять partial sync API

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговые revision/timestamp semantics или response invariants изменили зафиксированный contract
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
