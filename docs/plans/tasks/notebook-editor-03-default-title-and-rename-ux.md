# T3/BTF -> FRONT: Убрать `local-*` из notebook title и добавить rename в editor

## Status

- `proposed`

## Цель

Сделать notebook naming предсказуемым и пользовательским: новый local notebook должен открываться с нейтральным дефолтным названием, внутренний local route/storage id не должен попадать в видимый `title`, а пользователь должен иметь возможность переименовать notebook прямо из editor без полного sync flow.

## Контекст

- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `docs/qa_plan.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/screen_specs.md`
- existing notebook title/default behavior:
  - `ui/src/features/notebooks/model/notebookListSlice.ts`
  - `ui/src/features/notebooks/model/useNotebooksList.ts`
  - `ui/src/features/notebooks/model/useNotebookSidebar.ts`
  - `ui/src/features/editor/model/useNotebookEditor.ts`
  - `ui/src/features/editor/ui/NotebookEditorView.tsx`
- existing backend metadata rename contract:
  - `api/app/features/notebooks/router.py`
  - `api/app/features/notebooks/service.py`
  - `api/tests/integration/notebooks/test_item.py`
  - `api/tests/integration/notebooks/test_revision.py`
- related backend task:
  - `docs/plans/tasks/notebook-persistence-04-item-and-metadata-update-endpoints.md`

## Scope

- зафиксировать единое дефолтное название нового notebook для frontend UX и использовать его последовательно в create/list/editor/sidebar flows
- убрать fallback naming вида `Notebook ${id}` и любые другие user-visible title, построенные из local route/storage id
- обеспечить, что новый local notebook сразу открывается с пользовательским title, а не с technical identifier
- добавить в notebook editor user-visible rename affordance для `title` area
- реализовать local rename path:
  - изменение title обновляет active working copy
  - изменение сохраняется в local persistence
  - unsynced local notebook не требует backend round-trip для rename
- реализовать synced rename path:
  - для notebook с `serverId` frontend использует существующий metadata update contract `PATCH /api/v1/notebooks/{notebook_id}`
  - rename не должен ждать full sync action и не должен эмулировать snapshot sync
- синхронизировать editor title, sidebar item title и notebook list title после rename без перезагрузки страницы
- определить и реализовать UX для rename interaction:
  - inline edit в header или эквивалентный явный edit control
  - keyboard-friendly submit/cancel behavior
  - понятный disabled/pending/error state для server-backed rename
- обновить frontend regression coverage для default title, route open behavior и rename flows

## Out of scope

- redesign всего notebook header или global toolbar
- rename из списка `/notebooks`, если для этого нужен отдельный UI flow
- массовое переименование, slug generation, search normalization
- изменение backend rename contract или revision semantics
- autosave/sync redesign beyond title rename handling
- локализация naming policy beyond one approved default English title

## Технические ограничения

- local route/storage id (`local-...`) остается внутренним идентификатором и не должен использоваться как user-facing notebook title
- решение должно сохранять local-first ownership модели: active working copy живет во frontend + local storage
- synced rename должен использовать существующий metadata update endpoint, а не full `/sync`
- frontend implementation должна оставаться в FSD boundaries:
  - notebook list logic в `features/notebooks`
  - editor title interaction в `features/editor`
  - backend request adapter для rename в соответствующем API/model слое
- rename не должен silently ломать current revision/conflict semantics
- не добавлять новую dependency без отдельного approval

## Acceptance criteria

- [ ] Новый notebook в create flow получает единый дефолтный title, согласованный между notebook list, sidebar и editor
- [ ] Во frontend больше нет user-visible title вида `Notebook local-...`, `Notebook <id>` или другого названия, собранного из internal local id
- [ ] При открытии нового local notebook editor header показывает дефолтный title, а не technical route id
- [ ] Пользователь может переименовать notebook из `/notebooks/:notebookId` через явный edit flow в области title
- [ ] Rename local-only notebook обновляет UI и local persistence без backend dependency
- [ ] Rename synced notebook отправляет отдельный metadata update request на `PATCH /api/v1/notebooks/{notebook_id}` и обновляет UI после успешного ответа
- [ ] Ошибка server-backed rename показывается пользователю явно и не приводит к silent desync title между editor и persisted state
- [ ] Rename не требует full manual sync action и не меняет execution state сам по себе
- [ ] Keyboard interaction для rename поддерживает как минимум start edit, submit и cancel
- [ ] Frontend tests покрывают default title policy, отсутствие `local-*` leak и rename behavior минимум для local notebook и synced notebook

## Verification

- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] `cd ui && pnpm lint`
- [ ] вручную проверить сценарий:
  - создать notebook из sidebar
  - убедиться, что editor и sidebar показывают дефолтный title без `local-*`
  - переименовать notebook до sync
  - перезагрузить страницу и убедиться, что local title сохранился
- [ ] вручную проверить сценарий:
  - sync notebook с backend
  - переименовать уже synced notebook
  - убедиться, что title обновился без запуска full sync и сохраняется после reopen
- [ ] вручную проверить error path для failed rename request и убедиться, что пользователь видит ошибку, а текущий title state остается консистентным

## Dependencies

- `Depends on T3/BTF -> BACK: Реализовать notebook retrieval и metadata update endpoints`
- `Depends on T3/BTF -> BACK: Зафиксировать revision semantics и sync-ready notebook responses`

## Files likely to change

- `ui/src/features/notebooks/model/notebookListSlice.ts`
- `ui/src/features/notebooks/model/useNotebooksList.ts`
- `ui/src/features/notebooks/model/useNotebookSidebar.ts`
- `ui/src/features/editor/model/useNotebookEditor.ts`
- `ui/src/features/editor/ui/NotebookEditorView.tsx`
- `ui/src/features/sync/api/notebookSyncApi.ts`
- `ui/src/features/notebooks/model/*.test.tsx`
- `ui/src/features/editor/ui/*.test.tsx`
- `ui/src/pages/notebook-editor/ui/*.test.tsx`

## Documentation impact

- `Likely:`
- `ui/docs/ui_architecture.md`
- `ui/docs/screen_specs.md`
- `docs/qa_plan.md`

## Риски / заметки

- сейчас в коде есть несколько разных default/fallback naming paths; если исправить только один, `local-*` продолжит протекать через другой surface
- rename для synced notebook легко случайно привязать к full sync path; это ухудшит UX и размоет уже существующий backend metadata contract
- если editor title и notebook list state обновляются разными источниками, нужен явный plan для их согласования после rename
- для дефолтного названия нужно выбрать один canonical вариант (`Untitled` или `Untitled notebook`) и не смешивать оба в интерфейсе

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговый rename UX или default title policy изменили зафиксированное поведение
- если реализация не потребовала doc changes, явно дописать это в этой секции
- если итоговая реализация отклонилась от исходного task scope, кратко зафиксировать delta в этой секции
