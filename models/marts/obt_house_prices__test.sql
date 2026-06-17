WITH test_data AS (
    SELECT * FROM {{ ref('stg_house_prices__test') }}
)

SELECT 
    -- 1. Traemos TODAS las columnas limpias, menos las dos que vamos a alterar
    * EXCEPT (ms_zoning, roof_matl),
    
    -- 2. Reescribimos ms_zoning con el "disfraz" de seguridad
    CASE 
        WHEN ms_zoning = 'C (all)' THEN 'RL'
        ELSE ms_zoning 
    END AS ms_zoning,
    
    -- 3. Reescribimos roof_matl con el "disfraz" de seguridad
    CASE 
        WHEN roof_matl = 'ClyTile' THEN 'CompShg'
        ELSE roof_matl 
    END AS roof_matl

FROM test_data