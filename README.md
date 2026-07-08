# Retail Sales & Profitability Analysis

SQL + Python analysis of 9,994 retail orders (2014-2017) from the well-known "Superstore" dataset, answering the standard set of questions a retail analyst is actually asked: where's the money, where's it leaking, and is discounting helping or hurting.

## Dataset

`data/superstore.csv` — 9,994 orders: Order/Ship dates, Customer, Segment, Region, Category, Sub-Category, Product, Sales, Discount, Profit. Downloaded from Kaggle ([Superstore Dataset](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final)) — a real, widely-used retail dataset, not synthetic.

**Data quality notes (found during cleaning, not assumed):** the raw CSV is Latin-1 encoded, not UTF-8 (typical of Excel exports on Windows) — loading with the wrong encoding throws a decode error. Dates are stored as US-format strings (`M/D/YYYY`); sorting them as text before parsing gives a wrong date range (looked like Jan-Sep 2017 only; the real range is 2014-01-03 to 2017-12-30). No nulls, no fully duplicated rows; 8 rows share an Order ID + Product ID (same product appearing twice on one order — plausible, not treated as an error).

## Tools

SQLite (via Python's `sqlite3`), pandas, matplotlib.

## How to run

**As a script** (fast, regenerates all files):
```bash
pip install -r requirements.txt
python analysis/clean_and_analyze.py
```
Loads and cleans the CSV, loads it into an in-memory SQLite database, applies `sql/schema.sql`, runs every query in `sql/queries.sql`, saves results to `analysis/query_results/`, and regenerates the charts in `visuals/`.

**As a notebook** (readable, walks through the analysis step by step with explanations and inline charts):
```bash
pip install -r requirements.txt
jupyter notebook notebooks/analysis.ipynb
```
`notebooks/analysis.ipynb` covers the same analysis with markdown commentary between each step — this is the version to open on GitHub, since it renders with all outputs and charts already visible.

## What's in `sql/queries.sql`

10 queries covering: `GROUP BY` on multiple dimensions, a range-condition `JOIN` (against a discount-tier lookup table, not just equality joins), `LAG()` for month-over-month and year-over-year growth, `RANK()` inside a CTE for top-N-per-group, and SQLite date arithmetic (`julianday()`) for a shipping-time analysis. A `VIEW` (`orders_enriched`) precomputes profit margin once so every query downstream just references it instead of repeating the division.

## Key findings

**1. Furniture Tables lose more money than any other sub-category makes: -$17,725 total profit on $206,966 of sales (-14.8% margin), and Bookcases lose another -$3,473.** These aren't small numbers — Tables alone erase about 6% of the company's entire profit.

**2. Discounting past ~20% turns profitable orders into losses, and it's not subtle.** Average margin by discount tier: no discount = 34.0%, 1-20% off = 17.4%, 21-40% off = **-16.7%**, 41%+ off = **-108.9%**. Past a certain discount threshold, the company is often selling at a loss larger than the sale price itself. This is the single most actionable finding in the dataset — it's a pricing/discount-approval policy problem, not a "sell more" problem.

**3. The worst individual products are 3D printers and specialty machines, not cheap items.** The single worst product, a Cubify CubeX 3D printer, lost -$8,880 on just 3 orders sold at 53% average discount. This is a good example of why "worst by total profit" and "worst by margin %" can point to different SKUs — a low-volume, high-discount, high-ticket item can out-lose an entire category of cheap products.

**4. A subtlety worth knowing (this is the kind of thing that trips people up in an interview):** the Machines sub-category shows a *negative average margin per order* (-7.2%) in Q1, but *positive total profit* (+$3,385). Those aren't contradictory — a handful of large, high-margin machine sales can outweigh many small money-losing ones when you sum profit dollars instead of averaging percentages. Always check which aggregation you're actually looking at before drawing a conclusion.

**5. Growth story: Technology and Office Supplies both grew ~20-39% year-over-year in 2016-2017, while Furniture growth slowed to +8.3% in 2017** after +16.7% in 2016 — worth flagging given Furniture is also where the profit leak is concentrated. Growing a category that's actively losing money isn't automatically good news.

**6. Standard Class shipping averages 5.0 days versus 0.04 days for Same Day** — sanity-checks correctly (Same Day should be ~same day), and confirms the shipping data itself is trustworthy before drawing operational conclusions from it.

## Files

```
03-retail-sales-profitability-analysis/
├── data/superstore.csv
├── sql/schema.sql                     # orders_enriched view + discount_tier lookup
├── sql/queries.sql                    # 10 annotated business-question queries
├── analysis/clean_and_analyze.py      # cleaning + full pipeline (script version)
├── analysis/query_results/            # CSV output of each query
├── notebooks/analysis.ipynb           # same analysis, notebook version with narrative + inline charts
├── visuals/                           # generated charts (PNG)
└── requirements.txt
```
