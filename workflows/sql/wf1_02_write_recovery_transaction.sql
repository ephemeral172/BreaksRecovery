-- WF1-02 / ADR-006: upsert agents + INSERT recovery_transactions (agent_id)
-- Credential: RPA DB ONLY
-- $1 agent_login, $2 shift_date, $3 is_night_shift, $4 error_code, $5 processing_comment
-- n8n Query Parameters (array): {{ [$json.agent_login, $json.shift_date, $json.is_night_shift, $json.error_code || '', $json.processing_comment || ''] }}

WITH input AS (
  SELECT
    $1::varchar AS agent_login,
    $2::date AS shift_date,
    $3::boolean AS is_night_shift,
    NULLIF($4::text, '') AS error_code,
    NULLIF($5::text, '') AS processing_comment
),
upsert_agent AS (
  INSERT INTO n8n_breaks_recovery.agents (agent_login)
  SELECT agent_login FROM input
  ON CONFLICT (agent_login) DO NOTHING
  RETURNING id
),
agent_row AS (
  SELECT id FROM upsert_agent
  UNION ALL
  SELECT a.id
  FROM n8n_breaks_recovery.agents a
  INNER JOIN input i ON a.agent_login = i.agent_login
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
  CASE WHEN i.error_code IS NOT NULL THEN NOW() ELSE NULL END,
  CASE
    WHEN i.error_code IS NULL THEN 'in_progress'
    WHEN i.error_code = 'BE2' THEN 'skipped_BE2'
    WHEN i.error_code = 'BE3' THEN 'skipped_BE3'
    ELSE 'failed'
  END,
  i.processing_comment,
  (SELECT id FROM agent_row),
  i.shift_date,
  i.is_night_shift,
  i.error_code
FROM input i
ON CONFLICT (agent_id, shift_date) DO UPDATE SET
  processing_status = EXCLUDED.processing_status,
  processing_end_time = EXCLUDED.processing_end_time,
  processing_comment = COALESCE(EXCLUDED.processing_comment, recovery_transactions.processing_comment),
  error_code = COALESCE(EXCLUDED.error_code, recovery_transactions.error_code),
  is_night_shift = EXCLUDED.is_night_shift
RETURNING id AS transaction_id, agent_id, processing_status;
