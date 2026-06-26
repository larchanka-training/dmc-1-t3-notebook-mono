# T3/BTF -> FRONT: Ввести общий frontend provider abstraction для AI generation

## Status

- `done`

## Цель

Выделить единый frontend boundary для AI provider paths, чтобы текущий backend-backed flow и будущий `WebLLM` local flow работали через один нормализованный интерфейс и не дублировали notebook AI UX, insertion flow и error handling.

## Контекст

- `docs/plans/06-webllm-local-mode-plan.md`
- `docs/ai-architecture.md`
- `ui/docs/ui_architecture.md`
- `docs/system_architecture.md`
- `docs/requirements.md`
- existing frontend AI flow:
  - `ui/src/features/ai/api/aiApi.ts`
  - `ui/src/features/ai/model/useBlockAiAction.ts`
  - `ui/src/features/ai/model/contextBuilder.ts`
  - `ui/src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx`

## Scope

- определить единый frontend interface для AI generation provider
- выделить normalized result shape для:
  - success result
  - warnings
  - retryable / non-retryable errors
  - provider identity metadata
- адаптировать существующий backend provider path под новый abstraction layer
- оставить current backend contract usage внутри provider implementation, а не в UI hook
- подготовить extension point для будущего `webllm` provider без изменения notebook editor semantics
- сохранить совместимость с текущими transient AI states (`idle`, `submitting`, `success`, `error`)

## Out of scope

- реальная инициализация `WebLLM`
- browser capability checks
- feature flags
- redesign notebook-editor UI
- любые backend изменения

## Технические ограничения

- import direction должен оставаться совместимым с FSD boundaries из `ui/docs/ui_architecture.md`
- provider abstraction должен жить внутри `ui/src/features/ai/`, а не в `shared/api/` как generic transport framework
- нельзя ломать существующий вызов backend endpoint `POST /ai/code-blocks/generate`
- нельзя создавать второй state ownership path вне текущего AI feature

## Acceptance criteria

- [x] В frontend существует общий provider abstraction для AI generation
- [x] Existing backend generation path работает через новый abstraction без изменения user-visible behavior
- [x] Provider result shape содержит `provider` metadata, достаточную для UI labeling
- [x] `useBlockAiAction` или эквивалентный feature hook больше не зависит напрямую от backend-only response semantics
- [x] Existing tests backend path не требуют переписывания product behavior expectations

## Verification

- [x] `cd ui && pnpm test -- --runInBand`
- [x] вручную сверить, что backend endpoint contract usage остался прежним
- [x] вручную сверить, что provider-specific branching не вытекла в notebook page layer

## Dependencies

- `T3/BTF -> RESEARCH: Зафиксировать scope и direction для WebLLM local mode`

## Files likely to change

- `ui/src/features/ai/api/`
- `ui/src/features/ai/model/`
- `ui/src/features/ai/index.ts`
- `ui/src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx`

## Documentation impact

- `Primary:`
- `docs/plans/tasks/webllm-local-mode-02-frontend-provider-abstraction.md`
- `Likely:`
- `docs/ai-architecture.md`

## Риски / заметки

- если abstraction будет слишком transport-oriented, UI всё равно останется backend-specific
- если abstraction будет слишком абстрактным, он усложнит existing backend path без реальной пользы
- хороший критерий: current notebook AI UX не должен знать, откуда именно пришёл code result, кроме provider label и fallback messaging

## Completion update

- `Status` обновлен на `done`
- В `ui/src/features/ai/api/` добавлены общий provider boundary (`provider.ts`) и backend implementation (`backendAiProvider.ts`), а `useBlockAiAction` переведен на provider-level contract вместо прямой зависимости от backend transport semantics.
