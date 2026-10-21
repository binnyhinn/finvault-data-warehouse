CREATE TABLE IF NOT EXISTS bronze.customers (
    customer_id TEXT, first_name TEXT, last_name TEXT,
    city TEXT, state TEXT, segment TEXT, updated_at TEXT,
    batch_id BIGINT, source_file TEXT, loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bronze.accounts (
    account_id TEXT, customer_id TEXT, account_type TEXT, branch_code TEXT,
    status TEXT, initial_balance TEXT, updated_at TEXT,
    batch_id BIGINT, source_file TEXT, loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bronze.transactions (
    transaction_id TEXT, account_id TEXT, txn_ts TEXT, posting_date TEXT,
    amount TEXT, direction TEXT, txn_type_code TEXT, status TEXT,
    source_updated_at TEXT,
    batch_id BIGINT, source_file TEXT, loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bronze.daily_balances (
    account_id TEXT, business_date TEXT, opening_balance TEXT, closing_balance TEXT,
    batch_id BIGINT, source_file TEXT, loaded_at TIMESTAMPTZ DEFAULT now()
);