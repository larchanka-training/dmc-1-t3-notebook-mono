# T3/BTF -> FRONT: Перевести runtime core с replay на live worker session

## Status

- `done`

## Цель

Перевести `Execution Runtime` с replay-based session restoration на настоящую persistent `Web Worker` session, чтобы shared execution state жил в live in-memory context, repeated runs не требовали replay предыдущих blocks, а поведение runtime соответствовало ожидаемой notebook `execution session`.

## Контекст

- `docs/plans/04-live-worker-session-transition-plan.md`
- `docs/plans/tasks/live-worker-session-01-target-semantics-and-contracts.md`
- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `ui/docs/runtime_architecture.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/adr/ADR-003-runtime-execution-model.md`
- текущая runtime implementation:
  - `ui/src/features/execution/lib/notebookRuntimeCore.ts`
  - `ui/src/features/execution/lib/notebookRuntimeWorker.ts`
  - `ui/src/features/execution/lib/notebookWorkerBridge.ts`
- текущие execution contracts:
  - `ui/src/features/execution/model/types.ts`
  - `ui/src/features/execution/model/executionSlice.ts`

## Scope

- заменить `sessionBlocks` / replay-based restore model внутри runtime core на live worker-owned execution context
- реализовать способ последовательного выполнения переданного списка code blocks внутри уже существующей session без предварительного replay более ранних blocks
- сохранить существующий transport contract между bridge и worker, если для migration не требуется его минимально расширить
- сохранить normalized outputs/error contract для:
  - `execution-started`
  - `execution-output`
  - `execution-error`
  - `execution-complete`
- сохранить правила lifecycle:
  - `run all` делает `RESET_SESSION` перед full execution
  - `run current` и `run from here` reuse текущий worker session
  - `stop` и `timeout` по-прежнему terminate-ят worker и создают clean session для следующего запуска
- устранить зависимость от branch truncation workaround для repeated run того же блока
- гарантировать, что syntax/runtime error в одном блоке не переводят runtime обратно на replay path и не требуют неявного rebuild session history

## Out of scope

- redesign execution store shape
- UI changes в notebook editor или output renderer
- cooperative cancellation внутри пользовательского кода
- durable persistence execution session или outputs
- backend changes
- sandbox/permission model beyond current worker isolation boundary

## Технические ограничения

- реализация должна оставаться в рамках dedicated `Web Worker`, без перехода на `iframe` или backend runtime
- нельзя открывать worker доступ к app internals, store, persistence adapters или backend credentials
- новые зависимости не добавлять без явного одобрения
- orchestrator по-прежнему решает, какие blocks запускать; runtime не должен сам вычислять notebook ranges
- `run all` reset semantics, timeout behavior и stale-message protection по `executionId` должны сохраниться

## Acceptance criteria

- [ ] `ui/src/features/execution/lib/notebookRuntimeCore.ts` или эквивалентный runtime core больше не восстанавливает session через replay массива ранее выполненных source blocks
- [ ] Повторный `run current` одного и того же блока выполняется без redeclaration workaround и без ошибки вида `Identifier '<name>' has already been declared`
- [ ] Повторный `run from here` или downstream run не воспроизводит upstream blocks только ради восстановления runtime state
- [ ] Shared mutable state и ранее определённые значения остаются доступны между последовательными block runs внутри одной live worker session
- [ ] `run all` по-прежнему начинает execution с clean session reset и исполняет blocks сверху вниз
- [ ] `stop` и timeout по-прежнему гарантируют, что следующий запуск начнётся в новой clean worker session
- [ ] Existing execution output/error protocol остаётся совместимым с текущим editor/store integration или документированно обновлён без скрытого contract drift

## Verification

- [ ] `cd ui && ./node_modules/.bin/vitest run src/features/execution/lib/notebookRuntimeCore.test.ts src/features/execution/lib/notebookWorkerBridge.test.ts src/features/execution/model/executionSlice.test.ts`
- [ ] `cd ui && ./node_modules/.bin/tsc -p tsconfig.app.json --noEmit`
- [ ] вручную проверить сценарий: верхний блок создаёт shared state, нижний блок использует его без `run all`, затем repeated `run current` верхнего блока не падает на redeclaration
- [ ] вручную проверить сценарий: `stop` или timeout long-running блока, затем следующий `run current` стартует из clean session

## Dependencies

- `Depends on T3/BTF -> FRONT: Зафиксировать target live-session semantics и migration contracts`

## Files likely to change

- `ui/src/features/execution/lib/notebookRuntimeCore.ts`
- `ui/src/features/execution/lib/notebookRuntimeWorker.ts`
- `ui/src/features/execution/lib/notebookWorkerBridge.ts`
- `ui/src/features/execution/lib/notebookRuntimeCore.test.ts`
- `ui/src/features/execution/lib/notebookWorkerBridge.test.ts`
- `ui/src/features/execution/model/types.ts`

## Documentation impact

- `Conditional:`
- `ui/docs/runtime_architecture.md`
- `ui/docs/adr/ADR-003-runtime-execution-model.md`
- `docs/plans/04-live-worker-session-transition-plan.md`

## Риски / заметки

- persistent JS context внутри worker имеет tricky declaration semantics для `const`, `let`, `class` и function declarations; implementation нельзя свести к наивному `eval` без явной модели binding persistence
- важно не сломать coarse-grained cancellation, пока runtime internals меняются
- если для migration потребуется минимальное расширение runtime message contract, это изменение должно быть документировано и синхронизировано с execution store tests
- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговая live-session implementation изменила описанные runtime boundaries
- если часть старых tests была переписана из-за implicit replay assumptions, кратко зафиксировать это в этой секции
- если runtime contract пришлось скорректировать, перечислить минимальные совместимые изменения и причину
- runtime core переведён с replay массива `sessionBlocks` на live worker-owned session scope с persistent top-level bindings внутри worker
- transport contract между bridge/store и worker сохранён: используются те же `RUN_BLOCKS` / `RESET_SESSION` / `TERMINATE_SESSION` и те же normalized `execution-*` messages
- runtime tests обновлены под live-session semantics: downstream reruns больше не предполагают upstream replay, добавлено покрытие для repeated mutable-state runs и persistent function rebinding
- `ui/docs/runtime_architecture.md` обновлён под фактическую live-session implementation
