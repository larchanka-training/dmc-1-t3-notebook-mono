# Использование поддомена `t3.jsnb.org` для проекта другой команды

Дата подготовки: 20 июня 2026

## 1. Контекст задачи

У нас есть домен:

```text
jsnb.org
```

Домен куплен и управляется в Cloudflare. Основной проект уже размещён в AWS и может использовать связку вида:

```text
Cloudflare DNS -> CloudFront -> ALB -> ECS / Backend / Frontend
```

Другая команда хочет использовать поддомен третьего уровня:

```text
t3.jsnb.org
```

Главный вопрос: как направить `t3.jsnb.org` на их проект в AWS, не задевая основной проект на `jsnb.org` и другие ваши поддомены.

Короткий ответ: это можно сделать безопасно. DNS-запись для `t3.jsnb.org` независима от записей для `jsnb.org`, `www.jsnb.org`, `api.jsnb.org`, `app.jsnb.org` и других имён, если не менять их записи и аккуратно проверить wildcard-записи.

---

## 2. Базовая идея DNS

DNS-зона `jsnb.org` может содержать много отдельных записей:

```text
jsnb.org          -> ваш основной проект
www.jsnb.org      -> ваш frontend / CloudFront
api.jsnb.org      -> ваш backend / ALB / API Gateway
t3.jsnb.org       -> проект другой команды
```

Каждая запись работает отдельно. Добавление записи `t3` не должно менять поведение основной записи `jsnb.org`.

В Cloudflare запись обычно создаётся так:

```text
Type: CNAME
Name: t3
Target: <AWS endpoint другой команды>
Proxy status: DNS only или Proxied
```

Итоговый hostname будет:

```text
t3.jsnb.org
```

---

## 3. Главные варианты архитектуры

Есть три основных варианта.

| Вариант | Суть | Когда выбирать |
|---|---|---|
| Вариант A | Одна CNAME-запись `t3` в Cloudflare на их CloudFront | Лучший стартовый вариант, если нужен только `t3.jsnb.org` |
| Вариант B | Одна CNAME-запись `t3` в Cloudflare на их ALB | Если у другой команды нет CloudFront и они публикуют проект напрямую через ALB |
| Вариант C | Делегировать `t3.jsnb.org` через NS-записи в их Route 53 | Если им нужно самостоятельно управлять `api.t3.jsnb.org`, `admin.t3.jsnb.org`, `preview.t3.jsnb.org` и т.д. |

Рекомендация для первого этапа: начать с варианта A или B, то есть с одной CNAME-записи. Делегирование через NS лучше делать только если другой команде реально нужна автономия в DNS.

---

# 4. Вариант A — `t3.jsnb.org` ведёт на CloudFront другой команды

## 4.1. Схема

```text
Пользователь
  |
  v
https://t3.jsnb.org
  |
  v
Cloudflare DNS
  |
  v
CNAME t3 -> dxxxxxxxxxxxxx.cloudfront.net
  |
  v
CloudFront другой команды
  |
  v
ALB / S3 / ECS / frontend / backend другой команды
```

## 4.2. Что остаётся у вас

Вы сохраняете контроль над DNS-зоной `jsnb.org` в Cloudflare.

Вы добавляете только одну запись:

```text
CNAME t3 -> dxxxxxxxxxxxxx.cloudfront.net
```

Вы не трогаете:

```text
jsnb.org
www.jsnb.org
api.jsnb.org
app.jsnb.org
```

## 4.3. Что должна сделать другая команда

Другая команда должна настроить свой CloudFront так, чтобы он принимал запросы для hostname:

```text
t3.jsnb.org
```

В CloudFront это называется Alternate domain name / CNAME.

Также им нужен SSL/TLS-сертификат для:

```text
t3.jsnb.org
```

Важный момент: если сертификат используется с CloudFront, ACM-сертификат должен быть создан или импортирован в регионе:

```text
us-east-1 / US East (N. Virginia)
```

Это требование AWS CloudFront.

## 4.4. Пошаговая карта для варианта A

### Шаг 1. Другая команда готовит CloudFront

Они создают или используют существующую CloudFront Distribution.

В настройках CloudFront добавляют:

```text
Alternate domain name:
t3.jsnb.org
```

### Шаг 2. Другая команда запрашивает ACM-сертификат

В AWS Certificate Manager они запрашивают сертификат:

```text
Domain name:
t3.jsnb.org

Region:
us-east-1
```

Validation method лучше выбрать DNS validation.

### Шаг 3. Они присылают вам DNS validation record

Они пришлют CNAME-запись примерно такого вида:

```text
Type: CNAME
Name: _abc123.t3.jsnb.org
Value: _xyz987.acm-validations.aws
```

Или Cloudflare может попросить ввести `Name` как:

```text
_abc123.t3
```

Зависит от интерфейса Cloudflare.

### Шаг 4. Вы добавляете validation-запись в Cloudflare

В Cloudflare:

```text
Type: CNAME
Name: _abc123.t3
Target: _xyz987.acm-validations.aws
Proxy status: DNS only
```

Важно: validation-запись должна быть DNS only, не Proxied.

### Шаг 5. Другая команда ждёт выпуск сертификата

После появления DNS validation record AWS ACM подтверждает домен и выпускает сертификат.

### Шаг 6. Другая команда прикрепляет сертификат к CloudFront

В CloudFront они выбирают выпущенный ACM-сертификат для `t3.jsnb.org`.

### Шаг 7. Они присылают вам CloudFront domain name

Например:

```text
d123456abcdef8.cloudfront.net
```

### Шаг 8. Вы создаёте основную DNS-запись

В Cloudflare:

```text
Type: CNAME
Name: t3
Target: d123456abcdef8.cloudfront.net
Proxy status: DNS only на первом этапе
TTL: Auto
```

### Шаг 9. Проверка

Проверить DNS:

```bash
dig t3.jsnb.org
```

Проверить HTTPS:

```bash
curl -I https://t3.jsnb.org
```

Проверить сертификат:

```bash
openssl s_client -connect t3.jsnb.org:443 -servername t3.jsnb.org </dev/null
```

Ожидаемый результат:

```text
certificate должен быть выдан для t3.jsnb.org
HTTP должен отвечать от проекта другой команды
ваш jsnb.org не должен измениться
```

## 4.5. Плюсы варианта A

- Хорошо подходит для production.
- CloudFront даёт CDN, HTTPS, кеширование, защиту на уровне edge.
- У другой команды остаётся контроль над своим AWS-проектом.
- Вы сохраняете контроль над DNS-зоной `jsnb.org`.
- Минимальный риск задеть основной проект.

## 4.6. Минусы варианта A

- Нужна корректная настройка сертификата в `us-east-1`.
- Другая команда не сможет сама создавать `api.t3.jsnb.org`, `admin.t3.jsnb.org` и другие записи без вашего участия, если не делать delegation.
- Если включить Cloudflare Proxied поверх CloudFront, может появиться дополнительная сложность с TLS, кешированием и headers.

---

# 5. Вариант B — `t3.jsnb.org` ведёт напрямую на ALB другой команды

## 5.1. Схема

```text
Пользователь
  |
  v
https://t3.jsnb.org
  |
  v
Cloudflare DNS
  |
  v
CNAME t3 -> their-alb.region.elb.amazonaws.com
  |
  v
Application Load Balancer другой команды
  |
  v
ECS / EC2 / backend / frontend другой команды
```

## 5.2. Когда выбирать этот вариант

Этот вариант подходит, если у другой команды нет CloudFront и входной точкой проекта является ALB.

Например:

```text
ALB -> ECS service -> контейнеры приложения
```

## 5.3. Что должна сделать другая команда

Они должны настроить HTTPS listener на своём ALB:

```text
Listener: 443 HTTPS
Certificate: t3.jsnb.org
Target group: их ECS / EC2 / backend
```

Для ALB сертификат ACM должен быть в том же AWS-регионе, что и сам Load Balancer.

Например, если ALB находится в:

```text
eu-central-1
```

то и сертификат ACM для ALB должен быть в:

```text
eu-central-1
```

## 5.4. Пошаговая карта для варианта B

### Шаг 1. Другая команда готовит ALB

У них должен быть ALB с DNS-name вида:

```text
my-alb-123456.eu-central-1.elb.amazonaws.com
```

### Шаг 2. Другая команда запрашивает ACM-сертификат

В регионе ALB они запрашивают сертификат:

```text
Domain name:
t3.jsnb.org

Region:
тот же регион, где ALB
```

Validation method: DNS validation.

### Шаг 3. Они присылают вам DNS validation CNAME

Пример:

```text
Type: CNAME
Name: _abc123.t3.jsnb.org
Value: _xyz987.acm-validations.aws
```

### Шаг 4. Вы добавляете validation record в Cloudflare

```text
Type: CNAME
Name: _abc123.t3
Target: _xyz987.acm-validations.aws
Proxy status: DNS only
```

### Шаг 5. Они выпускают сертификат и прикрепляют его к ALB

В ALB listener `443 HTTPS` они выбирают ACM-сертификат для `t3.jsnb.org`.

### Шаг 6. Они присылают ALB DNS name

Например:

```text
my-alb-123456.eu-central-1.elb.amazonaws.com
```

### Шаг 7. Вы создаёте CNAME в Cloudflare

```text
Type: CNAME
Name: t3
Target: my-alb-123456.eu-central-1.elb.amazonaws.com
Proxy status: DNS only на первом этапе
TTL: Auto
```

### Шаг 8. Проверка

```bash
dig t3.jsnb.org
curl -I https://t3.jsnb.org
openssl s_client -connect t3.jsnb.org:443 -servername t3.jsnb.org </dev/null
```

## 5.5. Плюсы варианта B

- Простая схема без CloudFront.
- Хорошо подходит для backend/API-сервиса.
- Меньше CDN-логики и кеширования.
- Вы сохраняете контроль над DNS.

## 5.6. Минусы варианта B

- Нет CDN-слоя CloudFront.
- ALB напрямую открыт в интернет.
- Нужно аккуратно настроить security groups, HTTPS, redirect HTTP -> HTTPS.
- Если frontend статический, CloudFront часто удобнее.

---

# 6. Вариант C — делегировать `t3.jsnb.org` в Route 53 другой команды

## 6.1. Схема

```text
Cloudflare управляет parent zone:
jsnb.org

В Cloudflare создаются NS-записи:
t3.jsnb.org -> nameservers Route 53 другой команды

Route 53 другой команды управляет child zone:
t3.jsnb.org
```

После этого другая команда сама может создавать:

```text
t3.jsnb.org
api.t3.jsnb.org
app.t3.jsnb.org
admin.t3.jsnb.org
preview.t3.jsnb.org
*.t3.jsnb.org
```

## 6.2. Когда выбирать этот вариант

Delegation нужен, если другой команде требуется самостоятельное управление DNS внутри `t3.jsnb.org`.

Например, если у них будут:

```text
api.t3.jsnb.org
admin.t3.jsnb.org
assets.t3.jsnb.org
preview-123.t3.jsnb.org
dev.t3.jsnb.org
staging.t3.jsnb.org
```

Если им нужен только один адрес `t3.jsnb.org`, delegation избыточен.

## 6.3. Что делает другая команда

Они создают в Route 53 Public Hosted Zone:

```text
t3.jsnb.org
```

Route 53 выдаёт им 4 NS-сервера примерно такого вида:

```text
ns-111.awsdns-01.com
ns-222.awsdns-02.net
ns-333.awsdns-03.org
ns-444.awsdns-04.co.uk
```

Они присылают вам эти NS-сервера.

## 6.4. Что делаете вы в Cloudflare

В зоне `jsnb.org` вы создаёте NS-записи:

```text
Type: NS
Name: t3
Value: ns-111.awsdns-01.com

Type: NS
Name: t3
Value: ns-222.awsdns-02.net

Type: NS
Name: t3
Value: ns-333.awsdns-03.org

Type: NS
Name: t3
Value: ns-444.awsdns-04.co.uk
```

После этого запросы к `t3.jsnb.org` и всему, что ниже, будут обслуживаться Route 53 другой команды.

## 6.5. Пошаговая карта для варианта C

### Шаг 1. Согласовать границы ответственности

Нужно письменно зафиксировать:

```text
Владелец parent domain jsnb.org: ваша команда
Владелец child zone t3.jsnb.org: другая команда
```

Другая команда получает контроль только над:

```text
t3.jsnb.org
*.t3.jsnb.org
```

Они не получают контроль над:

```text
jsnb.org
www.jsnb.org
api.jsnb.org
app.jsnb.org
```

### Шаг 2. Другая команда создаёт hosted zone

В AWS Route 53:

```text
Create hosted zone
t3.jsnb.org
Type: Public hosted zone
```

### Шаг 3. Они присылают вам NS records

Пример:

```text
ns-111.awsdns-01.com
ns-222.awsdns-02.net
ns-333.awsdns-03.org
ns-444.awsdns-04.co.uk
```

### Шаг 4. Вы добавляете NS records в Cloudflare

В DNS-зоне `jsnb.org`:

```text
NS t3 -> ns-111.awsdns-01.com
NS t3 -> ns-222.awsdns-02.net
NS t3 -> ns-333.awsdns-03.org
NS t3 -> ns-444.awsdns-04.co.uk
```

### Шаг 5. Проверить делегирование

```bash
dig NS t3.jsnb.org
```

Ожидаемый результат: должны вернуться NS-сервера Route 53.

### Шаг 6. Другая команда создаёт записи в своей Route 53 зоне

Например:

```text
t3.jsnb.org          -> CloudFront / ALB
api.t3.jsnb.org      -> ALB / API Gateway
admin.t3.jsnb.org    -> CloudFront
```

### Шаг 7. Другая команда сама выпускает ACM-сертификаты

Для CloudFront:

```text
ACM region: us-east-1
Certificate: t3.jsnb.org или *.t3.jsnb.org
```

Для ALB:

```text
ACM region: регион ALB
Certificate: t3.jsnb.org или api.t3.jsnb.org
```

Поскольку DNS-зона `t3.jsnb.org` уже у них в Route 53, они смогут сами добавлять DNS validation records.

## 6.6. Плюсы варианта C

- Максимальная автономия другой команды.
- Они сами управляют всеми DNS-записями внутри `t3.jsnb.org`.
- Вам не нужно каждый раз добавлять им новые DNS records.
- Удобно для preview environments и большого количества поддоменов.

## 6.7. Минусы варианта C

- Вы отдаёте другой команде больше контроля.
- Если они ошибутся в своей зоне, проблема будет на `t3.jsnb.org` и всех его поддоменах.
- Нужно чётко оформить ответственность.
- Не стоит делать delegation, если нужен только один hostname.

---

# 7. Cloudflare DNS only или Proxied

У Cloudflare для A/AAAA/CNAME-записей есть два режима:

```text
DNS only
Proxied
```

## 7.1. DNS only

В режиме DNS only Cloudflare только отвечает на DNS-запрос и возвращает адрес назначения.

```text
Пользователь -> DNS Cloudflare -> AWS endpoint
```

Трафик HTTPS идёт напрямую в AWS.

### Плюсы DNS only

- Проще отладка.
- Меньше риска конфликтов TLS.
- AWS сам отвечает за сертификаты, HTTPS, кеширование, WAF.
- Хороший вариант для первого подключения.

### Минусы DNS only

- Трафик не проходит через Cloudflare WAF.
- IP/endpoint origin может быть виден через DNS.
- Нет защиты Cloudflare на уровне HTTP-прокси.

## 7.2. Proxied

В режиме Proxied Cloudflare становится reverse proxy перед AWS.

```text
Пользователь -> Cloudflare proxy -> AWS endpoint
```

### Плюсы Proxied

- Можно использовать Cloudflare WAF, DDoS-защиту, кеширование, rules.
- Origin можно частично скрыть.
- Можно управлять security policies на стороне Cloudflare.

### Минусы Proxied

- Сложнее TLS-цепочка.
- Нужно проверять SSL/TLS mode в Cloudflare.
- Возможны проблемы с кешированием, headers, WebSocket, redirects.
- Если за Cloudflare стоит CloudFront, получается CDN поверх CDN. Это может быть нормально, но требует аккуратной настройки.

## 7.3. Рекомендация

Для первого запуска:

```text
Proxy status: DNS only
```

После успешного запуска можно отдельно обсудить, нужно ли включать Proxied.

---

# 8. Что проверить перед изменениями

Перед тем как добавлять `t3.jsnb.org`, нужно посмотреть текущие DNS-записи в Cloudflare.

Особенно проверить:

```text
jsnb.org
www
api
app
*
*.jsnb.org
```

## 8.1. Почему важен wildcard

Wildcard-запись может выглядеть так:

```text
*.jsnb.org -> ваш CloudFront
```

Она означает, что любой неизвестный поддомен может вести на ваш проект.

Например:

```text
abc.jsnb.org
random.jsnb.org
t3.jsnb.org
```

Но явная запись `t3` обычно имеет приоритет над wildcard. Всё равно важно проверить наличие wildcard, чтобы понимать текущую картину.

## 8.2. Что не трогать

Не менять записи:

```text
jsnb.org
www
api
app
```

Не менять CloudFront/ALB вашего проекта.

Не менять SSL-сертификаты вашего проекта.

---

# 9. Чек-лист данных от другой команды

Перед началом попросите другую команду прислать:

```text
1. Какой вариант они хотят:
   - CloudFront
   - ALB
   - delegation в Route 53

2. Какой endpoint использовать:
   - CloudFront domain name вида dxxxx.cloudfront.net
   - или ALB DNS name вида xxx.region.elb.amazonaws.com

3. Нужен ли им только t3.jsnb.org или ещё поддомены:
   - api.t3.jsnb.org
   - admin.t3.jsnb.org
   - preview.t3.jsnb.org

4. DNS validation records для ACM-сертификата.

5. Требуется ли Cloudflare Proxy:
   - DNS only
   - Proxied

6. Кто отвечает за HTTPS:
   - они в AWS ACM
   - или вы через Cloudflare proxy

7. Есть ли WebSocket, API, file upload, streaming, SSE.
```

---

# 10. Рекомендуемая roadmap для вашего случая

## Этап 1. Безопасная подготовка

Цель: ничего не менять в production до понимания текущего DNS.

Действия:

```text
1. Открыть Cloudflare -> jsnb.org -> DNS -> Records.
2. Экспортировать или скопировать текущие DNS-записи.
3. Отметить записи, связанные с вашим проектом.
4. Проверить наличие wildcard-записи *.jsnb.org.
5. Проверить, какие записи Proxied, а какие DNS only.
```

Результат:

```text
Понятно, какие записи уже используются вашим проектом.
Понятно, есть ли wildcard.
Понятно, какие записи нельзя менять.
```

## Этап 2. Выбор варианта

Если другой команде нужен только один адрес:

```text
t3.jsnb.org
```

выбрать:

```text
Вариант A: CNAME на CloudFront
```

или:

```text
Вариант B: CNAME на ALB
```

Если им нужна целая зона:

```text
api.t3.jsnb.org
admin.t3.jsnb.org
preview.t3.jsnb.org
```

выбрать:

```text
Вариант C: NS delegation в Route 53
```

## Этап 3. Сертификат

Для CloudFront:

```text
ACM certificate в us-east-1
Domain: t3.jsnb.org
Validation: DNS
```

Для ALB:

```text
ACM certificate в регионе ALB
Domain: t3.jsnb.org
Validation: DNS
```

Ваша задача: добавить DNS validation CNAME в Cloudflare.

## Этап 4. Основная DNS-запись

После выпуска сертификата добавить:

Для CloudFront:

```text
Type: CNAME
Name: t3
Target: dxxxxxxxxxxxxx.cloudfront.net
Proxy status: DNS only
```

Для ALB:

```text
Type: CNAME
Name: t3
Target: xxx.region.elb.amazonaws.com
Proxy status: DNS only
```

Для delegation:

```text
Type: NS
Name: t3
Value: ns-xxx.awsdns-xx.com
```

## Этап 5. Проверка

Проверить:

```bash
dig t3.jsnb.org
curl -I https://t3.jsnb.org
openssl s_client -connect t3.jsnb.org:443 -servername t3.jsnb.org </dev/null
```

Проверить, что ваш проект не изменился:

```bash
curl -I https://jsnb.org
curl -I https://www.jsnb.org
curl -I https://api.jsnb.org
```

## Этап 6. Документирование

Зафиксировать:

```text
Кто владелец домена jsnb.org.
Кто владелец проекта на t3.jsnb.org.
Какая DNS-запись создана.
Куда она ведёт.
Кто отвечает за сертификат.
Кто отвечает за AWS-инфраструктуру.
Кто отвечает за инциденты.
Как отключить t3.jsnb.org при необходимости.
```

---

# 11. Как быстро отключить поддомен при проблемах

Если `t3.jsnb.org` начнёт создавать проблемы, например phishing, broken app, security incident, неправильные redirects, можно быстро отключить DNS.

## Для CNAME-варианта

В Cloudflare:

```text
Удалить или Disable запись:
CNAME t3 -> ...
```

Или временно заменить на maintenance page / ваш CloudFront.

## Для delegation-варианта

В Cloudflare:

```text
Удалить NS records для t3
```

После propagation `t3.jsnb.org` перестанет делегироваться в Route 53 другой команды.

---

# 12. Риски и как их снизить

## Риск 1. Сломать основной проект

Причина: случайно изменить `jsnb.org`, `www`, `api`, `app`.

Как снизить:

```text
Перед изменениями сделать скриншот / экспорт DNS records.
Добавлять только новую запись t3.
Не менять существующие записи.
```

## Риск 2. Ошибка с сертификатом CloudFront

Причина: сертификат создан не в `us-east-1`.

Как снизить:

```text
Для CloudFront всегда просить ACM certificate в us-east-1.
```

## Риск 3. Ошибка с сертификатом ALB

Причина: сертификат создан не в регионе ALB.

Как снизить:

```text
Для ALB сертификат должен быть в том же регионе, где ALB.
```

## Риск 4. Cloudflare Proxy ломает поведение

Причина: включили Proxied без проверки TLS, headers, WebSocket, cache.

Как снизить:

```text
Первый запуск делать DNS only.
Proxied включать отдельно после тестов.
```

## Риск 5. Другая команда хочет много поддоменов

Причина: при CNAME-варианте им каждый раз нужно просить вас добавить запись.

Как снизить:

```text
Если поддоменов много, перейти на delegation через NS в Route 53.
```

## Риск 6. Репутационный риск для `jsnb.org`

Причина: чужой проект находится на вашем домене третьего уровня.

Как снизить:

```text
Письменно зафиксировать ответственность.
Проверить, что проект другой команды безопасный.
Согласовать право отключения t3.jsnb.org при инциденте.
```

---

# 13. Готовое сообщение другой команде

```text
Да, мы можем выделить t3.jsnb.org под ваш проект.

Предлагаю на первом этапе сделать отдельную DNS-запись в Cloudflare:

t3.jsnb.org -> ваш AWS CloudFront или ALB endpoint

Основной домен jsnb.org и наши текущие поддомены при этом не затрагиваются.

С вашей стороны нужно:

1. Сообщить, что вы используете как входную точку: CloudFront или ALB.
2. Настроить ваш CloudFront/ALB на hostname t3.jsnb.org.
3. Выпустить ACM-сертификат для t3.jsnb.org.
   - Для CloudFront сертификат должен быть в us-east-1.
   - Для ALB сертификат должен быть в регионе вашего ALB.
4. Прислать нам DNS validation CNAME record для ACM.
5. После выпуска сертификата прислать CloudFront domain name или ALB DNS name, куда нужно направить t3.jsnb.org.

На первом этапе мы рекомендуем режим Cloudflare DNS only, чтобы не смешивать Cloudflare proxy и AWS TLS/CDN-настройки.

Если вам потребуется самостоятельное управление зоной t3.jsnb.org и поддоменами вроде api.t3.jsnb.org, admin.t3.jsnb.org, preview.t3.jsnb.org, тогда отдельно обсудим делегирование t3.jsnb.org через NS records в ваш Route 53.
```

---

# 14. Практическая рекомендация

Для текущего запроса лучший путь:

```text
Вариант A, если у другой команды есть CloudFront.
Вариант B, если у другой команды только ALB.
```

То есть:

```text
Cloudflare DNS:
CNAME t3 -> их AWS endpoint
Proxy status: DNS only
```

Delegation через NS делать только если другая команда прямо говорит, что им нужна отдельная DNS-зона `t3.jsnb.org` и много внутренних поддоменов.

---

# 15. Источники

1. Cloudflare — Create subdomain records  
   https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-subdomain/

2. Cloudflare — Proxy status: DNS-only and Proxied  
   https://developers.cloudflare.com/dns/proxy-status/

3. Cloudflare — Delegate subdomains outside Cloudflare  
   https://developers.cloudflare.com/dns/manage-dns-records/how-to/subdomains-outside-cloudflare/

4. Cloudflare — Subdomain delegation and available setups  
   https://developers.cloudflare.com/dns/zone-setups/subdomain-setup/setup/

5. AWS CloudFront — Requirements for using SSL/TLS certificates with CloudFront  
   https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html

6. AWS CloudFront — Configure alternate domain names and HTTPS  
   https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-procedures.html

7. AWS Elastic Load Balancing — SSL certificates for Application Load Balancer  
   https://docs.aws.amazon.com/elasticloadbalancing/latest/application/https-listener-certificates.html

8. AWS Elastic Load Balancing — Create an HTTPS listener for Application Load Balancer  
   https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html
