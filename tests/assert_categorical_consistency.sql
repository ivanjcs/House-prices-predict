-- Este test busca si existen barrios en el set de prueba que falten en el de entrenamiento
WITH barrios_train AS (
    SELECT DISTINCT neighborhood FROM {{ ref('int_house_prices__train_filtered') }}
),

barrios_test AS (
    SELECT DISTINCT neighborhood FROM {{ ref('stg_house_prices__test') }}
)

SELECT 
    t.neighborhood AS barrio_huerfano_en_test
FROM barrios_test t
LEFT JOIN barrios_train tr 
    ON t.neighborhood = tr.neighborhood
WHERE tr.neighborhood IS NULL