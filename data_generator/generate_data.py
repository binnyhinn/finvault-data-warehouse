import csv, random
from datetime import date, datetime, timedelta
from pathlib import Path

SEED = 42
N_CUSTOMERS = 200
DAYS = 30
START = date(2026, 7, 1)
LAST_DAY = START + timedelta(days=DAYS - 1)
OUT = Path("data")

rnd = random.Random(SEED)          # same seed = same data every run

FIRST = ["Arjun", "Priya", "Karthik", "Divya", "Ravi", "Meera", "Vikram", "Kavya"]
LAST = ["Kumar", "Nair", "Iyer", "Reddy", "Pillai", "Menon", "Raj", "Das"]
CITIES = [("Chennai", "Tamil Nadu"), ("Bengaluru", "Karnataka"),
          ("Kochi", "Kerala"), ("Mumbai", "Maharashtra"), ("Nagercoil", "Tamil Nadu")]
SEGMENTS = ["MASS", "PREMIUM", "BUSINESS"]


def money(paise):                  # money is stored as integer paise, never float
    return f"{paise / 100:.2f}"


customers = {}
for i in range(1, N_CUSTOMERS + 1):
    cid = f"C{i:06d}"
    city, state = rnd.choice(CITIES)
    customers[cid] = {
        "customer_id": cid,
        "first_name": rnd.choice(FIRST),
        "last_name": rnd.choice(LAST),
        "city": city,
        "state": state,
        "segment": rnd.choices(SEGMENTS, [70, 20, 10])[0],
        "updated_at": f"{START} 00:00:00",
    }

print(len(customers), "customers")

ACCT_TYPES = ["SAVINGS", "CURRENT", "SALARY"]
accounts = {}
n = 0
for cid in customers:
    for _ in range(rnd.choice([1, 1, 2])):          # 1 or 2 accounts each
        n += 1
        aid = f"A{n:07d}"
        start_bal = rnd.randint(1000, 100000) * 100
        accounts[aid] = {
            "account_id": aid,
            "customer_id": cid,
            "account_type": rnd.choice(ACCT_TYPES),
            "branch_code": f"BR{rnd.randint(1, 10):03d}",
            "status": "ACTIVE",
            "initial_balance": money(start_bal),
            "updated_at": f"{START} 00:00:00",
            "balance": start_bal,                   # running ledger, internal only
        }

print(len(accounts), "accounts")

# code, direction, min INR, max INR
TXN_TYPES = [
    ("UPI_IN", "CREDIT", 100, 20000), ("NEFT_IN", "CREDIT", 1000, 80000),
    ("UPI_OUT", "DEBIT", 20, 15000), ("POS", "DEBIT", 100, 12000),
    ("ATM_WD", "DEBIT", 500, 10000), ("BILL_PAY", "DEBIT", 200, 6000),
]
TXN_HEADER = ["transaction_id", "account_id", "txn_ts", "posting_date",
              "amount", "direction", "txn_type_code", "status", "source_updated_at"]


def write_csv(path, header, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)


tid = 0
pending = {}     # delivery_date -> late rows waiting to arrive
truth = []       # log of every defect we plant

for day in range(DAYS):
    d = START + timedelta(days=day)
    txn_rows, bal_rows = list(pending.pop(d, [])), []   # late rows arrive today

    for aid, acc in accounts.items():
        opening = acc["balance"]
        for _ in range(rnd.choices([0, 1, 2, 3], [30, 35, 25, 10])[0]):
            code, direction, lo, hi = rnd.choice(TXN_TYPES)
            amt = rnd.randint(lo * 100, hi * 100)
            if direction == "DEBIT" and amt > acc["balance"]:
                continue                                  # no overdrafts
            tid += 1
            acc["balance"] += amt if direction == "CREDIT" else -amt
            ts = datetime(d.year, d.month, d.day) + timedelta(seconds=rnd.randint(0, 86399))
            row = [f"T{tid:010d}", aid, str(ts), d.isoformat(),
                   money(amt), direction, code, "POSTED", str(ts)]

            # DEFECT 1: late arrival (money is in the balance, row shows up days later)
            if rnd.random() < 0.01 and day < DAYS - 1:
                late = min(d + timedelta(days=rnd.randint(1, 3)), LAST_DAY)
                pending.setdefault(late, []).append(row)
                truth.append(["LATE_ARRIVAL", row[0], d.isoformat(), late.isoformat()])
            else:
                txn_rows.append(row)

            # DEFECT 2: duplicate (same row delivered twice)
            if rnd.random() < 0.005:
                txn_rows.append(row)
                truth.append(["DUPLICATE_TXN", row[0], d.isoformat(), d.isoformat()])

            # DEFECT 3: invalid extra row (NOT part of the true ledger)
            if rnd.random() < 0.004:
                tid += 1
                bad = row.copy()
                bad[0] = f"T{tid:010d}"
                kind = rnd.choice(["ZERO_AMOUNT", "ORPHAN_ACCOUNT", "MISSING_ACCOUNT"])
                if kind == "ZERO_AMOUNT":
                    bad[4] = "0.00"
                elif kind == "ORPHAN_ACCOUNT":
                    bad[1] = "A9999999"
                else:
                    bad[1] = ""
                txn_rows.append(bad)
                truth.append([kind, bad[0], d.isoformat(), d.isoformat()])

        # DEFECT 4: wrong balance in the source snapshot
        reported = acc["balance"]
        if rnd.random() < 0.005:
            reported += rnd.randint(1, 50) * 100
            truth.append(["BALANCE_DISCREPANCY", aid, d.isoformat(), d.isoformat()])
        bal_rows.append([aid, d.isoformat(), money(opening), money(reported)])

    bdir = OUT / "raw" / f"batch_date={d.isoformat()}"
    write_csv(bdir / "transactions.csv", TXN_HEADER, txn_rows)
    write_csv(bdir / "daily_balances.csv",
              ["account_id", "business_date", "opening_balance", "closing_balance"], bal_rows)
    if day == 0:       # first batch = full load of customers and accounts
        write_csv(bdir / "customers.csv", list(next(iter(customers.values())).keys()),
                  [list(c.values()) for c in customers.values()])
        acc_cols = ["account_id", "customer_id", "account_type", "branch_code",
                    "status", "initial_balance", "updated_at"]
        write_csv(bdir / "accounts.csv", acc_cols,
                  [[a[c] for c in acc_cols] for a in accounts.values()])

write_csv(OUT / "ground_truth" / "injected_issues.csv",
          ["issue_type", "entity_id", "business_date", "delivery_date"], truth)
print("done:", tid, "transaction ids over", DAYS, "days")
print("planted:", len(truth), "issues")