-- 1. Definimos la lista de columnas categóricas
{% set columnas_categoricas = [
    'ms_zoning', 'street', 'alley', 'lot_shape', 'land_contour', 
    'utilities', 'lot_config', 'land_slope', 'neighborhood', 
    'condition1', 'condition2', 'bldg_type', 'house_style', 
    'roof_style', 'roof_matl', 'exterior1st', 'exterior2nd', 
    'mas_vnr_type', 'exter_qual', 'exter_cond', 'foundation', 
    'bsmt_qual', 'bsmt_cond', 'bsmt_exposure', 'bsmt_fin_type1', 
    'bsmt_fin_type2', 'heating', 'heating_qc', 'central_air', 
    'electrical', 'kitchen_qual', 'functional', 'fireplace_qu', 
    'garage_type', 'garage_finish', 'garage_qual', 'garage_cond', 
    'paved_drive', 'pool_qc', 'fence', 'misc_feature', 
    'sale_type', 'sale_condition'
] %}

WITH train_data AS (
    SELECT * FROM {{ ref('int_house_prices__train_filtered') }}
),

test_data AS (
    SELECT * FROM {{ ref('stg_house_prices__test') }}
),

-- 2. EL PARCHE ANTIBUGS: Forzamos todas las columnas a ser texto puro
cast_train AS (
    SELECT 
        {% for col in columnas_categoricas %}
        CAST({{ col }} AS STRING) AS {{ col }}{% if not loop.last %},{% endif %}
        {% endfor %}
    FROM train_data
),

cast_test AS (
    SELECT 
        {% for col in columnas_categoricas %}
        CAST({{ col }} AS STRING) AS {{ col }}{% if not loop.last %},{% endif %}
        {% endfor %}
    FROM test_data
),

-- 3. Ahora el UNPIVOT no fallará por discrepancia de tipos
unpivoted_test AS (
    SELECT column_name, column_value
    FROM cast_test
    UNPIVOT(
        column_value FOR column_name IN (
            {{ columnas_categoricas | join(', ') }}
        )
    )
),

unpivoted_train AS (
    SELECT column_name, column_value
    FROM cast_train
    UNPIVOT(
        column_value FOR column_name IN (
            {{ columnas_categoricas | join(', ') }}
        )
    )
)

-- 4. Ejecutamos el LEFT JOIN estructural
SELECT DISTINCT 
    t.column_name AS columna_con_error,
    t.column_value AS categoria_huerfana
FROM unpivoted_test t
LEFT JOIN unpivoted_train tr 
    ON t.column_name = tr.column_name 
   AND t.column_value = tr.column_value
WHERE tr.column_value IS NULL 
  AND t.column_value IS NOT NULL