/*
===============================================================================
Contrôles qualité : Couche Gold
===============================================================================
Objectif du script :
    Ce script effectue des contrôles de qualité afin de valider l'intégrité,
    la cohérence et l'exactitude de la couche Gold. Il vérifie :
    - L'unicité des clés de substitution dans les tables de dimension.
    - L'intégrité référentielle entre la table de faits et les dimensions.
    - La validité des relations du modèle de données à des fins analytiques.

Notes d'utilisation :
    - Toute ligne retournée signale une anomalie à investiguer.
===============================================================================
*/

-- ====================================================================
-- Contrôles 'gold.dim_customers'
-- ====================================================================
-- Unicité de la clé client
-- Résultat attendu : Aucun résultat
SELECT
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- Intégration du genre (CRM prioritaire, ERP en repli)
-- Résultat attendu : 'Féminin', 'Masculin', 'n/a'
SELECT DISTINCT
    gender
FROM gold.dim_customers;

-- ====================================================================
-- Contrôles 'gold.dim_products'
-- ====================================================================
-- Unicité de la clé produit
-- Résultat attendu : Aucun résultat
SELECT
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- Unicité du numéro produit (un seul enregistrement actif par produit)
-- Résultat attendu : Aucun résultat
SELECT
    product_number,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_number
HAVING COUNT(*) > 1;

-- ====================================================================
-- Contrôles 'gold.fact_sales'
-- ====================================================================
-- Intégrité référentielle entre la table de faits et les dimensions
-- Résultat attendu : Aucun résultat
SELECT
    *
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE p.product_key IS NULL
   OR c.customer_key IS NULL;
