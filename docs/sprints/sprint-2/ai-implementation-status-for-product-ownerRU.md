# Статус реализации AI для Product Owner

## Назначение

Этот документ простыми словами объясняет, что уже реализовано по `docs/plans/05-ai-integration-plan.md`, что сознательно не вошло в первый slice и что ещё нужно сделать, чтобы реальная генерация кода заработала end-to-end для пользователей.

Канонический implementation scope для этого статуса задаётся документами:

- `docs/plans/05-ai-integration-plan.md`
- `docs/ai-architecture.md`
- `api/docs/ai_contract.md`
- `docs/ai-test-cases.md`

## Что уже реализовано

Первый AI slice для Version 1 больше не находится только на уровне архитектуры и планирования. Базовый продуктовый и технический foundation уже собран.

### 1. Реализован основной пользовательский сценарий

Целевой Version 1 flow теперь определён и связан в одну цепочку:

1. Пользователь пишет задачу или описание в `text` block.
2. Пользователь запускает AI для этого блока.
3. Frontend собирает ограниченный контекст.
4. Запрос уходит в backend AI endpoint.
5. Backend валидирует запрос и вызывает AI provider через отдельную boundary.
6. Backend извлекает код, проверяет JavaScript syntax и делает одну repair retry, если код сломан.
7. Frontend вставляет сгенерированный код в notebook.

Это и есть core product scenario, зафиксированный в `05-ai-integration-plan.md`.

### 2. Зафиксирован backend contract для AI

В проекте теперь есть один канонический backend endpoint для AI code generation:

- `POST /api/v1/ai/code-blocks/generate`

Формат request/response задокументирован и согласован между backend, frontend и QA. Это значит, что команды больше не работают с плавающими или неформальными предположениями о payload.

### 3. Реализованы backend-проверки и safety gates

До вызова реальной модели backend теперь проверяет:

- пользователь авторизован
- notebook принадлежит пользователю или доступен ему
- source block валиден
- prompt действительно просит сгенерировать код
- prompt не является unsafe и не пытается сделать prompt injection

С продуктовой точки зрения это важно, потому что AI здесь не является свободным chat-режимом. Он ограничен use case генерации кода внутри notebook.

### 4. Реализован backend post-processing ответа модели

Backend больше не возвращает raw provider text “как есть”.

Сейчас он уже умеет:

- извлекать код из ответа модели
- проверять JavaScript syntax
- делать bounded repair retry, если первый ответ невалидный
- возвращать нормализованные ошибки, если генерация не удалась

Это была одна из самых сложных частей плана, и она уже покрыта тестами.

### 5. Реализовано frontend AI-взаимодействие внутри notebook

Editor уже поддерживает продуктовый AI interaction pattern:

- AI запускается из `text` block
- пользователь видит состояния запроса (`idle`, `submitting`, `success`, `error`)
- AI state остаётся transient и не меняет durable notebook schema
- полученный код вставляется в следующий пустой `code` block или в новый `code` block после source block

Это означает, что notebook-side AI UX foundation уже существует.

### 6. Реализован deterministic context builder

Frontend теперь собирает контекст контролируемо, а не отправляет в модель произвольное содержимое notebook.

Поддержано:

- default `scope: this`
- ограниченный `scope: notebook`
- выбор insertion target
- обрезка request при слишком большом контексте

Это важно, потому что делает первый slice предсказуемым и тестируемым.

### 7. Зафиксировано acceptance coverage для первого slice

Для первого AI vertical slice теперь определён фиксированный acceptance subset.

Это значит, что команда уже зафиксировала:

- какие сценарии блокируют merge
- какие кейсы покрываются backend integration tests
- какие кейсы покрываются frontend integration tests
- какие проверки пока остаются manual

Это не даёт AI scope разрастись в бесконечную QA-поверхность.

## Что сознательно не вошло в первый slice

Следующие вещи намеренно оставлены вне первого implementation slice.

### 1. Local LLM / `WebLLM`

Это не канонический путь для Version 1.

Утверждённая архитектура является backend-first. Локальное выполнение модели в браузере остаётся optional future scope или fallback scope, а не обязательной частью первой поставки.

### 2. Полноценная Playwright AI end-to-end automation

Первый slice не требует широкой Playwright AI automation, чтобы считаться реализованным.

Сейчас проект опирается на:

- backend integration tests
- frontend integration tests
- manual integrated smoke для реального browser path

Playwright `@ai` coverage остаётся логичным следующим шагом, но она не требовалась для завершения первого slice.

### 3. Durable AI history или новый `ai` block type

Notebook model остаётся намеренно простой:

- `text` blocks
- `code` blocks

Нового durable `ai` block type нет, нет и отдельной модели prompt history или отдельной AI-сущности в notebook persistence.

### 4. Широкое notebook-wide AI поведение по умолчанию

Первый slice не отправляет весь notebook по умолчанию.

Scope остаётся ограниченным и детерминированным, чтобы поведение было предсказуемым и проще валидировалось.

### 5. Продвинутые AI platform features

По-прежнему вне scope:

- provider routing
- token/cost analytics
- advanced revision UX
- direct browser-to-provider production mode
- полная productization local fallback

## Почему пользователь сейчас видит

`Validation: AI generation requires a synced notebook available on the server.`

Это ожидаемое текущее поведение.

Backend AI flow завязан на реальную server-side notebook identity. Backend должен уметь:

- проверить права доступа
- найти notebook
- найти source block внутри notebook

Если текущий notebook существует только локально и ещё не синхронизирован с backend, frontend блокирует запрос ещё до вызова AI endpoint.

Если editor route использует local working-copy id вроде `local-...`, само по себе это не является блокером. Synced local working copy всё равно может вызывать AI, если sync metadata содержит реальный server-backed notebook id.

То есть сейчас AI доступен для notebook, который уже существует на сервере, включая synced local working copy этого notebook, но не для чисто локального unsynced draft.

## Что ещё нужно сделать, чтобы заработала реальная генерация кода

Оставшаяся работа теперь связана уже не столько с UI, сколько с runtime и окружением.

### 1. Обеспечить использование AI только со synced notebook

Реальный generation path зависит от того, что notebook существует на backend.

На практическом продуктовом языке это значит: пользователь должен работать с notebook, который уже создан или синхронизирован на сервер.

### 2. Настроить реальный provider path через `AWS Bedrock`

Утверждённый canonical provider path такой:

- frontend -> backend -> Bedrock

Значит, в backend runtime должна быть реально доступна и рабочая provider configuration для целевого окружения.

### 3. Доделать backend runtime configuration для Bedrock

Минимально нужно:

- Bedrock credentials / IAM access
- region configuration
- model configuration
- безопасная работа с environment variables / secrets

Без этого code path существует структурно, но не может выполнять реальную генерацию против provider.

### 4. Проверить backend connectivity из реального окружения

Даже если код корректен, генерация не заработает, пока backend environment не может реально достучаться до Bedrock и не имеет прав использовать выбранную модель.

Это сейчас главный практический dependency для перехода от “feature foundation реализован” к “реальная генерация работает”.

### 5. Завершить DevOps / operations hardening

Implementation plan явно оставляет отдельный operational step:

- безопасная runtime configuration
- request logging без утечки секретов
- basic protective throttling
- документация поведения для local/dev/staging/prod

Это ещё нужно завершить до того, как feature можно считать production-ready.

### 6. Прогнать реальный integrated smoke scenario

После настройки Bedrock команде нужен один реальный manual integrated test:

1. login
2. открыть synced notebook
3. написать задачу в `text` block
4. запустить AI generation
5. получить сгенерированный код
6. подтвердить вставку в `code` block
7. проверить, что код остаётся editable и executable

Это подтвердит, что работает именно полный реальный путь, а не только моки или изолированные части.

### 7. Добавить browser-level AI E2E automation после стабилизации реального path

Когда реальный provider path будет работать стабильно, следующим логичным шагом QA станет Playwright `@ai` scenario, который покрывает реальный пользовательский путь в браузере.

## Product Summary

AI feature уже реализована как реальный первый slice, но пока ещё не полностью operational в реальном окружении.

Что уже есть сегодня:

- user-facing notebook AI flow
- backend contract
- validation and repair pipeline
- insertion logic
- automated acceptance coverage для первого slice

Что пока блокирует реальную генерацию:

- требование synced notebook в реальном использовании
- реальная Bedrock configuration
- runtime и DevOps setup
- финальный integrated smoke на реальном окружении

## Recommended Next Product Step

Самый полезный следующий шаг сейчас связан не с новым UI.

Нужно довести до конца реальный backend runtime path для Bedrock и проверить один реальный synced-notebook generation flow end-to-end.

После этого команда сможет:

- включить реальную user-facing code generation
- добавить Playwright AI E2E coverage
- позже отдельно решить, должен ли `WebLLM` оставаться deferred или стать осознанным fallback mode
