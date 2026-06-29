# Модели Bedrock для `eu-north-1` для генерации `JavaScript`

> Исследовательская заметка спринта для обсуждения в команде. Этот файл не является каноническим архитектурным документом.

## Назначение

Эта заметка фиксирует практический shortlist моделей Amazon Bedrock, которые релевантны текущему AI scope:

- backend-mediated генерация через Bedrock
- генерация `JavaScript` внутри notebook workflow
- целевой регион `AI_BEDROCK_REGION=eu-north-1`

Цель документа — помочь команде принять решения:

1. какая модель должна быть моделью по умолчанию для Version 1
2. какие альтернативные модели стоит сравнивать
3. оправдан ли multi-model compare mode в продукте

## Границы и оговорки

- Доступность и цены проверялись `2026-06-25`.
- В заметке используются официальные AWS Bedrock pricing и Bedrock model access docs.
- AWS pricing pages не всегда показывают точные Bedrock `modelId` в текстовом экспорте.
- Перед тем как подключать новую модель в `AI_PROVIDER_MODEL`, нужно брать точный `modelId` из `Amazon Bedrock -> Model catalog` в `eu-north-1`.
- Ниже формулировка “подтверждено в `eu-north-1`” означает, что provider/model появился для `Europe (Stockholm)` в текстовом экспорте AWS Bedrock pricing page.
- `anthropic.claude-haiku-4-5-20251001-v1:0` вынесен отдельно, потому что уже фигурирует в обсуждении спринта, но в текстовом экспорте AWS pricing page во время этой проверки для него не нашлось строки со Stockholm pricing.

## Текущая ситуация в репозитории

Текущий локальный backend config уже использует Bedrock и указывает на:

- `AI_PROVIDER_NAME=bedrock`
- `AI_PROVIDER_MODEL=deepseek.v3.2`
- `AI_BEDROCK_REGION=eu-north-1`

Это означает, что путь с минимальным риском — оставить одну Bedrock model как основной production default и добавлять compare capability только как контролируемый эксперимент.

## Короткая рекомендация

### Рекомендуемая модель по умолчанию для Version 1

- `DeepSeek v3.2`

Почему:

- уже подключена в репозитории
- подтверждена для `Europe (Stockholm)`
- разумная стоимость
- меньше AWS onboarding friction, чем у Anthropic

### Лучшая альтернатива для compare mode

- `Mistral Devstral 2 123B`

Почему:

- явно позиционируется как code-oriented model
- подтверждена для `Europe (Stockholm)`
- выглядит существенно более сильным “developer model” кандидатом, чем generic chat models
- стоит дороже DeepSeek по output, но все еще реалистична для контролируемых экспериментов

### Лучший “дешевый second opinion” кандидат

- `NVIDIA Nemotron 3 Super 120B A12B`

Почему:

- очень низкая цена output tokens
- подтверждена для `Europe (Stockholm)`
- привлекательна как недорогой side-by-side baseline

### Модель, которую стоит оценивать только если команда готова к дополнительному AWS friction

- `Anthropic Claude Haiku 4.5`

Почему:

- вероятно, хорошо подходит по качеству code generation и instruction following
- но Anthropic в Bedrock требует дополнительных access steps, поэтому rollout сложнее, чем у DeepSeek

## Подтвержденные Bedrock-кандидаты в `eu-north-1`

| Model | Подтверждено в `eu-north-1` | Цена / 1M input tokens | Цена / 1M output tokens | Подходит для JS code generation | Основные плюсы | Основные минусы |
|---|---|---:|---:|---|---|---|
| `DeepSeek v3.2` | yes | `$0.74` | `$2.22` | сильный кандидат для default | уже используется в repo; низкий setup friction; сбалансированное соотношение price/quality | не самый явно code-specialized вариант |
| `Mistral Devstral 2 123B` | yes | `$0.48` | `$2.40` | сильный compare-кандидат | явно dev-oriented; input price ниже, чем у DeepSeek | output price немного выше; еще не подключена в repo |
| `MiniMax M2.1` | yes | `$0.36` | `$1.44` | бюджетный compare-кандидат | дешевле DeepSeek; подтверждена доступность в Stockholm | менее очевидная репутация именно для code generation, чем у Devstral / Claude |
| `MiniMax M2.5` | yes | `$0.36` | `$1.44` | бюджетный compare-кандидат | такая же низкая цена, как у M2.1; легко включить в эксперименты | та же неопределенность по code specialization |
| `Kimi K2.5` | yes | `$0.72` | `$3.60` | возможный compare-кандидат | способная model family для длинных задач; подтверждена доступность в Stockholm | дорогая по output; слабее как default choice для частой генерации кода |
| `NVIDIA Nemotron 3 Super 120B A12B` | yes | `$0.18` | `$0.78` | дешевый baseline / second opinion | очень привлекательный cost profile; дешевые output tokens | неясно, сможет ли она обойти DeepSeek по качеству кода в этом продукте |

## Модели, которые обсуждаются явно, но не подтверждены этим pricing extract

### `Anthropic Claude Haiku 4.5`

Статус:

- обсуждается командой
- точный кандидат `modelId` уже фигурирует в контексте спринта: `anthropic.claude-haiku-4-5-20251001-v1:0`
- сложность Bedrock access для нее явно выше, чем для DeepSeek

Операционные замечания:

- Anthropic models требуют одноразовый `First Time Use` / use-case submission в Bedrock
- Bedrock documentation также указывает на возможные AWS Marketplace prerequisites для first enablement third-party models
- это увеличивает rollout friction для `dev` / `staging` / `prod`

Рекомендация:

- оценивать только если команде нужен quality-focused compare path и есть время на access setup
- не переключать основной product default на Anthropic, пока хотя бы один smoke run не пройдет успешно в реальном target environment

### Семейство `Amazon Nova`

Статус:

- операционно выглядит привлекательно, потому что это first-party AWS
- но text-exported pricing page, использованный в этой проверке, не показал пригодную Stockholm pricing row в собранном excerpt

Рекомендация:

- проверять напрямую в `Model catalog` для `eu-north-1`
- если подходящая `Nova` text model доступна в Stockholm, ее стоит benchmark-ить, потому что first-party AWS models обычно уменьшают operational friction

## Почему Anthropic сложнее, чем DeepSeek, в Bedrock

Это вопрос AWS onboarding, а не application-code.

По сравнению с `DeepSeek`, Anthropic обычно добавляет:

- одноразовую use-case / first-time-use submission
- возможный AWS Marketplace subscription path при first enablement
- более длинный operational checklist для Bedrock access readiness

Для этого спринта это означает:

- `DeepSeek` — лучший “ship now” default
- `Anthropic` — лучший “quality benchmark if access is approved” candidate

## Рекомендация по продукту для multi-model support

### Моя рекомендация

Не стоит выпускать “много равноправных моделей” как обычную end-user feature в Version 1.

Лучше:

1. оставить одну primary production model
2. добавить одно опциональное compare action под feature flag или internal setting
3. ограничить compare mode до `2` моделей на один запрос

### Почему не стоит сразу показывать много моделей

- продуктовая сложность быстро растет
- пользователи не будут понимать, как выбирать между множеством model names
- стоимость растет почти линейно с числом model runs
- QA и observability усложняются, потому что один prompt теперь имеет несколько provider outcomes
- текущий product scope — это `AI inside notebook workflow`, а не model playground

### Более подходящие product shapes для Version 1

#### Option A. Только одна default model

Подходит когда:

- цель спринта — надежная поставка
- важнее всего cost и operational simplicity

Оценка:

- лучший default для production launch

#### Option B. Default model + `Compare with alternative`

Подходит когда:

- команда хочет controlled experimentation
- продукту все еще нужен один canonical path

Поведение:

- первый run использует default model
- пользователь может явно запросить еще один alternative result
- UI показывает оба draft перед insertion

Оценка:

- лучший баланс для этого проекта

#### Option C. User-selectable model picker

Подходит когда:

- команда сознательно хочет “model lab” experience

Оценка:

- не рекомендуется для Version 1
- слишком много UX и QA complexity для текущего scope

## Рекомендуемый V1 shortlist

### Основная модель

- `DeepSeek v3.2`

### Альтернативная compare-model

- `Mistral Devstral 2 123B`

### Опциональный дешевый baseline

- `NVIDIA Nemotron 3 Super 120B A12B`

Это дает команде:

- один уже интегрированный default
- один code-oriented challenger
- один недорогой baseline для cost-sensitive experiments

## Предлагаемый evaluation plan

Для любого кандидата сравнивать нужно на одном и том же prompt set:

1. генерация обычной `JavaScript` function
2. генерация class
3. генерация React component
4. code edit / repair prompt
5. поведение на malformed output
6. latency и timeout behavior

Измерять:

- долю syntax-valid code
- соблюдение правила “returns only code”
- необходимость repair retry
- median latency
- average token cost

## Предложение по решению

### Для спринта

- оставить `DeepSeek v3.2` как default Bedrock model в `eu-north-1`
- подготовить compare experiments для `Mistral Devstral 2 123B`
- держать `Anthropic Claude Haiku 4.5` как отдельный benchmark track, а не как immediate rollout default

### Для product scope

- не строить open-ended multi-model selection в Version 1
- если compare mode будет реализован, он должен быть явным, ограниченным и не по умолчанию

## Источники

- AWS Bedrock pricing: `https://aws.amazon.com/bedrock/pricing/`
- AWS Bedrock model access и Anthropic prerequisites: `https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html`
- Repo runtime smoke guide: `docs/guides/bedrock-runtime-smoke.md`
- Repo Bedrock runtime contract: `api/docs/ai_runtime_operations.md`
