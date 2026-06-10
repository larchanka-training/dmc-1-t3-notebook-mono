# T3/BTF -> BACK: Подготовить notebook persistence model и migration baseline

## Status

- `planned`

## Цель

Подготовить durable backend-основу для notebook persistence, чтобы все следующие notebook API задачи опирались на фиксированную модель хранения, ownership и revision metadata, а не на временные договорённости.

## Контекст

- `docs/plans/02-notebook-persistence-plan.md`
- `docs/requirements.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `api/docs/api_architecture.md`
- `api/docs/persistence.md`
- upstream auth dependency: `docs/plans/01-auth-backend-plan.md`
- текущий backend skeleton: `api/app/features/notebooks/__init__.py`, `api/app/api/v1/router.py`

## Scope

- добавить persistence model для notebook storage в `api/app/features/notebooks/models.py`
- зафиксировать поля `id`, `owner_id`, `title`, `content_snapshot`, `revision`, `created_at`, `updated_at`, `last_synced_at`
- обеспечить, что `content_snapshot` может durable хранить notebook-level `tags` и block-level `meta.tags`
- подготовить Alembic migration(s) для notebook table и необходимых owner/revision lookup constraints
- добавить repository primitives для create/get/list/update/delete notebook row
- сохранить snapshot-based model на базе `JSONB`, без отдельной block graph schema

## Out of scope

- HTTP endpoints `/api/v1/notebooks*`
- snapshot validation rules и DTO schemas
- sync endpoint и conflict behavior
- IndexedDB/local working copy persistence
- frontend integration

## Технические ограничения

- durable notebook content должен оставаться одним `JSONB` snapshot per notebook
- snapshot round-trip через repository/model не должен терять notebook-level `tags` и block-level `meta.tags`
- ownership должен быть привязан к authenticated user из auth foundation
- новые зависимости не добавлять без явного одобрения
- backend structure должна остаться `feature-driven with internal layers`

## Acceptance criteria

- [ ] В кодовой базе есть ORM/persistence model для notebook c полями, согласованными с `api/docs/persistence.md`
- [ ] Alembic migration создаёт notebook storage без multi-table block decomposition
- [ ] Repository layer поддерживает create/get/list/update/delete primitives для notebook entity и сохраняет `content_snapshot` без потери notebook-level `tags` и block-level `meta.tags`
- [ ] Ownership и revision fields готовы для последующего CRUD и sync behavior
- [ ] Базовая notebook persistence foundation не ломает существующие system health integration tests

## Verification

- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/test_canary.py -q`
- [ ] применить Alembic migration в integration DB и проверить итоговую схему notebook storage

## Dependencies

- `Depends on T3/BTF -> BACK: Подготовить auth persistence и session foundation`

## Documentation impact

- `Required:`
- `api/docs/persistence.md`
- `api/docs/api_architecture.md`

## Риски / заметки

- если auth user model ещё не зафиксирован в коде, notebook migration нельзя реализовывать через временный owner surrogate
- нужно заранее определить hard delete vs soft delete direction, чтобы не сломать migration baseline следующим task

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговая notebook storage model, ownership semantics или migration strategy изменили зафиксированный contract
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
