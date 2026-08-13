-- ==============================================================================
-- 5.0 FASE DE AUDITORÍA, CONTROL DE CALIDAD Y NORMALIZACIÓN DE TIPOS
-- ==============================================================================

-- 5.1 CONTROL DE VOLUMETRÍA E INTEGRIDAD (CONCILIACIÓN DE REGISTROS)
-- Objetivo: Validar que la tabla de hechos final tenga exactamente el mismo 
-- número de filas que la tabla original, garantizando cero pérdida de datos en el ETL.
SELECT 
    COUNT(*) AS total_registros, 
    'ANALISIS (Tabla Hechos)' AS origen_datos 
FROM datos_tarjetas.fact_tarjetas_credito_debito AS ftcd

UNION ALL

SELECT 
    COUNT(*) AS total_registros, 
    'ORIGINAL (Tabla Cruda)' AS origen_datos 
FROM datos_originales.tarjetas_de_crédito_y_débito AS tdcyd;


-- 5.2 TRANSFORMAR Y LIMPIAR TIPO DE DATO (SQL NATIVO EN TABLA DE HECHOS)
-- Objetivo: Corregir el formato de texto de la columna "persona_natural". 
-- Se eliminan separadores de miles (.), se reemplazan comas decimales (,) por puntos 
-- y se fuerza el casteo a tipo de dato numérico exacto (NUMERIC).
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito 
ALTER COLUMN persona_natural TYPE NUMERIC 
USING REPLACE(REPLACE(persona_natural::TEXT, '.', ''), ',', '.')::NUMERIC;


-- 5.3 COMPROBACIÓN DE EXTREMOS Y AUDITORÍA VISUAL (TABLA HECHOS)
-- Objetivo: Validar que la distribución y ordenamiento de los valores máximos 
-- en la nueva tabla estructurada concuerden con los datos procesados.
SELECT * 
FROM datos_tarjetas.fact_tarjetas_credito_debito AS ftcd
ORDER BY ftcd.persona_natural DESC
LIMIT 10;


-- 5.4 COMPROBACIÓN DE EXTREMOS Y AUDITORÍA VISUAL (TABLA ORIGINAL)
-- Objetivo: Contraste final de control contra la tabla original para asegurar 
-- que el casteo del tipo de dato numérico no alteró la veracidad de la información.
SELECT 
    "PERSONA_NATURAL",
    REPLACE(REPLACE("PERSONA_NATURAL", '.', ''), ',', '.')::NUMERIC AS persona_natural_limpia
FROM datos_originales.tarjetas_de_crédito_y_débito AS tdcyd 
ORDER BY persona_natural_limpia DESC
LIMIT 10;