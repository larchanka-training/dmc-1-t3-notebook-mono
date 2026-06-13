# Локальный Запуск

Этот документ описывает актуальную последовательность локального запуска монорепозитория.

## Что нужно заранее

Перед запуском должны быть установлены:

- Docker Desktop
- Git

Проверьте, что Docker запущен:

```bash
docker info
```

Если `docker info` завершается ошибкой, запустите Docker Desktop и дождитесь, пока Docker Engine перейдёт в рабочее состояние.

## Подготовка репозитория

Работайте из ветки `development`:

```bash
git checkout development
```

Инициализируйте submodules:

```bash
git submodule update --init --recursive
```

После этого в репозитории должны быть заполнены директории:

- `ui/`
- `api/`

## Подготовка `.env` файлов

Создайте локальные `.env` файлы из примеров.

Frontend:

```bash
cp ui/.env.example ui/.env
```

После копирования проверьте `ui/.env` и установите:

```text
VITE_API_PROXY_TARGET=http://api:8000
```

Backend:

```bash
cp api/.env.example api/.env
```

Текущие локальные порты:

- frontend внутри контейнера: `5173`
- backend API: `8000`
- PostgreSQL: `5432`

## Настройка hosts

Добавьте локальные домены в `hosts`:

```text
127.0.0.1 notebook.com
127.0.0.1 api.notebook.com
127.0.0.1 pgadmin.notebook.com
```

Примеры:

- macOS / Linux: `/etc/hosts`
- Windows: `C:\Windows\System32\drivers\etc\hosts`

## Подготовка локальных TLS-сертификатов

Локальный `proxy` ожидает готовые сертификаты в директории `proxy/certs/`.

Рекомендуемый способ: `mkcert`.

### 1. Установите `mkcert`

Примеры:

- macOS: `brew install mkcert`
- Windows: через `choco` или `scoop`

### 2. Установите локальный root CA

```bash
mkcert -install
```

### 3. Сгенерируйте сертификат для всех локальных доменов

Из корня репозитория выполните:

```bash
mkcert \
  -cert-file proxy/certs/notebook.com.pem \
  -key-file proxy/certs/notebook.com-key.pem \
  notebook.com api.notebook.com pgadmin.notebook.com
```

После этого должны появиться файлы:

- `proxy/certs/notebook.com.pem`
- `proxy/certs/notebook.com-key.pem`

## Запуск сервисов

Запускайте из корня репозитория:

```bash
chmod +x start-services.sh
./start-services.sh
```

Скрипт:

- проверяет, что существуют `ui`, `api`, `ui/.env` и `api/.env`
- проверяет, что существуют `proxy/certs/notebook.com.pem` и `proxy/certs/notebook.com-key.pem`
- запускает сервисы через `docker compose up -d`

## Какие адреса открывать

После запуска откройте:

- `https://notebook.com:8443`
- `https://api.notebook.com:8443`
- `https://pgadmin.notebook.com:8443`

Если сертификат был создан через `mkcert` и локальный root CA установлен корректно, предупреждения браузера быть не должно.

## Вход в pgAdmin

Для входа в `pgAdmin` используйте учётные данные из `docker-compose.yaml`:

- Email: `admin@example.com`
- Password: `admin123`

Параметры подключения к PostgreSQL внутри `pgAdmin`:

- Host: `postgres`
- Port: `5432`
- Database: `wiki`
- Username: `admin`
- Password: `admin123`

## Полезные команды

Показать контейнеры:

```bash
docker compose ps
```

Посмотреть логи:

```bash
docker compose logs -f
```

Перезапустить отдельный сервис:

```bash
docker compose restart frontend
docker compose restart api
docker compose restart proxy
```

Остановить сервисы:

```bash
./stop-services.sh
```

Остановить проект и удалить project images, кроме `postgres:17` и `pgadmin`:

```bash
./stop-services.sh cleanup
```

Полностью удалить контейнеры, volumes и images:

```bash
./stop-services.sh remove
```

## Что проверять, если что-то не работает

### Docker недоступен

Симптом:

```text
failed to connect to the docker API
```

Что делать:

- запустить Docker Desktop
- дождаться старта Docker Engine
- повторно выполнить `docker info`

### Локальные домены не открываются

Проверьте:

- в `hosts` добавлены все три домена
- контейнер `proxy` запущен
- `docker compose ps`
- `docker compose logs proxy`

### Frontend открывается, но API-запросы не работают

Проверьте:

- в `ui/.env` указан `VITE_API_PROXY_TARGET=http://api:8000`
- `docker compose logs frontend`
- `docker compose logs api`
- `docker compose ps`

### Браузер показывает предупреждение по сертификату

Проверьте:

- выполнялась ли команда `mkcert -install`
- существуют ли файлы в `proxy/certs/`
- сертификат ли выпущен на все три домена:
  - `notebook.com`
  - `api.notebook.com`
  - `pgadmin.notebook.com`
