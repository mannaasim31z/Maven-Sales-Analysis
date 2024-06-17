-- Data Cleaning
UPDATE dim_date
SET Date=STR_TO_DATE(Date,'%m/%d/%Y');

ALTER TABLE fact_sales
MODIFY COLUMN Date DATE;


UPDATE dim_products
SET product_cost=CAST(REPLACE(Product_Cost, '$', '') AS DECIMAL(10, 2));

UPDATE dim_products
SET product_price=CAST(REPLACE(Product_Price, '$', '') AS DECIMAL(10, 2));

-- 1. Productwise Total Revenue and Quantity sold
WITH product_revenue AS (
SELECT product_name,SUM(Units) AS sold_unit,ROUND(SUM(Product_price*Units),2) AS total_revenue
FROM dim_products p 
JOIN fact_sales s 
ON p.Product_ID=s.Product_ID
GROUP BY product_name),
top_products AS (
SELECT product_name,sold_unit,total_revenue,DENSE_RANK() OVER(ORDER BY total_revenue DESC) AS rnk
FROM product_revenue)
SELECT product_name,sold_unit,total_revenue
FROM top_products
WHERE rnk<=5;

-- 2. Product With Max and Minimum Product cost
SELECT Product_ID,Product_Name,Product_Cost
FROM dim_products
WHERE Product_Cost IN ((SELECT MAX(Product_Cost) FROM dim_products),(SELECT MIN(Product_Cost) FROM dim_products));

-- 3. Top 5 Products by gross profit
WITH products AS (
SELECT product_name,ROUND(SUM((Product_price-product_cost)*Units),2) AS gross_profit
FROM dim_products p 
JOIN fact_sales s 
ON p.Product_ID=s.Product_ID
GROUP BY product_name),
top_products AS (
SELECT product_name,gross_profit,DENSE_RANK() OVER(ORDER BY gross_profit DESC) AS rnk
FROM products)
SELECT product_name,gross_profit
FROM top_products
WHERE rnk<=5;

-- 4. Top 3 Products of each category by gross profit
WITH products AS (
SELECT Product_Category,Product_Name,ROUND(SUM((Product_price-product_cost)*Units),2) AS gross_profit
FROM dim_products p 
JOIN fact_sales s 
ON p.Product_ID=s.Product_ID
GROUP BY product_name,Product_Category),
top_products AS (
SELECT Product_Category,Product_Name,gross_profit,DENSE_RANK() OVER(PARTITION BY Product_Category ORDER BY gross_profit DESC) AS rnk
FROM products)
SELECT Product_Category,Product_Name,gross_profit
FROM top_products
WHERE rnk<=3;  

-- 5. Product Category wise Gross Profit Margin
SELECT Product_Category,ROUND(SUM((Product_price-product_cost)*Units)*100/SUM(Product_Price*Units),2) AS profit_gross_margin
FROM dim_products p 
JOIN fact_sales s 
ON p.Product_ID=s.Product_ID
GROUP BY Product_Category;

-- 6. Category wise Profit per Unit
SELECT Product_Category,ROUND(SUM((Product_price-product_cost)*Units)/SUM(Units),2) AS profit_per_units
FROM dim_products p 
JOIN fact_sales s 
ON p.Product_ID=s.Product_ID
GROUP BY Product_Category
ORDER BY profit_per_units DESC;

-- 7. Products That generate 70% of total profit
WITH x AS (
SELECT p.Product_ID,Product_Name,ROUND(SUM((Product_price-product_cost)*Units),2) AS gross_profit
FROM dim_products p 
JOIN fact_sales s 
ON p.Product_ID=s.Product_ID
GROUP BY p.Product_ID,Product_Name),
y AS (
SELECT Product_ID,Product_Name,gross_profit,SUM(gross_profit) OVER() AS total_gross_profit,
SUM(gross_profit) OVER(ORDER BY gross_profit DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_sum
FROM x)
SELECT Product_ID,Product_Name,gross_profit,0.7*total_gross_profit AS 70_percentage_of_gross_profit,running_sum
FROM y
WHERE running_sum<0.7*total_gross_profit;

-- 8. Monthly Total Revenue And Quantity sold
SELECT DATE_FORMAT(Date,'%Y-%m') AS month,SUM(Units) AS units_sold,ROUND(SUM(product_price*Units),2) AS total_revenue
FROM dim_products p 
JOIN fact_sales s 
ON p.Product_ID=s.Product_ID
GROUP BY month
ORDER BY month;

-- 9. Monthly Gross Profit margin and Month over Month Change
WITH x AS (
SELECT DATE_FORMAT(Date,'%Y-%m') AS month,ROUND(SUM((Product_price-product_cost)*Units)*100/SUM(Product_Price*Units),2) AS profit_gross_margin
FROM dim_products d 
JOIN fact_sales s 
ON d.Product_ID=s.Product_ID
GROUP BY month),
y AS (
SELECT month,profit_gross_margin,LAG(profit_gross_margin,1) OVER(ORDER BY month) AS prev_month_profit_gross_margin
FROM x)
SELECT month,profit_gross_margin,prev_month_profit_gross_margin,ROUND(((profit_gross_margin/prev_month_profit_gross_margin)-1)*100,2) AS mom_change
FROM y;

-- 10. Categorywise Gross Profit Contribution Percentage
WITH products AS (
SELECT Product_Category,ROUND(SUM((Product_price-product_cost)*Units),2) AS gross_profit
FROM dim_products p
JOIN fact_sales s 
ON p.Product_ID=s.Product_ID
GROUP BY Product_Category)
SELECT Product_Category,ROUND(gross_profit*100/SUM(gross_profit) OVER(),2) AS gross_profit_contribution_percentage
FROM products;

-- 11. Monthly Revenue Trend for each category
SELECT DATE_FORMAT(Date,'%Y-%m') AS month,Product_Category,ROUND(SUM(Product_price*Units),2) AS total_revenue
FROM dim_products p 
JOIN fact_sales s 
ON p.Product_ID=s.Product_ID
GROUP BY month,Product_Category;

-- 12. Gross Profit Comparison 
WITH monthly_profit AS (
SELECT YEAR(Date) AS year,MONTH(Date) AS m_no,MONTHNAME(Date) AS month,ROUND(SUM((Product_price-product_cost)*Units),2) AS gross_profit
FROM dim_products p 
JOIN fact_sales s 
ON p.Product_ID=s.Product_ID
GROUP BY year,m_no,month)
SELECT m_no,month,
MAX(CASE WHEN year=2022 THEN gross_profit ELSE 0 END) AS 2022_gross_profit,
MAX(CASE WHEN year=2023 THEN gross_profit ELSE 0 END) AS 2023_gross_profit
FROM monthly_profit
GROUP BY m_no,month
ORDER BY m_no;

-- 13. Each Category Top & Bottom produts according to profit margin
WITH products AS (
SELECT Product_Category,Product_Name,ROUND(SUM((Product_price-product_cost)*Units),2) AS gross_profit
FROM dim_products p 
JOIN fact_sales s 
ON p.Product_ID=s.Product_ID
GROUP BY Product_Category,Product_Name),
top_bottom_products AS (
SELECT Product_Category,Product_Name,RANK() OVER(PARTITION BY Product_Category ORDER BY gross_profit DESC) AS rnk1,
RANK() OVER(PARTITION BY Product_Category ORDER BY gross_profit ASC) AS rnk2
FROM products)
SELECT Product_Category,
GROUP_CONCAT(CASE WHEN rnk1=1 THEN Product_Name ELSE NULL END) AS top_product,
GROUP_CONCAT(CASE WHEN rnk2=1 THEN Product_Name ELSE NULL END) AS bottom_product
FROM top_bottom_products
GROUP BY Product_Category;




