-- PROC-01 / C1: схема + variant контейнера (PDF №3, №5, №6)
-- Credential: WFM DB read-only
-- Params: $1 = wfm_user_id (UUID text), $2 = shift_date (DATE, D+1)
--
-- test WFM: schedule_variant.name нет → schedule_container.name;
--   day ротации — schedule_scheme_container.day (PDF №6), не schedule_variant.day
-- Цепочка: schedule_scheme_validity_period → schedule_scheme
--   → schedule_scheme_container → schedule_variant (день ротации по ss.date / ss.max_day)
--
-- Выход: schedule_scheme_name, schedule_variant_name, schedule_variant_id

WITH validity AS (
  SELECT ssvp.schedule_scheme_id
  FROM public.schedule_scheme_validity_period ssvp
  WHERE ssvp.user_id = $1::uuid
    AND $2::date >= ssvp.start_date::date
    AND (ssvp.end_date IS NULL OR $2::date <= ssvp.end_date::date)
  ORDER BY ssvp.start_date DESC
  LIMIT 1
),
scheme AS (
  SELECT
    ss.id,
    ss.name,
    ss.date::date AS day_start_scheme,
    COALESCE(ss.max_day, 0) AS period_schedule
  FROM validity v
  INNER JOIN public.schedule_scheme ss
    ON ss.id = v.schedule_scheme_id
),
rotation AS (
  SELECT
    s.id,
    s.name,
    CASE
      WHEN s.period_schedule > 0 THEN
        ((($2::date - s.day_start_scheme) % s.period_schedule) + s.period_schedule)
        % s.period_schedule
      ELSE 0
    END AS shift_day
  FROM scheme s
),
variants AS (
  SELECT
    r.name AS schedule_scheme_name,
    COALESCE(
      NULLIF(trim(sc.name), ''),
      to_char(sv.start, 'FMHH24:MI') || '-' || to_char(sv.end, 'FMHH24:MI')
    ) AS schedule_variant_name,
    sv.id::text AS schedule_variant_id,
    ssc.day AS variant_day,
    r.shift_day,
    ABS(ssc.day - r.shift_day) AS day_distance
  FROM rotation r
  INNER JOIN public.schedule_scheme_container ssc
    ON ssc.schedule_scheme_id = r.id
  INNER JOIN public.schedule_variant sv
    ON sv.schedule_container_id = ssc.schedule_container_id
  LEFT JOIN public.schedule_container sc
    ON sc.id = sv.schedule_container_id
),
picked AS (
  SELECT
    schedule_scheme_name,
    schedule_variant_name,
    schedule_variant_id
  FROM variants
  WHERE variant_day = shift_day
  ORDER BY schedule_variant_name
  LIMIT 1
),
fallback AS (
  SELECT
    schedule_scheme_name,
    schedule_variant_name,
    schedule_variant_id
  FROM variants
  ORDER BY day_distance, variant_day, schedule_variant_name
  LIMIT 1
),
scheme_only AS (
  SELECT
    r.name AS schedule_scheme_name,
    NULL::text AS schedule_variant_name,
    NULL::text AS schedule_variant_id
  FROM rotation r
)
SELECT
  schedule_scheme_name,
  schedule_variant_name,
  schedule_variant_id
FROM picked
UNION ALL
SELECT
  f.schedule_scheme_name,
  f.schedule_variant_name,
  f.schedule_variant_id
FROM fallback f
WHERE NOT EXISTS (SELECT 1 FROM picked)
UNION ALL
SELECT
  s.schedule_scheme_name,
  s.schedule_variant_name,
  s.schedule_variant_id
FROM scheme_only s
WHERE NOT EXISTS (SELECT 1 FROM picked)
  AND NOT EXISTS (SELECT 1 FROM fallback)
LIMIT 1;
