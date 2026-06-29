# T3/BTF -> FRONT: Добавить notebook deletion flow для list, sidebar и editor

## Status

- `proposed`

## Цель

Добавить пользовательский flow удаления notebook в frontend так, чтобы V1 notebook management соответствовал `docs/project.md`: пользователь может удалить notebook из списка и из editor context, а локальное и server-backed состояние очищается без зависших working copies, execution state или неверной navigation.

## Контекст

- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `docs/qa_plan.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/screen_specs.md`
- `ui/docs/api_contracts.md`
- `api/docs/persistence.md`
- existing backend delete contract:
  - `api/app/features/notebooks/router.py`
  - `api/app/features/notebooks/service.py`
  - `api/tests/integration/notebooks/test_delete.py`
- current frontend notebook flows:
  - `ui/src/features/notebooks/model/useNotebooksList.ts`
  - `ui/src/features/notebooks/ui/NotebooksList.tsx`
  - `ui/src/features/notebooks/model/useNotebookSidebar.ts`
  - `ui/src/features/notebooks/ui/NotebookSidebar.tsx`
  - `ui/src/features/editor/model/useNotebookEditor.ts`
  - `ui/src/features/editor/ui/NotebookEditorView.tsx`

## Scope

- добавить frontend delete flow для notebook items
- зафиксировать различие между удалением:
  - `local-only` notebook
  - `synced` notebook с `serverId`
  - `remote-only` notebook, ещё не скачанного в local working copy
- реализовать route-safe cleanup при удалении активного notebook
- обновить list/sidebar/editor tests и MSW handlers под `DELETE /api/v1/notebooks/:notebookId`
- выровнять docs, если deletion entry points или UX policy меняют текущие screen expectations

## Out of scope

- soft delete / restore / trash bin
- bulk deletion
- sync conflict redesign
- export-before-delete flow
- backend contract changes beyond already documented `204 No Content`

## Технические ограничения

- deletion semantics должны оставаться aligned с `api/docs/persistence.md`: server-backed delete это hard delete с `204`
- frontend не должен пытаться вызывать backend delete для `local-only` notebooks без `serverId`
- deletion активного notebook не должен оставлять пользователя на `/notebooks/:notebookId` после удаления working copy
- execution/session state и sync state для deleted active notebook должны очищаться deterministically
- implementation должна соблюдать FSD boundaries; delete API wiring не должно расползаться в editor UI без feature/model boundary
- не добавлять новую dependency без approval

## Assumptions

- `remote-only` notebook можно удалять из list/sidebar без предварительного open: frontend вызывает backend `DELETE` по `serverId` и убирает item из merged list
- `synced` notebook при удалении удаляется и с backend, и из local repository
- `local-only` notebook удаляется только из local repository и из list state
- базовый UX использует явное confirm step перед destructive action; точная visual form (`AlertDialog`, inline confirm, browser confirm) выбирается в implementation, но должна быть testable
- после удаления активного notebook пользователь редиректится на `/notebooks`

## Planned Tasks

## Task 1: `T3/BTF -> FRONT: Add delete state primitives and notebook deletion adapter`

**Description:** Добавить feature-level primitives для notebook deletion, не смешивая destructive logic с presentational components. Это включает delete API adapter, local repository cleanup и store/list updates для merged notebook items.

**Acceptance criteria:**
- [ ] Frontend имеет явный delete adapter для `DELETE /api/v1/notebooks/:notebookId`
- [ ] Notebook list feature умеет удалить item по `local id`, `serverId` или их комбинации без full page reload
- [ ] Local repository cleanup покрывает `local-only` и `synced` notebooks, не ломая merge logic для remaining items
- [ ] `remote-only` item может быть удалён через backend и исчезает из merged list без создания local copy

**Verification:**
- [ ] `cd ui && pnpm test -- --runInBand useNotebooksList`
- [ ] `cd ui && pnpm test -- --runInBand NotebookSidebar`

**Dependencies:** `None`

**Initial status:** `planned`

**Documentation impact:**
- `Likely:`
- `ui/docs/api_contracts.md`

**Likely files or areas:**
- `ui/src/features/notebooks/model/useNotebooksList.ts`
- `ui/src/features/notebooks/model/notebookListSlice.ts`
- `ui/src/features/sync/api/notebookSyncApi.ts`
- `ui/test/msw/handlers/notebooks.ts`

**Scope:** M

## Task 2: `T3/BTF -> FRONT: Expose delete actions in notebook list, sidebar, and editor context`

**Description:** Добавить user-visible delete entry points в notebook management surfaces и обеспечить безопасное поведение для активного notebook. Пользователь должен понимать, что именно удаляется, и после удаления не оставаться в битом editor route.

**Acceptance criteria:**
- [ ] Notebook list screen имеет delete action для item и confirmation step перед удалением
- [ ] Editor sidebar имеет delete action для relevant notebook item или active notebook context без нарушения compact navigation layout
- [ ] Когда удаляется активный notebook, frontend очищает editor-related local state и переводит пользователя на `/notebooks`
- [ ] Во время delete request destructive control не допускает повторный submit и показывает минимальный pending/error feedback

**Verification:**
- [ ] `cd ui && pnpm test -- --runInBand NotebooksListPage`
- [ ] `cd ui && pnpm test -- --runInBand NotebookEditorPage`
- [ ] вручную проверить:
- [ ] delete `local-only` notebook из list
- [ ] delete `synced` notebook из active editor route с redirect на `/notebooks`

**Dependencies:** `T3/BTF -> FRONT: Add delete state primitives and notebook deletion adapter`

**Initial status:** `planned`

**Documentation impact:**
- `Likely:`
- `ui/docs/screen_specs.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/notebook_editor_sidebar.md`

**Likely files or areas:**
- `ui/src/features/notebooks/ui/NotebooksList.tsx`
- `ui/src/features/notebooks/ui/NotebookSidebar.tsx`
- `ui/src/features/notebooks/model/useNotebookSidebar.ts`
- `ui/src/features/editor/ui/NotebookEditorView.tsx`
- `ui/src/features/editor/model/useNotebookEditor.ts`
- `ui/src/pages/notebook-editor/ui/NotebookEditorPage.tsx`

**Scope:** M

## Task 3: `T3/BTF -> QA: Lock deletion regressions across local-first and server-backed flows`

**Description:** Закрыть регрессии на стыке list merge, local persistence и server-backed delete contract, чтобы deletion не вызывал phantom items, broken redirects или stale working copies после reload.

**Acceptance criteria:**
- [ ] Tests покрывают delete для `local-only`, `synced` и `remote-only` notebooks
- [ ] Tests подтверждают, что удалённый active notebook больше не открывается после redirect/reload
- [ ] MSW delete handler поддерживает `204`, `404` и predictable error path для frontend tests
- [ ] Если implementation меняет documented notebook management actions, связанные docs обновлены

**Verification:**
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] `cd ui && pnpm lint`

**Dependencies:** `T3/BTF -> FRONT: Expose delete actions in notebook list, sidebar, and editor context`

**Initial status:** `planned`

**Documentation impact:**
- `Required if behavior changed:`
- `docs/qa_plan.md`
- `ui/docs/screen_specs.md`
- `ui/docs/ui_architecture.md`

**Likely files or areas:**
- `ui/src/features/notebooks/model/*.test.tsx`
- `ui/src/pages/notebook-editor/ui/*.test.tsx`
- `ui/test/msw/handlers/notebooks.ts`
- `docs/qa_plan.md`

**Scope:** S

## Риски / заметки

- самый рискованный участок не backend, а merged local/server list: легко удалить local record, но оставить phantom `remote-only` item или наоборот
- удаление active notebook без явного cleanup может оставить stale execution outputs и toolbar state до следующего mount
- если delete action добавить только на `/notebooks`, editor sidebar останется inconsistent notebook-management surface
- если использовать слишком лёгкий confirm UX без pending/error handling, пользователь легко получит double-submit или не поймёт, что server delete не завершился

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если итоговый UX сужает scope (например, delete только из list page), это нужно явно зафиксировать как delta
- если docs не потребовали updates, отметить это явно в этой секции
