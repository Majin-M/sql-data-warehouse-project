/*
===============================================================================
Contrôles qualité : Couche Silver
===============================================================================
Objectif du script :
    Ce script effectue divers contrôles de qualité afin de vérifier la
    cohérence, l'exactitude et la standardisation des données de la couche
    'silver'. Il comprend des contrôles sur :
    - Les clés primaires nulles ou en doublon.
    - Les espaces indésirables dans les champs texte.
    - La standardisation et la cohérence des données.
    - Les plages et l'ordre des dates invalides.
    - La cohérence entre champs liés.

Notes d'utilisation :
    - Exécutez ces contrôles après le chargement de la couche Silver
      (EXEC silver.load_silver;).
    - Chaque requête indique le résultat attendu. Toute ligne retournée
      par une requête dont le résultat attendu est "Aucun résultat"
      signale une anomalie à investiguer.
===============================================================================
*/

-- ====================================================================
-- Contrôles 'silver.crm_cust_info'
-- ====================================================================
-- Clés primaires nulles ou en doublon
-- Résultat attendu : Aucun résultat
SELECT
    cst_id,
    COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Espaces indésirables
-- Résultat attendu : Aucun résultat
SELECT
    cst_key
FROM silver.crm_cust_info
WHERE cst_key != TRIM(cst_key);

SELECT
    cst_firstname,
    cst_lastname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)
   OR cst_lastname  != TRIM(cst_lastname);

-- Standardisation et cohérence des données
-- Résultat attendu : 'Célibataire', 'Marié(e)', 'n/a'
SELECT DISTINCT
    cst_marital_status
FROM silver.crm_cust_info;

-- Résultat attendu : 'Féminin', 'Masculin', 'n/a'
SELECT DISTINCT
    cst_gndr
FROM silver.crm_cust_info;

-- ====================================================================
-- Contrôles 'silver.crm_prd_info'
-- ====================================================================
-- Clés primaires nulles ou en doublon
-- Résultat attendu : Aucun résultat
SELECT
    prd_id,
    COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Espaces indésirables
-- Résultat attendu : Aucun résultat
SELECT
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- Coûts nuls ou négatifs
-- Résultat attendu : Aucun résultat
SELECT
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Standardisation et cohérence des données
-- Résultat attendu : 'Montagne', 'Route', 'Autres ventes', 'Touring', 'n/a'
SELECT DISTINCT
    prd_line
FROM silver.crm_prd_info;

-- Ordre des dates invalide (date de début > date de fin)
-- Résultat attendu : Aucun résultat
SELECT
    *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- ====================================================================
-- Contrôles 'silver.crm_sales_details'
-- ====================================================================
-- Dates invalides dans la couche Bronze (avant transformation)
-- Résultat attendu : Dates invalides à corriger en Silver
SELECT
    NULLIF(sls_due_dt, 0) AS sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0
   OR LEN(sls_due_dt) != 8
   OR sls_due_dt > 20500101
   OR sls_due_dt < 19000101;

-- Ordre des dates invalide (date de commande > date d'expédition ou d'échéance)
-- Résultat attendu : Aucun résultat
SELECT
    *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
   OR sls_order_dt > sls_due_dt;

-- Cohérence : Ventes = Quantité * Prix
-- Résultat attendu : Aucun résultat
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL
   OR sls_quantity IS NULL
   OR sls_price IS NULL
   OR sls_sales <= 0
   OR sls_quantity <= 0
   OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

-- ====================================================================
-- Contrôles 'silver.erp_cust_az12'
-- ====================================================================
-- Dates de naissance hors plage
-- Résultat attendu : Dates de naissance entre 1924-01-01 et aujourd'hui
SELECT DISTINCT
    bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01'
   OR bdate > GETDATE();

-- Standardisation et cohérence des données
-- Résultat attendu : 'Féminin', 'Masculin', 'n/a'
SELECT DISTINCT
    gen
FROM silver.erp_cust_az12;

-- ====================================================================
-- Contrôles 'silver.erp_loc_a101'
-- ====================================================================
-- Standardisation et cohérence des données
-- Résultat attendu : noms de pays en français et 'n/a'
SELECT DISTINCT
    cntry
FROM silver.erp_loc_a101
ORDER BY cntry;

-- ====================================================================
-- Contrôles 'silver.erp_px_cat_g1v2'
-- ====================================================================
-- Espaces indésirables
-- Résultat attendu : Aucun résultat
SELECT
    *
FROM silver.erp_px_cat_g1v2
WHERE cat != TRIM(cat)
   OR subcat != TRIM(subcat)
   OR maintenance != TRIM(maintenance);

-- Standardisation et cohérence des données
SELECT DISTINCT
    maintenance
FROM silver.erp_px_cat_g1v2;
