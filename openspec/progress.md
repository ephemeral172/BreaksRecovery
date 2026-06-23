# Progress — BreaksRecovery

> **Легенда:** ✓ — сделано · ✓ *пояснение* — сделано с уточнением · ~ — частично · — — не сделано

**Обновлено:** 16.06.2026 (Main canvas layout: Phase 3/4/5 без наложений)

---

## Прогресс (оценка)

| Область | % | Комментарий |
|---|---:|---|
| **Проект целиком** (WF-1 + WF-2) | **~42** | Фундамент готов; бизнес-логика и WF-2 — впереди |
| **Робот 1 — восстановление** (ТЗ §4.5) | **~50** | INIT + GET DATA закрыты; шаги 4–6, 8–12, 15–18 — нет |
| **Робот 2 — балансировка** | **~5** | Черновик воркфлоу |
| Фаза 0 — каркас (БД, конфиг, InitTables, ADR) | **~98** | Осталось: email_fallback.json, Stash prod |
| Phase 2 GET DATA (test E2E) | **100** | 4918 агентов D+1, Filter 4918→4918 |
| Phase 3 PROCESS — логика 8–11 | **~5** | Code-заглушки |
| Phase 4 UPLOAD WFMS | **~10** | HTTP-заглушки |
| Phase 5 FINISH (MM, WF-2) | **~40** | Trigger WF-2 ✓; MM ~ |

### ТЗ §4.5 Робот 1 — по шагам

| Шаг | Содержание | % |
|---|---|---:|
| 1–2 | Cron, конфиг, mappings/*.json (git) | 100 |
| 3 | Агенты D+1, исключить обработанных | 100 |
| 4–6 | SQL WFM: контейнер, навыки, история 7 дн. | 0 |
| 7 | Loop 1 агент = 1 транзакция | 100 |
| 8–11 | Контейнер, новости, слоты | ~5 |
| 12 | Пакет загрузки | ~5 |
| 13 | Write Transaction | 100 |
| 15–18 | WFMS upload + upload_status | ~10 |
| 18–20 | MM + триггер WF-2 | ~40 |

**Следующий фокус:** WF1-02…04 (SQL шаги 4–6) → Code шаги 8–11 → WFMS upload.

---

## Сводка — Фаза 0

> **Фаза 0:** ~95% · **Фаза 1 GET DATA:** 100% (test) · **Весь проект:** ~42%

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
| WF-02b | `LoadMappings` | ✓ E2E Stash `RPA-1824` (22.06) | §6.5 | — |
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

### Phase 1 INIT (22.06.2026, Stash RPA-1824)

| Нода / шаг | Результат | TDR | ТЗ |
|---|---|---|---|
| Execute GetConfig | ✓ `GitBranch: RPA-1824`, Stash raw URL | §6.5 | §4.5 шаг 1–2 |
| Execute LoadMappings | ✓ 8 JSON из Stash; `mappings.activity` (153), … | §6.5 | — |

### Phase 1 INIT (18.06.2026, TDR v3 + GitHub dev)

| Нода / шаг | Результат | TDR | ТЗ |
|---|---|---|---|
| Cron → Execute GetConfig | ✓ `GitRawBaseURL`, `MappingsPath: mappings` | §6.5 | §4.5 шаг 1–2 |
| Execute InitTables | ✓ 4 табл. (пропуск — БД уже OK) | §6.3, ADR-008 | §2.6 |
| Restore Config Context | ✓ конфиг с GitHub URL | ADR-004 | — |
| Execute LoadMappings | ✓ 8 JSON с GitHub (`activity` 153, `fte_groups` 161, …) | §6.5 | — |

### Phase 1 INIT (17.06.2026, legacy)

| Нода / шаг | Результат | TDR | ТЗ |
|---|---|---|---|
| Execute InitTables | ✓ 10 табл. `n8n_breaks_recovery` (до TDR v3) | §6.3, ADR-006 | §2.6 |

### Phase 2 GET DATA (18.06.2026, WFM test)

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
| Process loop (шаги 8–13) | ~ заглушки Code | — | §4.5 шаги 8–13 |
| Write Transaction | ✓ SQL agents + agent_id (ADR-006) | §6.3, §7.3 | §4.5 шаг 13 |
| Auth/Upload/Publish WFMS | ~ заглушки | §7.2 | §4.5 шаги 15–17 |
| Write Upload Status | ~ placeholder | §6.3 | §4.5 шаг 18 |
| Send MM Notification | ~ Continue On Error | §7.4 | §4.9 |
| Trigger WF-2 | ✓ | ADR-001 | §4.5 шаг 20 |

---

## Спринт 0 — детализация

### Инфраструктура и настройка

| # | Задача | Результат |
|---|---|---|
| S0-01 | `BreaksRecovery_Main` (Reframework) | ~ ✓ INIT+GET DATA E2E; логика 8–11 — заглушки |
| S0-01b | `BreaksRecovery_Balance` (WF-2) | ~ черновик |
| S0-01c | `ErrorHandler` | ✓ JSON; Main errorWorkflow ✓ |
| S0-02 | Credential WFM DB (read-only) | ✓ test |
| S0-03 | Credential RPA DB | ✓ `bpa-primo-test-orch01` |
| S0-04 | Credential Mattermost Bot | — |
| S0-04b | Credential SMTP fallback | — |
| S0-05 | `breaks_recovery_transactions` | ✓ |
| S0-06 | `breaks_balance_transactions` | ✓ |
| S0-06b | `breaks_balance_moves` | ✓ |
| S0-06c | 6 cfg_* таблиц | ✓ |
| S0-06d | SQL `init_cfg_data.sql` | ✓ |
| S0-06e | Применить SQL на non-prod | ✓ 153/53/77/2/161 (n8n_breaks_recovery) |
| S0-06f | `cfg_email_fallback` данные | — |
| S0-06g | `GetConfig` | ✓ прогнан |
| S0-07 | Cron 05:00 МСК | ✓ |
| S0-11 | Main E2E прогон | ✓ |
| S0-08 | mappings в Stash (`RPA-1824`) | ✓ LoadMappings E2E |
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
| R-08 | WFMS заглушки | ✓ |
| R-09 | Mattermost через 1С Bot API | ~ Continue On Error |

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
| N-07 | HTTP→Git: LoadMappings + GitRawBaseURL | ✓ Stash `RPA/n8n`, ветка `RPA-1824` |
| N-13 | LoadMappings E2E (httpRequest, не fetch) | ✓ 18.06; `this.helpers.httpRequest` в Code |
| N-14 | LoadMappings Stash: `?at=refs/heads/`, Basic Auth, Response Text | ✓ 22.06; ветка `RPA-1824`, static data + 8 items |
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
| WF1-02 | SQL: расписание + контейнер + схема | — |
| WF1-03 | SQL: навыки агента | — |
| WF1-04 | SQL: история 7 дней (новости) | — |
| WF1-05 | Логика: тип контейнера | ~ заглушка |
| WF1-06 | Логика: минуты новостей | ~ заглушка |
| WF1-07 | Логика: недостающие активности | ~ заглушка |
| WF1-08 | Логика: слоты | ~ заглушка |
| WF1-09 | Пакет загрузки | ~ заглушка |
| WF1-10 | Загрузка в WFMS | ~ заглушка |
| WF1-11 | Публикация + FTE | ~ заглушка |
| WF1-12 | Write Transaction (реальный INSERT) | ✓ ADR-006 agents + agent_id |
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
- [ ] Пакет загрузки WFMS (шаг 12) — не `console.log` / не писать полный пакет в `processing_comment`
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
