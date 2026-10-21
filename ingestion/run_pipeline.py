import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL_STEPS = [
    "sql/silver/01_silver_transactions.sql",
    "sql/silver/02_silver_reference.sql",
    "sql/gold/01_dim_date_and_types.sql",
    "sql/gold/02_dim_customer_account.sql",
    "sql/gold/03_facts.sql",
    "sql/gold/04_reconciliation.sql",
    "sql/gold/05_marts.sql",
]


def run_sql(rel):
    print("SQL ->", rel)
    with open(ROOT / rel) as f:
        subprocess.run(["docker", "exec", "-i", "finvault_postgres", "psql", "-U", "finvault",
                        "-d", "finvault", "-v", "ON_ERROR_STOP=1", "-q"],
                       stdin=f, check=True)


def env_with_password():
    env = dict(os.environ)
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith("POSTGRES_PASSWORD="):
            env["POSTGRES_PASSWORD"] = line.split("=", 1)[1].strip()
    return env


if __name__ == "__main__":
    print("1. bronze load (incremental, skips loaded batches)")
    subprocess.run([sys.executable, str(ROOT / "ingestion/load_bronze.py")], cwd=ROOT, check=True)
    for step in SQL_STEPS[:5]:
        run_sql(step)
    print("dbt tests")
    subprocess.run(["dbt", "test", "--profiles-dir", "."], cwd=ROOT / "dbt_project",
                   env=env_with_password(), check=True)
    run_sql(SQL_STEPS[5])
    run_sql(SQL_STEPS[6])
    print("pipeline finished")

