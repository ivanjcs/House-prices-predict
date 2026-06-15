WITH staging_train AS (
    -- 1. Traemos los datos estandarizados de la capa staging
    SELECT * FROM {{ ref('stg_house_prices__train') }}
),

limpieza_y_deduplicacion AS (
    SELECT 
        * EXCEPT(garage_yr_blt), 
        
    -- Corrección del "Cero Lógico" en fechas
    -- Si el año es 0 (porque no tiene garaje), asignamos el año de construcción de la casa
    -- para no destruir los pesos matemáticos del modelo de Machine Learning.
        CASE 
            WHEN garage_yr_blt = 0 THEN year_built 
            ELSE garage_yr_blt 
        END AS garage_yr_blt
        
    FROM staging_train
    
    -- 2. DEDUPLICACIÓN LÓGICA: Garantizamos que cada casa aparezca una sola vez
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY property_id 
        ORDER BY 
            -- Priorizamos el registro que tenga datos de barrio, y en caso de empate, el más actualizado
            CASE WHEN neighborhood IS NOT NULL THEN 1 ELSE 0 END DESC,
            year_built DESC
    ) = 1
)

SELECT *
FROM limpieza_y_deduplicacion
WHERE 
    -- 1. Regla de negocio original: Eliminar outliers masivos de superficie
    gr_liv_area <= 4000
    
    -- 2. Filtro de nicho de mercado: Excluir zonas no residenciales (C = Comercial)
    -- Los 10 registros que detectaste distorsionan el precio residencial.
    AND ms_zoning != 'C (all)'
