-- precompute margin % and year/month once so queries don't repeat it
DROP VIEW IF EXISTS orders_enriched;
CREATE VIEW orders_enriched AS
SELECT
    *,
    ROUND(100.0 * Profit / NULLIF(Sales, 0), 2) AS profit_margin_pct,
    CAST(strftime('%Y', order_date_iso) AS INTEGER)  AS order_year,
    CAST(strftime('%m', order_date_iso) AS INTEGER)  AS order_month
FROM orders;

-- discount buckets, used in Q4
DROP TABLE IF EXISTS discount_tier;
CREATE TABLE discount_tier (
    tier_label TEXT PRIMARY KEY,
    min_discount REAL,
    max_discount REAL
);
INSERT INTO discount_tier VALUES
    ('No discount',   0.0,  0.0),
    ('Low (1-20%)',   0.01, 0.20),
    ('Medium (21-40%)', 0.21, 0.40),
    ('High (41%+)',   0.41, 1.00);
