# План реализации: GetTransactionData → Process

> **Обновлено:** 02.07.2026  
> **Основа:** Jira GetTransactionData, ТЗ §4.5 шаги 2–3 и 7, TDR §7.1/7.3, PDF «Инструкция WFM», текущий `BreaksRecovery_GetTransactionData`.

**Легенда:** ✓ — сделано · ⚠️ — частично / требует замены · ❌ — не сделано

---

## Jira GetTransactionData — ✓ закрыта 02.07.2026

| DoD Jira | Статус | Примечание |
|---|---|---|
| Payload для Process (шаг 6) | ✓ | Execute GetTransactionData → Process |
| agents + recovery_transactions | ✓ | INSERT ON CONFLICT, tx 7775 |
| Config + mappings из git | ✓ | LoadMappings |
| Get Agents D+1 (ночник) | ✓ | zvusmanova, `is_night_shift: true` |
| Исключить обработанных (шаг 2) | ✓ ⚠️ | **ADR-009:** `success`, `skipped_BE2`, `skipped_BE3` (не только success night) |
| BE1/SE1, параметризованный SQL | ✓ | GetTransactionData sub-workflow |
| Идempotency / skip success / 5/2·2/2 | ⚠️ | не формализовано в PR-скринах |

**E2E:** n8n test, WFM test, `transaction_id` 7775, `agent_id` 1396, полный `mappings`.

**Следующая Jira:** **RPA-1834** Process → `openspec/plans/process-wfm-restore.md`.

---

## Статус спринта (GTD + Process)


| Область                       | Статус     | Комментарий                                        |
| ----------------------------- | ---------- | -------------------------------------------------- |
| **Фаза B** GetTransactionData | ✓ **100%** | Jira ✓ Done 02.07.2026 |
| **Фаза C** Process C1–C8      | 🔄 **~85%** | код ✓; **E2E smoke ✓**; Jira DoD unit/кейсы — ⚠️ |
| **Фаза D** Upload + Finish    | ❌ **0%**   | после закрытия Process (ADR-009: `success` после upload) |


**Спринт GTD — закончен.** Спринт **RPA-1834** (Process) — in progress.

### E2E Process smoke (01.07.2026, n8n test, WFM test)


| Поле                 | Значение                                                 | Статус              |
| -------------------- | -------------------------------------------------------- | ------------------- |
| Агент                | `zvusmanova`                                             | ✓                   |
| `transaction_id`     | 7775                                                     | ✓                   |
| `shift_date`         | 2026-07-02                                               | ✓ ночник D+1        |
| `shift_start_msk`    | 2026-07-01T23:50:00                                      | ✓                   |
| C1 Container         | scheme + variant (`Written Pro 22:00 9hrs 10 мин`)       | ✓ proc_01 PDF №3+№6 |
| C4 News              | `news_minutes: 0` (паттерн не в `news_reading.json`)     | ⚠️ ожидаемо         |
| C5 Plan/Fact         | 24 строки usa, `plan_source: usa`                        | ✓                   |
| C6 Slots             | `activities_to_restore: []`, `wfms_lines: []`            | ✓ смена уже полная  |
| BE2/BE3              | false branch (`standard_9hrs`)                           | ✓                   |
| C7 Write Transaction | `container_*` записаны, `processing_status: in_progress` | ✓ по ADR-009        |


**Known issues (test WFM vs PDF/.docx):**


| Проблема                                         | Обход на test                                                                        |
| ------------------------------------------------ | ------------------------------------------------------------------------------------ |
| `schedule_variant.name` нет                      | `schedule_container.name` (proc_01)                                                  |
| `schedule_variant.day` нет                       | `schedule_scheme_container.day` (proc_01)                                            |
| `schedule_variant_activity.work_activity_id` нет | proc_04 = только usa (PDF №1); шаблон → `proc_04_alt_template.sql` после discover D4 |
| `user_schedule`, `usa.schedule_variant_id` нет   | не используем legacy alt-пути                                                        |


Сверка схемы: `workflows/sql/proc_01_discover.sql` (блоки D2–D4b). ADR-007 §5 — таблица PDF ↔ SQL.

---

## Фаза A — уже сделано (не трогаем, только сверка)


| #   | Шаг                          | Что                                                                                      | Где сейчас                                                    | Статус    |
| --- | ---------------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------- | --------- |
| A1  | Config + mappings            | GetConfig (шаблон), LoadMappings из Stash `configuration/test`, `BreaksRecovery/Mapping` | `BreaksRecovery_2.GetConfig`, `BreaksRecovery_LoadMappings`   | ✓ E2E     |
| A2  | DDL RPA                      | InitTables: `agents`, `recovery_transactions`, …                                         | `BreaksRecovery_3.InitTables`                                 | ✓         |
| A3  | Каркас Main                  | Phase 1 INIT, From list, без Restore/WFMS                                                | `BreaksRecovery_Main`                                         | ✓         |
| A4  | Write Transaction (прототип) | UPSERT agents + transactions, массив Query Parameters                                    | `Write Transaction` + `wf1_02_write_recovery_transaction.sql` | ✓ 1 агент |
| A5  | ErrorHandler                 | MM 1C API, maskPii, UPDATE failed                                                        | `BreaksRecovery_8.ErrorHandler`                               | ✓ JSON    |


---

## Фаза B — GetTransactionData (новый sub-workflow / блок Main)

Новый sub-workflow: `**BreaksRecovery_GetTransactionData**` (или блок в Main с жёлтой sticky «GetTransaction»).


| #      | Шаг задачи                 | Что делаем                                             | SQL / логика       | PDF WFM                                            | Ноды / артефакт | Зависит от | Статус |
| ------ | -------------------------- | ------------------------------------------------------ | ------------------ | -------------------------------------------------- | --------------- | ---------- | ------ |
| **B0** | Шаг 1: создать процесс     | Воркфлоу `BreaksRecovery_GetTransactionData`           | —                  | `workflows/BreaksRecovery_GetTransactionData.json` | A1              | ✓          |        |
| **B1** | Шаг 2–3: исключить обработанных | `gtd_01_get_processed_agents.sql` (ADR-009) | — | Get Processed Agents | A2 | ✓ |
| **B2** | Шаг 3: агенты D+1          | `gtd_02_agents_d_plus_1.sql` + fte_groups `$3::text[]` | PDF №1, №8         | Get Agents D+1                                     | B1              | ✓          |        |
| **B3** | Фильтр вертикалей          | `ANY($3::text[])` в GTD-02                             | Mapping fte_groups | Prepare GTD Context                                | A1              | ✓          |        |
| **B4** | Шаг 4: upsert agents       | `gtd_03_upsert_agent.sql`                              | —                  | Upsert Agent                                       | B2              | ✓          |        |
| **B5** | Шаг 5: insert transactions | `gtd_04_insert_transaction.sql`                        | —                  | Insert Transaction                                 | B4              | ✓          |        |
| **B6** | Шаг 6: payload             | Assemble Payload + mappings                            | TDR §6.4           | Assemble Payload `$input.all()` (fix 02.07)        | B5              | ✓          |        |
| **B7** | Ошибки BE1/SE1             | Set BE1/SE1 → ErrorHandler                             | ADR-005            | BE1/SE1 ветки                                      | A5              | ✓          |        |
| **B8** | Main: перестройка Phase 2  | Execute GetTransactionData                             | —                  | Main Phase 2                                       | B0–B6           | ✓          |        |


### Формат payload (шаг B6)

```json
{
  "transaction_id": 1,
  "agent_id": 1,
  "agent_login": "...",
  "shift_start_msk": "2026-06-25T09:00:00",
  "is_night_shift": false,
  "shift_date": "2026-06-25",
  "mappings": { "...": "из LoadMappings, один раз" }
}
```

**Fix 02.07.2026 — Assemble Payload:** в `Split In Batches` нельзя читать `$('Attach Transaction Id').all()` — возвращается только последняя итерация (1 item). На Done Branch все items уже собраны → **`const records = $input.all()`**. E2E: **1262** agents на `shift_date` 2026-07-03.

### DoD фазы B

- Массив payload на выходе GetTransactionData
- Строки в `agents` + `recovery_transactions`
- Идемпотентность по `(agent_id, shift_date)`
- Тест-кейсы: дневной 5/2, 2/2, ночной, пропуск ночника
- SQL параметризован (`$1`, `$2`, …)

### E2E smoke (30.06.2026, n8n test)


| Поле                    | Значение                        | Статус                      |
| ----------------------- | ------------------------------- | --------------------------- |
| Агент                   | `zvusmanova`                    | ✓                           |
| `transaction_id`        | 1396                            | ✓ GTD B5                    |
| `is_night_shift`        | true                            | ✓ ночник D+1                |
| `shift_date`            | 2026-07-01                      | ✓                           |
| `shift_start_msk`       | 2026-06-30T22:10:00             | ✓ старт вчера, смена на D+1 |
| RPA `processing_status` | `in_progress`                   | ✓                           |
| Process loop            | до BE2/BE3 Check (false branch) | ✓ C4–C8                     |

### E2E full payload (02.07.2026, n8n test)

| Поле | Значение | Статус |
|---|---|---|
| Агентов на выходе GTD | **1262** | ✓ после fix Assemble Payload |
| `shift_date` | 2026-07-03 | ✓ |
| Test Agent Selector | 2 items (`zvusmanova`, `zvorudzhova.ext`) | ✓ multi-agent E2E |
| Process multi-agent | `success` + `skipped_BE2` | ✓ см. `process-wfm-restore.md` |

---
**Credentials (GetTransactionData):** Get Agents D+1 → **WFM DB**; Upsert/Insert → **RPA DB**; LoadMappings Fetch → **Stash Basic Auth**.

**Known issues:**

- Изолированный запуск GTD без входа от LoadMappings — пустой `support skills` (нужен Pin Data или запуск через Main).
- n8n сериализует DATE как UTC ISO (`2026-06-30T21:00:00.000Z` для `2026-07-01`) — артефакт отображения, не баг БД.
- Trigger WF-2: `sub-workflow cannot be called` — caller policy / перепривязка Balance (не GTD).
- Не проверено на test: идемпотентность повторного GTD, skip финализированных агентов (B1, ADR-009).

---

## Фаза C — Process (логика 8–11, в loop по payload)


| #      | ТЗ шаг       | Что делаем               | WFM SQL (PDF)                                  | Ноды                                                   | Статус     |
| ------ | ------------ | ------------------------ | ---------------------------------------------- | ------------------------------------------------------ | ---------- |
| **C1** | 4–6 / шаг 8  | Контейнер/схема агента   | PDF №3+№5+№6 (`schedule_scheme_container`)     | `Get Container Scheme` + `Determine Container Rules`   | ✓ E2E test |
| **C2** | 4–6 / шаг 9  | Навыки агента            | `user_skill_mapping` + `skill`                 | `Get Agent Skills` + `Merge Agent Skills`              | ✓ SQL      |
| **C3** | 4–6 / шаг 10 | История 7 дней (новости) | PDF №1 период / №8                             | `Get History 7d` + `Merge History 7d`                  | ✓ SQL      |
| **C4** | 9            | Минуты новостей          | —                                              | `Calculate News Duration` + Mapping                    | ✓          |
| **C5** | 10           | План vs факт             | PDF №1 usa (plan + fact D+1); PDF №2 → alt     | `Get Shift Plan/Fact` + `Find Missing Activities`      | ✓ E2E test |
| **C6** | 11           | Слоты, BE2/BE3           | —                                              | `Calculate Slots`, `BE2/BE3 Check`                     | ✓          |
| **C7** | 13           | UPDATE transaction       | `container_`*, `news_minutes`, BE2/BE3 статусы | `Write Transaction` → `proc_07_update_transaction.sql` | ✓          |


**proc_07 / ADR-009:** happy-path **не** ставит `success` — только `in_progress` до Phase D (upload или пустой batch). BE2 → `skipped_be2`, BE3 → `skipped_be3` + `processing_end_time`.

| **C8** | 12 | Пакет WFMS | TDR §7.2 JSON | `Init WFMS Batch` + `Add to Batch` | ✓ |

> После GetTransactionData **Write Transaction в loop** меняется на **UPDATE** финальных полей транзакции, созданной в B5.

---

## Фаза D — Upload + Finish (позже)


| #   | Шаг   | Что                                     | Статус                  |
| --- | ----- | --------------------------------------- | ----------------------- |
| D1  | 15–18 | WFMS upload (не HTTP-заглушки, LDAP UI) | ❌ убрано по ревью 24.06 |
| D2  | 18–20 | MM Success/Warn, Trigger WF-2           | ~ заглушка MM           |


---

## Порядок работ (спринт GTD + Process) — ✓ закрыт 01.07.2026


| Очередь | Задача                                         | Статус             |
| ------- | ---------------------------------------------- | ------------------ |
| 1       | B0 + B1 + B2 (SQL + sub-workflow каркас)       | ✓                  |
| 2       | B4 + B5 + B6 (RPA writes + payload)            | ✓                  |
| 3       | B7 + B8 (Main rewire, BE1/SE1, тесты D+1)      | ✓                  |
| 4       | C1 + C2 (контейнер + навыки)                   | ✓                  |
| 5       | C3–C6 (новости, plan/fact, слоты)              | ✓                  |
| 6       | C7–C8 (UPDATE + batch)                         | ✓                  |
| 7       | **D1–D2** (WFMS upload, финализация `success`) | ❌ следующий спринт |


---

## Что меняем в Main


| Сейчас                             | Станет                            |
| ---------------------------------- | --------------------------------- |
| Get Processed Agents (ADR-009) | → B1 (`success`, `skipped_BE2`, `skipped_BE3`) |
| Build WF1 Query + Get Agents D+1   | → B2 (новый SQL из Jira)          |
| Filter New Agents                  | → не нужен (фильтр в B2)          |
| Write Transaction INSERT в loop    | → B5 INSERT + Process UPDATE (C7) |
| Limit-нода для теста               | → оставить для отладки B2–B5      |


---

## Файлы, которые появятся / изменятся


| Файл                                               | Назначение                                              |
| -------------------------------------------------- | ------------------------------------------------------- |
| `workflows/BreaksRecovery_GetTransactionData.json` | новый sub-workflow                                      |
| `workflows/sql/gtd_01_get_processed_agents.sql`      | шаг B1 (ADR-009)                                                  |
| `workflows/sql/gtd_02_agents_d_plus_1.sql`         | шаг B2                                                  |
| `workflows/sql/gtd_03_upsert_agent.sql`            | шаг B4                                                  |
| `workflows/sql/gtd_04_insert_transaction.sql`      | шаг B5                                                  |
| `workflows/sql/proc_01_get_container_scheme.sql`   | C1                                                      |
| `workflows/sql/proc_02_get_agent_skills.sql`       | C2                                                      |
| `workflows/sql/proc_03_get_history_7d.sql`         | C3                                                      |
| `workflows/sql/proc_07_update_transaction.sql`     | C7 UPDATE                                               |
| `workflows/sql/proc_04_get_shift_plan.sql`         | C5 plan (usa, PDF №1)                                   |
| `workflows/sql/proc_04_alt_template.sql`           | C5 plan-шаблон (prod, после discover D4)                |
| `workflows/sql/proc_05_get_shift_fact.sql`         | C5–C6 fact (usa D+1)                                    |
| `workflows/sql/proc_05_alt_status_log.sql`         | PDF №2 fact (legacy/WF-2)                               |
| `workflows/sql/proc_01_discover.sql`               | discover схемы WFM test/prod                            |
| `workflows/js/phase_c_logic.js`                    | эталон C4–C8                                            |
| `workflows/BreaksRecovery_Main.json`               | Phase 2 → Execute GetTransactionData; Phase 3 WFM C1–C8 |
| `openspec/progress.md`                             | статусы B/C                                             |


---

## Ссылки на документы


| Документ                                                   | Для чего                                          |
| ---------------------------------------------------------- | ------------------------------------------------- |
| Jira GetTransactionData                                    | **источник правды** для B2–B6                     |
| `Инструкция по взаимодействию с WFM.pdf`                   | шаблоны SQL, UTC+3, ночные смены, доступы         |
| ADR-007 (`openspec/decisions/ADR-007-wfm-sql-pitfalls.md`) | `not_erasable`, `time` vs `timestamp`, fte_groups |
| Stash Mapping `BreaksRecovery/Mapping/*`                   | fte_groups, activity, container                   |
| ADR-005                                                    | BE1/SE1, ErrorHandler                             |
| ADR-009                                                    | enum `processing_status`                          |


---

## Следующий спринт (Phase D + доработки)


| #   | Задача                                                                      | Зависимость                    |
| --- | --------------------------------------------------------------------------- | ------------------------------ |
| D1  | WFMS upload (шаги 15–17), сервисная УЗ                                      | заявка LDAP                    |
| D2  | Финализация `processing_status = success` + `processing_end_time` (ADR-009) | после upload или пустого batch |
| D3  | MM Success/Warn, Trigger WF-2 (шаги 18–20)                                  | D1                             |
| T1  | E2E с **дефицитом** перерывов (агент с затёртыми breaks)                    | test WFM                       |
| T2  | E2E с контейнером из `container.json` (non-standard budget)                 | test WFM                       |
| T3  | Маппинг `news_reading` для схем типа `Night Written Pro …`                  | mappings                       |


**DoD Phase C (факт):** loop Process на n8n без SQL-ошибок; BE2/BE3 ветки работают; happy-path без восстановления подтверждён (`zvusmanova`). **Не проверено:** восстановление + upload + `success`.