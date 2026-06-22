WITH test_data AS (
    SELECT * FROM {{ ref('stg_house_prices__test') }}
)

SELECT 
    -- 1. Exclusión de variables crudas + Las 2 que vamos a "disfrazar"
    * EXCEPT(
        first_flr_sf, second_flr_sf, garage_area, garage_yr_blt,
        pool_area, mas_vnr_area, year_built, year_remod_add,
        wood_deck_sf, open_porch_sf, enclosed_porch, three_ssn_porch, screen_porch,
        full_bath, half_bath, bsmt_full_bath, bsmt_half_bath,
        condition1, condition2, mo_sold,

        -- [Exclusiones definidas por la Auditoria Visual] --------------

        -- Exclusiones por varianza cercana a cero
        low_qual_fin_sf, misc_val,

        -- Exclusiones por imbalances extremos sin poder predictivo
        street, utilities, pool_qc,

        -- Exclusiones por Alta correlación (Multicolinealidad)
        bsmt_cond, bsmt_fin_type1, exterior2nd, garage_cond, 
        garage_qual, mssub_class, tot_rms_abv_grd, ms_zoning,

        -- Exclusion de variables crudas que vamos a binarizar/agrupar ahora
        roof_matl, heating, central_air, kitchen_abv_gr, electrical, misc_feature
    ),

    -- [ DISFRACES DE SEGURIDAD CATEGÓRICA ] ---------------------------------
    CASE WHEN ms_zoning = 'C (all)' THEN 'RL' ELSE ms_zoning END AS ms_zoning,
    CASE WHEN roof_matl = 'ClyTile' THEN 'CompShg' ELSE roof_matl END AS roof_matl,

    -- [ Feature Engineering ] ------------
    COALESCE((bsmt_fin_sf1 + bsmt_fin_sf2) / NULLIF(total_bsmt_sf, 0), 0) AS porcentaje_sotano_terminado,
    SAFE_DIVIDE(gr_liv_area, lot_area) AS lot_coverage_pct,
    CASE WHEN garage_cars = 0 THEN -999 ELSE (yr_sold - garage_yr_blt) END AS garage_age,
    CASE WHEN pool_area > 0 THEN 1 ELSE 0 END AS has_pool,
    CASE WHEN mas_vnr_area > 0 THEN 1 ELSE 0 END AS has_masonry,
    (yr_sold - year_built) AS house_age,
    (yr_sold - year_remod_add) AS years_since_remodel,
    CASE WHEN year_built != year_remod_add THEN 1 ELSE 0 END AS has_been_remodified,
    
    (full_bath + (0.5 * half_bath) + bsmt_full_bath + (0.5 * bsmt_half_bath)) AS total_bathrooms,
    
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

    SIN(2 * 3.141592653589793 * mo_sold / 12) AS mo_sold_sin,
    COS(2 * 3.141592653589793 * mo_sold / 12) AS mo_sold_cos,
    CASE WHEN mo_sold BETWEEN 4 AND 7 THEN 1 ELSE 0 END AS es_temporada_alta,

    (enclosed_porch + three_ssn_porch + screen_porch) AS total_living_porch,
    (wood_deck_sf + open_porch_sf) AS total_outdoor_deck,


    -- [ REGLAS DEFINIDAS por (Auditoria Visual )] ---------------------------
    
    -- Imbalance: Binarización
    -- Si es el material estándar (CompShg) es 1, cualquier otra rareza es 0
    CASE WHEN roof_matl = 'CompShg' THEN 1 ELSE 0 END AS has_standard_roof,
    
    -- Si es calefacción a gas estándar (GasA) es 1, otro es 0
    CASE WHEN heating = 'GasA' THEN 1 ELSE 0 END AS has_gas_heating,
    
    -- CentralAir ya es Y/N, lo pasamos a 1/0
    CASE WHEN CAST(central_air AS STRING) IN ('Y', 'true', 'TRUE') THEN 1 ELSE 0 END AS has_central_air,
    
    -- Cocinas: 1 es lo normal, más de 1 es raro/multifamiliar
    CASE WHEN kitchen_abv_gr = 1 THEN 1 ELSE 0 END AS is_single_kitchen,

    -- Imbalance: Agrupación (Binning)
    
    -- Sistema eléctrico: 1 si es estándar (SBrkr), 0 si es antiguo/peligroso
    CASE WHEN electrical = 'SBrkr' THEN 1 ELSE 0 END AS has_standard_electrical,    

    -- MiscFeature: Separamos las casas que tienen un rasgo raro (Shed, etc) de las que no
    -- Ojo aquí con los valores nulos que vienen de la capa bronce
    CASE WHEN COALESCE(misc_feature, 'None') = 'None' THEN 0 ELSE 1 END AS has_misc_feature,
    -- NOTA CRUCIAL: No se incluye LOG(sale_price) porque test.csv no tiene precio.

FROM test_data
