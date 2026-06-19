-- ============================================================
-- Миграция на TDR v3 (18.06.2026)
-- 1) Переименование транзакционных таблиц
-- 2) Удаление legacy cfg_* (маппинги → mappings/*.json в git)
-- ============================================================

-- Переименование журналов (если созданы по старому TDR)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'n8n_breaks_recovery'
      AND table_name = 'breaks_recovery_transactions'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'n8n_breaks_recovery'
      AND table_name = 'recovery_transactions'
  ) THEN
    ALTER TABLE n8n_breaks_recovery.breaks_recovery_transactions
      RENAME TO recovery_transactions;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'n8n_breaks_recovery'
      AND table_name = 'breaks_balance_transactions'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'n8n_breaks_recovery'
      AND table_name = 'balance_transactions'
  ) THEN
    ALTER TABLE n8n_breaks_recovery.breaks_balance_transactions
      RENAME TO balance_transactions;
  END IF;
END $$;

-- Переименование индексов (best effort)
ALTER INDEX IF EXISTS n8n_breaks_recovery.ix_brt_shift_date RENAME TO ix_rt_shift_date;
ALTER INDEX IF EXISTS n8n_breaks_recovery.ix_brt_status RENAME TO ix_rt_status;
ALTER INDEX IF EXISTS n8n_breaks_recovery.ix_bbt_coverage_date RENAME TO ix_bt_coverage_date;
ALTER INDEX IF EXISTS n8n_breaks_recovery.ix_bbt_status RENAME TO ix_bt_status;

-- Удаление cfg_* — данные перенесены в mappings/*.json
DROP TABLE IF EXISTS n8n_breaks_recovery.cfg_email_fallback CASCADE;
DROP TABLE IF EXISTS n8n_breaks_recovery.cfg_fte_groups CASCADE;
DROP TABLE IF EXISTS n8n_breaks_recovery.cfg_news_exception_skills CASCADE;
DROP TABLE IF EXISTS n8n_breaks_recovery.cfg_news_reading CASCADE;
DROP TABLE IF EXISTS n8n_breaks_recovery.cfg_non_standard_containers CASCADE;
DROP TABLE IF EXISTS n8n_breaks_recovery.cfg_activity_mapping CASCADE;
