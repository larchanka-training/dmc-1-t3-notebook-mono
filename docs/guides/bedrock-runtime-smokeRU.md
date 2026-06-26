# Bedrock Runtime Smoke Guide

## Назначение

Этот guide даёт команде пошаговый checklist по AWS Console для проверки canonical AI runtime path:

- `frontend -> backend -> AWS Bedrock`

Используйте его, когда нужно:

- подтвердить доступность Bedrock model в целевом регионе
- проверить wiring backend runtime role и secret
- отличить config issue от live AWS access issue
- прогнать manual Bedrock-backed smoke на synced notebook

Для backend operational contract и failure taxonomy также смотрите:

- [../../api/docs/ai_runtime_operations.md](../../api/docs/ai_runtime_operations.md)
- [./bedrock-runtime-smoke.md](./bedrock-runtime-smoke.md)

## Что нужно до начала

- доступ к правильному AWS account
- доступ к target region в AWS Console
- доступ к ECS service, где работает backend API
- доступ к IAM role, привязанной к ECS task
- доступ к Secrets Manager secret, на который ссылается `AWS_APP_SECRET_ARN`

Этот guide предполагает, что target region:

- `eu-north-1`

## Короткий маршрут

Откройте эти экраны по порядку:

1. `Amazon Bedrock -> Model catalog`
2. `ECS -> Clusters -> <target cluster> -> Services -> <api service>`
3. `ECS -> Task definition -> latest active revision`
4. `IAM -> Roles -> <task role>`
5. `Secrets Manager -> <secret from AWS_APP_SECRET_ARN>`
6. `GET /api/v1/system/health`
7. `CloudWatch -> Log groups -> <api service log group>`

## Шаг 1. Подтвердить AWS Region

В верхней панели AWS Console выставьте регион:

- `Europe (Stockholm) / eu-north-1`

Не смешивайте регионы при проверке Bedrock, ECS и Secrets Manager.

Если backend config указывает на `eu-north-1`, а в консоли вы смотрите другой регион, результат smoke нельзя считать валидным.

## Шаг 2. Подтвердить модель в Bedrock

Откройте:

- `Amazon Bedrock -> Model catalog`

Проверьте:

- target model видна в `eu-north-1`
- точный model id совпадает с `AI_PROVIDER_MODEL`
- для модели не остались незавершённые onboarding steps, например:
  - `Request access`
  - `Complete setup`
  - `Subscribe`
  - `First-time use`

Если карточка модели не видна в `eu-north-1`, backend не сможет вызвать её из этого региона.

## Шаг 3. Подтвердить prerequisites для third-party model

Откройте карточку target model в Bedrock и проверьте, не требуется ли:

- заполнить first-time-use form
- оформить AWS Marketplace subscription
- подтвердить billing или payment method

Если что-то из этого не завершено, backend может выглядеть “правильно настроенным”, но всё равно падать на invoke с access error.

## Шаг 4. Подтвердить target backend service

Откройте:

- `ECS -> Clusters -> <target cluster> -> Services -> <api service>`

Проверьте:

- это действительно backend API service нужного окружения
- service находится в состоянии `Running`
- tasks живы и healthy
- service использует ожидаемую revision task definition

Если у вас несколько окружений, например `dev`, `staging`, `prod`, проверяйте ровно тот service, где хотите прогнать smoke.

## Шаг 5. Подтвердить Task Definition

Из ECS service откройте:

- `Task definition -> latest active revision`

Проверьте:

- `Task role ARN`
- container environment variables или secrets
- что `AWS_APP_SECRET_ARN` действительно передаётся, если runtime config идёт через Secrets Manager

Здесь wiring target environment становится конкретным.

## Шаг 6. Подтвердить IAM Role

Откройте:

- `IAM -> Roles -> <task role from the ECS task definition>`

Проверьте, что role умеет:

- вызывать выбранную Bedrock model
- читать runtime secret из Secrets Manager
- расшифровывать secret, если используется customer-managed KMS key

Минимально role должна поддерживать Bedrock invoke path и:

- `secretsmanager:GetSecretValue`

Если role неверная или неполная, Bedrock smoke не пройдёт независимо от application code.

## Шаг 7. Подтвердить runtime secret

Откройте:

- `Secrets Manager -> <secret referenced by AWS_APP_SECRET_ARN>`

Проверьте, что secret содержит ожидаемые runtime settings, например:

```ini
AI_PROVIDER_ENABLED=true
AI_PROVIDER_NAME=bedrock
AI_PROVIDER_MODEL=deepseek.v3.2
AI_BEDROCK_REGION=eu-north-1
AI_BEDROCK_TIMEOUT_SECONDS=20
AI_BEDROCK_MAX_RETRIES=1
```

Проверьте особенно внимательно:

- `AI_PROVIDER_ENABLED=true`
- `AI_PROVIDER_NAME=bedrock`
- `AI_PROVIDER_MODEL` точно совпадает с model id из Bedrock
- `AI_BEDROCK_REGION=eu-north-1`

Если secret и Bedrock catalog расходятся по region или model id, считайте это hard blocker.

## Шаг 8. Подтвердить health surface

Откройте:

- `GET /api/v1/system/health`

Backend должен вернуть безопасный AI readiness block с полями:

- `provider`
- `configured`
- `ready`
- `reason`
- `missing_fields`

Ожидаемые happy-path значения:

- `ai.provider = "bedrock"`
- `ai.configured = true`
- `ai.ready = true`

Смысл типовых значений:

| Health value | Meaning |
|---|---|
| `reason=disabled` | `AI_PROVIDER_ENABLED` выключен |
| `reason=incomplete-config` | не хватает одного или нескольких обязательных AI env vars |
| `reason=sdk-unavailable` | в runtime контейнера недоступна Bedrock SDK support |
| `reason=ready` | local runtime wiring готов; live AWS invoke всё ещё требует валидных role/model access |

## Шаг 9. Подтвердить CloudWatch Logs

Откройте:

- `CloudWatch -> Log groups -> <api service log group>`

После одного AI request проверьте, что logs содержат:

- `request_id`
- класс исхода provider path, например timeout, unavailable, invalid response или success

В логах не должно быть:

- raw AWS credentials
- полного prompt text
- полного notebook context payload
- secret values из `AWS_APP_SECRET_ARN`

## Шаг 10. Прогнать product smoke

Когда AWS и health checks чистые:

1. Войдите в продукт.
2. Откройте synced notebook.
3. Выберите durable `text` block как AI source.
4. Введите простой prompt, например:

```text
Write JavaScript code that parses a CSV string into an array of objects.
```

5. Запустите AI generation.
6. Подтвердите, что backend request завершился успешно.
7. Подтвердите, что generated code вставился в следующий пустой `code` block или в новый `code` block под source block.
8. Подтвердите, что вставленный код остаётся редактируемым.
9. Запустите этот `code` block в notebook runtime.

## Быстрый checklist на несовпадения

Эти значения должны совпадать между экранами:

| Экран | Что должно совпасть |
|---|---|
| Bedrock Model catalog | точный model id |
| Runtime secret | `AI_PROVIDER_MODEL` |
| Console region | `eu-north-1` |
| Runtime secret | `AI_BEDROCK_REGION=eu-north-1` |
| ECS service | правильный task definition |
| Task definition | правильные task role и `AWS_APP_SECRET_ARN` |
| IAM role | права на Bedrock invoke и Secrets Manager read |

## Типовые ошибки и их смысл

| Симптом | Наиболее вероятная причина |
|---|---|
| модель не видна в Bedrock | неверный регион или модель недоступна в регионе |
| health показывает `incomplete-config` | неверные или отсутствующие secret/env values |
| health показывает `sdk-unavailable` | проблема packaging/runtime контейнера |
| AI request возвращает `503 AI_PROVIDER_UNAVAILABLE` | проблема task role, model access или outbound connectivity |
| AI request возвращает `504 AI_PROVIDER_TIMEOUT` | проблема provider latency или timeout budget |
| frontend flow ломается до backend call | проблема auth, sync или source-block prerequisite |

## Рекомендуемый workflow для команды

Когда команда включает AI в новом окружении:

1. Проверить доступность Bedrock model в target region.
2. Проверить ECS service и task definition.
3. Проверить привязанную task role.
4. Проверить runtime secret.
5. Проверить `GET /api/v1/system/health`.
6. Отправить один реальный AI request и зафиксировать `requestId`.
7. Если request упал, открыть CloudWatch logs и искать этот `requestId`.

Такой порядок не смешивает notebook-level проблемы с AWS runtime проблемами.
