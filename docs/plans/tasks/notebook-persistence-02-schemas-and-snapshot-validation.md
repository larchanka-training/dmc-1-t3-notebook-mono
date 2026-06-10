# T3/BTF -> BACK: Зафиксировать notebook schemas и snapshot validation rules

## Status

- `planned`

## Цель

Зафиксировать backend-side contract для notebook payloads и snapshot validation, чтобы CRUD endpoints принимали и возвращали только Version 1 notebook shape и не смешивали durable notebook state с runtime artifacts.

## Контекст

- `docs/plans/02-notebook-persistence-plan.md`
- `api/docs/persistence.md`
- `api/docs/api_architecture.md`
- `docs/project.md`
- `docs/system_architecture.md`
- foundation task: `docs/plans/tasks/notebook-persistence-01-model-and-migration-baseline.md`
- frontend canonical shape reference: `ui/docs/notebook_schema.md`

## Scope

- добавить request/response DTOs для notebook summary, full notebook, create payload и metadata patch payload
- реализовать validation rules для `content_snapshot`
- ограничить block types до `text` и `code`
- зафиксировать правила для `blocks` order, `metadata.version`, `content_snapshot.id`, `content_snapshot.title`, `content_snapshot.tags` и `block.meta.tags`
- исключить runtime outputs и execution session state из durable snapshot contract
- добавить service-level helpers для согласования notebook row metadata и `content_snapshot`

## Out of scope

- реализация HTTP routes
- sync endpoint `/api/v1/notebooks/{notebook_id}/sync`
- local persistence в IndexedDB
- execution runtime output normalization

## Технические ограничения

- notebook format должен оставаться structured `JSON`
- durable snapshot не должен включать `text`, `object`, `table`, `chart`, `error` outputs как stored notebook state
- validation должна требовать notebook-level `tags` и `meta.tags` у каждого блока независимо от его типа
- validation rules должны быть пригодны и для create, и для later sync flows
- API contract остаётся under `/api/v1`

## Acceptance criteria

- [ ] В кодовой базе существуют DTO/schema модели для notebook summary, full notebook, create payload и patch payload
- [ ] Validation отвергает notebook snapshots с неподдерживаемыми block types или malformed content shape
- [ ] Validation требует `content_snapshot.tags` как список строк и `block.meta.tags` как список строк для каждого блока
- [ ] Runtime outputs и execution session data не проходят как часть durable `content_snapshot`
- [ ] Правила согласования `title`/`id` между notebook row и snapshot определены и переиспользуемы в service layer
- [ ] Integration tests покрывают минимум valid snapshot и invalid payload paths для missing tags, non-array tags и non-string tag values

## Verification

- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/notebooks/test_validation.py -q`

## Dependencies

- `Depends on T3/BTF -> BACK: Подготовить notebook persistence model и migration baseline`

## Documentation impact

- `Required:`
- `api/docs/persistence.md`
- `ui/docs/notebook_schema.md`

## Риски / заметки

- если frontend mock notebook shape уже расходится с canonical snapshot, это нужно явно зафиксировать как follow-up, а не размывать validation
- не надо проектировать block-level partial update contract внутри этой задачи

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговые snapshot rules, DTO shape или validation boundaries изменили зафиксированный contract
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
