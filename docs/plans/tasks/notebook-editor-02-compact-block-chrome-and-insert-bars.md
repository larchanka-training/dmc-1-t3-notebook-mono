# T3/BTF -> FRONT: Упростить block chrome и ввести inline insert bars

## Status

- `proposed`

## Цель

Сделать block UI компактным и document-first: убрать redundant block header/footer chrome, перенести insertion в inline insert bars между блоками и снизить постоянный визуальный шум, чтобы на первом плане оставались content и output.

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
- текущие block/entity surfaces:
  - `ui/src/entities/block/ui/*`
- текущие tests:
  - `ui/src/features/editor/ui/NotebookEditorView.test.tsx`
  - `ui/src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx`

## Scope

- убрать persistent block header и block footer, если они не несут необходимой V1 functionality
- убрать redundant labels, которые повторяют очевидный editor mode:
  - `JavaScript`
  - `Editable Source`
  - аналогичные decorative или technical labels
- привести block container к compact chrome model без лишних nested surfaces
- внедрить inline insert bars внутри block sequence:
  - before first block
  - between blocks
  - after last block
- сделать insert bars главным user-visible path для добавления `text` и `code` blocks
- удалить legacy add-above / add-below controls из block-level chrome, если они еще присутствуют
- сохранить output panel attached к originating `code` block
- убедиться, что text block не получает пустую output/footer area
- обновить tests и manual acceptance scenarios под новый insertion model и compact block chrome

## Out of scope

- redesign notebook sidebar
- redesign notebook header и top bar
- block collapse/expand behavior
- изменение AI detail flows beyond visual placement inside compact chrome
- изменение execution orchestration или output data model
- drag and drop, pinning, favorites, batch actions

## Технические ограничения

- editor должен оставаться vertical notebook flow, а не dashboard/card grid
- insertion должна жить в notebook canvas sequence, а не в отдельном global control area
- output не становится отдельным notebook block type
- compact chrome не должен ухудшить accessibility:
  - interactive elements остаются keyboard reachable
  - icon-only actions имеют accessible names
- visual simplification не должна ломать current run, run-from-here, delete, move и AI flows
- не добавлять новую dependency без approval

## Acceptance Criteria

- [ ] Block UI больше не содержит постоянный decorative header и footer без V1 necessity
- [ ] User-visible labels, дублирующие очевидный editor mode, удалены из default block chrome
- [ ] Каждый insert position в notebook sequence имеет inline insert control
- [ ] Пользователь может вставить `text` и `code` block до первого, между любыми двумя и после последнего блока
- [ ] Legacy add-above / add-below controls удалены из block-local chrome
- [ ] Block content читается раньше, чем secondary chrome
- [ ] Code output остается визуально attached к producing code block
- [ ] Text block не рендерит пустую output/footer area
- [ ] Frontend tests покрывают rendering insert bars и отсутствие legacy block chrome elements

## Verification

- [ ] `cd ui && pnpm lint`
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] вручную проверить:
  - insert before first block
  - insert between blocks
  - insert after last block
- [ ] вручную проверить `code` block:
  - нет redundant top label/footer
  - output остается на месте после run
- [ ] вручную проверить `text` block:
  - нет empty output/footer chrome
  - AI action flow остается доступным

## Dependencies

- `Depends on T3/BTF -> FRONT: Разделить Block.ActionCluster и Block.Toolbar`

## Files likely to change

- `ui/src/features/editor/ui/NotebookEditorView.tsx`
- `ui/src/features/editor/ui/NotebookBlockView.tsx`
- `ui/src/features/editor/ui/BlockActionCluster.tsx`
- `ui/src/features/editor/ui/InsertBlockDivider.tsx`
- `ui/src/features/editor/model/useNotebookEditor.ts`
- `ui/src/entities/block/ui/*`
- `ui/src/features/editor/ui/*.test.tsx`
- `ui/src/pages/notebook-editor/ui/*.test.tsx`

## Documentation impact

- `Primary:`
- `docs/plans/tasks/notebook-editor-02-compact-block-chrome-and-insert-bars.md`
- `Likely:`
- `ui/docs/ui_architecture.md`
- `ui/docs/ui-structure.md`
- `ui/docs/notebook_block_layout_schema.md`

## Риски / заметки

- слишком агрессивное упрощение chrome может ухудшить discoverability insert controls или status feedback
- если header/footer убрать частично, а labels останутся в других nested containers, UI останется визуально перегруженным
- insert bars должны быть видимыми ровно настолько, чтобы быть discoverable, но не превращаться в постоянный шум

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если implementation меняет зафиксированное naming или visual contract, обновить связанные UI docs

