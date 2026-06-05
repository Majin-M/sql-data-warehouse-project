/*
===============================================================================
Procédure stockée : Chargement de la couche Silver (Bronze -> Silver)
===============================================================================
Objectif du script :
    Cette procédure stockée exécute le processus ETL (Extraction,
    Transformation, Chargement) afin d'alimenter les tables du schéma
    'silver' à partir du schéma 'bronze'.

Actions effectuées :
    - Vide les tables Silver.
    - Insère les données transformées et nettoyées depuis Bronze vers Silver.

Paramètres :
    Aucun.
    Cette procédure stockée n'accepte aucun paramètre et ne retourne
    aucune valeur.

Exemple d'utilisation :
    EXEC silver.load_silver;
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME; 
    BEGIN TRY
        SET @batch_start_time = GETDATE();
       	PRINT '================================================';
		PRINT 'Chargement de la couche Silver';
		PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Chargement des tables CRM';
		PRINT '------------------------------------------------';

		-- Chargement de silver.crm_cust_info
        SET @start_time = GETDATE();
		PRINT '>> Vidage de la table : silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> Insertion des données dans : silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info (
			cst_id, 
			cst_key, 
			cst_firstname, 
			cst_lastname, 
			cst_marital_status, 
			cst_gndr,
			cst_create_date
		)
		SELECT
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname) AS cst_lastname,
			CASE 
				WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Célibataire'
				WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Marié(e)'
				ELSE 'n/a'
			END AS cst_marital_status, -- Normalisation du statut marital vers un format lisible
			CASE 
				WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Féminin'
				WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Masculin'
				ELSE 'n/a'
			END AS cst_gndr, -- Normalisation du genre vers un format lisible
			cst_create_date
		FROM (
			SELECT
				*,
				ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
		) t
		WHERE flag_last = 1; -- Sélection de l'enregistrement le plus récent par client
		SET @end_time = GETDATE();
        PRINT '>> Durée du chargement : ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' secondes';
        PRINT '>> -------------';

		-- Chargement de silver.crm_prd_info
        SET @start_time = GETDATE();
		PRINT '>> Vidage de la table : silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '>> Insertion des données dans : silver.crm_prd_info';
		INSERT INTO silver.crm_prd_info (
			prd_id,
			cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt
		)
		SELECT
			prd_id,
			REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id, -- Extraction de l'identifiant de catégorie
			SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,        -- Extraction de la clé produit
			prd_nm,
			ISNULL(prd_cost, 0) AS prd_cost,
			CASE 
				WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Montagne'
				WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Route'
				WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Autres ventes'
				WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
				ELSE 'n/a'
			END AS prd_line, -- Correspondance des codes de gamme produit vers des valeurs descriptives
			CAST(prd_start_dt AS DATE) AS prd_start_dt,
			CAST(
				LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 
				AS DATE
			) AS prd_end_dt -- Calcul de la date de fin : veille de la prochaine date de début
		FROM bronze.crm_prd_info;
        SET @end_time = GETDATE();
        PRINT '>> Durée du chargement : ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' secondes';
        PRINT '>> -------------';

        -- Chargement de silver.crm_sales_details
        SET @start_time = GETDATE();
		PRINT '>> Vidage de la table : silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '>> Insertion des données dans : silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details (
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
		)
		SELECT 
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			CASE 
				WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
			END AS sls_order_dt,
			CASE 
				WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
			END AS sls_ship_dt,
			CASE 
				WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
			END AS sls_due_dt,
			CASE 
				WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) 
					THEN sls_quantity * ABS(sls_price)
				ELSE sls_sales
			END AS sls_sales, -- Recalcul des ventes si la valeur d'origine est manquante ou incorrecte
			sls_quantity,
			CASE 
				WHEN sls_price IS NULL OR sls_price <= 0 
					THEN sls_sales / NULLIF(sls_quantity, 0)
				ELSE sls_price -- Déduction du prix si la valeur d'origine est invalide
			END AS sls_price
		FROM bronze.crm_sales_details;
        SET @end_time = GETDATE();
        PRINT '>> Durée du chargement : ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' secondes';
        PRINT '>> -------------';

        -- Chargement de silver.erp_cust_az12
        SET @start_time = GETDATE();
		PRINT '>> Vidage de la table : silver.erp_cust_az12';
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '>> Insertion des données dans : silver.erp_cust_az12';
		INSERT INTO silver.erp_cust_az12 (
			cid,
			bdate,
			gen
		)
		SELECT
			CASE
				WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) -- Suppression du préfixe 'NAS' si présent
				ELSE cid
			END AS cid, 
			CASE
				WHEN bdate > GETDATE() THEN NULL
				ELSE bdate
			END AS bdate, -- Mise à NULL des dates de naissance dans le futur
			CASE
				WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Féminin'
				WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Masculin'
				ELSE 'n/a'
			END AS gen -- Normalisation du genre et gestion des valeurs inconnues
		FROM bronze.erp_cust_az12;
	    SET @end_time = GETDATE();
        PRINT '>> Durée du chargement : ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' secondes';
        PRINT '>> -------------';

		PRINT '------------------------------------------------';
		PRINT 'Chargement des tables ERP';
		PRINT '------------------------------------------------';

        -- Chargement de silver.erp_loc_a101
        SET @start_time = GETDATE();
		PRINT '>> Vidage de la table : silver.erp_loc_a101';
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '>> Insertion des données dans : silver.erp_loc_a101';
		INSERT INTO silver.erp_loc_a101 (
			cid,
			cntry
		)
		SELECT
			REPLACE(cid, '-', '') AS cid, 
			CASE
				WHEN TRIM(cntry) = 'DE' THEN 'Allemagne'
				WHEN TRIM(cntry) IN ('US', 'USA') THEN 'États-Unis'
				WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
				ELSE TRIM(cntry)
			END AS cntry -- Normalisation et gestion des codes pays manquants ou vides
		FROM bronze.erp_loc_a101;
	    SET @end_time = GETDATE();
        PRINT '>> Durée du chargement : ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' secondes';
        PRINT '>> -------------';
		
		-- Chargement de silver.erp_px_cat_g1v2
		SET @start_time = GETDATE();
		PRINT '>> Vidage de la table : silver.erp_px_cat_g1v2';
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '>> Insertion des données dans : silver.erp_px_cat_g1v2';
		INSERT INTO silver.erp_px_cat_g1v2 (
			id,
			cat,
			subcat,
			maintenance
		)
		SELECT
			id,
			cat,
			subcat,
			maintenance
		FROM bronze.erp_px_cat_g1v2;
		SET @end_time = GETDATE();
		PRINT '>> Durée du chargement : ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' secondes';
        PRINT '>> -------------';

		SET @batch_end_time = GETDATE();
		PRINT '======================================================================';
		PRINT 'Le chargement de la couche Silver est terminé';
        PRINT '   - Durée totale du chargement : ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' secondes';
		PRINT '======================================================================';
		
	END TRY
	BEGIN CATCH
		PRINT '======================================================================';
		PRINT 'UNE ERREUR EST SURVENUE LORS DU CHARGEMENT DE LA COUCHE SILVER';
		PRINT 'Message d`erreur : ' + ERROR_MESSAGE();
		PRINT 'Numéro d`erreur : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'État d`erreur : ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '======================================================================';
	END CATCH
END
