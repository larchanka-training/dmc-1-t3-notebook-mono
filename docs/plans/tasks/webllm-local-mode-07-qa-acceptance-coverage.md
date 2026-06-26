# T3/BTF -> QA: Добавить acceptance coverage для WebLLM local mode

## Status

- `done`

## Цель

Расширить AI acceptance suite так, чтобы она покрывала ровно утверждённое поведение `WebLLM` local mode и retry fallback, не превращая local provider в обязательную часть baseline Stage 7 backend-first slice и не раздувая QA surface до второй полной AI матрицы.

## Контекст

- `docs/plans/06-webllm-local-mode-plan.md`
- `docs/ai-architecture.md`
- `docs/ai-test-cases.md`
- `docs/qa_plan.md`
- existing AI frontend tests:
  - `ui/src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx`
  - `ui/src/features/ai/`
- local mode implementation tasks:
  - `docs/plans/tasks/webllm-local-mode-05-local-mode-and-retry-ui.md`
  - `docs/plans/tasks/webllm-local-mode-06-local-draft-eligibility-policy.md`

## Scope

- добавить acceptance cases для approved `WebLLM` behavior:
  - supported local success
  - unsupported browser/runtime
  - model bootstrap failure
  - retryable backend failure with local retry path
  - provider labeling
- проверить, что notebook insertion behavior одинаков для backend result и local result
- отделить backend-contract expectations от frontend-local fallback expectations в QA docs
- зафиксировать, что `WebLLM` не является mandatory prerequisite для baseline AI slice

## Out of scope

- broad model benchmarking
- performance certification across many devices
- Playwright-wide AI automation matrix
- backend provider tests unrelated to local mode

## Технические ограничения

- acceptance suite не должна подразумевать, что `WebLLM` заменяет backend path
- coverage должна оставаться bounded и соответствовать утверждённому scope
- если часть сценариев пока manual-only, это должно быть явно указано, а не скрыто

## Acceptance criteria

- [ ] `docs/ai-test-cases.md` содержит отдельный bounded раздел для `WebLLM` local mode / fallback scenarios
- [ ] QA artifacts различают backend-contract cases и frontend-local cases
- [ ] Покрыты сценарии local success, unsupported runtime, bootstrap failure, backend retryable failure -> local retry, provider labeling
- [ ] Покрыто, что code insertion semantics не расходятся между backend и local providers
- [ ] Нигде в acceptance wording не зафиксировано, что `WebLLM` обязателен для базового backend-first AI slice

## Verification

- [ ] обновить `docs/ai-test-cases.md`
- [ ] при необходимости обновить `docs/qa_plan.md`
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] вручную сверить, что QA wording не конфликтует с `docs/ai-architecture.md`

## Dependencies

- `T3/BTF -> FRONT: Реализовать policy для unsynced local notebooks в WebLLM mode`

## Files likely to change

- `docs/ai-test-cases.md`
- `docs/qa_plan.md`
- `ui/src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx`
- other AI frontend tests if coverage is added there

## Documentation impact

- `Primary:`
- `docs/plans/tasks/webllm-local-mode-07-qa-acceptance-coverage.md`
- `Likely:`
- `docs/ai-test-cases.md`
- `docs/qa_plan.md`

## Риски / заметки

- главный риск: начать тестировать неподтверждённые `WebLLM` product ideas как уже принятые требования
- если не отделить local-mode cases от backend-contract cases, QA перестанет различать дефект provider runtime и дефект canonical API path
- acceptance должна оставаться про product behavior, а не про внутренние детали конкретной модели

## Completion update

- `Status` обновлен на `done`
- В `docs/ai-test-cases.md` добавлен отдельный bounded `WebLLM Local-Mode Acceptance Subset`, который:
  - отделяет frontend-local expectations от backend endpoint contract
  - покрывает local success, unsupported runtime, bootstrap failure, retryable backend failure -> local retry, unsynced local draft policy и provider labeling
  - явно фиксирует неизменность notebook insertion semantics между backend и local providers
- `docs/qa_plan.md` уточнен так, чтобы `WebLLM` оставался optional local slice и не становился mandatory prerequisite для baseline backend-first AI gate
- Frontend integration coverage дополнена page-level деградационными сценариями для unsupported runtime и bootstrap failure
