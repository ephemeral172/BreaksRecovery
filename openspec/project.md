# BreaksRecovery — OpenSpec

## Общее описание

**Робот:** BreaksRecovery  
**Версия ТЗ:** 1.0 (от 09.06.2026, автор: Veniamin Savchuk)  
**Платформа:** n8n  
**Размер процесса:** L  
**Критичность:** P3 (SLA ≥99%, восстановление ≤3 дней 5×2)  
**Jira:** BPAPMO-1233  

Робот автоматизирует два ежедневных процесса WFM/RTM для агентов колл-центра Avito:

- **WF-1 «Восстановление»** — восстанавливает перерывы, обеды и чтение новостей в расписаниях ~2000 агентов на следующий день, которые были «затёрты» бот-планированием.
- **WF-2 «Балансировка покрытия»** — перемещает перерывы/обеды из интервалов с нехваткой FTE (просадка) в интервалы с избытком (профицит), не создавая новых просадок.

Суммарная экономия: **3,22 FTE/мес** (WF-1: 2,17 + WF-2: 1,05).

**Прогресс (18.06.2026):** проект **~42%** · WF-1 **~50%** · WF-2 **~5%**. Детали — `openspec/progress.md`.

---

## Стек технологий

| Компонент | Технология / Система |
|---|---|
| Платформа автоматизации | n8n (self-hosted, контур RPA) |
| БД источник (чтение) | PostgreSQL — `wfms-db01.msk.avito.ru`, схема `public` (Naumen WFM) |
| БД робота (запись) | PostgreSQL — БД RPA Data (контур RPA) |
| Web UI взаимодействие | WFMS `wfms.avito.ru` (Naumen WFM), авторизация LDAP |
| Уведомления | Mattermost REST API (корпоративный мессенджер) |
| Безопасность | mTLS-сертификаты (non-prod / prod) |
| Репозиторий | Stash: `https://stash.msk.avito.ru/projects/RPA/repos/n8n` |
| Таймзона | Europe/Moscow (UTC+3); БД хранит UTC, +3 ч при чтении |

---

## Архитектура воркфлоу

Робот строится по подходу **Reframework** (как остальные роботы команды RPA): фиксированные
блоки Init → CreateTables → GetTransaction → Process → End Process, плюс отдельный
воркфлоу **Error Handler**, который вызывается на любой ошибке.

```
[Cron 05:00 MSK]
       │
       ▼
┌──────────────────────────────────┐
│       BreaksRecovery_Main         │
│                                   │
│  ┌─────────────────────────┐      │
│  │  Init (Get Config)      │      │  ← JSON-нода (позже HTTP→Git), НЕ из БД
│  └─────────┬───────────────┘      │
│  ┌─────────▼───────────────┐      │
│  │  Validate Config        │      │  ← проверка пустых полей; fail → Error Handler
│  └─────────┬───────────────┘      │
│  ┌─────────▼───────────────┐      │
│  │  Create Tables          │      │  ← схема + CREATE TABLE (idempotent)
│  └─────────┬───────────────┘      │
│  ┌─────────▼───────────────┐      │
│  │  WF-1: Восстановление    │     │  ← Транзакция = 1 агент (~2000/день)
│  │  (Шаги 3–20)            │      │     Загрузка одним пакетом в конце
│  └─────────┬───────────────┘      │
│            │  Execute Workflow     │
│  ┌─────────▼───────────────┐      │
│  │  WF-2: Балансировка      │     │  ← Транзакция = 1 группа линий/навыков
│  │  (Шаги 21–38)           │      │     Загрузка по 1 сотруднику в конце
│  └─────────┬───────────────┘      │
│  ┌─────────▼───────────────┐      │
│  │  End Process (MM + очистка)│    │
│  └─────────────────────────┘      │
└───────────────┬───────────────────┘
                │ при любой ошибке (force throw)
                ▼
┌──────────────────────────────────┐
│   ErrorHandler                    │  ← отдельный воркфлоу (Reframework)
│   входы: error_type (BE/SE),      │
│   error_message, workflow_id,     │
│   workflow_name                   │
│   → норм. + статусы + нотификация │
└──────────────────────────────────┘
```

**Триггер WF-2:** не отдельный Cron, а `Execute Workflow` из WF-1 после его полного завершения.

### Эталонный паттерн (робот [Claims], скриншоты 16.06)

Эталоном служит робот Claims той же команды. Ключевые паттерны:

**GetConfig (отдельный воркфлоу):**
```
Start → Edit Fields (JSON-шаблон конфига) → HTTP Request (GET к Git)
      → IF «конфиг получен?»
          false → SE: Ошибка получения конфига (force throw)
```
JSON-шаблон — это дефолтный конфиг прямо в Edit Fields. HTTP Request перетирает его актуальными значениями из Git.

**InitTables (отдельный воркфлоу):**
```
Start → Создание схемы (executeQuery: CREATE SCHEMA IF NOT EXISTS)
      → Создание таблицы 1 (executeQuery)
      → Создание таблицы 2 (executeQuery)
      → ...
```
Каждая таблица — отдельная нода. Имена берутся из конфига (`DBSchemaName`, `DBTableNameTransactions` и т.д.).

**Main (три зоны):**
```
Phase 1: INIT     → Call GetConfig → Определение пустых полей → Проверка конфигурации
                    ↓ ошибка → Call ErrorHandler
Phase 2: GET DATA → Call InitTables → Call GetProcessingData → Получение транзакций
                    ↓ ошибка → Call ErrorHandler
Phase 3: PROCESS  → Loop: Call Process (sub-workflow) → Успешное завершение / Call Notify
                    ↓ аварийная ошибка → SE: Аварийное обновление статуса
```

**ErrorHandler (отдельный воркфлоу, два входа):**
```
Start (ручной) ─┐
                ├→ Merge (append) → Нормализация ошибки → Call GetConfig
Error Trigger ──┘                                          → Отправка уведомления (HTTP)
                                                           → Проставление статуса Error (executeQuery)
```

---

### Reframework-блоки

| Блок | Назначение |
|---|---|
| **Init / Get Config** | Чтение конфига. На старте — JSON-нода; в дальнейшем — HTTP Request к Git-репозиторию (папка робота). **Конфиг хранится в Git, не в БД** — изменения через пулреквесты. |
| **Validate Config** | Проверка, что конфиг получен и обязательные поля не пустые. При провале — принудительный вызов ошибки → Error Handler. |
| **Create Tables** | Создание схемы и таблиц (idempotent, `CREATE TABLE IF NOT EXISTS`). Каждая таблица — отдельным аргументом. |
| **GetTransaction** | Формирование транзакционной выборки (необработанные записи; можно с лимитом/партиями за запуск). |
| **Process** | Основная бизнес-логика. Каждый под-воркфлоу возвращает `success: true/false` + `error_type` + `error_message`. |
| **End Process** | Нотификации (если требуются по ТЗ) + очистка БД по ретеншену. |
| **Error Handler** | Отдельный воркфлоу: два входа (ручной проброс + авто-триггер на ошибке). Нормализует, заново читает конфиг, проставляет статусы `ERROR` необработанным, шлёт нотификацию. |

### Обработка ошибок (Set Edit Fields)

На false-ветке узлов формируется объект ошибки и передаётся в Error Handler:

| Поле | Значение |
|---|---|
| `success` | `false` |
| `error_type` | `Business Error` (BEn) / `System Error` (SEn) |
| `error_message` | Детальное описание + артефакты (в каком процессе, комментарии) |

Ноды БД/HTTP иногда «падают» без ветки Error — на этапе разработки тестировать поведение
и при необходимости ставить `Continue On Fail`, затем вручную проверять наличие результата
(«пруфов») и вызывать бизнес-ошибку с описанием.

---

## Структура БД RPA (таблицы робота)

> **Источник:** TDR v3 (18.06.2026), разделы 6.3, 6.5, 7.3. ADR-008.

> **Схема:** **`n8n_breaks_recovery`** — 4 таблицы (журналы + `agents`). Маппинги **не в БД**.

> **Два слоя конфигурации (TDR v3):**
> - **runtime + GetConfig** — параметры исполнения: имена таблиц, batch/chunking, retry, URL, cron
> - **mappings/*.json в git** — справочники (активности, контейнеры, новости, FTE). PR в Stash, не SQL

> **Конвенция колонок (встреча 16.06):** каждая транзакционная таблица содержит
> `id`, `processing_status`, `processing_comment`, `processing_start_time`, `processing_end_time`, `created_at`.

---

### SQL-схема (TDR v3 §6.3, ADR-006, ADR-008)

```sql
CREATE TABLE n8n_breaks_recovery.agents (
    id          SERIAL PRIMARY KEY,
    agent_login VARCHAR(100) NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE n8n_breaks_recovery.recovery_transactions (
    id                    SERIAL PRIMARY KEY,
    processing_start_time TIMESTAMPTZ NOT NULL,
    processing_end_time   TIMESTAMPTZ,
    processing_status     VARCHAR(100) NOT NULL,
    processing_comment    TEXT,
    agent_id              INTEGER NOT NULL REFERENCES n8n_breaks_recovery.agents(id),
    shift_date            DATE NOT NULL,
    is_night_shift        BOOLEAN NOT NULL DEFAULT FALSE,
    container_name        VARCHAR(200),
    container_type        VARCHAR(50),
    schedule_pattern      VARCHAR(50),
    news_minutes          INTEGER,
    activities_restored   INTEGER DEFAULT 0,
    upload_status         VARCHAR(50),
    error_code            VARCHAR(20),
    UNIQUE (agent_id, shift_date)
);
CREATE INDEX ix_rt_shift_date ON n8n_breaks_recovery.recovery_transactions (shift_date);
CREATE INDEX ix_rt_status     ON n8n_breaks_recovery.recovery_transactions (processing_status);

CREATE TABLE n8n_breaks_recovery.balance_transactions (
    id                        SERIAL PRIMARY KEY,
    processing_start_time     TIMESTAMPTZ NOT NULL,
    processing_end_time       TIMESTAMPTZ,
    processing_status         VARCHAR(100) NOT NULL,
    processing_comment        TEXT,
    group_name                VARCHAR(200) NOT NULL,
    direction                 VARCHAR(50),
    channel                   VARCHAR(50),
    coverage_date             DATE NOT NULL,
    drop_ranges_total         INTEGER DEFAULT 0,
    drop_ranges_no_candidates INTEGER DEFAULT 0,
    moves_count               INTEGER DEFAULT 0,
    upload_status             VARCHAR(50),
    error_code                VARCHAR(20),
    UNIQUE (group_name, coverage_date)
);
CREATE INDEX ix_bt_coverage_date ON n8n_breaks_recovery.balance_transactions (coverage_date);
CREATE INDEX ix_bt_status        ON n8n_breaks_recovery.balance_transactions (processing_status);

CREATE TABLE n8n_breaks_recovery.breaks_balance_moves (
    id             SERIAL PRIMARY KEY,
    transaction_id INTEGER NOT NULL REFERENCES n8n_breaks_recovery.balance_transactions(id),
    agent_id       INTEGER NOT NULL REFERENCES n8n_breaks_recovery.agents(id),
    activity_name  VARCHAR(200) NOT NULL,
    coverage_date  DATE NOT NULL,
    old_start      TIMESTAMPTZ NOT NULL,
    old_end        TIMESTAMPTZ NOT NULL,
    new_start      TIMESTAMPTZ NOT NULL,
    new_end        TIMESTAMPTZ NOT NULL,
    line_name      VARCHAR(200),
    UNIQUE (agent_id, coverage_date, activity_name, old_start)
);
CREATE INDEX ix_bbm_agent_date ON n8n_breaks_recovery.breaks_balance_moves (agent_id, coverage_date);
```

> **Итого 4 таблицы в БД.** Маппинги — `mappings/*.json` (§6.5). Миграция с cfg_*: `workflows/sql/migrate_tdr_v3.sql`.

---

## Маппинги в git (TDR v3 §6.5)

Путь: `BreaksRecovery_Main/mappings/` в репозитории `projects/RPA/repos/n8n`.

| Файл | Назначение | Строк (≈) |
|---|---|---|
| `activity.json` | Можно ли ставить перерыв на активность | 153 |
| `container.json` | Нестандартные контейнеры | 53 |
| `news_reading.json` | Минуты новостей по паттерну/дню | 77 |
| `news_exception_skills.json` | Навыки +15 мин | 2 |
| `fte_groups.json` | Группы FTE (Робот 2 + фильтр Робот 1) | 161 |
| `email_fallback.json` | Адреса SE2 | 0 (ждём email) |
| `fte_thresholds.json` | Мин. FTE по группам (WF-2) | шаблон |
| `runtime.json` | Batch, retry, cron, SMTP | TDR §6.5 |

Загрузка: воркфлоу `LoadMappings` (HTTP из `GitRawBaseURL`). Нода **Fetch JSON** (HTTP Request) — **Basic Auth** credential (Stash). Шаблон: `workflows/config/breaks-recovery.config.json`. Legacy SQL: `init_cfg_data.sql` (deprecated).

### Git / Stash (`projects/RPA/repos/n8n`)

Поля **GetConfig** (и `workflows/config/breaks-recovery.config.json`):

```json
"GitRawBaseURL": "https://stash.msk.avito.ru/projects/RPA/repos/n8n/raw",
"GitBranch": "RPA-1824",
"MappingsPath": "BreaksRecovery_Main/mappings"
```

> После merge PR в `dev`/`main` — обновить только `GitBranch` в GetConfig.

**Cron:** источник правды — `GetConfig.CronSchedule` + нода Cron в Main (должны совпадать). Блок `scheduler` убран из `runtime.json` (был дубль).

**Формат raw URL:** ветка в query `?at=refs/heads/{branch}`, не в path:

`.../raw/BreaksRecovery_Main/mappings/activity.json?at=refs%2Fheads%2FRPA-1824`

Цепочка Main Phase 1: `GetConfig` → `InitTables` (опц.) → `Restore Config Context` → **`Execute LoadMappings`** → Phase 2.

**Авторизация:** репозиторий приватный → HTTP **401** без credentials. На ноде **Fetch JSON** (LoadMappings) → **Authentication: Basic Auth** → credential **HTTP Basic Auth**:

| Поле | Значение |
|---|---|
| User | логин Stash (или `x-token-auth` для PAT-only) |
| Password | App Password / Personal Access Token |

Создание токена: Stash → Manage account → HTTP access tokens / App passwords.

---

## Модель данных: три слоя

| Слой | Источник | Куда | Когда обновляется | Пример |
|---|---|---|---|---|
| **Справочники / правила** | ТЗ → PR в git | `mappings/*.json` | Редко, через PR | activity.json, container.json |
| **Операционные данные** | WFM DB (read-only) | не копируются | Каждый запуск | Смены, активности |
| **Результаты робота** | робот | `recovery_transactions`, `balance_*` | Каждый запуск | Журнал обработки |

### Legacy cfg_* (до TDR v3)

Таблицы `cfg_*` и `InitCfgData` — **устарели**. Данные перенесены в `mappings/`. На существующей БД: `migrate_tdr_v3.sql`.

**Порядок применения (TDR v3):**
1. `InitTables` — 4 таблицы в `n8n_breaks_recovery`
2. Залить `mappings/*.json` в git (PR в Stash)
3. Указать `GitRawBaseURL` в GetConfig
4. На legacy БД: `workflows/sql/migrate_tdr_v3.sql`

### Non-prod vs prod

| Контур | mappings (git) | Операционные данные |
|---|---|---|
| **Non-prod** | ветка `dev/breaks-recovery` | Тестовая WFM DB |
| **Prod** | prod-ветка после PR | Prod WFM DB |

### Правила изменения справочников

- Правки маппингов — **PR в git**, ревью RPA
- Операционные данные (смены, активности) — только из WFM DB, не в mappings
- Runtime-параметры (batch, cron) — `mappings/runtime.json` или GetConfig

---

## Credentials в n8n

| Название в n8n | Тип | Система | Режим | Что настраивать |
|---|---|---|---|---|
| `WFM DB` | PostgreSQL | `wfms-db01.msk.avito.ru`, схема `public` | **только чтение** | host, port, db, user, password (LDAP) |
| `RPA DB` | PostgreSQL | `bpa-primo-prod-db01.msk.avito.ru:5432`, схема `n8n_breaks_recovery` | **INSERT/UPDATE/SELECT** | host, port, db, user, password |
| `Mattermost_Bot` | HTTP Header Auth | `https://mt.avito.ru/api/v4/`, через **1С Bot API** | отправка | Bot Token |
| `SMTP_Fallback` | SMTP | `exchange.avito.ru:587` (TLS) | отправка | логин, пароль; адреса из `email_fallback.json` |

> **Важно:** журналы транзакций — **RPA DB**. Маппинги — **git**, не RPA DB (TDR v3 §7.3).
> Из **WFM DB** робот только читает.

---

## Таймзоны

| Источник | Хранит время | Правило |
|---|---|---|
| **WFM DB** (Naumen) | UTC | При чтении добавлять **+3 часа** → `start + INTERVAL '3 hours'` (Europe/Moscow) |
| **RPA DB** (транзакции) | локальное/0-смещение | Конвертация не требуется |

Открытый вопрос Q-05: подтвердить, что у всех навыков `skill.time_zone = Europe/Moscow`
(иначе сдвиг +3 ч сломается на региональных линиях). Кандидат персональной TZ:
`zone_validity_period.user_zone` — для v1 решить: исключать таких агентов или учитывать.

---

## WFM SQL — технические ловушки (ADR-007)

| # | Ловушка | Решение |
|---|---|---|
| 1 | `not_erasable` на test (в TDR — `not_eraseble` для usa) | На test: `user_schedule_activity.not_erasable`; сверить `information_schema` |
| 2 | `schedule_variant*.start/end` — `time`; usa — `timestamp without time zone` | Склеивать time с `shift_date` D+1 |
| 3 | План/факт FTE (Робот 2) | `queue_forecast → queue.skill_id → skill ← skill_fte` |

Кандидаты из .docx: `skill.max_flaw` (Q-03 порог просадки), `zone_validity_period.user_zone` (Q-05).

**ИБ:** параметризованные запросы в Postgres-нодах; маскировка логинов в MM/email; секреты только в Credentials. Чеклист — `openspec/progress.md` § «Чеклист ИБ».

---

## Каналы Mattermost

| Канал | Назначение |
|---|---|
| `RPA_BN_BreaksRecovery` | Бизнес-уведомления: Success, Warn, BE |
| `RPA_Robot_Prod_Notifications` | Системные ошибки (SE), критические алерты |

---

## Cron-расписание

```
0 5 * * *  (Europe/Moscow)
```

На этапе ОПЭ запуск планируется вручную (~13:00), после ОПЭ — переключить на 19:30.

---

## Правила именования

### Воркфлоу в n8n (конвенция на инстансе, 18.06.2026)

| Имя в n8n | Роль | Файл в репо |
|---|---|---|
| `BreaksRecovery_Main` | Робот 1, главный | `workflows/BreaksRecovery_Main.json` |
| `BreaksRecovery_Balance` | Робот 2 | *(черновик, не в репо)* |
| `GetConfig` | JSON-конфиг + Validate | `workflows/BreaksRecovery_2.GetConfig.json` |
| `InitTables` | CREATE SCHEMA/TABLE | `workflows/BreaksRecovery_3.InitTables.json` |
| `LoadMappings` | HTTP: mappings/*.json из git | `workflows/BreaksRecovery_LoadMappings.json` |
| `InitCfgData` | ~~Заливка cfg_*~~ **deprecated** (TDR v3) | — |
| `ErrorHandler` | Reframework error workflow | `workflows/BreaksRecovery_8.ErrorHandler.json` |

- **Главные** роботы: `BreaksRecovery_<Role>` (PascalCase + underscore).
- **Sub-workflow:** короткое имя без префикса (`GetConfig`, `InitTables`, …).
- **Execute Workflow** в JSON — `mode: name`, значение **точно как в n8n**.
- **Credentials БД:** `RPA DB` (журналы, agents), `WFM DB` (только SELECT). Маппинги — git HTTP, не БД.
- Таблицы БД: snake_case.

---

## Процесс работы с репозиторием (Git / Stash)

Конвенция команды RPA (встреча 16.06):

- Основная ветка разработки — `dev`. Из неё создаётся ветка под задачу, после — Pull Request обратно в `dev`.
- Изменения проходят **code review** (заявка в канале Mattermost в установленном формате).
- Конфиги робота лежат в Git (репозиторий `projects/RPA/repos/n8n`); правки конфига — через PR.
- В ветке `configuration` есть под-ветка `test`, в которую можно лить напрямую без PR.
- Робот хранится в `dev` до полной готовности.
- Подключение Stash можно отложить на пару дней — сначала локальная разработка и JSON-конфиг.

---

## Ретеншен данных (очистка БД, блок End Process)

| Тип данных | Срок хранения | Источник |
|---|---|---|
| Транзакционные данные | **12 месяцев** | TDR раздел 5.1 |
| ПДн (login агентов) | **6 месяцев** | TDR раздел 5.2 |
| Временные таблицы | очищать сразу по завершении задачи | конвенция команды |

> **Примечание:** на вводной встрече (16.06) прозвучало «2 года» как общее правило команды.
> TDR для этого проекта уточняет: транзакции — 12 месяцев (возможно, из-за ПДн в виде login-а).
> Финально следуем TDR. Очистка реализуется через TTL-задачу в блоке End Process.

## Формат пакета загрузки в WFMS (TDR раздел 7.2)

Каждая строка пакета — JSON-объект:

```json
{
  "login": "ivanov_aa",
  "activity": "Перерыв",
  "start": "2026-06-17T10:30:00+03:00",
  "end": "2026-06-17T10:40:00+03:00",
  "timeZone": "Europe/Moscow"
}
```

Шаги UI:
1. `POST /login` (LDAP-форма) → сессионный cookie
2. Навигация к оргточке «Поддержка»
3. `POST multipart/upload` — файл-пакет (WF-1: все агенты разом; WF-2: по 1 сотруднику)
4. `POST /schedule/publish` — «Опубликовать изменения»
5. `POST /fte/recalculate` — «Пересчитать FTE»

Retry: 3 попытки с exponential backoff (1/3/9 сек). Ошибка → BE4.

---

## mTLS-сертификаты

- Нужны для prod-контура (см. ссылку на PaaS-доки в ТЗ).
- **На non-prod / staging сертификаты не требуются** — доступ напрямую (подтверждено на встрече 16.06).
- Вывод: для текущего спринта mTLS — не блокер, можно отложить, сфокусироваться на каркасе и БД.

---

## Ограничения (вне scope v1)

- Тонкая оптимизация по 5-минутным окнам
- Простановка плавающих перерывов (агент ставит сам)
- Работа с индивидуальными договорённостями (отработки/переносы часов)
- Изменение контейнеров/схем и прогноза FTE
- Desktop-приложения

---

## Контакты

| Роль | Имя | Email |
|---|---|---|
| Stakeholder | Tatyana Nikolaeva | tanikolaeva@avito.ru |
| Process Master | Aleksandr Krasyukov | aakrasyukov@avito.ru |
| Process Master | Anastasiya Kazarina | aakazarina@avito.ru |
| Process Master | Ramil Ramaev | rsramaev@avito.ru |
| RPA-аналитик | Veniamin Savchuk | vdsavchuk@avito.ru |

---

## Ссылки

- ТЗ: `ТЗ.pdf` (в корне репозитория)
- TDR v3: https://cf.avito.ru/spaces/RPA/pages/914753799
- БД WFMS: `wfms-db01.msk.avito.ru`
- WFMS UI: https://wfms.avito.ru
- Stash: https://stash.msk.avito.ru/projects/RPA/repos/n8n
- mTLS docs: https://docs.k.avito.ru/service-paas-docs/paas/lifecycle/service_development/security/mtls/
