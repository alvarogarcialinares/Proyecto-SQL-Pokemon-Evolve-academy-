-- ==========================================================
-- PROYECTO SQL - POKEMON ANALYTICS
-- Archivo: 03_eda.sql
-- Objetivo: validacion de calidad, EDA e insights analiticos.
-- ==========================================================

-- ==========================================================
-- 1. COMPROBACIONES GENERALES
-- ==========================================================

-- 1.1 Volumen de datos por capa.
-- Insight: comprueba que la carga y la transformación al modelo han mantenido el número de registros esperado.
SELECT 'carga.stg_pokemon_raw' AS tabla, COUNT(*) AS total_filas FROM carga.stg_pokemon_raw
UNION ALL
SELECT 'modelo.dim_pokemon', COUNT(*) FROM modelo.dim_pokemon
UNION ALL
SELECT 'modelo.fact_estadisticas_pokemon', COUNT(*) FROM modelo.fact_estadisticas_pokemon;

-- 1.2 Uso de funciones de fecha sobre fecha_carga.
-- Insight: permite saber cuando se cargaron los datos en el sistema.
SELECT
    DATE(fecha_carga) AS dia_carga,
    EXTRACT(YEAR FROM fecha_carga) AS anio_carga,
    COUNT(*) AS registros_cargados
FROM carga.stg_pokemon_raw
GROUP BY DATE(fecha_carga), EXTRACT(YEAR FROM fecha_carga)
ORDER BY dia_carga;

-- ==========================================================
-- 2. CALIDAD DE DATOS
-- ==========================================================

-- 2.1 Detección de nulos en campos importantes.
-- type_2 puede ser NULL sin ser error, porque muchos Pokemon solo tienen un tipo.
SELECT
    COUNT(*) FILTER (WHERE name IS NULL OR TRIM(name) = '') AS nulos_nombre,
    COUNT(*) FILTER (WHERE type_1 IS NULL OR TRIM(type_1) = '') AS nulos_tipo_1,
    COUNT(*) FILTER (WHERE type_2 IS NULL OR TRIM(type_2) = '') AS nulos_tipo_2_no_error,
    COUNT(*) FILTER (WHERE generation IS NULL OR TRIM(generation) = '') AS nulos_generacion,
    COUNT(*) FILTER (WHERE base_stat_total IS NULL OR TRIM(base_stat_total) = '') AS nulos_total_estadisticas
FROM carga.stg_pokemon_raw;

-- 2.2 Corrección sencilla de nulos/vacios en campos descriptivos no críticos.
-- Insight: si habitat viene vacío, se marca como 'Desconocido' para evitar valores sin interpretar.
UPDATE carga.stg_pokemon_raw
SET habitat = 'Desconocido'
WHERE habitat IS NULL OR TRIM(habitat) = '';

-- 2.3 Duplicados usando GROUP BY y COUNT.
-- Insight: revisa si hay Pokemon con mismo número de Pokedex y mismo nombre repetidos exactamente.
SELECT
    pokedex_number,
    name,
    COUNT(*) AS total_repeticiones
FROM carga.stg_pokemon_raw
GROUP BY pokedex_number, name
HAVING COUNT(*) > 1
ORDER BY total_repeticiones DESC, name;

-- 2.4 Duplicados usando RANK() OVER(PARTITION BY ...).
-- Insight: otra forma de localizar registros repetidos o múltiples formas de un mismo Pokemon.
WITH ranking_duplicados AS (
    SELECT
        raw_id,
        pokedex_number,
        name,
        RANK() OVER (PARTITION BY pokedex_number, name ORDER BY raw_id) AS ranking_repeticion
    FROM carga.stg_pokemon_raw
)
SELECT *
FROM ranking_duplicados
WHERE ranking_repeticion > 1;

-- 2.5 Validación de tipos numéricos antes de hacer CAST.
-- Insight: comprueba si hay valores no numéricos en columnas que deberían ser números.
SELECT
    COUNT(*) FILTER (WHERE hp !~ '^[0-9]+$') AS hp_no_numerico,
    COUNT(*) FILTER (WHERE attack !~ '^[0-9]+$') AS ataque_no_numerico,
    COUNT(*) FILTER (WHERE defense !~ '^[0-9]+$') AS defensa_no_numerico,
    COUNT(*) FILTER (WHERE base_stat_total !~ '^[0-9]+$') AS total_no_numerico
FROM carga.stg_pokemon_raw;

-- 2.6 Validación de valores fuera de rango esperado.
-- Insight: detecta estadísticas imposibles o sospechosas.
SELECT
    name,
    hp,
    attack,
    defense,
    base_stat_total,
    height_m,
    weight_kg
FROM carga.stg_pokemon_raw
WHERE CAST(hp AS INT) <= 0
   OR CAST(attack AS INT) < 0
   OR CAST(defense AS INT) < 0
   OR CAST(base_stat_total AS INT) <= 0
   OR CAST(height_m AS NUMERIC) < 0
   OR CAST(weight_kg AS NUMERIC) < 0;

-- ==========================================================
-- 3. ANÁLISIS DESCRIPTIVO DEL MODELO
-- ==========================================================

-- 3.1 Resumen general del dataset.
-- Insight: muestra el tamañoo del dataset y las métricas medias principales.
SELECT
    COUNT(*) AS total_pokemon,
    ROUND(AVG(hp), 2) AS media_hp,
    ROUND(AVG(ataque), 2) AS media_ataque,
    ROUND(AVG(defensa), 2) AS media_defensa,
    ROUND(AVG(velocidad), 2) AS media_velocidad,
    ROUND(AVG(total_estadisticas), 2) AS media_total_estadisticas
FROM modelo.fact_estadisticas_pokemon;

-- 3.2 Distribución por nivel de poder.
-- Insight: permite ver si predominan Pokemon de poder bajo, medio, alto o muy alto.
SELECT
    np.nombre_nivel,
    COUNT(*) AS total_pokemon,
    ROUND(AVG(f.total_estadisticas), 2) AS media_total_estadisticas
FROM modelo.fact_estadisticas_pokemon f
INNER JOIN modelo.dim_nivel_poder np
    ON f.nivel_poder_id = np.nivel_poder_id
GROUP BY np.nombre_nivel
ORDER BY media_total_estadisticas DESC;

-- ==========================================================
-- 4. CONSULTAS ANALÍTICAS DOCUMENTADAS
-- ==========================================================

-- Consulta 1: Poder medio por tipo.
-- Insight: identifica que tipos tienen mejores estadísticas medias.
SELECT *
FROM analisis.vw_poder_por_tipo
ORDER BY media_total_estadisticas DESC;

-- Consulta 2: Poder medio por generación.
-- Insight: compara generaciones y ayuda a ver si algunas concentran Pokemon mas fuertes.
SELECT *
FROM analisis.vw_poder_por_generacion
ORDER BY media_total_estadisticas DESC;

-- Consulta 3: Comparación entre Pokemon legendarios, míticos, bebés y normales.
-- Insight: permite comprobar si los Pokemon especiales tienen estadísticas superiores.
SELECT
    CASE
        WHEN p.es_legendario THEN 'Legendario'
        WHEN p.es_mitico THEN 'Mitico'
        WHEN p.es_bebe THEN 'Bebe'
        ELSE 'Normal'
    END AS categoria_pokemon,
    COUNT(*) AS total_pokemon,
    ROUND(AVG(f.total_estadisticas), 2) AS media_total_estadisticas,
    MAX(f.total_estadisticas) AS max_total_estadisticas
FROM modelo.fact_estadisticas_pokemon f
INNER JOIN modelo.dim_pokemon p
    ON f.pokemon_id = p.pokemon_id
GROUP BY categoria_pokemon
ORDER BY media_total_estadisticas DESC;

-- Consulta 4: Pokemon con doble tipo frente a Pokemon de un solo tipo.
-- Insight: analiza si tener dos tipos se asocia con mayor poder medio.
SELECT
    CASE
        WHEN f.tipo_2_id IS NULL THEN 'Un solo tipo'
        ELSE 'Doble tipo'
    END AS clase_tipo,
    COUNT(*) AS total_pokemon,
    ROUND(AVG(f.total_estadisticas), 2) AS media_total_estadisticas,
    ROUND(AVG(f.velocidad), 2) AS media_velocidad
FROM modelo.fact_estadisticas_pokemon f
GROUP BY clase_tipo;

-- Consulta 5: Pokemon por encima de la media general usando subquery.
-- Insight: localiza Pokemon cuyo total de estadísticas supera la media del dataset.
SELECT
    p.nombre,
    f.total_estadisticas
FROM modelo.fact_estadisticas_pokemon f
INNER JOIN modelo.dim_pokemon p
    ON f.pokemon_id = p.pokemon_id
WHERE f.total_estadisticas > (
    SELECT AVG(total_estadisticas)
    FROM modelo.fact_estadisticas_pokemon
)
ORDER BY f.total_estadisticas DESC, p.nombre;

-- Consulta 6: Ranking de Pokemon dentro de cada generación usando función ventana.
-- Insight: muestra los Pokemon mas fuertes de cada generación.
WITH ranking_generacion AS (
    SELECT
        g.nombre_generacion,
        p.nombre,
        f.total_estadisticas,
        RANK() OVER (
            PARTITION BY g.generacion_id
            ORDER BY f.total_estadisticas DESC
        ) AS ranking_en_generacion
    FROM modelo.fact_estadisticas_pokemon f
    INNER JOIN modelo.dim_pokemon p
        ON f.pokemon_id = p.pokemon_id
    INNER JOIN modelo.dim_generacion g
        ON f.generacion_id = g.generacion_id
)
SELECT *
FROM ranking_generacion
WHERE ranking_en_generacion <= 5
ORDER BY nombre_generacion, ranking_en_generacion, nombre;

-- Consulta 7: CTEs encadenadas para calcular ranking de tipos.
-- Insight: calcula media por tipo y despues ordena los tipos de mayor a menor poder.
WITH media_por_tipo AS (
    SELECT
        nombre_tipo,
        total_pokemon,
        media_total_estadisticas
    FROM analisis.vw_poder_por_tipo
),
ranking_tipos AS (
    SELECT
        nombre_tipo,
        total_pokemon,
        media_total_estadisticas,
        RANK() OVER (ORDER BY media_total_estadisticas DESC) AS ranking_tipo
    FROM media_por_tipo
)
SELECT *
FROM ranking_tipos
ORDER BY ranking_tipo;

-- Consulta 8: Habilidades más frecuentes.
-- Insight: permite saber qué habilidades aparecen en más Pokemon.
SELECT
    h.nombre_habilidad,
    COUNT(*) AS total_pokemon_con_habilidad
FROM modelo.puente_pokemon_habilidad ph
INNER JOIN modelo.dim_habilidad h
    ON ph.habilidad_id = h.habilidad_id
GROUP BY h.nombre_habilidad
ORDER BY total_pokemon_con_habilidad DESC, h.nombre_habilidad
LIMIT 20;

-- Consulta 9: Relación entre altura, peso y poder por nivel.
-- Insight: resume si los Pokemon de mayor nivel de poder tienden a ser más altos o pesados.
SELECT
    np.nombre_nivel,
    COUNT(*) AS total_pokemon,
    ROUND(AVG(f.altura_m), 2) AS altura_media_m,
    ROUND(AVG(f.peso_kg), 2) AS peso_medio_kg,
    ROUND(AVG(f.total_estadisticas), 2) AS media_total_estadisticas
FROM modelo.fact_estadisticas_pokemon f
INNER JOIN modelo.dim_nivel_poder np
    ON f.nivel_poder_id = np.nivel_poder_id
GROUP BY np.nombre_nivel
ORDER BY media_total_estadisticas DESC;

-- Consulta 10: Tipos primarios y secundarios con LEFT JOIN.
-- Insight: LEFT JOIN permite conservar Pokemon sin segundo tipo.
SELECT
    p.nombre,
    t1.nombre_tipo AS tipo_principal,
    COALESCE(t2.nombre_tipo, 'Sin segundo tipo') AS tipo_secundario,
    f.total_estadisticas
FROM modelo.fact_estadisticas_pokemon f
INNER JOIN modelo.dim_pokemon p
    ON f.pokemon_id = p.pokemon_id
INNER JOIN modelo.dim_tipo t1
    ON f.tipo_1_id = t1.tipo_id
LEFT JOIN modelo.dim_tipo t2
    ON f.tipo_2_id = t2.tipo_id
ORDER BY f.total_estadisticas DESC, p.nombre
LIMIT 50;

-- Consulta 11: Resumen reutilizable con función.
-- Insight: permite consultar rápidamente un resumen de cualquier tipo Pokemon.
SELECT *
FROM analisis.fn_resumen_tipo('Dragon');

-- Consulta 12: Porcentaje de Pokemon por generación.
-- Insight: muestra qué peso tiene cada generación sobre el total del dataset.
WITH total_dataset AS (
    SELECT COUNT(*) AS total_pokemon
    FROM modelo.fact_estadisticas_pokemon
),
pokemon_por_generacion AS (
    SELECT
        g.nombre_generacion,
        COUNT(*) AS total_generacion
    FROM modelo.fact_estadisticas_pokemon f
    INNER JOIN modelo.dim_generacion g
        ON f.generacion_id = g.generacion_id
    GROUP BY g.nombre_generacion
)
SELECT
    pg.nombre_generacion,
    pg.total_generacion,
    ROUND((pg.total_generacion::NUMERIC / td.total_pokemon) * 100, 2) AS porcentaje_sobre_total
FROM pokemon_por_generacion pg
CROSS JOIN total_dataset td
ORDER BY porcentaje_sobre_total DESC;
