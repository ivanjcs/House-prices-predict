WITH train_cols AS (
  SELECT LOWER(column_name) AS column_name
  -- Magia de dbt: Busca la base de datos y el esquema EXACTO donde se guardó el modelo
  FROM `{{ ref('obt_house_prices__train').database }}.{{ ref('obt_house_prices__train').schema }}.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = '{{ ref("obt_house_prices__train").identifier }}'
    AND LOWER(column_name) NOT IN ('log_sale_price', 'sale_price')
),

test_cols AS (
  SELECT LOWER(column_name) AS column_name
  FROM `{{ ref('obt_house_prices__test').database }}.{{ ref('obt_house_prices__test').schema }}.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = '{{ ref("obt_house_prices__test").identifier }}'
)

SELECT 
    COALESCE(tr.column_name, te.column_name) AS columna_asimetrica,
    CASE
        WHEN tr.column_name IS NULL THEN 'Falta en TRAIN (o sobró en TEST)'
        WHEN te.column_name IS NULL THEN 'Falta en TEST (o sobró en TRAIN)'
    END AS tipo_error
FROM train_cols tr
FULL OUTER JOIN test_cols te 
    ON tr.column_name = te.column_name
WHERE tr.column_name IS NULL OR te.column_name IS NULL