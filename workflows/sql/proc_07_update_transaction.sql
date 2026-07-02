-- PROC-07 / C7: UPDATE recovery_transactions после Process (INSERT только в GTD B5)
-- Credential: RPA DB ONLY
-- Params:
--   $1 transaction_id, $2 container_name, $3 container_type, $4 schedule_pattern,
--   $5 news_minutes (nullable), $6 error_code, $7 processing_comment, $8 is_night_shift,
--   $9 activities_restored (nullable)
--
-- n8n Query Parameters:
-- {{ [$json.transaction_id, $json.container_name || '', $json.container_type || '',
--     $json.schedule_pattern || '', $json.news_minutes ?? '', $json.error_code || '',
--     $json.processing_comment || '', $json.is_night_shift, $json.activities_restored ?? ''] }}

UPDATE n8n_breaks_recovery.recovery_transactions rt
SET
  container_name = NULLIF($2::text, ''),
  container_type = NULLIF($3::text, ''),
  schedule_pattern = NULLIF($4::text, ''),
  news_minutes = CASE
    WHEN NULLIF($5::text, '') IS NULL THEN rt.news_minutes
    ELSE NULLIF($5::text, '')::integer
  END,
  is_night_shift = COALESCE($8::boolean, rt.is_night_shift),
  activities_restored = CASE
    WHEN NULLIF($9::text, '') IS NULL THEN rt.activities_restored
    ELSE NULLIF($9::text, '')::integer
  END,
  error_code = NULLIF($6::text, ''),
  processing_comment = COALESCE(NULLIF($7::text, ''), rt.processing_comment),
  processing_status = CASE
    WHEN NULLIF($6::text, '') = 'BE2' THEN 'skipped_BE2'
    WHEN NULLIF($6::text, '') = 'BE3' THEN 'skipped_BE3'
    WHEN NULLIF($6::text, '') = 'SKIP_TZ' THEN 'skipped_TZ'
    WHEN NULLIF($6::text, '') IS NOT NULL THEN 'failed'
    ELSE 'success'
  END,
  processing_end_time = NOW()
WHERE rt.id = $1::integer
RETURNING
  rt.id AS transaction_id,
  rt.agent_id,
  rt.processing_status,
  rt.container_name,
  rt.container_type,
  rt.schedule_pattern,
  rt.news_minutes;
