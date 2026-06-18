# T3/BTF -> BACK: Реализовать Bedrock gateway и runtime wiring для AI generation

## Status

- `planned`

## Цель

Заменить текущий `UnavailableAiGenerationGateway` на реальный backend-side Bedrock-backed provider path, чтобы `POST /api/v1/ai/code-blocks/generate` мог выполнять реальный вызов модели через `AWS Bedrock` и возвращать уже существующий normalized AI result flow без изменения внешнего contract.

## Контекст

- `docs/plans/05-ai-integration-plan.md`
- `docs/ai-architecture.md`
- `api/docs/ai_contract.md`
- `api/docs/api_architecture.md`
- `docs/requirements.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- existing AI backend slices:
  - `docs/plans/tasks/ai-integration-02-authenticated-endpoint-and-provider-boundary.md`
  - `docs/plans/tasks/ai-integration-03-validation-and-repair-pipeline.md`
  - `docs/plans/tasks/ai-integration-06-qa-acceptance-suite.md`
- current provider boundary and wiring:
  - `api/app/integrations/ai/provider.py`
  - `api/app/features/ai/dependencies.py`
  - `api/app/features/ai/service.py`
  - `api/app/core/config.py`

## Scope

- реализовать реальный `AiGenerationGateway` для `AWS Bedrock`
- подключить gateway через `get_ai_generation_gateway()` вместо текущего `UnavailableAiGenerationGateway`, когда runtime config включена и валидна
- добавить backend settings для Bedrock runtime:
  - provider enablement toggle
  - region
  - model id
  - request timeout
  - при необходимости optional retry/transport tuning, если это не ломает текущий contract
- реализовать provider request mapping из текущего `AiProviderGenerateRequest` в Bedrock invocation payload
- реализовать provider response mapping в `AiProviderGenerateResponse`
- реализовать controlled mapping Bedrock transport/runtime failures в существующие backend provider errors:
  - timeout -> `AiProviderTimeoutError`
  - unavailable/network/authz/runtime failures -> `AiProviderUnavailableError`
  - malformed/unusable provider payload -> `AiProviderInvalidResponseError`
- обеспечить совместимость с уже реализованными extraction / syntax validation / repair retry semantics в `AiService`
- сохранить unit/integration testability через dependency override или mockable gateway path
- добавить backend tests для runtime-wired Bedrock gateway behavior без реального внешнего network call в CI

## Out of scope

- настройка реальных AWS credentials, IAM policy, network access и deployment secrets в окружении
- изменение frontend AI flow
- local `WebLLM` fallback
- multi-provider routing
- cost analytics, token metering или request usage dashboards
- расширение AI output beyond `JavaScript`
- изменение notebook sync flow
- production observability rollout, alerting и runbook automation beyond minimal backend wiring

## Технические ограничения

- внешний AI contract из `api/docs/ai_contract.md` должен остаться неизменным
- canonical provider path остаётся `frontend -> backend -> Bedrock`
- provider credentials не должны попадать в client-visible payloads, logs или exceptions
- backend должен по-прежнему возвращать normalized error semantics, а не raw Bedrock payloads
- direct browser-to-provider access добавлять нельзя
- новые зависимости добавлять только при реальной необходимости; если SDK уже доступен или может быть подключён аккуратно, не раздувать scope
- существующие acceptance scenarios по prompt screening, extraction, validation и repair retry не должны деградировать из-за provider wiring

## Acceptance criteria

- [ ] В backend существует Bedrock-backed реализация `AiGenerationGateway`, пригодная для реального вызова AI model
- [ ] `get_ai_generation_gateway()` умеет выбирать real Bedrock gateway вместо `UnavailableAiGenerationGateway`, когда runtime config корректна
- [ ] `POST /api/v1/ai/code-blocks/generate` при корректной Bedrock runtime config проходит provider invocation path без изменения внешнего request/response contract
- [ ] Bedrock timeout-class failures маппятся в текущий `AiProviderTimeoutError` path и приводят к contract-aligned `AI_PROVIDER_TIMEOUT`
- [ ] Bedrock unavailable/authz/network/runtime failures маппятся в текущий `AiProviderUnavailableError` path и приводят к contract-aligned `AI_PROVIDER_UNAVAILABLE`
- [ ] Malformed or unusable Bedrock response маппится в `AiProviderInvalidResponseError` path и приводит к contract-aligned `AI_RESPONSE_INVALID`
- [ ] Gateway path совместим с already implemented extraction, syntax validation и bounded repair retry, включая повторный provider call на repair attempt
- [ ] Backend tests покрывают как минимум:
- [ ] successful provider response mapping
- [ ] timeout mapping
- [ ] unavailable failure mapping
- [ ] malformed response mapping
- [ ] repair attempt invocation through provider path

## Verification

- [ ] `cd api && .venv/bin/python -m pytest tests/unit -q`
- [ ] `cd api && .venv/bin/python -m pytest -m integration tests/integration/ai/test_endpoint.py tests/integration/ai/test_validation_pipeline.py -q`
- [ ] добавить/запустить tests для Bedrock gateway mapping без реального network call
- [ ] вручную проверить, что при runtime-disabled или incomplete config backend сохраняет controlled unavailable behavior, а не падает неуправляемо
- [ ] вручную сверить, что response shape AI endpoint не изменился относительно `api/docs/ai_contract.md`

## Dependencies

- `T3/BTF -> BACK: Реализовать authenticated AI endpoint и provider boundary`
- `T3/BTF -> BACK: Реализовать deterministic validation и repair pipeline для AI code generation`
- `T3/BTF -> FRONT/BACK: notebook sync/server-backed notebook flow` должен быть достаточно готов, чтобы реальный generation path можно было smoke-проверять на synced notebook

## Files likely to change

- `api/app/integrations/ai/provider.py`
- `api/app/features/ai/dependencies.py`
- `api/app/core/config.py`
- `api/app/features/ai/service.py` only if minimal orchestration changes are required for runtime config integration
- `api/tests/unit/`
- `api/tests/integration/ai/`

## Documentation impact

- `Primary:`
- `docs/plans/tasks/ai-integration-07-bedrock-gateway-and-runtime-wiring.md`
- `Likely:`
- `api/docs/ai_contract.md` only if hidden contract assumptions are uncovered
- `docs/ai-architecture.md` if runtime behavior wording needs clarification
- backend runtime/deployment docs if config variables are introduced

## Риски / заметки

- если Bedrock-specific mapping проникнет в `AiService`, boundary между provider integration и business logic станет хрупкой
- если timeout/unavailable semantics не останутся normalized, frontend error handling и acceptance suite потеряют стабильность
- если repair retry path не будет реально прогоняться через provider gateway, можно получить ложную “поддержку repair” только на stub path
- синхронизация notebook всё ещё отдельный prerequisite: без server-backed notebook реальный user flow не будет доступен, даже если Bedrock gateway уже реализован

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если реализация потребовала уточнить provider-related config contract или error semantics, зафиксировать это в `api/docs/ai_contract.md`
- если verification достигнута через equivalent provider-mock suites и один manual smoke against real runtime, явно отметить это в notes
