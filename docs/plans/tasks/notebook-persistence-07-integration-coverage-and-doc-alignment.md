# T3/BTF -> BACK: Завершить notebook persistence integration coverage и document alignment

## Status

- `planned`

## Цель

Закрыть notebook persistence direction regression-ориентированными tests и выровнять документацию, чтобы следующие frontend и sync задачи опирались на проверенный и явно описанный backend contract.

## Контекст

- `docs/plans/02-notebook-persistence-plan.md`
- `api/docs/persistence.md`
- `docs/qa_plan.md`
- `api/tests/conftest.py`
- prerequisite specs:
  - `docs/plans/tasks/notebook-persistence-06-revision-semantics-and-sync-readiness.md`
  - `docs/plans/tasks/auth-backend-06-auth-integration-hardening.md`

## Scope

- довести integration coverage для notebook collection/item/delete flows
- покрыть anonymous access, owner-only access, valid create defaults включая `tags: []` и validation failures для tag contract
- перевести notebook tests на реальный или near-real authenticated fixture вместо skipped placeholder
- выровнять documentation conflicts, влияющие на notebook persistence implementation
- зафиксировать test surface для дальнейших sync tasks

## Out of scope

- новые notebook endpoints сверх текущего CRUD набора
- UI integration tests
- E2E offline/sync scenarios
- реализация sync endpoint

## Технические ограничения

- integration coverage должна использовать общий auth/session path, а не специальный bypass только для notebook tests
- документация должна выравниваться в пользу canonical contract sources, а не плодить новые расхождения
- не добавлять временный fake auth mode только ради notebook tests
- tag-related contract checks должны покрывать и notebook-level, и block-level shape

## Acceptance criteria

- [ ] Integration tests покрывают anonymous `401`, owner-only `404`, create/list/get/patch/delete flows, round-trip сохранение `tags` и invalid notebook payload paths для malformed or missing tag fields
- [ ] Notebook tests используют рабочий authenticated fixture или эквивалентный contract-faithful session issuance path
- [ ] Документация согласована по notebook access semantics, минимум для `404` owner-only behavior и persistence fields, включая tag-related fields
- [ ] Полный notebook integration suite проходит без reliance на skipped `authenticated_client`

## Verification

- [ ] `cd api && pytest -q`
- [ ] `cd api && pytest -m integration tests/integration/notebooks -q`

## Dependencies

- `Depends on T3/BTF -> BACK: Зафиксировать revision semantics и sync-ready notebook responses`
- `Depends on T3/BTF -> BACK: Завершить auth-focused integration coverage и developer documentation`

## Documentation impact

- `Required:`
- `api/docs/persistence.md`
- `docs/qa_plan.md`
- `api/tests/conftest.py`

## Риски / заметки

- если auth hardening отстанет, notebook integration coverage нельзя закрывать через временные test-only shortcuts
- любые doc conflicts лучше фиксировать прямо в canonical docs, а не в дополнительных RU companion notes

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговый test surface или access semantics изменили зафиксированное поведение
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
