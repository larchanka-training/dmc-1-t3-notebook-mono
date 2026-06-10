# Приоритет создания планов

## Цель

Этот документ фиксирует, какие файлы-планы нужно создать прямо сейчас, в каком порядке и что именно должно быть внутри каждого из них.

Он нужен как промежуточный рабочий артефакт между верхнеуровневым roadmap и подробными задачами.

Этот документ отвечает на вопросы:

- какой следующий план писать после уже существующего [01-auth-backend-plan.md](./01-auth-backend-plan.md)
- какие планы действительно нужны для движения к MVP
- что должен покрывать каждый план, чтобы команда и агенты могли дальше раскладывать его в задачи

## Основание

Порядок ниже следует из:

- [mvp-roadmap.md](./mvp-roadmap.md)
- [mvp-roadmapRU.md](./mvp-roadmapRU.md)
- текущего состояния репозитория
- уже существующего плана [01-auth-backend-plan.md](./01-auth-backend-plan.md)

## Что уже есть

Уже создан:

- [01-auth-backend-plan.md](./01-auth-backend-plan.md)

Дальше нужно последовательно добавить планы по следующим направлениям.

## Приоритетный список файлов-планов

### 1. `docs/plans/02-notebook-persistence-plan.md`

**Почему это следующий приоритет**

После авторизации это самый важный backend-этап. Без него нельзя перейти к реальной работе со списком notebook, открытием notebook, хранением состояния и последующей синхронизацией.

**Что должен дать этот план**

- общее представление, как реализовать backend-хранение notebook
- порядок шагов от модели хранения до API и integration tests
- явные зависимости от auth

**Что должно быть внутри**

- Goal
- Task Artifact
- Assumptions
- Architecture Notes
- Tasks
- Risks and Open Points

**Какие темы должен покрывать**

- модель хранения notebook
- JSONB snapshot
- notebook CRUD API
- revision model
- owner-only access control
- связь notebook API с auth
- integration coverage для notebook endpoints
- минимальная опора для дальнейшей frontend integration

**Ожидаемые этапы внутри плана**

1. persistence model and migrations
2. create/list/get notebook
3. rename/delete notebook
4. owner-only access control
5. integration tests
6. frontend contract alignment

### 2. `docs/plans/03-local-first-persistence-plan.md`

**Почему это следующий приоритет**

MVP требует local-first поведения. После backend-хранения notebook нужно отдельно спланировать хранение рабочей копии в браузере, чтобы не смешивать local state, server state и sync.

**Что должен дать этот план**

- структуру local-first хранения
- правила работы с рабочей копией
- понятный порядок реализации browser-side persistence

**Что должно быть внутри**

- Goal
- Task Artifact
- Assumptions
- Architecture Notes
- Tasks
- Risks and Open Points

**Какие темы должен покрывать**

- IndexedDB/Dexie
- local notebook working copy
- unsynced metadata
- restore after reload
- local/server state boundaries
- влияние на notebook editor stores
- проверки на reload recovery

**Ожидаемые этапы внутри плана**

1. local storage schema
2. persistence adapters
3. working copy save/load
4. unsynced change markers
5. restore after reload
6. frontend wiring and tests

### 3. `docs/plans/04-execution-runtime-plan.md`

**Почему это высокий приоритет**

Даже при готовом auth и notebook storage продукт ещё не станет notebook в полном смысле слова, пока код нельзя выполнять. Это одна из центральных возможностей MVP.

**Что должен дать этот план**

- понятную модель выполнения кода в браузере
- порядок реализации runtime от основы до пользовательских команд запуска
- ясные границы между runtime, editor и outputs

**Что должно быть внутри**

- Goal
- Task Artifact
- Assumptions
- Architecture Notes
- Tasks
- Risks and Open Points

**Какие темы должен покрывать**

- worker/runtime foundation
- execution session
- run block
- run all
- run from selected point
- output binding
- output normalization
- error and timeout behavior
- negative scenarios

**Ожидаемые этапы внутри плана**

1. runtime foundation
2. single block execution
3. session reuse and reset rules
4. run all / run from selected point
5. output normalization
6. tests and failure handling

### 4. `docs/plans/05-sync-plan.md`

**Почему это следующий приоритет**

Этот этап логически следует после backend-хранения notebook и local-first хранения рабочей копии. Раньше писать его можно, но полноценно планировать лучше после фиксации этих двух направлений.

**Что должен дать этот план**

- полную схему ручной синхронизации
- порядок реализации backend sync и frontend conflict UX
- ясные правила конфликтов

**Что должно быть внутри**

- Goal
- Task Artifact
- Assumptions
- Architecture Notes
- Tasks
- Risks and Open Points

**Какие темы должен покрывать**

- sync endpoint
- `base_revision`
- `409 Conflict`
- success/error/conflict states
- conflict UX
- local/server reconciliation rules
- отсутствие auto-merge

**Ожидаемые этапы внутри плана**

1. backend sync contract realization
2. frontend sync state model
3. success and error handling
4. conflict response handling
5. explicit conflict UX
6. integration and end-to-end verification

### 5. `docs/plans/06-ai-integration-plan.md`

**Почему это не нужно писать первым**

AI важен для MVP, но не должен планироваться раньше auth, notebook data flow и runtime. Иначе получится план поверх ещё неустойчивой основы.

**Что должен дать этот план**

- последовательность реализации AI внутри notebook workflow
- границы между backend AI endpoint и frontend insertion flow
- связь AI с обычным редактированием и выполнением кода

**Что должно быть внутри**

- Goal
- Task Artifact
- Assumptions
- Architecture Notes
- Tasks
- Risks and Open Points

**Какие темы должен покрывать**

- backend AI endpoint
- selected block context
- prompt flow
- regenerate flow
- confirm/edit insertion
- execution after insertion
- contract between backend and frontend

**Ожидаемые этапы внутри плана**

1. backend endpoint
2. prompt flow in UI
3. regenerate flow
4. insertion and editing
5. execution after insertion
6. tests and error handling

### 6. `docs/plans/07-release-readiness-plan.md`

**Почему он последний**

Этот план имеет смысл только после того, как понятны реальные core flows продукта. Иначе он превратится в список пожеланий, а не в конкретный plan для доведения MVP до выпуска.

**Что должен дать этот план**

- перечень работ для выхода на MVP sign-off
- понимание quality gates
- набор проверок, без которых продукт нельзя считать готовым

**Что должно быть внутри**

- Goal
- Task Artifact
- Assumptions
- Architecture Notes
- Tasks
- Risks and Open Points

**Какие темы должен покрывать**

- export notebook JSON
- smoke flows
- regression coverage
- performance checks
- accessibility checks
- error handling polish
- final MVP exit criteria

**Ожидаемые этапы внутри плана**

1. export
2. smoke and regression coverage
3. known gap cleanup
4. performance and accessibility checks
5. release readiness checklist

## Рекомендуемый порядок создания этих планов

Создавать их лучше в таком порядке:

1. `02-notebook-persistence-plan.md`
2. `03-local-first-persistence-plan.md`
3. `04-execution-runtime-plan.md`
4. `05-sync-plan.md`
5. `06-ai-integration-plan.md`
6. `07-release-readiness-plan.md`

## Почему именно такой порядок

- `02` нужен, потому что без backend-хранения notebook дальнейшие шаги висят в воздухе.
- `03` нужен сразу после `02`, потому что local-first — одно из главных требований MVP.
- `04` нужен рано, потому что выполнение кода — одна из центральных возможностей продукта.
- `05` зависит от понимания и backend-хранения, и local-first модели.
- `06` лучше писать после фиксации опоры под notebook data flow и runtime.
- `07` должен завершать набор направлений, а не подменять собой недостающие core plans.

## Практическое правило

Пока не создан следующий plan-файл, не стоит массово плодить задачи по этому направлению.

Сначала:

1. direction plan
2. потом task specs
3. потом implementation

Это снижает риск хаотичной разработки и помогает команде и агентам работать по одинаковой картине проекта.

## Следующее рекомендуемое действие

Следующий файл, который стоит создать прямо сейчас:

- `docs/plans/02-notebook-persistence-plan.md`

После него:

- `docs/plans/03-local-first-persistence-plan.md`
- `docs/plans/04-execution-runtime-plan.md`
