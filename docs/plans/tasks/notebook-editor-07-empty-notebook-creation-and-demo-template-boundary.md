# T3/BTF -> FRONT: Убрать demo-seed из create flow и ввести empty notebook UX

## Status

- `done`

## Цель

Сделать создание нового notebook продуктовым и предсказуемым: новый notebook не должен содержать заранее подставленный demo/debug контент, а первый пользовательский шаг должен идти через явный empty-state UX с действиями вставки block и, при необходимости, отдельным доступом к example notebook.

## Контекст

- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `docs/qa_plan.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/ui-structure.md`
- `ui/docs/help_content.md`
- current local draft and editor seed behavior:
  - `ui/src/entities/notebook/lib/localDraftNotebook.ts`
  - `ui/src/entities/notebook/lib/sampleNotebook.ts`
  - `ui/src/features/notebooks/model/useNotebooksList.ts`
  - `ui/src/features/editor/model/useNotebookEditor.ts`
- related editor UX tasks:
  - `docs/plans/tasks/notebook-editor-03-default-title-and-rename-ux.md`
  - `docs/plans/tasks/notebook-editor-04-header-topbar-and-status-alignment.md`

## Scope

- убрать использование `sampleNotebook` как дефолтного содержимого для нового local draft notebook
- зафиксировать canonical create behavior:
  - новый notebook создается без demo/debug blocks
  - active working copy для нового notebook открывается как empty notebook
- определить и реализовать empty-state UX для `Notebook.Canvas`, когда `blocks.length === 0`
- empty-state UX должен давать пользователю как минимум явные действия:
  - insert text block
  - insert code block
- при необходимости сохранить `sampleNotebook` только как отдельный example/demo artifact, а не как source для обычного create flow
- убрать route-level fallback, при котором editor для нового notebook синхронно показывает seeded sample content до загрузки local state
- убедиться, что create flow, editor open flow и local persistence используют одну и ту же semantics пустого notebook
- обновить frontend tests на:
  - create notebook opens without prefilled demo blocks
  - empty-state actions create the expected first block
  - persisted empty notebook reopens consistently

## Out of scope

- redesign notebook top bar или sidebar beyond changes, необходимых для empty-state entry point
- полноценная template gallery
- backend API changes для notebook creation
- изменение block model, execution model или sync semantics
- переписывание help page целиком
- локализация empty-state copy

## Технические ограничения

- Version 1 block types остаются только `text` и `code`
- notebook content format остается canonical structured `JSON`
- решение должно сохранять local-first ownership: новый notebook создается и живет во frontend + local persistence до sync
- empty-state не должен подменять собой `Notebook.TopBar`; notebook-level insert actions остаются доступны и вне empty-state
- `sampleNotebook`, если остается в кодовой базе, не должен снова использоваться как implicit default content source
- implementation должна соблюдать FSD boundaries между `entities/notebook`, `features/notebooks` и `features/editor`
- не добавлять новую dependency без approval

## Acceptance criteria

- [ ] Создание нового notebook больше не копирует demo/debug blocks из `sampleNotebook` или эквивалентного seeded source
- [ ] При открытии нового notebook пользователь видит пустой `Notebook.Canvas`, а не заранее заполненный документ
- [ ] Empty-state в canvas содержит как минимум явные действия `insert text block` и `insert code block`
- [ ] Выбор empty-state действия создает первый block ожидаемого типа и переводит notebook из empty state в обычный editor flow
- [ ] Перезагрузка страницы или повторное открытие нового local notebook сохраняет согласованное empty-state или уже созданный первый block без возврата seeded demo content
- [ ] Обычный create flow и route open flow не показывают sample content как временный synchronous fallback
- [ ] Frontend tests покрывают empty create behavior и первый block insertion path

## Verification

- [ ] `cd ui && pnpm lint`
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] вручную проверить сценарий:
  - создать новый notebook
  - убедиться, что editor открывается без предзаполненных blocks
  - добавить первый text block из empty state
  - перезагрузить страницу и убедиться, что block сохранен локально
- [ ] вручную проверить сценарий:
  - создать новый notebook
  - не добавлять blocks
  - перезагрузить страницу и убедиться, что empty-state остается пустым и не превращается в demo notebook

## Dependencies

- `Depends on T3/BTF -> FRONT: Убрать \`local-*\` из notebook title и добавить rename в editor`
- `Align with T3/BTF -> FRONT: Выравнять Notebook.Header, Notebook.TopBar и status surfaces`

## Files likely to change

- `ui/src/entities/notebook/lib/localDraftNotebook.ts`
- `ui/src/entities/notebook/lib/sampleNotebook.ts`
- `ui/src/entities/notebook/index.ts`
- `ui/src/features/notebooks/model/useNotebooksList.ts`
- `ui/src/features/editor/model/useNotebookEditor.ts`
- `ui/src/features/editor/ui/NotebookEditorView.tsx`
- `ui/src/features/editor/ui/*.test.tsx`
- `ui/src/features/notebooks/model/*.test.tsx`
- `ui/src/pages/notebook-editor/ui/*.test.tsx`

## Documentation impact

- `Primary:`
- `docs/plans/tasks/notebook-editor-07-empty-notebook-creation-and-demo-template-boundary.md`
- `Likely:`
- `ui/docs/ui-structure.md`
- `ui/docs/help_content.md`
- `ui/docs/ui_architecture.md`

## Риски / заметки

- если seeded sample убрать только из `createLocalDraftNotebook`, но оставить route fallback в editor, пользователь продолжит видеть ложный demo state при открытии нового notebook
- если empty-state UX будет доступен только в canvas, но не будет согласован с existing top bar insert actions, flow станет визуально раздвоенным
- example/demo notebook полезен для demo и onboarding, но его нужно держать как явный template или отдельный action, а не как скрытый default
- если tests останутся завязаны на seeded blocks, они начнут маскировать regressions в реальном create flow

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если вместе с реализацией будет выбран отдельный user-facing example/template entry point, зафиксировать итоговую UX semantics в `Documentation impact`
- если `sampleNotebook` будет удален или переименован, обновить связанные tests и references в docs
