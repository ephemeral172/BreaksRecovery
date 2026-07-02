-- PROC-05 alt: фактические активности (PDF №2) — user_status_log_history
-- Credential: WFM DB read-only
-- Params: $1 = wfm_user_id, $2 = shift_date (DATE), $3 = is_night_shift (boolean)
--
-- Не используется в WF-1 на D+1 (смена ещё не прошла). Для WF-2 / ретроспективы.
--
-- Выход: activity_name (status_name), start_msk, end_msk, duration_min

SELECT
  us.name AS activity_name,
  to_char(logHistory.start + INTERVAL '3 hours', 'YYYY-MM-DD"T"HH24:MI:SS') AS start_msk,
  to_char(logHistory."end" + INTERVAL '3 hours', 'YYYY-MM-DD"T"HH24:MI:SS') AS end_msk,
  (EXTRACT(EPOCH FROM (logHistory."end" - logHistory.start)) / 60)::integer AS duration_min
FROM public.user_status_log_history logHistory
INNER JOIN public.user_status us
  ON us.id = logHistory.telephony_status_id
WHERE logHistory.user_id = $1::uuid
  AND (
    ($3::boolean = FALSE AND (logHistory.start + INTERVAL '3 hours')::date = $2::date)
    OR (
      $3::boolean = TRUE
      AND (logHistory.start + INTERVAL '3 hours')::date >= ($2::date - INTERVAL '1 day')
      AND (logHistory.start + INTERVAL '3 hours')::date <= $2::date
    )
  )
ORDER BY logHistory.start;
