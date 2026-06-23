# ADR-009: Enum `processing_status` (recovery_transactions)

**Дата:** 23.06.2026  
**Статус:** Принято  
**Источник:** Code review PR (Anastasiya Tretyakova), ТЗ §4.5 шаг 3

## Контекст

TDR v3 задаёт `processing_status VARCHAR(100)`, но не перечисляет значения.
ADR-003 (legacy) использовал `calculated` / `loaded` / `skipped` / `error` — устарело.

## Решение

### Значения `recovery_transactions.processing_status`

| Статус | Когда | Повтор в тот же день |
|---|---|---|
| `in_progress` | Write Transaction, старт агента | **Да** |
| `success` | Успешная обработка + upload (TODO шаги 15–18) | **Нет** |
| `skipped_BE2` | Нераспознанный контейнер | **Нет** |
| `skipped_BE3` | Нет слота | **Нет** |
| `failed` | SE / необработанная ошибка (ErrorHandler) | **Да** |

### Get Processed Agents (ТЗ §4.5 шаг 3)

Исключать из выборки D+1 только **финализированные** статусы:

```sql
AND t.processing_status IN ('success', 'skipped_BE2', 'skipped_BE3')
```

`failed` и `in_progress` **не** считаются «уже обработанными».

## Последствия

- `workflows/sql/wf1_01_get_processed_agents.sql` и Main → Get Processed Agents
- ErrorHandler уже использует тот же набор финальных статусов в UPDATE
- `success` будет выставляться при реализации Write Upload Status (Phase 4)

## Связанные документы

- ADR-005 (Error Handler)
- TDR v3 §6.3 (`recovery_transactions`)
