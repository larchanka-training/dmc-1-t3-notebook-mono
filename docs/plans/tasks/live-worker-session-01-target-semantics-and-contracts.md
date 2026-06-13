# T3/BTF -> FRONT: Зафиксировать target live-session semantics и migration contracts

## Status

- `planned`

## Цель

Зафиксировать для Stage 6 единые `live worker session` semantics, migration boundaries и regression expectations, чтобы переход с replay-based runtime на persistent worker context выполнялся по явному контракту, а не через локальные workaround-исправления в runtime core.

## Контекст

- `docs/plans/06-live-worker-session-transition-plan.md`
- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `docs/qa_plan.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/runtime_architecture.md`
- `ui/docs/adr/ADR-003-runtime-execution-model.md`
- текущая runtime implementation:
  - `ui/src/features/execution/lib/notebookRuntimeCore.ts`
  - `ui/src/features/execution/lib/notebookRuntimeWorker.ts`
  - `ui/src/features/execution/lib/notebookWorkerBridge.ts`
- текущие runtime tests:
  - `ui/src/features/execution/lib/notebookRuntimeCore.test.ts`
  - `ui/src/features/execution/lib/notebookWorkerBridge.test.ts`

## Scope

- зафиксировать в task-ready и code-ready виде целевые semantics для:
  - `run current`
  - `run all`
  - `run from here`
  - `reset`
  - `stop`
- явно отделить:
  - orchestrator responsibility за block ordering и range selection
  - worker runtime responsibility за live in-memory execution session
  - transient output ownership в execution store
- описать migration contract для runtime internals:
  - replay предыдущих source blocks больше не является допустимым способом обычного session restore
  - redeclaration avoidance не должна опираться на branch truncation workaround
  - `run all` остаётся единственной стандартной точкой clean session reset перед full notebook execution
- обновить и/или добавить targeted tests, которые закрепляют:
  - repeated `run current` одного и того же блока
  - отсутствие upstream replay side effects в обычных downstream runs
  - reset semantics для `run all`
  - coarse-grained terminate-and-recreate semantics для `stop` и `timeout`
- задокументировать явные non-goals migration:
  - без backend execution
  - без durable outputs
  - без DOM runtime
  - без расширения language support

## Out of scope

- фактическая замена replay runtime internals на live evaluation model
- переписывание UI execution controls
- расширение output protocol
- chart-specific runtime behavior
- новые runtime dependencies

## Технические ограничения

- semantics должны оставаться совместимыми с canonical `Execution Session` model из `docs/project.md`
- runtime остаётся `client-side`, а orchestration остаётся `frontend-side`
- worker-first решение из `ADR-003` не пересматривается
- нельзя неявно менять публичный execution store contract без явной документации в task artifact и docs
- тесты не должны закреплять replay behavior как desired behavior

## Acceptance criteria

- [ ] В `ui/docs/runtime_architecture.md` явно зафиксировано, что target runtime session является live worker context, а replay previous source history больше не считается целевой semantics
- [ ] В runtime/task docs явно описано, что `run current` и `run from here` reuse текущую live session без обязательного upstream replay внутри runtime
- [ ] В runtime/task docs явно описано, что `run all` выполняет clean reset session перед top-to-bottom execution
- [ ] В `ui/src/features/execution/lib/notebookRuntimeCore.test.ts` или эквивалентном test suite есть сценарии, которые защищают от возврата branch-truncation workaround как основного механизма session correctness
- [ ] Regression expectations для `stop` и `timeout` зафиксированы так, чтобы следующий запуск начинался из clean worker session после terminate/recreate
- [ ] Scope migration и non-goals сформулированы без двусмысленности для последующих implementation tasks

## Verification

- [ ] `cd ui && ./node_modules/.bin/vitest run src/features/execution/lib/notebookRuntimeCore.test.ts src/features/execution/lib/notebookWorkerBridge.test.ts`
- [ ] review docs diff в `ui/docs/runtime_architecture.md` и убедиться, что replay model описана как current limitation, а не как target architecture
- [ ] вручную сверить task artifact с `docs/plans/06-live-worker-session-transition-plan.md`, чтобы acceptance criteria не выходили за рамки approved plan

## Dependencies

- `None`

## Files likely to change

- `ui/docs/runtime_architecture.md`
- `ui/docs/adr/ADR-003-runtime-execution-model.md`
- `ui/src/features/execution/lib/notebookRuntimeCore.test.ts`
- `ui/src/features/execution/lib/notebookWorkerBridge.test.ts`
- `docs/plans/06-live-worker-session-transition-plan.md`

## Documentation impact

- `Required:`
- `ui/docs/runtime_architecture.md`
- `ui/docs/adr/ADR-003-runtime-execution-model.md`
- `docs/plans/06-live-worker-session-transition-plan.md`

## Риски / заметки

- если в этой задаче оставить двусмысленность между orchestrator sequencing и runtime session restore, следующая implementation slice почти наверняка смешает два ownership boundary
- важно закрепить ожидаемое поведение side effects именно как product/runtime semantics, а не как incidental detail текущих тестов
- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговая semantics формулируется точнее или меняет текущие runtime notes
- если итоговая реализация task ограничилась tests без doc changes, явно зафиксировать почему существующая документация уже покрывала нужный contract
- если acceptance criteria или verification были скорректированы по факту, кратко зафиксировать delta в этой секции
