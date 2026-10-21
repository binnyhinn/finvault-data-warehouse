from pathlib import Path

import pandas as pd
import psycopg2
import streamlit as st

ROOT = Path(__file__).resolve().parent.parent
st.set_page_config(page_title="FinVault", layout="wide")


@st.cache_resource
def conn():
    env = {}
    for line in (ROOT / ".env").read_text().splitlines():
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()
    return psycopg2.connect(host="localhost", port=env.get("POSTGRES_PORT", "5432"),
                            dbname=env["POSTGRES_DB"], user=env["POSTGRES_USER"],
                            password=env["POSTGRES_PASSWORD"])


def q(sql):
    with conn().cursor() as cur:
        cur.execute(sql)
        cols = [c[0] for c in cur.description]
        return pd.DataFrame(cur.fetchall(), columns=cols)


st.title("FinVault: Financial Data Warehouse")
st.caption("Synthetic banking data. Bronze, Silver and Gold layers in PostgreSQL.")

kpi = q("""SELECT COUNT(*)::int AS txns, COALESCE(SUM(amount), 0)::float AS volume
           FROM gold.fact_transactions WHERE is_posted""")
rec = q("""SELECT COUNT(*) FILTER (WHERE status = 'FAIL')::int AS fails, COUNT(*)::int AS checks
           FROM gold.reconciliation WHERE check_name = 'MOVEMENT'""")
quar = q("SELECT COUNT(*)::int AS n FROM silver.quarantine_transactions")

c1, c2, c3, c4 = st.columns(4)
c1.metric("Posted transactions", f"{kpi.txns[0]:,}")
c2.metric("Total volume (INR)", f"{kpi.volume[0]:,.0f}")
c3.metric("Balance checks failed", f"{rec.fails[0]} of {rec.checks[0]:,}")
c4.metric("Rows quarantined", int(quar.n[0]))

st.subheader("Daily transaction volume")
daily = q("""SELECT d.full_date, f.direction, SUM(f.amount)::float AS amount
             FROM gold.fact_transactions f JOIN gold.dim_date d ON d.date_key = f.date_key
             WHERE f.is_posted GROUP BY 1, 2 ORDER BY 1""")
st.line_chart(daily.pivot(index="full_date", columns="direction", values="amount"))

left, right = st.columns(2)
with left:
    st.subheader("Volume by customer segment")
    seg = q("""SELECT segment, SUM(total_amount)::float AS amount
               FROM gold.mart_customer_segments GROUP BY 1 ORDER BY 2 DESC""")
    st.bar_chart(seg.set_index("segment"))
with right:
    st.subheader("Volume by transaction category")
    cat = q("""SELECT category, SUM(total_amount)::float AS amount
               FROM gold.mart_monthly_transactions GROUP BY 1 ORDER BY 2 DESC""")
    st.bar_chart(cat.set_index("category"))

st.subheader("Reconciliation breaks (largest first)")
st.caption("Each row is a day where opening balance + posted transactions did not equal closing balance.")
st.dataframe(q("""SELECT account_id, business_date, expected::float, actual::float, difference::float
                  FROM gold.reconciliation WHERE check_name = 'MOVEMENT' AND status = 'FAIL'
                  ORDER BY ABS(difference) DESC LIMIT 25"""), width="stretch")
