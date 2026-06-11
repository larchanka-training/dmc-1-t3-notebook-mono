# Stage 6 Plan: Transition from Replay Runtime to Live Worker Session

## Цель

Перевести notebook execution runtime с текущей replay-based session модели на настоящую live `Web Worker` session, чтобы выполнение `JavaScript` вело себя как ожидаемый notebook kernel:

- повторный `run current` не ломается на redeclaration
- `run from here` не переисполняет лишние side effects выше целевой точки
- shared execution state сохраняется как live runtime context, а не как повторное воспроизведение source history
- поведение ближе к реальному `execution session`, зафиксированному в `docs/project.md` и `ui/docs/runtime_architecture.md`

## Контекст

- [docs/project.md](../project.md)
- [docs/system_architecture.md](../system_architecture.md)
- [docs/tech_stack.md](../tech_stack.md)
- [docs/plans/mvp-roadmap.md](./mvp-roadmap.md)
- [docs/plans/05-execution-runtime.md](./05-execution-runtime.md)
- [ui/docs/runtime_architecture.md](../../ui/docs/runtime_architecture.md)
- [ui/docs/adr/ADR-003-runtime-execution-model.md](../../ui/docs/adr/ADR-003-runtime-execution-model.md)
- текущая runtime core implementation:
  - `ui/src/features/execution/lib/notebookRuntimeCore.ts`
  - `ui/src/features/execution/lib/notebookRuntimeWorker.ts`
  - `ui/src/features/execution/lib/notebookWorkerBridge.ts`

## Текущее состояние

Stage 5 execution MVP реализован и покрыт тестами:

- `run current`
- `run all`
- `run from here`
- output binding
- runtime controls/states
- transient output semantics

Но текущая session semantics основана не на live lexical/runtime scope, а на replay уже выполненных code blocks.

## Проблема

### 1. Session сейчас не является настоящим live runtime context

Текущая реализация хранит `execution session` как список source blocks и перед каждым новым запуском формирует program через replay предыдущих blocks.

Следствие:

- runtime воспроизводит историю кода, а не продолжает настоящий in-memory JS scope
- поведение ближе к `recompute from source history`, чем к notebook kernel

### 2. Side effects replay-ятся повторно

При `run from here` или повторном downstream run верхние blocks исполняются снова, если они нужны для восстановления state.

Это может повторно вызывать:

- `fetch`
- `console` outputs
- `localStorage` writes
- mutation-heavy code
- nondeterministic expressions (`Date.now()`, `Math.random()`)

### 3. Performance деградирует с ростом истории

Чем больше upstream blocks уже участвовали в session, тем больше source приходится повторно исполнять для восстановления state.

Это ухудшает:

- latency повторных runs
- predictability long notebook flows
- timeout behavior

### 4. Асинхронность и background behavior плохо сочетаются с replay

`setTimeout`, subscriptions, long-lived callbacks, async workflows и внешние side effects в replay-модели либо дублируются, либо дают семантику, отличную от ожидаемой пользователем.

### 5. Уже найден реальный symptom

Баг с повторным `Run block` / `From here` и ошибкой:

`Identifier 'orders' has already been declared`

был исправлен через truncate replay branch, но это локальный workaround внутри replay architecture, а не решение корневой проблемы.

## Почему это важно

Проектная модель обещает пользователю `execution session`, в которой state сохраняется между связанными запусками.

Replay-based model достаточно хороша как Stage 5 MVP, но становится хрупкой для:

- notebooks с side effects
- notebooks с большим числом code blocks
- более реалистичного exploratory coding
- будущих runtime extensions

Если оставить replay architecture как долгосрочную основу, стоимость исправлений и edge-case hardening будет только расти.

## Целевая модель

### Target runtime semantics

Worker должен владеть настоящим live runtime session:

- один dedicated worker на notebook session
- один persistent JS context внутри worker
- `run current` исполняет code block в уже существующем live scope
- `run from here` выполняет нужный range в live scope без replay более ранних blocks внутри самого runtime
- `run all` по-прежнему делает clean reset и top-to-bottom execution
- `stop` / `timeout` по-прежнему coarse-grained через terminate + recreate worker

### Architectural ownership

- `Execution Orchestrator` по-прежнему отвечает за block order, range selection, commands и output binding
- `Worker Runtime` отвечает за isolated execution и live session state
- outputs по-прежнему transient
- backend по-прежнему не участвует в run flow

## Migration principles

1. Не ломать существующий Stage 5 UX до конца migration.
2. Сначала заменить runtime internals, не меняя публичные execution store contracts без необходимости.
3. Сохранить worker-first decision из ADR-003.
4. Не смешивать migration runtime semantics с новыми фичами вроде chart protocol, DOM runtime, persistence outputs или backend execution.
5. Держать fallback path и verification на каждом шаге.

## Предлагаемый план перехода

### Step 1. Зафиксировать ограничения replay-модели тестами и документацией

Нужно явно закрепить:

- side-effect replay risk
- current branch-truncation workaround
- expected future live-session semantics

Deliverables:

- doc alignment in `ui/docs/runtime_architecture.md`
- targeted tests that would fail under broken branch replacement or wrong reset semantics

### Step 2. Introduce live worker evaluation boundary

Заменить runtime core так, чтобы worker хранил live session context, а не массив source blocks.

Возможные варианты:

- worker-owned mutable scope object + wrapped evaluation function
- worker-owned module-like evaluator with persistent bindings
- explicit cell registry and evaluator API

На этом шаге важно:

- не менять execution bridge protocol резко
- сохранить existing normalized output/error contract

### Step 3. Separate declaration persistence from range orchestration

После перехода к live scope:

- runtime больше не replay-ит upstream blocks для обычного `run current`
- orchestrator продолжает решать, какие blocks запускать для `run all` / `run from here`
- runtime просто исполняет переданный block sequence в уже существующей session

Это должно убрать повторные side effects выше стартовой точки в обычных downstream runs.

### Step 4. Revisit error and timeout semantics under live session

Проверить и закрепить:

- syntax error does not corrupt an otherwise valid session
- runtime error in one block не делает session невалидной автоматически, если не требуется reset
- `stop` и `timeout` по-прежнему гарантируют clean next session через terminate/recreate

### Step 5. Expand verification for live session behavior

Добавить tests/scenarios для:

- repeated `run current` on the same block
- repeated `run from here` without upstream replay side effects
- shared mutable state across sequential blocks
- reset correctness for `run all`
- behavior after stop/timeout

## Что не нужно делать в этом плане

- не переводить runtime на backend execution
- не добавлять `iframe` runtime как primary path
- не делать durable persistence outputs
- не вводить полноценный `console` history system
- не расширять notebook language support beyond current `JavaScript`
- не добавлять new dependency без явного одобрения

## Риски migration

### 1. Live eval в worker может усложнить isolation guarantees

Нужно сохранить минимальный runtime surface и не открыть app internals.

### 2. JS declaration semantics tricky

`const`, `let`, `class`, function declarations и top-level bindings в persistent context потребуют аккуратной модели, иначе появятся новые edge cases.

### 3. Async and cancellation semantics останутся coarse-grained

Даже в live session full cooperative cancellation, скорее всего, останется out of scope. Это нужно сохранить как explicit boundary.

### 4. Migration может затронуть tests шире, чем кажется

Если часть текущих tests implicitly полагается на replay behavior, их придется переписать под более правильную live-session semantics.

## Acceptance criteria for the transition plan

Этот direction plan можно считать реализованным, когда:

- runtime больше не зависит от replay предыдущих source blocks для обычного сохранения session state
- повторный `run current` одного и того же блока не требует branch truncation workaround, чтобы избежать redeclaration
- repeated downstream runs не воспроизводят upstream side effects только ради восстановления state
- `run all` по-прежнему reset-ит session и исполняет notebook сверху вниз
- current execution store/output contracts остаются совместимыми или документированно обновлены

## Suggested future task split

Рекомендуемый порядок будущих task specs:

1. `Execution Runtime: Зафиксировать target live-session semantics и contracts`
2. `Worker Runtime: Перевести runtime core с replay на live worker session`
3. `Execution QA: Добавить regression coverage для repeated runs, side effects и reset semantics`
4. `Docs: Обновить runtime architecture и Stage roadmap после migration`

## Итог

Replay-based runtime выполнила свою задачу как быстрый Stage 5 MVP.

Но если продукт остается `JavaScript notebook` с настоящим exploratory execution flow, следующий качественный шаг — переход на live worker session.

Иначе проект будет продолжать наращивать workaround-слой вокруг архитектуры, которая по семантике уже расходится с ожиданием от notebook execution.
