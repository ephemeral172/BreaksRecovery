-- TDR v3 §6.3: 4 таблицы в n8n_breaks_recovery (маппинги — в git, не в БД)
-- Credential: RPA DB

SELECT table_name, (
  CASE table_name
    WHEN 'agents' THEN 1
    WHEN 'recovery_transactions' THEN 1
    WHEN 'balance_transactions' THEN 1
    WHEN 'breaks_balance_moves' THEN 1
    ELSE 0
  END
) AS expected
FROM information_schema.tables
WHERE table_schema = 'n8n_breaks_recovery'
ORDER BY table_name;
