/*
================================================================================
  SCRIPT DE SEGUNDO ETL Y REESTRUCTURACIÓN DE MODELADO DIMENSIONAL
  Descripción: Reestructuración de tabla de hechos, creación de dim_metrica,
               refactorización de dim_descripcion y poblado de dim_fecha.
================================================================================
*/

-- -----------------------------------------------------------------------------
-- 1. REESTRUCTURACIÓN Y CREACIÓN DE LA DIMENSIÓN MÉTRICA
-- -----------------------------------------------------------------------------

-- Agregar clave foránea para la dimensión métrica en la tabla de hechos
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito 
ADD COLUMN id_tipo_metrica INT;

-- Crear tabla de dimensión métrica
CREATE TABLE datos_tarjetas.dim_metrica (
    id_tipo_metrica INT PRIMARY KEY,
    tipo_metrica VARCHAR(50)
);

INSERT INTO datos_tarjetas.dim_metrica (id_tipo_metrica, tipo_metrica)
VALUES 
    (1, 'Monto financiero'),
    (2, 'Cantidad / Conteo');

-- Ampliación de atributos en dim_metrica
ALTER TABLE datos_tarjetas.dim_metrica 
ADD COLUMN medida INT;

ALTER TABLE datos_tarjetas.dim_metrica 
ADD COLUMN metrica_descripcion INT;

-- Corrección de tipo de dato (Demostración de corrección de tipos en DDL)
ALTER TABLE datos_tarjetas.dim_metrica
    ALTER COLUMN medida TYPE VARCHAR(50) USING medida::VARCHAR,
    ALTER COLUMN metrica_descripcion TYPE VARCHAR(255) USING metrica_descripcion::VARCHAR;

-- Actualización de descriptores en la dimensión métrica
UPDATE datos_tarjetas.dim_metrica
SET medida = 'Pesos (COP)', 
    metrica_descripcion = 'Valores monetarios absolutos (Saldos, comisiones, tasas)'
WHERE id_tipo_metrica = 1;

UPDATE datos_tarjetas.dim_metrica
SET medida = 'Unidades', 
    metrica_descripcion = 'Conteos físicos (Número de tarjetas, transacciones)'
WHERE id_tipo_metrica = 2;

-- Actualización del id_tipo_metrica en la tabla de hechos según el concepto
UPDATE datos_tarjetas.fact_tarjetas_credito_debito AS ftcd 
SET id_tipo_metrica = 2
FROM datos_tarjetas.dim_concepto AS dc 
WHERE dc.id_concepto = ftcd.id_concepto
  AND dc.descripcion_concepto IN (
      'Tarjetas vigentes a la fecha de corte',
      'Tarjetas vigentes durante el mes',
      'Tarjetas canceladas',
      'Tarjetas bloqueadas temporalmente',
      'Cantidad de tarjetas sin chip de seguridad',
      'Cantidad de tarjetas con tecnología sin contacto (Contactless)',
      'Cantidad de transacciones por compras nacionales',
      'Cantidad de transacciones por avances nacionales / retiros débito'
  );

-- Asignación por defecto a Monto financiero
UPDATE datos_tarjetas.fact_tarjetas_credito_debito 
SET id_tipo_metrica = 1
WHERE id_tipo_metrica IS NULL;

-- -----------------------------------------------------------------------------
-- 2. REFACTORIZACIÓN DE DIMENSIONES Y RENOMBRAMIENTO
-- -----------------------------------------------------------------------------

-- Eliminación de la dimensión concepto obsoleta y su FK en hechos
DROP TABLE datos_tarjetas.dim_concepto;

ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito 
DROP COLUMN id_concepto;

-- Renombramiento de dim_descr_detallada a dim_descripcion
ALTER TABLE datos_tarjetas.dim_descr_detallada RENAME TO dim_descripcion;

ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito 
RENAME COLUMN id_descr_detallada TO id_descripcion;

ALTER TABLE datos_tarjetas.dim_descripcion 
RENAME COLUMN id_descr_detallada TO id_descripcion;

-- Renombramiento de atributo en la tabla de hechos para evitar ambigüedad semántica
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito 
RENAME COLUMN total_tarjetas TO valor;

-- -----------------------------------------------------------------------------
-- 3. CONSTRUCCIÓN Y POBLADO DE LA DIMENSIÓN TIEMPO / FECHA
-- -----------------------------------------------------------------------------

CREATE TABLE datos_tarjetas.dim_fecha (
    id_fecha INT PRIMARY KEY,
    fecha_corte DATE,
    dia_num INT,
    mes_num INT,
    año INT,
    dia_name VARCHAR(20),
    mes_name VARCHAR(20),
    final_mes BOOLEAN
);

-- Carga inicial y derivación de atributos temporales
INSERT INTO datos_tarjetas.dim_fecha (
    id_fecha,
    fecha_corte,
    dia_num,
    mes_num,
    año,
    dia_name,
    mes_name
)
SELECT DISTINCT 
    TO_CHAR(ftcd.fecha_corte, 'YYYYMMDD')::INT AS id_fecha,
    ftcd.fecha_corte,
    EXTRACT(DAY FROM ftcd.fecha_corte)::INT AS dia_num,
    EXTRACT(MONTH FROM ftcd.fecha_corte)::INT AS mes_num,
    EXTRACT(YEAR FROM ftcd.fecha_corte)::INT AS año,
    CASE EXTRACT(DOW FROM ftcd.fecha_corte)
        WHEN 1 THEN 'lunes'
        WHEN 2 THEN 'martes'
        WHEN 3 THEN 'miércoles'
        WHEN 4 THEN 'jueves'
        WHEN 5 THEN 'viernes'
        WHEN 6 THEN 'sábado'
        WHEN 0 THEN 'domingo'
    END AS dia_name,
    CASE EXTRACT(MONTH FROM ftcd.fecha_corte)
        WHEN 1 THEN 'enero'
        WHEN 2 THEN 'febrero'
        WHEN 3 THEN 'marzo'
        WHEN 4 THEN 'abril'
        WHEN 5 THEN 'mayo'
        WHEN 6 THEN 'junio'
        WHEN 7 THEN 'julio'
        WHEN 8 THEN 'agosto'
        WHEN 9 THEN 'septiembre'
        WHEN 10 THEN 'octubre'
        WHEN 11 THEN 'noviembre'
        WHEN 12 THEN 'diciembre'
    END AS mes_name
FROM datos_tarjetas.fact_tarjetas_credito_debito AS ftcd
ORDER BY ftcd.fecha_corte ASC;

-- Cálculo del indicador de fin de mes
WITH ultima_fecha AS (
    SELECT 
        df.fecha_corte,
        (df.dia_num = MAX(df.dia_num) OVER(PARTITION BY df.año, df.mes_num)) AS es_final_mes
    FROM datos_tarjetas.dim_fecha AS df
)
UPDATE datos_tarjetas.dim_fecha AS df
SET final_mes = uf.es_final_mes
FROM ultima_fecha AS uf
WHERE df.fecha_corte = uf.fecha_corte;

-- -----------------------------------------------------------------------------
-- 4. VINCULACIÓN DE LA CLAVE SURROGATE DE FECHA EN LA TABLA DE HECHOS
-- -----------------------------------------------------------------------------

-- Crear nueva columna FK para la fecha
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito 
ADD COLUMN id_fecha INT;

-- Migración de la clave Surrogate basada en la fecha natural
UPDATE datos_tarjetas.fact_tarjetas_credito_debito AS ftcd
SET id_fecha = df.id_fecha 
FROM datos_tarjetas.dim_fecha AS df
WHERE df.fecha_corte = ftcd.fecha_corte;

-- Eliminación de la fecha natural en la Fact Table (Normalización Dimensional)
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito 
DROP COLUMN fecha_corte;