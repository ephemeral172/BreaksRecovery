# T1 — E2E Process с дефicit перерывов (RPA-1834)

> **Цель:** `activities_to_restore` ≠ `[]`; при наличии слотов — `wfms_lines` ≠ `[]`, `activities_restored` > 0.

**Предусловие:** re-import `BreaksRecovery_Main.json` после `python3 scripts/sync_main_process.py` (proc_05 + Code-ноды из `phase_c_logic.js`).

---

## Шаг 0 — Sync repo → n8n

```bash
cd /Users/kj/BreaksRecovery
python3 scripts/sync_main_process.py
```

В n8n: **Import** `workflows/BreaksRecovery_Main.json` (overwrite).

Проверка: **Get Shift Fact** содержит `usa.not_erasable`; **Calculate Slots** — `segmentAllowsPlacement`.

---

## Шаг 1 — Discover агента с дефicit

Postgres-нода → **WFM DB**, SQL: `workflows/sql/discover_deficit_agents_d1_fte.sql`

**Query Parameters** (2 параметра):

```javascript
={{ [
  $('Build Query Params').first().json.shift_date,
  $('Build Query Params').first().json.support_skills
] }}
```

Если ноды Build Query Params нет — временная нода **Set** или вручную:

```javascript
={{ [ '2026-07-03', $('Extract Support Skills').first().json.support_skills ] }}
```

`shift_date` = **D+1 MSK** (как в GTD).

### Выбор строки

| Поле | Критерий |
|---|---|
| `deficit_hint` | `missing_breaks` или `missing_lunch` |
| `break_count` | 0–2 |
| `has_fixed_breaks` | ⚠️ проверить в Process — non-standard fixed → skip_slots |

Записать: `agent_login`, `wfm_user_id`, `shift_date`, `is_night_shift`, `shift_start_msk`.

**Verify (опционально):** `gtd_02_verify_login.sql` — params `$1` shift_date, `$2` login, `$3` support_skills.

| gtd_status | Действие |
|---|---|
| `ok_for_get_agents_d1` | можно полный GTD с фильтром login |
| `no_fte_skill` | только **Pin Data** (вариант A) |
| `no_shift_on_date` | другой login / shift_date |

**Baseline без дефicit:** `zvusmanova` — `activities_to_restore: []` (контроль).

---

## Шаг 2 — RPA: transaction_id + agent_id

Если агент **не** прошёл через GTD сегодня:

1. **Insert** в `recovery_transactions` (как GTD B5) или Pin с существующим `transaction_id`.
2. `agent_id` из `n8n_breaks_recovery.agents` по login.

Либо запустить GTD с фильтром:

```sql
AND u.login = 'CANDIDATE_LOGIN'
```

в Get Agents D+1 (временно, убрать после теста).

---

## Шаг 3 — Pin Data → Process loop

Шаблон: `workflows/fixtures/process_deficit_pin.template.json`

**Pin Data** на вход **Process Each Agent** (первая нода loop после GTD):

```json
{
  "transaction_id": 7780,
  "agent_id": 1396,
  "agent_login": "CANDIDATE_LOGIN",
  "shift_date": "2026-07-03",
  "is_night_shift": false,
  "shift_start_msk": "2026-07-03T09:00:00",
  "wfm_user_id": "uuid-from-discover",
  "mappings": { }
}
```

`mappings` — **целиком** из output **Execute GetTransactionData** или **LoadMappings** (обязательно: `activity`, `container`, `news_reading`, `news_exception_skills`).

Запуск: от **Process Each Agent** до **Write Transaction** (Execute Workflow / Test workflow).

---

## Шаг 4 — Ожидаемый результат

| Нода | Дефicit | BE3 (нет слота) |
|---|---|---|
| **Get Shift Fact** | мало `Перерыв` / нет `Обед` | рабочие сегменты ≥60 мин |
| **Determine Container Rules** | `container_type` ≠ null, не BE2 | — |
| **Find Missing Activities** | `activities_to_restore` **не пуст** | — |
| **Calculate Slots** | `wfms_lines.length` > 0 | `error_code: BE3` |
| **Add to Batch** | `batch_line_count` > 0 | 0 |
| **Write Transaction** | `activities_restored` > 0 | `skipped_BE3` |

---

## Шаг 5 — Зафиксировать (заполнить после прогона)

| Поле | Значение |
|---|---|
| agent_login | |
| shift_date | |
| deficit_hint (discover) | |
| container_type | |
| activities_to_restore | |
| wfms_lines count | |
| error_code | |
| activities_restored (proc_07) | |

После успеха — обновить `openspec/plans/process-wfm-restore.md` (E2E E2) и `openspec/progress.md`.

---

## Troubleshooting

| Симптом | Причина | Действие |
|---|---|---|
| `activities_to_restore: []` | смена уже полная / wrong shift_date | другой login из discover |
| BE2 | контейнер не 9hrs/12hrs/5-2/2-2 и не в container.json | другой агент |
| `skip_slots: fixed_breaks` | non-standard fixed | не T1-slots; выбрать standard |
| BE3 | нет сегмента ≥60 мин «yes» | ок для E4; для E2 нужен агент со слотами |
| BE3 login discover | см. `process-wfm-restore.md` § «Как найти логин для BE3» | способ A: одиночный Process + `Limit=1` |
| `news_minutes: 0` | паттерн не в news_reading | ок для теста перерывов |

---

## SQL-файлы

| Файл | Назначение |
|---|---|
| `discover_deficit_agents_d1.sql` | все агенты с дефicit |
| `discover_deficit_agents_d1_fte.sql` | + фильтр fte_groups |
| `gtd_02_verify_login.sql` | проверка login перед GTD |
