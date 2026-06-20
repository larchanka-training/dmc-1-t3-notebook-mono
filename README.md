# Монорепозиторий проекта

Этот репозиторий содержит все основные сервисы проекта (Frontend, Backend, База данных, pgAdmin, reverse-proxy и др.) и предоставляет удобный способ локального запуска через Docker.

Для работы необходим установленный **Docker** (или Docker Desktop).
## AI Agent Configuration

- [AGENTS.md](./AGENTS.md) — bootstrap entry point and execution policy for AI agents (required reading order, source-of-truth precedence, mandatory rules).
- [CLAUDE.md](./CLAUDE.md) — Claude-specific agent entry point; references `AGENTS.md` for all execution context.
- [docs/guides/local-development.md](./docs/guides/local-development.md) — актуальная инструкция по локальному запуску: Docker Desktop, submodules, `.env`, hosts и URL сервисов.
---

# Зачем это всё нужно

### Docker — одинаковая среда у всей команды

Все сервисы запускаются в контейнерах, что гарантирует одинаковую конфигурацию у всех разработчиков и исключает проблемы «работает у меня / не работает у тебя».

### Локальные домены (notebook.com и поддомены)

Используются для:
- корректной работы cookies (особенно **SameSite**, secure cookies),
- корректной работы OAuth / redirect-URL,
- настройки reverse-proxy через виртуальные хосты,
- эмуляции production-инфраструктуры.

### HTTPS даже локально

Самоподписанный сертификат позволяет использовать:
- secure cookies,
- сервис-воркеры,
- API, требующие https,
- корректную работу auth-процессов.

Браузер предупредит, что сертификат небезопасный — это нормально для dev. Нужно нажать **Advanced → Continue anyway**.

---

# Настройка локальных доменов

Чтобы `notebook.com`, `api.notebook.com` и `pgadmin.notebook.com` открывались локально, добавьте в файл hosts:

```
127.0.0.1 notebook.com
127.0.0.1 api.notebook.com
127.0.0.1 pgadmin.notebook.com
```

## Как изменить `hosts`

### macOS / Linux:

`sudo nano /etc/hosts`

### Windows:

Открыть блокнот от имени администратора → файл:  
`C:\Windows\System32\drivers\etc\hosts`

После изменений желательно перезагрузить DNS-кэш (например, `ipconfig /flushdns` на Windows).

---

# Запуск проекта локально

Актуальная последовательность локального запуска вынесена в отдельный документ:

- [docs/guides/local-development.md](./docs/guides/local-development.md)

Короткая версия:

```bash
git submodule update --init --recursive
cp ui/.env.example ui/.env
cp api/.env.example api/.env
chmod +x start-services.sh
./start-services.sh
```

После копирования проверьте, что в `ui/.env` указано:

```text
VITE_API_PROXY_TARGET=http://api:8000
```

## Остановка сервисов

Для остановки и очистки используйте:

```bash
./stop-services.sh
./stop-services.sh cleanup
./stop-services.sh remove
```

---

# Доступные адреса после запуска

- **[https://notebook.com:8443](https://notebook.com:8443/)** — фронтенд
- **[https://api.notebook.com:8443](https://api.notebook.com:8443/)** — API
- **[https://pgadmin.notebook.com:8443](https://pgadmin.notebook.com:8443/)** — веб-интерфейс PostgreSQL

При первом заходе может появиться предупреждение о сертификате — это ожидаемо.

---

# Предупреждение о самоподписанном сертификате

Браузер покажет сообщение о небезопасном соединении.  
Можно смело нажимать:

**Advanced → Continue to site / Всё равно перейти**

Это типично для локальной разработки.

Если хотите полноценный dev-https без предупреждений — используйте `mkcert` для генерации доверенного локального сертификата (можно добавить инструкции).

---

# Полезные команды

### Просмотр контейнеров

`docker compose ps`

### Логи сервисов

`docker compose logs -f`

### Остановка всех сервисов

`./stop-services.sh`

### Пересборка

`docker compose up -d --build`

---

# Возможные проблемы и решения

### ❗ Сайт не открывается

Проверьте:
- hosts-файл,
- что контейнеры запущены (`docker ps`),
- логи (`docker compose logs`).

### ❗ Порт занят

Узнайте, кто его использует: `lsof -i :80 lsof -i :443`

или на Windows: `netstat -a -b`

### ❗ Предупреждение о сертификате

Это нормально. Нажмите «Continue».  
Чтобы убрать предупреждения — используйте `mkcert`.

### ❗ frontend или backend не запустились

Проверьте:
- что подтянуты `ui` и `api` submodules,
- что существуют `ui/.env` и `api/.env`,
- логи `docker compose logs frontend api proxy`.
