# cleans superstore.csv, loads into sqlite, runs sql/queries.sql, builds charts
# run from project root: python analysis/clean_and_analyze.py
import os
import re
import sqlite3
import pandas as pd
import matplotlib.pyplot as plt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_CSV = os.path.join(ROOT, "data", "superstore.csv")
SCHEMA_SQL = os.path.join(ROOT, "sql", "schema.sql")
QUERIES_SQL = os.path.join(ROOT, "sql", "queries.sql")
RESULTS_DIR = os.path.join(ROOT, "analysis", "query_results")
VISUALS_DIR = os.path.join(ROOT, "visuals")
os.makedirs(RESULTS_DIR, exist_ok=True)
os.makedirs(VISUALS_DIR, exist_ok=True)

# exported from Excel on Windows -> latin-1, not utf-8
df = pd.read_csv(RAW_CSV, encoding="latin-1")

df["Order Date"] = pd.to_datetime(df["Order Date"], format="%m/%d/%Y")
df["Ship Date"] = pd.to_datetime(df["Ship Date"], format="%m/%d/%Y")

n_dupe_rows = df.duplicated().sum()
n_dupe_order_product = df.duplicated(subset=["Order ID", "Product ID"]).sum()
print(f"Rows: {len(df)}")
print(f"Fully duplicated rows: {n_dupe_rows}")
print(f"Duplicate Order+Product lines: {n_dupe_order_product}")
print(f"Date range: {df['Order Date'].min().date()} to {df['Order Date'].max().date()}")
nulls = df.isnull().sum()
print("Nulls per column:", "none" if nulls.sum() == 0 else nulls[nulls > 0].to_dict())

# sqlite date funcs expect ISO format, not M/D/Y
df["order_date_iso"] = df["Order Date"].dt.strftime("%Y-%m-%d")
df["ship_date_iso"] = df["Ship Date"].dt.strftime("%Y-%m-%d")

conn = sqlite3.connect(":memory:")
df.to_sql("orders", conn, index=False, if_exists="replace")

with open(SCHEMA_SQL) as f:
    conn.executescript(f.read())

with open(QUERIES_SQL) as f:
    sql_text = f.read()

blocks = re.split(r"(?=-- Q\d+:)", sql_text)
blocks = [b.strip() for b in blocks if b.strip().startswith("-- Q")]
print(f"\nFound {len(blocks)} labeled queries.\n")

results = {}
for block in blocks:
    qid = re.match(r"-- (Q\d+):", block).group(1)
    sql_lines = [l for l in block.splitlines() if not l.strip().startswith("--")]
    sql = "\n".join(sql_lines).strip()
    if not sql:
        continue
    try:
        result = pd.read_sql_query(sql, conn)
    except Exception as e:
        print(f"{qid} FAILED: {e}")
        continue
    results[qid] = result
    result.to_csv(os.path.join(RESULTS_DIR, f"{qid}.csv"), index=False)
    print(f"{qid}: {len(result)} rows")

conn.close()

plt.style.use("seaborn-v0_8-whitegrid")

# profit by sub-category — losses front and center
if "Q1" in results:
    q1 = results["Q1"].sort_values("total_profit")
    colors = ["#C44E52" if v < 0 else "#55A868" for v in q1["total_profit"]]
    plt.figure(figsize=(9, 6))
    plt.barh(q1["Sub-Category"], q1["total_profit"], color=colors)
    plt.title("Total Profit by Sub-Category (red = losing money)")
    plt.xlabel("Total Profit (USD)")
    plt.tight_layout()
    plt.savefig(os.path.join(VISUALS_DIR, "profit_by_subcategory.png"), dpi=150)
    plt.close()

# monthly sales trend
if "Q2" in results:
    q2 = results["Q2"].copy()
    q2["period"] = q2["order_year"].astype(str) + "-" + q2["order_month"].astype(str).str.zfill(2)
    plt.figure(figsize=(11, 4.5))
    plt.plot(q2["period"], q2["monthly_sales"], marker="o", markersize=3, color="#4C72B0")
    plt.xticks(rotation=90, fontsize=6)
    plt.title("Monthly Sales, 2014-2017")
    plt.ylabel("Sales (USD)")
    plt.tight_layout()
    plt.savefig(os.path.join(VISUALS_DIR, "monthly_sales_trend.png"), dpi=150)
    plt.close()

# discount tier vs avg margin
if "Q4" in results:
    q4 = results["Q4"]
    plt.figure(figsize=(6, 4.5))
    colors = ["#C44E52" if v < 0 else "#55A868" for v in q4["avg_margin_pct"]]
    plt.bar(q4["tier_label"], q4["avg_margin_pct"], color=colors)
    plt.axhline(0, color="black", linewidth=0.8)
    plt.title("Average Profit Margin % by Discount Tier")
    plt.ylabel("Avg Profit Margin (%)")
    plt.xticks(rotation=15)
    plt.tight_layout()
    plt.savefig(os.path.join(VISUALS_DIR, "margin_by_discount_tier.png"), dpi=150)
    plt.close()

# YoY growth by category
if "Q9" in results:
    q9 = results["Q9"].dropna(subset=["yoy_growth_pct"])
    plt.figure(figsize=(7, 4.5))
    for cat in q9["Category"].unique():
        sub = q9[q9["Category"] == cat]
        plt.plot(sub["order_year"], sub["yoy_growth_pct"], marker="o", label=cat)
    plt.axhline(0, color="black", linewidth=0.8)
    plt.title("Year-over-Year Sales Growth by Category")
    plt.ylabel("YoY Growth (%)")
    plt.legend()
    plt.tight_layout()
    plt.savefig(os.path.join(VISUALS_DIR, "yoy_growth_by_category.png"), dpi=150)
    plt.close()

print("\nCharts saved to visuals/. Done.")
