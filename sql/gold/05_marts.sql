CREATE OR REPLACE VIEW gold.mart_monthly_transactions AS
SELECT d.year, d.month, d.month_name, t.category, f.direction,
       COUNT(*) AS txn_count, SUM(f.amount) AS total_amount
FROM gold.fact_transactions f
JOIN gold.dim_date d ON d.date_key = f.date_key
JOIN gold.dim_transaction_type t ON t.txn_type_key = f.txn_type_key
WHERE f.is_posted
GROUP BY 1, 2, 3, 4, 5;

CREATE OR REPLACE VIEW gold.mart_account_activity AS
WITH act AS (
    SELECT a.account_id, COUNT(*) AS txn_count,
           SUM(CASE WHEN f.direction = 'CREDIT' THEN f.amount ELSE 0 END) AS total_credits,
           SUM(CASE WHEN f.direction = 'DEBIT' THEN f.amount ELSE 0 END) AS total_debits
    FROM gold.fact_transactions f
    JOIN gold.dim_account a USING (account_key)
    WHERE f.is_posted
    GROUP BY a.account_id
),
latest AS (
    SELECT DISTINCT ON (account_id) account_id, business_date, closing_balance
    FROM gold.fact_daily_account_balance
    ORDER BY account_id, business_date DESC
)
SELECT l.account_id,
       COALESCE(act.txn_count, 0) AS txn_count,
       COALESCE(act.total_credits, 0) AS total_credits,
       COALESCE(act.total_debits, 0) AS total_debits,
       l.business_date AS balance_date,
       l.closing_balance
FROM latest l
LEFT JOIN act USING (account_id);

CREATE OR REPLACE VIEW gold.mart_customer_segments AS
SELECT c.segment, d.year, d.month,
       COUNT(*) AS txn_count,
       SUM(f.amount) AS total_amount,
       COUNT(DISTINCT c.customer_id) AS active_customers
FROM gold.fact_transactions f
JOIN gold.dim_customer c USING (customer_key)
JOIN gold.dim_date d ON d.date_key = f.date_key
WHERE f.is_posted
GROUP BY 1, 2, 3;

CREATE OR REPLACE VIEW gold.mart_reconciliation_summary AS
SELECT check_name, status, COUNT(*) AS checks,
       COALESCE(SUM(ABS(difference)), 0) AS total_abs_difference
FROM gold.reconciliation
GROUP BY 1, 2;