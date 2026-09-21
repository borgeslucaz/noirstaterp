CREATE TABLE IF NOT EXISTS noir_fazenda_schema_migrations (
  version VARCHAR(64) NOT NULL,
  applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Ledger de movimentação.
--
-- Existe porque o extrato do Renewed-Banking é um blob JSON por conta, reescrito
-- inteiro a cada transação, sem limite e sem índice. Dá para MOSTRAR, não dá para
-- SOMAR: não há como perguntar "quanto entrou para este cidadão na semana passada"
-- sem decodificar todo o histórico de todo mundo.
--
-- Aqui cada movimento é uma linha, com o período já calculado na escrita. A
-- apuração vira um SUM com índice em cima.
CREATE TABLE IF NOT EXISTS noir_fazenda_ledger (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  -- Idempotência: mesmo movimento reentregue não vira linha nova. Restart do
  -- provider, replay de evento e chamada dupla de export caem todos aqui.
  event_id VARCHAR(160) NOT NULL,
  subject_type ENUM('player', 'org') NOT NULL,
  subject_id VARCHAR(64) NOT NULL,
  direction ENUM('in', 'out') NOT NULL,
  category VARCHAR(48) NOT NULL,
  -- Desnormalizado de propósito: a decisão do que é tributável é tomada uma vez,
  -- na escrita, com a config vigente. Apuração não reinterpreta o passado.
  taxable TINYINT(1) NOT NULL DEFAULT 0,
  amount BIGINT NOT NULL,
  counterparty VARCHAR(128) NULL,
  provider VARCHAR(64) NOT NULL,
  source_resource VARCHAR(64) NOT NULL,
  period_key VARCHAR(16) NOT NULL,
  reference VARCHAR(64) NULL,
  metadata JSON NULL,
  occurred_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_noir_fazenda_ledger_event (event_id),
  KEY idx_noir_fazenda_ledger_base (subject_type, subject_id, period_key, taxable),
  KEY idx_noir_fazenda_ledger_statement (subject_type, subject_id, occurred_at),
  KEY idx_noir_fazenda_ledger_period (period_key, subject_type),
  KEY idx_noir_fazenda_ledger_occurred (occurred_at),
  CONSTRAINT chk_noir_fazenda_ledger_amount CHECK (amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Apuração por sujeito e período. Uma linha por (cidadão, período).
--
-- `taxable_base` é congelada no fechamento: lançamento que chegue atrasado depois
-- do fechamento não muda apuração já fechada, ele cai no período corrente. É a
-- mesma escolha que um livro-caixa real faz, e evita que dívida mude sozinha
-- depois de cobrada.
CREATE TABLE IF NOT EXISTS noir_fazenda_assessments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  subject_type ENUM('player', 'org') NOT NULL,
  subject_id VARCHAR(64) NOT NULL,
  period_key VARCHAR(16) NOT NULL,
  period_start DATETIME NOT NULL,
  period_end DATETIME NOT NULL,
  taxable_base BIGINT NOT NULL DEFAULT 0,
  exempt_base BIGINT NOT NULL DEFAULT 0,
  entry_count INT UNSIGNED NOT NULL DEFAULT 0,
  assessed BIGINT NOT NULL DEFAULT 0,
  paid BIGINT NOT NULL DEFAULT 0,
  effective_rate DECIMAL(6,4) NOT NULL DEFAULT 0.0000,
  -- 'simulated' é o estado de quem apurou com a cobrança desligada: o número
  -- existe, mas não é dívida. É o estado em que o sistema nasce.
  status ENUM('simulated', 'assessed', 'paid', 'overdue', 'waived', 'void')
    NOT NULL DEFAULT 'simulated',
  due_at DATETIME NULL,
  closed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_noir_fazenda_assessment_subject_period (subject_type, subject_id, period_key),
  KEY idx_noir_fazenda_assessment_open (subject_type, subject_id, status),
  KEY idx_noir_fazenda_assessment_due (status, due_at),
  CONSTRAINT chk_noir_fazenda_assessment_nonnegative
    CHECK (taxable_base >= 0 AND assessed >= 0 AND paid >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_fazenda_payments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  assessment_id BIGINT UNSIGNED NOT NULL,
  subject_type ENUM('player', 'org') NOT NULL,
  subject_id VARCHAR(64) NOT NULL,
  amount BIGINT NOT NULL,
  method ENUM('bank', 'cash', 'auto', 'admin', 'waiver') NOT NULL,
  reference VARCHAR(96) NULL,
  actor VARCHAR(128) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_noir_fazenda_payment_assessment (assessment_id),
  KEY idx_noir_fazenda_payment_subject (subject_type, subject_id, created_at),
  CONSTRAINT chk_noir_fazenda_payment_amount CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO noir_fazenda_schema_migrations (version)
VALUES ('001_initial');
