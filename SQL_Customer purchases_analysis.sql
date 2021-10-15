# Customer Purchases analysis on the famrers market dataset
# Counting New vs. Returning Customers by Week
WITH
customer_markets_attended AS
(
 SELECT DISTINCT
 customer_id,
 market_date,
 MIN(market_date) OVER(PARTITION BY cp.customer_id) AS first_purchase_date
 FROM farmers_market.customer_purchases cp
)
SELECT
 md.market_year,
 md.market_week,
 COUNT(customer_id) AS customer_visit_count,
 COUNT(DISTINCT customer_id) AS distinct_customer_count,
 COUNT(DISTINCT
	CASE WHEN cma.market_date = cma.first_purchase_date
	THEN customer_id
	ELSE NULL
	END) AS new_customer_count,
	COUNT(DISTINCT
	CASE WHEN cma.market_date = cma.first_purchase_date
	THEN customer_id
	ELSE NULL
	END)/ COUNT(DISTINCT customer_id) AS new_customer_percent
FROM customer_markets_attended AS cma
 LEFT JOIN farmers_market.market_date_info AS md
 ON cma.market_date = md.market_date
GROUP BY md.market_year, md.market_week
ORDER BY md.market_year, md.market_week

# Customer appreciation table for spending more than $50
SELECT cp.customer_id, c.customer_first_name,
 c.customer_last_name, SUM(quantity * cost_to_customer_per_qty) AS total_spent
FROM farmers_market.customer c
 LEFT JOIN farmers_market.customer_purchases cp
 ON c.customer_id = cp.customer_id
GROUP BY cp.customer_id, c.customer_first_name, c.customer_last_name
HAVING total_spent > 50
ORDER BY c.customer_last_name, c.customer_first_name

# Creating a CTE analysing customer purchases based on zip code and distance from market
WITH customer_and_zip_data AS
(
 SELECT
 c.customer_id,
 DATEDIFF(MAX(market_date), MIN(market_date)) AS customer_duration_days,
 COUNT(DISTINCT market_date) AS number_of_markets,
 ROUND(SUM(quantity * cost_to_customer_per_qty), 2) AS total_spent,
 ROUND(SUM(quantity * cost_to_customer_per_qty) / COUNT(DISTINCT market_date),2) AS average_spent_per_market,
 c.customer_zip,
 z.median_household_income AS zip_median_household_income,
 z.percent_high_income AS zip_percent_high_income,
 z.percent_under_18 AS zip_percent_under_18,
 z.percent_over_65 AS zip_percent_over_65,
 z.people_per_sq_mile AS zip_people_per_sq_mile,
ROUND(2 * 3961 * ASIN(SQRT(POWER(SIN(RADIANS((z.latitude - 38.4463) / 2)),2) +
COS(RADIANS(38.4463)) * COS(RADIANS(z.latitude)) * POWER((SIN(RADIANS((z.longitude - -
78.8712) / 2))), 2)))) AS zip_miles_from_market
 FROM farmers_market.customer AS c
 LEFT JOIN farmers_market.customer_purchases AS cp
 ON cp.customer_id = c.customer_id
 LEFT JOIN zip_data AS z
 ON c.customer_zip = z.zip_code_5
 GROUP BY c.customer_id
)

# Summarising avg customer purchases, count of customers per zipcode and distance from market
SELECT cz.customer_zip,
 COUNT(cz.customer_id) AS customer_count,
 ROUND(AVG(cz.total_spent)) AS average_total_spent,
 MIN(cz.zip_miles_from_market) AS zip_miles_from_market
FROM customer_and_zip_data AS cz
GROUP BY cz.customer_zip

