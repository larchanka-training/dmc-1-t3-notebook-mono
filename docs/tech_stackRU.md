# Технологический стек

## 1. Назначение

Этот документ фиксирует подтвержденный технологический стек проекта на системном уровне.

В нем описываются:

- технологии, уже выбранные для проекта
- роль каждой выбранной технологии
- технологические границы между frontend, backend, storage, runtime и integrations
- технологические решения, которые пока осознанно не зафиксированы

## 2. Стек проекта на общем уровне

| Область | Технология | Роль |
|---|---|---|
| Язык frontend | `TypeScript` | Основной язык реализации frontend |
| Framework frontend | `React` | Пользовательский интерфейс notebook |
| Build tool frontend | `Vite` | Development server и build pipeline frontend |
| Язык backend | `Python 3.11+` | Основной язык реализации backend |
| Framework backend | `FastAPI` | HTTP API слой |
| Конфигурация backend | `Pydantic Settings` | Конфигурация через окружение |
| Сервер backend | `Uvicorn` | ASGI application server |
| База данных | `PostgreSQL` | Долговременное server-side хранилище |
| Локальная персистентность | `IndexedDB` | Browser-side persistent working copy |
| Reverse proxy | `Nginx` | Локальный HTTPS и маршрутизация локальных доменов |
| Локальная оркестрация | `Docker Compose` | Локальный запуск нескольких сервисов |
| Администрирование БД | `pgAdmin` | Локальный просмотр и администрирование базы данных |
| Формат notebook-контента | `JSON` | Канонический формат хранения и синхронизации notebook |
| Формат text block | `Markdown` | Формат контента текстовых блоков |
| Формат code block | `JavaScript` | Формат исполняемого notebook-кода |
| Формат API-обмена | `HTTP + JSON` | Коммуникация между frontend и backend |
| Метод аутентификации | `Email + OTP` | Sign-in flow для Version 1 |
| Browser-side auth state | `Secure HTTP-only session cookie` | Браузерное auth-state управляется через backend session |
| Путь доступа к AI | `Backend-mediated LLM access` | LLM-запросы проходят через backend |

## 3. Frontend Stack

Подтвержденный frontend stack:

- `React`
- `TypeScript`
- `Vite`

Frontend отвечает за:

- notebook UI
- редактирование блоков
- execution UI
- sync UI
- AI request UI
- интеграцию с локальной персистентностью

Frontend также владеет:

- активной рабочей копией notebook во время редактирования
- browser-side локальной персистентностью
- client-side execution orchestration

## 4. Backend Stack

Подтвержденный backend stack:

- `Python 3.11+`
- `FastAPI`
- `Pydantic Settings`
- `Uvicorn`
- `PostgreSQL`

Backend отвечает за:

- аутентификацию
- выдачу и проверку OTP
- персистентность notebook
- sync endpoints
- access control
- AI integration endpoints
- health и operational endpoints

## 5. Persistence и форматы данных

Подтвержденные решения по persistence и data formats:

- долговременное server-side хранилище: `PostgreSQL`
- browser-side локальная персистентность: `IndexedDB`
- формат notebook: структурированный `JSON`
- формат text block: `Markdown`
- формат code block: исполняемый `JavaScript`
- формат synchronization payload: `JSON`
- формат экспорта для Version 1: переносимый notebook `JSON`

## 6. Runtime и execution technologies

Подтвержденные технологические решения по выполнению:

- исполняемый notebook-язык: `JavaScript`
- location выполнения для Version 1: `client-side`
- location execution control: `frontend-side execution orchestrator`

Execution runtime остается отдельной архитектурной частью, даже при client-side размещении.

## 7. Authentication и security technologies

Подтвержденные решения по аутентификации и безопасности:

- способ входа: `Email + OTP`
- аутентифицированное browser-state: backend-managed secure `HTTP-only` session cookie
- доставка OTP: внешний email delivery service
- применение access control: backend-side
- credentials AI-провайдера: backend-side
- уровень доверия к notebook-коду: untrusted
- уровень доверия к AI-сгенерированному коду: untrusted

## 8. AI integration technologies

Подтвержденные решения по AI-интеграции:

- AI requests инициируются из frontend
- доступ к AI provider идет через backend
- AI возвращает код для выбранного notebook-блока
- возвращенный AI-код после вставки становится обычным редактируемым notebook-контентом

Это означает, что в Version 1 проект не использует прямой browser-to-provider доступ к LLM.

## 9. Инструменты локальной разработки

Подтвержденный tooling для локальной разработки:

- `Docker Compose`
- `Nginx`
- `PostgreSQL`
- `pgAdmin`

Локальные домены:

- `notebook.com`
- `api.notebook.com`
- `pgadmin.notebook.com`

## 10. Quality и development foundation

Сейчас в проекте уже есть следующая development foundation:

- frontend linting через `ESLint`
- backend test foundation через `Pytest`
- backend API self-documentation через FastAPI OpenAPI

Это часть текущего foundation, но это еще не весь итоговый testing и CI/CD stack.

## 11. Отложенные технологические решения

Следующие технологические выборы пока не зафиксированы в этом документе:

| Область | Возможные варианты | Рекомендуемая отправная точка для разбора |
|---|---|---|
| Управление состоянием frontend | `React Context + useReducer`, `Zustand`, `Redux Toolkit`, `TanStack Query` только для server state | `Zustand` для состояния notebook editor; `TanStack Query` добавлять только при росте сложности server state |
| Frontend routing | `React Router`, `TanStack Router`, минимальный первый slice без роутинга | `React Router` |
| UI component layer | custom components с design tokens, `shadcn/ui`, `MUI`, `Chakra UI` | custom components плюс выборочное использование `shadcn/ui` primitives |
| Charting library | `Recharts`, `Apache ECharts`, `Chart.js`, `Observable Plot` | `Recharts` для простых charts в Version 1 |
| Rich text editing | обычный `Markdown` textarea, `TipTap`, `Lexical` | обычный `Markdown` textarea для Version 1 |
| Backend data access | `SQLAlchemy ORM`, `SQLAlchemy Core`, `SQLModel` | `SQLAlchemy ORM` или `SQLAlchemy Core` |
| Migration tool | `Alembic`, raw SQL migrations, `yoyo-migrations` | `Alembic` |
| Background jobs | отсутствие отдельного job layer, `FastAPI BackgroundTasks`, `RQ`, `Dramatiq`, `Celery` | без отдельной job-system или `FastAPI BackgroundTasks` для Version 1 |
| Email provider | `AWS SES`, `Resend`, `Postmark`, `SendGrid`, `Mailgun` | `AWS SES` или `Resend` |
| LLM provider | `OpenAI`, `Anthropic`, `AWS Bedrock`, `OpenRouter` | один основной provider за backend adapter |
| Frontend test stack | `Vitest + React Testing Library`, `Playwright`, `Cypress`, смешанный stack | `Vitest + React Testing Library` плюс небольшой `Playwright` smoke layer |
| CI/CD tooling | `GitHub Actions`, Docker image build pipeline, registry-based deploy pipeline, Terraform apply pipeline | `GitHub Actions` как основной CI/CD orchestrator |

Эти решения должны быть зафиксированы позже в repo-specific архитектурных документах или ADR.

## 12. Связанные документы

- [project.md](./project.md)
- [projectRU.md](./projectRU.md)
- [system_architectureRU.md](./system_architectureRU.md)
- [Local-Proxy.md](./Local-Proxy.md)
