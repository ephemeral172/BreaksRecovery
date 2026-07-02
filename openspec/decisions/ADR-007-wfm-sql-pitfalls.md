# ADR-007: WFM SQL — технические ловушки

**Дата:** 17.06.2026  
**Статус:** Принято  
**Источник:** Ревью TDR / .docx WFM (тимлид), TDR New  

## Контекст

Описание БД WFM в TDR/.docx покрывает потребности робота, но три момента ломают SQL при невнимательной реализации.

## Решение

### 1. `not_eraseble` ≠ `not_erasable` (TDR/.docx) — сверка с test

| Источник | Таблица | Поле в документации |
|---|---|---|
| TDR / .docx | `user_schedule_activity` | `not_eraseble` (e-r-a-s-e-b-l-e) |
| TDR / .docx | `work_activity` | `not_erasable` (e-r-a-s-a-b-l-e) |

**Факт на `wfm-test-avito.dc.oswfm.ru` (17.06.2026):**

| Проверка | Результат |
|---|---|
| Колонка `not_eraseble` | **Нигде нет** — везде `not_erasable` |
| `user_schedule_activity.not_erasable` | только `false` (≈29.7M строк) |
| `work_activity.not_erasable` | `false` = 153 типов, `true` = 137 типов |
| FTE join `queue→skill←skill_fte` | OK (`LIMIT 1`) |
| `skill.time_zone` | 100% `Europe/Moscow` (330) |

**Семантика `not_erasable` (интерпретация для робота, сверить с WFM):**

- `not_erasable = true` → активность **нельзя затирать/трогать** (защищённый тип в `work_activity`)
- `not_erasable = false` → тип **можно** менять в рамках правил робота

На уровне `user_schedule_activity` флаг всегда `false` на test — **фильтр «не трогать» делаем через JOIN `work_activity`** по `work_activity_id`, не только по полю usa.

```sql
INNER JOIN work_activity wa ON wa.id = usa.work_activity_id
WHERE wa.not_erasable = false   -- кандидаты для восстановления; true — пропуск
```

Перед prod — подтвердить у aakazarina / WFM.

### 2. `schedule_variant*.start/end` — тип `time`; `user_schedule_activity` — `timestamp`

На test (17.06.2026):
- `schedule_variant`, `schedule_variant_activity` → **`time without time zone`**
- `user_schedule_activity.start/end` → **`timestamp without time zone`** (не timestamptz)
- **`schedule_variant.name` на test нет** — имя контейнера брать из **`schedule_container.name`**, иначе fallback `start-end` (см. `proc_01`)
- **`schedule_variant.day` на test нет** — день ротации в **`schedule_scheme_container.day`** (PDF №6)
- **`schedule_variant_activity.work_activity_id` на test нет** — plan через **usa** (`proc_04`); шаблон — `proc_04_alt_template.sql` после discover D4

Шаблон смены — время суток **без даты**. Нельзя сравнивать напрямую с `user_schedule_activity.start`.

При расчёте «положенных» перерывов (нода **Determine Container Rules**):

```sql
-- shift_date = D+1 (DATE)
(shift_date + schedule_variant.start)::timestamptz AT TIME ZONE 'Europe/Moscow'
```

Точная формула зависит от TZ агента — сверить с `skill.time_zone` и `zone_validity_period.user_zone` (Q-05).

### 3. Цепочка план↔факт FTE (Робот 2)

Прогноз и факт связаны через навык:

```
queue_forecast.queue_id → queue.id
queue.skill_id          → skill.id
skill_fte.skill_id      → skill.id
```

Карта покрытия: **`queue_forecast → queue → skill ← skill_fte`**.

В SQL WF-2 джойн записать явно; не джойнить `queue_forecast` напрямую к `skill_fte` без `queue`.

### Открытые вопросы (.docx подтверждает кандидатов)

| # | Поле | Назначение |
|---|---|---|
| Q-03 | `skill.max_flaw` (integer, «Недостаток FTE») | Кандидат на порог просадки |
| Q-05 | `zone_validity_period.user_zone` | Персональная TZ агента; для v1 — исключать или учитывать |

### 4. Фильтр агентов поддержки (WF1-01)

**Проблема:** на test WFM без фильтра WF1-01 возвращает **~13833** синтетических логинов (`4e14`…); на prod ожидается **~2000** агентов поддержки.

**Решение:** scope робота = линии из `cfg_fte_groups` (+ `cfg_news_exception_skills`):

1. **Get Support Skills** (RPA DB) — `SELECT DISTINCT skill_name FROM cfg_fte_groups UNION …`
2. **Build WF1 Query** (Code) — подставляет список в CTE `support_skills`
3. **Get Agents D+1** (WFM) — `EXISTS (user_skill_mapping → skill.name IN support_skills)`

Оргточка WFMS «Поддержка» — контекст **загрузки** (§7.2), не SQL-фильтр в §7.1. На test синтетика без навыков поддержки отсекается автоматически.

**n8n:** при 0 строк Postgres-нода не передаёт items дальше. В Main: `alwaysOutputData` на **Get Processed Agents** + нода **Continue Phase 2** (линейная цепочка без тупика).

### 5. Соответствие PDF «Инструкция WFM» (Process SQL)

| PDF № | Задача | Файл WF-1 | Примечание |
|---|---|---|---|
| 1 | Запланированные активности на дату | `proc_04` (fallback без variant_id) | `user_schedule_activity` |
| 2 | Фактические активности (телефония) | `proc_05_alt_status_log.sql` | Не на D+1; WF-1 использует usa в `proc_05` |
| 3–6 | Схема + variant контейнера | `proc_01` | `schedule_scheme_container` → `schedule_variant` |
| 7–10 | История / плановая длительность | `proc_03` | `user_schedule_activity` |

Legacy alt-файлы (`proc_*_alt_*`) сохранены для discover/prod-сверки, основной путь — PDF.

## ИБ (требования тимлида)

- Postgres-ноды: **параметризованные запросы** (`$1`, `$2`), без конкатенации пользовательских данных в SQL.
- Секреты — только n8n Credentials.
- Логины/ПДн в сообщениях MM/email — **маскировать** перед отправкой.
- Внешние вызовы — TLS 1.2+, без HTTP.

## Последствия

- Проверочные SELECT-ы на WFM test — блокер перед Phase 1 GET DATA.
- Зафиксировать в `project.md` § WFM SQL.
- ErrorHandler и все DML-ноды — параметризация + маскировка ПДн.
