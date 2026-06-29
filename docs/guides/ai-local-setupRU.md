# Локальный запуск AI генерации кода

## Назначение

Этот гайд описывает, как настроить AWS credentials и Bedrock model access для того, чтобы кнопка AI генерации кода работала локально. Охватывает полный путь от получения ключей в AWS Console до первого успешного запроса.

После выполнения всех шагов `POST /api/v1/ai/code-blocks/generate` должен возвращать `200` вместо `503`.

## Как устроен локальный AI path

```
UI → Nginx (8443) → API container → boto3 → AWS Bedrock (eu-north-1)
```

API-контейнер использует boto3 для вызова AWS Bedrock. Для этого boto3 должен найти credentials. В локальной среде credentials берутся из папки `~/.aws/` на вашей машине — `docker-compose.yaml` монтирует её внутрь контейнера:

```yaml
volumes:
  - ${HOME}/.aws:/home/appuser/.aws:ro
environment:
  AWS_PROFILE: ${AWS_PROFILE:-default}
  AWS_SDK_LOAD_CONFIG: "1"
  AWS_EC2_METADATA_DISABLED: "true"
```

Папка `~/.aws/` не существует по умолчанию — её нужно создать, получив ключи в AWS Console.

## Что нужно до начала

- Доступ к AWS аккаунту, в котором разрешён Amazon Bedrock.
- Выбранная модель должна быть активирована в регионе `eu-north-1` (см. Шаг 3).
- Docker Desktop запущен локально.

## Шаг 1. Получить AWS Access Key в AWS Console

1. Откройте [AWS Console](https://console.aws.amazon.com/).
2. Нажмите на имя аккаунта в правом верхнем углу → **Security credentials**.
3. Прокрутите вниз до раздела **Access keys**.
4. Нажмите **Create access key**.
5. Выберите use case **Command Line Interface (CLI)**, поставьте галочку подтверждения → **Next**.
6. Описание (Description) — опционально, например `local-dev`.
7. Нажмите **Create access key**.
8. Скопируйте значения:
   - **Access key ID** — выглядит как `AKIAIOSFODNN7EXAMPLE`
   - **Secret access key** — длинная строка, показывается только один раз
9. Нажмите **Done**.

> **Важно:** secret access key показывается только на этом экране. Если закрыть страницу не скопировав — придётся создать новый ключ.

> **Безопасность:** это root-аккаунт ключи. Никогда не коммитьте их в репозиторий и не передавайте в чат. Для командной работы лучше завести IAM-пользователя с минимальными правами (см. Приложение ниже).

## Шаг 2. Настроить credentials локально

Установите AWS CLI, если ещё не стоит:

```bash
brew install awscli
```

Запустите настройку:

```bash
aws configure
```

Ответьте на вопросы:

```
AWS Access Key ID [None]: <ваш Access Key ID>
AWS Secret Access Key [None]: <ваш Secret Access Key>
Default region name [None]: eu-north-1
Default output format [None]: json
```

Это создаст два файла:

- `~/.aws/credentials` — содержит ключи
- `~/.aws/config` — содержит регион и формат

Проверьте, что credentials работают:

```bash
aws sts get-caller-identity
```

Ожидаемый ответ — JSON с вашим `Account`, `UserId` и `Arn`. Если видите `NoCredentials` — что-то пошло не так при `aws configure`.

## Шаг 3. Активировать модель в Amazon Bedrock

AWS Bedrock требует явно включить каждую модель в аккаунте перед использованием. Это разовая операция.

1. Откройте [AWS Console](https://console.aws.amazon.com/) и переключитесь в регион **Europe (Stockholm) / eu-north-1**.
2. Перейдите в **Amazon Bedrock → Model catalog** (или **Model access** в левом меню).
3. Найдите модель, которая прописана в `api/.env` в переменной `AI_PROVIDER_MODEL`.
4. Откройте карточку модели и нажмите **Request access** или **Enable**, если кнопка присутствует.
5. Дождитесь статуса **Access granted** (обычно мгновенно для большинства моделей, кроме Anthropic).

Убедитесь, что точный model ID в карточке совпадает с `AI_PROVIDER_MODEL` в `api/.env`. Несовпадение ID — частая причина ошибок.

> **Anthropic models:** для Claude требуется дополнительная форма подтверждения use case. Это занимает время. Если используете DeepSeek или Mistral — шаг обычно мгновенный.

## Шаг 4. Проверить `api/.env`

Откройте `api/.env` и убедитесь, что AI-переменные заполнены корректно:

```ini
AI_PROVIDER_ENABLED=true
AI_PROVIDER_NAME=bedrock
AI_PROVIDER_MODEL=<точный model id из Bedrock catalog>
AI_BEDROCK_REGION=eu-north-1
AI_BEDROCK_TIMEOUT_SECONDS=20
AI_BEDROCK_MAX_RETRIES=1
```

Частые ошибки:

| Проблема | Симптом |
|---|---|
| `AI_PROVIDER_ENABLED=false` | health показывает `reason=disabled` |
| `AI_BEDROCK_REGION` не совпадает с регионом активации | `503` при вызове |
| `AI_PROVIDER_MODEL` не совпадает с id в Bedrock | `503` или `AccessDeniedException` |

## Шаг 5. Перезапустить API контейнер

После изменения `~/.aws/` или `api/.env` контейнер нужно перезапустить:

```bash
docker compose restart api
```

Или полный rebuild если меняли Dockerfile:

```bash
docker compose up --build api
```

## Шаг 6. Проверить health и сделать тестовый запрос

Проверьте health endpoint:

```
GET https://api.notebook.com:8443/api/v1/system/health
```

Ожидаемый ответ:

```json
{
  "status": "healthy",
  "ai": {
    "provider": "bedrock",
    "configured": true,
    "ready": true,
    "reason": "ready"
  }
}
```

> `ready: true` означает только, что конфигурация полна и boto3 доступен. Реальные credentials проверяются только при первом AI запросе.

Затем откройте UI, создайте текстовый блок с prompt, например:

```
Write a JavaScript function that sorts an array of numbers.
```

Нажмите кнопку AI генерации. Если всё настроено — появится сгенерированный code block.

## Диагностика ошибок

### `503 AI_PROVIDER_UNAVAILABLE`

Самая частая причина локально — нет credentials или модель не активирована.

```bash
# Проверить что credentials видны
aws sts get-caller-identity

# Проверить что модель доступна (пример для DeepSeek)
aws bedrock list-foundation-models \
  --region eu-north-1 \
  --query 'modelSummaries[?contains(modelId, `deepseek`)].{id:modelId,status:modelLifecycle.status}'
```

Также проверьте логи контейнера:

```bash
docker compose logs api --tail=50 | grep -E "AI|bedrock|error|503"
```

Если видите `169.254.169.254 timed out` — `~/.aws/` не найден или пустой.

### `504 AI_PROVIDER_TIMEOUT`

Bedrock отвечает слишком долго. Проверьте:

- правильный ли регион (`eu-north-1`)
- не слишком ли маленький `AI_BEDROCK_TIMEOUT_SECONDS` (ставьте не меньше `20`)

### Health показывает `reason=incomplete-config`

Не заполнена одна из обязательных переменных. Поле `missing_fields` в ответе укажет какая именно.

## Приложение. IAM-пользователь с минимальными правами

Использовать root-аккаунт ключи для разработки — допустимо только временно. Лучше создать отдельного IAM-пользователя.

### Минимальная IAM-политика для Bedrock

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "arn:aws:bedrock:eu-north-1::foundation-model/*"
    }
  ]
}
```

### Создание пользователя

1. **IAM → Users → Create user**
2. Имя, например `notebook-dev-local`
3. На шаге Permissions выберите **Attach policies directly** → создайте политику выше
4. После создания пользователя перейдите в **Security credentials → Create access key** — аналогично Шагу 1

Затем запустите `aws configure` с ключами нового пользователя.

## Связанные документы

- [bedrock-runtime-smokeRU.md](./bedrock-runtime-smokeRU.md) — smoke-checklist для AWS окружения
- [local-development.md](./local-development.md) — общий гайд по локальной разработке
- [../../api/docs/ai_runtime_operations.md](../../api/docs/ai_runtime_operations.md) — operational contract backend AI
- [../sprints/sprint-2/ai-models-eu-north-1-researchRU.md](../sprints/sprint-2/ai-models-eu-north-1-researchRU.md) — shortlist моделей для eu-north-1
