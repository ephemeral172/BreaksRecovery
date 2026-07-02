-- GTD-02 verify: пройдёт ли login через Get Agents D+1 (shift + fte_groups)
-- Credential: WFM DB read-only
-- Params: $1 shift_date (DATE D+1), $2 login, $3 support skill names (text[])
--
-- Использование: перед T1 / ручным фильтром AND u.login = '...'

WITH activity_msk AS (
  SELECT
    usa.user_id,
    usa.start + INTERVAL '3 hours' AS start_msk,
    usa."end" + INTERVAL '3 hours' AS end_msk
  FROM public.user_schedule_activity usa
  JOIN public.work_activity wa ON wa.id = usa.work_activity_id
  WHERE usa.start BETWEEN ($1::date - INTERVAL '1 day') - INTERVAL '3 hours'
                      AND ($1::date + INTERVAL '2 days') - INTERVAL '3 hours'
    AND wa.absence = FALSE
),
candidates AS (
  SELECT
    user_id,
    MIN(start_msk) FILTER (WHERE start_msk::date = $1::date) AS day_shift_start,
    MIN(start_msk) FILTER (
      WHERE start_msk::date = $1::date - 1
        AND end_msk::date = $1::date
    ) AS night_shift_start
  FROM activity_msk
  GROUP BY user_id
),
agent_row AS (
  SELECT
    u.id::text AS wfm_user_id,
    u.login AS agent_login,
    to_char(
      COALESCE(c.night_shift_start, c.day_shift_start),
      'YYYY-MM-DD"T"HH24:MI:SS'
    ) AS shift_start_msk,
    (c.night_shift_start IS NOT NULL) AS is_night_shift,
    to_char($1::date, 'YYYY-MM-DD') AS shift_date,
    EXISTS (
      SELECT 1
      FROM public.user_skill_mapping usm
      INNER JOIN public.skill sk ON sk.id = usm.skill_id
      WHERE usm.user_id = u.id
        AND sk.name = ANY ($3::text[])
    ) AS has_fte_skill
  FROM candidates c
  JOIN public."user" u ON u.id = c.user_id
  WHERE u.login = $2::text
    AND (c.day_shift_start IS NOT NULL OR c.night_shift_start IS NOT NULL)
)
SELECT
  agent_login,
  wfm_user_id,
  shift_date,
  is_night_shift,
  shift_start_msk,
  has_fte_skill,
  CASE
    WHEN agent_login IS NULL THEN 'no_shift_on_date'
    WHEN has_fte_skill = FALSE THEN 'no_fte_skill'
    ELSE 'ok_for_get_agents_d1'
  END AS gtd_status
FROM agent_row
UNION ALL
SELECT
  $2::text,
  NULL,
  to_char($1::date, 'YYYY-MM-DD'),
  NULL,
  NULL,
  NULL,
  'no_shift_on_date'
WHERE NOT EXISTS (SELECT 1 FROM agent_row);
