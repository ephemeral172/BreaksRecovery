-- Discover T1 + fte_groups: дефicit D+1 только среди агентов с FTE-навыком
-- Credential: WFM DB read-only
-- Params:
--   $1 = shift_date (DATE, D+1)
--   $2 = support skill names text[] (как gtd_02 / Extract Support Skills)
--
-- Если $2 = [] — фильтр FTE не применяется (как discover_deficit_agents_d1.sql).

WITH params AS (
  SELECT $1::date AS shift_date
),
activity_msk AS (
  SELECT
    usa.user_id,
    usa.start + INTERVAL '3 hours' AS start_msk,
    usa."end" + INTERVAL '3 hours' AS end_msk,
    wa.name AS activity_name,
    (EXTRACT(EPOCH FROM (usa."end" - usa.start)) / 60)::integer AS duration_min
  FROM public.user_schedule_activity usa
  JOIN public.work_activity wa ON wa.id = usa.work_activity_id
  CROSS JOIN params p
  WHERE usa.start BETWEEN (p.shift_date - INTERVAL '1 day') - INTERVAL '3 hours'
                      AND (p.shift_date + INTERVAL '2 days') - INTERVAL '3 hours'
    AND wa.absence = FALSE
),
candidates AS (
  SELECT
    user_id,
    MIN(start_msk) FILTER (WHERE start_msk::date = (SELECT shift_date FROM params)) AS day_shift_start,
    MIN(start_msk) FILTER (
      WHERE start_msk::date = (SELECT shift_date FROM params) - 1
        AND end_msk::date = (SELECT shift_date FROM params)
    ) AS night_shift_start
  FROM activity_msk
  GROUP BY user_id
),
shift_window AS (
  SELECT
    c.user_id,
    u.login AS agent_login,
    u.id::text AS wfm_user_id,
    p.shift_date,
    (c.night_shift_start IS NOT NULL) AS is_night_shift,
    COALESCE(c.night_shift_start, c.day_shift_start) AS shift_start_msk
  FROM candidates c
  JOIN public."user" u ON u.id = c.user_id
  CROSS JOIN params p
  WHERE (c.day_shift_start IS NOT NULL OR c.night_shift_start IS NOT NULL)
    AND (
      cardinality($2::text[]) = 0
      OR EXISTS (
        SELECT 1
        FROM public.user_skill_mapping usm
        INNER JOIN public.skill sk ON sk.id = usm.skill_id
        WHERE usm.user_id = c.user_id
          AND sk.name = ANY ($2::text[])
      )
    )
),
facts AS (
  SELECT
    sw.agent_login,
    sw.wfm_user_id,
    sw.shift_date,
    sw.is_night_shift,
    to_char(sw.shift_start_msk, 'YYYY-MM-DD"T"HH24:MI:SS') AS shift_start_msk,
    SUM(a.duration_min) FILTER (
      WHERE a.activity_name NOT IN ('Перерыв', 'Обед', 'Обучение (Новости)', 'Отсутствует', 'Больничный', 'Отпуск')
    ) AS work_min,
    COALESCE(SUM(a.duration_min) FILTER (WHERE a.activity_name = 'Обед'), 0) AS lunch_min,
    COUNT(*) FILTER (
      WHERE a.activity_name = 'Перерыв' AND a.duration_min >= 10
    ) AS break_count,
    COALESCE(SUM(a.duration_min) FILTER (WHERE a.activity_name = 'Перерыв'), 0) AS break_total_min,
    COUNT(*) AS usa_rows
  FROM shift_window sw
  JOIN activity_msk a ON a.user_id = sw.user_id
  WHERE (
    (sw.is_night_shift = FALSE AND a.start_msk::date = sw.shift_date)
    OR (
      sw.is_night_shift = TRUE
      AND a.start_msk::date >= sw.shift_date - 1
      AND a.start_msk::date <= sw.shift_date
    )
  )
  GROUP BY sw.agent_login, sw.wfm_user_id, sw.shift_date, sw.is_night_shift, sw.shift_start_msk
)
SELECT
  agent_login,
  wfm_user_id,
  shift_date,
  is_night_shift,
  shift_start_msk,
  work_min,
  lunch_min,
  break_count,
  break_total_min,
  usa_rows,
  CASE
    WHEN work_min >= 480 AND lunch_min < 30 THEN 'missing_lunch'
    WHEN work_min >= 480 AND break_count < 3 THEN 'missing_breaks'
    WHEN work_min >= 480 AND break_total_min < 30 THEN 'low_break_minutes'
    ELSE 'ok_or_short_shift'
  END AS deficit_hint
FROM facts
WHERE work_min >= 480
  AND (lunch_min < 30 OR break_count < 3 OR break_total_min < 30)
ORDER BY break_count ASC, lunch_min ASC, agent_login
LIMIT 50;
