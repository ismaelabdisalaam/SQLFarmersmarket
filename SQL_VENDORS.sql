use farmers_market

# Analyse Total Sales by Vendor ID and Market date and the factors influencing sales, such as market day,market conditions, booth number and type 
WITH vendorsales_perday AS
(
SELECT
 cp.market_date,
 md.market_day,
 md.market_year,
 md.market_week,
 md.market_rain_flag,
 cp.vendor_id,
 v.vendor_name,
 v.vendor_type,
 vba.booth_number,
 b.booth_type,
 ROUND(SUM(cp.quantity * cp.cost_to_customer_per_qty),2) AS sales
FROM farmers_market.customer_purchases AS cp
 LEFT JOIN farmers_market.market_date_info AS md
 ON cp.market_date = md.market_date
 LEFT JOIN farmers_market.vendor AS v
 ON cp.vendor_id = v.vendor_id
 LEFT JOIN farmers_market.vendor_booth_assignments AS vba
 ON cp.vendor_id = vba.vendor_id
 AND cp.market_date = vba.market_date
 LEFT JOIN farmers_market.booth AS b
 ON vba.booth_number = b.booth_number
GROUP BY cp.market_date, cp.vendor_id
ORDER BY cp.market_date, cp.vendor_id
)

# Summary of Vendor sales by market week 
SELECT
 v.market_year,
 v.market_week,
 SUM(v.sales) AS weekly_sales,
 v.vendor_id
FROM vendorsales_perday AS v
GROUP BY v.market_year, v.market_week, v.vendor_id

# What is the total value of the inventory each vendor brought to each market?
SELECT market_date, vendor_id,
 ROUND(SUM(quantity * original_price),2) AS inventory_value
FROM vendor_inventory
GROUP BY market_date, vendor_id
ORDER BY market_date, vendor_id

# What quantity of each product did each vendor sell per marke date
# Did the prices of any products change over time
# What are the total sales per vendor for the season
# How frequently do vendors discount their product prices
SELECT vi.market_date,
 vi.vendor_id,
 v.vendor_name,
 vi.product_id,
 p.product_name,
 vi.quantity AS quantity_available,
 sales.quantity_sold,
 ROUND((sales.quantity_sold / vi.quantity) * 100, 2) AS percent_of_available_sold,
 vi.original_price,
 (vi.original_price * sales.quantity_sold) - sales.total_sales AS discount_amount,
 sales.total_sales
FROM farmers_market.vendor_inventory AS vi
 LEFT JOIN
 (
 SELECT market_date,
 vendor_id,
 product_id,
 SUM(quantity) quantity_sold,
 SUM(quantity * cost_to_customer_per_qty) AS total_sales
 FROM farmers_market.customer_purchases
 GROUP BY market_date, vendor_id, product_id
 ) AS sales
 ON vi.market_date = sales.market_date
 AND vi.vendor_id = sales.vendor_id
 AND vi.product_id = sales.product_id
 LEFT JOIN farmers_market.vendor v
 ON vi.vendor_id = v.vendor_id
 LEFT JOIN farmers_market.product p
 ON vi.product_id = p.product_id
ORDER BY vi.vendor_id, vi.product_id, vi.market_date


# Show the products with the largest quantities available at each market: the bulk product with the largest weight available, and the unit product with the highest count available
WITH
product_quantity_by_date AS
(
 SELECT vi.market_date,
 vi.product_id,
 p.product_name,
 SUM(vi.quantity) AS total_quantity_available,
 p.product_qty_type
 FROM farmers_market.vendor_inventory vi
 LEFT JOIN farmers_market.product p
 ON vi.product_id = p.product_id
 GROUP BY market_date, product_id
)
SELECT * FROM
(
 SELECT
 market_date,
 product_id,
 product_name,
 total_quantity_available,
 product_qty_type,
 RANK() OVER (PARTITION BY market_date ORDER BY total_quantity_available DESC) AS quantity_rank
 FROM product_quantity_by_date
 WHERE product_qty_type = 'unit'
 UNION
 SELECT market_date,
 product_id,
 product_name,
 total_quantity_available,
 product_qty_type,
 RANK() OVER (PARTITION BY market_date ORDER BY total_quantity_available DESC) AS quantity_rank
 FROM product_quantity_by_date
 WHERE product_qty_type = 'lbs'
) x
WHERE x.quantity_rank = 1
ORDER BY market_date

# how many times each vendor has rented a booth at the farmer’s market:
SELECT
 vendor_id,
 count(*) AS count_of_booth_assignments
FROM farmers_market.vendor_booth_assignments
GROUP BY vendor_id

# the current record sales and the day its been broken
WITH
sales_per_market_date AS
(
 SELECT	market_date,
 ROUND(SUM(quantity * cost_to_customer_per_qty),2) AS sales
 FROM farmers_market.customer_purchases
 GROUP BY market_date
 ORDER BY market_date
),
record_sales_per_market_date AS
(
 SELECT
 cm.market_date,
 cm.sales,
 MAX(pm.sales) AS previous_max_sales,
 CASE WHEN cm.sales > MAX(pm.sales)
 THEN "YES"
 ELSE "NO"
 END sales_record_set
 FROM sales_per_market_date AS cm
 LEFT JOIN sales_per_market_date AS pm
 ON pm.market_date < cm.market_date
 GROUP BY cm.market_date, cm.sales
)
SELECT market_date, sales
FROM record_sales_per_market_date
WHERE sales_record_set = 'YES'
ORDER BY market_date DESC
LIMIT 1

# Displays the market dates with the highest and lowest total sales
WITH
sales_per_market AS
(
 SELECT
 market_date,
 ROUND(SUM(quantity * cost_to_customer_per_qty),2) AS sales
 FROM farmers_market.customer_purchases
 GROUP BY market_date
 ),
 market_dates_ranked_by_sales AS
 (
 SELECT
 market_date,
 sales,
 RANK() OVER (ORDER BY sales) AS sales_rank_asc,
 RANK() OVER (ORDER BY sales DESC) AS sales_rank_desc
 FROM sales_per_market
 )
SELECT market_date, sales, sales_rank_desc AS sales_rank
FROM market_dates_ranked_by_sales
WHERE sales_rank_asc = 1
UNION
SELECT market_date, sales, sales_rank_desc AS sales_rank
FROM market_dates_ranked_by_sales
WHERE sales_rank_desc = 1
