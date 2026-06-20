# Local Proxy

## 1. Назначение

Локальный `proxy` сервис использует `Nginx` как reverse proxy для маршрутизации запросов к сервисам монорепозитория.

Он нужен для:

- локальных доменов `notebook.com`, `api.notebook.com`, `pgadmin.notebook.com`
- HTTPS в локальной разработке
- проверки сценариев, завязанных на `Secure` cookies и same-origin поведение
- более близкой к production схеме доступа через единый входной proxy

Текущая локальная схема описана в:

- [docker-compose.yaml](../docker-compose.yaml)
- [proxy/Dockerfile](../proxy/Dockerfile)
- [proxy/nginx.conf](../proxy/nginx.conf)

## 2. Как это работает сейчас

В `docker-compose.yaml` сервис `proxy` публикует два локальных порта:

- `8080` для HTTP
- `8443` для HTTPS

Локальные домены:

| Домен | Проксируется в | Внутренний порт сервиса |
|---|---|---|
| `notebook.com` | `frontend` | `5173` |
| `api.notebook.com` | `api` | `8000` |
| `pgadmin.notebook.com` | `pgadmin` | `80` |

Важно: proxy больше не использует `host.docker.internal`.

Сейчас маршрутизация идет по внутренним именам Docker Compose сервисов:

- `frontend:5173`
- `api:8000`
- `pgadmin:80`

Это корректно для текущей конфигурации, потому что все сервисы находятся в одной Compose-сети и Docker сам резолвит их имена.

## 3. Dockerfile proxy

Текущий [proxy/Dockerfile](../proxy/Dockerfile) делает следующее:

1. Берет образ `nginx:alpine`
2. Копирует `nginx.conf` в контейнер
3. Использует сертификаты, примонтированные в `/keys` из локальной директории `proxy/certs/`

`proxy` больше не генерирует TLS-сертификаты внутри образа.

## 4. Текущая конфигурация Nginx

В [proxy/nginx.conf](../proxy/nginx.conf):

- определены upstream для `frontend`, `api` и `pgadmin`
- для каждого локального домена создан отдельный `server`
- каждый `server` слушает:
  - `8080`
  - `8443 ssl`
- используется один и тот же сертификат:
  - `/keys/notebook.com.pem`
  - `/keys/notebook.com-key.pem`

Текущие upstream:

```nginx
upstream app {
  server frontend:5173;
}

upstream api {
  server api:8000;
}

upstream pgadmin {
  server pgadmin:80;
}
```

## 5. Что именно устарело в старой версии документа

Ранее в документе были указаны данные, которые больше не соответствуют проекту:

- домены `training.wiki`, `api.training.wiki`, `pgadmin.training.wiki`
- порты `80/443` вместо текущих `8080/8443`
- upstream через `host.docker.internal`
- сертификаты `training.wiki.pem` и `training.wiki-key.pem`
- ссылки на другой репозиторий

Все это больше не отражает фактическую локальную конфигурацию.

## 6. Что с SSL сейчас

Сейчас ожидаемая dev-схема такая:

- `Nginx` слушает `8443`
- сертификат заранее создается локально через `mkcert`
- сертификат и ключ монтируются в контейнер `proxy`
- браузер устанавливает TLS-соединение

Если `mkcert -install` был выполнен и сертификат выпущен для всех трех доменов, предупреждения браузера быть не должно.

## 7. Рекомендуемая dev-схема сертификатов

В проекте принята схема с одним dev-сертификатом с `SAN`, который покрывает:

- `notebook.com`
- `api.notebook.com`
- `pgadmin.notebook.com`

Предпочтительный вариант для команды:

1. Использовать `mkcert`
2. Один раз установить локальный root CA в систему разработчика
3. Сгенерировать сертификат сразу для всех трех доменов
4. Подключать готовые файлы сертификата в `proxy/certs/`

Пример команды:

```bash
mkcert \
  -cert-file proxy/certs/notebook.com.pem \
  -key-file proxy/certs/notebook.com-key.pem \
  notebook.com api.notebook.com pgadmin.notebook.com
```

Ожидаемые файлы:

- `proxy/certs/notebook.com.pem`
- `proxy/certs/notebook.com-key.pem`

## 8. Практическая рекомендация

Практическая схема для команды:

1. Один раз выполнить `mkcert -install`
2. Сгенерировать сертификат в `proxy/certs/`
3. Не коммитить приватный ключ в репозиторий
4. Монтировать сертификат и ключ в контейнер `proxy` через `docker-compose.yaml`

Итог:

- локальный HTTPS останется
- warning в браузере исчезнет после доверия к локальному CA
- все три домена будут покрыты корректно
