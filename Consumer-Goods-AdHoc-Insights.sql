-- Query 1: List of markets for "Atliq Exclusive" in APAC
SELECT DISTINCT
    market
FROM
    dim_customer
WHERE
    region = 'APAC'
        AND customer = 'Atliq Exclusive';

-- Query 2: Unique product percentage change (2021 vs 2020)
WITH cte1 AS (
    SELECT
        fiscal_year,
        COUNT(DISTINCT Product_code) AS unique_products
    FROM
        fact_sales_monthly
    GROUP BY
        fiscal_year
)

SELECT 
    up_2020.unique_products AS unique_products_2020,
    up_2021.unique_products AS unique_products_2021,
    ROUND(
        ((up_2021.unique_products - up_2020.unique_products) / up_2020.unique_products * 100), 2
    ) AS percentage_change
FROM 
    cte1 up_2020
CROSS JOIN 
    cte1 up_2021
    WHERE 
    up_2020.fiscal_year = 2020
    AND up_2021.fiscal_year = 2021;

-- Query 3: Unique product count by segment (descending)
SELECT 
    segment, COUNT(DISTINCT product_code) AS product_count
FROM
    dim_product
GROUP BY segment
ORDER BY product_count DESC;

-- Query 4: Segment with most product growth in 2021 vs 2020
WITH cte1 AS (
    SELECT 
        dp.segment,
        COUNT(DISTINCT fsm.product_code) AS unique_products,
        fsm.fiscal_year
    FROM
        fact_sales_monthly fsm
    JOIN dim_product dp ON fsm.product_code = dp.product_code
    WHERE fsm.fiscal_year IN (2020, 2021)
    GROUP BY dp.segment, fsm.fiscal_year)
SELECT 
    up_2020.segment,
    up_2020.unique_products AS product_count_2020,
    up_2021.unique_products AS product_count_2021,
    up_2021.unique_products - up_2020.unique_products AS difference
FROM 
    cte1 up_2020
JOIN 
    cte1 up_2021 
    ON up_2020.segment = up_2021.segment
WHERE 
    up_2020.fiscal_year = 2020 AND up_2021.fiscal_year = 2021
ORDER BY difference DESC;

-- Query 5: Highest and lowest manufacturing cost products
SELECT 
    p.product_code, product, manufacturing_cost
FROM
    fact_manufacturing_cost m
        JOIN
    dim_product p ON p.product_code = m.product_code
WHERE
    manufacturing_cost = (SELECT 
            MAX(manufacturing_cost)
        FROM
            fact_manufacturing_cost)
        OR manufacturing_cost = (SELECT 
            MIN(manufacturing_cost)
        FROM
            fact_manufacturing_cost)
ORDER BY manufacturing_cost DESC;

-- Query 6: Top 5 customers with highest avg pre-invoice discount in 2021 (India)
SELECT
    c.customer_code,
    c.customer,
    ROUND(AVG(pre_invoice_discount_pct), 2) AS avg_discount_percentage
FROM
    fact_pre_invoice_deductions pid
        JOIN
    dim_customer c ON c.customer_code = pid.customer_code
WHERE
    fiscal_year = 2021 AND market = 'India'
GROUP BY c.customer_code
ORDER BY avg_discount_percentage DESC
LIMIT 5;

-- Query 7: Monthly gross sales for "Atliq Exclusive"
SELECT MONTHNAME(date) AS 	months,
    MONTH(date) AS month_num,
    YEAR(date) as year,
    sold_quantity * gross_price AS gross_sales
FROM
    fact_sales_monthly s
        JOIN
    fact_gross_price g ON s.product_code = g.product_code
        JOIN
    dim_customer c ON c.customer_code = s.customer_code
WHERE
    customer = 'Atliq Exclusive')
    
SELECT 
    months,
    year,
    CONCAT(ROUND(SUM(gross_sales) / 1000000, 2), ' M') AS gross_sales_amount
FROM cte1
GROUP BY year , months
ORDER BY year , month_num;

-- Query 8: Quarter with highest total_sold_quantity in 2020
WITH cte1 AS (
 SELECT 
    MONTH(date) AS month_num, date, fiscal_year, sold_quantity
FROM
    fact_sales_monthly)
    
    SELECT  
    CASE
    WHEN month_num BETWEEN 9 AND 11 THEN "Q1"
    WHEN month_num = 12 OR month_num BETWEEN 1 AND 2 THEN "Q2"
    WHEN month_num BETWEEN 3 AND 5 THEN "Q3"
    WHEN month_num BETWEEN 6 AND 8 THEN "Q4"
    END AS quarters,
    ROUND(SUM(sold_quantity)/1000000, 2) AS total_sold_qty_in_millions
    FROM cte1
    WHERE fiscal_year = 2020
    GROUP BY quarters
    ORDER BY total_sold_qty_in_millions DESC;

-- Query 9: Channel with most gross sales and % contribution in 2021
WITH cte1 AS (
SELECT 
    channel,
    SUM(gross_price * sold_quantity) AS gross_sales,
    s.fiscal_year
FROM
    fact_sales_monthly s
        JOIN
    fact_gross_price g ON s.product_code = g.product_code
        JOIN
    dim_customer c ON c.customer_code = s.customer_code
    WHERE s.fiscal_year = 2021 
    GROUP BY channel
    ORDER BY gross_sales DESC )
    
    SELECT channel, ROUND(gross_sales/1000000, 2) AS gross_sales_mln, ROUND((gross_sales/SUM(gross_sales) OVER())*100, 2) AS percentage
    FROM cte1;

-- Query 10: Top 3 products by quantity per division in 2021
WITH cte1 AS (
SELECT 
    division,
    p.product_code,
    product,
    SUM(sold_quantity) AS total_sold_qty
FROM
    dim_product p
        JOIN
    fact_sales_monthly s ON p.product_code = s.product_code
WHERE
    fiscal_year = 2021
    GROUP BY p.product_code),
    
ranked_products AS (
SELECT *, 
	RANK() OVER(PARTITION BY division ORDER BY total_sold_qty DESC) AS rank_order
    FROM cte1)

SELECT * FROM ranked_products 
WHERE rank_order <= 3
