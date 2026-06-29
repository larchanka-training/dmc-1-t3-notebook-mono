# T3/BTF -> FRONT: Заменить block position badge на execution-order badge для code blocks

## Status

- `done`

## Цель

Сделать block-local execution feedback полезным для реального notebook workflow: вместо декоративного position badge code blocks должны показывать compact execution-order badge в стиле Colab/Jupyter, чтобы пользователь видел, какие блоки уже выполнялись и в каком порядке в текущей execution timeline.

## Контекст

- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `docs/qa_plan.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/ui-structure.md`
- related editor tasks:
  - `docs/plans/tasks/notebook-editor-01-block-toolbar-and-primary-actions.md`
  - `docs/plans/tasks/notebook-editor-02-compact-block-chrome-and-insert-bars.md`
- current implementation surfaces:
  - `ui/src/features/editor/ui/NotebookBlockView.tsx`
  - `ui/src/features/editor/model/useNotebookEditor.ts`
  - `ui/src/features/execution/model/types.ts`
  - `ui/src/features/execution/model/executionSlice.ts`
- execution state tests:
  - `ui/src/features/execution/model/executionSlice.test.ts`
  - `ui/src/app/model/store.test.ts`
  - `ui/src/app/model/persist.test.ts`

## Scope

- убрать user-facing block position badge как default indicator внутри notebook blocks
- оставить compact badge только для `code` blocks в block gutter
- рендерить пустой badge для `code` block до первого успешного выполнения
- после успешного выполнения присваивать block следующий execution-order number внутри текущей execution timeline
- при повторном выполнении того же блока заменять старый номер на новый последний execution-order number
- сохранять execution-order numbering между `run current` и `run from here`, пока текущая execution session остается валидной
- сбрасывать numbering timeline при `run all` и при session-reset boundaries, которые явно создают новую execution session
- обновить execution store и tests так, чтобы UI получал execution-order number, а не только boolean success marker

## Out of scope

- изменение AI action model для `text` blocks
- redesign notebook top bar или block toolbar
- изменение output rendering contract
- изменение live worker runtime semantics beyond execution-order UI state
- новые block types или новые notebook-wide execution controls

## Технические ограничения

- badge должен отображаться только для `code` blocks; `text` blocks не получают placeholder badge
- numbering относится к текущей frontend-managed execution timeline, а не к document order
- `run all` в текущей архитектуре остается explicit clean-session boundary и начинает numbering заново с `1`
- implementation должна оставаться в существующих FSD boundaries между `features/editor` и `features/execution`
- execution-order state не должен persistиться через reload как durable notebook content

## Acceptance criteria

- [x] `text` blocks больше не показывают block position badge
- [x] `code` blocks показывают compact execution badge в gutter
- [x] До первого успешного run badge у `code` block остается пустым
- [x] После успешного run block получает execution-order number текущей session timeline
- [x] Повторный успешный run того же блока заменяет предыдущий номер на новый последний execution-order number
- [x] Последовательные `run current` и `run from here` сохраняют общую numbering timeline, пока session не reset
- [x] `run all` очищает предыдущую numbering timeline и начинает новую с `1`
- [x] Execution store tests покрывают assignment, rerun replacement и reset semantics execution-order state

## Verification

- [x] `cd ui && pnpm vitest run src/features/execution/model/executionSlice.test.ts src/app/model/store.test.ts src/app/model/persist.test.ts`
- [x] `cd ui && pnpm exec tsc --noEmit`
- [ ] вручную проверить в editor:
  - `code` block до запуска показывает пустой badge
  - два последовательных run дают номера `1`, `2`
  - повторный run первого блока обновляет его номер на следующий по порядку
  - `run all` очищает предыдущую numbering timeline и начинает ее заново

## Dependencies

- `Depends on T3/BTF -> FRONT: Разделить Block.ActionCluster и Block.Toolbar`
- `Depends on T3/BTF -> FRONT: Упростить block chrome и ввести inline insert bars`

## Documentation impact

- `Required:`
- `ui/docs/ui-structure.md`

## Риски / заметки

- если execution-order semantics в UI и execution runtime разойдутся, badge начнет выглядеть nondeterministic при mixed flows `run current` / `run from here`
- при будущих изменениях session reset boundaries нужно отдельно сверять, должен ли execution-order timeline переживать новый boundary или очищаться

## Completion update

- статус обновлен до `done` после implementation и verification
- `ui/docs/ui-structure.md` синхронизирован с execution-order badge semantics
- если future runtime semantics изменят reset boundaries, обновить этот task artifact и связанные UI docs
