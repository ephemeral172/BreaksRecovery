-- PROC-02 / C2 / A.3: навыки агента на D+1 (Jira RPA-1834)
-- Credential: WFM DB read-only
-- Params: $1 = wfm_user_id (UUID text), $2 = shift_date (DATE, D+1)
--
-- Выход: skill_id, skill_priority, skill_name, skill_time_zone
-- Исключение non-Moscow TZ — в Merge Agent Skills (phase_c_logic.mergeAgentSkills)

SELECT
  usm.skill_id,
  usm.skill_priority,
  s.name AS skill_name,
  s.time_zone AS skill_time_zone
FROM public.user_skill_mapping usm
INNER JOIN public.skill s
  ON s.id = usm.skill_id
WHERE usm.user_id = $1::uuid
  AND usm.start <= $2::date
  AND (usm."end" IS NULL OR usm."end" >= $2::date)
ORDER BY usm.skill_priority NULLS LAST, s.name;
