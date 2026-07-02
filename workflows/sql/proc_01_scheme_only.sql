-- PROC-01 fallback: только schedule_scheme (без variant) — всегда пробуй блок E discover
-- Params: $1 wfm_user_id, $2 shift_date

SELECT
  ss.name AS schedule_scheme_name,
  NULL::text AS schedule_variant_name,
  NULL::text AS schedule_variant_id
FROM public.schedule_scheme_validity_period ssvp
INNER JOIN public.schedule_scheme ss
  ON ss.id = ssvp.schedule_scheme_id
WHERE ssvp.user_id = $1::uuid
  AND $2::date >= ssvp.start_date
  AND (ssvp.end_date IS NULL OR $2::date <= ssvp.end_date)
ORDER BY ssvp.start_date DESC
LIMIT 1;
