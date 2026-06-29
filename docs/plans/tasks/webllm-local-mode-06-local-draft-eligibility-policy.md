# T3/BTF -> FRONT: Реализовать policy для unsynced local notebooks в WebLLM mode

## Status

- `done`

## Цель

Явно определить и реализовать поведение `WebLLM` для unsynced local notebooks, чтобы backend sync prerequisite и local-only generation mode не создавали противоречивый UX и не заставляли пользователя гадать, почему один и тот же AI control иногда недоступен.

## Контекст

- `docs/plans/06-webllm-local-mode-plan.md`
- `docs/ai-architecture.md`
- existing synced-notebook backend prerequisite:
  - `ui/src/features/ai/model/useBlockAiAction.ts`
  - `ui/src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx`
- scope decision:
  - `docs/plans/tasks/webllm-local-mode-01-scope-and-direction-freeze.md`
- local-mode UI integration:
  - `docs/plans/tasks/webllm-local-mode-05-local-mode-and-retry-ui.md`

## Scope

- реализовать выбранную policy для `local-*` notebook ids:
  - либо local mode разрешён на unsynced drafts
  - либо local mode также требует synced notebook
- привести AI availability checks в соответствие с принятой policy
- разделить user-facing messaging для:
  - backend path unavailable because notebook is unsynced
  - local mode unavailable because policy/runtime/feature flag disallows it
- обновить tests под выбранное поведение
- при необходимости уточнить source-of-truth docs, если меняется user-visible AI availability

## Out of scope

- изменение backend sync requirements
- изменение backend AI endpoint
- redesign local-first notebook persistence
- broad AI UX changes beyond this eligibility rule

## Технические ограничения

- backend path по-прежнему не должен принимать pure local notebook id вместо server-backed id
- local mode policy должна быть одной и предсказуемой, без скрытых эвристик
- нельзя silently bypass current synced-notebook validation for backend provider path

## Acceptance criteria

- [ ] Для unsynced local notebook поведение `WebLLM` local mode определено и реализовано строго по выбранной policy
- [ ] Existing backend path по-прежнему требует server-backed notebook identity
- [ ] User-facing messages различают backend sync prerequisite и local-mode unavailability
- [ ] Tests покрывают synced notebook, unsynced notebook и mismatch scenarios under chosen policy

## Verification

- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] вручную пройти сценарий synced notebook
- [ ] вручную пройти сценарий unsynced notebook
- [ ] вручную сверить, что backend path не начал использовать local route id

## Dependencies

- `T3/BTF -> RESEARCH: Зафиксировать scope и direction для WebLLM local mode`
- `T3/BTF -> FRONT: Добавить explicit local-mode и retry-fallback UI для WebLLM`

## Files likely to change

- `ui/src/features/ai/model/useBlockAiAction.ts`
- `ui/src/features/ai/model/types.ts`
- `ui/src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx`
- optional AI docs

## Documentation impact

- `Primary:`
- `docs/plans/tasks/webllm-local-mode-06-local-draft-eligibility-policy.md`
- `Likely:`
- `docs/ai-architecture.md`
- `docs/project.md` if user-visible product behavior changes

## Риски / заметки

- если policy не зафиксирована явно, команда начнёт лечить случаи ad hoc условиями в UI code
- разрешение `WebLLM` на unsynced drafts повышает product convenience, но ослабляет parity с backend safety and audit semantics
- запрет local mode на unsynced drafts упрощает consistency, но может сделать feature менее полезной именно в offline/local-first сценариях

## Completion update

- `Status` обновлен на `done`
- `WebLLM` local mode подтвержден и реализован для `unsynced local drafts`; canonical backend path по-прежнему требует server-backed notebook id.
- `useBlockAiAction` теперь различает:
  - backend validation error for unsynced notebooks
  - local-mode availability messaging for disabled runtime / explicit local-draft path
- Notebook editor tests покрывают:
  - backend block on unsynced local notebook
  - disabled local mode messaging in that mismatch state
  - successful explicit local generation for an unsynced local draft
