-- ==============================================================================
-- PROYECTO: ANALÍTICA DE TARJETAS DE CRÉDITO Y DÉBITO (SFC)
-- FASE: PRIMER ETL (EXTRACT, TRANSFORM AND LOAD) & MODELADO ESTRELLA INICIAL
-- ==============================================================================

-- ==============================================================================
-- 1. PREPARACIÓN DE LA TABLA DE HECHOS
-- ==============================================================================

-- 1.1 Renombrar tabla principal a estándar analítico
ALTER TABLE datos_tarjetas."tarjetas_de_crédito_y_débito" RENAME TO fact_tarjetas_credito_debito;
 
-- 1.2 Normalizar nombres de columnas críticas respetando las comillas de la fuente original
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito RENAME COLUMN "TIPOENTIDAD" TO id_tipo_entidad;
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito RENAME COLUMN "CODIGOENTIDAD" TO codigo_entidad;
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito RENAME COLUMN "FECHACORTE" TO fecha_corte;
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito RENAME COLUMN "PERSONA_NATURAL" TO persona_natural;
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito RENAME COLUMN "PERSONA_JURIDICA" TO persona_juridica;
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito RENAME COLUMN "TOTAL_TARJETAS" TO total_tarjetas;

-- 1.3 Limpieza: Eliminar columnas redundantes o sin contexto relacional
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito DROP COLUMN codigo_entidad;


-- ==============================================================================
-- 2. CREACIÓN Y POBLACIÓN DE DIMENSIONES (EVALUACIÓN CUALITATIVA)
-- ==============================================================================

-- 2.1 DIMENSIÓN: TIPO DE ENTIDAD (Mapeo según normativa SFC)
CREATE TABLE datos_tarjetas.dim_tipo_entidad (
    id_tipo_entidad INT PRIMARY KEY,
    nombre_tipo_entidad VARCHAR(100)
);

INSERT INTO datos_tarjetas.dim_tipo_entidad (id_tipo_entidad, nombre_tipo_entidad)
VALUES 
(1, 'Bancos Comerciales'),
(4, 'Compañías de Financiamiento'),
(32, 'Cooperativas Financieras'),
(118, 'Redes de Procesamiento, Pagos y Servicios');


-- 2.2 DIMENSIÓN: NOMBRE DE ENTIDAD (Generación de Llave Subrogada)
CREATE TABLE datos_tarjetas.dim_nombre_entidad AS
SELECT DISTINCT "NOMBREENTIDAD" AS nombre_entidad
FROM datos_tarjetas.fact_tarjetas_credito_debito
ORDER BY nombre_entidad ASC;

ALTER TABLE datos_tarjetas.dim_nombre_entidad 
ADD COLUMN id_nombre_identidad SERIAL PRIMARY KEY;


-- 2.3 DIMENSIÓN: UCA (Unidad de Captura)
CREATE TABLE datos_tarjetas.dim_uca AS
SELECT DISTINCT "COD_UCA" AS cod_uca, "NOMBRE_UCA" AS nombre_uca
FROM datos_tarjetas.fact_tarjetas_credito_debito;

-- 2.3.1 Normalización de nombre del atributo "COD_UCA"
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito RENAME COLUMN "COD_UCA" TO cod_uca;

-- Limpieza en Hechos tras aislar la dimensión UCA
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito DROP COLUMN "NOMBRE_UCA";


-- 2.4 DIMENSIÓN: CONCEPTO (Estructurada a partir del atributo Subcuenta)
CREATE TABLE datos_tarjetas.dim_concepto (
    id_concepto INT PRIMARY KEY,
    descripcion_concepto VARCHAR(255) NOT NULL
);

INSERT INTO datos_tarjetas.dim_concepto (id_concepto, descripcion_concepto) VALUES
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
CREATE TABLE datos_tarjetas.dim_descr_detallada AS
SELECT DISTINCT "DESCRIPCION" AS descripcion 
FROM datos_tarjetas.fact_tarjetas_credito_debito;

ALTER TABLE datos_tarjetas.dim_descr_detallada 
ADD COLUMN id_descr_detallada SERIAL PRIMARY KEY;


-- ==============================================================================
-- 3. INDEXACIÓN DE LLAVES FORÁNEAS EN LA TABLA DE HECHOS (REEMPLAZO DE TEXTO A ID)
-- ==============================================================================

-- 3.1 Vinculación con dim_nombre_entidad
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito ADD COLUMN id_nombre_identidad INT;

UPDATE datos_tarjetas.fact_tarjetas_credito_debito ftcd 
SET id_nombre_identidad = dne.id_nombre_identidad
FROM datos_tarjetas.dim_nombre_entidad dne
WHERE dne.nombre_entidad = ftcd."NOMBREENTIDAD";

ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito DROP COLUMN "NOMBREENTIDAD";


-- 3.2 Vinculación con dim_concepto (Reemplazo del campo subcuenta)
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito RENAME COLUMN "SUBCUENTA" TO id_concepto;


-- 3.3 Vinculación con dim_descr_detallada
ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito ADD COLUMN id_descr_detallada INT;

UPDATE datos_tarjetas.fact_tarjetas_credito_debito ftcd 
SET id_descr_detallada = ddd.id_descr_detallada
FROM datos_tarjetas.dim_descr_detallada ddd
WHERE ftcd."DESCRIPCION" = ddd.descripcion;

ALTER TABLE datos_tarjetas.fact_tarjetas_credito_debito DROP COLUMN "DESCRIPCION";


-- ==============================================================================
-- 4. CONSULTAS DE CONTROL Y AUDITORÍA (SOLO PARA VERIFICACIÓN ANTES DE BI)
-- ==============================================================================

-- Control de integridad del modelo estrella
SELECT * 
FROM datos_tarjetas.fact_tarjetas_credito_debito 
LIMIT 10;