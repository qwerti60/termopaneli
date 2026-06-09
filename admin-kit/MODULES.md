# Манифест файлов админки по модулям

Пути от `backend/public/`.

## Ядро

```
admin-web/
  bootstrap_web.php
  index.php
  login.php
  logout.php
  login_reset.php
  admin_password.php
  admin_journal.php

include/
  api_bootstrap.php
  admin_auth.php
  admin_login_verify.php
  admin_audit_log.php
  admin_mail.php
  admin_password_service.php

api/v1/admin/auth/
  login.php
  logout.php
```

## Заявки и PDF

```
admin-web/
  requests.php
  request_view.php
  request_pdf.php
  admin_estimates.php
  admin_estimate_delete.php

include/
  admin_requests_service.php
  admin_estimate_calc.php
  admin_estimate_pdf.php
  admin_estimates.php
  company_pdf_defaults.php

api/v1/admin/requests/
  list.php
  status.php
```

**Composer:** `dompdf/dompdf` в `vendor/`.

## Каталог

```
admin-web/
  catalog_panels.php
  catalog_panel_new.php
  catalog_panel_edit.php
  catalog_panel_delete.php
  catalog_materials.php
  catalog_material_new.php
  catalog_material_edit.php
  catalog_material_delete.php
  catalog_edit.php
  catalog_work_prices.php
  catalog_work_new.php
  catalog_work_edit.php
  catalog_work_delete.php

include/
  admin_catalog_panels.php
  admin_catalog_materials.php
  admin_work_prices.php
  admin_catalog_media.php
```

**Каталог на диске:** `catalog_uploads/` (+ `.gitkeep`).

## Пользователи

```
admin-web/
  admin_users.php
  admin_user_toggle.php

include/
  admin_users.php
```

## Подписки

```
admin-web/
  subscriptions.php
  admin_subscribers.php
  admin_subscription_events.php
  admin_misc.php          # ссылки на документацию

include/
  admin_subscriptions.php
  subscriptions_repo.php
  subscription_plans.php
```

## Опционально (Termopaneli)

```
admin-web/app_user_guide.html   # справка по мобильному приложению — замените в новом проекте
```

## Shared с пользовательским API

Если нужны заявки/каталог/подписки в приложении, дополнительно выкладывают:

```
api/v1/auth/*
api/v1/catalog/list.php
api/v1/estimates/*
api/v1/subscription/*
include/estimates_user_auth.php
include/subscriptions_repo.php
…
```

См. `backend/README_API.txt`.
