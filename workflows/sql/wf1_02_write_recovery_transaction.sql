-- WF1-02 / ADR-006: upsert agents + INSERT recovery_transactions (agent_id)
-- Credential: RPA DB ONLY
-- ТЗ §4.5 шаг 13; параметры: $1 agent_login, $2 shift_date, $3 is_night_shift, $4 error_code, $5 processing_comment
-- n8n queryReplacement: agent_login, shift_date, is_night_shift, error_code, processing_comment

WITH upsert_agent AS (
  INSERT INTO n8n_breaks_recovery.agents (agent_login)
  VALUES ($1)
  ON CONFLICT (agent_login) DO NOTHING
  RETURNING id
),
agent_row AS (
  SELECT id FROM upsert_agent
  UNION ALL
  SELECT id FROM n8n_breaks_recovery.agents WHERE agent_login = $1
  LIMIT 1
)
INSERT INTO n8n_breaks_recovery.recovery_transactions (
  processing_start_time,
  processing_end_time,
  processing_status,
  processing_comment,
  agent_id,
  shift_date,
  is_night_shift,
  error_code
)
SELECT
  NOW(),
  CASE WHEN NULLIF($4, '') IS NOT NULL THEN NOW() ELSE NULL END,
  CASE
    WHEN NULLIF($4, '') IS NULL THEN 'in_progress'
    WHEN $4 = 'BE2' THEN 'skipped_BE2'
    WHEN $4 = 'BE3' THEN 'skipped_BE3'
    ELSE 'failed'
  END,
  NULLIF($5, ''),
  (SELECT id FROM agent_row),
  $2::date,
  $3::boolean,
  NULLIF($4, '')
ON CONFLICT (agent_id, shift_date) DO UPDATE SET
  processing_status = EXCLUDED.processing_status,
  processing_end_time = EXCLUDED.processing_end_time,
  processing_comment = COALESCE(EXCLUDED.processing_comment, recovery_transactions.processing_comment),
  error_code = COALESCE(EXCLUDED.error_code, recovery_transactions.error_code),
  is_night_shift = EXCLUDED.is_night_shift
RETURNING id AS transaction_id, agent_id, processing_status;
