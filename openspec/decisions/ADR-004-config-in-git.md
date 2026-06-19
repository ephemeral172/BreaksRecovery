# ADR-004: Хранение конфигурации в Git, а не в БД

**Дата:** 16.06.2026  
**Статус:** Принято (конвенция команды RPA)  
**Источник:** Вводная встреча 16.06.2026 (Anastasiya Tretyakova)  

## Контекст

Роботу нужны параметры запуска и крупные справочные маппинги. Вопрос: где хранить конфиг?

> Максим (встреча 16.06): «А можем ли мы хранить конфиг просто в отдельной табличке?»  
> Анастасия: «Конфиги мы храним именно в Git. Сначала это JSON, затем Git — чтобы
> вносить изменения через пулреквесты и отслеживать».

TDR v3 (ADR-008): маппинги — в `mappings/*.json` в git, не в БД.

## Решение

**Два слоя в git (TDR v3):**

| Слой | Файл / воркфлоу | Что |
|---|---|---|
| **Runtime** | `mappings/runtime.json` + `GetConfig` | Имена таблиц, batch, retry, cron, URL |
| **Маппинги** | `mappings/*.json` + `LoadMappings` | activity, container, news, FTE, email |

Этапы загрузки:

1. **Старт:** JSON-нода `GetConfig` с шаблоном (`workflows/config/breaks-recovery.config.json`).
2. **Далее:** HTTP к Git для `runtime.json` и mappings (ветка Stash).
3. **LoadMappings** — HTTP GET всех JSON из `GitRawBaseURL`.

После Init обязателен **Validate Config**. При провале → `ErrorHandler`.

## Исторический контекст (до TDR v3)

Ранее маппинги планировались в `cfg_*` таблицах БД. TDR v3 отменяет это — см. ADR-008.

## Последствия

- Параметры запуска и маппинги — через **PR в git**.
- БД RPA — только журналы (`recovery_transactions`, `balance_*`, `agents`).
- Версионирование маппингов — git history, не `updated_at` в SQL.
