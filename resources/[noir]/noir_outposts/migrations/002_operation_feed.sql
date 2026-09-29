-- noir_outposts 002_operation_feed
-- O feed do telefone lê as operações de uma organização em ordem decrescente de data.
-- Sem este índice a consulta varre a tabela inteira, que cresce a cada venda.

CREATE INDEX IF NOT EXISTS idx_operations_organization
    ON noir_outpost_operations (organization_id, created_at);
