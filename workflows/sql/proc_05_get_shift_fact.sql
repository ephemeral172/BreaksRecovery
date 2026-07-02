-- PROC-05 / C5–C6: текущее расписание агента на D+1 (timeline для слотов и сверки)
-- Credential: WFM DB read-only
-- Params: $1 = wfm_user_id, $2 = shift_date (DATE), $3 = is_night_shift (boolean)
-- ADR-007: UTC → MSK +3h; absence = false
--
-- WF-1 на D+1: «факт» = содержимое user_schedule_activity (что сейчас в сетке после бота).
-- PDF №2 (user_status_log_history) — телефония/статусы прошедших смен; см. proc_05_alt_status_log.sql
--
-- Выход: activity_name, start_msk, end_msk, duration_min

SELECT
  wa.name AS activity_name,
  to_char(usa.start + INTERVAL '3 hours', 'YYYY-MM-DD"T"HH24:MI:SS') AS start_msk,
  to_char(usa."end" + INTERVAL '3 hours', 'YYYY-MM-DD"T"HH24:MI:SS') AS end_msk,
  (EXTRACT(EPOCH FROM (usa."end" - usa.start)) / 60)::integer AS duration_min,
  usa.not_erasable AS not_erasable
FROM public.user_schedule_activity usa
INNER JOIN public.work_activity wa
  ON wa.id = usa.work_activity_id
WHERE usa.user_id = $1::uuid
  AND wa.absence = FALSE
  AND (
    ($3::boolean = FALSE AND (usa.start + INTERVAL '3 hours')::date = $2::date)
    OR (
      $3::boolean = TRUE
      AND (usa.start + INTERVAL '3 hours')::date >= ($2::date - INTERVAL '1 day')
      AND (usa.start + INTERVAL '3 hours')::date <= $2::date
    )
  )
ORDER BY usa.start;
