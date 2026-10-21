CREATE TABLE IF NOT EXISTS silver.transactions (
    transaction_id    TEXT PRIMARY KEY,
    account_id        TEXT NOT NULL,
    txn_ts            TIMESTAMP NOT NULL,
    posting_date      DATE NOT NULL,
    amount            NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    direction         TEXT NOT NULL CHECK (direction IN ('CREDIT','DEBIT')),
    txn_type_code     TEXT NOT NULL,
    status            TEXT NOT NULL,
    source_updated_at TIMESTAMP,
    batch_id          BIGINT,
    loaded_at         TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS silver.quarantine_transactions (
    transaction_id TEXT,
    account_id     TEXT,
    amount         TEXT,
    reason         TEXT,
    batch_id       BIGINT,
    source_file    TEXT,
    quarantined_at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE VIEW silver.v_transactions_checked AS
SELECT b.*,
    CASE
        WHEN b.account_id IS NULL THEN 'MISSING_ACCOUNT_ID'
        WHEN NOT EXISTS (SELECT 1 FROM bronze.accounts a WHERE a.account_id = b.account_id) THEN 'ORPHAN_ACCOUNT'
        WHEN b.amount IS NULL THEN 'NULL_AMOUNT'
        WHEN b.amount !~ '^[0-9]+(\.[0-9]+)?$' THEN 'NEGATIVE_OR_BAD_FORMAT_AMOUNT'
        WHEN b.amount::numeric = 0 THEN 'ZERO_AMOUNT'
        WHEN b.direction IS NULL OR b.direction NOT IN ('CREDIT','DEBIT') THEN 'BAD_DIRECTION'
    END AS reject_reason
FROM bronze.transactions b;

TRUNCATE silver.transactions, silver.quarantine_transactions;

INSERT INTO silver.quarantine_transactions (transaction_id, account_id, amount, reason, batch_id, source_file)
SELECT transaction_id, account_id, amount, reject_reason, batch_id, source_file
FROM silver.v_transactions_checked
WHERE reject_reason IS NOT NULL;

INSERT INTO silver.transactions
    (transaction_id, account_id, txn_ts, posting_date, amount, direction,
     txn_type_code, status, source_updated_at, batch_id)
SELECT transaction_id, account_id, txn_ts::timestamp, posting_date::date, amount::numeric(18,2),
       direction, txn_type_code, status, source_updated_at::timestamp, batch_id
FROM (
    SELECT c.*,
           ROW_NUMBER() OVER (PARTITION BY transaction_id
                              ORDER BY source_updated_at DESC, batch_id DESC) AS rn
    FROM silver.v_transactions_checked c
    WHERE reject_reason IS NULL
) x
WHERE rn = 1;
