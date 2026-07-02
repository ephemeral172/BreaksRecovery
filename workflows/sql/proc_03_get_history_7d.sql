-- PROC-03 / C3: активности за 7 календарных дней до shift_date (новости)
-- Credential: WFM DB read-only
-- Params: $1 = wfm_user_id (UUID text), $2 = shift_date (DATE, D+1)
-- ADR-007: UTC → MSK +3h
-- PDF №7 / №10: user_schedule_activity + work_activity
--
-- Выход: activity_date, activity_name, duration_min, is_absence
-- is_absence: bonus за пропуск новостей только если в день была рабочая активность

SELECT
  ((usa.start + INTERVAL '3 hours')::date) AS activity_date,
  wa.name AS activity_name,
  (EXTRACT(EPOCH FROM (usa."end" - usa.start)) / 60)::integer AS duration_min,
  wa.absence AS is_absence
FROM public.user_schedule_activity usa
INNER JOIN public.work_activity wa
  ON wa.id = usa.work_activity_id
WHERE usa.user_id = $1::uuid
  AND (usa.start + INTERVAL '3 hours')::date >= ($2::date - INTERVAL '7 days')
  AND (usa.start + INTERVAL '3 hours')::date < $2::date
ORDER BY activity_date, activity_name;
