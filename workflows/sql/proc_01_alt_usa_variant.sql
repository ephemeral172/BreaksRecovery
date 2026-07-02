-- PROC-01 alt C (legacy): variant через user_schedule_activity.schedule_variant_id
-- Superseded: proc_01_get_container_scheme.sql (PDF №3 schedule_scheme_container)
-- Params: $1 wfm_user_id, $2 shift_date (ночники: окно как gtd_02)

WITH validity AS (
  SELECT ssvp.schedule_scheme_id
  FROM public.schedule_scheme_validity_period ssvp
  WHERE ssvp.user_id = $1::uuid
    AND $2::date >= ssvp.start_date
    AND (ssvp.end_date IS NULL OR $2::date <= ssvp.end_date)
  ORDER BY ssvp.start_date DESC
  LIMIT 1
),
agent_variant AS (
  SELECT DISTINCT usa.schedule_variant_id
  FROM public.user_schedule_activity usa
  WHERE usa.user_id = $1::uuid
    AND usa.schedule_variant_id IS NOT NULL
    AND usa.start BETWEEN ($2::date - INTERVAL '1 day') - INTERVAL '3 hours'
                    AND ($2::date + INTERVAL '1 day') - INTERVAL '3 hours'
  LIMIT 1
)
SELECT
  ss.name AS schedule_scheme_name,
  sv.name AS schedule_variant_name,
  sv.id::text AS schedule_variant_id
FROM validity v
INNER JOIN public.schedule_scheme ss
  ON ss.id = v.schedule_scheme_id
LEFT JOIN agent_variant av
  ON TRUE
LEFT JOIN public.schedule_variant sv
  ON sv.id = av.schedule_variant_id;
