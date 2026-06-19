Proyecto SQL - Pokemon Analytics
1. Objetivo del proyecto
Este proyecto consiste en diseñar, implementar y analizar una base de datos relacional a partir de un dataset de Kaggle de Pokemon que se transforma en un modelo relacional en PostgreSQLL.Se usa la normalizacion, claves primarias, claves foraneas, constraints, vistas, funciones y consultas analiticas.

El proyecto simula una Pokedex analítica, cuyo objetivo es responder preguntas sobre tipos, generaciones, habilidades, estadisticas base, altura, peso y niveles de poder de los Pokemon.

2. Fuente de datos
El archivo de origen es:

data/pokemon_complete.csv
Este CSV contiene informacion de Pokemon de distintas generaciones, incluyendo nombre, numero de Pokedex, tipos, estadisticas base, altura, peso, habilidades, generacion y variables descriptivas.

3. Arquitectura por capas
El proyecto se organiza en tres capas:

Capa carga
Contiene la tabla cruda (sin limpiar "raw"):

carga.stg_pokemon_raw
Esta tabla conserva una estructura parecida al CSV original. Los campos se cargan como texto para poder validar y convertir tipos posteriormente.

Capa modelo
Contiene el modelo relacional limpio:

modelo.dim_pokemon
modelo.dim_tipo
modelo.dim_generacion
modelo.dim_nivel_poder
modelo.dim_habilidad
modelo.fact_estadisticas_pokemon
modelo.puente_pokemon_habilidad
Capa analisis
Contiene vistas y funciones reutilizables:

analisis.vw_poder_por_tipo
analisis.vw_poder_por_generacion
analisis.fn_resumen_tipo(text)
4. Tabla de hechos y granularidad
La tabla principal de hechos es:

modelo.fact_estadisticas_pokemon
Granularidad:

Cada fila representa las estadisticas base de un Pokemon o forma concreta dentro del dataset.

Medidas principales:

hp
ataque
defensa
ataque_especial
defensa_especial
velocidad
total_estadisticas
altura_m
peso_kg
Variables que quedan fuera del modelo final:

base_experience: se conserva en la tabla de carga porque forma parte del CSV original, pero no se incorpora a la tabla de hechos. El análisis se centra en estadísticas base, tipos, generaciones, habilidades, altura, peso y nivel de poder.
ratio_ataque_defensa: no se crea como métrica derivada para mantener el proyecto más claro y evitar una variable menos intuitiva en esta primera versión.
5. Dimensiones y tabla puente
Las dimensiones sirven para describir y clasificar la tabla de hechos.

modelo.dim_pokemon: información identificativa y descriptiva del Pokemon.
modelo.dim_tipo: tipos Pokemon, como Fire, Water, Dragon, Grass, etc.
modelo.dim_generacion: generaciones de la 1 a la 9.
modelo.dim_nivel_poder: clasificación propia basada en total_estadisticas.
modelo.dim_habilidad: habilidades encontradas en el dataset.
Además de las dimensiones, el modelo incluye una tabla puente:

modelo.puente_pokemon_habilidad: relaciona Pokemon con habilidades.
Esta tabla puente es necesaria porque un Pokemon puede tener varias habilidades y una misma habilidad puede aparecer en muchos Pokemon. Por eso no se guarda una unica habilidad directamente en la tabla de hechos, sino que se crea una relación intermedia.

6. Alcance del proyecto
Dentro del alcance:

Estadísticas base de Pokemon.

Tipos principales y secundarios.

Generaciones.

Habilidades.

Clasificación de poder. Criterio: - Bajo: 0 a 330 - Medio: 331 a 450 - Alto: 451 a 580 - Muy alto: 581 o más

Comparación entre Pokemon legendarios, míticos, bebés y normales.

Análisis de altura, peso y poder.

Fuera del alcance:

Combates reales.
Movimientos.
Objetos.
Naturalezas.
Entrenamiento competitivo.
Datos de jugadores.
7. Decisiones de diseño
Se usa la tabla (carga.stg_pokemon_raw) para mantener trazabilidad con el CSV original.
Se separan tipos, generaciones, habilidades y niveles de poder en dimensiones para evitar repetir información y mejorar la normalización.
pokemon_id es clave primaria surrogate porque el número de Pokedex puede repetirse en distintas formas.
type_2 puede ser NULL porque muchos Pokemon solo tienen un tipo.
Se usa una tabla puente para habilidades porque un Pokemon puede tener varias habilidades y una habilidad puede pertenecer a muchos Pokemon.
Se crean índices sobre generación, tipo principal y habilidad porque son campos frecuentes en filtros, joins y agrupaciones.
8. Orden de ejecución
En DBeaver o en otro programa conectado a PostgreSQL, ejecutar en este orden:

01_schema.sql
02_data.sql
03_eda.sql
9. Consultas analíticas incluidas
El archivo 03_eda.sql incluye validaciones de calidad de datos y 12 consultas analíticas, entre ellas:

Poder medio por tipo.
Poder medio por generación.
Comparación de legendarios, míticos, bebés y normales.
Comparacion entre Pokemon de un tipo y doble tipo.
Pokemon por encima de la media general.
Ranking de Pokemon dentro de cada generación.
Ranking de tipos con CTEs encadenadas.
Habilidades mas frecuentes.
Relación entre altura, peso y poder.
Uso de LEFT JOIN para segundo tipo.
Uso de función para resumen por tipo.
Porcentaje de Pokemon por generación.
10. Herramientas
PostgreSQL
DBeaver
GitHub
11. Notas finales
El proyecto está pensado para ser pequeño, claro y reproducible. El objetivo no es crear una Pokedex completa de combate competitivo, sino practicar SQL sobre un modelo relacional coherente a partir de un CSV real.
