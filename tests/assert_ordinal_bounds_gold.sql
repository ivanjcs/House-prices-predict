-- Este test fallará si algún valor ordinal se sale de la escala que diseñamos
-- (Por ejemplo, si exter_qual es mayor a 5 o menor a 0).
WITH combined_data AS (
    SELECT 
        property_id, 'Train' AS dataset,
        exter_qual, functional, bsmt_exposure, lot_shape 
    FROM {{ ref('obt_house_prices__train') }}
    
    UNION ALL
    
    SELECT 
        property_id, 'Test' AS dataset,
        exter_qual, functional, bsmt_exposure, lot_shape 
    FROM {{ ref('obt_house_prices__test') }}
)

SELECT *
FROM combined_data
WHERE exter_qual NOT BETWEEN 0 AND 5
   OR functional NOT BETWEEN 0 AND 7
   OR bsmt_exposure NOT BETWEEN 0 AND 4
   OR lot_shape NOT BETWEEN 0 AND 3