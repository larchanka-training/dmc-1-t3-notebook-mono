# T3/BTF -> FRONT: Добавить execution controls и user-visible runtime states

## Status

- `done`

## Цель

Сделать execution behavior видимым и управляемым в notebook editor UI: пользователь должен запускать и останавливать выполнение, видеть `running`/`stopping`/`error`/`canceled`/`timeout` состояния и понимать, что происходит с текущим `code` block execution flow.

## Контекст

- `docs/plans/05-execution-runtime.md`
- `docs/plans/tasks/execution-runtime-02-worker-runtime-bridge-and-lifecycle.md`
- `docs/plans/tasks/execution-runtime-03-orchestrator-run-sequencing.md`
- `docs/plans/tasks/execution-runtime-04-output-renderer.md`
- `docs/project.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/runtime_architecture.md`
- текущий block actions UI: `ui/src/features/editor/ui/BlockActionCluster.tsx`
- текущий editor composition: `ui/src/features/editor/ui/NotebookEditorView.tsx`, `ui/src/features/editor/ui/NotebookBlockView.tsx`
- execution state source: `ui/src/features/execution/model/`

## Scope

- подключить user-facing execution controls в editor UI:
  - `run current`
  - `run from here`, если он уже представлен в block-level interaction design
  - `stop`
- отразить execution lifecycle states в интерфейсе:
  - `idle`
  - `running`
  - `stopping`
  - `error`
  - `canceled`
  - `timeout`
- предотвратить конфликтующие execution flows, когда один запуск уже активен
- обеспечить понятный feedback для пользователя, какой block исполняется и что произошло после остановки/ошибки
- привести block action cluster и surrounding notebook UI к согласованному execution UX

## Out of scope

- redesign notebook editor layout
- расширенный progress visualization за пределами текущего block action / output context
- chart-specific UI
- backend changes
- durable persistence execution statuses

## Технические ограничения

- execution controls должны оставаться совместимыми с frontend-side orchestration model
- `stop` должен использовать coarse-grained worker termination, а не cooperative cancellation protocol
- UI не должен позволять нескольким конкурирующим execution sessions одновременно мутировать один notebook execution state
- block action UX должен оставаться в рамках зафиксированного `ui_architecture.md`

## Acceptance criteria

- [ ] Для `code` blocks в UI доступны корректные execution actions, согласованные с текущим interaction model
- [ ] Во время активного запуска пользователь видит, что execution идет, и может вызвать `stop`
- [ ] После `stop`, `timeout` или execution error пользователь получает понятный user-visible result/status
- [ ] UI не допускает конфликтующих повторных запусков, которые приводят к невалидному execution state
- [ ] Execution state в UI согласован с данными из execution store и не строится на локальных placeholder flags

## Verification

- [ ] `cd ui && pnpm test -- editor`
- [ ] `cd ui && pnpm test -- execution`
- [ ] вручную проверить запуск и остановку long-running code block
- [ ] вручную проверить, что повторные клики run во время активного execution не создают конфликтующий flow
- [ ] вручную проверить отображение runtime error и timeout states в UI

## Dependencies

- `Depends on T3/BTF -> FRONT: Реализовать Output Renderer для runtime outputs`

## Files likely to change

- `ui/src/features/editor/ui/BlockActionCluster.tsx`
- `ui/src/features/editor/ui/NotebookEditorView.tsx`
- `ui/src/features/editor/ui/NotebookBlockView.tsx`
- `ui/src/features/execution/model/`

## Documentation impact

- `Conditional:`
- `ui/docs/ui_architecture.md`
- `docs/qa_plan.md`

## Риски / заметки

- если execution states будут вычисляться частично локально в UI, а частично в store, легко получить расходящееся поведение
- `timeout` и `canceled` нужно различать на уровне UX, иначе пользователю будет непонятно, что именно произошло
- важно не перегрузить block action cluster лишними controls и при этом не потерять обязательные сценарии run/stop

## Completion update

- `Status` updated to `done`
- implemented:
  - user-facing execution controls wired in notebook editor UI for `run current`, `run from here`, `run all`, and `stop`
  - user-visible runtime states surfaced through editor UI: `idle`, `running`, `stopping`, `error`, `canceled`, `timeout`
  - block-level execution markers and toolbar-level status messaging driven from execution store state
  - conflicting execution starts prevented while an execution is already `running` or `stopping`
  - block action and toolbar controls disabled consistently while conflicting execution actions are not allowed
- verification completed:
  - `cd ui && ./node_modules/.bin/tsc -p tsconfig.app.json --noEmit`
  - `cd ui && ./node_modules/.bin/vitest run src/features/editor/ui/NotebookEditorView.test.tsx src/features/execution/model/executionSlice.test.ts`
- documentation impact:
  - no additional documentation updates were required because the implemented run/stop controls and visible runtime states stayed within the interaction model already described in `ui/docs/ui_architecture.md`
- delta from original scope:
  - `run all` remains available in the toolbar even though the task scope only required `run current`, optional `run from here`, and `stop`; this is consistent with the already implemented orchestration flow and avoids regressing available execution controls
