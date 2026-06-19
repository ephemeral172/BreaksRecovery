-- One-time cleanup: legacy schema from first InitTables run (rpa.*).
-- Run ONLY after:
--   1) InitTables → n8n_breaks_recovery.*
--   2) init_cfg_data.sql → n8n_breaks_recovery.cfg_*
--
-- ADR-006: rpa is not used; test data only, no migration.

DROP SCHEMA IF EXISTS rpa CASCADE;

-- Verify
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name IN ('rpa', 'n8n_breaks_recovery')
ORDER BY schema_name;
