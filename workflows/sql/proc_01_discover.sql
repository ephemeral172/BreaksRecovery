-- PROC-01 discover: как на test связаны scheme и variant
-- Credential: WFM DB. Запускать по одному блоку.

-- A) Таблицы schedule* / user_schedule
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND (table_name LIKE 'schedule%' OR table_name = 'user_schedule')
ORDER BY table_name;

-- B) Колонки schedule_scheme_validity_period
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'schedule_scheme_validity_period'
ORDER BY ordinal_position;

-- C) Колонки schedule_scheme
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'schedule_scheme'
ORDER BY ordinal_position;

-- D) Колонки schedule_variant
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'schedule_variant'
ORDER BY ordinal_position;

-- D4) Колонки schedule_variant_activity (FK к work_activity — proc_04)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'schedule_variant_activity'
ORDER BY ordinal_position;

-- D4b) FK schedule_variant_activity → work_activity
SELECT
  src_col.column_name AS sva_column,
  tgt_col.table_name AS ref_table,
  tgt_col.column_name AS ref_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage src_col
  ON src_col.constraint_name = tc.constraint_name
 AND src_col.table_schema = tc.table_schema
JOIN information_schema.constraint_column_usage tgt_col
  ON tgt_col.constraint_name = tc.constraint_name
 AND tgt_col.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND src_col.table_name = 'schedule_variant_activity'
  AND tgt_col.table_name = 'work_activity';

-- D2) Колонки schedule_scheme_container (day — proc_01, PDF №6)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'schedule_scheme_container'
ORDER BY ordinal_position;

-- D3) Колонки schedule_container (имя контейнера — proc_01)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'schedule_container'
ORDER BY ordinal_position;

-- E) Колонки user_schedule_activity с variant/schedule/scheme в имени
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'user_schedule_activity'
  AND (
    column_name LIKE '%variant%'
    OR column_name LIKE '%schedule%'
    OR column_name LIKE '%scheme%'
    OR column_name LIKE '%container%'
  )
ORDER BY ordinal_position;

-- F) FK → schedule_variant
SELECT
  src_col.table_name AS referencing_table,
  src_col.column_name AS referencing_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage src_col
  ON src_col.constraint_name = tc.constraint_name
 AND src_col.table_schema = tc.table_schema
JOIN information_schema.constraint_column_usage tgt_col
  ON tgt_col.constraint_name = tc.constraint_name
 AND tgt_col.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND tgt_col.table_name = 'schedule_variant'
ORDER BY 1, 2;

-- G) Smoke: только схема для zvusmanova
-- Params: $1 = a48a5127-b3a6-499c-891b-a6bf0ce7a89f, $2 = 2026-07-01
SELECT ss.name AS schedule_scheme_name
FROM public.schedule_scheme_validity_period ssvp
INNER JOIN public.schedule_scheme ss
  ON ss.id = ssvp.schedule_scheme_id
WHERE ssvp.user_id = $1::uuid
  AND $2::date >= ssvp.start_date::date
  AND (ssvp.end_date IS NULL OR $2::date <= ssvp.end_date::date)
ORDER BY ssvp.start_date DESC
LIMIT 1;
