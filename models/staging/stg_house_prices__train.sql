{% set columnas_na = [
    'PoolQC', 'MiscFeature', 'Alley', 'Fence', 'FireplaceQu', 
    'GarageType', 'GarageFinish', 'GarageQual', 'GarageCond', 
    'BsmtCond', 'BsmtExposure', 'BsmtQual', 'BsmtFinType1', 'BsmtFinType2', 'MasVnrType'
] %}

-- Creamos la lista para el Grupo "Cero Lógico"
{% set columnas_zero = [
    'GarageCars', 'GarageArea', 'BsmtFullBath', 'BsmtHalfBath', 
    'BsmtUnfSF', 'BsmtFinSF1', 'BsmtFinSF2', 'TotalBsmtSF', 
    'MasVnrArea', 'GarageYrBlt'
] %}

-- Grupo "Moda General" para variables categóricas con nulos esporádicos
{% set columnas_moda = [
    'Electrical', 'MSZoning', 'Utilities', 'Exterior1st', 
    'Exterior2nd', 'KitchenQual', 'Functional', 'SaleType'
] %}

WITH raw_source AS (
    SELECT * FROM {{ source('bronze_raw', 'house_prices_train') }}
),

-- Calculamos la Moda General (el valor más frecuente ignorando nulos) para cada columna
global_modes AS (
    SELECT
        {% for col in columnas_moda %}
        (
            SELECT {{ col }} 
            FROM raw_source 
            WHERE {{ col }} IS NOT NULL 
            GROUP BY {{ col }} 
            ORDER BY COUNT(*) DESC 
            LIMIT 1
        ) AS mode_{{ col | lower }}{% if not loop.last %},{% endif %}
        {% endfor %}
)

SELECT
    -- 1. Columnas sin modificación (LIMPIO DE DUPLICADOS)
    s.Id AS property_id,
    s.MSSubClass AS mssub_class,
    s.LotArea AS lot_area,
    s.Street AS street,
    s.LotShape AS lot_shape,
    s.LandContour AS land_contour,
    s.LotConfig AS lot_config,
    s.LandSlope AS land_slope,
    s.Neighborhood AS neighborhood,
    s.Condition1 AS condition1,
    s.Condition2 AS condition2,
    s.BldgType AS bldg_type,
    s.HouseStyle AS house_style,
    s.OverallQual AS overall_qual,
    s.OverallCond AS overall_cond,
    s.YearBuilt AS year_built,
    s.YearRemodAdd AS year_remod_add,
    s.RoofStyle AS roof_style,
    s.RoofMatl AS roof_matl,
    s.ExterQual AS exter_qual,
    s.ExterCond AS exter_cond,
    s.Foundation AS foundation,
    s.Heating AS heating,
    s.HeatingQC AS heating_qc,
    s.CentralAir AS central_air,
    s.LowQualFinSF AS low_qual_fin_sf,
    s.GrLivArea AS gr_liv_area,
    s.FullBath AS full_bath,
    s.HalfBath AS half_bath,
    s.BedroomAbvGr AS bedroom_abv_gr,
    s.KitchenAbvGr AS kitchen_abv_gr,
    s.TotRmsAbvGrd AS tot_rms_abv_grd,
    s.Fireplaces AS fireplaces,
    s.PavedDrive AS paved_drive,
    s.WoodDeckSF AS wood_deck_sf,
    s.OpenPorchSF AS open_porch_sf,
    s.EnclosedPorch AS enclosed_porch,
    s.ScreenPorch AS screen_porch,
    s.PoolArea AS pool_area,
    s.MiscVal AS misc_val,
    s.MoSold AS mo_sold,
    s.YrSold AS yr_sold,
    s.SaleCondition AS sale_condition,
    s.SalePrice AS sale_price,

    -- ALERTA: Busca las filas de los pisos y cámbialas manualmente para que empiecen con letras:
    s.`1stFlrSF` AS first_flr_sf,
    s.`2ndFlrSF` AS second_flr_sf,
    s.`3SsnPorch` AS three_ssn_porch,
    
    -- 2. Imputación Avanzada: lot_frontage (Mediana por Barrio)
    COALESCE(
        SAFE_CAST(s.LotFrontage AS FLOAT64),
        PERCENTILE_CONT(SAFE_CAST(s.LotFrontage AS FLOAT64), 0.5) OVER (PARTITION BY s.Neighborhood)
    ) AS lot_frontage,

    -- 3. Imputación por Moda General 
    {% for col in columnas_moda %}
    COALESCE(NULLIF(CAST(s.{{ col }} AS STRING), 'NA'), m.mode_{{ col | lower }}) AS {{ col | lower }},
    {% endfor %}

    -- 4. Grupo "El Vacío es una Categoría"
    {% for col in columnas_na %}
    COALESCE(NULLIF(CAST(s.{{ col }} AS STRING), 'NA'), 'None') AS {{ col | lower }},
    {% endfor %}

    -- 5. Grupo "El Vacío es un Cero Lógico"
    {% for col in columnas_zero %}
    COALESCE(SAFE_CAST(s.{{ col }} AS INT64), 0) AS {{ col | lower }}{% if not loop.last %},{% endif %}
    {% endfor %}

FROM raw_source AS s
CROSS JOIN global_modes AS m