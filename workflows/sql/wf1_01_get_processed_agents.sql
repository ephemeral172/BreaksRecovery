-- Уже обработанные агенты на D+1 (пропуск ночников, ТЗ §4.5 шаг 3)
-- Credential: RPA DB
-- Использовать в Main перед Filter New Agents

SELECT a.agent_login
FROM n8n_breaks_recovery.agents a
INNER JOIN n8n_breaks_recovery.recovery_transactions t ON t.agent_id = a.id
WHERE t.shift_date = ((NOW() AT TIME ZONE 'Europe/Moscow')::date + 1);
