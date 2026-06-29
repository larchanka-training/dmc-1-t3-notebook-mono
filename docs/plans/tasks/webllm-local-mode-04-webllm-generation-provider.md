# T3/BTF -> FRONT: Реализовать WebLLM generation provider

## Status

- `done`

## Цель

Реализовать frontend local provider для AI code generation через `WebLLM`, который принимает тот же нормализованный provider-level prompt/context shape, что и текущий AI flow, при этом при необходимости использует только релевантное подмножество этого контекста внутри local runtime, и возвращает нормализованный code result, совместимый с уже существующим notebook insertion behavior.

## Контекст

- `docs/plans/06-webllm-local-mode-plan.md`
- `docs/ai-architecture.md`
- `ui/docs/ui_architecture.md`
- existing AI frontend flow:
  - `ui/src/features/ai/model/contextBuilder.ts`
  - `ui/src/features/ai/model/useBlockAiAction.ts`
  - `ui/src/features/ai/api/aiApi.ts`
- planned runtime foundation:
  - `docs/plans/tasks/webllm-local-mode-03-runtime-bootstrap-and-capability-checks.md`

## Scope

- реализовать local provider implementation поверх выбранного `WebLLM` runtime
- принимать те же normalized inputs, что и backend path:
  - prompt
  - source text
  - relevant blocks
  - notebook title when present
  - insertion strategy metadata if needed by current abstraction
- при необходимости использовать reduced subset этого контекста внутри local runtime, не меняя внешний provider-abstraction contract
- нормализовать provider output до plain `JavaScript` code
- возвращать provider metadata `provider = webllm`
- реализовать frontend-local error mapping для:
  - unsupported runtime
  - model bootstrap failure
  - timeout / cancellation
  - invalid or unusable provider response
- сохранить совместимость с existing insertion flow и transient AI status model

## Out of scope

- explicit UI controls for `Generate locally`
- retry after backend failure
- local-draft eligibility policy
- backend-side validation or screening changes

## Технические ограничения

- нельзя создавать отдельный notebook insertion path для `WebLLM`
- нельзя менять block model, source block semantics или context builder rules
- local provider должен укладываться в already planned frontend provider abstraction
- reduced context inside local runtime допустим, но внешний provider-level input shape должен оставаться совместимым с backend path
- если provider output требует lightweight post-processing, это не должно silently diverge from existing notebook AI semantics

## Acceptance criteria

- [ ] В frontend существует рабочая `WebLLM` provider implementation, совместимая с общим AI provider abstraction
- [ ] Local provider принимает тот же normalized provider-level input shape, что и backend-backed provider path, даже если внутри использует reduced subset context
- [ ] Local provider возвращает plain code result и `provider = webllm`
- [ ] Local provider маппит основные failure classes в стабильные frontend-local errors
- [ ] Existing code insertion semantics могут использовать результат local provider без отдельной ветки notebook mutation logic

## Verification

- [x] `cd ui && pnpm test -- --runInBand`
- [x] добавить/запустить unit tests на success path local provider
- [x] добавить/запустить unit tests на unsupported / timeout / invalid-response cases
- [x] вручную сверить, что provider result shape совместим с current notebook insertion flow

## Dependencies

- `T3/BTF -> FRONT: Добавить WebLLM runtime bootstrap и capability checks`

## Files likely to change

- `ui/src/features/ai/api/`
- `ui/src/features/ai/lib/`
- `ui/src/features/ai/model/`
- AI feature tests

## Documentation impact

- `Primary:`
- `docs/plans/tasks/webllm-local-mode-04-webllm-generation-provider.md`
- `Likely:`
- `docs/ai-architecture.md`
- `docs/ai-test-cases.md`

## Риски / заметки

- output local model может чаще приходить с prose/markdown noise, чем backend-managed path; это нужно учитывать в normalization contract
- если local provider начнёт требовать другой prompt format, abstraction окажется фиктивным
- local inference timeouts и cancellations должны иметь user-meaningful mapping, иначе retry UX будет путаным

## Completion update

- `Status` обновлен на `done`
- Local provider реализован в `ui/src/features/ai/api/localAiProvider.ts` поверх existing frontend provider abstraction и `LocalAiRuntimeController`.
- `useBlockAiAction` переведен на provider injection point без изменения existing notebook insertion path.
- Добавлены stable frontend-local error mappings:
  - `AI_LOCAL_UNSUPPORTED`
  - `AI_LOCAL_BOOTSTRAP_FAILED`
  - `AI_LOCAL_TIMEOUT`
  - `AI_LOCAL_CANCELLED`
  - `AI_LOCAL_RESPONSE_INVALID`
- Зафиксирована lightweight local normalization semantics:
  - extraction from fenced markdown
  - trimming obvious prose noise
  - deterministic frontend-side JavaScript syntax validation before returning success
- Архитектурная фиксация обновлена в `docs/ai-architecture.md`.
