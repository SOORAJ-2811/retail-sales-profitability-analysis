-- superstore orders, 9,994 rows, 2014-2017

-- Q1: profit by category/sub-category, losses first
SELECT
    Category,
    "Sub-Category",
    COUNT(*)                        AS num_orders,
    ROUND(SUM(Sales), 2)            AS total_sales,
    ROUND(SUM(Profit), 2)           AS total_profit,
    ROUND(AVG(profit_margin_pct), 2) AS avg_margin_pct
FROM orders_enriched
GROUP BY Category, "Sub-Category"
ORDER BY total_profit ASC;


-- Q2: month-over-month sales growth
WITH monthly AS (
    SELECT
        order_year,
        order_month,
        ROUND(SUM(Sales), 2) AS monthly_sales
    FROM orders_enriched
    GROUP BY order_year, order_month
)
SELECT
    order_year,
    order_month,
    monthly_sales,
    LAG(monthly_sales) OVER (ORDER BY order_year, order_month) AS prev_month_sales,
    ROUND(
        100.0 * (monthly_sales - LAG(monthly_sales) OVER (ORDER BY order_year, order_month))
        / LAG(monthly_sales) OVER (ORDER BY order_year, order_month), 2
    ) AS mom_growth_pct
FROM monthly
ORDER BY order_year, order_month;


-- Q3: sales/profit by region + segment
SELECT
    Region,
    Segment,
    COUNT(*)                AS num_orders,
    ROUND(SUM(Sales), 2)     AS total_sales,
    ROUND(SUM(Profit), 2)    AS total_profit
FROM orders_enriched
GROUP BY Region, Segment
ORDER BY total_sales DESC;


-- Q4: margin by discount tier (join is a range condition, not equality)
SELECT
    dt.tier_label,
    COUNT(*)                          AS num_orders,
    ROUND(AVG(o.profit_margin_pct), 2) AS avg_margin_pct,
    ROUND(SUM(o.Profit), 2)            AS total_profit
FROM orders_enriched o
JOIN discount_tier dt
  ON o.Discount BETWEEN dt.min_discount AND dt.max_discount
GROUP BY dt.tier_label
ORDER BY avg_margin_pct DESC;


-- Q5: top 10 customers by profit
SELECT
    "Customer Name",
    Segment,
    COUNT(*)               AS num_orders,
    ROUND(SUM(Sales), 2)    AS total_sales,
    ROUND(SUM(Profit), 2)   AS total_profit
FROM orders_enriched
GROUP BY "Customer Name", Segment
ORDER BY total_profit DESC
LIMIT 10;


-- Q6: worst 10 products by profit (repricing/discontinue candidates)
SELECT
    "Product Name",
    Category,
    "Sub-Category",
    COUNT(*)               AS num_orders,
    ROUND(SUM(Sales), 2)    AS total_sales,
    ROUND(SUM(Profit), 2)   AS total_profit,
    ROUND(AVG(Discount), 2) AS avg_discount
FROM orders_enriched
GROUP BY "Product Name", Category, "Sub-Category"
ORDER BY total_profit ASC
LIMIT 10;


-- Q7: avg days to ship, by ship mode
SELECT
    "Ship Mode",
    COUNT(*)                                              AS num_orders,
    ROUND(AVG(julianday(ship_date_iso) - julianday(order_date_iso)), 2) AS avg_days_to_ship
FROM orders
GROUP BY "Ship Mode"
ORDER BY avg_days_to_ship;


-- Q8: top 3 sub-categories by profit, per region
WITH region_subcat AS (
    SELECT
        Region,
        "Sub-Category",
        SUM(Profit) AS total_profit
    FROM orders_enriched
    GROUP BY Region, "Sub-Category"
),
ranked AS (
    SELECT
        *,
        RANK() OVER (PARTITION BY Region ORDER BY total_profit DESC) AS profit_rank
    FROM region_subcat
)
SELECT Region, "Sub-Category", ROUND(total_profit, 2) AS total_profit, profit_rank
FROM ranked
WHERE profit_rank <= 3
ORDER BY Region, profit_rank;


-- Q9: YoY sales growth by category
WITH yearly AS (
    SELECT
        Category,
        order_year,
        ROUND(SUM(Sales), 2) AS yearly_sales
    FROM orders_enriched
    GROUP BY Category, order_year
)
SELECT
    Category,
    order_year,
    yearly_sales,
    LAG(yearly_sales) OVER (PARTITION BY Category ORDER BY order_year) AS prev_year_sales,
    ROUND(
        100.0 * (yearly_sales - LAG(yearly_sales) OVER (PARTITION BY Category ORDER BY order_year))
        / LAG(yearly_sales) OVER (PARTITION BY Category ORDER BY order_year), 2
    ) AS yoy_growth_pct
FROM yearly
ORDER BY Category, order_year;


-- Q10: overall KPIs
SELECT
    COUNT(*)                     AS total_orders,
    ROUND(SUM(Sales), 2)         AS total_sales,
    ROUND(SUM(Profit), 2)        AS total_profit,
    ROUND(100.0 * SUM(Profit) / SUM(Sales), 2) AS overall_margin_pct,
    ROUND(AVG(Discount), 3)      AS avg_discount
FROM orders_enriched;
