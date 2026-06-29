# Локальная проверка `WebLLM` local mode

## Назначение

Этот гайд описывает, как локально проверить задачу из `docs/plans/06-webllm-local-mode-plan.md`:

- rollout guard: local mode выключен по умолчанию
- explicit opt-in через frontend env flags
- lazy bootstrap через `Prepare WebLLM`
- успешную локальную генерацию с provider label `webllm:*`
- policy для unsynced local draft
- минимальный набор автоматизированных проверок

Это guide именно для browser-local `WebLLM` path. Для canonical backend path через `Bedrock` используйте:

- [ai-local-setupRU.md](./ai-local-setupRU.md)
- [bedrock-runtime-smokeRU.md](./bedrock-runtime-smokeRU.md)

## Что нужно заранее

1. Поднять монорепозиторий по [local-development.md](./local-development.md).
2. Открывать UI через `https://notebook.com:8443`, а не через произвольный insecure origin.
3. Использовать браузер с `WebGPU` support. Практически это обычно актуальный `Chrome` / `Edge`.

Если хотите проверить retry fallback после backend failure, backend AI path тоже должен быть доступен локально. Для этого отдельно настройте Bedrock по [ai-local-setupRU.md](./ai-local-setupRU.md).

## Шаг 1. Проверить rollout guard по умолчанию

Убедитесь, что в `ui/.env` нет этих переменных:

```env
VITE_WEBLLM_LOCAL_MODE_ROLLOUT_POLICY
VITE_WEBLLM_LOCAL_MODE_ENABLED
```

Если раньше вы уже включали local mode, удалите их и перезапустите frontend:

```bash
docker compose restart frontend
```

Откройте любой notebook и найдите AI action у `text` block.

Ожидаемое поведение:

- видна только canonical кнопка `Generate code`
- секция `Local WebLLM` может оставаться видимой
- `Generate locally` видна, но disabled
- есть явное explanatory message о том, что local mode сейчас выключен конфигурацией
- никакая hidden local bootstrap activity не стартует сама по себе

Это подтверждает, что local mode не активируется silently и rollout disabled by default работает, даже если UI оставляет local controls видимыми.

## Шаг 2. Включить local mode только через explicit opt-in

Добавьте в `ui/.env`:

```env
VITE_WEBLLM_LOCAL_MODE_ROLLOUT_POLICY=dev-opt-in
VITE_WEBLLM_LOCAL_MODE_ENABLED=true
```

Repo fix уже добавляет `@mlc-ai/web-llm` в frontend dependencies, поэтому отдельный `VITE_WEBLLM_MODULE_SPECIFIER=https://esm.run/@mlc-ai/web-llm` для штатного локального запуска больше не нужен.

Опционально можно явно задать модель и timeout:

```env
VITE_WEBLLM_MODEL=Llama-3.2-1B-Instruct-q4f32_1-MLC
VITE_WEBLLM_BOOTSTRAP_TIMEOUT_MS=120000
```

Перезапустите frontend:

```bash
docker compose restart frontend
```

После этого у AI action должна появиться отдельная панель `Local WebLLM`.

Ожидаемое поведение:

- canonical кнопка `Generate code` остаётся основной
- local mode показывается как отдельный блок
- `Generate locally` уже видна, но disabled до readiness
- до bootstrap доступна кнопка `Prepare WebLLM`
- model download не стартует сам по себе при открытии страницы

## Шаг 3. Проверить supported happy path

Откройте notebook с `text` block, где есть AI prompt.

Нажмите:

1. `Prepare WebLLM`
2. дождитесь статуса вида `Local mode ready via webllm:<model>`
3. `Generate locally`

Ожидаемое поведение:

- во время bootstrap UI показывает `Preparing WebLLM...` или progress text
- после bootstrap появляется `Generate locally`
- после успешной генерации status становится `Ready via webllm:<model> · scope: ...`
- preview подписан как `Generated draft · webllm:<model>`
- сгенерированный код вставляется тем же insertion flow, что и backend path

Минимальная ручная проверка вставки:

- если следующий `code` block пустой, результат попадает в него
- если следующего пустого `code` block нет, создаётся новый `code` block сразу после source `text` block

## Шаг 4. Проверить policy для unsynced local draft

Для детерминированной проверки откройте route с локальным draft id:

- `https://notebook.com:8443/notebooks/local-draft-1`

Сначала нажмите обычную backend-кнопку `Generate code`.

Ожидаемое поведение:

- backend path блокируется сообщением `AI generation requires a synced notebook available on the server.`

Затем в той же карточке AI:

1. нажмите `Prepare WebLLM`
2. дождитесь статуса `Backend AI requires a synced notebook. Local mode ready via webllm:<model>.`
3. нажмите `Generate locally`

Ожидаемое поведение:

- local generation проходит даже для unsynced local draft
- backend prerequisite не relax-ится
- UI явно различает:
  - backend unavailable because notebook is unsynced
  - local mode available because generation идёт browser-local

## Шаг 5. Проверить unsupported runtime

Самый простой ручной вариант: открыть тот же UI в браузере/окружении без `WebGPU` support.

Проверка:

1. local mode должен быть включён env-флагами
2. нажмите `Prepare WebLLM`

Ожидаемое поведение:

- bootstrap не начинается как успешный
- `Generate locally` остаётся видимой, но disabled
- рядом показывается frontend-local ошибка
- типовые сообщения:
  - `Local AI runtime requires WebGPU support.`
  - `Local AI runtime requires a secure browser context.`
  - `Local AI runtime could not acquire a compatible WebGPU adapter.`

Важно: это должен быть именно frontend-local failure. Он не должен выглядеть как backend AI error.

## Шаг 6. Проверить retry fallback после backend failure

Этот сценарий лучше всего воспроизводить, когда canonical Bedrock path уже настроен.

Базовый сценарий:

1. оставьте local mode включённым и подготовьте `WebLLM` заранее через `Prepare WebLLM`
2. вызовите backend `Generate code`
3. добейтесь retryable backend failure класса `AI_PROVIDER_TIMEOUT` или `AI_PROVIDER_UNAVAILABLE`
4. проверьте, что local button меняет текст на `Retry locally with WebLLM`
5. нажмите его

Ожидаемое поведение:

- backend error показывается отдельно, например `Provider via bedrock: ...`
- local retry не подменяет backend path silently
- после local retry status становится `Ready via webllm:<model> · scope: ...`

Если вручную воспроизводить backend failure неудобно, этот путь уже покрыт frontend integration test `NotebookEditorPage.test.tsx`.

## Автоматизированная проверка

Запустите focused frontend tests:

```bash
cd ui
pnpm test -- src/shared/config/localAi.test.ts src/features/ai/model/localRuntime.test.ts src/features/ai/api/localAiProvider.test.ts src/features/ai/model/useBlockAiAction.test.ts src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx
```

Что именно покрывают эти файлы:

- `src/shared/config/localAi.test.ts`: rollout policy и explicit opt-in parsing
- `src/features/ai/model/localRuntime.test.ts`: lazy bootstrap, unsupported, timeout, cancellation, reset
- `src/features/ai/api/localAiProvider.test.ts`: provider normalization и local error mapping
- `src/features/ai/model/useBlockAiAction.test.ts`: provider abstraction и unchanged insertion semantics
- `src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx`: explicit local success, unsupported runtime, bootstrap failure, unsynced draft, retry-local UX

Если нужен полный frontend regression run:

```bash
cd ui
pnpm test
```

## Краткий чеклист приёмки

- без env opt-in canonical backend path остаётся primary, а local controls не становятся silently active
- local panel и `Generate locally` могут оставаться видимыми, но должны быть disabled и объяснены, пока runtime не готов
- с env opt-in local mode остаётся отдельной, явно labeled частью UI
- `Prepare WebLLM` запускает lazy bootstrap только по user action
- успешный local result маркируется как `webllm:<model>`
- unsynced draft всё ещё блокирует backend AI path, но может использовать explicit local mode
- retryable backend failure может предлагать `Retry locally with WebLLM`
- insertion semantics не отличаются от backend success path

## Связанные документы

- [local-development.md](./local-development.md)
- [ai-local-setupRU.md](./ai-local-setupRU.md)
- [bedrock-runtime-smokeRU.md](./bedrock-runtime-smokeRU.md)
- [../ai-test-cases.md](../ai-test-cases.md)
- [../plans/06-webllm-local-mode-plan.md](../plans/06-webllm-local-mode-plan.md)
