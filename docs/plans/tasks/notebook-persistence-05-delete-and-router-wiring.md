# T3/BTF -> BACK: Реализовать notebook deletion и подключение notebooks router

## Status

- `planned`

## Цель

Завершить минимальный notebook CRUD lifecycle и официально подключить notebooks feature в `/api/v1`, чтобы backend предоставлял полный базовый durable notebook API перед следующими sync-related этапами.

## Контекст

- `docs/plans/02-notebook-persistence-plan.md`
- `api/docs/persistence.md`
- `api/docs/api_architecture.md`
- prerequisite spec: `docs/plans/tasks/notebook-persistence-04-item-and-metadata-update-endpoints.md`
- current router state: `api/app/api/v1/router.py`

## Scope

- реализовать `DELETE /api/v1/notebooks/{notebook_id}`
- выбрать и реализовать delete strategy для Version 1: hard delete или soft delete
- подключить notebooks router в `api/app/api/v1/router.py`
- убедиться, что router wiring не ломает existing health/system endpoints
- сохранить reusable protected-route pattern для notebook feature

## Out of scope

- `/api/v1/notebooks/{notebook_id}/sync`
- explicit conflict handling
- notebook export
- frontend delete confirmation UX

## Технические ограничения

- notebook routes должны остаться под `/api/v1/notebooks`
- inaccessible notebook deletion path должен возвращать `404`
- delete behavior не должен требовать фронтенду knowledge о внутренней delete strategy

## Acceptance criteria

- [ ] `DELETE /api/v1/notebooks/{notebook_id}` удаляет owned notebook по зафиксированной Version 1 strategy
- [ ] Повторный запрос к недоступному или отсутствующему notebook возвращает contract-stable `404`
- [ ] Notebooks router подключён в `api/app/api/v1/router.py`
- [ ] После подключения router существующие `/api/v1/health` и `/api/v1/system/health` integration tests продолжают проходить
- [ ] Backend protection pattern для notebook routes не дублирует auth logic в каждом handler

## Verification

- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/notebooks/test_delete.py -q`
- [ ] `cd api && pytest -m integration tests/integration/system/test_health.py -q`

## Dependencies

- `Depends on T3/BTF -> BACK: Реализовать notebook retrieval и metadata update endpoints`

## Documentation impact

- `Required:`
- `api/docs/persistence.md`
- `api/docs/api_architecture.md`

## Риски / заметки

- если delete strategy не будет явно зафиксирована, later QA и export behavior окажутся неоднозначными
- router wiring нельзя делать через legacy `api/v1/routes/notebooks/*` path, если feature router уже является canonical backend boundary

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговая delete strategy или router wiring изменили зафиксированное поведение
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
