# T3/BTF -> FRONT: Реализовать worker runtime bridge и session lifecycle

## Status

- `done`

## Цель

Реализовать минимальный `Worker Runtime` для Stage 5, чтобы notebook `JavaScript` исполнялся в изолированном `Web Worker`, session reuse/reset rules соблюдались, а frontend execution layer получал нормализованные runtime messages вместо mock run behavior.

## Контекст

- `docs/plans/03-execution-runtime.md`
- `docs/plans/tasks/execution-runtime-01-execution-contracts-and-store.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/runtime_architecture.md`
- `ui/docs/adr/ADR-003-runtime-execution-model.md`
- текущий execution slice: `ui/src/features/execution/model/`
- текущий editor placeholder run flow: `ui/src/features/editor/model/useNotebookEditor.ts`
- текущая output type model: `ui/src/entities/output/`, `ui/src/features/execution/model/types.ts`

## Scope

- добавить dedicated `Web Worker` для исполнения notebook `JavaScript`
- реализовать runtime adapter / bridge между frontend execution layer и worker:
  - spawn worker
  - send typed app-to-worker commands
  - receive normalized result messages
  - receive normalized error messages
  - terminate worker
  - recreate clean worker session после `stop` или `timeout`
- зафиксировать app-to-worker protocol для минимального worker lifecycle:
  - `RUN_BLOCKS`
  - `RESET_SESSION`
  - `TERMINATE_SESSION`
  - run-scoped `executionId` или эквивалентный identifier для защиты от stale messages
- реализовать session lifecycle semantics:
  - первый запуск создает session
  - `run current` и `run from here` переиспользуют текущую session
  - `run all` выполняется только после reset session
  - `stop` грубо завершает текущий worker
- реализовать только transport и lifecycle semantics для `run current` / `run from here` / `run all`, не расширяя задачу до полного block-order orchestration
- нормализовать syntax errors, runtime errors, timeout и canceled execution в единый error shape
- гарантировать, что сообщения от старого worker или старого `executionId` игнорируются после `stop`, `reset`, `timeout` или повторного запуска
- ограничить runtime boundary так, чтобы worker не получал app stores, persistence adapters, auth secrets и другие app internals

## Out of scope

- полноценный orchestration sequencing поверх notebook block order
- вычисление ordered block range для `run all` и `run from here`; эта задача только исполняет уже переданный runtime payload
- UI wiring block actions
- финальный output renderer
- backend changes
- DOM-centric runtime или `iframe` runtime
- durable persistence execution session state

## Технические ограничения

- primary runtime для Version 1 должен быть `Web Worker`, а не `iframe`
- cancellation допускается только coarse-grained через terminate/recreate worker
- execution остается `client-side`; backend не должен участвовать в run flow
- runtime bridge не должен передавать в worker доступ к React app internals
- новые зависимости не добавлять без явного одобрения

## Acceptance criteria

- [ ] В кодовой базе существует worker entry point и runtime bridge, который может исполнять JavaScript вне main UI thread
- [ ] В execution domain зафиксирован минимальный typed app-to-worker protocol как минимум для `RUN_BLOCKS`, `RESET_SESSION`, `TERMINATE_SESSION` и worker-to-app сообщений с `executionId`
- [ ] `run current` и `run from here` используют один и тот же worker session до явного reset/stop
- [ ] `run all` запускается через reset session и не наследует предыдущее execution state
- [ ] `stop` завершает активный worker, а следующий запуск использует новую clean session
- [ ] Syntax errors, thrown runtime errors, timeout и canceled execution приводятся к общему normalized error contract
- [ ] Сообщения от завершенного worker или неактуального `executionId` не мутируют текущий execution state после `stop`, `reset`, `timeout` или rapid re-run
- [ ] Реализация не открывает worker доступ к app store, auth secrets или persistence adapters

## Verification

- [ ] `cd ui && ./node_modules/.bin/vitest run src/features/execution/model/executionSlice.test.ts`
- [ ] `cd ui && ./node_modules/.bin/vitest run` для runtime bridge / worker lifecycle test files
- [ ] `cd ui && ./node_modules/.bin/tsc -p tsconfig.app.json --noEmit`
- [ ] вручную проверить сценарий: блок 1 объявляет переменную, блок 2 использует её без reset
- [ ] вручную проверить сценарий: `run all` после предыдущего run не видит старую session
- [ ] вручную проверить сценарий: `stop` прерывает long-running execution и следующий run стартует с чистого состояния
- [ ] вручную или тестом проверить сценарий: сообщения от старого worker после terminate/recreate игнорируются и не перезаписывают outputs текущего запуска

## Dependencies

- `Depends on T3/BTF -> FRONT: Зафиксировать execution-контракты и store actions`

## Files likely to change

- `ui/src/features/execution/`
- `ui/src/shared/lib/`
- worker entry file under `ui/src/`
- `ui/src/features/execution/model/types.ts`
- `ui/src/features/execution/model/executionSlice.ts`

## Documentation impact

- `Conditional:`
- `ui/docs/runtime_architecture.md`
- `ui/docs/adr/ADR-003-runtime-execution-model.md`

## Риски / заметки

- самый чувствительный участок задачи это сохранение общего scope между последовательными запусками без утечки деталей bridge API
- timeout semantics важно реализовать без ложных positive и без подвешивания UI state
- если bridge protocol окажется слишком низкоуровневым, следующая orchestration задача станет избыточно сложной
- если в этой задаче начать вычислять block order вместо принятия готового runtime payload, она начнет пересекаться с `execution-runtime-03-orchestrator-run-sequencing.md`

## Completion update

- `Status` updated to `done`
- implemented:
  - worker entry point and dedicated `Web Worker` bridge
  - typed app-to-worker protocol: `RUN_BLOCKS`, `RESET_SESSION`, `TERMINATE_SESSION`
  - worker-to-app runtime messages with `executionId`
  - timeout / stop terminate-and-recreate lifecycle
  - stale message protection by active `executionId`
  - real `run current` execution through the worker bridge
- verification completed:
  - `cd ui && ./node_modules/.bin/tsc -p tsconfig.app.json --noEmit`
  - `cd ui && ./node_modules/.bin/vitest run src/features/execution/model/executionSlice.test.ts src/features/execution/lib/notebookRuntimeCore.test.ts src/features/execution/lib/notebookWorkerBridge.test.ts src/features/editor/ui/NotebookEditorView.test.tsx`
- documentation updated:
  - `ui/docs/runtime_architecture.md`
- follow-up orchestration work was completed in:
  - `docs/plans/tasks/execution-runtime-03-orchestrator-run-sequencing.md`
