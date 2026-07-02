-- GTD-01 / GetTransactionData + ADR-009 (ТЗ §4.5 шаг 3)
-- Credential: RPA DB
-- Params: $1 = shift_date (DATE, D+1)
-- Исключить из WFM-выборки агентов с финальными статусами (дневные и ночные).
-- failed / in_progress — не исключаем (повторная обработка в тот же день).

SELECT a.agent_login
FROM n8n_breaks_recovery.recovery_transactions rt
JOIN n8n_breaks_recovery.agents a ON a.id = rt.agent_id
WHERE rt.shift_date = $1::date
  AND rt.processing_status IN ('success', 'skipped_BE2', 'skipped_BE3');
