# T3/BTF -> FRONT: Зафиксировать execution-контракты и store actions

## Status

- `done`

## Цель

Подготовить frontend execution foundation для Stage 5, чтобы дальнейшая реализация `Worker Runtime`, sequencing и output rendering опиралась на единые execution types, message contracts и Zustand actions, а не на placeholder state и локальные заглушки editor hook.

## Контекст

- `docs/plans/03-execution-runtime.md`
- `docs/plans/mvp-roadmap.md`
- `docs/requirements.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/runtime_architecture.md`
- `ui/docs/adr/ADR-003-runtime-execution-model.md`
- текущее execution состояние: `ui/src/features/execution/model/types.ts`, `ui/src/features/execution/model/executionSlice.ts`
- текущий placeholder run flow: `ui/src/features/editor/model/useNotebookEditor.ts`
- current app store composition: `ui/src/app/model/store.ts`

## Scope

- расширить execution domain types для:
  - execution commands: `run current`, `run all`, `run from here`, `reset`, `stop`
  - normalized runtime messages
  - execution lifecycle states
  - normalized output and error payloads
  - execution run identifier для защиты от stale worker messages после `stop`, `reset` или повторного запуска
- заменить execution slice с static initial state на Zustand slice с actions для:
  - start execution
  - mark running blocks
  - initialize latest-run output collection for `blockId`
  - append normalized output to `blockId`
  - record normalized error
  - reset execution session state
  - stop / terminate current execution flow
- зафиксировать separation между:
  - durable notebook content
  - transient execution outputs
  - execution session lifecycle state
- привести entity/output types и execution types к совместимому контракту, чтобы `Output Renderer` больше не зависел только от placeholder model
- подготовить store shape, пригодный для подключения worker bridge без повторного redesign
- зафиксировать semantics execution outputs:
  - `outputs[blockId]` хранит outputs только последнего запуска этого блока
  - новый запуск блока или execution range заменяет предыдущий массив outputs для затронутого `blockId`
  - порядок элементов массива соответствует порядку прихода normalized runtime messages
  - отсутствие `outputs[blockId]` означает, что у блока еще нет результата последнего запуска
  - пустой массив `outputs[blockId]` означает, что latest run уже начался, но еще не прислал outputs

## Out of scope

- реализация `Web Worker`
- фактическое выполнение пользовательского `JavaScript`
- реальный sequencing `run all` и `run from here`
- реальный UI rendering outputs
- backend changes
- persistence runtime outputs в `IndexedDB`, backend или notebook JSON

## Технические ограничения

- execution orchestration должна оставаться `frontend-side`
- runtime outputs не должны попадать в durable notebook model
- новые зависимости не добавлять без явного одобрения
- store architecture должна оставаться совместимой с проектным `Zustand` model
- execution model должен соответствовать worker-first решению из `ADR-003`
- Version 1 block types остаются только `text` и `code`; outputs не превращать в block types
- `text` blocks не должны получать execution outputs entry
- массив outputs не означает автоматическую поддержку streaming UI, `console` capture или interactive user input во время выполнения

## Acceptance criteria

- [x] В `ui/src/features/execution/model/types.ts` или эквивалентном execution domain слое есть типы для commands, lifecycle state, normalized outputs, normalized errors и run-scoped identifier (`executionId` или эквивалент)
- [x] `createExecutionSlice` содержит не только initial state, но и actions для старта, завершения, сброса, остановки и записи outputs/errors
- [x] Outputs хранятся в execution state отдельно от notebook entities и привязываются к `blockId`
- [x] Store contract хранит `outputs` как массив нормализованных outputs последнего запуска блока, а не как append-only историю всей session
- [x] Повторный запуск блока или execution range очищает previous latest-run outputs для затронутых `blockId` до записи новых runtime messages
- [x] Контракт различает отсутствие `outputs[blockId]` и пустой latest-run outputs array для уже стартовавшего запуска
- [x] Контракт допускает как минимум `text`, `object`, `table`, `error` outputs без повторного изменения store shape
- [x] Store actions или reducers игнорируют stale runtime messages, если они пришли не от текущего execution run
- [x] Текущее placeholder-only состояние editor больше не является source of truth для execution lifecycle

## Verification

- [x] `cd ui && pnpm test -- executionSlice`
  Verified via direct local runner: `cd ui && ./node_modules/.bin/vitest run src/features/execution/model/executionSlice.test.ts`
- [x] `cd ui && pnpm test -- store`
  Verified via direct local runner: `cd ui && ./node_modules/.bin/vitest run src/app/model/store.test.ts`
- [x] покрыть тестами reset/replace semantics для latest-run outputs и игнорирование stale messages по `executionId`
- [x] проверить через type-aware imports, что notebook entity types не получили поля для durable runtime outputs
  Verified via `cd ui && ./node_modules/.bin/tsc -p tsconfig.app.json --noEmit`

## Dependencies

- `None`

## Files likely to change

- `ui/src/features/execution/model/types.ts`
- `ui/src/features/execution/model/executionSlice.ts`
- `ui/src/app/model/store.ts`
- `ui/src/app/model/types.ts`
- `ui/src/entities/output/`
- `ui/src/features/editor/model/useNotebookEditor.ts`

## Documentation impact

- `Conditional:`
- `ui/docs/runtime_architecture.md`
- `ui/docs/ui_architecture.md`

## Риски / заметки

- если execution contract останется слишком тесно привязан к текущему placeholder output model, следующая задача про `Worker Runtime` потребует лишнего refactor
- важно не смешать execution session state с notebook working copy state
- `chart` output не нужно делать обязательной частью store contract, если это усложняет Stage 5 core; достаточно не закрыть для него путь полностью
- latest-run outputs semantics должна оставаться bounded per block; store не должен превращаться в session-wide log без отдельной задачи
- interactive input during execution и полноценный `console` stream остаются отдельными future features и не должны неявно просочиться в Task 1 contract

## Completion update

- `Status` updated to `done`
- execution contracts moved to the shared execution domain: commands, statuses, runtime messages, normalized errors, `executionId`, and latest-run output arrays
- `executionStore` now owns execution lifecycle and runtime outputs; editor-local placeholder execution state is no longer the source of truth
- output rendering was moved off the placeholder model to `OutputItem[]` owned by `executionStore`
- documentation updated in:
  - `docs/plans/03-execution-runtime.md`
  - `ui/docs/runtime_architecture.md`
  - `ui/docs/ui_architecture.md`
  - `ui/docs/state_model.md`
  - `ui/docs/zusthand-store.md`
  - `ui/docs/adr/ADR-009-zustand-state-model.md`
- Russian companion docs were updated as well for the affected UI/runtime/state documents
- delta from original scope:
  - the task also completed the first practical renderer-side adaptation from placeholder outputs to `OutputItem[]` so the execution contract is exercised by the notebook editor already in this slice
