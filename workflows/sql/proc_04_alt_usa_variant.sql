-- PROC-04 alt (legacy): plan через user_schedule_activity.schedule_variant_id
-- Superseded: proc_04_get_shift_plan.sql ($3 schedule_variant_id из proc_01)
-- НЕ работает на test WFM — колонки нет. Оставлен для prod/discover.
-- Params: $1 wfm_user_id, $2 shift_date

WITH agent_variant AS (
  SELECT DISTINCT usa.schedule_variant_id
  FROM public.user_schedule_activity usa
  WHERE usa.user_id = $1::uuid
    AND usa.schedule_variant_id IS NOT NULL
    AND usa.start BETWEEN ($2::date - INTERVAL '1 day') - INTERVAL '3 hours'
                    AND ($2::date + INTERVAL '1 day') - INTERVAL '3 hours'
  LIMIT 1
)
SELECT
  wa.name AS activity_name,
  sva.start AS plan_start_time,
  sva."end" AS plan_end_time,
  (EXTRACT(EPOCH FROM (sva."end" - sva.start)) / 60)::integer AS duration_min
FROM agent_variant av
INNER JOIN public.schedule_variant_activity sva
  ON sva.schedule_variant_id = av.schedule_variant_id
INNER JOIN public.work_activity wa
  ON wa.id = sva.work_activity_id
ORDER BY sva.start;
