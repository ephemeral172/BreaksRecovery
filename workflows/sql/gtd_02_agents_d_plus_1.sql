-- GTD-02 / Jira GetTransactionData шаг 3 + fte_groups (TDR v3 §6.5, ADR-007)
-- Credential: WFM DB read-only
-- Params:
--   $1 = shift_date (DATE, D+1)
--   $2 = excluded logins (text[], обработанные ночники)
--   $3 = support skill names (text[], mappings/fte_groups.json)
--
-- Выход: wfm_user_id, agent_login, shift_start_msk, is_night_shift, shift_date

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
)
SELECT DISTINCT
  u.id::text AS wfm_user_id,
  u.login AS agent_login,
  to_char(
    COALESCE(c.night_shift_start, c.day_shift_start),
    'YYYY-MM-DD"T"HH24:MI:SS'
  ) AS shift_start_msk,
  (c.night_shift_start IS NOT NULL) AS is_night_shift,
  to_char($1::date, 'YYYY-MM-DD') AS shift_date
FROM candidates c
JOIN public."user" u ON u.id = c.user_id
WHERE (c.day_shift_start IS NOT NULL OR c.night_shift_start IS NOT NULL)
  AND (cardinality($2::text[]) = 0 OR u.login <> ALL ($2::text[]))
  AND EXISTS (
    SELECT 1
    FROM user_skill_mapping usm
    INNER JOIN skill sk ON sk.id = usm.skill_id
    WHERE usm.user_id = u.id
      AND sk.name = ANY ($3::text[])
  )
ORDER BY u.login;
