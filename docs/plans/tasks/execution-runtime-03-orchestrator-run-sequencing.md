# T3/BTF -> FRONT: Подключить execution orchestration и run sequencing

## Status

- `done`

## Цель

Подключить `Execution Orchestrator` к реальному notebook editor flow, чтобы `run current`, `run all` и `run from here` исполняли правильную последовательность code blocks, переиспользовали или сбрасывали `execution session` по зафиксированным правилам и привязывали результаты к correct `blockId`.

## Контекст

- `docs/plans/05-execution-runtime.md`
- `docs/plans/tasks/execution-runtime-01-execution-contracts-and-store.md`
- `docs/plans/tasks/execution-runtime-02-worker-runtime-bridge-and-lifecycle.md`
- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/runtime_architecture.md`
- текущий editor flow: `ui/src/features/editor/model/useNotebookEditor.ts`
- текущий notebook rendering flow: `ui/src/features/editor/ui/NotebookEditorView.tsx`, `ui/src/features/editor/ui/NotebookBlockView.tsx`
- notebook domain model: `ui/src/entities/notebook/`

## Scope

- заменить mock `runBlock` behavior в editor layer на реальный orchestration flow
- реализовать выбор execution range для:
  - `run current`
  - `run all`
  - `run from here`
- использовать ordered notebook blocks как source of truth для sequencing
- исполнять только `code` blocks и корректно пропускать `text` blocks
- обновлять execution store по мере прогресса:
  - active target
  - running block ids
  - per-block outputs
  - normalized errors
- обеспечить корректный binding outputs к blockId originating code block
- подготовить orchestration слой к подключению `Output Renderer` без возврата к placeholder outputs

## Out of scope

- финальный UI renderer для всех output variants
- визуальный polish execution controls
- chart-specific runtime protocol
- backend changes
- persistence execution outputs across reload

## Технические ограничения

- sequencing должен опираться на фактический notebook block order, а не на UI-local assumptions
- `run all` обязан reset-ить session перед запуском
- `run current` и `run from here` обязаны reuse current session, если нет explicit stop/reset
- outputs должны оставаться execution artifacts, а не notebook blocks
- реализация должна оставаться в рамках frontend FSD boundaries

## Acceptance criteria

- [ ] `run current` исполняет только выбранный `code` block и записывает результат под его `blockId`
- [ ] `run all` исполняет все `code` blocks сверху вниз после reset session
- [ ] `run from here` исполняет выбранный `code` block и все нижележащие `code` blocks в notebook order
- [ ] `text` blocks корректно пропускаются и не отправляются в runtime
- [ ] Execution state (`targetBlockId`, `runningBlockIds`, status, outputs, error`) отражает реальный orchestration progress
- [ ] Editor layer больше не использует placeholder label как substitute для execution result

## Verification

- [ ] `cd ui && pnpm test -- editor`
- [ ] `cd ui && pnpm test -- execution`
- [ ] вручную проверить сценарий: переменная из верхнего блока доступна при `run from here` для нижнего блока без reset
- [ ] вручную проверить сценарий: `run all` после локального `run current` не использует старый shared state
- [ ] вручную проверить binding outputs к правильным code blocks в mixed notebook с `text` и `code`

## Dependencies

- `Depends on T3/BTF -> FRONT: Реализовать worker runtime bridge и session lifecycle`

## Files likely to change

- `ui/src/features/editor/model/useNotebookEditor.ts`
- `ui/src/features/editor/ui/NotebookEditorView.tsx`
- `ui/src/features/editor/ui/BlockActionCluster.tsx`
- `ui/src/features/execution/`
- `ui/src/entities/notebook/`

## Documentation impact

- `Conditional:`
- `ui/docs/ui_architecture.md`
- `ui/docs/runtime_architecture.md`

## Риски / заметки

- текущий editor hook держит notebook и outputs локально; возможно, придется частично перенести ownership execution state в store до UI integration
- ошибка в range-selection logic быстро приведет к неверной session semantics, поэтому sequencing лучше закрепить integration tests до визуального polishing
- важно не смешать orchestration logic и rendering logic в одном компоненте или hook

## Completion update

- `Status` updated to `done`
- implemented:
  - notebook-order range selection for `run current`, `run all`, and `run from here`
  - `text` block skipping during runtime payload construction
  - editor orchestration wiring through the existing worker bridge
  - per-block latest-run output clearing and rebinding for the targeted execution range
  - toolbar `Run all` action and block-level `Run from here` action
- verification completed:
  - `cd ui && ./node_modules/.bin/tsc -p tsconfig.app.json --noEmit`
  - `cd ui && ./node_modules/.bin/vitest run src/features/editor/ui/NotebookEditorView.test.tsx src/features/execution/model/executionSlice.test.ts src/features/execution/lib/notebookRuntimeCore.test.ts src/features/execution/lib/notebookWorkerBridge.test.ts`
- documentation updated:
  - `ui/docs/runtime_architecture.md`
- delta from original scope:
  - no additional `ui/docs/ui_architecture.md` changes were required because the execution ownership boundary remained the same
