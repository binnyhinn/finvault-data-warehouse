CREATE TABLE IF NOT EXISTS gold.reconciliation (
    check_name    TEXT NOT NULL,
    account_id    TEXT NOT NULL,
    business_date DATE NOT NULL,
    expected      NUMERIC(18,2),
    actual        NUMERIC(18,2),
    difference    NUMERIC(18,2),
    status        TEXT NOT NULL,
    checked_at    TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (check_name, account_id, business_date)
);

TRUNCATE gold.reconciliation;

WITH mv AS (
    SELECT a.account_id, f.date_key, SUM(f.signed_amount) AS m
    FROM gold.fact_transactions f
    JOIN gold.dim_account a USING (account_key)
    GROUP BY 1, 2
)
INSERT INTO gold.reconciliation (check_name, account_id, business_date, expected, actual, difference, status)
SELECT 'MOVEMENT', b.account_id, b.business_date,
       b.opening_balance + COALESCE(mv.m, 0),
       b.closing_balance,
       b.closing_balance - (b.opening_balance + COALESCE(mv.m, 0)),
       CASE WHEN b.closing_balance = b.opening_balance + COALESCE(mv.m, 0) THEN 'PASS' ELSE 'FAIL' END
FROM gold.fact_daily_account_balance b
LEFT JOIN mv ON mv.account_id = b.account_id AND mv.date_key = b.date_key;

INSERT INTO gold.reconciliation (check_name, account_id, business_date, expected, actual, difference, status)
SELECT 'CONTINUITY', b.account_id, b.business_date,
       p.closing_balance,
       b.opening_balance,
       b.opening_balance - p.closing_balance,
       CASE WHEN b.opening_balance = p.closing_balance THEN 'PASS' ELSE 'FAIL' END
FROM gold.fact_daily_account_balance b
JOIN gold.fact_daily_account_balance p
  ON p.account_id = b.account_id AND p.business_date = b.business_date - 1;
