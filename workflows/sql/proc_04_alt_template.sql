-- PROC-04 alt: plan из schedule_variant_activity (шаблон контейнера)
-- Params: $2 shift_date, $3 schedule_variant_id, $4 is_night_shift (не используется)
--
-- test WFM: work_activity_id нет — проверить колонку FK через proc_01_discover блок D4.
-- Кандидаты: activity_id, workactivity_id (сверить с information_schema + FK).
--
-- Выход: activity_name, start_msk, end_msk, duration_min, plan_source, is_fixed
-- is_fixed: schedule_variant_activity.is_fixed (prod); COALESCE на test без колонки — discover D4

SELECT
  wa.name AS activity_name,
  to_char(($2::date + sva.start)::timestamp, 'YYYY-MM-DD"T"HH24:MI:SS') AS start_msk,
  to_char(
    (
      CASE
        WHEN sva."end" <= sva.start
          THEN $2::date + INTERVAL '1 day' + sva."end"
        ELSE $2::date + sva."end"
      END
    )::timestamp,
    'YYYY-MM-DD"T"HH24:MI:SS'
  ) AS end_msk,
  (
    EXTRACT(
      EPOCH FROM (
        CASE
          WHEN sva."end" <= sva.start
            THEN sva."end" - sva.start + INTERVAL '1 day'
          ELSE sva."end" - sva.start
        END
      )
    ) / 60
  )::integer AS duration_min,
  'template'::text AS plan_source,
  COALESCE(sva.is_fixed, FALSE) AS is_fixed
FROM public.schedule_variant_activity sva
INNER JOIN public.work_activity wa
  ON wa.id = sva.activity_id
WHERE NULLIF($3::text, '') IS NOT NULL
  AND sva.schedule_variant_id = NULLIF($3::text, '')::uuid
  AND wa.absence = FALSE
ORDER BY sva.start;
