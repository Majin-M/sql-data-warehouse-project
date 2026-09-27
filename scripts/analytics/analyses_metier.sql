/*
===============================================================================
Analyses métier : Comportement client, performance produit et tendances
===============================================================================
Objectif du script :
    Ce script regroupe les requêtes d'analyse répondant aux exigences BI
    du projet. Elles s'appuient exclusivement sur la couche Gold.

    1. Vue d'ensemble : indicateurs clés
    2. Tendances de vente : évolution dans le temps et cumul
    3. Performance produit : comparaison annuelle et contribution
    4. Comportement client : segmentation et répartition

Notes d'utilisation :
    - Les requêtes sont indépendantes : exécutez-les une par une.
    - Prérequis : scripts/gold/ddl_gold.sql et scripts/gold/ddl_gold_reports.sql.
===============================================================================
*/

-- =============================================================================
-- 1. Vue d'ensemble : indicateurs clés
-- =============================================================================
SELECT 'Chiffre d''affaires total' AS measure_name, SUM(sales_amount) AS measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Quantité totale vendue', SUM(quantity) FROM gold.fact_sales
UNION ALL
SELECT 'Prix de vente moyen', AVG(price) FROM gold.fact_sales
UNION ALL
SELECT 'Nombre de commandes', COUNT(DISTINCT order_number) FROM gold.fact_sales
UNION ALL
SELECT 'Nombre de produits', COUNT(product_key) FROM gold.dim_products
UNION ALL
SELECT 'Nombre de clients', COUNT(customer_key) FROM gold.dim_customers
UNION ALL
SELECT 'Nombre de clients ayant commandé', COUNT(DISTINCT customer_key) FROM gold.fact_sales;

-- Période couverte par les ventes
SELECT
    MIN(order_date)                                  AS first_order_date,
    MAX(order_date)                                  AS last_order_date,
    DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS order_range_months
FROM gold.fact_sales;

-- =============================================================================
-- 2. Tendances de vente
-- =============================================================================
-- Évolution mensuelle des ventes
SELECT
    DATETRUNC(MONTH, order_date)  AS order_month,
    SUM(sales_amount)             AS total_sales,
    COUNT(DISTINCT customer_key)  AS total_customers,
    SUM(quantity)                 AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY order_month;

-- Cumul des ventes et moyenne mobile du prix, par année
SELECT
    order_year,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_year) AS running_total_sales,
    AVG(avg_price)   OVER (ORDER BY order_year) AS moving_average_price
FROM (
    SELECT
        DATETRUNC(YEAR, order_date) AS order_year,
        SUM(sales_amount)           AS total_sales,
        AVG(price)                  AS avg_price
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(YEAR, order_date)
) t
ORDER BY order_year;

-- Ventes par pays
SELECT
    c.country,
    SUM(f.sales_amount)            AS total_sales,
    COUNT(DISTINCT f.customer_key) AS total_customers
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY c.country
ORDER BY total_sales DESC;

-- =============================================================================
-- 3. Performance produit
-- =============================================================================
-- Performance annuelle de chaque produit, comparée à sa moyenne
-- et à l'année précédente
WITH yearly_product_sales AS (
    SELECT
        YEAR(f.order_date)  AS order_year,
        p.product_name,
        SUM(f.sales_amount) AS current_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY
        YEAR(f.order_date),
        p.product_name
)
SELECT
    order_year,
    product_name,
    current_sales,
    AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
    current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
    CASE
        WHEN current_sales > AVG(current_sales) OVER (PARTITION BY product_name) THEN 'Au-dessus de la moyenne'
        WHEN current_sales < AVG(current_sales) OVER (PARTITION BY product_name) THEN 'En dessous de la moyenne'
        ELSE 'Dans la moyenne'
    END AS avg_change,
    LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS py_sales,
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_py,
    CASE
        WHEN LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) IS NULL THEN 'n/a' -- Première année de vente
        WHEN current_sales > LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) THEN 'Hausse'
        WHEN current_sales < LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) THEN 'Baisse'
        ELSE 'Stable'
    END AS py_change
FROM yearly_product_sales
ORDER BY product_name, order_year;

-- Contribution de chaque catégorie au chiffre d'affaires total
WITH category_sales AS (
    SELECT
        p.category,
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    GROUP BY p.category
)
SELECT
    category,
    total_sales,
    SUM(total_sales) OVER () AS overall_sales,
    CAST(CAST(total_sales AS FLOAT) * 100 / SUM(total_sales) OVER () AS DECIMAL(5, 2)) AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC;

-- Top 5 et flop 5 des produits par chiffre d'affaires
SELECT TOP 5
    product_name,
    total_sales
FROM gold.report_products
ORDER BY total_sales DESC;

SELECT TOP 5
    product_name,
    total_sales
FROM gold.report_products
ORDER BY total_sales ASC;

-- Répartition des produits par segment de performance
SELECT
    product_segment,
    COUNT(*)         AS total_products,
    SUM(total_sales) AS total_sales
FROM gold.report_products
GROUP BY product_segment
ORDER BY total_sales DESC;

-- =============================================================================
-- 4. Comportement client
-- =============================================================================
-- Répartition des clients par segment (VIP, Régulier, Nouveau)
SELECT
    customer_segment,
    COUNT(*)                AS total_customers,
    SUM(total_sales)        AS total_sales,
    AVG(avg_order_value)    AS avg_order_value
FROM gold.report_customers
GROUP BY customer_segment
ORDER BY total_customers DESC;

-- Répartition des clients par tranche d'âge
SELECT
    age_group,
    COUNT(*)         AS total_customers,
    SUM(total_sales) AS total_sales
FROM gold.report_customers
GROUP BY age_group
ORDER BY age_group;

-- Top 10 des clients par chiffre d'affaires
SELECT TOP 10
    customer_number,
    customer_name,
    customer_segment,
    total_orders,
    total_sales
FROM gold.report_customers
ORDER BY total_sales DESC;

-- Clients n'ayant passé qu'une seule commande
SELECT
    COUNT(*) AS one_time_customers,
    CAST(CAST(COUNT(*) AS FLOAT) * 100 / (SELECT COUNT(*) FROM gold.report_customers) AS DECIMAL(5, 2)) AS percentage_of_customers
FROM gold.report_customers
WHERE total_orders = 1;
