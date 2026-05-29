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
| Модель поставки приложения | `Hosted web application with local-first behavior` | Продукт работает в браузере, выполняет код client-side и использует server-side слой для управления, хранения и интеграций |
| Язык frontend | `TypeScript` | Основной язык реализации frontend |
| Framework frontend | `React` | Пользовательский интерфейс notebook |
| Build tool frontend | `Vite` | Development server и build pipeline frontend |
| Язык backend | `Python 3.12+` | Основной язык реализации backend |
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
| Метод аутентификации | `Email + OTP`, `Google OAuth` | Sign-in flows для Version 1 |
| Browser-side auth state | `Secure HTTP-only session cookie` | Браузерное auth-state управляется через backend session |
| Внешний identity provider | `Google OAuth` | Сторонний browser sign-in |
| Путь доступа к AI | `Backend-mediated LLM access` | LLM-запросы проходят через backend |

## 3. Frontend Stack

Подтвержденный frontend stack:

- `React 18`
- `TypeScript 5.6`
- `Vite 8`
- `Zustand 5` (глобальное состояние, slice composition pattern)
- `TanStack React Query 5` (server state)
- `React Router v7` (client-side routing, `createBrowserRouter`)
- `shadcn/ui` + `Radix UI` + `Tailwind CSS 3` (component layer)
- `Zod 4` (schema validation)
- `CodeMirror 6` через `@uiw/react-codemirror` (редактор кодовых блоков)
- `Dexie 4` (обёртка над IndexedDB)
- `Recharts` (графики)
- `lucide-react` (иконки)
- `pnpm` (пакетный менеджер)
- `Vitest 4` + `React Testing Library` (unit и component тесты)
- `MSW 2` (мокирование API в тестах)
- `Playwright 1.54` (end-to-end тесты)
- `steiger` (линтинг FSD-архитектуры)

Frontend отвечает за:

- browser-delivered application shell
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

- `Python 3.12+`
- `FastAPI`
- `Pydantic v2` и `Pydantic Settings`
- `SQLAlchemy 2.0 ORM` (async engine, стиль `select()`)
- `Alembic` (миграции схемы)
- `psycopg (binary) v3` (async-драйвер для PostgreSQL 16)
- `Uvicorn`
- `PostgreSQL 16`
- `pytest` + `FastAPI TestClient` (backend тесты)

Backend отвечает за:

- аутентификацию
- выдачу и проверку OTP
- обработку Google OAuth
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
- delivery surface приложения: browser-hosted web application

Execution runtime остается отдельной архитектурной частью, даже при client-side размещении.

## 7. Authentication и security technologies

Подтвержденные решения по аутентификации и безопасности:

- способы входа: `Email + OTP`, `Google OAuth`
- аутентифицированное browser-state после входа через email или Google: backend-managed secure `HTTP-only` session cookie
- доставка OTP: внешний email delivery service
- внешний identity provider: `Google OAuth`
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

Подтвержденная quality и development foundation включает:

- frontend linting через `ESLint`; FSD-архитектурный линтинг через `steiger`
- frontend unit и component тесты с `Vitest 4` + `React Testing Library`
- мокирование API в frontend-тестах через `MSW 2`
- end-to-end тесты с `Playwright 1.54`
- backend тесты с `pytest` + `FastAPI TestClient`
- backend API self-documentation через FastAPI OpenAPI

CI/CD tooling пока не зафиксирован (см. Раздел 11).

## 11. Отложенные технологические решения

Следующие технологические выборы пока не зафиксированы в этом документе:

| Область | Возможные варианты | Рекомендуемая отправная точка для разбора |
|---|---|---|
| Rich text editing | обычный `Markdown` textarea, `TipTap`, `Lexical` | обычный `Markdown` textarea для Version 1 |
| Background jobs | отсутствие отдельного job layer, `FastAPI BackgroundTasks`, `RQ`, `Dramatiq`, `Celery` | без отдельной job-system или `FastAPI BackgroundTasks` для Version 1 |
| Email provider | `AWS SES`, `Resend`, `Postmark`, `SendGrid`, `Mailgun` | `AWS SES` или `Resend` |
| LLM provider | `OpenAI`, `Anthropic`, `AWS Bedrock`, `OpenRouter` | один основной provider за backend adapter |
| CI/CD tooling | `GitHub Actions`, Docker image build pipeline, registry-based deploy pipeline, Terraform apply pipeline | `GitHub Actions` как основной CI/CD orchestrator |

Эти решения должны быть зафиксированы позже в repo-specific архитектурных документах или ADR.

## 12. Связанные документы

- [project.md](./project.md)
- [projectRU.md](./projectRU.md)
- [system_architectureRU.md](./system_architectureRU.md)
- [Local-Proxy.md](./Local-Proxy.md)
