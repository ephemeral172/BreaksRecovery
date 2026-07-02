-- CANONICAL: см. gtd_01_get_processed_agents.sql (GetTransactionData)
-- Дубликат для справки / legacy Main; логика идентична GTD-01 + ADR-009
-- Credential: RPA DB
-- ADR-009: только финализированные success / skipped_BE2 / skipped_BE3
-- failed / in_progress — повторная обработка в тот же день

SELECT a.agent_login
FROM n8n_breaks_recovery.agents a
INNER JOIN n8n_breaks_recovery.recovery_transactions t ON t.agent_id = a.id
WHERE t.shift_date = ((NOW() AT TIME ZONE 'Europe/Moscow')::date + 1)
  AND t.processing_status IN ('success', 'skipped_BE2', 'skipped_BE3');
