# T3/BTF -> QA: Зафиксировать acceptance suite для первого AI vertical slice

## Status

- `done`

## Цель

Превратить AI direction и test inventory в исполнимый acceptance suite для первого Version 1 AI vertical slice, чтобы backend contract, frontend notebook flow и ключевые error paths проверялись одинаково людьми и автотестами. Эта задача не переопределяет продуктовое поведение, а фиксирует, что именно проверяется и на каком тестовом слое.

## Контекст

- `docs/plans/05-ai-integration-plan.md`
- `api/docs/ai_contract.md`
- `docs/plans/tasks/ai-integration-02-authenticated-endpoint-and-provider-boundary.md`
- `docs/plans/tasks/ai-integration-03-validation-and-repair-pipeline.md`
- `docs/plans/tasks/ai-integration-04-block-action-and-transient-ui-state.md`
- `docs/plans/tasks/ai-integration-05-context-builder-and-code-insertion-flow.md`
- `docs/ai-architecture.md`
- `docs/qa_plan.md`
- `docs/ai-test-cases.md`
- existing backend/frontend/e2e test strategy and locations

## Scope

- зафиксировать acceptance suite для первого AI vertical slice на основе уже существующего `docs/ai-test-cases.md`
- разделить acceptance coverage на три слоя:
  - backend contract/integration
  - frontend integration
  - E2E or manual critical path checks
- определить минимальный initial subset test cases, required before the slice can be considered ready
- привязать test cases к конкретным automated or manual verification paths
- уточнить expected ownership:
  - какие сценарии покрываются backend integration tests
  - какие сценарии покрываются frontend integration tests
  - какие сценарии остаются E2E/manual smoke
- зафиксировать acceptance coverage для contract, validation pipeline и frontend insertion behavior, уже определённых в `api/docs/ai_contract.md` ... `ai-integration-05-context-builder-and-code-insertion-flow.md`
- при необходимости уточнить `docs/ai-test-cases.md`, если в нем остаются ambiguous outcomes, мешающие стабильной acceptance verification

## Out of scope

- реализация production code
- exhaustively automated coverage of all 61 cases before first slice lands
- full performance benchmarking or cost analytics
- broad model-quality evaluation beyond Version 1 implemented scenarios
- provider-specific infrastructure monitoring

## Технические ограничения

- acceptance suite должен опираться на Version 1 canonical behavior, а не на stretch-scope features
- `docs/ai-test-cases.md` остаётся основным test inventory, но initial readiness subset должен быть меньше полного списка
- проверки должны быть совместимы с project testing pyramid из `docs/qa_plan.md`
- acceptance suite не должен неявно делать `WebLLM` fallback обязательной частью first delivery slice

## Acceptance criteria

- [ ] Зафиксирован initial acceptance subset для first delivery slice с явным списком обязательных scenarios
- [ ] Acceptance suite разделяет backend integration, frontend integration и E2E/manual layers без дублирования ответственности
- [ ] Для каждого обязательного scenario указано, где он проверяется и какой verification path считается достаточным
- [ ] В обязательный subset входят как минимум сценарии, покрывающие:
- [ ] happy path generation
- [ ] unauthenticated request
- [ ] forbidden notebook access
- [ ] prompt rejected
- [ ] prompt unsafe
- [ ] provider unavailable or timeout-class failure
- [ ] extraction failure and syntax invalid final failure
- [ ] repair retry success
- [ ] insertion into empty code block
- [ ] insertion by creating a new code block
- [ ] `scope: this`
- [ ] `scope: notebook`
- [ ] Если `docs/ai-test-cases.md` содержит ambiguous outcomes, они уточнены до уровня, достаточного для стабильной реализации tests
- [ ] QA artifact или обновлённые docs позволяют проверить slice readiness без дополнительных устных договорённостей и без повторного толкования продуктового поведения

## Verification

- [ ] ручная сверка acceptance subset с `docs/ai-test-cases.md`, `docs/qa_plan.md` и AI task specs
- [ ] подтвердить, что хотя бы один backend integration suite и один frontend or E2E path покрывают обязательный subset
- [ ] убедиться, что acceptance artifacts позволяют однозначно ответить, какие кейсы блокируют merge, а какие остаются post-MVP or stretch coverage

## Dependencies

- `T3/BTF -> BACK: Зафиксировать AI backend contract и error model`
- `T3/BTF -> BACK: Реализовать authenticated AI endpoint и provider boundary`
- `T3/BTF -> BACK: Реализовать deterministic validation и repair pipeline для AI code generation`
- `T3/BTF -> FRONT: Реализовать block-scoped AI action и transient UI state`
- `T3/BTF -> FRONT: Реализовать deterministic context builder и code insertion flow`

## Files likely to change

- `docs/ai-test-cases.md`
- `docs/qa_plan.md`
- `docs/plans/tasks/ai-integration-06-qa-acceptance-suite.md`
- backend/frontend/e2e test planning artifacts if they exist separately

## Documentation impact

- `Primary:`
- `docs/plans/tasks/ai-integration-06-qa-acceptance-suite.md`
- `Likely:`
- `docs/ai-test-cases.md`
- `docs/qa_plan.md`
- `docs/plans/05-ai-integration-plan.md`

## Риски / заметки

- если не определить initial subset, команда начнёт трактовать все 61 кейс как merge-blocking, что затормозит slice без реальной пользы
- если acceptance suite не разделит backend/frontend/E2E ownership, появятся либо дыры, либо дорогие и дублирующие тесты
- ambiguous outcomes вроде placeholder-only code должны быть сняты до начала стабилизации CI coverage

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если readiness subset изменился относительно первоначального плана, кратко зафиксировать причину
- если verification достигнута через существующие artifacts без новых документов, явно отметить это здесь

### Implementation notes

- `docs/ai-test-cases.md` теперь фиксирует первый merge-blocking acceptance subset как 13 обязательных scenarios вместо неявного "30-case subset".
- Acceptance ownership разделён между backend integration, frontend integration и manual integrated smoke без дублирования ответственности.
- Ambiguous outcomes, мешавшие стабильной автоматизации, уточнены:
  - `TC-E-13` больше не фиксирует неверное `validation.extractionApplied: true` для repair-success path
  - `TC-EMP-04` теперь детерминированно требует `AI_CODE_EXTRACTION_FAILED`
- `docs/qa_plan.md` теперь явно перечисляет текущие automated suites, которые считаются достаточными для first-slice AI merge gate.

### Verification notes

- Manual cross-check completed against `docs/qa_plan.md`, `api/docs/ai_contract.md`, `docs/ai-architecture.md`, and tasks `ai-integration-02` ... `ai-integration-05`.
- Confirmed automated backend acceptance coverage via `api/tests/integration/ai/test_endpoint.py` and `api/tests/integration/ai/test_validation_pipeline.py`.
- Confirmed automated frontend acceptance coverage via `ui/src/features/ai/api/aiApi.test.ts`, `ui/src/features/ai/model/contextBuilder.test.ts`, and `ui/src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx`.
