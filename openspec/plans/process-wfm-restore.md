# План: Process — восстановление перерывов (RPA-1834)

> **Обновлено:** 02.07.2026 (multi-agent E2E ✓; BE3 runbook)
> **Jira:** **RPA-1834** — [BreaksRecovery_Recovery] Process (Получение контекста смены)  
> **Scope:** ТЗ §4.5 шаги 8–13 (полный расчётный цикл A→G, не только контекст смены)  
> **Sprint:** RPA_2026Q3S1_12.07 · **SP:** 2  
> **Основа:** ТЗ §4.5 шаги 8–13, TDR §4.2.1 / §4.3 / §6.1.1 / §6.5 / §7.1, PDF «Инструкция WFM», ADR-007, ADR-009

**Легенда:** ✓ — сделано · ⚠️ — частично / расхождение · ❌ — не сделано · 🔄 — in progress

**Вход:** payload от GetTransactionData (`transaction_id`, `agent_id`, `agent_login`, `shift_date`, `is_night_shift`, `shift_start_msk`, `wfm_user_id`, `mappings`).

**Предусловие:** Jira **GetTransactionData** — ✓ **закрыта** 02.07.2026 (см. `get-transaction-data-process.md`).

---

## Статус спринта Process

| Область | Статус | Комментарий |
|---|---|---|
| Код C1–C8 в repo + Main | ✓ ~96% | логика + SE1 ✓ |
| **12hrs 3×10+1×15** | ✓ | budget 75 = обед 30 + 45 |
| **news missed + absence** | ✓ | proc_03 is_absence, calculateNewsDuration |
| **is_fixed WFM/template** | ✓ | shift_plan.is_fixed + container.json |
| **SE1 Write Transaction** | ✓ | `patch_main_se1.py` |
| **A.3 proc_02 + SKIP_TZ** | ✓ | `proc_02_get_agent_skills.sql`, Merge Agent Skills |
| **BE1 per-agent continue** | ✓ | `Handle Process BE1`, retry×3, 5 WFM nodes; loop payload через `.item.json` (Split In Batches) |
| **E2E smoke n8n** (01.07, zvusmanova) | ✓ **пройден** | loop без SQL-ошибок, happy-path, Write Transaction |
| **E2E multi-agent** (02.07) | ✓ **пройден** | 3 агента: `success` + `skipped_BE2` + `skipped_BE3` |
| **Jira DoD — unit-тесты в репо** (T1–T8 + A.3) | ✓ | `npm test` → 15/15 |
| **Jira DoD — кейсы** (deficit, BE2, BE3, 9hrs…) | ⚠️ | unit ✓; E2E BE2/BE3/multi ✓; deficit — Phase D |
| **Задача RPA-1834** | ✓ **Done** | E2E Process закрыт; Phase D — след. спринт |

---

## Маппинг Jira → реализация

| Jira | ТЗ | Что | SQL / нода | Файл | Статус |
|---|---|---|---|---|---|
| **A.1** | 10 | Факт смены D+1 | proc_05 + proc_04 | `proc_05_get_shift_fact.sql`, `proc_04_get_shift_plan.sql` | ✓ ⚠️ test WFM |
| **A.2** | 8 | Контейнер + паттерн | proc_01 | `proc_01_get_container_scheme.sql` | ✓ ⚠️ test: `schedule_container`, `ssc.day` |
| **A.3** | 9 | Навыки + TZ v1 | proc_02 + Merge Agent Skills | `proc_02_get_agent_skills.sql`, `mergeAgentSkills` | ✓ |
| **A.4** | 9 | История 7 дн. | proc_03 | `proc_03_get_history_7d.sql` | ✓ |
| **B** | 8 | Тип контейнера BE2 | Determine Container Rules | `mappings/container.json` + Code | ✓ E2E |
| **C** | 9 | news_minutes | Calculate News Duration | `news_reading.json` + Code | ✓ absence filter |
| **D** | 10 | факт vs норма | Find Missing Activities | `phase_c_logic.js` | ✓ ⚠️ без unit-тестов |
| **E** | 11 | слоты BE3 | Calculate Slots | `phase_c_logic.js` | ✓ ⚠️ T1 deficit не прогнан |
| **F** | 13 | UPDATE RPA | Write Transaction | `proc_07_update_transaction.sql` | ✓ ⚠️ статусы ADR-009 |
| **G** | 12 | batch WFMS | Init WFMS Batch + Add to Batch | staticData | ✓ |

---

## Расхождения Jira ↔ ADR-009 (зафиксировать в PR)

| Jira DoD | Реализация | Решение |
|---|---|---|
| `processing_status` = Success / Skipped | happy-path → `in_progress`; BE2/BE3 → `skipped_BE2`/`skipped_BE3` | ADR-009: `success` после Phase D (upload) |
| Skipped (generic) | `skipped_BE2`, `skipped_BE3` | Оставляем ADR-009 |
| A.2 SQL из Jira (ss.name, sva…) | test WFM: другие колонки | ADR-007 §5; prod discover |

---

## Definition of Done — чеклист Jira

### RPA UPDATE (шаг F)

| Поле | proc_07 | E2E |
|---|---|---|
| `container_name`, `container_type`, `schedule_pattern` | ✓ | ✓ zvusmanova |
| `news_minutes` | ✓ | ⚠️ 0 (нет паттерна) |
| `activities_restored` | ✓ | ✓ 0 happy-path |
| `processing_end_time` | ✓ BE2/BE3 only | — |
| `processing_status` | ⚠️ ADR-009 | in_progress happy |
| `error_code` BE2/BE3 | ✓ | smoke BE2 false |

### Unit-тесты (типовые кейсы)

| # | Кейс | Статус |
|---|---|---|
| T1 | standard_9hrs: обед 30 + 3×10 + новости | ✓ |
| T2 | standard_12hrs: обед 30 + 3×10 + 15 + новости | ✓ |
| T3 | non-standard fixed («Night 1st line 22:00 ПН 5hrs») | ✓ |
| T4 | news_exception +15 (DE Claim/Billing) | ✓ |
| T5 | BE2 — контейнер не распознан | ✓ |
| T6 | BE3 — нет слота | ✓ |
| T7 | not_erasable — не ставить поверх | ✓ |
| T8 | FTE coverage не влияет | ✓ |
| A.3 | SKIP_TZ при non-Moscow skill TZ | ✓ |

> Запуск: `npm test` в корне репо.

### E2E n8n (test WFM)

| # | Кейс | Статус |
|---|---|---|
| E1 | Happy-path night (`zvusmanova`) | ✓ 01.07, 02.07 (tx 21690) |
| E2 | Deficit перерывов → `wfms_lines` ≠ [] | 🔄 runbook `t1-deficit-e2e.md` |
| E3 | BE2 контейнер | ✓ 02.07 `zvorudzhova.ext` → `skipped_BE2` (tx 21689) |
| E4 | BE3 нет слота | ✓ 02.07 `aabazulina` → `skipped_BE3` (tx 20435, `standard_12hrs`) |
| E5 | Non-standard container из `container.json` | ❌ |
| E6 | Multi-agent loop (2+ агента, разные исходы) | ✓ 02.07 (3 агента: success, BE2, BE3) |

### Прочее DoD

| # | Требование | Статус |
|---|---|---|
| SQL параметризован | ✓ | |
| login маскируется в MM | ~ ErrorHandler | |
| BE1 WFM SQL fail → failed, цикл продолжается | ✓ | `Handle Process BE1` |
| BE2/BE3 → WARN RPA_BN, цикл продолжается | ✓ | |
| SE1 → RPA_Robot_Test_Notifications | ✓ | `Set Process SE1 Error` на Write Transaction |

---

## Порядок работ (закрытие RPA-1834)

| Очередь | Задача | Статус |
|---|---|---|
| 0 | **A.3 proc_02 + SKIP_TZ + BE1** | ✓ |
| 0b | **12hrs + news absence + is_fixed + SE1** | ✓ |
| 1 | Сверка SQL A.1–A.4 с Jira + PDF (prod discover) | ⚠️ |
| 2 | Unit-тесты `phase_c_logic.js` (T1–T8) | ✓ |
| 3 | E2E deficit (T1 / `discover_deficit_agents_d1_fte.sql`) | 🔄 runbook готов |
| 4 | E2E BE2 / BE3 / non-standard | ✓ BE2+BE3+multi 02.07 |
| 5 | news_reading для night-схем | ❌ |
| 6 | Документация + PR + Jira Done | ✓ E2E multi-agent зафиксирован |

---

## E2E multi-agent (02.07.2026)

**Тройной прогон — подтверждён:**

| `agent_login` | tx | `processing_status` | `container_name` |
|---|---:|---|---|
| `aabazulina` | 20435 | `skipped_BE3` | `STR Chat 7:00 12hrs 30 мин` |
| `zvorudzhova.ext` | 21689 | `skipped_BE2` | `тестовая` |
| `zvusmanova` | 21690 | `success` | `Written Pro 22:00 9hrs 10 мин` |

**Настройка Main:**

```
Execute GetTransactionData (1262 items)
  → Test Agent Selector   TEST_LOGINS = ['zvusmanova', 'zvorudzhova.ext', 'aabazulina']
  → Limit (3)
  → Process Each Agent
```

**GTD fix:** `Assemble Payload` — `$input.all()` вместо `$('Attach Transaction Id').all()` (`BreaksRecovery_GetTransactionData.json`).

---

## Как найти логин для BE3 (3-й агент в TEST_LOGINS)

> **Подтверждено 02.07.2026:** `aabazulina` (tx **20435**, day shift 07:00) → `skipped_BE3`, контейнер `STR Chat 7:00 12hrs 30 мин`, `standard_12hrs`.

> **Важно:** dump GTD не содержит факт расписания — BE3 определяется только прогоном Process или SQL к WFM.

### Что такое BE3

Агент с **распознанным** контейнером (не BE2), но **нет сегмента ≥60 мин** с `can_place_break: yes` (типично: смена из одного блока **CSI** или все сегменты `not_erasable`). См. unit-тест T6 в `tests/phase_c_logic.test.js`.

### Способ A — пробный прогон Process (рекомендуется на test WFM)

1. В `Test Agent Selector` оставь **один** кандидат:

```javascript
const TEST_LOGINS = ['aabazulina'];  // или другой login из GTD
```

2. `Limit = 1`, запусти Main до **Write Transaction**.
3. Смотри OUTPUT:
   - `error_code: BE3` + `processing_status: skipped_BE3` → **найден**, добавь в финальный `TEST_LOGINS`
   - `success` или `skipped_BE2` → возьми следующего кандидата

**Кандидаты для перебора** (дневные смены из GTD 02.07, `shift_date` 2026-07-03):

| `agent_login` | `transaction_id` | `shift_start_msk` |
|---|---:|---|
| `aabazulina` | 20435 | 2026-07-03T07:00:00 |
| `aabiryukova` | 20436 | 2026-07-03T06:00:00 |
| `aaglebov` | 20444 | 2026-07-03T14:00:00 |
| `aakhalimullina` | 20452 | 2026-07-03T12:00:00 |

Ночники с `.ext` чаще дают **BE2** (нераспознанный контейнер), не BE3.

### Способ B — нода Calculate Slots

После одиночного прогона открой **Calculate Slots** для кандидата:

- `error_code: BE3` — подтверждение
- `wfms_lines: []` при непустом `activities_to_restore` — дефicit без слота (BE3, не deficit E2E)

### Способ C — WFM SQL (эвристика)

Postgres → **WFM DB**, `shift_date = D+1` (как в GTD). Искать агентов, у которых на смене **одна длинная активность CSI** (≥480 мин) без перерывов/обеда:

```sql
-- Эвристика BE3-кандидат: shift_work_min >= 480 AND только CSI (can_place_break = no)
-- Credential: WFM DB read-only; params: $1 = shift_date (DATE)
-- Уточнять в Process — не гарантия BE3 без прогона
```

Полный discover deficit (не BE3): `workflows/sql/discover_deficit_agents_d1_fte.sql` — для E2 (восстановление), не для BE3.

### Финальный TEST_LOGINS (когда BE3 найден)

```javascript
const TEST_LOGINS = [
  'zvusmanova',        // success
  'zvorudzhova.ext',   // skipped_BE2
  'aabazulina',        // skipped_BE3 — подтверждён 02.07
];
```

`Limit = 3`. Если агенты уже в финальном статусе на D+1 — сброс в RPA DB:

```sql
UPDATE n8n_breaks_recovery.recovery_transactions rt
SET processing_status = 'in_progress',
    error_code = NULL,
    processing_comment = NULL,
    processing_end_time = NULL
FROM n8n_breaks_recovery.agents a
WHERE rt.agent_id = a.id
  AND a.agent_login IN ('zvusmanova', 'zvorudzhova.ext', 'aabazulina')
  AND rt.shift_date = '2026-07-03';
```

---

## Файлы

| Файл | Назначение |
|---|---|
| `workflows/BreaksRecovery_Main.json` | Process loop C1–C8 |
| `workflows/sql/proc_01` … `proc_07` | WFM + RPA SQL |
| `workflows/js/phase_c_logic.js` | эталон B–G |
| `mappings/*.json` | container, news_reading, activity |
| `scripts/sync_main_process.py` | SQL + Code → Main.json перед import n8n |
| `scripts/patch_main_be1.py` | BE1 + SKIP_TZ wiring в Main.json (после sync) |
| `scripts/patch_main_se1.py` | SE1 на Write Transaction (после sync) |
| `workflows/fixtures/process_deficit_pin.template.json` | Pin Data для E2E deficit |
| `openspec/plans/t1-deficit-e2e.md` | пошаговый runbook E2E E2 |
| `tests/phase_c_logic.test.js` | unit-тесты RPA-1834 DoD T1–T8 |
| `package.json` | `npm test` |

---

## Ссылки

| Документ | Для чего |
|---|---|
| `get-transaction-data-process.md` | GTD ✓ закрыта |
| ADR-007 | WFM SQL pitfalls, PDF ↔ SQL |
| ADR-009 | processing_status |
| `openspec/progress.md` | общий трекинг |
