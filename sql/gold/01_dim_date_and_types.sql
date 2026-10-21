CREATE TABLE IF NOT EXISTS gold.dim_date (
    date_key       INT PRIMARY KEY,
    full_date      DATE NOT NULL UNIQUE,
    year           INT NOT NULL,
    quarter        INT NOT NULL,
    month          INT NOT NULL,
    month_name     TEXT NOT NULL,
    day_of_month   INT NOT NULL,
    iso_day_of_week INT NOT NULL,
    day_name       TEXT NOT NULL,
    week_of_year   INT NOT NULL,
    is_weekend     BOOLEAN NOT NULL,
    is_month_end   BOOLEAN NOT NULL
);

TRUNCATE gold.dim_date;

INSERT INTO gold.dim_date
SELECT to_char(d, 'YYYYMMDD')::int,
       d,
       EXTRACT(YEAR FROM d)::int,
       EXTRACT(QUARTER FROM d)::int,
       EXTRACT(MONTH FROM d)::int,
       trim(to_char(d, 'Month')),
       EXTRACT(DAY FROM d)::int,
       EXTRACT(ISODOW FROM d)::int,
       trim(to_char(d, 'Day')),
       EXTRACT(WEEK FROM d)::int,
       EXTRACT(ISODOW FROM d) IN (6, 7),
       d = (date_trunc('month', d)::date + INTERVAL '1 month - 1 day')::date
FROM (SELECT g::date AS d
      FROM generate_series('2026-01-01'::date, '2026-12-31'::date, '1 day') g) days;

CREATE TABLE IF NOT EXISTS gold.dim_transaction_type (
    txn_type_key  INT PRIMARY KEY,
    txn_type_code TEXT NOT NULL UNIQUE,
    txn_type_name TEXT NOT NULL,
    category      TEXT NOT NULL,
    direction     TEXT NOT NULL CHECK (direction IN ('CREDIT','DEBIT'))
);

TRUNCATE gold.dim_transaction_type;

INSERT INTO gold.dim_transaction_type VALUES
    (1, 'UPI_IN',   'UPI Received',    'TRANSFER', 'CREDIT'),
    (2, 'NEFT_IN',  'NEFT Received',   'TRANSFER', 'CREDIT'),
    (3, 'UPI_OUT',  'UPI Payment',     'PAYMENT',  'DEBIT'),
    (4, 'POS',      'Card Purchase',   'SPEND',    'DEBIT'),
    (5, 'ATM_WD',   'ATM Withdrawal',  'CASH',     'DEBIT'),
    (6, 'BILL_PAY', 'Bill Payment',    'BILLS',    'DEBIT');
