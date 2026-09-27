/*
===============================================================================
Script DDL : Création des vues de reporting Gold
===============================================================================
Objectif du script :
    Ce script crée les vues de reporting de la couche Gold, construites à
    partir du schéma en étoile (gold.fact_sales, gold.dim_customers,
    gold.dim_products). Elles consolident les indicateurs clés par client
    et par produit, prêts à être consommés par un outil de BI.

    Prérequis : exécuter au préalable scripts/gold/ddl_gold.sql.

Utilisation :
    SELECT * FROM gold.report_customers;
    SELECT * FROM gold.report_products;
===============================================================================
*/

-- =============================================================================
-- Création du rapport : gold.report_customers
-- =============================================================================
/*
Points clés :
    1. Rassemble les informations essentielles : nom, âge et historique d'achat.
    2. Segmente les clients par catégorie (VIP, Régulier, Nouveau)
       et par tranche d'âge.
    3. Agrège les indicateurs au niveau client :
       - nombre total de commandes
       - montant total des ventes
       - quantité totale achetée
       - nombre de produits distincts
       - ancienneté (en mois)
    4. Calcule des KPI :
       - récence (mois écoulés depuis la dernière commande)
       - panier moyen
       - dépense mensuelle moyenne
*/
IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
    DROP VIEW gold.report_customers;
GO

CREATE VIEW gold.report_customers AS

WITH base_query AS (
    -- Récupération des colonnes utiles depuis le schéma en étoile
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON c.customer_key = f.customer_key
    WHERE f.order_date IS NOT NULL
),

customer_aggregation AS (
    -- Agrégation des indicateurs au niveau client
    SELECT
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number)                     AS total_orders,
        SUM(sales_amount)                                AS total_sales,
        SUM(quantity)                                    AS total_quantity,
        COUNT(DISTINCT product_key)                      AS total_products,
        MAX(order_date)                                  AS last_order_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
    FROM base_query
    GROUP BY
        customer_key,
        customer_number,
        customer_name,
        age
)

SELECT
    customer_key,
    customer_number,
    customer_name,
    age,
    CASE
        WHEN age IS NULL THEN 'n/a'
        WHEN age < 20    THEN 'Moins de 20 ans'
        WHEN age < 30    THEN '20-29 ans'
        WHEN age < 40    THEN '30-39 ans'
        WHEN age < 50    THEN '40-49 ans'
        ELSE '50 ans et plus'
    END AS age_group,
    CASE
        WHEN lifespan >= 12 AND total_sales > 5000  THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Régulier'
        ELSE 'Nouveau'
    END AS customer_segment,
    last_order_date,
    DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan,
    -- Panier moyen
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS avg_order_value,
    -- Dépense mensuelle moyenne
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_spend
FROM customer_aggregation;
GO

-- =============================================================================
-- Création du rapport : gold.report_products
-- =============================================================================
/*
Points clés :
    1. Rassemble les informations essentielles : nom, catégorie,
       sous-catégorie et coût.
    2. Segmente les produits selon leur chiffre d'affaires
       (Haute performance, Performance moyenne, Faible performance).
    3. Agrège les indicateurs au niveau produit :
       - nombre total de commandes
       - montant total des ventes
       - quantité totale vendue
       - nombre de clients distincts
       - durée de vie commerciale (en mois)
    4. Calcule des KPI :
       - récence (mois écoulés depuis la dernière vente)
       - revenu moyen par commande
       - revenu mensuel moyen
*/
IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;
GO

CREATE VIEW gold.report_products AS

WITH base_query AS (
    -- Récupération des colonnes utiles depuis le schéma en étoile
    SELECT
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
),

product_aggregation AS (
    -- Agrégation des indicateurs au niveau produit
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
        MAX(order_date)                                  AS last_sale_date,
        COUNT(DISTINCT order_number)                     AS total_orders,
        COUNT(DISTINCT customer_key)                     AS total_customers,
        SUM(sales_amount)                                AS total_sales,
        SUM(quantity)                                    AS total_quantity,
        ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)), 1) AS avg_selling_price
    FROM base_query
    GROUP BY
        product_key,
        product_name,
        category,
        subcategory,
        cost
)

SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    last_sale_date,
    DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency_in_months,
    CASE
        WHEN total_sales > 50000  THEN 'Haute performance'
        WHEN total_sales >= 10000 THEN 'Performance moyenne'
        ELSE 'Faible performance'
    END AS product_segment,
    lifespan,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    avg_selling_price,
    -- Revenu moyen par commande
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS avg_order_revenue,
    -- Revenu mensuel moyen
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_revenue
FROM product_aggregation;
GO
