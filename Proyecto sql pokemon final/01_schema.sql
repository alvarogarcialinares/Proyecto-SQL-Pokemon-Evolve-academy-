-- ==========================================================
-- PROYECTO SQL - POKEMON ANALYTICS
-- Archivo: 01_schema.sql
-- Objetivo: crear la estructura relacional del proyecto.
-- ==========================================================

-- Capas del proyecto:
-- carga    -> tabla cruda parecida al CSV original.
-- modelo   -> modelo dimensional limpio con PK, FK y constraints.
-- analisis -> vistas y funciones para responder preguntas analíticas.

CREATE SCHEMA IF NOT EXISTS carga;
CREATE SCHEMA IF NOT EXISTS modelo;
CREATE SCHEMA IF NOT EXISTS analisis;

-- Borrado ordenado para que el proyecto pueda ejecutarse desde cero.
DROP FUNCTION IF EXISTS analisis.fn_resumen_tipo(TEXT);
DROP VIEW IF EXISTS analisis.vw_poder_por_generacion;
DROP VIEW IF EXISTS analisis.vw_poder_por_tipo;

DROP TABLE IF EXISTS modelo.puente_pokemon_habilidad;
DROP TABLE IF EXISTS modelo.fact_estadisticas_pokemon;
DROP TABLE IF EXISTS modelo.dim_habilidad;
DROP TABLE IF EXISTS modelo.dim_nivel_poder;
DROP TABLE IF EXISTS modelo.dim_generacion;
DROP TABLE IF EXISTS modelo.dim_tipo;
DROP TABLE IF EXISTS modelo.dim_pokemon;
DROP TABLE IF EXISTS carga.stg_pokemon_raw;

-- ==========================================================
-- CAPA CARGA
-- ==========================================================

CREATE TABLE IF NOT EXISTS carga.stg_pokemon_raw (
    raw_id SERIAL PRIMARY KEY,
    pokedex_number TEXT,
    name TEXT,
    type_1 TEXT,
    type_2 TEXT,
    hp TEXT,
    attack TEXT,
    defense TEXT,
    sp_attack TEXT,
    sp_defense TEXT,
    speed TEXT,
    base_stat_total TEXT,
    height_m TEXT,
    weight_kg TEXT,
    base_experience TEXT,
    abilities TEXT,
    hidden_ability TEXT,
    generation TEXT,
    is_legendary TEXT,
    is_mythical TEXT,
    is_baby TEXT,
    color TEXT,
    shape TEXT,
    egg_groups TEXT,
    habitat TEXT,
    growth_rate TEXT,
    capture_rate TEXT,
    base_happiness TEXT,
    genus TEXT,
    evolution_chain_id TEXT,
    flavor_text TEXT,
    sprite_url TEXT,
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE carga.stg_pokemon_raw IS
'Tabla de carga inicial. Cada fila representa un registro original del CSV de Pokemon. Se guardan los campos como texto para poder validar y convertir tipos después. Algunas columnas del CSV, como base_experience, se conservan aquí por trazabilidad pero no pasan al modelo analítico final.';

-- ==========================================================
-- CAPA MODELO: DIMENSIONES
-- ==========================================================

CREATE TABLE IF NOT EXISTS modelo.dim_pokemon (
    pokemon_id SERIAL PRIMARY KEY,
    raw_id_origen INT NOT NULL UNIQUE,
    numero_pokedex INT NOT NULL CHECK (numero_pokedex > 0),
    nombre VARCHAR(120) NOT NULL,
    es_legendario BOOLEAN NOT NULL DEFAULT FALSE,
    es_mitico BOOLEAN NOT NULL DEFAULT FALSE,
    es_bebe BOOLEAN NOT NULL DEFAULT FALSE,
    color VARCHAR(50),
    forma VARCHAR(80),
    grupo_huevo VARCHAR(200),
    habitat VARCHAR(80),
    ritmo_crecimiento VARCHAR(80),
    genero VARCHAR(120),
    texto_descriptivo TEXT,
    url_sprite TEXT
);

COMMENT ON TABLE modelo.dim_pokemon IS
'Dimension Pokemon. Cada fila representa un Pokemon o forma concreta del dataset. El número de Pokedex no es UNIQUE porque algunas formas pueden compartir número.';

CREATE TABLE IF NOT EXISTS modelo.dim_tipo (
    tipo_id SERIAL PRIMARY KEY,
    nombre_tipo VARCHAR(50) NOT NULL UNIQUE
);

COMMENT ON TABLE modelo.dim_tipo IS
'Dimension Tipo. Cada fila representa un tipo Pokemon, por ejemplo Fire, Water, Grass o Dragon.';

CREATE TABLE IF NOT EXISTS modelo.dim_generacion (
    generacion_id INT PRIMARY KEY,
    nombre_generacion VARCHAR(30) NOT NULL UNIQUE,
    region_principal VARCHAR(50) NOT NULL,
    CHECK (generacion_id BETWEEN 1 AND 9)
);

COMMENT ON TABLE modelo.dim_generacion IS
'Dimension Generacion. Cada fila representa una generación principal de Pokemon, de la 1 a la 9.';

CREATE TABLE IF NOT EXISTS modelo.dim_nivel_poder (
    nivel_poder_id SERIAL PRIMARY KEY,
    nombre_nivel VARCHAR(30) NOT NULL UNIQUE,
    stat_min INT NOT NULL CHECK (stat_min >= 0),
    stat_max INT NOT NULL CHECK (stat_max > stat_min)
);

COMMENT ON TABLE modelo.dim_nivel_poder IS
'Dimension Nivel de Poder. Clasifica cada Pokemon segun su base_stat_total en bajo, medio, alto o muy alto.';

CREATE TABLE IF NOT EXISTS modelo.dim_habilidad (
    habilidad_id SERIAL PRIMARY KEY,
    nombre_habilidad VARCHAR(120) NOT NULL UNIQUE
);

COMMENT ON TABLE modelo.dim_habilidad IS
'Dimension Habilidad. Cada fila representa una habilidad Pokemon encontrada en el CSV.';

-- ==========================================================
-- CAPA MODELO: TABLA DE HECHOS
-- ==========================================================

CREATE TABLE IF NOT EXISTS modelo.fact_estadisticas_pokemon (
    estadistica_id SERIAL PRIMARY KEY,
    pokemon_id INT NOT NULL UNIQUE REFERENCES modelo.dim_pokemon(pokemon_id),
    tipo_1_id INT NOT NULL REFERENCES modelo.dim_tipo(tipo_id),
    tipo_2_id INT REFERENCES modelo.dim_tipo(tipo_id),
    generacion_id INT NOT NULL REFERENCES modelo.dim_generacion(generacion_id),
    nivel_poder_id INT NOT NULL REFERENCES modelo.dim_nivel_poder(nivel_poder_id),
    hp INT NOT NULL CHECK (hp > 0),
    ataque INT NOT NULL CHECK (ataque >= 0),
    defensa INT NOT NULL CHECK (defensa >= 0),
    ataque_especial INT NOT NULL CHECK (ataque_especial >= 0),
    defensa_especial INT NOT NULL CHECK (defensa_especial >= 0),
    velocidad INT NOT NULL CHECK (velocidad >= 0),
    total_estadisticas INT NOT NULL CHECK (total_estadisticas > 0),
    altura_m NUMERIC(6,2) CHECK (altura_m >= 0),
    peso_kg NUMERIC(8,2) CHECK (peso_kg >= 0),
    fecha_carga TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE modelo.fact_estadisticas_pokemon IS
'Tabla de hechos principal. Cada fila representa las estadísticas base de un Pokemon o forma concreta. Es la tabla central del análisis. No incluye base_experience ni ratio_ataque_defensa para mantener el modelo centrado en estadisticas base, altura y peso.';

CREATE TABLE IF NOT EXISTS modelo.puente_pokemon_habilidad (
    pokemon_id INT NOT NULL REFERENCES modelo.dim_pokemon(pokemon_id),
    habilidad_id INT NOT NULL REFERENCES modelo.dim_habilidad(habilidad_id),
    es_oculta BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (pokemon_id, habilidad_id)
);

COMMENT ON TABLE modelo.puente_pokemon_habilidad IS
'Tabla puente porque un Pokemon puede tener varias habilidades y una misma habilidad puede aparecer en muchos Pokemon.';

-- Índices útiles para acelerar consultas frecuentes por tipo y generación.
CREATE INDEX IF NOT EXISTS idx_fact_generacion
ON modelo.fact_estadisticas_pokemon(generacion_id);

CREATE INDEX IF NOT EXISTS idx_fact_tipo_1
ON modelo.fact_estadisticas_pokemon(tipo_1_id);

CREATE INDEX IF NOT EXISTS idx_puente_habilidad
ON modelo.puente_pokemon_habilidad(habilidad_id);

-- ==========================================================
-- CAPA ANÁLISIS: VISTAS
-- ==========================================================

CREATE OR REPLACE VIEW analisis.vw_poder_por_tipo AS
WITH tipos_pokemon AS (
    SELECT tipo_1_id AS tipo_id, total_estadisticas, ataque, defensa, velocidad
    FROM modelo.fact_estadisticas_pokemon
    UNION ALL
    SELECT tipo_2_id AS tipo_id, total_estadisticas, ataque, defensa, velocidad
    FROM modelo.fact_estadisticas_pokemon
    WHERE tipo_2_id IS NOT NULL
)
SELECT
    t.nombre_tipo,
    COUNT(*) AS total_pokemon,
    ROUND(AVG(tp.total_estadisticas), 2) AS media_total_estadisticas,
    ROUND(AVG(tp.ataque), 2) AS media_ataque,
    ROUND(AVG(tp.defensa), 2) AS media_defensa,
    ROUND(AVG(tp.velocidad), 2) AS media_velocidad
FROM tipos_pokemon tp
INNER JOIN modelo.dim_tipo t
    ON tp.tipo_id = t.tipo_id
GROUP BY t.nombre_tipo;

COMMENT ON VIEW analisis.vw_poder_por_tipo IS
'Vista analítica que resume el poder medio de los Pokemon por tipo, contando tanto tipo principal como tipo secundario.';

CREATE OR REPLACE VIEW analisis.vw_poder_por_generacion AS
SELECT
    g.generacion_id,
    g.nombre_generacion,
    g.region_principal,
    COUNT(*) AS total_pokemon,
    ROUND(AVG(f.total_estadisticas), 2) AS media_total_estadisticas,
    MAX(f.total_estadisticas) AS max_total_estadisticas,
    MIN(f.total_estadisticas) AS min_total_estadisticas
FROM modelo.fact_estadisticas_pokemon f
INNER JOIN modelo.dim_generacion g
    ON f.generacion_id = g.generacion_id
GROUP BY g.generacion_id, g.nombre_generacion, g.region_principal;

COMMENT ON VIEW analisis.vw_poder_por_generacion IS
'Vista analitica que resume numero de Pokemon y estadisticas por generacion.';

-- ==========================================================
-- FUNCIÓN
-- ==========================================================

CREATE OR REPLACE FUNCTION analisis.fn_resumen_tipo(p_nombre_tipo TEXT)
RETURNS TABLE (
    nombre_tipo VARCHAR,
    total_pokemon BIGINT,
    media_hp NUMERIC,
    media_ataque NUMERIC,
    media_defensa NUMERIC,
    media_total_estadisticas NUMERIC,
    max_total_estadisticas INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH pokemon_del_tipo AS (
        SELECT f.*
        FROM modelo.fact_estadisticas_pokemon f
        INNER JOIN modelo.dim_tipo t
            ON t.tipo_id = f.tipo_1_id OR t.tipo_id = f.tipo_2_id
        WHERE LOWER(t.nombre_tipo) = LOWER(p_nombre_tipo)
    )
    SELECT
        p_nombre_tipo::VARCHAR AS nombre_tipo,
        COUNT(*) AS total_pokemon,
        ROUND(AVG(hp), 2) AS media_hp,
        ROUND(AVG(ataque), 2) AS media_ataque,
        ROUND(AVG(defensa), 2) AS media_defensa,
        ROUND(AVG(total_estadisticas), 2) AS media_total_estadisticas,
        MAX(total_estadisticas) AS max_total_estadisticas
    FROM pokemon_del_tipo;
END;
$$;

COMMENT ON FUNCTION analisis.fn_resumen_tipo(TEXT) IS
'Función reutilizable que devuelve un resumen estadístico de un tipo Pokemon concreto.';
