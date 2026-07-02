-- PROC-04 / C5: план смены D+1 (PDF №1 — user_schedule_activity)
-- Credential: WFM DB read-only
-- Params: $1 = wfm_user_id, $2 = shift_date, $3 = schedule_variant_id (ignored on test), $4 = is_night_shift
--
-- test WFM: schedule_variant_activity.work_activity_id НЕТ — шаблон в proc_04_alt_template.sql
-- WF-1: C5 сверяет shift_fact + container budget; shift_plan — диагностика (shift_plan_count).
--
-- Выход: activity_name, start_msk, end_msk, duration_min, plan_source, is_fixed

SELECT
  wa.name AS activity_name,
  to_char(usa.start + INTERVAL '3 hours', 'YYYY-MM-DD"T"HH24:MI:SS') AS start_msk,
  to_char(usa."end" + INTERVAL '3 hours', 'YYYY-MM-DD"T"HH24:MI:SS') AS end_msk,
  (EXTRACT(EPOCH FROM (usa."end" - usa.start)) / 60)::integer AS duration_min,
  'usa'::text AS plan_source,
  FALSE AS is_fixed
FROM public.user_schedule_activity usa
INNER JOIN public.work_activity wa
  ON wa.id = usa.work_activity_id
WHERE usa.user_id = $1::uuid
  AND wa.absence = FALSE
  AND (
    ($4::boolean = FALSE AND (usa.start + INTERVAL '3 hours')::date = $2::date)
    OR (
      $4::boolean = TRUE
      AND (usa.start + INTERVAL '3 hours')::date >= ($2::date - INTERVAL '1 day')
      AND (usa.start + INTERVAL '3 hours')::date <= $2::date
    )
  )
ORDER BY usa.start;
