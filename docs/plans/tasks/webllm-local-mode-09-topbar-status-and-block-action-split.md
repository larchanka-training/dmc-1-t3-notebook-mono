# T3/BTF -> FRONT: Перенести WebLLM readiness в Notebook.TopBar и убрать block-level prepare

## Status

- `proposed`

## Цель

Сделать optional `WebLLM` local mode понятным и архитектурно согласованным: lifecycle browser-local runtime должен отображаться один раз на уровне notebook editor, а `text` blocks должны сохранять только block-scoped generation actions и result states.

## Контекст

- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `docs/ai-architecture.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/ui-structure.md`
- `ui/docs/notebook_block_layout_schema.md`
- related local mode tasks:
  - `docs/plans/tasks/webllm-local-mode-03-runtime-bootstrap-and-capability-checks.md`
  - `docs/plans/tasks/webllm-local-mode-05-local-mode-and-retry-ui.md`
- current frontend implementation:
  - `ui/src/features/ai/model/localRuntime.ts`
  - `ui/src/features/ai/model/useBlockAiAction.ts`
  - `ui/src/features/ai/ui/BlockAiAction.tsx`
  - `ui/src/features/editor/ui/NotebookEditorToolbar.tsx`
  - `ui/src/pages/notebook-editor/ui/NotebookEditorPage.tsx`

## Scope

- перенести explicit local runtime prepare/reset and readiness summary из block AI UI в `Notebook.TopBar`
- добавить notebook-level status surface для optional local AI runtime:
  - `disabled`
  - `unsupported`
  - `preparing`
  - `ready`
  - `failed`
- сохранить canonical backend generate action как primary action для eligible `text` blocks
- оставить в `text` block secondary local generate action только когда local runtime уже `ready`
- сохранить `Retry locally with WebLLM` как block-scoped secondary action после retryable backend failure
- убрать повторяющийся `Prepare WebLLM local mode` control и notebook-wide runtime summary из каждого text block
- обновить tests на top bar composition и block AI action behavior

## Out of scope

- redesign всего notebook top bar beyond adding local AI surface
- новый global provider chooser
- backend health badge or `Bedrock ready` indicator
- backend contract changes
- изменение insertion semantics для AI-generated code

## Технические ограничения

- `WebLLM` остаётся optional explicit local mode, а не равноправным default provider path
- browser-local runtime lifecycle должен оставаться lazy и не стартовать на page load
- notebook-level local AI surface не должна подменять block-scoped provider labeling для actual generation results
- block AI flow должен остаться source-block based
- implementation должна соблюдать FSD boundaries между `features/ai`, `features/editor` и `pages/notebook-editor`

## Acceptance Criteria

- [ ] `Notebook.TopBar` содержит отдельный local AI status/control surface для optional `WebLLM` runtime
- [ ] `Prepare WebLLM local mode` больше не дублируется в каждом eligible `text` block
- [ ] `text` block сохраняет primary backend generate action
- [ ] `text` block показывает secondary local generate action только когда local runtime уже `ready`
- [ ] После retryable backend failure block UI может предложить `Retry locally with WebLLM`, не превращая local provider в primary path
- [ ] Local runtime readiness/error messaging больше не повторяется у каждого text block и отображается notebook-level
- [ ] Tests покрывают top bar local AI surface и обновлённые block AI states

## Verification

- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] `cd ui && pnpm lint`
- [ ] вручную проверить:
  - local mode disabled / unsupported / ready states в `Notebook.TopBar`
  - отсутствие `Prepare WebLLM` в каждом text block
  - backend generate как primary block action
  - local generate как secondary block action только после runtime preparation
  - retryable backend failure -> `Retry locally with WebLLM`

## Dependencies

- `Depends on T3/BTF -> FRONT: Добавить WebLLM runtime bootstrap и capability checks`
- `Depends on T3/BTF -> FRONT: Добавить explicit local-mode и retry-fallback UI для WebLLM`

## Files likely to change

- `ui/src/features/ai/model/useBlockAiAction.ts`
- `ui/src/features/ai/ui/BlockAiAction.tsx`
- `ui/src/features/ai/ui/`
- `ui/src/features/editor/ui/NotebookEditorToolbar.tsx`
- `ui/src/features/editor/ui/NotebookEditorView.tsx`
- `ui/src/pages/notebook-editor/ui/NotebookEditorPage.tsx`
- `ui/src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx`
- `ui/src/features/editor/ui/*.test.tsx`

## Documentation impact

- `Primary:`
- `docs/plans/tasks/webllm-local-mode-09-topbar-status-and-block-action-split.md`
- `Likely:`
- `docs/ai-architecture.md`
- `ui/docs/ui-structure.md`
- `ui/docs/notebook_block_layout_schema.md`

## Риски / заметки

- если notebook-wide runtime lifecycle останется block-local, UI продолжит создавать ложное впечатление, что `WebLLM` подготавливается отдельно для каждого source block
- если local and backend actions будут визуально симметричны, users начнут воспринимать `WebLLM` как второй default provider path
- top bar local AI status должен быть коротким operational surface, а не длинной explanatory panel
