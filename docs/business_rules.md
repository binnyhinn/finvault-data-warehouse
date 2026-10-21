# FinVault: Business Rules

## Table grain
| Table | One row per |
|---|---|
| fact_transactions | transaction |
| fact_daily_account_balance | account per business date |
| dim_customer | customer version (SCD2) |
| dim_account | account version (SCD2) |
| dim_date | calendar date |
| dim_transaction_type | transaction type |

## Money rules (avoid double counting)
1. A transaction amount is always positive. `direction` gives the sign: credit adds, debit subtracts.
2. Only POSTED transactions move money. REVERSED rows are kept for audit but excluded from totals.
3. A balance is a snapshot, not a flow. You can add balances across accounts for one day, never across days.
4. Balances come from `fact_daily_account_balance`. Transactions are used to verify them, not to rebuild them.
5. Amounts use NUMERIC(18,2), never floats.

## Reconciliation rules
- **MOVEMENT:** opening balance + net posted transactions = closing balance, for every account and day.
- **CONTINUITY:** today's opening balance = yesterday's closing balance.
- Results are stored in `gold.reconciliation` as PASS or FAIL with the difference.

## Data quality rules (Silver)
- Duplicate transaction IDs: keep one row.
- Missing account, unknown account, zero amount, or negative amount: move to `silver.quarantine_transactions` with a reason. Nothing is silently dropped.

## SCD Type 2
- Customers: city, state and segment changes create a new version.
- Accounts: status, type and branch changes create a new version.
- Each version has `valid_from`, `valid_to` and `is_current`.
- Facts join to the version that was valid when the transaction happened.

## Incremental loading
- Every batch gets a batch ID and a row in `audit.etl_batch_audit`.
- Already loaded batches are skipped, so re-running is safe.
- `fact_transactions` loads only batches newer than the last one loaded. Late-arriving rows are picked up because they arrive in a later batch.