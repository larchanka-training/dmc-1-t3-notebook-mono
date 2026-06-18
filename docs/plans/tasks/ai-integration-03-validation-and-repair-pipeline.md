# T3/BTF -> BACK: Реализовать deterministic validation и repair pipeline для AI code generation

## Status

- `done`

## Цель

Реализовать backend post-provider pipeline, который превращает provider response в safe insertable AI result для notebook: детерминированно извлекает code, проверяет синтаксис `JavaScript`, выполняет bounded repair retry при extraction/syntax failures и возвращает outcome строго по contract из `api/docs/ai_contract.md`.

## Контекст

- `docs/plans/05-ai-integration-plan.md`
- `api/docs/ai_contract.md`
- `docs/plans/tasks/ai-integration-02-authenticated-endpoint-and-provider-boundary.md`
- `docs/ai-architecture.md`
- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `api/docs/api_architecture.md`
- `docs/ai-test-cases.md`
- backend AI feature area: `api/app/features/ai/`
- provider integration boundary from previous slice: `api/app/integrations/`

## Scope

- реализовать deterministic code extraction из provider responses для Version 1 AI flow
- поддержать основные provider output forms:
  - fenced `javascript` code block
  - fenced generic code block
  - plain-text response containing extractable code
  - mixed prose + code response, где code может быть выделен детерминированно
- определить и реализовать extraction-failure semantics для:
  - empty string
  - whitespace-only response
  - fenced empty block
  - prose-only response without extractable code
- реализовать deterministic `JavaScript` syntax validation для extracted code без backend execution generated code
- реализовать bounded repair retry:
  - использовать validation/extraction error как structured feedback
  - ограничить число repair attempts
  - повторно прогонять extraction и syntax validation после repair response
- вернуть success/error outcome строго по contract, включая agreed `validation` metadata и agreed final error semantics
- добавить unit/integration coverage для successful extraction, repair-success path, repair-exhausted path, empty responses и malformed provider responses
- явно зафиксировать outcome для comment-only / placeholder-only code case и реализовать поведение в соответствии с решением

## Out of scope

- router wiring и authenticated endpoint plumbing
- notebook access checks и request pre-validation
- frontend insertion behavior и transient AI UI state
- local `WebLLM` fallback implementation
- semantic validation generated code beyond deterministic extraction/syntax checks
- execution-time validation of generated code in notebook runtime
- advanced code formatting or auto-linting of AI output
- multi-language syntax validation

## Технические ограничения

- generated code остаётся untrusted; backend не исполняет notebook code
- deterministic validation должна иметь приоритет над дополнительными LLM calls, кроме bounded repair retry
- Version 1 поддерживает только `JavaScript`
- bounded repair retry должен оставаться ограниченным и предсказуемым; нельзя вводить open-ended retry loop
- public response не должен утекать raw provider internals, prompts, credentials или opaque upstream payloads сверх согласованного contract
- pipeline должен использовать provider boundary из предыдущего slice, а не встраивать provider-specific logic напрямую в router
- новые зависимости не добавлять без явного одобрения; если для syntax validation нужен parser/runtime helper, решение должно соответствовать текущему stack и repository constraints

## Acceptance criteria

- [ ] Backend детерминированно извлекает code string из valid provider responses с fenced code block или однозначно extractable plain code
- [ ] Empty, whitespace-only, prose-only и fenced-empty provider responses детерминированно приводят к extraction failure path, а не к silent success
- [ ] Extracted code проходит deterministic `JavaScript` syntax validation без backend execution generated code
- [ ] Invalid syntax запускает bounded repair retry с structured feedback вместо немедленного final success/failure
- [ ] Если repair retry возвращает valid code, backend отдаёт `status: "success"` с корректным `validation` object, отражающим repair/extraction path
- [ ] Если repair retry исчерпан и code всё ещё не extractable, backend возвращает final error строго по contract из `api/docs/ai_contract.md`
- [ ] Если repair retry исчерпан и code всё ещё syntactically invalid, backend возвращает final error строго по contract
- [ ] Malformed provider response, incompatible upstream payload или parse failure маппятся в final error строго по contract без raw upstream leakage
- [ ] Total repair strategy ограничена фиксированным числом attempts и не допускает unbounded retry behavior
- [ ] Comment-only or placeholder-only code case имеет явно зафиксированное поведение: либо `success` с warning, либо deterministic failure; итоговое поведение отражено в tests и не оставлено неявным
- [ ] Unit и integration tests покрывают как минимум:
- [ ] valid extraction success
- [ ] extraction failure with retry exhausted
- [ ] syntax invalid then repair success
- [ ] syntax invalid then repair exhausted
- [ ] empty response
- [ ] malformed provider response

## Verification

- [ ] `cd api && .venv/bin/python -m pytest tests/unit -q`
- [ ] `cd api && .venv/bin/python -m pytest -m integration tests/integration/ai/test_validation_pipeline.py -q`
- [ ] вручную проверить, что generated code не исполняется на backend ни в одном validation path
- [ ] вручную сверить final error mapping с `docs/ai-test-cases.md` для empty, timeout, malformed and repair-related scenarios

## Dependencies

- `T3/BTF -> BACK: Зафиксировать AI backend contract и error model`
- `T3/BTF -> BACK: Реализовать authenticated AI endpoint и provider boundary`

## Files likely to change

- `api/app/features/ai/service.py`
- `api/app/features/ai/`
- `api/app/integrations/`
- `api/tests/unit/`
- `api/tests/integration/ai/`
- `docs/ai-test-cases.md` (if clarification is needed for placeholder-only code outcome)

## Documentation impact

- `Primary:`
- `docs/plans/tasks/ai-integration-03-validation-and-repair-pipeline.md`
- `Likely if behavior is clarified:`
- `docs/ai-test-cases.md`
- `docs/ai-architecture.md`
- `docs/plans/05-ai-integration-plan.md`
- `Conditional if contract metadata changes:`
- `api/docs/ai_contract.md`

## Риски / заметки

- самое слабое место этого slice: ambiguous extraction heuristics; если extraction rules не будут достаточно узкими, backend начнёт принимать prose as code или станет непредсказуемым для QA
- если syntax validation зависит от внешнего JS toolchain, нужно заранее проверить, что решение совместимо с backend deployment constraints и local test setup
- placeholder-only code case уже подсвечен в `docs/ai-test-cases.md` как неоднозначный; его нужно зафиксировать здесь, иначе acceptance не будет стабильным
- timeout handling как transport/provider concern частично начинается в предыдущем slice, но repair-time timeout semantics должны быть согласованы и покрыты в pipeline tests

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если реализация потребовала уточнить contract-level error catalog, `validation` metadata или retry semantics, зафиксировать delta в `api/docs/ai_contract.md`
- если verification была достигнута иными эквивалентными test paths, кратко описать это в этой секции

### Implementation notes

- Реализованы deterministic extraction, JavaScript syntax validation через backend-side `node --check`, bounded repair retry (`max 1`) и normalized final errors `AI_CODE_EXTRACTION_FAILED` / `AI_CODE_SYNTAX_INVALID`.
- Comment-only / placeholder-only valid code зафиксирован как `success` c warning `AI_COMMENT_ONLY_CODE`.
- Добавлено покрытие для extraction success, repair success, repair exhausted, empty/prose-only responses и malformed provider response.

### Verification notes

- Выполнено: `cd api && .venv/bin/python -m pytest tests/unit -q`
- Выполнено: `cd api && .venv/bin/python -m pytest -m integration tests/integration/ai/test_validation_pipeline.py -q`
- Дополнительно выполнено: `cd api && .venv/bin/python -m pytest -m integration tests/integration/ai/test_endpoint.py tests/integration/ai/test_validation_pipeline.py -q`
