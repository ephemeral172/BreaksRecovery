-- DEPRECATED: заменён на gtd_02_agents_d_plus_1.sql (Jira GetTransactionData шаг 3)
-- WF1-01 / TDR §7.1 оп.1: агенты на смене D+1 (включая ночные)
-- Credential: WFM DB read-only
-- ТЗ §4.5 шаг 3; ADR-007: UTC -> MSK +3h
--
-- Выход: agent_login, shift_date (YYYY-MM-DD), is_night_shift
-- shift_date — text, чтобы n8n не сериализовал DATE как 2026-06-18T21:00:00.000Z
-- is_night_shift: смена началась сегодня (run_date), закончилась завтра (shift_date) — TDR
-- Фильтр поддержки: EXISTS user_skill_mapping + skill IN cfg_fte_groups (см. wf1_00, Build WF1 Query)
-- Без фильтра на test ~13833 синтетических логинов (4e14…); с фильтром — порядок prod (~2000)

WITH params AS (
  SELECT
    (NOW() AT TIME ZONE 'Europe/Moscow')::date AS run_date,
    ((NOW() AT TIME ZONE 'Europe/Moscow')::date + 1) AS shift_date
),
support_skills(skill_name) AS (
  VALUES
    ('__SKILL_PLACEHOLDER__')
),
activities_msk AS (
  SELECT
    u.login AS agent_login,
    (usa.start AT TIME ZONE 'UTC' + INTERVAL '3 hours')::date AS start_msk_date,
    (usa.end AT TIME ZONE 'UTC' + INTERVAL '3 hours')::date AS end_msk_date
  FROM user_schedule_activity usa
  INNER JOIN "user" u ON u.id = usa.user_id
  WHERE usa.start IS NOT NULL
    AND usa.end IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM user_skill_mapping usm
      INNER JOIN skill sk ON sk.id = usm.skill_id
      INNER JOIN support_skills ss ON ss.skill_name = sk.name
      WHERE usm.user_id = u.id
    )
)
SELECT
  am.agent_login,
  to_char(p.shift_date, 'YYYY-MM-DD') AS shift_date,
  BOOL_OR(am.start_msk_date = p.run_date AND am.end_msk_date >= p.shift_date) AS is_night_shift
FROM activities_msk am
CROSS JOIN params p
WHERE am.start_msk_date = p.shift_date
   OR am.end_msk_date = p.shift_date
   OR (am.start_msk_date < p.shift_date AND am.end_msk_date > p.shift_date)
GROUP BY am.agent_login, p.shift_date, p.run_date
ORDER BY am.agent_login;
