# T3/BTF -> BACK: Реализовать notebook retrieval и metadata update endpoints

## Status

- `planned`

## Цель

Дать frontend реальный item-level notebook flow: открыть один notebook по id и обновить его lightweight metadata без полного sync path. Это завершает основную read/update часть backend CRUD.

## Контекст

- `docs/plans/02-notebook-persistence-plan.md`
- `api/docs/persistence.md`
- `api/docs/api_architecture.md`
- prerequisite spec: `docs/plans/tasks/notebook-persistence-03-create-and-list-endpoints.md`
- current API wiring state: `api/app/api/v1/router.py`

## Scope

- реализовать `GET /api/v1/notebooks/{notebook_id}`
- реализовать `PATCH /api/v1/notebooks/{notebook_id}`
- вернуть full notebook snapshot для owned notebook
- разрешить metadata update минимум для `title`
- синхронизировать row metadata и `content_snapshot.title`, если title хранится в обоих местах
- вернуть `404 Not Found` для notebook, который недоступен текущему user

## Out of scope

- `DELETE /api/v1/notebooks/{notebook_id}`
- full sync semantics и `base_revision` conflict handling
- block-level partial update API
- frontend notebook editor persistence wiring

## Технические ограничения

- inaccessible private notebook должен возвращать `404`, а не `403`
- patch endpoint не должен подменять future sync contract и full snapshot write path
- auth enforcement должна идти через shared dependencies, а не через raw cookie inspection

## Acceptance criteria

- [ ] `GET /api/v1/notebooks/{notebook_id}` возвращает full notebook response для owned notebook
- [ ] `PATCH /api/v1/notebooks/{notebook_id}` обновляет поддерживаемые metadata fields без поломки snapshot consistency
- [ ] Запрос к notebook другого пользователя или несуществующему notebook возвращает `404 Not Found`
- [ ] Updated notebook response отражает актуальные `updated_at` и согласованный `title`
- [ ] Integration tests покрывают owner-only access и metadata update path

## Verification

- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/notebooks/test_item.py -q`
- [ ] вручную проверить сценарий `create -> get by id -> patch title -> get by id`

## Dependencies

- `Depends on T3/BTF -> BACK: Реализовать notebook create и list endpoints`

## Documentation impact

- `Required:`
- `api/docs/persistence.md`

## Риски / заметки

- если title update semantics оставить неявными, later sync task может получить расхождение между DB row и snapshot
- не нужно в этой задаче добавлять generic patch fields без contract update

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговые get/patch semantics или `404` ownership behavior изменили зафиксированный contract
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
