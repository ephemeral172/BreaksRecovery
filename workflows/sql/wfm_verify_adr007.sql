-- ADR-007: проверки на wfm-test перед боевым SQL
-- Credential: WFM DB. Запускать по одному блоку в Postgres-ноде n8n.

-- 0) Подключение
SELECT 1 AS connection_ok;

-- 1) Имена колонок not_eras* (на test usa.not_eraseble НЕТ — только not_erasable)
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name LIKE 'not_eras%'
ORDER BY table_name, column_name;

-- 1b) Семантика true/false
SELECT 'user_schedule_activity.not_erasable' AS field, not_erasable AS value, COUNT(*) AS cnt
FROM user_schedule_activity
GROUP BY not_erasable
ORDER BY not_erasable;

SELECT 'work_activity.not_erasable' AS field, not_erasable AS value, COUNT(*) AS cnt
FROM work_activity
GROUP BY not_erasable
ORDER BY not_erasable;

-- 2) Типы start/end у шаблона смены и факта
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('schedule_variant', 'schedule_variant_activity', 'user_schedule_activity')
  AND column_name IN ('start', 'end', 'not_erasable', 'not_eraseble')
ORDER BY table_name, column_name;

-- 3) Цепочка FTE: queue_forecast -> queue -> skill <- skill_fte
-- LIMIT 1: полный COUNT(*) на test может идти минутами
SELECT 1 AS fte_join_ok
FROM queue_forecast qf
INNER JOIN queue q ON q.id = qf.queue_id
INNER JOIN skill s ON s.id = q.skill_id
INNER JOIN skill_fte sf ON sf.skill_id = s.id
LIMIT 1;

-- 4) skill.time_zone (Q-05)
SELECT time_zone, COUNT(*) AS cnt
FROM skill
GROUP BY time_zone
ORDER BY cnt DESC
LIMIT 10;

-- 5) schedule_scheme / schedule_variant — колонки и FK (proc_01)
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
    table_name IN (
      'schedule_scheme',
      'schedule_scheme_validity_period',
      'schedule_scheme_variant',
      'schedule_variant',
      'user_schedule'
    )
    OR column_name LIKE '%schedule_scheme%'
    OR column_name LIKE '%schedule_variant%'
  )
ORDER BY table_name, ordinal_position;
