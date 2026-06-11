# T3/BTF -> QA: Закрепить Stage 5 тестами и acceptance verification

## Status

- `done`

## Цель

Закрепить Stage 5 как стабильный MVP slice через тесты и явные acceptance-сценарии, чтобы execution contracts, `Worker Runtime`, orchestration sequencing, `Output Renderer` и user-visible runtime states проверялись системно, а не только через разрозненные ручные прогоны.

## Контекст

- `docs/plans/05-execution-runtime.md`
- `docs/plans/tasks/execution-runtime-01-execution-contracts-and-store.md`
- `docs/plans/tasks/execution-runtime-02-worker-runtime-bridge-and-lifecycle.md`
- `docs/plans/tasks/execution-runtime-03-orchestrator-run-sequencing.md`
- `docs/plans/tasks/execution-runtime-04-output-renderer.md`
- `docs/plans/tasks/execution-runtime-05-execution-controls-and-states.md`
- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `ui/docs/ui_architecture.md`
- `ui/docs/runtime_architecture.md`
- текущие frontend tests: `ui/src/features/execution/**/*.test.ts`, `ui/src/features/editor/**/*.test.tsx`, `ui/src/entities/output/**/*.test.ts`

## Scope

- добавить или обновить unit tests для:
  - execution slice transitions
  - normalized error and output contracts
  - runtime adapter lifecycle behavior
- добавить или обновить integration/component tests для:
  - `run current`
  - `run all`
  - `run from here`
  - `stop`
  - output binding to correct `blockId`
  - rendering `text`, `object`, `table`, `error`
- зафиксировать acceptance scenarios для Stage 5 как executable verification checklist
- проверить и закрепить правило, что runtime outputs не попадают в durable notebook state
- при необходимости дополнить `docs/qa_plan.md` Stage 5-specific сценариями

## Out of scope

- новые runtime features вне Stage 5 scope
- backend/API testing
- e2e coverage для несвязанных notebook features
- redesign existing test infrastructure beyond what Stage 5 needs

## Технические ограничения

- verification должна опираться на реальные execution boundaries проекта: `client-side`, `frontend-side orchestration`, worker-based execution
- тесты не должны закреплять placeholder behavior, который заменяется runtime implementation
- acceptance checks должны подтверждать, что outputs не становятся durable notebook content
- новые test dependencies не добавлять без явного одобрения

## Acceptance criteria

- [ ] Unit tests покрывают execution store transitions и normalized error/output behavior
- [ ] Runtime adapter tests покрывают session reuse, reset before `run all`, worker termination on `stop`, и clean restart behavior
- [ ] Integration или component tests покрывают `run current`, `run all`, `run from here` и binding outputs к правильным `code` blocks
- [ ] Output rendering tests покрывают `text`, `object`, `table`, `error`
- [ ] Есть проверка, что reload не восстанавливает runtime outputs как durable notebook state
- [ ] Acceptance checklist Stage 5 позволяет другому инженеру повторить ключевые сценарии без догадок

## Verification

- [ ] `cd ui && pnpm test`
- [ ] `cd ui && pnpm test -- execution`
- [ ] `cd ui && pnpm test -- editor`
- [ ] вручную пройти acceptance scenarios: session reuse, reset on `run all`, stop/timeout, output rendering, no durable outputs after reload

## Dependencies

- `Depends on T3/BTF -> FRONT: Добавить execution controls и user-visible runtime states`

## Files likely to change

- `ui/src/features/execution/**/*.test.ts`
- `ui/src/features/editor/**/*.test.tsx`
- `ui/src/entities/output/**/*.test.ts`
- `ui/src/entities/notebook/**/*.test.ts`
- `docs/qa_plan.md`

## Documentation impact

- `Conditional:`
- `docs/qa_plan.md`
- `docs/plans/05-execution-runtime.md`

## Риски / заметки

- если sequencing и worker lifecycle не закрепить integration tests, регрессии будут трудноуловимы и проявятся только в ручной работе с notebook
- важно не ограничиться happy-path checks: `stop`, `timeout`, syntax error и runtime error должны быть явно покрыты
- тесты должны проверять separation between durable notebook content and transient runtime outputs, иначе Stage 5 нарушит проектные архитектурные границы

## Completion update

- `Status` updated to `done`
- implemented:
  - unit and integration coverage consolidated across execution slice, worker bridge/runtime core, editor orchestration, controls/states, and output rendering
  - explicit persistence test added to confirm runtime outputs do not restore as durable notebook state after rehydrate/reload
  - Stage 5 acceptance checklist added to `docs/qa_plan.md`
- verification completed:
  - `cd ui && ./node_modules/.bin/vitest run`
  - `cd ui && ./node_modules/.bin/tsc -p tsconfig.app.json --noEmit`
- verification note:
  - `cd ui && pnpm test` was not reliable in this non-interactive environment because `pnpm` attempted an install flow that aborted without TTY; equivalent verification was completed through direct `vitest` execution
- documentation updated:
  - `docs/qa_plan.md`
- delta from original scope:
  - no additional `docs/plans/05-execution-runtime.md` changes were required because the Stage 5 readiness model itself did not change; only the executable verification checklist was expanded
