# T3/BTF -> DEVOPS: Настроить Bedrock runtime config и operational smoke для AI generation

## Status

- `done`

## Цель

Подготовить рабочее runtime-окружение для canonical backend AI path через `AWS Bedrock`, чтобы backend с уже реализованным Bedrock gateway мог реально выполнять генерацию кода в staging/production-like среде и команда могла пройти end-to-end smoke на synced notebook.

## Контекст

- `docs/plans/05-ai-integration-plan.md`
- `docs/ai-architecture.md`
- `api/docs/ai_contract.md`
- `api/docs/api_architecture.md`
- `docs/qa_plan.md`
- `docs/ai-test-cases.md`
- parent operational intent:
  - `docs/plans/05-ai-integration-plan.md` -> `Task 8: DEVOPS`
- implementation dependency:
  - `docs/plans/tasks/ai-integration-07-bedrock-gateway-and-runtime-wiring.md`
- target runtime surfaces:
  - backend environment config
  - AWS credentials / IAM
  - model access
  - operational notes / smoke procedure

## Scope

- выбрать и зафиксировать рабочую Bedrock model configuration для first AI slice
- настроить runtime secrets/config для backend:
  - AWS region
  - credentials / assumed role / equivalent secure access path
  - model id
  - any required provider toggles
- обеспечить, что backend runtime environment реально может достучаться до Bedrock и имеет права на вызов выбранной модели
- зафиксировать безопасный operational способ хранения и передачи Bedrock secrets/config в local-dev-like secure environment, staging и production-like environment
- определить и задокументировать minimal observability expectations для AI runtime:
  - request correlation ids
  - отсутствие secret leakage
  - distinguishable timeout vs unavailable failure classes
- подготовить manual operational smoke procedure для реального AI path:
  - synced notebook exists on server
  - user triggers AI from source `text` block
  - backend reaches Bedrock
  - generated code returns and inserts into notebook
- задокументировать known failure modes и quick diagnosis path:
  - missing credentials
  - no Bedrock model access
  - region mismatch
  - outbound connectivity issue
  - request timeout

## Out of scope

- изменение frontend notebook UX
- изменение backend AI contract
- внедрение `WebLLM`
- полноценная alerting platform
- cost dashboards, token analytics, autoscaling policy
- широкая Playwright automation
- redesign auth or sync flow
- migration to a dedicated secret manager if the team has not yet selected one

## Технические ограничения

- provider access должен оставаться backend-side only
- Bedrock credentials, role assumptions и provider internals не должны попадать в browser, API payloads или публичные docs
- operational setup должен быть совместим с текущим deployment/runtime model проекта
- first AI slice не должен внезапно требовать local `WebLLM` как fallback prerequisite
- observability должна быть минимально полезной, но не должна тащить новую heavy infrastructure без отдельного одобрения

## Acceptance criteria

- [ ] Существует production-like runtime configuration, достаточная для реального Bedrock invocation из backend
- [ ] Backend environment имеет подтверждённый доступ к выбранной Bedrock model в целевом регионе
- [ ] Required env vars / secrets / runtime toggles задокументированы и достаточны для запуска canonical AI path другим инженером без устных пояснений
- [ ] AI request logging/correlation path не утечёт provider secrets, full prompt internals или raw credentials
- [ ] Команда может пройти manual operational smoke:
- [ ] login
- [ ] open synced notebook
- [ ] trigger AI generation from `text` block
- [ ] receive generated code from Bedrock-backed backend path
- [ ] confirm insertion into `code` block
- [ ] Known failure modes задокументированы так, чтобы различать config/access issue vs provider timeout vs notebook prerequisite issue

## Verification

- [ ] вручную проверить backend startup с полной Bedrock runtime config
- [ ] вручную подтвердить успешный provider call against real Bedrock environment
- [ ] вручную пройти end-to-end smoke на synced notebook
- [ ] вручную проверить negative smoke:
- [ ] missing or invalid credentials
- [ ] wrong / unavailable model access
- [ ] timeout-class behavior
- [ ] сверить, что operational notes покрывают setup, smoke и common failure diagnosis

## Dependencies

- `T3/BTF -> BACK: Реализовать Bedrock gateway и runtime wiring для AI generation`
- `T3/BTF -> FRONT/BACK: synced notebook/server-backed notebook flow`

## Files likely to change

- backend runtime env docs
- deployment/runtime notes
- infrastructure or compose/environment templates if they are used for team setup
- optional backend config docs referencing AI runtime variables
- `docs/qa_plan.md` only if manual smoke wording needs a concrete AI runtime update

## Documentation impact

- `Primary:`
- `docs/plans/tasks/ai-integration-08-bedrock-runtime-config-and-operational-smoke.md`
- `Likely:`
- backend runtime/deployment docs
- `docs/qa_plan.md`
- `docs/ai-architecture.md` only if operational constraints must be clarified

## Риски / заметки

- главный риск не в коде, а в доступах: backend может быть “готов”, но без Bedrock model access feature останется визуально реализованной, но фактически нерабочей
- без clear smoke procedure команда будет путать проблемы sync prerequisite и проблемы provider runtime
- если logs будут слишком подробными, есть риск утечки prompt contents или provider-sensitive runtime data
- если этот шаг не довести до конца, продукт продолжит показывать готовый UI flow без реально доступной генерации

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если в ходе работы выбрана другая Bedrock model, кратко зафиксировать причину
- если operational smoke потребовал уточнить acceptance subset или runtime constraints, отразить это в `docs/qa_plan.md` и/или `docs/ai-architecture.md`
- если verification была достигнута на staging-like environment, явно указать это в notes

### Implementation notes

- Исправлен packaging/runtime gap: `boto3` добавлен в `api/pyproject.toml`, чтобы editable install и dev/test venv действительно содержали Bedrock SDK, а backend не деградировал в `sdk-unavailable` только из-за неполной package metadata.
- Добавлен безопасный AI runtime readiness summary в `GET /api/v1/system/health`:
  - `provider`
  - `configured`
  - `ready`
  - `reason`
  - `missing_fields`
- Добавлены backend AI service logs с `request_id` correlation и явным различением timeout / unavailable / invalid-response классов без логирования prompt, notebook context или secret values.
- Добавлен operational runbook: `api/docs/ai_runtime_operations.md` с runtime config, secrets path, smoke, negative smoke и quick diagnosis.
- `api/.env.example` уточнён: AWS credentials не должны храниться в репозитории и должны приходить через default boto3 credential chain или runtime role.
- `docs/qa_plan.md` уточнён: manual AI smoke теперь явно начинается с `system/health` readiness probe перед browser flow.

### Verification notes

- Выполнить в локальном backend окружении:
  - `cd api && .venv/bin/python -m pytest tests/unit/ai/test_provider.py tests/integration/system/test_health.py -q`
- Real Bedrock invocation по-прежнему требует внешнего AWS access и не может быть подтверждён только изменениями внутри репозитория.
- Staging/production-like validation остаётся операционной задачей с реальными credentials, model access и outbound connectivity.
