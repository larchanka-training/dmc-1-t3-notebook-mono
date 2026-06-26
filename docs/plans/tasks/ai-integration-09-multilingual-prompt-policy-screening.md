# T3/BTF -> BACK: Реализовать multilingual prompt-policy screening для AI code generation

## Status

- `planned`

## Цель

Убрать неявную англоязычную привязку в backend prompt-policy screening для `POST /api/v1/ai/code-blocks/generate`, чтобы endpoint принимал валидные code-generation и code-revision запросы на поддерживаемых языках, начиная с русского, но при этом сохранял текущую contract-driven границу: только генерация/ревизия кода, никакого general chat и никакого ослабления unsafe screening.

## Контекст

- `docs/plans/05-ai-integration-plan.md`
- `api/docs/ai_contract.md`
- `docs/ai-architecture.md`
- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `api/docs/api_architecture.md`
- existing AI backend implementation:
  - `api/app/features/ai/service.py`
  - `api/app/features/ai/router.py`
  - `api/app/features/ai/schemas.py`
- existing AI tests and acceptance context:
  - `api/tests/unit/ai/`
  - `api/tests/integration/ai/test_endpoint.py`
  - `docs/ai-test-cases.md`
  - `docs/plans/tasks/ai-integration-06-qa-acceptance-suite.md`
- earlier AI backend slices:
  - `docs/plans/tasks/ai-integration-02-authenticated-endpoint-and-provider-boundary.md`
  - `docs/plans/tasks/ai-integration-03-validation-and-repair-pipeline.md`

## Scope

- выделить текущую backend prompt-policy screening logic в более явно тестируемую форму, если это нужно для надёжного расширения
- расширить deterministic screening так, чтобы он распознавал code-intent запросы не только на английском, но и на поддерживаемом русском языке
- как минимум покрыть русскоязычные phrasing patterns для запросов вида:
  - создать / сделать / написать функцию
  - реализовать helper / script / component
  - отрефакторить / обновить / переделать текущий код
- как минимум покрыть русскоязычные non-code patterns для reject path:
  - объяснить концепцию
  - кратко суммировать или описать текст
  - ответить как чат без генерации кода
- расширить unsafe screening русскими эквивалентами policy-evasion и prompt-injection phrasing, достаточными для first multilingual slice
- сохранить `AI_PROMPT_REJECTED` для non-code intent и `AI_PROMPT_UNSAFE` для unsafe intent без изменения response semantics
- добавить unit/integration tests на bilingual prompt-policy behavior, чтобы ложные reject/pass cases были зафиксированы в CI
- при необходимости уточнить docs, если текущая wording в contract или architecture создаёт впечатление, что допустимы только английские user prompts

## Out of scope

- автоперевод prompt на frontend или backend
- новый request field вроде `promptLanguage`
- изменение `context.language`, которая по-прежнему описывает язык целевого кода, а не natural language prompt
- поддержка multi-language code output beyond `JavaScript`
- превращение endpoint в общий multilingual chat assistant
- LLM-based guard classification как обязательный primary path
- broad NLP/ML intent-classification system
- изменение notebook UI, toolbar UX или insertion flow

## Технические ограничения

- public API contract из `api/docs/ai_contract.md` должен остаться обратно совместимым
- backend остаётся final enforcement point для prompt policy
- deterministic screening должен оставаться primary decision path; fallback classifier допустим только как отдельный future slice, не как скрытая часть этой задачи
- implementation не должна ослабить existing unsafe screening ради повышения recall для code prompts
- endpoint по-прежнему поддерживает только `JavaScript` generation/revision
- новые зависимости не добавлять без явного одобрения; предпочтительны встроенные string/regex/stem-like rules в рамках текущего stack
- нельзя silently broaden endpoint so that generic educational, summarization, or conversational prompts start passing only because they are written in Russian

## Acceptance criteria

- [ ] Prompt-policy screening принимает корректные Russian code-intent prompts, эквивалентные уже допустимым English code-generation/code-revision requests
- [ ] Prompt-policy screening продолжает принимать существующие English code-intent prompts без регрессии
- [ ] Prompt-policy screening отклоняет Russian non-code prompts с `AI_PROMPT_REJECTED`, если запрос не просит generation/revision code
- [ ] Prompt-policy screening отклоняет English non-code prompts с тем же поведением, без регрессии
- [ ] Prompt-policy screening отклоняет Russian unsafe/policy-evasion prompts с `AI_PROMPT_UNSAFE`
- [ ] Prompt-policy screening отклоняет English unsafe/policy-evasion prompts с тем же поведением, без регрессии
- [ ] Реализация не требует нового client-sent metadata field для natural-language detection
- [ ] `context.language: "javascript"` остаётся единственным допустимым target-language contract rule и не переосмысляется как язык prompt
- [ ] Integration behavior AI endpoint остаётся неизменным вне policy decision: provider не вызывается для rejected/unsafe prompts и вызывается для accepted prompts
- [ ] Automated backend coverage существует как минимум для:
- [ ] Russian code-intent accepted
- [ ] English code-intent accepted
- [ ] Russian non-code rejected
- [ ] English non-code rejected
- [ ] Russian unsafe rejected
- [ ] English unsafe rejected

## Verification

- [ ] `cd api && .venv/bin/python -m pytest tests/unit/ai -q`
- [ ] `cd api && .venv/bin/python -m pytest -m integration tests/integration/ai/test_endpoint.py -q`
- [ ] вручную сверить `api/docs/ai_contract.md`, что public request/response shape не менялся
- [ ] вручную подтвердить по tests или explicit mock assertions, что rejected/unsafe bilingual prompts не доходят до provider boundary

## Dependencies

- `T3/BTF -> BACK: Реализовать authenticated AI endpoint и provider boundary`
- `T3/BTF -> BACK: Реализовать deterministic validation и repair pipeline для AI code generation`
- `T3/BTF -> QA: Зафиксировать acceptance suite для первого AI vertical slice`

## Files likely to change

- `api/app/features/ai/service.py`
- optional extracted helper under `api/app/features/ai/`
- `api/tests/unit/ai/`
- `api/tests/integration/ai/test_endpoint.py`
- `docs/ai-test-cases.md`
- `api/docs/ai_contract.md` and/or `docs/ai-architecture.md` if policy wording requires clarification

## Documentation impact

- `Primary:`
- `docs/plans/tasks/ai-integration-09-multilingual-prompt-policy-screening.md`
- `Likely:`
- `docs/plans/05-ai-integration-plan.md`
- `docs/ai-test-cases.md`
- `Conditional if wording must become explicit:`
- `api/docs/ai_contract.md`
- `docs/ai-architecture.md`

## Риски / заметки

- главный риск этой задачи: поднять recall для Russian code prompts ценой ложных accept для explanatory/chat prompts; acceptance и reject examples должны быть достаточно узкими
- если logic останется привязанной к exact-word matching без минимальной нормализации, поддержка быстро станет хрупкой даже внутри одного языка
- если попытаться решить всё через provider-side translation or hidden classification prompt, policy boundary станет менее предсказуемой и труднее тестируемой
- multilingual support здесь означает support для user intent screening, а не расширение product scope до multi-language code generation

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если implementation потребовала уточнить multilingual wording в contract или architecture docs, зафиксировать это в соответствующих документах
- если acceptance examples были скорректированы после реальных false-positive/false-negative findings, кратко записать это здесь
