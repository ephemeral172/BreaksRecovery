# ADR-006: Схема `n8n_breaks_recovery` и вынос ПДн в `agents`

**Дата:** 17.06.2026  
**Статус:** Принято  
**Источник:** Встреча RPA 17.06.2026 (Anastasiya Tretyakova)  

> **Имена таблиц (ADR-008):** `recovery_transactions` (было `breaks_recovery_transactions`), `balance_transactions` (было `breaks_balance_transactions`). `breaks_balance_moves` без изменений.

## Контекст

1. Конвенция команды RPA: схема робота в БД RPA Data называется по имени воркфлоу/проекта, не `rpa`.
2. Требование ИБ: персональные данные (логины агентов) не хранить в транзакционных журналах.
3. TDR §6.3 ещё описывает `agent_login` в `recovery_transactions` — документ отстаёт от решения на встрече.

## Решение

### Схема БД

- Заменить `rpa` → **`n8n_breaks_recovery`** во всех DDL, DML, конфиге и воркфлоу.
- Схема **`rpa` не используется** — это черновик первого прогона InitTables (тестовые таблицы + cfg_*). Данные не мигрируем; на non-prod схему **удаляем** после прогона нового InitTables и заливки cfg_*.

### Удаление legacy-схемы (one-time, non-prod)

```sql
DROP SCHEMA IF EXISTS rpa CASCADE;
```

Скрипт: `workflows/sql/drop_legacy_rpa_schema.sql`. Запускать **после** InitTables + `init_cfg_data.sql` в `n8n_breaks_recovery`.

### Таблица `agents` (ПДн)

```sql
CREATE TABLE n8n_breaks_recovery.agents (
    id          SERIAL PRIMARY KEY,
    agent_login VARCHAR(100) NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### Транзакционные таблицы

- `recovery_transactions`: `agent_login` → **`agent_id INTEGER NOT NULL REFERENCES agents(id)`**
- `breaks_balance_moves`: `agent_login` → **`agent_id INTEGER NOT NULL REFERENCES agents(id)`**
- UNIQUE/индексы переписаны на `agent_id`.

### Порядок InitTables

```
схема → agents → recovery_transactions → balance_transactions
     → breaks_balance_moves → cfg_* (6 таблиц) → проверка
```

### Паттерн записи в прикладных воркфлоу (WF-1 / WF-2)

```sql
INSERT INTO n8n_breaks_recovery.agents (agent_login)
VALUES ($1)
ON CONFLICT (agent_login) DO NOTHING;

SELECT id AS agent_id
FROM n8n_breaks_recovery.agents
WHERE agent_login = $1;

-- затем INSERT/UPDATE в recovery_transactions / breaks_balance_moves с agent_id
```

InitTables **только создаёт структуру**, заполнение `agents` — ответственность Main/Balance.

### Конфиг (ADR-004)

Добавить поле `DBTableNameAgents: "agents"`.

## Последствия

- Обновить `BreaksRecovery 3. InitTables`, config, `init_cfg_data.sql`, Main, ErrorHandler, `project.md`.
- Перезалить cfg_* в `n8n_breaks_recovery` на non-prod после прогона InitTables.
- Запросить обновление TDR §6.3 (отдельная задача документации).
