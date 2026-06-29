# T3/BTF -> FRONT: Разделить Block.ActionCluster и Block.Toolbar

## Status

- `proposed`

## Цель

Привести block-local controls к новой V1-модели: primary action для текущего block type должен жить в `Block.ActionCluster`, а structural block management actions должны быть вынесены в отдельный `Block.Toolbar`, который не шумит в idle-state и появляется только для active block.

## Контекст

- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `docs/qa_plan.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/ui-structure.md`
- `ui/docs/screen_specs.md`
- `ui/docs/notebook_block_layout_schema.md`
- текущие editor surfaces:
  - `ui/src/features/editor/ui/NotebookEditorView.tsx`
  - `ui/src/features/editor/ui/NotebookBlockView.tsx`
  - `ui/src/features/editor/ui/BlockActionCluster.tsx`
  - `ui/src/features/editor/model/useNotebookEditor.ts`
  - `ui/src/features/editor/model/blockUiSlice.ts`
- AI и execution surfaces:
  - `ui/src/features/ai/ui/BlockAiAction.tsx`
  - `ui/src/features/execution/*`
- текущие тесты:
  - `ui/src/features/editor/ui/NotebookEditorView.test.tsx`
  - `ui/src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx`

## Scope

- определить и реализовать отдельный `Block.Toolbar` для structural block actions
- перенести в `Block.Toolbar` только block-management actions:
  - move block up
  - move block down
  - delete block
- сделать `Block.Toolbar` скрытым по умолчанию и показывать его только когда block selected, focused или otherwise clearly active
- зафиксировать, что `Block.ActionCluster` содержит только primary action для текущего block type:
  - `text` block: AI action и связанный transient AI status
  - `code` block: run / run from here / execution status
- убрать из primary cluster любые structural actions, не относящиеся к основной работе внутри блока
- обеспечить keyboard reachability для `Block.Toolbar` и корректное поведение при focus transitions
- синхронизировать visible action model между `text` и `code` blocks без возврата к always-visible toolbar
- обновить regression coverage для rendering и visibility rules `Block.ActionCluster` и `Block.Toolbar`

## Out of scope

- redesign notebook-level top bar или notebook header
- изменение insert-between-block pattern
- удаление block header/footer chrome как visual redesign slice
- collapse/expand behavior для block content
- изменение AI contracts, execution contracts или sync contracts
- новые block types beyond `text` and `code`

## Технические ограничения

- V1 UI architecture остается block-scoped:
  - `text` block не получает execution controls
  - `code` block не получает default AI action
- решение должно оставаться в FSD boundaries:
  - editor chrome в `features/editor`
  - AI-specific behavior в `features/ai`
  - execution-specific status integration в соответствующих feature/entity слоях
- `Block.Toolbar` visibility не должна требовать тяжелого global state, если достаточно local presentational/state slice solution
- destructive action `Delete block` должна оставаться semantically distinguishable
- keyboard-only пользователь должен иметь доступ и к primary actions, и к toolbar actions
- не добавлять новую dependency без отдельного approval

## Acceptance Criteria

- [ ] Каждый block в editor имеет разделение на `Block.ActionCluster` и `Block.Toolbar`
- [ ] `Block.ActionCluster` содержит только primary action для соответствующего block type
- [ ] `Block.Toolbar` содержит только `move up`, `move down`, `delete`
- [ ] `Block.Toolbar` скрыт в idle-state и становится доступным только для active block
- [ ] `text` block не показывает run controls в primary cluster
- [ ] `code` block не показывает default AI action в primary cluster
- [ ] Structural actions больше не конкурируют визуально с primary block actions
- [ ] Keyboard navigation позволяет открыть active block state и выполнить toolbar action без мыши
- [ ] Existing block operations сохраняют поведение после переноса controls
- [ ] Frontend tests покрывают как минимум rendering split, visibility rules и keyboard reachability

## Verification

- [ ] `cd ui && pnpm lint`
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] вручную проверить `text` block:
  - idle-state не показывает structural toolbar
  - AI action доступен
  - toolbar появляется при явной активации блока
- [ ] вручную проверить `code` block:
  - доступны `Run` и `Run from here`
  - structural toolbar появляется только для active block
  - delete/move actions остаются рабочими
- [ ] вручную проверить keyboard-only flow:
  - focus на block
  - переход к toolbar actions
  - выполнение move/delete без мыши

## Dependencies

- None

## Files likely to change

- `ui/src/features/editor/ui/NotebookBlockView.tsx`
- `ui/src/features/editor/ui/BlockActionCluster.tsx`
- `ui/src/features/editor/ui/NotebookEditorView.tsx`
- `ui/src/features/editor/model/useNotebookEditor.ts`
- `ui/src/features/editor/model/blockUiSlice.ts`
- `ui/src/features/editor/model/sliceTypes.ts`
- `ui/src/features/ai/ui/BlockAiAction.tsx`
- `ui/src/features/editor/ui/*.test.tsx`
- `ui/src/pages/notebook-editor/ui/*.test.tsx`

## Documentation impact

- `Primary:`
- `docs/plans/tasks/notebook-editor-01-block-toolbar-and-primary-actions.md`
- `Likely:`
- `ui/docs/ui_architecture.md`
- `ui/docs/screen_specs.md`

## Риски / заметки

- если active-block semantics будут размыты между hover, focus и selection, toolbar может стать либо слишком шумным, либо плохо discoverable
- перенос actions между cluster и toolbar легко ломает keyboard tab order; это нужно проверить отдельно
- если implementation оставит structural actions одновременно и в cluster, и в toolbar, задача не достигнет цели снижения visual noise

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если итоговый interaction model отличается от текущих docs, обновить `ui/docs/*`

