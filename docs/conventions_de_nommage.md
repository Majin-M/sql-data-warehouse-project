# **Conventions de Nommage**

Ce document décrit les conventions de nommage utilisées pour les schémas, tables, vues, colonnes et autres objets dans l'entrepôt de données.

## **Table des matières**

1. [Principes généraux](#principes-généraux)
2. [Conventions de nommage des tables](#conventions-de-nommage-des-tables)
   - [Règles Bronze](#règles-bronze)
   - [Règles Silver](#règles-silver)
   - [Règles Gold](#règles-gold)
3. [Conventions de nommage des colonnes](#conventions-de-nommage-des-colonnes)
   - [Clés de substitution](#clés-de-substitution)
   - [Colonnes techniques](#colonnes-techniques)
4. [Procédures stockées](#conventions-de-nommage-des-procédures-stockées)

---

## **Principes généraux**

- **Conventions de nommage** : Utiliser le snake_case, avec des lettres minuscules et des underscores (`_`) pour séparer les mots.
- **Langue** : Utiliser l'anglais pour tous les noms d'objets.
- **Éviter les mots réservés** : Ne pas utiliser de mots réservés SQL comme noms d'objets.

## **Conventions de nommage des tables**

### **Règles Bronze**
- Tous les noms doivent commencer par le nom du système source, et les noms de tables doivent correspondre exactement aux noms d'origine, sans renommage.
- **`<sourcesystem>_<entity>`**
  - `<sourcesystem>` : Nom du système source (ex. `crm`, `erp`).
  - `<entity>` : Nom exact de la table dans le système source.
  - Exemple : `crm_customer_info` → Informations clients provenant du système CRM.

### **Règles Silver**
- Tous les noms doivent commencer par le nom du système source, et les noms de tables doivent correspondre exactement aux noms d'origine, sans renommage.
- **`<sourcesystem>_<entity>`**
  - `<sourcesystem>` : Nom du système source (ex. `crm`, `erp`).
  - `<entity>` : Nom exact de la table dans le système source.
  - Exemple : `crm_customer_info` → Informations clients provenant du système CRM.

### **Règles Gold**
- Tous les noms doivent utiliser des appellations métier significatives, en commençant par un préfixe de catégorie.
- **`<category>_<entity>`**
  - `<category>` : Décrit le rôle de la table, par exemple `dim` (dimension) ou `fact` (table de faits).
  - `<entity>` : Nom descriptif de la table, aligné sur le domaine métier (ex. `customers`, `products`, `sales`).
  - Exemples :
    - `dim_customers` → Table de dimension pour les données clients.
    - `fact_sales` → Table de faits contenant les transactions de vente.

#### **Glossaire des préfixes de catégorie**

| Préfixe     | Signification                     | Exemple(s)                                  |
|-------------|-----------------------------------|---------------------------------------------|
| `dim_`      | Table de dimension                | `dim_customer`, `dim_product`               |
| `fact_`     | Table de faits                    | `fact_sales`                                |
| `report_`   | Table de reporting                | `report_customers`, `report_sales_monthly`  |

## **Conventions de nommage des colonnes**

### **Clés de substitution**
- Toutes les clés primaires des tables de dimension doivent utiliser le suffixe `_key`.
- **`<table_name>_key`**
  - `<table_name>` : Fait référence au nom de la table ou de l'entité à laquelle appartient la clé.
  - `_key` : Suffixe indiquant qu'il s'agit d'une clé de substitution (surrogate key).
  - Exemple : `customer_key` → Clé de substitution dans la table `dim_customers`.

### **Colonnes techniques**
- Toutes les colonnes techniques doivent commencer par le préfixe `dwh_`, suivi d'un nom descriptif indiquant la finalité de la colonne.
- **`dwh_<column_name>`**
  - `dwh` : Préfixe réservé exclusivement aux métadonnées générées par le système.
  - `<column_name>` : Nom descriptif indiquant la finalité de la colonne.
  - Exemple : `dwh_load_date` → Colonne générée par le système pour stocker la date de chargement de l'enregistrement.

## **Conventions de nommage des procédures stockées**

- Toutes les procédures stockées utilisées pour le chargement des données doivent suivre le modèle de nommage suivant :
- **`load_<layer>`**
  - `<layer>` : Représente la couche chargée, à savoir `bronze`, `silver` ou `gold`.
  - Exemples :
    - `load_bronze` → Procédure stockée pour le chargement des données dans la couche Bronze.
    - `load_silver` → Procédure stockée pour le chargement des données dans la couche Silver.
