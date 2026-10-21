CREATE TABLE IF NOT EXISTS silver.customers (
    customer_id TEXT NOT NULL,
    first_name  TEXT,
    last_name   TEXT,
    city        TEXT,
    state       TEXT,
    segment     TEXT,
    updated_at  TIMESTAMP NOT NULL,
    batch_id    BIGINT,
    PRIMARY KEY (customer_id, updated_at)
);

CREATE TABLE IF NOT EXISTS silver.accounts (
    account_id      TEXT NOT NULL,
    customer_id     TEXT NOT NULL,
    account_type    TEXT,
    branch_code     TEXT,
    status          TEXT,
    initial_balance NUMERIC(18,2),
    updated_at      TIMESTAMP NOT NULL,
    batch_id        BIGINT,
    PRIMARY KEY (account_id, updated_at)
);

CREATE TABLE IF NOT EXISTS silver.daily_balances (
    account_id      TEXT NOT NULL,
    business_date   DATE NOT NULL,
    opening_balance NUMERIC(18,2) NOT NULL,
    closing_balance NUMERIC(18,2) NOT NULL,
    batch_id        BIGINT,
    PRIMARY KEY (account_id, business_date)
);

TRUNCATE silver.customers, silver.accounts, silver.daily_balances;

INSERT INTO silver.customers
SELECT DISTINCT ON (customer_id, updated_at::timestamp)
       customer_id, first_name, last_name, city, state, segment,
       updated_at::timestamp, batch_id
FROM bronze.customers
WHERE customer_id IS NOT NULL AND updated_at IS NOT NULL
ORDER BY customer_id, updated_at::timestamp, batch_id DESC;

INSERT INTO silver.accounts
SELECT DISTINCT ON (account_id, updated_at::timestamp)
       account_id, customer_id, account_type, branch_code, status,
       initial_balance::numeric(18,2), updated_at::timestamp, batch_id
FROM bronze.accounts
WHERE account_id IS NOT NULL AND customer_id IS NOT NULL AND updated_at IS NOT NULL
ORDER BY account_id, updated_at::timestamp, batch_id DESC;

INSERT INTO silver.daily_balances
SELECT DISTINCT ON (account_id, business_date::date)
       account_id, business_date::date, opening_balance::numeric(18,2),
       closing_balance::numeric(18,2), batch_id
FROM bronze.daily_balances
WHERE account_id IS NOT NULL AND business_date IS NOT NULL
ORDER BY account_id, business_date::date, batch_id DESC;
