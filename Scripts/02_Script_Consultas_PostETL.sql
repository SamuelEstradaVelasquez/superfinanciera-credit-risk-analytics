/*
================================================================================
  GLOSARIO DE ABREVIATURAS Y NOMENCLATURA
================================================================================
  PCT / %       = Porcentaje.
  FTCD          = Tabla de hechos: Fact Tarjetas de Crédito y Débito.
  DNE           = Tabla de dimensión: Nombre de Entidad (Bancos / Financieras).
  DD / DDD      = Tabla de dimensión: Descripción / Descripción Detallada.
  DU / UCA      = Tabla de dimensión: Unidad / Franquicia (Visa, Mastercard, etc.).
  DC            = Tabla de dimensión: Concepto / Deterioro de Cartera.
  DM            = Tabla de dimensión: Métrica.
  DF            = Tabla de dimensión: Fecha.
  ID / COD      = Identificador numérico / Código clave.
  TDCYD         = Tabla de staging/backup: Tarjetas de Crédito y Débito.
  
------------------------------------------------================----------------
  NOTA SOBRE LA EVOLUCIÓN DEL MODELO (CAMBIOS POST-ETL)
------------------------------------------------================----------------
  Dado que este script es de carácter exploratorio (Pre-ETL / Profiling), varios
  nombres de entidades y atributos corresponden a la estructura inicial y fueron
  renombrados o reestructurados en el modelo dimensional definitivo:
  
  * dim_descr_detallada / dim_concepto -> Se unificó en: dim_descripcion
  * dim_fecha                         -> Evolucionó a: dim_tiempo
  * total_tarjetas (columna ambigua)  -> Se dividió en: monto_total / cantidad_tarjetas
  * id_nombre_identidad               -> Corregido a: id_nombre_entidad
================================================================================
*/


-- OBJETIVO: Consulta de diagnóstico para auditar la naturaleza de las métricas según su descripción.
-- HALLAZGO: Se detectó una inconsistencia de diseño en origen (sobrecarga semántica): una sola columna 
-- ('total_tarjetas') mezcla contextos de 'Monto' y 'Cantidad' según el ID consultado.
-- ACCIÓN ETL: Para corregir esta estructura, se crearán dos columnas de destino independientes: 
-- 'monto_total' y 'cantidad_tarjetas'.

--================================================================================
-- Consulta cualquier descripción
-- Consulta del ID de cada descripción
SELECT *
FROM datos_tarjetas.dim_descripcion;
-- Datos por descripción
SELECT 
    dne.nombre_entidad,
    du.nombre_uca,
    ddd.descripcion,
    ftcd.persona_juridica,
    ftcd.persona_natural,
    ftcd.valor
FROM datos_tarjetas.fact_tarjetas_credito_debito AS ftcd
JOIN datos_tarjetas.dim_descripcion AS ddd 
    ON ddd.id_descripcion = ftcd.id_descripcion
JOIN datos_tarjetas.dim_nombre_entidad AS dne  
    ON dne.id_nombre_identidad = ftcd.id_nombre_identidad 
JOIN datos_tarjetas.dim_uca AS du 
    ON du.cod_uca = ftcd.cod_uca 
WHERE ftcd.id_descripcion = 60 -- ID de descripción modificable para auditoría
LIMIT 10;


-- Consulta para la dimensión métrica: Verificación de descripciones para métricas de cantidad
SELECT *
FROM datos_tarjetas.dim_descripcion AS dc 
WHERE dc.descripcion IN (
    'Tarjetas vigentes a la fecha de corte',
    'Tarjetas vigentes durante el mes',
    'Tarjetas canceladas',
    'Tarjetas bloqueadas temporalmente',
    'Cantidad de tarjetas sin chip de seguridad',
    'Cantidad de tarjetas con tecnología sin contacto (Contactless)',
    'Cantidad de transacciones por compras nacionales',
    'Cantidad de transacciones por avances nacionales / retiros débito'
);


-- Auditoría: Comprobación de tipos de métrica cargados en la tabla de hechos
SELECT DISTINCT 
    ftcd.id_tipo_metrica 
FROM datos_tarjetas.fact_tarjetas_credito_debito AS ftcd;


-- Validación de registros por tipo de métrica (Monto vs Cantidad)
(SELECT 
    dc.descripcion,
    dm.tipo_metrica,
    ftcd.valor
FROM datos_tarjetas.fact_tarjetas_credito_debito AS ftcd
JOIN datos_tarjetas.dim_descripcion AS dc 
    ON dc.id_descripcion = ftcd.id_descripcion 
JOIN datos_tarjetas.dim_metrica AS dm  
    ON dm.id_tipo_metrica = ftcd.id_tipo_metrica 
WHERE ftcd.id_tipo_metrica = 2
LIMIT 10)
UNION ALL
(SELECT 
    dc.descripcion,
    dm.tipo_metrica,
    ftcd.valor
FROM datos_tarjetas.fact_tarjetas_credito_debito AS ftcd
JOIN datos_tarjetas.dim_descripcion AS dc 
    ON dc.id_descripcion = ftcd.id_descripcion 
JOIN datos_tarjetas.dim_metrica AS dm  
    ON dm.id_tipo_metrica = ftcd.id_tipo_metrica 
WHERE ftcd.id_tipo_metrica = 1
LIMIT 10);

-- Búsqueda de huérfanos (Llaves en hechos no existentes en dimensión)
SELECT DISTINCT 
    ftcd.id_descripcion  
FROM datos_tarjetas.fact_tarjetas_credito_debito AS ftcd
LEFT JOIN datos_tarjetas.dim_descripcion AS dc 
    ON dc.id_descripcion  = ftcd.id_descripcion 
WHERE dc.id_descripcion  IS NULL;

-- Consulta de control a la fuente original (Backup staging)
SELECT DISTINCT 
    "SUBCUENTA",
    "DESCRIPCION"
FROM datos_originales.tarjetas_de_crédito_y_débito AS tdcyd
ORDER BY "SUBCUENTA" ASC;

-- CONCLUSIÓN: La dimensión descr_detallada satisface su propia dimensión y la de concepto,
-- además de ser la descripción original. Se procede a eliminar la dimensión concepto y su 
-- atributo en la tabla de hechos por redundancia. Cambiaremos el nombre de descr_detallada a 'descripcion'.
-- La solución completa se ejecuta en Script_Segundo_ETL.sql.


-- -----------------------------------------------------------------------------
-- CONSULTAS PARA CONSTRUCCIÓN Y VALIDACIÓN DE LA DIMENSIÓN FECHA (dim_tiempo)
-- -----------------------------------------------------------------------------

-- Fechas únicas en fact
/*SELECT DISTINCT 
    ftcd.fecha_corte  -> Esta se utilizo antes de la creación de su dimension por eso es ambiguia
FROM datos_tarjetas.fact_tarjetas_credito_debito AS ftcd;*/

-- Generación de clave surrogate (ID entero YYYYMMDD)
SELECT 
    TO_CHAR(fecha_corte, 'YYYYMMDD')::INT AS fecha_numerica
FROM datos_tarjetas.dim_fecha AS df;

-- Extracción de día
SELECT 
    EXTRACT(DAY FROM fecha_corte) AS dia_num
FROM datos_tarjetas.dim_fecha AS df;

-- Mapeo de días de la semana en español
SELECT 
    df.fecha_corte,
    CASE EXTRACT(DOW FROM df.fecha_corte)
        WHEN 1 THEN 'lunes'
        WHEN 2 THEN 'martes'
        WHEN 3 THEN 'miércoles'
        WHEN 4 THEN 'jueves'
        WHEN 5 THEN 'viernes'
        WHEN 6 THEN 'sábado'
        WHEN 0 THEN 'domingo'
    END AS dia_nombre
FROM datos_tarjetas.dim_fecha AS df;

-- Mapeo de meses en español

-- @name: Ventas por Año
SELECT 
    df.mes_num,
    CASE df.mes_num
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
    END AS mes_nombre
FROM datos_tarjetas.dim_fecha AS df;


































