CREATE TABLE IF NOT EXISTS gold.dim_customer (
    customer_key BIGSERIAL PRIMARY KEY,
    customer_id  TEXT NOT NULL,
    first_name   TEXT,
    last_name    TEXT,
    city         TEXT,
    state        TEXT,
    segment      TEXT,
    valid_from   TIMESTAMP NOT NULL,
    valid_to     TIMESTAMP NOT NULL,
    is_current   BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS gold.dim_account (
    account_key  BIGSERIAL PRIMARY KEY,
    account_id   TEXT NOT NULL,
    customer_id  TEXT NOT NULL,
    account_type TEXT,
    branch_code  TEXT,
    status       TEXT,
    valid_from   TIMESTAMP NOT NULL,
    valid_to     TIMESTAMP NOT NULL,
    is_current   BOOLEAN NOT NULL
);

TRUNCATE gold.dim_customer, gold.dim_account RESTART IDENTITY;

INSERT INTO gold.dim_customer
    (customer_id, first_name, last_name, city, state, segment, valid_from, valid_to, is_current)
SELECT customer_id, first_name, last_name, city, state, segment,
       CASE WHEN rn = 1 THEN TIMESTAMP '1900-01-01' ELSE updated_at END,
       COALESCE(next_at, TIMESTAMP '9999-12-31'),
       next_at IS NULL
FROM (
    SELECT s.*,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY updated_at) AS rn,
           LEAD(updated_at) OVER (PARTITION BY customer_id ORDER BY updated_at) AS next_at
    FROM silver.customers s
) x
ORDER BY customer_id, updated_at;

INSERT INTO gold.dim_account
    (account_id, customer_id, account_type, branch_code, status, valid_from, valid_to, is_current)
SELECT account_id, customer_id, account_type, branch_code, status,
       CASE WHEN rn = 1 THEN TIMESTAMP '1900-01-01' ELSE updated_at END,
       COALESCE(next_at, TIMESTAMP '9999-12-31'),
       next_at IS NULL
FROM (
    SELECT s.*,
           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY updated_at) AS rn,
           LEAD(updated_at) OVER (PARTITION BY account_id ORDER BY updated_at) AS next_at
    FROM silver.accounts s
) x
ORDER BY account_id, updated_at;
