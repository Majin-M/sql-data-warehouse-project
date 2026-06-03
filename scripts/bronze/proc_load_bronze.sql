/*
===============================================================================
Procédure stockée : Chargement de la couche Bronze (Source -> Bronze)
===============================================================================
Objectif du script :
    Cette procédure stockée charge les données dans le schéma 'bronze'
    à partir de fichiers CSV externes.

    Elle effectue les actions suivantes :
    - Vide les tables Bronze avant le chargement des données.
    - Utilise la commande BULK INSERT pour charger les données
      depuis les fichiers CSV vers les tables Bronze.

Paramètres :
    Aucun.
    Cette procédure stockée n'accepte aucun paramètre et ne retourne
    aucune valeur.

Exemple d'utilisation :
    EXEC bronze.load_bronze;
===============================================================================
*/


CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
	DECLARE @start_time DATETIME,@end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
		SET @batch_start_time=GETDATE();
			PRINT '================================================';
			PRINT 'Chargement de la couche Bronze';
			PRINT '================================================';
			PRINT '------------------------------------------------';
			PRINT 'Chargement des tables CRM';
			PRINT '------------------------------------------------';
			
			SET @start_time=GETDATE();
			PRINT '>> Vidage de la table : bronze.crm_cust_info';
			TRUNCATE TABLE bronze.crm_cust_info;
			PRINT '>> Insertion des données dans : bronze.crm_cust_info';
			BULK INSERT bronze.crm_cust_info
			FROM 'C:\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
			WITH(
				FIRSTROW=2,
				FIELDTERMINATOR=',',
				TABLOCK
			);
			SET @end_time=GETDATE();
			PRINT '>> Durée du chargement : ' + CAST(DATEDIFF(second, @start_time, @end_time )AS NVARCHAR) + ' secondes';
			PRINT '>> -------------';

			SET @start_time=GETDATE();
			PRINT '>> Vidage de la table : bronze.crm_prd_info';
			TRUNCATE TABLE bronze.crm_prd_info;
			PRINT '>> Insertion des données dans : bronze.crm_prd_info';
			BULK INSERT bronze.crm_prd_info
			FROM 'C:\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
			WITH (
				FIRSTROW=2,
				FIELDTERMINATOR=',',
				TABLOCK
			);
			SET @end_time=GETDATE();
			PRINT '>> Durée du chargement : ' + CAST(DATEDIFF(second, @start_time, @end_time )AS NVARCHAR) + ' secondes';
			PRINT '>> -------------';
		
			SET @start_time=GETDATE();
	
			PRINT '>> Vidage de la table : bronze.crm_sales_details';
			TRUNCATE TABLE bronze.crm_sales_details;

			PRINT '>> Insertion des données dans : bronze.crm_sales_details';
			BULK INSERT bronze.crm_sales_details
			FROM 'C:\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
			WITH (
				FIRSTROW=2,
				FIELDTERMINATOR=',',
				TABLOCK
			);

			SET @end_time=GETDATE();
			PRINT '>> Durée du chargement : ' + CAST(DATEDIFF(second, @start_time, @end_time )AS NVARCHAR) + ' secondes';
			PRINT '>> -------------';

			PRINT'----------------------------------------------------------------------';
			PRINT 'chargement des tables ERP';
			PRINT'----------------------------------------------------------------------';

			SET @start_time=GETDATE();
			PRINT '>> Vidage de la table : bronze.erp_cust_az12';
			TRUNCATE TABLE bronze.erp_cust_az12;

			PRINT '>> Insertion des données dans : bronze.erp_cust_az12';
			BULK INSERT bronze.erp_cust_az12
			FROM 'C:\sql-data-warehouse-project\datasets\source_erp\cust_az12.csv'
			WITH (
				FIRSTROW=2,
				FIELDTERMINATOR=',',
				TABLOCK
			);
			SET @end_time=GETDATE();
			PRINT '>> Durée du chargement : ' + CAST(DATEDIFF(second, @start_time, @end_time )AS NVARCHAR) + ' secondes';
			PRINT '>> -------------';

			SET @start_time=GETDATE();
			PRINT '>> Vidage de la table : bronze.erp_loc_a101';
			TRUNCATE TABLE bronze.erp_loc_a101;

			PRINT '>> Insertion des données dans : bronze.erp_loc_a101';
			BULK INSERT bronze.erp_loc_a101
			FROM 'C:\sql-data-warehouse-project\datasets\source_erp\loc_a101.csv'
			WITH (
				FIRSTROW=2,
				FIELDTERMINATOR=',',
				TABLOCK
			);
			SET @end_time=GETDATE();
			PRINT '>> Durée du chargement : ' + CAST(DATEDIFF(second, @start_time, @end_time )AS NVARCHAR) + ' secondes';
			PRINT '>> -------------';

			SET @start_time=GETDATE();
			PRINT '>> Vidage de la table : bronze.erp_px_cat_g1v2';
			TRUNCATE TABLE bronze.erp_px_cat_g1v2;

			PRINT'>>Insertion des données dans : bronze.erp_px_cat_g1v2';
			BULK INSERT bronze.erp_px_cat_g1v2
			FROM 'C:\sql-data-warehouse-project\datasets\source_erp\px_cat_g1v2.csv'
			WITH (
				FIRSTROW=2,
				FIELDTERMINATOR=',',
				TABLOCK
			);
			SET @end_time=GETDATE();
			PRINT '>> Durée du chargement : ' + CAST(DATEDIFF(second, @start_time, @end_time )AS NVARCHAR) + ' secondes';
			PRINT '>> -------------';
		SET @batch_end_time=GETDATE();
		PRINT '======================================================================';
		PRINT 'Le chargement de la couche Bronze est terminé';
		PRINT '   - Durée totale du chargement : ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time )AS NVARCHAR) + ' secondes';
		PRINT '======================================================================';
	END TRY 
	BEGIN CATCH
		PRINT '======================================================================';
		PRINT 'UNE ERREUR EST SURVENUE LORS DU CHARGEMENT DE LA COUCHE BRONZE';
		PRINT 'Message d`erreur : '+ ERROR_MESSAGE();
		PRINT 'Numéro d`erreur : '+ CAST( ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Etat d`erreur : '+ CAST( ERROR_STATE() AS NVARCHAR);
		PRINT '======================================================================';
	END CATCH
END
