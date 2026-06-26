# T3/BTF -> FRONT: Добавить WebLLM runtime bootstrap и capability checks

## Status

- `done`

## Цель

Подготовить frontend runtime foundation для `WebLLM`, чтобы приложение умело определять поддержку local generation в текущем browser environment, лениво загружать runtime/model и явно показывать readiness states вместо неявных или хрупких fallback-поведений.

## Контекст

- `docs/plans/06-webllm-local-mode-plan.md`
- `docs/ai-architecture.md`
- `ui/docs/ui_architecture.md`
- `docs/tech_stack.md`
- existing AI feature structure:
  - `ui/src/features/ai/model/`
  - `ui/src/features/ai/api/`
  - `ui/src/shared/config/`

## Scope

- выбрать конкретный frontend runtime bootstrap path для `WebLLM`
- реализовать browser capability detection для local generation prerequisites
- реализовать explicit local-runtime states:
  - `unsupported`
  - `idle`
  - `loading-model`
  - `ready`
  - `failed`
- обеспечить lazy initialization:
  - без eager model bootstrap при открытии editor page
  - без hidden download на обычный backend-first happy path
- подготовить error surface для:
  - unsupported browser/runtime
  - bootstrap failure
  - initialization timeout or cancellation
- встроить runtime state в boundaries `features/ai`, а не в page-level state

## Out of scope

- actual generation call через `WebLLM`
- retry-fallback UI
- policy about synced vs unsynced notebooks
- acceptance coverage beyond this runtime foundation

## Технические ограничения

- инициализация должна быть lazy и reversible
- нельзя привязывать bootstrap к notebook page mount
- нельзя захардкодить поведение так, чтобы unsupported environments ломали canonical backend path
- нельзя вводить глобальный app-wide state manager для local model lifecycle вне текущего feature scope без явной необходимости

## Acceptance criteria

- [ ] Frontend умеет определять, доступен ли local `WebLLM` runtime в текущем окружении
- [ ] Runtime/model bootstrap не стартует автоматически при обычном открытии notebook editor
- [ ] Frontend различает как минимум `unsupported`, `idle`, `loading-model`, `ready`, `failed`
- [ ] Ошибки bootstrap и unsupported environments представлены в стабильной frontend-local форме
- [ ] Backend-first flow продолжает работать без зависимости от local runtime readiness

## Verification

- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] вручную пройти supported-path simulation
- [ ] вручную пройти unsupported-path simulation
- [ ] вручную сверить, что page open не триггерит hidden local model initialization

## Dependencies

- `T3/BTF -> FRONT: Ввести общий frontend provider abstraction для AI generation`

## Files likely to change

- `ui/src/features/ai/model/`
- `ui/src/features/ai/lib/`
- `ui/src/shared/config/`
- frontend tests around AI feature

## Documentation impact

- `Primary:`
- `docs/plans/tasks/webllm-local-mode-03-runtime-bootstrap-and-capability-checks.md`
- `Likely:`
- `docs/ai-architecture.md`
- `docs/tech_stack.md` if `WebLLM` becomes a fixed stack choice

## Риски / заметки

- главный риск: сделать bootstrap неявным и тем самым испортить perceived performance editor page
- browser capability checks легко становятся flaky, если их зашить в ad hoc conditions без test coverage
- local model readiness должен восприниматься как optional feature readiness, а не как global app health

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если library choice стал фиксированным stack decision, отметить это в `docs/tech_stack.md`

### Implementation notes

- Добавлен feature-owned local runtime controller в `ui/src/features/ai/model/localRuntime.ts` с explicit states:
  - `unsupported`
  - `idle`
  - `loading-model`
  - `ready`
  - `failed`
- Capability detection выполняется до bootstrap и не триггерит hidden model download:
  - secure context
  - `Worker`
  - `WebAssembly`
  - `WebGPU` adapter availability
- Bootstrap остаётся lazy:
  - hook mount и обычное открытие editor page не инициируют `WebLLM`
  - dynamic import runtime/module и model init происходят только по явному `initialize()`
- Подготовлена стабильная frontend-local error surface для:
  - disabled/unsupported environment
  - bootstrap failure
  - bootstrap timeout
  - bootstrap cancellation
- Добавлен runtime config boundary в `ui/src/shared/config/localAi.ts`:
  - `VITE_WEBLLM_LOCAL_MODE_ENABLED`
  - `VITE_WEBLLM_MODEL`
  - `VITE_WEBLLM_BOOTSTRAP_TIMEOUT_MS`
  - `VITE_WEBLLM_MODULE_SPECIFIER`
- `docs/tech_stack.md` обновлён, чтобы зафиксировать `WebLLM` как optional lazy local runtime, а не default provider path

### Verification notes

- Выполнено: `cd ui && pnpm test -- --runInBand`
- Выполнено: unit coverage для supported, unsupported, timeout, cancellation и reset-after-failure сценариев
- Manual browser simulation не выполнялась в этой среде
