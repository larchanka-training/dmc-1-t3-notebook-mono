# T3/BTF -> RESEARCH: Зафиксировать scope и direction для WebLLM local mode

## Status

- `done`

## Цель

Зафиксировать продуктовую и архитектурную рамку для `WebLLM`, чтобы команда реализовала один ограниченный local mode поверх уже существующего backend-first AI flow, а не создала второй основной AI pipeline с отличающимися правилами и UX.

## Контекст

- `docs/plans/06-webllm-local-mode-plan.md`
- `docs/plans/05-ai-integration-plan.md`
- `docs/ai-architecture.md`
- `docs/sprints/sprint-2/ai-implementation-status-for-product-owner.md`
- `docs/sprints/sprint-2/ai-decision-record.md`
- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `ui/docs/ui_architecture.md`

## Scope

- зафиксировать, что canonical AI path остаётся `frontend -> backend -> Bedrock`
- зафиксировать, что `WebLLM` вводится только как:
  - explicit local mode
  - и/или retry fallback после retryable backend failure
- явно исключить automatic provider routing:
  - по длине prompt
  - по размеру notebook context
  - по любым эвристикам на frontend
- зафиксировать продуктовую политику для local drafts:
  - local mode доступен только для synced notebooks
  - или local mode разрешён также для unsynced local working copies
- зафиксировать expected UX wording:
  - local mode не маскируется под backend generation
  - UI явно показывает provider source
- зафиксировать risk statement про ослабление единой backend prompt-policy boundary при local mode

## Out of scope

- реализация frontend provider abstraction
- подключение конкретной `WebLLM` библиотеки
- любые backend contract changes
- реализация feature flags
- QA automation beyond scope wording

## Технические ограничения

- нельзя противоречить `docs/ai-architecture.md` и `docs/plans/05-ai-integration-plan.md`
- нельзя переопределять Version 1 default provider path
- нельзя вводить новый durable `ai` block type
- нельзя расширять продукт до browser-only AI mode
- если scope для unsynced drafts меняет user-facing behavior, это должно быть явно отражено в docs

## Acceptance criteria

- [ ] В документации явно зафиксировано, что `WebLLM` не является default AI path
- [ ] Automatic provider routing явно помечен как out of scope
- [ ] Зафиксировано одно конкретное решение для unsynced local notebooks
- [ ] Зафиксировано, что local mode должен быть explicit и provider-labelled
- [ ] Зафиксировано, что local mode не меняет notebook insertion semantics и block model

## Verification

- [ ] вручную сверить `docs/plans/06-webllm-local-mode-plan.md` с `docs/ai-architecture.md`
- [ ] вручную сверить, что выбранная формулировка не конфликтует с `docs/plans/05-ai-integration-plan.md`
- [ ] вручную сверить, что `docs/sprints/sprint-2/ai-decision-record.md` и/или `docs/ai-architecture.md` достаточно явно отражают принятое направление

## Dependencies

- None

## Files likely to change

- `docs/plans/06-webllm-local-mode-plan.md`
- `docs/ai-architecture.md`
- `docs/sprints/sprint-2/ai-decision-record.md`
- optional product docs if local-draft policy changes visible behavior

## Documentation impact

- `Primary:`
- `docs/plans/tasks/webllm-local-mode-01-scope-and-direction-freeze.md`
- `Likely:`
- `docs/ai-architecture.md`
- `docs/sprints/sprint-2/ai-decision-record.md`

## Риски / заметки

- главный риск: silently превратить `WebLLM` из bounded fallback в второй основной AI mode
- если не зафиксировать policy для unsynced notebooks заранее, frontend implementation быстро расползётся в условные ветки и спорные UX messages
- если wording останется расплывчатой, QA начнёт тестировать неподтверждённые сценарии как product requirement

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если принято решение по unsynced drafts, кратко зафиксировать его здесь и в `docs/ai-architecture.md`

### Implementation notes

- В `docs/plans/06-webllm-local-mode-plan.md` зафиксировано, что `WebLLM` остаётся explicit local mode / retry fallback и не становится default provider path.
- В `docs/plans/06-webllm-local-mode-plan.md` и `docs/ai-architecture.md` явно исключён automatic provider routing по длине prompt, размеру context или frontend heuristics.
- Принято и задокументировано конкретное решение для unsynced notebooks:
  - explicit local `WebLLM` mode разрешён для unsynced local working copies
  - canonical backend path по-прежнему требует synced server-backed notebook id
- В `docs/ai-architecture.md` и `docs/sprints/sprint-2/ai-decision-record.md` закреплено, что local mode должен быть explicit и provider-labelled и не меняет notebook block model или insertion semantics.

### Verification notes

- Выполнено: manual cross-check `docs/plans/06-webllm-local-mode-plan.md` vs `docs/ai-architecture.md`
- Выполнено: manual cross-check против `docs/plans/05-ai-integration-plan.md`; конфликтов с backend-first direction нет
- Выполнено: `docs/sprints/sprint-2/ai-decision-record.md` обновлён так, чтобы implementation freeze по `WebLLM` был отражён явно
