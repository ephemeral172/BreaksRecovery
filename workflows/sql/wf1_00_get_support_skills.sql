-- DEPRECATED (TDR v3): навыки берутся из mappings/fte_groups.json + news_exception_skills.json
-- См. Main → Extract Support Skills / LoadMappings

-- WF1-00 (legacy): навыки из cfg_fte_groups

SELECT DISTINCT skill_name
FROM n8n_breaks_recovery.cfg_fte_groups
UNION
SELECT skill_name
FROM n8n_breaks_recovery.cfg_news_exception_skills
ORDER BY skill_name;
