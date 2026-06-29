# T3/BTF -> FRONT: Реализовать Output Renderer для runtime outputs

## Status

- `done`

## Цель

Реализовать `Output Renderer`, который показывает реальные runtime outputs рядом с originating `code` block, заменяет placeholder output flow и сохраняет архитектурное правило, что outputs являются transient execution artifacts, а не частью durable notebook content.

## Контекст

- `docs/plans/03-execution-runtime.md`
- `docs/plans/tasks/execution-runtime-01-execution-contracts-and-store.md`
- `docs/plans/tasks/execution-runtime-02-worker-runtime-bridge-and-lifecycle.md`
- `docs/plans/tasks/execution-runtime-03-orchestrator-run-sequencing.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/runtime_architecture.md`
- текущее output entity/UI состояние: `ui/src/entities/output/`
- текущий notebook block rendering: `ui/src/features/editor/ui/NotebookBlockView.tsx`, `ui/src/features/editor/ui/NotebookEditorView.tsx`
- текущий placeholder renderer: `ui/src/entities/output/ui/OutputPlaceholderView.tsx`

## Scope

- заменить placeholder output rendering на реальные runtime outputs из execution state
- реализовать rendering минимум для:
  - `text`
  - `object`
  - `table`
  - `error`
- обеспечить понятные UI states для:
  - output отсутствует
  - block сейчас исполняется
  - execution завершился ошибкой
  - output успешно получен
- сохранить визуальную привязку output к originating `code` block
- исключить сохранение output в durable notebook content или локальную notebook snapshot модель
- подготовить renderer к безопасному расширению под `chart`, не делая chart обязательной частью этой задачи

## Out of scope

- chart-specific renderer, если для него нужен отдельный visual contract
- execution controls (`run`, `stop`)
- orchestration sequencing logic
- backend changes
- durable persistence outputs across reload
- полноценный data-grid вместо минимального tabular output renderer

## Технические ограничения

- outputs должны читаться из execution state, а не из notebook content model
- renderer не должен вводить новые notebook block types
- rendering `object` output не должен ломать UI на произвольных JSON-like payloads
- `table` output допустимо реализовать минимально, без расширения scope до сложной табличной платформы
- implementation должна оставаться в рамках frontend FSD boundaries

## Acceptance criteria

- [ ] `Output Renderer` больше не зависит только от placeholder model и может читать реальные runtime outputs по `blockId`
- [ ] `text` output рендерится как читаемый текстовый результат рядом с originating `code` block
- [ ] `object` output рендерится как структурированный вывод без падения UI на типовых payloads
- [ ] `table` output рендерится как минимум в виде понятного табличного или structured fallback representation
- [ ] `error` output показывает нормализованную ошибку с достаточной информацией для пользователя
- [ ] После reload outputs не восстанавливаются как часть durable notebook state

## Verification

- [ ] `cd ui && pnpm test -- output`
- [ ] `cd ui && pnpm test -- editor`
- [ ] вручную проверить mixed notebook с несколькими code blocks и разными output types
- [ ] вручную проверить, что после reload страницы output исчезает до повторного run

## Dependencies

- `Depends on T3/BTF -> FRONT: Подключить execution orchestration и run sequencing`

## Files likely to change

- `ui/src/entities/output/ui/`
- `ui/src/entities/output/model/`
- `ui/src/entities/output/index.ts`
- `ui/src/features/editor/ui/NotebookBlockView.tsx`
- `ui/src/features/editor/ui/NotebookEditorView.tsx`

## Documentation impact

- `Conditional:`
- `ui/docs/ui_architecture.md`
- `ui/docs/runtime_architecture.md`

## Риски / заметки

- если renderer будет слишком тесно связан с текущим execution store shape, дальнейшее добавление `chart` output станет болезненным
- `object` output требует аккуратного fallback-rendering, иначе случайный runtime payload может визуально сломать block layout
- `table` output нужно держать минимальным, чтобы не раздувать Stage 5 scope

## Completion update

- `Status` updated to `done`
- implemented:
  - placeholder output rendering replaced by renderer fed from execution state `outputs[blockId]`
  - rendering for `text`, `object`, `table`, `error`
  - explicit UI states for no output yet, latest run started without outputs, and successful/error outputs
  - output remains visually bound to the originating `code` block in notebook rendering
- verification completed:
  - `cd ui && ./node_modules/.bin/vitest run src/entities/output/ui/OutputView.test.tsx src/features/editor/ui/NotebookEditorView.test.tsx`
  - `cd ui && ./node_modules/.bin/tsc -p tsconfig.app.json --noEmit`
- durable state rule confirmed:
  - runtime outputs are still owned by transient execution state and are not persisted into notebook content or durable notebook snapshot state
  - after reload, outputs do not restore as notebook content because execution state is not durable
- documentation impact:
  - no additional `ui/docs` changes were required for this slice because renderer ownership and transient output boundaries were already reflected by the current runtime/state docs
- delta from original scope:
  - `chart` remains a non-blocking minimal fallback and was not expanded into a dedicated visual contract
