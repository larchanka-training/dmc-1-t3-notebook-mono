# T3/BTF -> FRONT: Выравнять Notebook.Header, Notebook.TopBar и status surfaces

## Status

- `proposed`

## Цель

Довести editor shell до согласованной V1-структуры: `Notebook.Header` должен отвечать за title и metadata, `Notebook.TopBar` — за notebook-level actions, а status surfaces должны использовать единые user-facing names и не смешивать notebook identity с operational controls.

## Контекст

- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `docs/qa_plan.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/ui-structure.md`
- `ui/docs/screen_specs.md`
- related title task:
  - `docs/plans/tasks/notebook-editor-03-default-title-and-rename-ux.md`
- current editor shell:
  - `ui/src/features/editor/ui/NotebookEditorView.tsx`
  - `ui/src/features/editor/model/useNotebookEditor.ts`
  - `ui/src/features/notebooks/model/useNotebookSidebar.ts`
- existing status-related surfaces:
  - `ui/src/features/sync/*`
  - `ui/src/features/execution/*`

## Scope

- разделить в editor shell notebook identity area и notebook-level action area согласно docs:
  - `Notebook.Header`
  - `Notebook.TopBar`
- убедиться, что `Notebook.Header` содержит:
  - title display / rename affordance
  - short notebook metadata where needed
- убедиться, что `Notebook.TopBar` содержит notebook-level actions:
  - insert text block
  - insert code block
  - run all
  - stop
  - sync
  - other already-approved notebook-level controls
- привести naming user-visible status items к согласованной терминологии:
  - `Sync status`
  - `Runtime status`
- убрать provider-specific naming из default operational status surface, если он сейчас торчит как primary label
- не смешивать route/storage technical identifiers с notebook header summary
- обновить tests на editor shell composition и visible notebook-level controls

## Out of scope

- redesign notebook sidebar
- block-local chrome redesign
- AI request flow inside text blocks
- backend contract changes
- изменение default title / rename semantics beyond integration already defined in task 03

## Технические ограничения

- `Notebook.Header` не должен превращаться во вторую toolbar
- `Notebook.TopBar` не должен дублировать notebook title/edit affordance
- status surfaces должны оставаться короткими и operational, без длинного explanatory copy
- implementation должна соблюдать FSD boundaries между editor, notebooks, sync и execution slices
- не добавлять новую dependency без approval

## Acceptance Criteria

- [ ] Editor shell визуально и структурно разделяет `Notebook.Header` и `Notebook.TopBar`
- [ ] Notebook title и rename affordance живут в header, а не в notebook-level top bar
- [ ] Top bar содержит notebook-level actions и не смешивается с notebook identity metadata
- [ ] User-visible status labels приведены к `Sync status` / `Runtime status` или эквивалентной согласованной terminology
- [ ] Provider-specific runtime naming не используется как primary default status label в top-level editor controls
- [ ] Editor shell tests покрывают composition header/top bar и presence ключевых controls

## Verification

- [ ] `cd ui && pnpm lint`
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] вручную проверить:
  - title и metadata живут в header
  - insert/run/sync controls живут в top bar
  - runtime/sync statuses читаются отдельно и не перегружают title area

## Dependencies

- `Depends on T3/BTF -> FRONT: Убрать \`local-*\` из notebook title и добавить rename в editor`

## Files likely to change

- `ui/src/features/editor/ui/NotebookEditorView.tsx`
- `ui/src/features/editor/model/useNotebookEditor.ts`
- `ui/src/features/notebooks/model/useNotebookSidebar.ts`
- `ui/src/features/editor/ui/*.test.tsx`
- `ui/src/pages/notebook-editor/ui/*.test.tsx`

## Documentation impact

- `Primary:`
- `docs/plans/tasks/notebook-editor-04-header-topbar-and-status-alignment.md`
- `Likely:`
- `ui/docs/ui_architecture.md`
- `ui/docs/screen_specs.md`
- `ui/docs/ui-structure.md`

## Риски / заметки

- если identity и operational controls останутся смешанными, editor shell продолжит выглядеть как transitional state, а не как зафиксированная V1 structure
- status surfaces легко случайно перегрузить provider/runtime detail; это должно уходить в secondary UI, не в primary header/top bar

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если visual composition или naming policy изменились относительно docs, обновить связанные документы
