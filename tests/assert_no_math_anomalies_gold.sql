-- Este test fallará si alguna división por cero generó un infinito/NaN, 
-- o si la resta de años dio resultados negativos imposibles (ej. edad negativa).
WITH combined_data AS (
    SELECT 
        property_id, 
        'Train' AS dataset,
        porcentaje_sotano_terminado, 
        lot_coverage_pct, 
        garage_age, 
        house_age 
    FROM {{ ref('obt_house_prices__train') }}
    
    UNION ALL
    
    SELECT 
        property_id, 
        'Test' AS dataset,
        porcentaje_sotano_terminado, 
        lot_coverage_pct, 
        garage_age, 
        house_age 
    FROM {{ ref('obt_house_prices__test') }}
)

SELECT *
FROM combined_data
WHERE porcentaje_sotano_terminado IS NULL
   OR lot_coverage_pct IS NULL 
   OR IS_NAN(lot_coverage_pct) 
   OR IS_INF(lot_coverage_pct)
   OR garage_age IS NULL
   OR house_age < 0