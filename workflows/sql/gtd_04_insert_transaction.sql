-- GTD-04 / Jira GetTransactionData шаг 5
-- Credential: RPA DB
-- Params: $1 agent_id, $2 shift_date, $3 is_night_shift
-- processing_* обязательны по DDL (TDR §6.3); финальные поля заполняет Process

INSERT INTO n8n_breaks_recovery.recovery_transactions (
  processing_start_time,
  processing_status,
  agent_id,
  shift_date,
  is_night_shift
)
VALUES (NOW(), 'in_progress', $1, $2::date, $3::boolean)
ON CONFLICT (agent_id, shift_date) DO UPDATE
  SET
    is_night_shift = EXCLUDED.is_night_shift,
    processing_status = CASE
      WHEN recovery_transactions.processing_status IN ('success', 'skipped_BE2', 'skipped_BE3', 'skipped_TZ')
        THEN recovery_transactions.processing_status
      ELSE 'in_progress'
    END,
    processing_start_time = CASE
      WHEN recovery_transactions.processing_status IN ('success', 'skipped_BE2', 'skipped_BE3', 'skipped_TZ')
        THEN recovery_transactions.processing_start_time
      ELSE NOW()
    END,
    processing_comment = CASE
      WHEN recovery_transactions.processing_status IN ('success', 'skipped_BE2', 'skipped_BE3', 'skipped_TZ')
        THEN recovery_transactions.processing_comment
      ELSE NULL
    END
RETURNING id AS transaction_id;
