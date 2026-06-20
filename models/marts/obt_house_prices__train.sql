WITH intermediate_train AS (
    SELECT * FROM {{ ref('int_house_prices__train_filtered') }}
)

SELECT 
    -- 1. Exclusión de variables procesadas para evitar redundancia y colinealidad
    * EXCEPT(
        -- Filtros de pisos, garaje y terreno
        first_flr_sf, second_flr_sf,
        garage_area, garage_yr_blt,
        
        -- Estructuras específicas y temporalidad de la casa 
        pool_area, mas_vnr_area, 
        year_built, year_remod_add,
        
        -- Áreas de transición y esparcimiento exterior 
        wood_deck_sf, open_porch_sf, enclosed_porch, three_ssn_porch, screen_porch,
        
        -- Baños desglosados
        full_bath, half_bath, bsmt_full_bath, bsmt_half_bath,
        
        -- Condiciones de entorno y estacionalidad
        condition1, condition2, mo_sold
    ),

    -- 2. Utilidad Subterránea (Sótano) 
    COALESCE(
        (bsmt_fin_sf1 + bsmt_fin_sf2) / NULLIF(total_bsmt_sf, 0), 
        0
    ) AS porcentaje_sotano_terminado,

    -- 3. Áreas de Recreación Exterior
    (wood_deck_sf + open_porch_sf + enclosed_porch + three_ssn_porch + screen_porch) AS total_outdoor_space,
    
    CASE 
        WHEN (wood_deck_sf + open_porch_sf + enclosed_porch + three_ssn_porch + screen_porch) > 0 THEN 1 
        ELSE 0 
    END AS has_outdoor_space,

    -- 4. Densidad Privacidad y Estilo de Vida (Terreno)
    SAFE_DIVIDE(gr_liv_area, lot_area) AS lot_coverage_pct,

    -- 5. LA TRAMPA DEL GARAJE: Antigüedad y Depreciación (-999)
    -- Usamos garage_cars como bandera de verdad absoluta. 
    -- Si es 0, forzamos el -999 para que XGBoost aísle la anomalía en un nodo puro.
    CASE 
        WHEN garage_cars = 0 THEN -999
        ELSE (yr_sold - garage_yr_blt)
    END AS garage_age,

    -- 6. Amenidades Específicas (Binarización de matrices dispersas)
    CASE WHEN pool_area > 0 THEN 1 ELSE 0 END AS has_pool,
    CASE WHEN mas_vnr_area > 0 THEN 1 ELSE 0 END AS has_masonry,

    -- 7. Antigüedad y Uso de la Propiedad (Magnitud relativa)
    (yr_sold - year_built) AS house_age,

    -- 8. El Efecto "Lavado de Cara" (Remodelaciones)
    (yr_sold - year_remod_add) AS years_since_remodel,
    CASE WHEN year_built != year_remod_add THEN 1 ELSE 0 END AS has_been_remodeled,
    
    -- 10. Consolidación de Baños (Unificación de magnitudes de utilidad)
    -- Asignamos peso fraccional a los medios baños reflejando el estándar de tasación inmobiliaria
    (full_bath + (0.5 * half_bath) + bsmt_full_bath + (0.5 * bsmt_half_bath)) AS total_bathrooms,

    -- 11. Factor Ruido y Accesibilidad (Binarización de entorno disperso)
    CASE 
        WHEN condition1 IN ('Artery', 'Feedr', 'RRNn', 'RRAn', 'RRNe', 'RRAe') 
          OR condition2 IN ('Artery', 'Feedr', 'RRNn', 'RRAn', 'RRNe', 'RRAe') THEN 1 
        ELSE 0 
    END AS is_noisy,

    CASE 
        WHEN condition1 IN ('PosN', 'PosA') 
          OR condition2 IN ('PosA', 'PosN') THEN 1 
        ELSE 0 
    END AS is_near_park,

    -- 12. Estacionalidad Cíclica (Codificación Trigonométrica)
    -- Mapeamos el mes a un círculo unitario usando radianes para resolver la discontinuidad lineal
    SIN(2 * 3.141592653589793 * mo_sold / 12) AS mo_sold_sin,
    COS(2 * 3.141592653589793 * mo_sold / 12) AS mo_sold_cos,
    CASE WHEN mo_sold BETWEEN 4 AND 7 THEN 1 ELSE 0 END AS es_temporada_alta,

    -- 13. Refinación del Porche y Áreas de Transición (Diferenciación funcional)
    -- Separamos las áreas protegidas/habitables de las áreas descubiertas puras
    (enclosed_porch + three_ssn_porch + screen_porch) AS total_living_porch,
    (wood_deck_sf + open_porch_sf) AS total_outdoor_deck,

    -- -----------------------------------------------------------------------
    -- Variable Objetivo Optimizada para el cálculo de RMSE en Kaggle
    LOG(sale_price) AS log_sale_price

FROM intermediate_train