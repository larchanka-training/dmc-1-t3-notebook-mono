# T3/BTF -> BACK: Реализовать authenticated AI endpoint и provider boundary

## Status

- `done`

## Цель

Реализовать первый исполнимый backend slice для Stage 7 AI workflow: authenticated endpoint `POST /api/v1/ai/code-blocks/generate`, который принимает request по зафиксированному contract, применяет pre-provider validation и policy checks, вызывает provider через изолированную integration boundary и возвращает response без отклонений от `api/docs/ai_contract.md`.

## Контекст

- `docs/plans/05-ai-integration-plan.md`
- `api/docs/ai_contract.md`
- `docs/ai-architecture.md`
- `docs/requirements.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `api/docs/api_architecture.md`
- `docs/ai-test-cases.md`
- текущая auth/session foundation:
  - `docs/plans/tasks/auth-backend-01-persistence-and-session-foundation.md`
  - `docs/plans/tasks/auth-backend-03-email-otp-verify-and-session-issuance.md`
- backend structure:
  - `api/app/features/ai/`
  - `api/app/integrations/`
  - `api/app/core/`
  - `api/app/db/`

## Scope

- реализовать router-level endpoint `POST /api/v1/ai/code-blocks/generate` в рамках `api/app/features/ai/`
- добавить request/response schemas строго по зафиксированному backend contract
- подключить endpoint к общей `/api/v1` router wiring без нарушения feature-driven structure
- использовать существующие auth/session dependencies, чтобы endpoint работал только для authenticated user
- реализовать service-level orchestration для:
  - request validation orchestration
  - notebook access check
  - source block type check
  - prompt policy screening
  - provider invocation through adapter boundary
  - normalized success/error shaping
- реализовать provider-facing abstraction в `api/app/integrations/` или эквивалентной shared integration boundary, пригодную для primary `AWS Bedrock` path
- реализовать mapping provider/integration failures в normalized backend errors строго по contract из `api/docs/ai_contract.md`
- добавить integration tests на authenticated happy path, unauthenticated access, forbidden notebook access, invalid request rejection, prompt rejection/unsafe rejection и provider unavailable failure
- обновить backend OpenAPI artifacts автоматически через FastAPI schema, если это уже часть существующего workflow

## Out of scope

- deterministic code extraction implementation details beyond the minimal endpoint plumbing
- JavaScript syntax validation and bounded repair retry logic как отдельный полноценный pipeline slice
- frontend client wiring, block toolbar, transient UI state и insertion behavior
- `WebLLM` fallback implementation
- durable AI history, prompt storage или notebook `ai` block type
- advanced provider routing, multi-provider strategy или cost instrumentation
- performance optimization и request batching

## Технические ограничения

- backend architecture должна остаться `feature-driven with internal layers`
- API route должен оставаться под `/api/v1`
- authenticated access должен использовать существующий session-cookie based auth flow
- endpoint не должен исполнять notebook code на backend
- provider credentials и provider-specific low-level response details не должны попадать в public API response
- request handling должен придерживаться contract из `api/docs/ai_contract.md`
- Version 1 поддерживает только `JavaScript`
- direct browser-to-provider path не добавлять
- новые зависимости не добавлять без явного одобрения

## Acceptance criteria

- [ ] В `api/app/features/ai/` существует рабочий endpoint `POST /api/v1/ai/code-blocks/generate`, подключённый в общее API routing tree
- [ ] Endpoint требует authenticated session; запрос без valid session cookie получает `401` без provider invocation
- [ ] Endpoint использует зафиксированный request/response contract и не вводит ad hoc payload fields, ad hoc statuses или ad hoc errors вне `api/docs/ai_contract.md`
- [ ] Для notebook, недоступного текущему пользователю, endpoint возвращает error response строго по contract из `api/docs/ai_contract.md`
- [ ] Для invalid request cases endpoint возвращает validation failure строго по contract, не доходя до provider invocation
- [ ] Prompt policy rejection и unsafe prompt screening происходят до provider invocation и возвращаются строго по contract из `api/docs/ai_contract.md`
- [ ] Provider invocation изолирован за adapter/interface boundary, пригодной для `AWS Bedrock`, без Bedrock-specific logic в router handler
- [ ] Provider unavailable / malformed upstream / timeout-class failures маппятся в stable normalized backend errors по contract без raw upstream payload leakage
- [ ] Happy path возвращает success response строго по contract, без локальных расхождений в shape или field naming
- [ ] OpenAPI schema для endpoint отражает согласованный request/response shape
- [ ] Integration coverage существует как минимум для:
- [ ] authenticated success
- [ ] unauthenticated request
- [ ] forbidden notebook access
- [ ] invalid request
- [ ] prompt rejected
- [ ] prompt unsafe
- [ ] provider unavailable

## Verification

- [ ] `cd api && .venv/bin/python -m pytest tests/unit -q`
- [ ] `cd api && .venv/bin/python -m pytest -m integration tests/integration/ai/test_endpoint.py -q`
- [ ] вручную проверить OpenAPI schema для `POST /api/v1/ai/code-blocks/generate`
- [ ] вручную подтвердить, что запросы `AI_PROMPT_REJECTED` и `AI_PROMPT_UNSAFE` не вызывают provider adapter

## Dependencies

- `T3/BTF -> BACK: Зафиксировать AI backend contract и error model`
- `T3/BTF -> BACK: Подготовить auth persistence и session foundation`
- `T3/BTF -> BACK: Реализовать verify-otp и session issuance` 

## Files likely to change

- `api/app/features/ai/router.py`
- `api/app/features/ai/schemas.py`
- `api/app/features/ai/service.py`
- `api/app/features/ai/repository.py`
- `api/app/features/ai/__init__.py`
- `api/app/integrations/`
- `api/app/core/`
- `api/tests/unit/`
- `api/tests/integration/ai/`

## Documentation impact

- `Primary:`
- `docs/plans/tasks/ai-integration-02-authenticated-endpoint-and-provider-boundary.md`
- `Likely:`
- `api/docs/api_architecture.md`
- `docs/plans/05-ai-integration-plan.md`
- `Conditional if the implementation exposes contract gaps:`
- `api/docs/ai_contract.md`
- `docs/ai-architecture.md`

## Риски / заметки

- если source-block and notebook-access checks останутся размазаны между router и service без одного contract path, frontend и QA получат нестабильное поведение по error mapping
- provider boundary должна быть достаточно узкой для mocking в integration tests; иначе provider-unavailable и malformed-response coverage будет дорогой и хрупкой
- extraction, syntax validation и repair retry intentionally оставлены для следующего slice; не стоит частично протаскивать их сюда без task-level explicit scope update
- если в текущем backend state ещё нет notebook repository primitives для block lookup and ownership checks, понадобится опереться на существующий notebooks feature вместо дублирования data access

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если implementation потребовала уточнить contract, зафиксировать это в `api/docs/ai_contract.md`
- если часть planned verification была заменена эквивалентной, кратко описать почему
