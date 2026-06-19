-- Проверка заливки cfg_* (один result set для n8n)
-- Credential: RPA DB

SELECT 'cfg_activity_mapping' AS table_name, COUNT(*)::int AS row_count
FROM n8n_breaks_recovery.cfg_activity_mapping
UNION ALL
SELECT 'cfg_non_standard_containers', COUNT(*)::int
FROM n8n_breaks_recovery.cfg_non_standard_containers
UNION ALL
SELECT 'cfg_news_reading', COUNT(*)::int
FROM n8n_breaks_recovery.cfg_news_reading
UNION ALL
SELECT 'cfg_news_exception_skills', COUNT(*)::int
FROM n8n_breaks_recovery.cfg_news_exception_skills
UNION ALL
SELECT 'cfg_fte_groups', COUNT(*)::int
FROM n8n_breaks_recovery.cfg_fte_groups
ORDER BY table_name;
