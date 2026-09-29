-- noir_outposts 005_operation_retention
-- A manutenção remove operações pela idade; este índice evita uma varredura completa do ledger.

CREATE INDEX IF NOT EXISTS idx_operations_created_at
    ON noir_outpost_operations (created_at);
