-- EL siguiente código no se tiene que ejecutar solo se deja con el fin de informar procedimientos
/*
CREATE TABLE datos_orig_pruebas."tarjetas_de_crédito_y_débito" AS 
SELECT *
FROM datos_originales."tarjetas_de_crédito_y_débito";
*/


-- Consulta a los datos originales antes del etl
SELECT *
FROM datos_orig_pruebas.tarjetas_de_crédito_y_débito tdcyd;

BEGIN; -- Se añade un bloque transaccional para ver lo datos originales y el resultado final.

-- 1.1 Renombrar tabla principal a estándar analítico
ALTER TABLE datos_orig_pruebas."tarjetas_de_crédito_y_débito"  RENAME TO fact_tarjetas_credito_debito;
 
-- 1.2 Normalizar nombres de columnas críticas respetando las comillas de la fuente original
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito RENAME COLUMN "TIPOENTIDAD" TO id_tipo_entidad;
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito RENAME COLUMN "CODIGOENTIDAD" TO codigo_entidad;
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito RENAME COLUMN "FECHACORTE" TO fecha_corte;
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito RENAME COLUMN "PERSONA_NATURAL" TO persona_natural;
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito RENAME COLUMN "PERSONA_JURIDICA" TO persona_juridica;
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito RENAME COLUMN "TOTAL_TARJETAS" TO total_tarjetas;

-- 1.3 Limpieza: Eliminar columnas redundantes o sin contexto relacional
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito DROP COLUMN codigo_entidad;

-- 2.1 DIMENSIÓN: TIPO DE ENTIDAD (Mapeo según normativa SFC)
CREATE TABLE datos_orig_pruebas.dim_tipo_entidad (
    id_tipo_entidad INT PRIMARY KEY,
    nombre_tipo_entidad VARCHAR(100)
);

INSERT INTO datos_orig_pruebas.dim_tipo_entidad (id_tipo_entidad, nombre_tipo_entidad)
VALUES 
(1, 'Bancos Comerciales'),
(4, 'Compañías de Financiamiento'),
(32, 'Cooperativas Financieras'),
(118, 'Redes de Procesamiento, Pagos y Servicios');


-- 2.2 DIMENSIÓN: NOMBRE DE ENTIDAD (Generación de Llave Subrogada)
CREATE TABLE datos_orig_pruebas.dim_nombre_entidad AS
SELECT DISTINCT "NOMBREENTIDAD" AS nombre_entidad
FROM datos_orig_pruebas.fact_tarjetas_credito_debito
ORDER BY nombre_entidad ASC;

ALTER TABLE datos_orig_pruebas.dim_nombre_entidad 
ADD COLUMN id_nombre_identidad SERIAL PRIMARY KEY;


-- 2.3 DIMENSIÓN: UCA (Unidad de Captura)
CREATE TABLE datos_orig_pruebas.dim_uca AS
SELECT DISTINCT "COD_UCA" AS cod_uca, "NOMBRE_UCA" AS nombre_uca
FROM datos_orig_pruebas.fact_tarjetas_credito_debito;

-- 2.3.1 Normalización de nombre del atributo "COD_UCA"
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito RENAME COLUMN "COD_UCA" TO cod_uca;

-- Limpieza en Hechos tras aislar la dimensión UCA
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito DROP COLUMN "NOMBRE_UCA";


-- 2.4 DIMENSIÓN: CONCEPTO (Estructurada a partir del atributo Subcuenta)
CREATE TABLE datos_orig_pruebas.dim_concepto (
    id_concepto INT PRIMARY KEY,
    descripcion_concepto VARCHAR(255) NOT NULL
);

INSERT INTO datos_orig_pruebas.dim_concepto (id_concepto, descripcion_concepto) VALUES
(5, 'Tarjetas vigentes a la fecha de corte'),
(10, 'Tarjetas vigentes durante el mes'),
(15, 'Tarjetas canceladas'),
(20, 'Tarjetas bloqueadas temporalmente'),
(25, 'Cantidad de transacciones por compras nacionales'),
(30, 'Cantidad de transacciones por avances nacionales / retiros débito'),
(35, 'Monto monetario por compras en el exterior / compras débito'),
(40, 'Monto monetario por avances en el exterior / retiros débito'),
(45, 'Monto monetario por compras crédito nacional'),
(50, 'Monto monetario por avances crédito nacional'),
(55, 'Monto monetario por compras en el exterior'),
(60, 'Tarifa de intercambio (TII) / Intereses corrientes'),
(65, 'Intereses de mora'),
(70, 'Comisiones interbancarias y otras tarifas'),
(75, 'Castigos de cartera - Capital'),
(80, 'Castigos de cartera - Conceptos diferentes a capital'),
(85, 'Saldo total de la cartera'),
(90, 'Cupo de crédito disponible'),
(110, 'Cantidad de tarjetas sin chip de seguridad'),
(115, 'Cantidad de tarjetas con tecnología sin contacto (Contactless)');


-- 2.5 DIMENSIÓN: DESCRIPCIÓN DETALLADA
CREATE TABLE datos_orig_pruebas.dim_descr_detallada AS
SELECT DISTINCT "DESCRIPCION" AS descripcion 
FROM datos_orig_pruebas.fact_tarjetas_credito_debito;

ALTER TABLE datos_orig_pruebas.dim_descr_detallada 
ADD COLUMN id_descr_detallada SERIAL PRIMARY KEY;

-- 3.1 Vinculación con dim_nombre_entidad
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito ADD COLUMN id_nombre_identidad INT;

UPDATE datos_orig_pruebas.fact_tarjetas_credito_debito ftcd 
SET id_nombre_identidad = dne.id_nombre_identidad
FROM datos_orig_pruebas.dim_nombre_entidad dne
WHERE dne.nombre_entidad = ftcd."NOMBREENTIDAD";

ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito DROP COLUMN "NOMBREENTIDAD";


-- 3.2 Vinculación con dim_concepto (Reemplazo del campo subcuenta)
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito RENAME COLUMN "SUBCUENTA" TO id_concepto;


-- 3.3 Vinculación con dim_descr_detallada
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito ADD COLUMN id_descr_detallada INT;

UPDATE datos_orig_pruebas.fact_tarjetas_credito_debito ftcd 
SET id_descr_detallada = ddd.id_descr_detallada
FROM datos_orig_pruebas.dim_descr_detallada ddd
WHERE ftcd."DESCRIPCION" = ddd.descripcion;

ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito DROP COLUMN "DESCRIPCION";

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
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito 
ADD COLUMN id_tipo_metrica INT;

-- Crear tabla de dimensión métrica
CREATE TABLE datos_orig_pruebas.dim_metrica (
    id_tipo_metrica INT PRIMARY KEY,
    tipo_metrica VARCHAR(50)
);

INSERT INTO datos_orig_pruebas.dim_metrica (id_tipo_metrica, tipo_metrica)
VALUES 
    (1, 'Monto financiero'),
    (2, 'Cantidad / Conteo');

-- Ampliación de atributos en dim_metrica
ALTER TABLE datos_orig_pruebas.dim_metrica 
ADD COLUMN medida INT;

ALTER TABLE datos_orig_pruebas.dim_metrica 
ADD COLUMN metrica_descripcion INT;

-- Corrección de tipo de dato (Demostración de corrección de tipos en DDL)
ALTER TABLE datos_orig_pruebas.dim_metrica
    ALTER COLUMN medida TYPE VARCHAR(50) USING medida::VARCHAR,
    ALTER COLUMN metrica_descripcion TYPE VARCHAR(255) USING metrica_descripcion::VARCHAR;

-- Actualización de descriptores en la dimensión métrica
UPDATE datos_orig_pruebas.dim_metrica
SET medida = 'Pesos (COP)', 
    metrica_descripcion = 'Valores monetarios absolutos (Saldos, comisiones, tasas)'
WHERE id_tipo_metrica = 1;

UPDATE datos_orig_pruebas.dim_metrica
SET medida = 'Unidades', 
    metrica_descripcion = 'Conteos físicos (Número de tarjetas, transacciones)'
WHERE id_tipo_metrica = 2;

-- Actualización del id_tipo_metrica en la tabla de hechos según el concepto
UPDATE datos_orig_pruebas.fact_tarjetas_credito_debito AS ftcd 
SET id_tipo_metrica = 2
FROM datos_orig_pruebas.dim_concepto AS dc 
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
UPDATE datos_orig_pruebas.fact_tarjetas_credito_debito 
SET id_tipo_metrica = 1
WHERE id_tipo_metrica IS NULL;

-- -----------------------------------------------------------------------------
-- 2. REFACTORIZACIÓN DE DIMENSIONES Y RENOMBRAMIENTO
-- -----------------------------------------------------------------------------

-- Eliminación de la dimensión concepto obsoleta y su FK en hechos
DROP TABLE datos_orig_pruebas.dim_concepto;

ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito 
DROP COLUMN id_concepto;

-- Renombramiento de dim_descr_detallada a dim_descripcion
ALTER TABLE datos_orig_pruebas.dim_descr_detallada RENAME TO dim_descripcion;

ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito 
RENAME COLUMN id_descr_detallada TO id_descripcion;

ALTER TABLE datos_orig_pruebas.dim_descripcion 
RENAME COLUMN id_descr_detallada TO id_descripcion;

-- Renombramiento de atributo en la tabla de hechos para evitar ambigüedad semántica
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito 
RENAME COLUMN total_tarjetas TO valor;

-- -----------------------------------------------------------------------------
-- 3. CONSTRUCCIÓN Y POBLADO DE LA DIMENSIÓN TIEMPO / FECHA
-- -----------------------------------------------------------------------------

CREATE TABLE datos_orig_pruebas.dim_fecha (
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
INSERT INTO datos_orig_pruebas.dim_fecha (
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
FROM datos_orig_pruebas.fact_tarjetas_credito_debito AS ftcd
ORDER BY ftcd.fecha_corte ASC;

-- Cálculo del indicador de fin de mes
WITH ultima_fecha AS (
    SELECT 
        df.fecha_corte,
        (df.dia_num = MAX(df.dia_num) OVER(PARTITION BY df.año, df.mes_num)) AS es_final_mes
    FROM datos_orig_pruebas.dim_fecha AS df
)
UPDATE datos_orig_pruebas.dim_fecha AS df
SET final_mes = uf.es_final_mes
FROM ultima_fecha AS uf
WHERE df.fecha_corte = uf.fecha_corte;

-- -----------------------------------------------------------------------------
-- 4. VINCULACIÓN DE LA CLAVE SURROGATE DE FECHA EN LA TABLA DE HECHOS
-- -----------------------------------------------------------------------------

-- Crear nueva columna FK para la fecha
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito 
ADD COLUMN id_fecha INT;

-- Migración de la clave Surrogate basada en la fecha natural
UPDATE datos_orig_pruebas.fact_tarjetas_credito_debito AS ftcd
SET id_fecha = df.id_fecha 
FROM datos_orig_pruebas.dim_fecha AS df
WHERE df.fecha_corte = ftcd.fecha_corte;

-- Eliminación de la fecha natural en la Fact Table (Normalización Dimensional)
ALTER TABLE datos_orig_pruebas.fact_tarjetas_credito_debito 
DROP COLUMN fecha_corte;


-- Comparamos las tablas de pruebas con la tabla ya normalizada 
SELECT *
FROM datos_orig_pruebas.fact_tarjetas_credito_debito TABLA_PRUEBA
ORDER BY VALOR DESC;

SELECT *
FROM datos_tarjetas.fact_tarjetas_credito_debito AS TABLA_NORMALIZADA
ORDER BY VALOR DESC;	


ROLLBACK;

