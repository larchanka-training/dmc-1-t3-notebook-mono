# План подключения поддомена `t3.jsnb.org` — Вариант C (NS delegation)

Дата: 21 июня 2026

## Контекст

Команда `jsnb.org` выделила нам поддомен `t3.jsnb.org`.  
Выбран **Вариант C** — делегирование через NS-записи.

Схема разделения ответственности:

| Зона | Кто управляет |
|---|---|
| `jsnb.org` | Команда jsnb.org — Cloudflare DNS |
| `t3.jsnb.org` и всё ниже | Мы — AWS Route 53 |

После настройки мы самостоятельно управляем DNS-записями внутри `t3.jsnb.org`:

```text
t3.jsnb.org          → CloudFront (UI)
api.t3.jsnb.org      → ALB (API)
preview.t3.jsnb.org  → Preview ALB (опционально)
*.t3.jsnb.org        → wildcard-сертификат
```

---

## Текущее состояние инфраструктуры

| Ресурс | Состояние |
|---|---|
| CloudFront distribution | Есть, использует `cloudfront_default_certificate = true` (без custom domain) |
| ALB | Есть, только HTTP listener на 80 |
| ECS Fargate (API) | Есть |
| S3 bucket (UI) | Есть |
| Route 53 | Нет hosted zone для `t3.jsnb.org` |
| ACM сертификат | Нет |

---

## Шаги

### Шаг 1. Зафиксировать границы ответственности

Письменно согласовать с командой `jsnb.org`:

- Мы отвечаем за всё, что находится в зоне `t3.jsnb.org` и ниже.
- Они не трогают наши записи, мы не трогаем их `jsnb.org`.
- Мы имеем право самостоятельно добавлять, изменять и удалять записи внутри `t3.jsnb.org`.
- Они сохраняют право удалить NS-делегирование при нарушении с нашей стороны.
- Зафиксировать контактные лица с обеих сторон для инцидентов.

---

### Шаг 2. Создать Route 53 Public Hosted Zone

Создать hosted zone в AWS Route 53:

```text
Name: t3.jsnb.org
Type: Public hosted zone
```

**Через AWS Console:**

```
Route 53 → Hosted zones → Create hosted zone
Name: t3.jsnb.org
Type: Public
```

**Через Terraform (рекомендуется для IaC-подхода):**

Добавить в `infra/env/shared/main.tf`:

```hcl
resource "aws_route53_zone" "t3_jsnb_org" {
  name = "t3.jsnb.org"

  tags = merge(local.tags, {
    Name = "t3.jsnb.org"
  })
}

output "route53_zone_id" {
  value = aws_route53_zone.t3_jsnb_org.zone_id
}

output "route53_name_servers" {
  value = aws_route53_zone.t3_jsnb_org.name_servers
}
```

После `terraform apply` получить 4 NS-сервера:

```bash
terraform output route53_name_servers
```

Пример вывода:

```text
ns-111.awsdns-01.com
ns-222.awsdns-02.net
ns-333.awsdns-03.org
ns-444.awsdns-04.co.uk
```

---

### Шаг 3. Передать NS-записи команде jsnb.org

Отправить команде `jsnb.org` 4 NS-сервера в таком формате:

```text
Просьба добавить NS-делегирование для t3.jsnb.org в Cloudflare:

Type: NS   Name: t3   Value: ns-111.awsdns-01.com
Type: NS   Name: t3   Value: ns-222.awsdns-02.net
Type: NS   Name: t3   Value: ns-333.awsdns-03.org
Type: NS   Name: t3   Value: ns-444.awsdns-04.co.uk

Proxy status: DNS only (NS-записи не могут быть Proxied)
```

---

### Шаг 4. Проверить делегирование

После того как команда jsnb.org добавила NS-записи (DNS propagation — от нескольких минут до 48 часов):

```bash
dig NS t3.jsnb.org

# Ожидаемый результат: NS-серверы Route 53
# ns-111.awsdns-01.com
# ns-222.awsdns-02.net
# ns-333.awsdns-03.org
# ns-444.awsdns-04.co.uk
```

Если результат корректный — продолжаем.

---

### Шаг 5. Запросить ACM-сертификаты

Нужны два сертификата:

#### 5а. Сертификат для CloudFront — регион `us-east-1`

CloudFront требует ACM-сертификат строго в регионе `us-east-1`.

```text
Region: us-east-1
Domain: *.t3.jsnb.org
Additional domain: t3.jsnb.org
Validation method: DNS validation
```

Поскольку зона `t3.jsnb.org` уже в нашем Route 53, DNS validation records добавляем сами автоматически.

**Через Terraform (рекомендуется):**

Добавить в `infra/env/prod/main.tf` (с provider `us-east-1`):

```hcl
# Отдельный provider для нас-east-1 (обязательно для CloudFront ACM)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cloudfront" {
  provider                  = aws.us_east_1
  domain_name               = "t3.jsnb.org"
  subject_alternative_names = ["*.t3.jsnb.org"]
  validation_method         = "DNS"

  tags = merge(local.tags, {
    Name = "t3.jsnb.org CloudFront"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation_cloudfront" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.terraform_remote_state.shared.outputs.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_cloudfront : record.fqdn]
}
```

#### 5б. Сертификат для ALB — регион `eu-north-1`

ALB находится в `eu-north-1`, сертификат должен быть в том же регионе.

```text
Region: eu-north-1
Domain: api.t3.jsnb.org
Additional domain: t3.jsnb.org (опционально, если ALB будет обслуживать root)
Validation method: DNS validation
```

```hcl
resource "aws_acm_certificate" "alb" {
  domain_name               = "api.t3.jsnb.org"
  validation_method         = "DNS"

  tags = merge(local.tags, {
    Name = "api.t3.jsnb.org ALB"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation_alb" {
  for_each = {
    for dvo in aws_acm_certificate.alb.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.terraform_remote_state.shared.outputs.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "alb" {
  certificate_arn         = aws_acm_certificate.alb.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_alb : record.fqdn]
}
```

---

### Шаг 6. Обновить Terraform: модуль `static-site`

Текущий модуль использует `cloudfront_default_certificate = true`. Нужно добавить поддержку custom domain.

**Обновить `infra/modules/static-site/variables.tf`** — добавить:

```hcl
variable "domain_name" {
  description = "Custom domain for CloudFront (e.g. t3.jsnb.org). If empty, CloudFront default certificate is used."
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for the custom domain."
  type        = string
  default     = ""
}
```

**Обновить `infra/modules/static-site/main.tf`** — заменить блок `viewer_certificate`:

```hcl
aliases = var.domain_name != "" ? [var.domain_name] : []

viewer_certificate {
  acm_certificate_arn      = var.domain_name != "" ? var.acm_certificate_arn : null
  cloudfront_default_certificate = var.domain_name == ""
  ssl_support_method       = var.domain_name != "" ? "sni-only" : null
  minimum_protocol_version = var.domain_name != "" ? "TLSv1.2_2021" : "TLSv1"
}
```

---

### Шаг 7. Обновить `infra/env/prod/main.tf` — передать домен в модуль `ui`

```hcl
module "ui" {
  source = "../../modules/static-site"

  name                = "t3-notebook-${var.environment}-ui"
  bucket_name         = "t3-notebook-${var.environment}-ui"
  api_origin_domain   = module.alb.alb_dns_name
  domain_name         = "t3.jsnb.org"
  acm_certificate_arn = aws_acm_certificate_validation.cloudfront.certificate_arn
  tags                = local.tags
}
```

---

### Шаг 8. Создать DNS-записи в Route 53

Добавить в `infra/env/prod/main.tf`:

```hcl
# t3.jsnb.org → CloudFront (UI)
resource "aws_route53_record" "ui" {
  zone_id = data.terraform_remote_state.shared.outputs.route53_zone_id
  name    = "t3.jsnb.org"
  type    = "A"

  alias {
    name                   = module.ui.cloudfront_domain_name
    zone_id                = module.ui.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# api.t3.jsnb.org → ALB (API)
resource "aws_route53_record" "api" {
  zone_id = data.terraform_remote_state.shared.outputs.route53_zone_id
  name    = "api.t3.jsnb.org"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_hosted_zone_id
    evaluate_target_health = true
  }
}
```

Также проверить, что модуль `static-site` экспортирует `cloudfront_hosted_zone_id` в `outputs.tf`:

```hcl
output "cloudfront_hosted_zone_id" {
  value = aws_cloudfront_distribution.this.hosted_zone_id
}
```

---

### Шаг 9. Обновить ALB — добавить HTTPS listener

Текущий ALB имеет только HTTP listener. Для `api.t3.jsnb.org` нужен HTTPS.

В модуле `alb` или в `infra/env/prod/main.tf` добавить HTTPS listener с сертификатом:

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = module.alb.alb_arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.alb.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = module.api_service.target_group_arn
  }
}
```

Примечание: для CloudFront→ALB трафика можно оставить HTTP-only на ALB (CloudFront завершает TLS), но для прямого `api.t3.jsnb.org` нужен HTTPS.

---

### Шаг 10. Обновить конфигурацию приложения

#### API (CORS и сессионные cookie)

В `infra/env/prod/main.tf` обновить environment variables ECS-сервиса:

```hcl
environment = {
  ENVIRONMENT          = local.runtime_environment
  LOG_LEVEL            = var.log_level
  BACKEND_CORS_ORIGINS = "https://t3.jsnb.org"
  DEPLOY_NONCE         = var.deploy_nonce
}
```

Проверить настройку сессионных cookie в `api/app/core/`:
- `domain` cookie должен быть установлен как `.t3.jsnb.org` (чтобы работал на основном домене и поддоменах)
- `secure = True`
- `samesite = "lax"` или `"strict"`

#### Frontend (base URL)

Проверить, что base URL API в конфигурации Vite или `.env.production` указывает на:

```text
VITE_API_BASE_URL=/api
```

При routing через CloudFront это должно работать без изменений — `/api/*` уже проксируется на ALB через CloudFront origin behavior.

---

### Шаг 11. Применить Terraform

Порядок применения:

```bash
# 1. Сначала shared (hosted zone)
cd infra/env/shared
terraform init
terraform plan
terraform apply

# 2. Затем prod (сертификаты, CloudFront, DNS-записи)
cd infra/env/prod
terraform init
terraform plan
terraform apply
```

---

### Шаг 12. Финальная проверка

#### Проверить делегирование и DNS

```bash
# NS delegation
dig NS t3.jsnb.org

# UI endpoint
dig A t3.jsnb.org

# API endpoint
dig A api.t3.jsnb.org
```

#### Проверить HTTPS

```bash
# UI
curl -I https://t3.jsnb.org

# API health
curl -I https://t3.jsnb.org/api/v1/health

# Сертификат CloudFront
openssl s_client -connect t3.jsnb.org:443 -servername t3.jsnb.org </dev/null | grep -E "subject|issuer"
```

#### Проверить, что основной домен jsnb.org не затронут

```bash
# Эти запросы должны работать как и раньше
curl -I https://jsnb.org
```

#### Smoke test приложения

```bash
# E2E canary test
cd e2e
pnpm test --grep canary
```

---

### Шаг 13. Документировать результат

Зафиксировать в общем чанеле/wiki:

```text
Домен:          t3.jsnb.org
UI:             https://t3.jsnb.org (CloudFront → S3)
API:            https://t3.jsnb.org/api/* (CloudFront → ALB → ECS)
DNS zone:       AWS Route 53, Zone ID: <zone_id>
Сертификат CF:  ACM us-east-1, *.t3.jsnb.org
Сертификат ALB: ACM eu-north-1, api.t3.jsnb.org
Владелец зоны:  команда t3
Контакт jsnb.org: <имя и контакт>
Дата подключения: 2026-06-XX
```

---

## Сводная таблица шагов

| # | Шаг | Кто | Блокирует |
|---|---|---|---|
| 1 | Зафиксировать границы ответственности | Обе команды | — |
| 2 | Создать Route 53 Hosted Zone `t3.jsnb.org` | Мы | 1 |
| 3 | Передать NS-записи команде jsnb.org | Мы → они | 2 |
| 4 | Команда jsnb.org добавляет NS в Cloudflare | Они | 3 |
| 5 | Проверить делегирование `dig NS t3.jsnb.org` | Мы | 4 |
| 6 | Запросить ACM-сертификаты (us-east-1 + eu-north-1) | Мы | 5 |
| 7 | Обновить модуль `static-site` (custom domain support) | Мы | — |
| 8 | Обновить `env/prod` — передать домен и сертификат | Мы | 6, 7 |
| 9 | Добавить DNS-записи в Route 53 (A alias для CF и ALB) | Мы | 8 |
| 10 | Добавить HTTPS listener на ALB | Мы | 6 |
| 11 | Обновить CORS и cookie domain в API config | Мы | — |
| 12 | `terraform apply` (shared → prod) | Мы | 7–11 |
| 13 | Финальная проверка (`dig`, `curl`, e2e) | Мы | 12 |
| 14 | Документировать | Мы | 13 |

---

## Риски

| Риск | Снижение |
|---|---|
| CloudFront требует ACM в `us-east-1` | Создавать сертификат строго в `us-east-1` через alias provider |
| DNS propagation может занять до 48 часов | Начинать с делегирования заблаговременно |
| CORS-ошибки после смены домена | Обновить `BACKEND_CORS_ORIGINS` перед deploy |
| Cookie не работают после смены домена | Установить `domain=.t3.jsnb.org` в session cookie |
| Cloudflare proxy над CloudFront (CDN поверх CDN) | NS delegation исключает этот риск — трафик идёт напрямую в Route 53 / AWS |

---

## Как быстро откатить

При проблемах команда jsnb.org может удалить NS-записи `t3` в Cloudflare.  
После propagation DNS для `t3.jsnb.org` перестанет работать.  
Наш Route 53 и AWS-ресурсы остаются нетронутыми, основной `jsnb.org` не затрагивается.
