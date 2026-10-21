CREATE TABLE IF NOT EXISTS gold.fact_transactions (
    transaction_id TEXT PRIMARY KEY,
    date_key       INT,
    account_key    BIGINT,
    customer_key   BIGINT,
    txn_type_key   INT,
    txn_ts         TIMESTAMP NOT NULL,
    amount         NUMERIC(18,2) NOT NULL,
    signed_amount  NUMERIC(18,2) NOT NULL,
    direction      TEXT NOT NULL,
    status         TEXT NOT NULL,
    is_posted      BOOLEAN NOT NULL,
    batch_id       BIGINT
);

CREATE TABLE IF NOT EXISTS gold.fact_daily_account_balance (
    account_key     BIGINT NOT NULL,
    date_key        INT NOT NULL,
    account_id      TEXT NOT NULL,
    business_date   DATE NOT NULL,
    opening_balance NUMERIC(18,2) NOT NULL,
    closing_balance NUMERIC(18,2) NOT NULL,
    batch_id        BIGINT,
    PRIMARY KEY (account_key, date_key)
);

TRUNCATE gold.fact_transactions, gold.fact_daily_account_balance;

INSERT INTO gold.fact_transactions
SELECT t.transaction_id,
       to_char(t.posting_date, 'YYYYMMDD')::int,
       a.account_key,
       c.customer_key,
       tt.txn_type_key,
       t.txn_ts,
       t.amount,
       CASE WHEN t.status = 'POSTED'
            THEN CASE t.direction WHEN 'CREDIT' THEN t.amount ELSE -t.amount END
            ELSE 0 END,
       t.direction,
       t.status,
       t.status = 'POSTED',
       t.batch_id
FROM silver.transactions t
LEFT JOIN gold.dim_account a
       ON a.account_id = t.account_id AND t.txn_ts >= a.valid_from AND t.txn_ts < a.valid_to
LEFT JOIN gold.dim_customer c
       ON c.customer_id = a.customer_id AND t.txn_ts >= c.valid_from AND t.txn_ts < c.valid_to
LEFT JOIN gold.dim_transaction_type tt
       ON tt.txn_type_code = t.txn_type_code;

INSERT INTO gold.fact_daily_account_balance
SELECT a.account_key,
       to_char(b.business_date, 'YYYYMMDD')::int,
       b.account_id, b.business_date, b.opening_balance, b.closing_balance, b.batch_id
FROM silver.daily_balances b
JOIN gold.dim_account a
  ON a.account_id = b.account_id
 AND (b.business_date + 1)::timestamp - INTERVAL '1 second' >= a.valid_from
 AND (b.business_date + 1)::timestamp - INTERVAL '1 second' <  a.valid_to;
