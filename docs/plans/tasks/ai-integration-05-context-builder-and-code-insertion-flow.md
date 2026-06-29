# T3/BTF -> FRONT: Реализовать deterministic context builder и code insertion flow

## Status

- `done`

## Цель

Соединить AI request flow с реальной notebook model: детерминированно собирать bounded context для source `text` block и вставлять returned code в правильное место notebook как обычный editable `code` block по правилам Version 1. Эта задача начинается после того, как UI action и transient lifecycle state уже существуют.

## Контекст

- `docs/plans/05-ai-integration-plan.md`
- `api/docs/ai_contract.md`
- `docs/plans/tasks/ai-integration-04-block-action-and-transient-ui-state.md`
- `docs/ai-architecture.md`
- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `ui/docs/ui_architecture.md`
- `docs/ai-test-cases.md`
- notebook/editor state and persistence areas:
  - `ui/src/features/ai/`
  - `ui/src/features/editor/`
  - `ui/src/entities/notebook/`
  - `ui/src/entities/block/`
  - `ui/src/shared/persistence/`

## Scope

- реализовать deterministic context builder для AI request assembly на frontend
- поддержать default behavior эквивалентный `scope: this`
- поддержать минимальный `scope: notebook` по правилам Version 1:
  - include blocks from notebook start through source block inclusive
  - preserve order
  - exclude blocks after source block
- реализовать request-budget trimming logic согласно canonical context reduction principle:
  - source block always preserved
  - insertion metadata preserved
  - lower-priority distant blocks dropped first
- подготовить request payload строго по contract из `api/docs/ai_contract.md` с корректным `context`, `mode`, `language`, source block metadata и insertion strategy
- реализовать insertion flow после successful response:
  - если следующий block empty `code`, вставить code туда
  - иначе создать новый `code` block сразу после source `text` block
  - если next block отсутствует, создать новый `code` block в конце notebook согласно insertion rules
- убедиться, что insertion flow работает с реальной notebook/editing model, а не с отдельным AI-only representation
- покрыть unit/integration tests для context selection и insertion target selection

## Out of scope

- block action UI and transient request lifecycle plumbing
- revise flow с convert-code-to-text behavior
- local `WebLLM` fallback and related context branching
- advanced named-reference scope beyond `this` and `notebook`
- automatic inclusion of execution outputs as default AI context
- execution-session semantic validation of generated code

## Технические ограничения

- default context behavior должен соответствовать `scope: this`
- broader notebook context должен быть bounded and deterministic
- notebook durable block types остаются только `text` и `code`
- frontend insertion logic не должна зависеть от нового AI-specific block model
- source-of-truth notebook structure должна оставаться совместимой с persistence and sync model
- context builder не должен включать secrets, cookies, credentials или unrelated hidden app metadata

## Acceptance criteria

- [ ] Если в source prompt отсутствует directive, frontend ведёт себя как `scope: this` по правилам из `docs/ai-architecture.md` и без локального переопределения semantics
- [ ] Для `scope: this` request context включает только минимально релевантный source-centered context по правилам Version 1
- [ ] Для `scope: notebook` request context включает только блоки от начала notebook до source block включительно, в исходном порядке
- [ ] Если context budget exceeded, source block и insertion metadata сохраняются, а низкоприоритетные distant blocks отбрасываются первыми
- [ ] Successful AI response вставляется в следующий empty `code` block, если он существует сразу после source block
- [ ] Если следующий block не empty `code`, frontend создаёт новый `code` block сразу после source `text` block и вставляет туда generated code
- [ ] Если next block отсутствует, frontend создаёт новый `code` block в конце notebook по согласованным insertion rules
- [ ] Insertion flow создаёт обычный editable `code` block и не вводит отдельную AI-specific notebook representation или AI-only block mutation path
- [ ] Unit или integration coverage существует как минимум для:
- [ ] default `scope: this`
- [ ] explicit `scope: notebook`
- [ ] budget trimming
- [ ] insertion into existing empty code block
- [ ] insertion by creating a new code block

## Verification

- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] запустить unit/integration tests для context builder и insertion flow
- [ ] вручную проверить сценарии из Appendix B в `docs/ai-test-cases.md`
- [ ] вручную проверить, что generated code после insertion редактируется как обычный `code` block

## Dependencies

- `T3/BTF -> BACK: Зафиксировать AI backend contract и error model`
- `T3/BTF -> FRONT: Реализовать block-scoped AI action и transient UI state`
- notebook persistence/local-first editor model должен быть достаточно стабилен для block insertion behavior

## Files likely to change

- `ui/src/features/ai/model/`
- `ui/src/features/editor/model/`
- `ui/src/entities/notebook/`
- `ui/src/entities/block/`
- `ui/src/shared/persistence/`
- frontend test files covering editor and AI behavior

## Documentation impact

- `Primary:`
- `docs/plans/tasks/ai-integration-05-context-builder-and-code-insertion-flow.md`
- `Conditional if behavior is clarified:`
- `docs/ai-architecture.md`
- `ui/docs/ui_architecture.md`
- `docs/plans/05-ai-integration-plan.md`
- `docs/ai-test-cases.md`

## Риски / заметки

- insertion flow напрямую зависит от реальной notebook editing model; если editor state ownership ещё меняется, нельзя плодить parallel AI-only path для block mutations
- budget trimming без фиксированных правил быстро станет недетерминированным и приведёт к плавающим тестам
- `scope: notebook` легко разрастается в implicit “send whole notebook”; эта задача должна удерживать строго bounded behavior

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если implementation потребовала уточнить context contract или insertion rules, зафиксировать delta в `api/docs/ai_contract.md` и/или `docs/ai-architecture.md`
- если verification была достигнута эквивалентными test paths, кратко указать это здесь
- verification achieved through `CI=true pnpm test -- src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx src/features/editor/model/useNotebookEditor.persistence.test.ts`, which executed the full `ui` Vitest suite (`43` files / `157` tests passed)
