# ADR-008: Маппинги в Git JSON (TDR v3)

**Дата:** 18.06.2026  
**Статус:** Принято  
**Источник:** TDR v3.pdf (разделы 6.3, 6.5, 7.3)

## Контекст

TDR v2 / TDR New описывали справочники в таблицах `cfg_*` схемы `n8n_breaks_recovery`.
TDR v3 переносит все маппинги в git-репозиторий команды RPA в формате JSON.

## Решение

### БД RPA (`n8n_breaks_recovery`) — только 4 таблицы

| Таблица | Назначение |
|---|---|
| `agents` | ПДн: `agent_login` |
| `recovery_transactions` | Журнал Робот 1 (было `breaks_recovery_transactions`) |
| `balance_transactions` | Журнал Робот 2 (было `breaks_balance_transactions`) |
| `breaks_balance_moves` | Детали переносов WF-2 |

### Маппинги — `mappings/*.json` в git

| Файл | Было (cfg_*) |
|---|---|
| `activity.json` | `cfg_activity_mapping` |
| `container.json` | `cfg_non_standard_containers` |
| `news_reading.json` | `cfg_news_reading` |
| `news_exception_skills.json` | `cfg_news_exception_skills` |
| `fte_groups.json` | `cfg_fte_groups` |
| `email_fallback.json` | `cfg_email_fallback` |
| `fte_thresholds.json` | *(новый, WF-2)* |
| `runtime.json` | *(новый, параметры исполнения)* |

Путь в Stash: `BreaksRecovery_Main/mappings/` (репозиторий `projects/RPA/repos/n8n`).

### Загрузка в n8n

1. `GetConfig` — runtime-параметры, имена таблиц, `GitRawBaseURL`, `MappingsPath`
2. `LoadMappings` — HTTP GET всех JSON из git
3. Main хранит `mappings` в контексте выполнения (`Continue Phase 2`)

## Последствия

- `InitTables` создаёт 4 таблицы, не 10
- `InitCfgData` / `init_cfg_data.sql` — **legacy** (данные → `mappings/*.json`)
- Миграция существующей БД: `workflows/sql/migrate_tdr_v3.sql`
- До настройки `GitRawBaseURL` Phase 1 падает на `LoadMappings` — ожидаемо

## Связанные ADR

- ADR-004 уточнён: Git-конфиг = `GetConfig` + `runtime.json`; маппинги = отдельные JSON в git
- ADR-006 без изменений по `agents` / `agent_id`
