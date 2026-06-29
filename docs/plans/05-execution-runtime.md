# Stage 5 Plan: Execution Runtime MVP

## Цель

Реализовать MVP-исполнение notebook `JavaScript` в браузере в соответствии с архитектурными ограничениями проекта:

- выполнение остается `client-side`
- orchestration остается `frontend-side`
- код пользователя исполняется изолированно
- `execution session` сохраняется между связанными запусками
- outputs остаются runtime-артефактами и не входят в durable notebook state

План опирается на:

- [docs/plans/mvp-roadmap.md](./mvp-roadmap.md)
- [ui/docs/runtime_architecture.md](../../ui/docs/runtime_architecture.md)
- [ui/docs/adr/ADR-003-runtime-execution-model.md](../../ui/docs/adr/ADR-003-runtime-execution-model.md)
- текущее состояние `ui/src/features/execution/` и `ui/src/features/editor/`

## Границы Stage 5

### In scope

- `run current block`
- `run all`
- `run from here`
- worker-based runtime
- session reset/reuse rules
- outputs: `text`, `object`, `table`, `error`
- execution outputs are stored per `blockId` as `outputs of latest run`, not as a session-wide append-only history
- UI-состояния `idle`, `running`, `stopping`, `error`, `canceled`, `timeout`

### Out of scope

- backend changes
- durable persistence execution outputs
- изменение notebook JSON schema
- доступ runtime к app stores, auth secrets, persistence adapters
- полноценный DOM runtime
- расширенная chart runtime-модель, если она требует отдельного протокола

## Зависимости и порядок

Рекомендуемый порядок реализации:

1. `Execution Orchestrator`: доменные контракты и store actions
2. `Worker Runtime`: worker bridge и session lifecycle
3. `Execution Orchestrator`: sequencing и orchestration flow
4. `Output Renderer`: real output rendering
5. `Execution Orchestrator`: execution controls и user-visible states
6. `QA`: закрепление поведения тестами

## Derived task specs

- [execution-runtime-01-execution-contracts-and-store.md](./tasks/execution-runtime-01-execution-contracts-and-store.md)
- [execution-runtime-02-worker-runtime-bridge-and-lifecycle.md](./tasks/execution-runtime-02-worker-runtime-bridge-and-lifecycle.md)
- [execution-runtime-03-orchestrator-run-sequencing.md](./tasks/execution-runtime-03-orchestrator-run-sequencing.md)
- [execution-runtime-04-output-renderer.md](./tasks/execution-runtime-04-output-renderer.md)
- [execution-runtime-05-execution-controls-and-states.md](./tasks/execution-runtime-05-execution-controls-and-states.md)
- [execution-runtime-06-qa-and-acceptance-verification.md](./tasks/execution-runtime-06-qa-and-acceptance-verification.md)

## Задачи

## Task 1: `T3/BTF -> Execution Orchestrator: Зафиксировать execution-контракты и store actions`

**Модуль:** `Execution Orchestrator`

**Description:**  
Заменить текущий placeholder execution state на реальный доменный контракт: команды запуска, lifecycle execution session, нормализованные runtime-сообщения, run-scoped identifier для защиты от stale messages, store actions для `run`, `reset`, `stop`, записи outputs и ошибок.

**Acceptance criteria:**
- [ ] Типы execution покрывают `run current`, `run all`, `run from here`, `reset`, `stop`
- [ ] Zustand execution slice содержит actions, а не только initial state
- [ ] Outputs хранятся отдельно от notebook durable content и привязаны к `blockId`
- [ ] `outputs[blockId]` хранит массив normalized outputs только последнего запуска блока; новый run заменяет предыдущий массив для затронутого блока
- [ ] Stale runtime messages игнорируются по `executionId` или эквивалентному run identifier
- [ ] Контракты совместимы с `Web Worker` runtime model из ADR-003

**Verification:**
- [ ] Запустить unit tests для execution slice
- [ ] Проверить, что notebook entity types не начинают хранить outputs

**Dependencies:** `None`

**Initial status:** `planned`

**Documentation impact:**
- `None`, если реализация не меняет зафиксированную runtime-модель

**Likely files or areas:**
- `ui/src/features/execution/model/types.ts`
- `ui/src/features/execution/model/executionSlice.ts`
- `ui/src/app/model/store.ts`
- `ui/src/entities/output/`

**Scope:** `S`

## Task 2: `T3/BTF -> Worker Runtime: Реализовать worker bridge и session lifecycle`

**Модуль:** `Worker Runtime`

**Description:**  
Реализовать dedicated `Web Worker` и runtime adapter, который создает worker, отправляет execution commands, получает нормализованные сообщения, завершает worker по `stop` или `timeout` и поднимает чистую session для будущих запусков.

**Acceptance criteria:**
- [ ] Выполнение кода происходит вне main UI thread
- [ ] `run current` и `run from here` переиспользуют текущую worker session
- [ ] `run all` всегда стартует с reset session
- [ ] `stop` завершает worker и делает следующий запуск чистым
- [ ] Syntax errors и runtime errors нормализуются в единый error shape
- [ ] Runtime не получает доступ к app internals, stores, secrets и persistence adapters

**Verification:**
- [ ] Запустить unit tests для runtime adapter
- [ ] Проверить вручную reuse session между последовательными block runs
- [ ] Проверить вручную, что после `stop` следующий запуск начинается с пустой session

**Dependencies:** `T3/BTF -> Execution Orchestrator: Зафиксировать execution-контракты и store actions`

**Initial status:** `planned`

**Documentation impact:**
- `None`

**Likely files or areas:**
- `ui/src/features/execution/`
- `ui/src/shared/lib/` или execution-local `lib/`
- worker entry file в `ui/src/`

**Scope:** `M`

## Task 3: `T3/BTF -> Execution Orchestrator: Подключить sequencing для run current / run all / run from here`

**Модуль:** `Execution Orchestrator`

**Description:**  
Убрать mock run behavior из editor hook и заменить его на реальный orchestration flow: чтение ordered code blocks, определение диапазона исполнения, пропуск text blocks, отправка последовательности в runtime и привязка результатов к исходным блокам.

**Acceptance criteria:**
- [ ] `run current` исполняет только выбранный code block
- [ ] `run all` исполняет все code blocks сверху вниз после reset
- [ ] `run from here` исполняет выбранный code block и все code blocks ниже
- [ ] Text blocks не отправляются в runtime и не ломают sequencing
- [ ] `runningBlockIds`, `targetBlockId` и execution status отражают фактический прогресс

**Verification:**
- [ ] Запустить integration tests для всех трех сценариев запуска
- [ ] Проверить вручную корректный порядок выполнения и binding outputs к blockId

**Dependencies:** `T3/BTF -> Worker Runtime: Реализовать worker bridge и session lifecycle`

**Initial status:** `planned`

**Documentation impact:**
- `None`

**Likely files or areas:**
- `ui/src/features/editor/model/useNotebookEditor.ts`
- `ui/src/features/execution/`
- `ui/src/entities/notebook/`
- `ui/src/features/editor/ui/`

**Scope:** `M`

## Task 4: `T3/BTF -> Output Renderer: Заменить placeholder outputs на реальные runtime outputs`

**Модуль:** `Output Renderer`

**Description:**  
Заменить текущий placeholder renderer на реальный вывод runtime-результатов рядом с originating code block. Рендерер должен поддерживать минимум `text`, `object`, `table`, `error` и корректно показывать empty/running/failed states.

**Acceptance criteria:**
- [ ] `text` output рендерится как читаемый текстовый результат
- [ ] `object` output рендерится как структурированный объект без падения UI
- [ ] `table` output рендерится как табличное представление или минимальный структурированный fallback
- [ ] `error` output показывает нормализованную ошибку
- [ ] Output визуально привязан к originating code block
- [ ] После reload runtime outputs не восстанавливаются как durable notebook state

**Verification:**
- [ ] Запустить component tests для output rendering variants
- [ ] Проверить вручную disappearance outputs после reload

**Dependencies:** `T3/BTF -> Execution Orchestrator: Подключить sequencing для run current / run all / run from here`

**Initial status:** `planned`

**Documentation impact:**
- `None`

**Likely files or areas:**
- `ui/src/entities/output/ui/`
- `ui/src/entities/output/model/`
- `ui/src/features/editor/ui/NotebookBlockView.tsx`
- `ui/src/features/editor/ui/NotebookEditorView.tsx`

**Scope:** `S`

## Task 5: `T3/BTF -> Execution Orchestrator: Добавить execution controls и user-visible states`

**Модуль:** `Execution Orchestrator`

**Description:**  
Сделать execution state видимым в editor UI: `running`, `stopping`, `error`, `canceled`, `timeout`. Подключить `run` и `stop` controls в block action cluster и защитить UI от конфликтующих запусков.

**Acceptance criteria:**
- [ ] В UI доступны `run` и `stop` действия для code blocks
- [ ] Состояния `idle`, `running`, `stopping` корректно отражаются в интерфейсе
- [ ] `canceled` и `timeout` отображаются пользователю как понятный execution result/status
- [ ] Во время активного запуска UI не допускает конфликтующих execution flows

**Verification:**
- [ ] Запустить interaction tests для notebook editor
- [ ] Проверить вручную, что `stop` прерывает long-running execution

**Dependencies:** `T3/BTF -> Output Renderer: Заменить placeholder outputs на реальные runtime outputs`

**Initial status:** `planned`

**Documentation impact:**
- `None`

**Likely files or areas:**
- `ui/src/features/editor/ui/BlockActionCluster.tsx`
- `ui/src/features/editor/ui/NotebookEditorView.tsx`
- `ui/src/features/execution/model/`

**Scope:** `S`

## Task 6: `T3/BTF -> QA: Закрепить Stage 5 тестами и acceptance verification`

**Модуль:** `Cross-module`

**Description:**  
Добавить тесты, которые закрепляют поведение всех трех модулей вместе: execution contracts, worker lifecycle, sequencing, output rendering и правило, что outputs не попадают в durable notebook state.

**Acceptance criteria:**
- [ ] Unit tests покрывают execution slice transitions и error normalization
- [ ] Runtime adapter tests покрывают reuse/reset/terminate semantics
- [ ] Integration tests покрывают `run current`, `run all`, `run from here`
- [ ] Component tests покрывают rendering `text`, `object`, `table`, `error`
- [ ] Тесты подтверждают, что outputs не попадают в notebook content model

**Verification:**
- [ ] Запустить frontend test suite для затронутых модулей
- [ ] Выполнить manual Stage 5 acceptance scenario в notebook editor

**Dependencies:** `T3/BTF -> Execution Orchestrator: Добавить execution controls и user-visible states`

**Initial status:** `planned`

**Documentation impact:**
- `docs/qa_plan.md`, если Stage 5 acceptance scenarios нужно зафиксировать явно

**Likely files or areas:**
- `ui/src/features/execution/**/*.test.ts`
- `ui/src/features/editor/**/*.test.tsx`
- `ui/src/entities/output/**/*.test.ts`
- `ui/src/entities/notebook/**/*.test.ts`

**Scope:** `M`

## Риски

- Главный технический риск находится в `Worker Runtime`: корректное сохранение общего scope между запусками и безопасное завершение long-running code.
- `table` output может расширить scope, если сразу пытаться делать богатый data-grid вместо минимального renderer.
- Текущее состояние editor использует локальные placeholder outputs; переход к orchestration через store может потребовать небольшого рефакторинга ownership state.
- `chart` output лучше не включать в обязательный core Stage 5, если для него нужен отдельный runtime protocol.

## Итог Stage 5

Stage 5 можно считать завершенным, когда:

- notebook code реально исполняется в `Web Worker`
- `run current`, `run all`, `run from here` работают по зафиксированным правилам session lifecycle
- outputs отображаются рядом с code block и не сохраняются в durable notebook state
- пользователь видит execution progress и может остановить выполнение
- поведение закреплено тестами и manual verification
