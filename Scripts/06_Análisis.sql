-- (((((ANTENCION))))) Todo el análisis que se encuentra aquí está basado en la última fecha de corte consultada (12 de julio de 2026)

/* 
================================================================================
  GLOSARIO DE ABREVIATURAS Y NOMENCLATURA DE VARIABLES
================================================================================
  PCT / %       = Porcentaje.
  FTCD          = Tabla de hechos: Fact Tarjetas de Crédito y Débito.
  DNE           = Tabla de dimensión: Nombre de Entidad (Bancos / Financieras).
  DD            = Tabla de dimensión: Descripción de conceptos financieros.
  DU            = Tabla de dimensión: Unidad / Unidad de Cuenta / Franquicia.
  UCA           = Unidad de Comercialización / Administración (Franquicia).
  COD           = Código único de identificación.
  ID            = Identificador único numérico en la base de datos.
  TOP / POS     = Posición o ranking dentro del ordenamiento (Posición Top).
  IR            = Índice de Riesgo.
  DC            = Deterioro de Cartera.
  MAX           = Valor Máximo acumulado o total.
  X             = "Por" o "A nivel de" (ej. X_ENTIDAD = Por Entidad).
================================================================================
*/


-- 1. Top 5 bancos con más cartera de la última fecha de corte del 2026
SELECT 
    DENSE_RANK() OVER (ORDER BY SUM(ftcd.valor) DESC) AS pos_top,
    dne.nombre_entidad,
    dd.descripcion,
    SUM(ftcd.valor) AS total_cartera 
FROM datos_tarjetas.fact_tarjetas_credito_debito AS ftcd 
JOIN datos_tarjetas.dim_nombre_entidad AS dne 
    ON dne.id_nombre_identidad = ftcd.id_nombre_identidad
JOIN datos_tarjetas.dim_descripcion AS dd 
    ON dd.id_descripcion = ftcd.id_descripcion 
WHERE dd.id_descripcion = 60 
  AND ftcd.id_fecha = 20260712
GROUP BY 
    dne.nombre_entidad,
    dd.descripcion
ORDER BY total_cartera DESC
LIMIT 5;

					-- (((((((( ATENCION EJECUTAR EL SIGUIENTE CÓDIGO SOLO SI NO SE HA CREADO LA VISTA))))))))
-- 2. Índice de riesgo y montos (Vista Materializada) 
/*CREATE MATERIALIZED VIEW IndiceDeRiesgo AS
WITH indice_riesgo AS (
    SELECT 
        dne.nombre_entidad,
        du.nombre_uca,
        SUM(CASE WHEN ftcd.id_descripcion = 60 THEN ftcd.valor ELSE 0 END)::FLOAT AS total_cartera,
        SUM(SUM(CASE WHEN ftcd.id_descripcion = 60 THEN ftcd.valor ELSE 0 END)) OVER (PARTITION BY dne.nombre_entidad) AS max_cartera,
        SUM(CASE WHEN ftcd.id_descripcion = 22 THEN ftcd.valor ELSE 0 END) AS intereses_demora,
        SUM(CASE WHEN ftcd.id_descripcion = 20 THEN ftcd.valor ELSE 0 END) AS castigo_capital,
        SUM(CASE WHEN ftcd.id_descripcion = 19 THEN ftcd.valor ELSE 0 END) AS castigo_otros
    FROM datos_tarjetas.fact_tarjetas_credito_debito AS ftcd 
    JOIN datos_tarjetas.dim_nombre_entidad AS dne 
        ON dne.id_nombre_identidad = ftcd.id_nombre_identidad
    JOIN datos_tarjetas.dim_descripcion AS dd 
        ON dd.id_descripcion = ftcd.id_descripcion
    JOIN datos_tarjetas.dim_uca AS du
        ON du.cod_uca = ftcd.cod_uca 
    WHERE ftcd.id_fecha = 20260712
      AND ftcd.id_descripcion IN (60, 22, 20, 19)
    GROUP BY 
        dne.nombre_entidad,
        du.nombre_uca
),
deterioro_cartera AS (
    SELECT 
        nombre_entidad AS entidad,
        nombre_uca AS franquicia,
        total_cartera,
        (castigo_capital + intereses_demora + castigo_otros)::FLOAT AS deterioro,
        SUM((castigo_capital + intereses_demora + castigo_otros)::FLOAT) OVER (PARTITION BY nombre_entidad) AS deterioro_total_x_entidad,
        SUM((castigo_capital + intereses_demora + castigo_otros)::FLOAT) OVER (PARTITION BY nombre_uca) AS deterioro_total_x_franquicia
    FROM indice_riesgo
)
SELECT 
    dc.entidad,
    dc.franquicia,
    ROUND(ir.total_cartera::NUMERIC, 2) AS total_cartera,
    ir.intereses_demora,
    ir.castigo_capital,
    ir.castigo_otros,
    dc.deterioro,
    dc.deterioro_total_x_entidad,
    dc.deterioro_total_x_franquicia,
    ROUND(((dc.deterioro / NULLIF(ir.total_cartera, 0)) * 100)::NUMERIC, 2) AS pct_indice_riesgo,
    ROUND(
        (SUM(dc.deterioro) OVER (PARTITION BY dc.entidad) / 
         NULLIF(SUM(ir.total_cartera) OVER (PARTITION BY dc.entidad), 0) * 100)::NUMERIC, 3
    ) AS pct_indice_riesgo_x_entidad,
    ROUND(
        (SUM(dc.deterioro) OVER (PARTITION BY dc.franquicia) / 
         NULLIF(SUM(ir.total_cartera) OVER (PARTITION BY dc.franquicia), 0) * 100)::NUMERIC, 3
    ) AS pct_indice_riesgo_x_franquicia
FROM deterioro_cartera AS dc
JOIN indice_riesgo AS ir 
    ON dc.entidad = ir.nombre_entidad 
   AND dc.franquicia = ir.nombre_uca
ORDER BY pct_indice_riesgo DESC;*/

-- DROP MATERIALIZED VIEW IF EXISTS IndiceDeRiesgo; -- Solo usar para actualizar la vista materializada

SELECT *
FROM IndiceDeRiesgo;


-- 3. Top 5 índice de riesgo por franquicias
WITH ranking_franquicias AS (
    SELECT DISTINCT 
        franquicia,
        pct_indice_riesgo_x_franquicia
    FROM IndiceDeRiesgo
    ORDER BY pct_indice_riesgo_x_franquicia DESC
    LIMIT 5
)
SELECT 
    RANK() OVER (ORDER BY pct_indice_riesgo_x_franquicia DESC) AS pos_ranking, 
    franquicia,
    pct_indice_riesgo_x_franquicia
FROM ranking_franquicias;


-- 4. Montos globales 
WITH montos_globales AS (
    SELECT 
        SUM(total_cartera) AS total_cartera,
        ROUND(SUM(deterioro)::NUMERIC, 2) AS monto_indice_riesgo,
        SUM(castigo_otros) AS monto_castigo_otros,		
        SUM(intereses_demora) AS monto_mora,
        SUM(castigo_capital) AS monto_castigo_capital
    FROM IndiceDeRiesgo
)
SELECT *
FROM montos_globales;


-- 5. Porcentaje de castigos e intereses de mora que componen el índice de riesgo global (Salud de la cartera)
WITH salud_cartera_global AS (
    SELECT
        ROUND((SUM(deterioro) / SUM(total_cartera))::NUMERIC * 100, 3) AS indice_riesgo_global,
        ROUND((SUM(castigo_otros) / SUM(deterioro))::NUMERIC * 100, 3) AS pct_castigo_otros_x_indice_riesgo,	
        ROUND((SUM(intereses_demora) / SUM(deterioro))::NUMERIC * 100, 3) AS pct_mora_x_indice_riesgo,
        ROUND((SUM(castigo_capital) / SUM(deterioro))::NUMERIC * 100, 3) AS pct_castigo_capital_x_indice_riesgo
    FROM IndiceDeRiesgo
)
SELECT *
FROM salud_cartera_global;


-- 6. Porcentaje de castigos e intereses de mora por Entidad y Franquicia
WITH salud_cartera_detalle AS (
    SELECT
        entidad,
        franquicia,
        ROUND((deterioro / total_cartera)::NUMERIC * 100, 3) AS indice_riesgo,
        ROUND((castigo_otros / deterioro)::NUMERIC * 100, 3) AS pct_castigo_otros_x_indice_riesgo,	
        ROUND((intereses_demora / deterioro)::NUMERIC * 100, 3) AS pct_mora_x_indice_riesgo,
        ROUND((castigo_capital / deterioro)::NUMERIC * 100, 3) AS pct_castigo_capital_x_indice_riesgo
    FROM IndiceDeRiesgo
)
SELECT *
FROM salud_cartera_detalle;








