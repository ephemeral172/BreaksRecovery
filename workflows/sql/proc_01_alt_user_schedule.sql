-- PROC-01 alt B (legacy): variant через user_schedule
-- Superseded: proc_01_get_container_scheme.sql (PDF №3 schedule_scheme_container)
-- Params: $1 wfm_user_id, $2 shift_date
-- Если таблицы/колонок нет — см. proc_01_discover.sql блок D

SELECT
  ss.name AS schedule_scheme_name,
  sv.name AS schedule_variant_name,
  sv.id::text AS schedule_variant_id
FROM public.schedule_scheme_validity_period ssvp
INNER JOIN public.schedule_scheme ss
  ON ss.id = ssvp.schedule_scheme_id
INNER JOIN public.user_schedule us
  ON us.user_id = ssvp.user_id
 AND us."date" IN ($2::date, $2::date - INTERVAL '1 day')
INNER JOIN public.schedule_variant sv
  ON sv.id = us.schedule_variant_id
WHERE ssvp.user_id = $1::uuid
  AND $2::date >= ssvp.start_date
  AND (ssvp.end_date IS NULL OR $2::date <= ssvp.end_date)
ORDER BY ssvp.start_date DESC, us."date" DESC
LIMIT 1;
