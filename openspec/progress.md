# Progress — BreaksRecovery

> **Легенда:** ✓ — сделано · ✓ *пояснение* — сделано с уточнением · ~ — частично · — — не сделано

**Обновлено:** 02.07.2026 (RPA-1834: тройной E2E ✓ success+BE2+BE3 в одном прогоне)

---

## Jira — статус задач (RPA_2026Q3S1_12.07)

| Задача | Scope | Статус | План / артефакт |
|---|---|---|---|
| **GetTransactionData** | ТЗ §4.5 шаги 2–3, 7 | ✓ **Done** 02.07.2026 | `openspec/plans/get-transaction-data-process.md` |
| **RPA-1834** Process (Получение контекста смены) | ТЗ §4.5 шаги 8–13 | ✓ **Done** 02.07.2026 | E2E тройной прогон ✓ success+BE2+BE3 |
| Upload / EndProcess | шаги 15–18 | ❌ Planned | Phase D (не Jira этого спринта) |

---

## Прогресс (оценка)

| Область | % | Комментарий |
|---|---:|---|
| **Проект целиком** (WF-1 + WF-2) | **~58** | GTD ✓; Process DoD — в работе |
| **Робот 1 — восстановление** (ТЗ §4.5) | **~72** | шаги 1–13 код ✓; upload ❌ |
| **Робот 2 — балансировка** | **~5** | Черновик воркфлоу |
| Фаза 0 — каркас (БД, конфиг, InitTables, ADR) | **~98** | Осталось: email_fallback.json, Stash prod |
| Phase 2 GET DATA (GetTransactionData) | **100** | Jira ✓; E2E 1262 agents; fix Assemble Payload `$input.all()` |
| Phase 3 PROCESS — логика 8–13 | **100** | unit 15/15; E2E multi-agent ✓ (success+BE2+BE3) |
| Phase 4 UPLOAD WFMS | **0** | Phase D, ADR-009 `success` |
| Phase 5 FINISH (MM, WF-2) | **~40** | Trigger WF-2 ✓; MM ~ |

### ТЗ §4.5 Робот 1 — по шагам

| Шаг | Содержание | % |
|---|---|---:|
| 1–2 | Cron, конфиг, mappings/*.json (git) | 100 |
| 3 | Агенты D+1, исключить обработанных | 100 |
| 4–6 | SQL WFM: контейнер, навыки, история 7 дн. | 100 |
| 7 | Loop 1 агент = 1 транзакция | 100 |
| 8–11 | Контейнер, новости, слоты | 100 |
| 12 | Пакет загрузки (staticData batch) | 100 |
| 13 | Write Transaction (UPDATE proc_07) | 100 * |
| 15–18 | WFMS upload + upload_status | 0 |
| 18–20 | MM + триггер WF-2 | ~40 |

\* Шаг 13 — `proc_07_update_transaction.sql`. E2E 02.07.2026: multi-agent (2 агента) — `zvusmanova` → `success`, `zvorudzhova.ext` → `skipped_BE2`; loop Run 3 of 3 Done Branch ✓

**Спринт GTD:** ✓ **закрыт 02.07.2026** (Jira GetTransactionData Done).  
**Спринт Process:** ✓ **закрыт 02.07.2026** — RPA-1834; E2E multi-agent ✓  
**Следующий:** Phase D (WFMS upload + E2E deficit scenarios).

---

## Сводка — Фаза 0

> **Фаза 0:** ~98% · **Фаза 1 GET DATA:** 100% (Jira ✓, 1262 agents) · **Фаза 3 Process:** ~98% · **Весь проект:** ~58%

### Jira GetTransactionData — закрыта 02.07.2026

| DoD | Статус | Доказательство |
|---|---|---|
| Payload шаг 6 → Process | ✓ | Execute GetTransactionData, tx 7775, mappings |
| agents + recovery_transactions | ✓ | agent_id 1396, ON CONFLICT |
| Config + mappings из git | ✓ | LoadMappings |
| Get Agents D+1 (ночник) | ✓ | zvusmanova, is_night_shift true |
| gtd_01 ADR-009 (не Jira шаг 2) | ✓ | согласовано с TL |
| BE1/SE1, SQL параметризован | ✓ | GetTransactionData.json |
| Идempotency / skip success / дневные 5/2·2/2 | ⚠️ | не формализовано в скринах PR |

### Phase 2 GetTransactionData — E2E (02.07.2026)

| # | Задача | Результат | TDR | ТЗ |
|---|---|---|---|---|
| **Документация** |
| D-01–D-09 | OpenSpec, ADR-001…007, модель данных | ✓ | — | — |
| D-10 | ADR-008: TDR v3 mappings в git | ✓ | §6.5 | — |
| D-11 | ADR-009: enum processing_status | ✓ | §6.3 | §4.5 шаг 3 |
| **БД RPA** |
| DB-01–10 | 4 таблицы в `n8n_breaks_recovery.*` (+ `agents`) | ✓ TDR v3; legacy cfg удаляются migrate | §6.3, ADR-008 | §2.6 |
| DB-10–14 | mappings/*.json (153/53/77/2/161) | ✓ git; legacy init_cfg_data.sql deprecated | §6.5 | §4.5 |
| DB-16 | `email_fallback.json` | — ждём email | §7.5 | §4.8 SE2 |
| **Воркфлоу** |
| WF-01 | `GetConfig` | ✓ прогнан (n8n_breaks_recovery) | §7 | §2.6, §4.9 |
| WF-02 | `InitTables` | ✓ 4 табл. TDR v3 | §6.3, ADR-008 | §2.6 |
| WF-02b | `LoadMappings` | ✓ E2E Stash `configuration/test` | §6.5 | — |
| WF-04 | `BreaksRecovery_Main` Phase 1 INIT | ✓ E2E non-prod (17.06) | §7 | §4.5 |
| WF-04b | `BreaksRecovery_Main` Phase 2 GET DATA | ✓ E2E test (18.06): 4918→4918 | §7.1, §7.3 | §4.5 шаг 3 |
| WF-08 | Cron `0 2 * * *` UTC | ✓ | — | §2.6, §4.5 шаг 1 |
| WF-03 | `ErrorHandler` | ✓ JSON; прогон — | ADR-005 | §4.7–4.8 |
| WF-05 | Credentials полностью в Main | ~ RPA ✓, WFM ✓ | §7.1, §7.3 | — |
| WF-06–07 | Error fields, Balance | — | — | — |
| **Credentials** |
| A-05 | RPA DB (`robotdata`) | ✓ | §7.3 | — |
| A-02, A-04 | WFM DB | ✓ test | §7.1 | §2.6 |
| A-06 | Mattermost Bot | ~ Continue On Error | §7.4 | §4.9 |
| A-01, A-03, A-07 | prod RPA, Stash, SMTP | ~ Stash Basic Auth ✓ (LoadMappings) | — | §4.8 SE2 |

---

## Main E2E — детализация

### Phase 1 INIT (24.06.2026, Stash configuration/test)

| Нода / шаг | Результат | TDR | ТЗ |
|---|---|---|---|
| Execute GetConfig | ✓ `GitBranch: test`, Stash configuration raw URL | §6.5 | §4.5 шаг 1–2 |
| Execute LoadMappings | ✓ 8 JSON из Stash; `mappings.activity` (153), … | §6.5 | — |

### Phase 1 INIT (18.06.2026, TDR v3 + GitHub dev)

| Нода / шаг | Результат | TDR | ТЗ |
|---|---|---|---|
| Cron → Execute GetConfig | ✓ `GitRawBaseURL`, `MappingsPath: mappings` | §6.5 | §4.5 шаг 1–2 |
| Execute InitTables | ✓ 4 табл. (пропуск — БД уже OK) | §6.3, ADR-008 | §2.6 |
| Execute LoadMappings | ✓ 8 JSON с GitHub (`activity` 153, `fte_groups` 161, …) | §6.5 | — |

### Phase 1 INIT (17.06.2026, legacy)

| Нода / шаг | Результат | TDR | ТЗ |
|---|---|---|---|
| Execute InitTables | ✓ 10 табл. `n8n_breaks_recovery` (до TDR v3) | §6.3, ADR-006 | §2.6 |

### Phase 2 GetTransactionData (16.06.2026, Jira)

| Нода / шаг | Результат | TDR | ТЗ |
|---|---|---|---|
| GTD Input → Execute GetTransactionData | ✓ sub-workflow `BreaksRecovery_GetTransactionData` | §6.4, §7.1, §7.3 | §4.5 шаги 2–3, 7 |
| gtd_01…04 SQL | ✓ ADR-009 фильтр финальных статусов (01.07 rev) | §7.3 | шаги 2–3, 4–5 |
| Assemble Payload | ✓ `$input.all()` (fix 02.07: 1262 items) | §6.4 | шаг 6 |
| Test Agent Selector | ✓ `TEST_LOGINS` для E2E | — | — |
| BE1 / SE1 | ✓ ErrorHandler + Stop | ADR-005 | — |
| E2E smoke (30.06.2026) | ✓ `zvusmanova`, night shift, tx 1396, `in_progress` | — | ночник D+1 |
| **E2E full payload (02.07.2026)** | ✓ **1262** agents, `shift_date` 2026-07-03 | — | после fix Assemble Payload |

### Phase 3 Process — C1–C8 [Completed — RPA-1834]

| Нода / шаг | Результат | TDR | ТЗ |
|---|---|---|---|
| Get Container Scheme | ✓ `proc_01` (PDF №3+№6, test: `schedule_container`, `ssc.day`) | §7.1 | §4.5 шаги 4–6, 8 |
| Get Agent Skills | ✓ `proc_02` (Jira A.3: skill_id, priority, name, time_zone) | §7.1 | шаг 9 |
| Merge Agent Skills | ✓ SKIP_TZ при non-Moscow TZ | — | A.3 v1 |
| Get History 7d | ✓ `proc_03` (PDF №7/№10) | §7.1 | шаг 10 (история) |
| Determine Container Rules | ✓ BE2 + `standard_9hrs` fallback | §6.5 | шаг 8 |
| Calculate News Duration | ✓; ⚠️ паттерн `Night Written Pro…` не в mapping | §6.5 | шаг 9 |
| Get Shift Fact / Plan | ✓ `proc_05` / `proc_04` (usa, PDF №1) | §7.1 | шаг 10 |
| Find Missing Activities | ✓ budget vs fact | — | шаг 10 |
| Calculate Slots | ✓ BE3, `wfms_lines` | — | шаг 11 |
| Init WFMS Batch + Add to Batch | ✓ staticData, TDR §7.2 | §7.2 | шаг 12 |
| Write Transaction | ✓ `proc_07` (BE1→failed, SKIP_TZ→skipped_TZ, BE2/BE3→skipped_*; happy → `in_progress`) | §6.3, ADR-009 | шаг 13 |
| **BE1 Process** | ✓ `Handle Process BE1` + retry×3 на 5 WFM SQL; `.item.json` на error-ветке | ADR-005 | A.1–A.4 |
| Notify Process BE2/BE3 | ✓ параллельная ветка, маскировка login | ADR-005 | BE2/BE3 WARN |
| **E2E n8n (01.07.2026)** | ✓ `zvusmanova`, tx **7775**, BE2/BE3 false, `activities_restored: 0` | — | — |
| **E2E multi-agent (02.07.2026)** | ✓ **2 агента** в одном прогоне | — | см. ниже |

**E2E multi-agent 02.07.2026** (`Test Agent Selector` + `Limit`):

| Агент | tx | `processing_status` | `error_code` | Сценарий |
|---|---:|---|---|---|
| `zvorudzhova.ext` | 21689 | `skipped_BE2` | BE2 | контейнер `тестовая` (нераспознан) |
| `zvusmanova` | 21690 | `success` | — | `Written Pro 22:00 9hrs 10 мин`, `standard_9hrs` |
| `aabazulina` | 20435 | `skipped_BE3` | BE3 | `STR Chat 7:00 12hrs 30 мин`, `standard_12hrs` |

**Тройной E2E 02.07.2026** — все три исхода в одном прогоне ✓ (Write Transaction × 3):

| # | login | tx | status |
|---|---|---:|---|
| 1 | `aabazulina` | 20435 | `skipped_BE3` |
| 2 | `zvorudzhova.ext` | 21689 | `skipped_BE2` |
| 3 | `zvusmanova` | 21690 | `success` |

**Jira DoD E2E Process:** happy path ✓, BE2 ✓, BE3 ✓, multi-agent loop ✓. Остаток: Phase D (deficit/upload), BE1/SKIP_TZ E2E (опц.).

### Phase 3 Process — C1–C3 (16.06.2026)

| Нода / шаг | Результат | TDR | ТЗ |
|---|---|---|---|
| Get Container Scheme | ✓ `proc_01_get_container_scheme.sql` | §7.1 | §4.5 шаги 4–6, 8 |
| Get Agent Skills | ✓ `proc_02` (Jira A.3: skill_id, priority, name, time_zone) | §7.1 | шаг 9 |
| Merge Agent Skills | ✓ SKIP_TZ при non-Moscow TZ | — | A.3 v1 |
| Get History 7d | ✓ `proc_03_get_history_7d.sql` | §7.1 | шаг 10 (история) |
| Determine Container Rules | ✓ BE2 + mappings/container.json | §6.5 | шаг 8 |
| Write Transaction | ✓ `proc_07_update_transaction.sql` (UPDATE) | §6.3, §7.3 | шаг 13 |
| Calculate News / Missing / Slots | ~ заглушки | — | шаги 9–11 |
| E2E на n8n | — после импорта Main + проверка proc_01 на WFM | — | — |

### Phase 2 GET DATA (18.06.2026, WFM test) — legacy WF1-01

| Нода / шаг | Результат | TDR | ТЗ |
|---|---|---|---|
| Get Processed Agents | ✓ 0 на D+1 (`alwaysOutputData`) | §7.3 | §4.5 шаг 3 |
| Continue Phase 2 | ✓ `processed_agents_count: 0` | — | — |
| Get Support Skills | ✓ → Extract Support Skills (mappings) | §6.5 | §4.5 шаг 2* |
| Build WF1 Query | ✓ динамический WF1-01 | §7.1 оп.1 | §4.5 шаг 3 |
| Get Agents D+1 | ✓ **4918** агентов (фильтр fte_groups.json) | §7.1 оп.1 | §4.5 шаг 3 |
| Filter New Agents | ✓ **4918** (полный прогон цепочки) | §7.1 + §7.3 | §4.5 шаг 3 |

\* Навыки из `mappings/fte_groups.json` (TDR v3 §6.5), не из RPA DB.

### Phase 3–5 (каркас)

| Нода / шаг | Результат | TDR | ТЗ |
|---|---|---|---|
| Process loop (шаги 8–13) | ✓ C1–C8 E2E | — | §4.5 шаги 8–13 |
| Write Transaction | ✓ proc_07 UPDATE | §6.3, §7.3 | §4.5 шаг 13 |
| Auth/Upload/Publish WFMS | ❌ Phase D | §7.2 | §4.5 шаги 15–17 |
| Write Upload Status / `success` | ❌ Phase D | §6.3, ADR-009 | §4.5 шаг 18 |
| Send MM Notification | ~ Continue On Error | §7.4 | §4.9 |
| Trigger WF-2 | ✓ | ADR-001 | §4.5 шаг 20 |

---

## Спринт 0 — детализация

### Инфраструктура и настройка

| # | Задача | Результат |
|---|---|---|
| S0-01 | `BreaksRecovery_Main` (Reframework) | ✓ INIT + GTD + Process E2E (01.07) |
| S0-01b | `BreaksRecovery_Balance` (WF-2) | ~ черновик |
| S0-01c | `ErrorHandler` | ✓ JSON; Main errorWorkflow ✓ |
| S0-02 | Credential WFM DB (read-only) | ✓ test |
| S0-03 | Credential RPA DB | ✓ `bpa-primo-test-orch01` |
| S0-04 | Credential Mattermost Bot | — |
| S0-04b | Credential SMTP fallback | — |
| S0-05 | `recovery_transactions` | ✓ |
| S0-06 | `balance_transactions` | ✓ |
| S0-06b | `breaks_balance_moves` | ✓ |
| S0-06c | 6 cfg_* таблиц | ✓ |
| S0-06d | SQL `init_cfg_data.sql` | ✓ |
| S0-06e | Применить SQL на non-prod | ✓ 153/53/77/2/161 (n8n_breaks_recovery) |
| S0-06f | `cfg_email_fallback` данные | — |
| S0-06g | `GetConfig` | ✓ прогнан |
| S0-07 | Cron 05:00 МСК | ✓ |
| S0-11 | Main E2E прогон | ✓ multi-agent 02.07 |
| S0-08 | mappings в Stash (`configuration/test`) | ✓ LoadMappings E2E |
| S0-09 | mTLS non-prod | — не требуется |
| S0-10 | mTLS prod | — |

### Ревизия черновика (встреча 16.06)

| # | Задача | Результат |
|---|---|---|
| R-01 | GetConfig вместо `rpa_config` | ✓ Execute GetConfig |
| R-02 | Validate Config | ~ ✓ в GetConfig; ErrorHandler — |
| R-03 | Credentials RPA / WFM | ~ Write → RPA ✓; Get Agents → WFM ✓ |
| R-04 | Credentials в Balance | — |
| R-05 | Error Handler + Set Edit Fields | — |
| R-06 | BE2/BE3 проброс ошибки | — |
| R-07 | InitTables в каркасе | ✓ прогнан |
| R-08 | WFMS заглушки | ~ удалены из Main (ревью 24.06); Phase 4 пусто до логики 8–12 |
| R-09 | Mattermost через 1С Bot API | ~ Continue On Error |

### Ревизия PR (встреча 24.06, Tretyakova)

| # | Задача | Результат |
|---|---|---|
| T24-01 | Нейминг воркфлоу с префиксом (`BreaksRecovery_2.GetConfig`, …) | ✓ |
| T24-02 | Execute Workflow → from list (`cachedResultName`) | ✓ JSON; перепривязка в n8n UI — |
| T24-03 | Удалить `Restore Config Context` | ✓ Phase 1: GetConfig → LoadMappings → InitTables |
| T24-04 | Удалить HTTP-заглушки WFMS (Auth/Upload/Publish) | ✓ |
| T24-05 | Убрать `CronSchedule` из GetConfig | ✓ Cron только в Main |
| T24-06 | Папки Recovery / Balance в n8n | — UI на инстансе |
| T24-07 | Сжать layout canvas | ~ Phase 1 компактнее |
| T24-08 | Конфиги → `RPA/configuration`, ветка `test`, `BreaksRecovery/Mapping` | ✓ |

---

## Следующие шаги

| # | Задача | Результат |
|---|---|---|
| N-01 | Phase 1 INIT в Main | ✓ E2E non-prod |
| N-02 | ErrorHandler | ✓ JSON |
| N-03 | ErrorHandler в Main | ~ errorWorkflow в settings; Set+Execute на false-ветках — |
| N-04 | Credential WFM DB | ✓ |
| N-05 | SQL агентов D+1 | ✓ test + Main |
| N-06 | `cfg_email_fallback` | — |
| N-07 | HTTP→Git: LoadMappings + GitRawBaseURL | ✓ Stash `RPA/configuration`, ветка `test`, `BreaksRecovery/Mapping` |
| N-13 | LoadMappings E2E (httpRequest, не fetch) | ✓ 18.06; `this.helpers.httpRequest` в Code |
| N-14 | LoadMappings Stash: `?at=refs/heads/`, Basic Auth, Response Text | ✓ 22.06; ветка `test`, `BreaksRecovery/Mapping` |
| N-08 | Схема `n8n_breaks_recovery` + `agents` (ADR-006) | ✓ InitTables + cfg + DROP rpa |
| N-09 | WFM SQL ловушки (ADR-007) | ✓ test: not_erasable, time/timestamp, FTE join, TZ |
| N-10 | Write Transaction + фильтр агентов (ADR-006, ADR-007 §4) | ✓ Main + SQL |
| N-11 | Phase 2 GET DATA E2E (цепочка, не пошагово) | ✓ 4918→4918 test |
| N-12 | Continue Phase 2 + Filter fix (n8n 0 items) | ✓ |
| N-15 | Main canvas layout (nodes + sticky notes без наложений) | ✓ |

---

## Спринт 1 — WF-1: Восстановление

| # | Задача | Результат |
|---|---|---|
| WF1-01 | SQL: агенты на смене D+1 | ✓ test + Main |
| WF1-02 | SQL: расписание + контейнер + схема | ✓ proc_01 |
| WF1-03 | SQL: навыки агента | ✓ proc_02 |
| WF1-04 | SQL: история 7 дней (новости) | ✓ proc_03 |
| WF1-05 | Логика: тип контейнера | ✓ Determine Container Rules |
| WF1-06 | Логика: минуты новостей | ✓ Calculate News Duration |
| WF1-07 | Логика: недостающие активности | ✓ Find Missing + proc_04/05 |
| WF1-08 | Логика: слоты | ✓ Calculate Slots + BE3 |
| WF1-09 | Пакет загрузки | ✓ Init WFMS Batch + Add to Batch |
| WF1-10 | Загрузка в WFMS | ❌ Phase D |
| WF1-11 | Публикация + FTE | ❌ Phase D |
| WF1-12 | Write Transaction (UPDATE после GTD) | ✓ proc_07 |
| WF1-12b | Фильтр агентов по cfg_fte_groups | ✓ Get Support Skills + Build WF1 Query |
| WF1-13 | Mattermost уведомления | ~ Continue On Error |
| WF1-14 | Триггер WF-2 | ✓ |

---

## Спринт 2 — WF-2: Балансировка

| # | Задача | Результат |
|---|---|---|
| WF2-01 | SQL: план/факт FTE | — |
| WF2-02 | Логика: просадки | — |
| WF2-03 | SQL: кандидаты | — |
| WF2-04 | Алгоритм балансировки | — |
| WF2-05 | Пакет переносов | — |
| WF2-06 | Загрузка WFMS (по 1 сотруднику) | — |
| WF2-07 | Write balance transactions | — |
| WF2-08 | Mattermost сводка | — |

---

## Чеклист ИБ (TDR §5.3 «Что делаем сразу»)

> **Легенда:** ✓ — в коде/репо · ~ — частично · — — не сделано / вне кода · **Инфра** — заявка/ИБ, не репозиторий  
> **Обновлено:** 18.06.2026 · Источник: ADR-006, ADR-007, ErrorHandler, TDR §5.2–5.3

| # | Угроза / требование | Мера защиты | Статус | Где / примечание |
|---|---|---|---|---|
| ИБ-01 | SQL-инъекции (login, даты) в WFM DB и RPA DB | Параметризованные запросы (`$1`…), без конкатенации ПДн в SQL | ~ | ✓ Write Transaction, ErrorHandler (`queryReplacement`). — будущие WF1-02…04: login только `$1` |
| ИБ-02 | SQL в Code (динамический WF1-01) | Навыки из cfg (доверенный источник), escape `'` | ~ | Build WF1 Query; не подставлять `agent_login` в строку SQL |
| ИБ-03 | Секреты (LDAP, Bot Token, SMTP) в коде воркфлоу | Только n8n Credentials | ✓ | Main, InitTables, ErrorHandler — credentials в JSON, не в Code |
| ИБ-04 | Утечка ПДн (login) в логи n8n при ошибках | Маскировка перед MM/email; не логировать пакеты в Code | ~ | ✓ ErrorHandler `maskPii()`. — Main: Set+ErrorHandler на BE-ветках — |
| ИБ-05 | ПДн в транзакционных журналах | login только в `agents`; в transactions — `agent_id` | ✓ | ADR-006, Write Transaction |
| ИБ-06 | Ретеншен ПДн | login в `agents` ≤ 6 мес.; транзакции ≤ 12 мес. | ~ | Config `DataRetentionMonths*`; TTL-задача в End Process — |
| ИБ-07 | Перехват трафика (WFMS, Mattermost) | TLS 1.2+, без HTTP | ~ | ✓ URL `https://wfms.avito.ru`, `https://mt.avito.ru`. mTLS prod — **Инфра** (S0-10) |
| ИБ-08 | Запись в WFMS под чужим LDAP | Сервисная УЗ робота, только оргточка «Поддержка» | **Инфра** | Заявка на УЗ; Auth/Upload WFMS — заглушки |
| ИБ-09 | Аудит действий в WFMS | Журналирование в WFMS audit log | **Инфра** | При выдаче сервисной УЗ |
| ИБ-10 | Разделение БД read/write | WFM DB — только SELECT; RPA — INSERT/UPDATE | ✓ | Credentials разведены в Main (WF-05) |
| ИБ-11 | Регистрация обработки ПДн | Платформа регистрации актов удаления ПДн | — | Q-14, ИБ |
| ИБ-12 | Threat modeling | Схема угроз в Confluence/BoardMix | — | Q-13 |

### Правила при следующей разработке (WF1-02…04, Phase 4)

- [ ] WFM-запросы с `agent_login` — **только** `queryReplacement` + `$1` (не `{{ $json.agent_login }}` в теле SQL)
- [x] Пакет загрузки WFMS (шаг 12) — `staticData.wfmsBatch`, не в `processing_comment`
- [ ] Success/Warn MM в Main — маскировка login как в ErrorHandler (или общий helper)
- [ ] Прогон ErrorHandler E2E на test (ручной вход + Error Trigger)
- [ ] Подтвердить сервисную УЗ WFMS и scope «Поддержка» до включения реального Upload

---

## Открытые вопросы

| # | Вопрос | Ответственный | Результат |
|---|---|---|---|
| Q-01 | Названия активностей WFMS | WFM | — блокер |
| Q-02 | Лимиты batch WFMS | WFM | ~ |
| Q-03 | Порог просадки FTE | aakrasyukov | ~ |
| Q-04 | Навыки-исключения новостей | aakazarina | — |
| Q-05 | `skill.time_zone = Europe/Moscow` | WFM / RPA | ✓ test 330/330 |
| Q-06 | Разбивка нестандартных контейнеров | rsramaev | — |
| Q-07 | Goods Голос — копипаст? | aakazarina | — |
| Q-08 | Имена таблиц | — | ✓ |
| Q-09 | Приоритет перемещения WF-2 | aakazarina | — |
| Q-10 | Ночные смены | WFM | — |
| Q-11 | CAP Users группировка | aakazarina | — |
| Q-12 | Confluence Architecture | RPA | — |
| Q-13 | Threat modeling | RPA + ИБ | — |
| Q-14 | Регистрация ПДн | RPA + ИБ | — |
