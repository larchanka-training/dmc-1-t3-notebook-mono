# T3/BTF -> FRONT: Добавить explicit local-mode и retry-fallback UI для WebLLM

## Status

- `done`

## Цель

Встроить `WebLLM` в существующий notebook AI UX как явный локальный режим и как опциональный retry path после retryable backend failures, не ломая canonical backend-first generation flow и не скрывая от пользователя, какой provider дал результат.

## Контекст

- `docs/plans/06-webllm-local-mode-plan.md`
- `docs/ai-architecture.md`
- `ui/docs/ui_architecture.md`
- current block AI UX:
  - `ui/src/features/ai/model/useBlockAiAction.ts`
  - `ui/src/pages/notebook-editor/`
  - `ui/src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx`
- provider abstraction / local provider tasks:
  - `docs/plans/tasks/webllm-local-mode-02-frontend-provider-abstraction.md`
  - `docs/plans/tasks/webllm-local-mode-04-webllm-generation-provider.md`

## Scope

- добавить explicit user action для local generation, когда feature flag и runtime readiness позволяют
- добавить retry option после retryable backend errors:
  - `AI_PROVIDER_UNAVAILABLE`
  - `AI_PROVIDER_TIMEOUT`
  - и эквивалентных provider-class failures current UI flow
- явно показывать provider source в status / result messaging
- встроить local-mode path в текущие AI statuses и error summaries
- сохранить existing backend-first happy path без ухудшения UX
- сохранить тот же code insertion behavior после successful local generation

## Out of scope

- policy decision about unsynced local notebooks
- implementation of feature flag plumbing itself, если она требует отдельной конфигурационной задачи
- redesign notebook toolbar beyond minimal controls needed for local mode
- broad AI chat UX or multi-provider chooser

## Технические ограничения

- local mode должен быть explicit и не должен silently hijack normal generation button
- retry fallback можно предлагать только после retryable backend errors
- provider label должен быть user-visible
- нельзя вводить divergent insertion flow или отдельный notebook mutation format

## Acceptance criteria

- [ ] При enabled feature flag и ready runtime пользователь может явно запустить local generation
- [ ] После retryable backend failure UI может предложить `Retry locally with WebLLM`
- [ ] Успешный local result явно маркируется как `webllm`
- [ ] Existing backend-first happy path остаётся прежним для пользователя
- [ ] Local success использует тот же notebook insertion behavior, что и backend success

## Verification

- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] вручную пройти сценарий explicit local generation
- [ ] вручную пройти сценарий backend retryable failure -> local retry
- [ ] вручную сверить, что обычный backend generate path не стал local-by-default

## Dependencies

- `T3/BTF -> FRONT: Реализовать WebLLM generation provider`

## Files likely to change

- `ui/src/features/ai/model/useBlockAiAction.ts`
- `ui/src/features/ai/ui/`
- `ui/src/pages/notebook-editor/`
- notebook-editor tests

## Documentation impact

- `Primary:`
- `docs/plans/tasks/webllm-local-mode-05-local-mode-and-retry-ui.md`
- `Likely:`
- `docs/ai-architecture.md`

## Риски / заметки

- главный риск: сделать retry UX настолько заметным, что пользователи начнут воспринимать `WebLLM` как preferred path
- provider labeling нельзя прятать в debug-only UI, иначе теряется прозрачность
- local mode и retry fallback должны быть добавкой к текущему UX, а не его переписыванием

## Completion update

- `Status` обновлен на `done`
- В `BlockAiAction` добавлен явный local-mode UX:
  - `Prepare WebLLM`
  - `Generate locally`
  - `Retry locally with WebLLM` после retryable backend/provider errors
- `useBlockAiAction` теперь явно маркирует provider source в status/error/result messaging и сохраняет canonical backend-first primary action без silent switching.
- Local and backend success paths продолжают использовать один и тот же notebook insertion behavior через existing `onInsertCode` flow.
