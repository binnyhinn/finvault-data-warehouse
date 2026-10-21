import argparse, csv
from pathlib import Path

import psycopg2
from psycopg2.extras import execute_values

RAW = Path("data/raw")
TABLES = ["customers", "accounts", "transactions", "daily_balances"]


def load_env():
    env = {}
    for line in Path(".env").read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()
    return env


def connect():
    e = load_env()
    return psycopg2.connect(host="localhost", port=e.get("POSTGRES_PORT", "5432"),
                            dbname=e["POSTGRES_DB"], user=e["POSTGRES_USER"],
                            password=e["POSTGRES_PASSWORD"])


def load_batch(conn, batch_dir):
    batch_date = batch_dir.name.split("=")[1]
    cur = conn.cursor()

    # safe rerun: skip batches that already succeeded
    cur.execute("SELECT 1 FROM audit.etl_batch_audit "
                "WHERE batch_date = %s AND status = 'SUCCESS'", (batch_date,))
    if cur.fetchone():
        print(batch_date, "already loaded, skipping")
        return

    # audit row first, committed on its own so it survives a failed load
    cur.execute("INSERT INTO audit.etl_batch_audit (batch_date) VALUES (%s) "
                "RETURNING batch_id", (batch_date,))
    batch_id = cur.fetchone()[0]
    conn.commit()

    rows_read = rows_loaded = 0
    try:
        for table in TABLES:
            f = batch_dir / f"{table}.csv"
            if not f.exists():
                continue
            with open(f, newline="") as fh:
                reader = csv.reader(fh)
                header = next(reader)
                rows = [[(v if v != "" else None) for v in r] + [batch_id, f.name]
                        for r in reader]
            rows_read += len(rows)
            if rows:
                cols = ", ".join(header + ["batch_id", "source_file"])
                execute_values(cur, f"INSERT INTO bronze.{table} ({cols}) VALUES %s", rows)
                rows_loaded += len(rows)

        cur.execute("UPDATE audit.etl_batch_audit SET status = 'SUCCESS', rows_read = %s, "
                    "rows_loaded = %s, finished_at = now() WHERE batch_id = %s",
                    (rows_read, rows_loaded, batch_id))
        conn.commit()
        print(batch_date, "loaded", rows_loaded, "rows (batch", batch_id, ")")
    except Exception as ex:
        conn.rollback()
        cur.execute("UPDATE audit.etl_batch_audit SET status = 'FAILED', "
                    "finished_at = now(), error_message = %s WHERE batch_id = %s",
                    (str(ex)[:500], batch_id))
        conn.commit()
        print(batch_date, "FAILED:", ex)
        raise


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--date", help="load only this batch date, e.g. 2026-07-01")
    args = ap.parse_args()

    conn = connect()
    folders = sorted(RAW.glob("batch_date=*"))
    if args.date:
        folders = [f for f in folders if f.name == f"batch_date={args.date}"]
    for folder in folders:
        load_batch(conn, folder)
    conn.close()
