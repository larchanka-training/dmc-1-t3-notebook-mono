# Работа с Git в монорепозитории

Этот документ описывает рабочий процесс с `git` в текущем монорепозитории, где:

- корневой репозиторий хранит общую инфраструктуру и документацию;
- `api/` подключён как `git submodule`;
- `ui/` подключён как `git submodule`.

## Что важно понимать про структуру

В этом проекте есть три отдельных git-репозитория:

1. корневой репозиторий;
2. репозиторий `api/`;
3. репозиторий `ui/`.

Корневой репозиторий не хранит исходники `api` и `ui` напрямую. Он хранит ссылки на конкретные коммиты submodules.

Это значит:

- изменения внутри `api/` и `ui/` коммитятся в самих submodules;
- после этого в корневом репозитории нужно закоммитить обновлённый указатель на submodule;
- если изменить файлы внутри `api/` или `ui/`, но не обновить root-коммит, коллеги не получат новую привязку автоматически.

## Базовая подготовка репозитория

Клонирование:

```bash
git clone <repo-url>
cd dmc-1-t3-notebook-mono
git submodule update --init --recursive
```

Если репозиторий уже клонирован, но директории `api/` или `ui/` пустые:

```bash
git submodule update --init --recursive
```

Если нужно подтянуть содержимое submodules после переключения ветки в root:

```bash
git submodule update --init --recursive
```

## Ежедневный старт работы

Перед началом работы:

```bash
git status
git submodule status
```

Проверьте:

- нет ли незакоммиченных изменений в root;
- нет ли локальных изменений внутри `api/` и `ui/`;
- на какие коммиты сейчас указывают submodules.

Удобно также смотреть короткий статус:

```bash
git status --short
```

Типичный вывод:

```text
 m api
 M docs/plans/sprints.md
```

Здесь:

- `M docs/...` означает изменение файла в корневом репозитории;
- `m api` означает, что внутри submodule `api/` есть незакоммиченные изменения или указатель submodule отличается от зафиксированного состояния.

## Основное правило работы

Всегда разделяйте два уровня изменений:

1. изменения внутри `api/` или `ui/`;
2. изменение ссылки на submodule в корневом репозитории.

Если задача касается backend:

- обычно работа идёт в `api/`;
- затем фиксируется новый указатель `api` в root.

Если задача касается frontend:

- обычно работа идёт в `ui/`;
- затем фиксируется новый указатель `ui` в root.

Если задача касается документации, `docker-compose`, прокси, CI или общих файлов:

- работа идёт в root;
- submodules можно не трогать, если это не требуется задачей.

## Рекомендуемый workflow для задачи в `api/` или `ui/`

### 1. Убедитесь, что root-репозиторий в нужной ветке

```bash
git checkout <root-branch>
git pull
git submodule update --init --recursive
```

### 2. Перейдите в нужный submodule

Backend:

```bash
cd api
```

Frontend:

```bash
cd ui
```

### 3. Проверьте ветку и создайте рабочую ветку при необходимости

```bash
git status
git branch --show-current
git checkout -b <feature-branch>
```

Если нужная ветка уже существует:

```bash
git checkout <feature-branch>
```

### 4. Внесите изменения и закоммитьте их внутри submodule

```bash
git status
git add <files>
git commit -m "feat: describe change"
```

При необходимости отправьте ветку:

```bash
git push -u origin <feature-branch>
```

### 5. Вернитесь в root и зафиксируйте новый указатель submodule

```bash
cd ..
git status
git add api
git commit -m "chore: update api submodule pointer"
```

Для `ui`:

```bash
git add ui
git commit -m "chore: update ui submodule pointer"
```

Если вместе с этим менялись файлы в root, добавьте их в тот же коммит только если это логически одна задача.

## Workflow для изменений только в root

Если задача касается только root-репозитория:

```bash
git checkout -b <feature-branch>
git add <files>
git commit -m "docs: add git workflow guide"
```

В таком случае не нужно делать `git add api` или `git add ui`, если вы не меняли их указатели осознанно.

## Как понять, что именно изменилось в submodule

Проверка статуса submodules:

```bash
git submodule status
```

Проверка изменений внутри `api/`:

```bash
git -C api status
git -C api log --oneline --decorate -n 10
```

Проверка изменений внутри `ui/`:

```bash
git -C ui status
git -C ui log --oneline --decorate -n 10
```

Если root показывает изменение `api` или `ui`, полезно посмотреть, на какой коммит сдвинулся указатель:

```bash
git diff --submodule
```

## Когда нужен коммит в root

Коммит в root нужен, если:

- изменились файлы самого root-репозитория;
- изменился коммит submodule `api`;
- изменился коммит submodule `ui`.

Коммит в root не заменяет коммит внутри `api/` или `ui/`.

Неправильно:

- изменить код в `api/`;
- не сделать коммит в `api/`;
- сделать только `git add api` в root.

В этом случае root не сможет сослаться на новый стабильный коммит submodule.

## Как обновить submodule до актуального состояния

Если в root уже обновили указатель submodule, заберите изменения так:

```bash
git pull
git submodule update --init --recursive
```

Если нужно вручную получить latest changes внутри submodule для локальной работы, делайте это осознанно:

```bash
git -C api fetch
git -C api checkout <branch-or-commit>
```

или:

```bash
git -C ui fetch
git -C ui checkout <branch-or-commit>
```

После такого переключения root почти наверняка покажет изменение submodule. Это нормально, если вы действительно готовите обновление указателя.

## Типовые сценарии

### Изменения только в `api/`

```bash
cd api
git checkout -b feature/notebook-endpoint
git add .
git commit -m "feat: add notebook list endpoint"
git push -u origin feature/notebook-endpoint

cd ..
git add api
git commit -m "chore: update api submodule pointer"
```

### Изменения только в `ui/`

```bash
cd ui
git checkout -b feature/notebook-toolbar
git add .
git commit -m "feat: add notebook toolbar"
git push -u origin feature/notebook-toolbar

cd ..
git add ui
git commit -m "chore: update ui submodule pointer"
```

### Изменения в `api/` и документации root

```bash
cd api
git add .
git commit -m "feat: add notebook sync endpoint"
git push

cd ..
git add api docs/some-file.md
git commit -m "docs: align root docs with notebook sync flow"
```

## Частые ошибки

### Ошибка 1. Изменения внутри submodule есть, а root-коммит не обновлён

Симптом:

```text
 m api
```

Что это значит:

- внутри `api/` есть изменения;
- либо submodule сдвинут на другой коммит;
- root ещё не зафиксировал новое состояние.

Что делать:

1. проверить `git -C api status`;
2. закоммитить изменения в `api/` при необходимости;
3. выполнить `git add api` в root;
4. сделать root-коммит.

### Ошибка 2. Сделан коммит в root, но нет коммита в submodule

Симптом:

- root показывает изменение `api` или `ui`;
- внутри submodule есть незакоммиченные файлы.

Что делать:

1. зайти в submodule;
2. сделать коммит там;
3. вернуться в root и обновить указатель.

### Ошибка 3. После `git checkout` в root директории `api/` или `ui/` выглядят "сломано"

Обычно это значит, что root переключился на ветку с другими указателями submodules.

Исправление:

```bash
git submodule update --init --recursive
```

### Ошибка 4. Случайно включили в root-коммит изменение submodule

Перед коммитом проверяйте:

```bash
git status
git diff --submodule
```

Если задача не предполагала изменение `api` или `ui`, не добавляйте submodule в staging.

## Минимальный набор команд

Ежедневно чаще всего нужны:

```bash
git status
git submodule status
git submodule update --init --recursive
git -C api status
git -C ui status
git diff --submodule
```

## Практическое правило для команды

Для каждой задачи явно определяйте, где именно должны появиться коммиты:

- только в root;
- в `api` и затем в root;
- в `ui` и затем в root;
- в `api`, `ui` и root.

Это снижает риск:

- потерять изменения внутри submodule;
- закоммитить случайный pointer update;
- открыть PR, в котором непонятно, где лежит фактическое изменение.
