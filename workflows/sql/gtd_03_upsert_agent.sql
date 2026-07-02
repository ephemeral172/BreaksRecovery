-- GTD-03 / Jira GetTransactionData шаг 4
-- Credential: RPA DB
-- Params: $1 = agent_login (varchar)
-- DO UPDATE (не DO NOTHING) — RETURNING id для существующего агента

INSERT INTO n8n_breaks_recovery.agents (agent_login)
VALUES ($1)
ON CONFLICT (agent_login) DO UPDATE
  SET agent_login = EXCLUDED.agent_login
RETURNING id AS agent_id;
