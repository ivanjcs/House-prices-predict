WITH staging_train AS (
    SELECT * FROM {{ ref('stg_house_prices__train') }}
)

SELECT 
    * EXCEPT(garageyrblt), -- Excluimos la columna original para reescribirla
    
    -- Corrección del "Cero Lógico" en fechas
    -- Si el año es 0 (porque no tiene garaje), asignamos el año de construcción de la casa
    -- para no destruir los pesos matemáticos del modelo de Machine Learning.
    CASE 
        WHEN garageyrblt = 0 THEN year_built 
        ELSE garageyrblt 
    END AS garage_yr_blt

FROM staging_train
WHERE 
    -- 1. Regla de negocio original: Eliminar outliers masivos de superficie
    gr_liv_area <= 4000 
    
    -- 2. Filtro de nicho de mercado: Excluir zonas no residenciales (C = Comercial)
    -- Los 10 registros que detectaste distorsionan el precio residencial.
    AND mszoning != 'C (all)'