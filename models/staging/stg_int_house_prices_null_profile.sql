{# 
  Definimos las tablas que queremos analizar. 
  Al usar un diccionario, podemos correr el mismo análisis para train y test.
#}
{% set datasets = {
    'train': source('bronze_raw', 'house_prices_train'),
    'test': source('bronze_raw', 'house_prices_test')
} %}

WITH unioneed_profiles AS (
    {% for dataset_name, relation in datasets.items() %}
        {# El adapter de dbt va a BigQuery y extrae la lista real de columnas de la tabla #}
        {% set columns = adapter.get_columns_in_relation(relation) %}
        
        {% for col in columns %}
        SELECT
            '{{ dataset_name }}' AS dataset_source,
            '{{ col.name }}' AS nombre_columna,
             -- Contamos nulos reales o textos que digan 'NA' (Kaggle)
            COUNTIF(
                {{ adapter.quote(col.name) }} IS NULL 
                OR CAST({{ adapter.quote(col.name) }} AS STRING) = 'NA'
            ) AS total_nulos,
            -- Calculamos el porcentaje usando la misma lógica
            ROUND(
                COUNTIF(
                    {{ adapter.quote(col.name) }} IS NULL 
                    OR CAST({{ adapter.quote(col.name) }} AS STRING) = 'NA'
                ) / COUNT(*) * 100
            , 2) AS porcentaje_nulos
        FROM {{ relation }}
        
        {# Si no es la última columna del ciclo, metemos un UNION ALL #}
        {% if not loop.last %} UNION ALL {% endif %}
        {% endfor %}
        
        {# Si hay más datasets (como test), metemos un UNION ALL entre los bloques #}
        {% if not loop.last %} UNION ALL {% endif %}
    {% endfor %}
)

-- Resultado final ordenado de mayor a menor según el impacto de nulos
SELECT 
    dataset_source,
    nombre_columna,
    total_nulos,
    porcentaje_nulos
FROM unioneed_profiles
ORDER BY porcentaje_nulos DESC