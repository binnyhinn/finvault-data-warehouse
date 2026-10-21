import csv, glob
from collections import defaultdict
from decimal import Decimal as D

# 1. Load all transactions, skipping bad rows, de-duplicating by transaction_id
txns = {}
for f in glob.glob("data/raw/*/transactions.csv"):
    for r in csv.DictReader(open(f)):
        if not r["account_id"] or r["account_id"] == "A9999999" or D(r["amount"]) <= 0:
            continue                      # invalid rows are ignored
        txns[r["transaction_id"]] = r     # same id twice = one row (dedupe)

# 2. Net movement per (account, posting_date)
move = defaultdict(D)
for r in txns.values():
    a = D(r["amount"])
    move[(r["account_id"], r["posting_date"])] += a if r["direction"] == "CREDIT" else -a

# 3. Which balance errors did we plant?
truth = {(r["entity_id"], r["business_date"])
         for r in csv.DictReader(open("data/ground_truth/injected_issues.csv"))
         if r["issue_type"] == "BALANCE_DISCREPANCY"}

# 4. Check: opening + movement = closing
breaks = set()
for f in glob.glob("data/raw/*/daily_balances.csv"):
    for r in csv.DictReader(open(f)):
        k = (r["account_id"], r["business_date"])
        if D(r["opening_balance"]) + move[k] != D(r["closing_balance"]):
            breaks.add(k)

print("breaks found:", len(breaks), "| planted:", len(truth))
print("unexplained:", len(breaks - truth), "| missed:", len(truth - breaks))