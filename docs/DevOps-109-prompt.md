
# Attempt 6.1

## Initial AI Prompt

```
role: DevOps engineer
task:
  Расширить инфраструктуру для поддержки “живого” продукта
  Необходимо реализовать:
  - preview-развёртывания для каждой ветки (per-branch preview deployments)
  - автоматический деплой при merge в основную ветку
  - оптимизацию кэширования сборок (build caching)
 
  Результат:
  - работающие preview-URL для каждого pull request
  - обновлённый CI/CD pipeline
  - набор Terraform конфигураций в папке `infra/`

  составь - как наиболее оптимально это сделать с учетом того, что развертывание должно происходить в AWS облако.
  для развертывания мы будем использовать terraform.

  параметры AWS:
  - account id: 867633231218
  - регион: eu-north-1
  - имя S3 bucket: dmc-1-t3-notebook-terraform-state 
  - таблица в DynamoDB: dmc-1-t3-notebook-terraform-lock
  - для доступа к AWS в секретах GitHub прописаны параметры: secrets.AWS_ACCESS_KEY_ID, secrets.AWS_SECRET_ACCESS_KEY

  сохрани план в `docs/DevOps-109-specs.md` файл 

constraints:
  - мы не можем использовать AWS AppRunner - он не доступен в регионе eu-north-1
  - план должен быть составлен на английском.
  - локальная конфигурация docker должна оставаться рабочей, docker-compose.yaml, 
    также api/Dockerfile и ui/Dockerfile должны по прежнему создавать и запускать 
    локальную рабочую конфигурацию
  - домен будет изменен как только мы выберем имя и купим его.
  - в GitHub Actions нужно прописать возможность запускать build/deploy принудительно.
  - над похожим проектом работает 3 команды - каждая делает свою версию той же задачи, каждая в своем репозитарии на GitHub.
  - все 3 команды работают в рамках account id 867633231218, у каждой команды свой набор IAM пользователей в AWS.
  - для deploy в AWS создан пользователь `deploy-user`, он может быть использован только из GitHub Actions.
  - нужно чтобы наша концигурация не создавала конфликтов с развертыванием 
    в AWS других команд, поскольку каждая команда может выбрать свой путь развертывания.
  - наша команда называется `t3` - поэтому все префиксы должны включать `t3` и не испорльзовать слово `team`.
  - имя mono-репозитария нашей команды на GitHub - `larchanka-training/dmc-1-t3-notebook-mono`
  - в Terraform запрещено формировать ключи `for_each` из значений, которые становятся известны только во время `apply` (например, `security_group_id`, `subnet_id`, ARN ресурсов). Ключи `for_each` должны быть статическими и вычислимыми на этапе `plan`; динамические значения допускаются только в `each.value`.
  - версия PostgreSQL для RDS должна задаваться через переменную и указываться как major-версия (например, `"16"`), без жесткой фиксации minor-версии (например, `"16.4"`), чтобы избежать региональных ошибок `Cannot find version ... for postgres`.
  - в этом регионе AWS предоставляет только версию 17 для PostgreSQL
  - backend Terraform (S3 bucket для state и DynamoDB table для lock) должен рассматриваться как bootstrap-слой и управляться отдельно от основного apply (например, через `infra/bootstrap` и отдельный manual workflow).
  - если bootstrap workflow существует только в feature-ветке, нужно предусмотреть временный `push` trigger с `paths`-фильтром для тестирования до merge, потому что `workflow_dispatch` не будет зарегистрирован в GitHub UI/API до появления workflow в `main`.
```


## Execution

### Step 1

```
role: DevOps engineer
task:
  проанализируй `docs/DevOps-109-specs.md` план. 
  проверь на соответствие архитектуре проекта. 
```  


### Step 2

```
role: DevOps engineer
task:
  проанализируй `docs/DevOps-109-specs.md` план. 
  на его основе создай все нужные terraform описания. сохрани их в подпапке `infra`. 
  создай необходимые GitHub Actions. 
```


## Pre-release

### v1

```
context:
  В файле `docs/DevOps-109-Q&A.md` описаны проблемы которые пришлось 
  решать при создании terraform конфигурации для AWS инфраструктуры.
  Имя секции с вопросом начинается с "Q:" или "QQ:" есть это под-вопрос к предыдущему.
  имя секции с ответом - всегда "(response)".

task:
  Проанализируй проблемы которые пришлось решать. 

  Предложи - как улучшить документацию `docs/DevOps-109-specs.md` чтобы описанные проблемы не повторялись.
  Обрати внимание на то, что там пришлось исправить ошибку `Invalid for_each argument` в конфигурации terraform.
  файл `docs/DevOps-109-specs.md` должен быть на английском.

  Предложи - как улучшить исходный запрос в файле `docs/DevOps-109-prompt.md` секция "Initial AI Prompt".
  файл `docs/DevOps-109-prompt.md` должен быть на русском.
```

### v2

```
context:
  В файле `docs/DevOps-109-Q&A.md` описаны проблемы которые пришлось 
  решать при создании terraform конфигурации для AWS инфраструктуры.
  Имя секции с вопросом начинается с "Q:" или "QQ:" есть это под-вопрос к предыдущему.
  имя секции с ответом - всегда "(response)".

task:
  Проанализируй проблемы которые пришлось решать. 

  Предложи - как улучшить документацию `docs/DevOps-109-specs.md` чтобы описанные проблемы не повторялись.
  Обрати внимание на то, что там пришлось исправить ошибку `Invalid for_each argument` в конфигурации terraform.
  Файл `docs/DevOps-109-specs.md` должен быть на английском!

  Предложи - как улучшить исходный запрос в файле `docs/DevOps-109-prompt.md` секция "Initial AI Prompt". Добавляй уточнения в секцию "constraints".
  Файл `docs/DevOps-109-prompt.md` должен быть на русском!
```


# Polishing Solution

## Move `ui` to static S3 bucket

```
role: DevOps engineer
task:
  измени terraform конфигурацию чтобы `ui` отдавался со статичного S3 bucket.
  нужно осуществить переход с использования *Nginx в ECS* на *S3 + CloudFront*.

  что нужно сделать:
  - создать terraform модуль `infra/modules/static-site` (S3 + CloudFront)
  - удалить `module "ui_service"` (ECS/Nginx) из `env/dev` и `env/prod`
  - удалить переменную `ui_image` из `env/dev` и `env/prod` — docker-образ ui больше не нужен
  - обновить `deploy-main.yml`: заменить сборку docker-образа ui на `pnpm build`,
    добавить шаги `aws s3 sync` и `aws cloudfront create-invalidation`
  - обновить документацию: `docs/tech_stack.md`, `CLAUDE.md`

constraints:
  - S3 bucket должен быть приватным; доступ CloudFront → S3 только через OAC (Origin Access Control)
  - CloudFront должен быть единой точкой входа для ui И для api:
      `/*`    → S3 bucket (статика)
      `/api/*` → ALB (api-сервис) через CloudFront origin (http-only внутри AWS)
    это необходимо, потому что браузер запрещает mixed content (https ui + http api),
    а также потому что relative URL `/api/v1` резолвится в CloudFront-домен, а не в ALB
  - для SPA-роутинга CloudFront должен возвращать `index.html` при ошибках 403 и 404
  - CloudFront origin для ALB: `origin_protocol_policy = "http-only"`, порт 80
  - cache behavior для `/api/*`: TTL=0, cookies forward=all (нужно для сессионных куки),
    allowed_methods включают все HTTP-методы (GET/POST/PUT/DELETE/PATCH/OPTIONS)
  - VITE_API_BASE_URL (не VITE_API_URL!) должен получать абсолютный HTTPS-адрес:
    `https://<cloudfront_domain>/api/v1` — именно такую переменную читает `ui/src/shared/api/config.ts`
  - в GitHub Actions порядок шагов важен:
    1. сначала `terraform apply` (создаёт CloudFront distribution и ALB)
    2. затем `terraform output -raw ui_cloudfront_domain_name` → передать в `VITE_API_BASE_URL`
    3. затем `pnpm build` (bake URL в статику)
    4. затем `aws s3 sync` + `aws cloudfront create-invalidation`
  - Node.js в CI должен быть версии 22+, потому что pnpm 11.x требует Node ≥ 22.13
    (использует встроенный модуль `node:sqlite`, отсутствующий в Node 20)
  - `preview`-окружение (env/preview) использует ECS+proxy и НЕ меняется в рамках этой задачи
  - BACKEND_CORS_ORIGINS в api_service должен использовать CloudFront HTTPS-домен:
    `https://<module.ui.cloudfront_domain_name>`
```  


## Move `api/.env` to AWS secret

### Attempt 1
```
role: DevOps engineer
task:
  как перенести все значимые параметры из `api/.env` файла в AWS secret?
  чтобы локально по прежнему использовался `api/.env` файл.
  в при запуске на AWS эти значения должны читаться из AWS secret.
  желательно из одного AWS secret, чтобы не пришлось создавать десятки разных AWS secrets.
```  


### Attempt 2
```
role: DevOps engineer
task:
  нужно перенести все значимые параметры из `api/.env` файла в AWS secret.
  локально по прежнему будет использоваться `api/.env` файл.
  `api` приложение должно проверить - если оно запущено под AWS тогда нужно прочитать все параметры из AWS secret.

constraints:
  - это должен быть один AWS secret, не более
  - это должен быть именгно AWS secret, никакого дублирования secret в GitHub!
  - это должен быть plain text ini-file формат, никакого JSON!
```  


### Adjustments

#### Patch 1
```
для `api` проекта нужно прочитать .env` параметер `AUTH_DEBUG_MODE`. 
конвертировать его в boolean и если там `true` - тогда нужно OTP код положить в HTTP headers response для `/api/v1/auth/request-otp` запроса.
```

#### Patch 2
```
в ответе `/api/v1/health` вместе с версией нужно показывать время сборки приложения – реальное время сборки, когда оно было собрано GitHub actions и timezone вместе с ним. поле должно называться `build_time`.
Также в заголовках ответа `/api/v1/health` должен быть `X-Git-Branch` в котором содержится ветка в GIT из которой было собрано текущее приложение.
```





