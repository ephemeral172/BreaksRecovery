-- PROC-04 alt B (legacy): plan через user_schedule.schedule_variant_id
-- Superseded: proc_04_get_shift_plan.sql (PDF №1 + schedule_variant_activity)
-- Params: $1 wfm_user_id, $2 shift_date
-- НЕ работает на test WFM — таблицы user_schedule нет.

WITH agent_variant AS (
  SELECT us.schedule_variant_id
  FROM public.user_schedule us
  WHERE us.user_id = $1::uuid
    AND us."date" IN ($2::date, ($2::date - INTERVAL '1 day')::date)
    AND us.schedule_variant_id IS NOT NULL
  ORDER BY us."date" DESC
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
