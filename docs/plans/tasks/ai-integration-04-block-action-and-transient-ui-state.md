# T3/BTF -> FRONT: Реализовать block-scoped AI action и transient UI state

## Status

- `done`

## Цель

Добавить в notebook editor первый пользовательский AI entrypoint для source `text` block и реализовать transient frontend state для AI request lifecycle, чтобы пользователь мог запускать backend-mediated AI generation без изменения durable notebook schema. Эта задача заканчивается на UI action и lifecycle state и не включает context builder или block insertion.

## Контекст

- `docs/plans/05-ai-integration-plan.md`
- `api/docs/ai_contract.md`
- `docs/plans/tasks/ai-integration-02-authenticated-endpoint-and-provider-boundary.md`
- `docs/ai-architecture.md`
- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `ui/docs/ui_architecture.md`
- `docs/ai-test-cases.md`
- frontend editor and AI areas:
  - `ui/src/features/ai/`
  - `ui/src/features/editor/`
  - `ui/src/entities/block/`
  - `ui/src/shared/api/`

## Scope

- добавить AI action в block-level UI для source `text` block в рамках существующей block action cluster / editor interaction model
- реализовать transient AI state для source block без изменения durable notebook JSON schema
- поддержать минимум состояний AI request lifecycle:
  - `idle`
  - `submitting`
  - `success`
  - `error`
- реализовать frontend request flow к backend endpoint `POST /api/v1/ai/code-blocks/generate` строго по contract из `api/docs/ai_contract.md`
- отобразить user-visible loading and error states для AI request lifecycle без скрытого сайд-эффекта на notebook content
- сохранить source prompt/text block content неизменным при backend errors и rejected requests
- подключить normalized backend errors к UI state так, чтобы frontend мог различать contract-level classes ошибок без ad hoc string matching
- сохранить AI state как transient feature/editor state, а не как persisted notebook content или output artifact
- покрыть UI integration tests для idle, submitting, success и error states

## Out of scope

- deterministic context builder logic beyond minimal request assembly
- insertion of generated code into notebook blocks
- revise flow with convert-code-to-text behavior
- `WebLLM` fallback UI
- advanced UX around AI history, draft comparison or side-by-side diff
- durable storage of AI request/response state
- broader notebook-level context controls beyond minimal state plumbing

## Технические ограничения

- frontend architecture должна остаться в FSD boundaries; AI behavior живёт в `ui/src/features/ai/`
- notebook durable schema не расширять; новый `ai` block type добавлять нельзя
- AI state не должен сохраняться в canonical notebook snapshot, IndexedDB notebook content или sync payload как notebook data
- frontend должен использовать backend API contract; direct browser-to-provider path не добавлять
- block-scoped behavior должен оставаться привязанным к `text` block source surface
- UI components с поведением должны следовать проектному hook/component split внутри slice

## Acceptance criteria

- [ ] В editor UI существует AI action для source `text` block, доступный без изменения существующего notebook block model
- [ ] AI action не отображается как durable notebook block и не создаёт новую block type semantics
- [ ] Frontend хранит AI request lifecycle в transient state, а не в persisted notebook content
- [ ] При запуске AI request UI переходит в `submitting` state и показывает пользователю ожидаемую loading feedback
- [ ] При successful backend response UI переходит в `success` state и делает result доступным для следующего slice без самостоятельной block insertion logic
- [ ] При backend validation/auth/policy/provider errors UI переходит в `error` state и сохраняет source prompt/content без изменений
- [ ] Frontend корректно различает contract-level classes ошибок, необходимые для UI state mapping, на уровне UI state
- [ ] Notebook content и sync/durable state не меняются только из-за lifecycle state transitions (`idle/submitting/success/error`)
- [ ] UI integration coverage существует как минимум для:
- [ ] idle render
- [ ] loading state during request
- [ ] success state after resolved request
- [ ] error state after rejected request

## Verification

- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] запустить UI integration tests для AI feature state and block action behavior
- [ ] вручную проверить в editor, что AI state не сохраняется как notebook content после reload без explicit insertion flow
- [ ] вручную проверить, что source `text` block не мутирует при rejected/error responses

## Dependencies

- `T3/BTF -> BACK: Зафиксировать AI backend contract и error model`
- `T3/BTF -> BACK: Реализовать authenticated AI endpoint и provider boundary`

## Files likely to change

- `ui/src/features/ai/`
- `ui/src/features/editor/`
- `ui/src/entities/block/`
- `ui/src/shared/api/`
- `ui/src/shared/types/`
- `ui/src/shared/lib/`
- `ui/tests/` or existing frontend test locations

## Documentation impact

- `Primary:`
- `docs/plans/tasks/ai-integration-04-block-action-and-transient-ui-state.md`
- `Conditional if UI behavior clarifies architecture expectations:`
- `ui/docs/ui_architecture.md`
- `docs/plans/05-ai-integration-plan.md`
- `docs/ai-architecture.md`

## Риски / заметки

- если transient AI state случайно попадёт в notebook persistence or sync model, это сломает зафиксированную Version 1 content boundary
- UI error mapping нужно строить от normalized backend errors; ad hoc string matching приведёт к хрупкому поведению
- success state здесь не должен означать insertion complete; insertion начинается только в следующем frontend slice

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если implementation выявила gaps в backend contract для UI state mapping, зафиксировать это в `api/docs/ai_contract.md`
- если verification достигнута через другие эквивалентные frontend test paths, кратко отметить это здесь
