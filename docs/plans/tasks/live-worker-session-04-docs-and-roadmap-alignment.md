# T3/BTF -> FRONT: Обновить runtime docs и roadmap после live-session migration

## Status

- `done`

## Цель

Привести runtime documentation, ADR notes и Stage planning artifacts в соответствие с фактической live worker session implementation, чтобы в проекте не осталось устаревшего описания replay-based session semantics как текущей или целевой execution model.

## Контекст

- `docs/plans/04-live-worker-session-transition-plan.md`
- `docs/plans/tasks/live-worker-session-01-target-semantics-and-contracts.md`
- `docs/plans/tasks/live-worker-session-02-runtime-core-migration.md`
- `docs/plans/tasks/live-worker-session-03-regression-coverage-and-qa.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/qa_plan.md`
- `ui/docs/runtime_architecture.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/adr/ADR-003-runtime-execution-model.md`

## Scope

- обновить frontend/runtime docs так, чтобы они описывали live worker session как текущую реализованную model
- убрать или переформулировать notes, которые описывают replay-based runtime как актуальный implementation baseline
- обновить transition plan и связанные task artifacts:
  - отметить закрытые migration slices
  - зафиксировать итоговый accepted behavior
  - оставить только реальные remaining follow-ups, если они есть
- проверить, нужны ли правки в shared project docs, если wording про `execution session` или reset semantics стало точнее после migration
- при необходимости синхронизировать QA checklist с обновлёнными runtime docs

## Out of scope

- новые runtime behavior changes
- дополнительная implementation работа в `ui/src/features/execution/`, кроме мелких doc-driven rename/cleanup если они необходимы
- перевод companion RU docs, если это не требуется отдельной задачей по репозиторию
- backend documentation updates, не связанные напрямую с frontend execution model

## Технические ограничения

- документация должна оставаться согласованной с canonical project docs и не менять архитектуру задним числом
- нельзя описывать возможности, которых нет в реализации или verification
- если где-то остаются известные runtime limits, они должны быть явно обозначены как current limitation, а не скрыты
- terminology должна оставаться проектной: `execution session`, `runtime`, `worker`, `run current`, `run all`, `run from here`

## Acceptance criteria

- [x] `ui/docs/runtime_architecture.md` описывает live worker session как реализованную current model без ссылки на replay как основной session mechanism
- [x] `ui/docs/adr/ADR-003-runtime-execution-model.md` остаётся согласованным с фактическим runtime behavior после migration
- [x] `docs/plans/04-live-worker-session-transition-plan.md` обновлён как закрытый или актуализированный plan artifact с явным итогом migration
- [x] Если `docs/qa_plan.md` или related task specs ссылаются на устаревшие replay assumptions, они синхронизированы с новой semantics
- [x] В документации явно сохранены текущие boundaries: client-side runtime, frontend-side orchestrator, transient outputs, coarse-grained stop/timeout

## Verification

- [ ] diff review для `ui/docs/runtime_architecture.md`, `ui/docs/adr/ADR-003-runtime-execution-model.md`, `docs/plans/04-live-worker-session-transition-plan.md`
- [ ] сверить обновлённые docs с фактическими verification results из Stage 6 implementation и QA tasks
- [ ] вручную проверить, что в docs больше нет формулировок, описывающих replay-based session как желаемую текущую модель

## Dependencies

- `Depends on T3/BTF -> FRONT: Перевести runtime core с replay на live worker session`
- `Depends on T3/BTF -> QA: Добавить regression coverage для live worker session`

## Files likely to change

- `ui/docs/runtime_architecture.md`
- `ui/docs/adr/ADR-003-runtime-execution-model.md`
- `docs/plans/04-live-worker-session-transition-plan.md`
- `docs/qa_plan.md`
- `ui/docs/ui_architecture.md`

## Documentation impact

- `Required:`
- `ui/docs/runtime_architecture.md`
- `ui/docs/adr/ADR-003-runtime-execution-model.md`
- `docs/plans/04-live-worker-session-transition-plan.md`
- `Conditional:`
- `docs/qa_plan.md`
- `ui/docs/ui_architecture.md`

## Риски / заметки

- если documentation alignment сделать до завершения migration и QA, легко зафиксировать optimistic behavior, которого ещё нет в коде
- часть shared docs может не требовать изменений; это нужно явно отметить, а не обновлять их формально
- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- перечислить, какие документы реально были обновлены и почему
- если часть planned doc updates оказалась не нужна, явно зафиксировать это в этой секции
- если после migration остались открытые runtime follow-ups, перечислить их как отдельные next steps, а не прятать в narrative
- обновлены `ui/docs/runtime_architecture.md`, `ui/docs/adr/ADR-003-runtime-execution-model.md` и `ui/docs/ui_architecture.md`, чтобы зафиксировать live worker session как current implementation и убрать migration-phase wording как current baseline
- `docs/plans/04-live-worker-session-transition-plan.md` переписан как закрытый Stage 6 summary artifact с accepted behavior, закрытыми slices и текущими runtime boundaries
- `docs/qa_plan.md` оставлен по существу без structural changes; обновлена только формулировка checklist, чтобы он ссылался на current live worker session model, а не на будущую migration
- shared project docs `docs/project.md` и `docs/system_architecture.md` не потребовали изменений: их execution-session wording уже совместим с итоговой live-session semantics
- отдельные future runtime ideas оставлены как потенциальные follow-ups без открытия новой migration slice: console capture/streaming outputs, runtime policy for `fetch`, возможные DOM-oriented requirements
