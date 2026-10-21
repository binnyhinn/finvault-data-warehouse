import csv
from pathlib import Path

import psycopg2
import pytest

ROOT = Path(__file__).resolve().parent.parent


def load_env():
    env = {}
    for line in (ROOT / ".env").read_text().splitlines():
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()
    return env


@pytest.fixture(scope="module")
def cur():
    e = load_env()
    conn = psycopg2.connect(host="localhost", port=e.get("POSTGRES_PORT", "5432"),
                            dbname=e["POSTGRES_DB"], user=e["POSTGRES_USER"],
                            password=e["POSTGRES_PASSWORD"])
    yield conn.cursor()
    conn.close()


def one(cur, sql):
    cur.execute(sql)
    return cur.fetchone()[0]


def planted(kinds):
    with open(ROOT / "data/ground_truth/injected_issues.csv") as f:
        return sum(1 for r in csv.DictReader(f) if r["issue_type"] in kinds)


def test_all_batches_succeeded(cur):
    assert one(cur, "SELECT COUNT(*) FROM audit.etl_batch_audit WHERE status <> 'SUCCESS'") == 0


def test_silver_has_no_duplicate_transactions(cur):
    assert one(cur, "SELECT COUNT(*) FROM silver.transactions") == \
           one(cur, "SELECT COUNT(DISTINCT transaction_id) FROM silver.transactions")


def test_quarantine_matches_planted_bad_rows(cur):
    bad = planted({"ZERO_AMOUNT", "ORPHAN_ACCOUNT", "MISSING_ACCOUNT"})
    assert one(cur, "SELECT COUNT(*) FROM silver.quarantine_transactions") == bad


def test_gold_facts_match_silver(cur):
    assert one(cur, "SELECT COUNT(*) FROM gold.fact_transactions") == \
           one(cur, "SELECT COUNT(*) FROM silver.transactions")


def test_no_orphan_keys_in_facts(cur):
    assert one(cur, "SELECT COUNT(*) FROM gold.fact_transactions WHERE account_key IS NULL "
                    "OR customer_key IS NULL OR txn_type_key IS NULL OR date_key IS NULL") == 0


def test_one_current_row_per_customer(cur):
    assert one(cur, "SELECT COUNT(*) FROM gold.dim_customer WHERE is_current") == \
           one(cur, "SELECT COUNT(DISTINCT customer_id) FROM gold.dim_customer")


def test_reconciliation_catches_every_planted_balance_error(cur):
    fails = one(cur, "SELECT COUNT(*) FROM gold.reconciliation "
                     "WHERE check_name = 'MOVEMENT' AND status = 'FAIL'")
    assert fails == planted({"BALANCE_DISCREPANCY"})