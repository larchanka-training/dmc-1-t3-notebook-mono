# T3/BTF -> QA: Добавить regression coverage для live worker session

## Status

- `done`

## Цель

Расширить automated и manual verification для Stage 6 так, чтобы `live worker session` behavior, отсутствие replay side effects, reset semantics и failure recovery были закреплены regression coverage, а не только локальными unit assertions в runtime core.

## Контекст

- `docs/plans/04-live-worker-session-transition-plan.md`
- `docs/plans/tasks/live-worker-session-01-target-semantics-and-contracts.md`
- `docs/plans/tasks/live-worker-session-02-runtime-core-migration.md`
- `docs/qa_plan.md`
- `ui/docs/runtime_architecture.md`
- текущие execution/runtime tests:
  - `ui/src/features/execution/lib/notebookRuntimeCore.test.ts`
  - `ui/src/features/execution/lib/notebookWorkerBridge.test.ts`
  - `ui/src/features/execution/model/executionSlice.test.ts`
  - `ui/src/features/editor/ui/NotebookEditorView.test.tsx`

## Scope

- добавить regression scenarios для live session behavior на уровнях, где это реально проверяется в текущем UI/runtime stack:
  - runtime core tests
  - worker bridge tests
  - editor/execution integration tests при необходимости
- закрепить automated coverage минимум для сценариев:
  - repeated `run current` одного и того же блока
  - repeated `run from here` без upstream replay side effects
  - shared mutable state across sequential blocks
  - `run all` как clean reset boundary
  - behavior after `stop`
  - behavior after timeout
  - syntax/runtime error without silent session corruption beyond documented boundary
- обновить verification guidance в relevant docs/task artifacts, если текущий smoke checklist не покрывает Stage 6 semantics
- подготовить manual QA checklist для mixed notebooks с `text` и `code` blocks, где легко пропустить regression в sequencing или output binding

## Out of scope

- реализация самой live worker session migration
- расширение output renderer под новые output types
- Playwright-heavy end-to-end campaign, если runtime behavior достаточно надёжно покрывается unit/integration уровнями
- backend QA scope

## Технические ограничения

- coverage должна проверять target semantics, а не детали конкретной внутренней реализации
- тесты не должны закреплять replay-specific допущения как expected behavior
- verification должна оставаться выполнимой в существующем `Vitest`-based frontend stack без новых зависимостей
- manual scenarios должны использовать project vocabulary: `run current`, `run all`, `run from here`, `execution session`

## Acceptance criteria

- [x] В automated test suite есть отдельные regression scenarios для repeated `run current`, repeated `run from here`, `run all` reset и post-timeout/post-stop recovery
- [x] Есть проверка, что downstream повторные runs не вызывают upstream side-effect replay только ради восстановления state
- [x] Есть проверка, что shared state между sequential blocks сохраняется в live session до явного reset или terminate
- [x] Есть проверка, что syntax/runtime error обрабатываются по задокументированным правилам и не ломают следующий корректный run сильнее, чем это допускает contract
- [x] Manual verification checklist для Stage 6 фиксирует минимум сценарии repeated runs, reset, stop/timeout и output binding в mixed notebook
- [x] QA guidance не конфликтует с `docs/qa_plan.md` и текущими runtime architecture docs

## Verification

- [ ] `cd ui && ./node_modules/.bin/vitest run src/features/execution/lib/notebookRuntimeCore.test.ts src/features/execution/lib/notebookWorkerBridge.test.ts src/features/editor/ui/NotebookEditorView.test.tsx`
- [ ] `cd ui && ./node_modules/.bin/tsc -p tsconfig.app.json --noEmit`
- [ ] вручную пройти checklist: repeated `run current`, repeated `run from here`, `run all`, `stop`, timeout, syntax error, runtime error
- [ ] проверить, что обновлённый checklist встроен в task/doc artifacts и может использоваться без чтения всей migration discussion

## Dependencies

- `Depends on T3/BTF -> FRONT: Перевести runtime core с replay на live worker session`

## Files likely to change

- `ui/src/features/execution/lib/notebookRuntimeCore.test.ts`
- `ui/src/features/execution/lib/notebookWorkerBridge.test.ts`
- `ui/src/features/editor/ui/NotebookEditorView.test.tsx`
- `docs/qa_plan.md`
- `ui/docs/runtime_architecture.md`

## Documentation impact

- `Conditional:`
- `docs/qa_plan.md`
- `ui/docs/runtime_architecture.md`
- `docs/plans/04-live-worker-session-transition-plan.md`

## Риски / заметки

- слишком низкоуровневые tests могут не поймать regression между orchestrator и worker bridge; при необходимости стоит добавить один integration-level editor scenario, а не только unit coverage
- важно не раздуть scope до полного E2E-пакета, если Stage 6 риск лучше покрывается дешёвыми targeted tests
- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату

## Completion update

- после выполнения обновить `Status` на `done` или `blocked` по фактическому результату
- обновить документы из `Documentation impact`, если итоговый regression suite изменил recommended verification flow
- если часть planned scenarios была сознательно опущена как дублирующая или слишком дорогая, явно зафиксировать это и чем она компенсирована
- если для QA пришлось скорректировать существующие Stage 5 checks, кратко описать изменения
- integration-level regression coverage добавлен в `ui/src/features/editor/ui/NotebookEditorView.test.tsx`: live-session reuse без upstream replay, timeout reset boundary/recovery и recovery после runtime/syntax errors
- runtime-level coverage из `session-02` не дублировался сверх уже существующих `notebookRuntimeCore` и `notebookWorkerBridge` checks; post-stop recovery остаётся закреплённым на bridge level, а editor-level suite добирает timeout/error integration gaps
- `docs/qa_plan.md` обновлён: Stage 5 acceptance checklist заменён на Stage 6 regression checklist для mixed notebooks с repeated runs, reset boundaries, stop/timeout, errors и output binding
