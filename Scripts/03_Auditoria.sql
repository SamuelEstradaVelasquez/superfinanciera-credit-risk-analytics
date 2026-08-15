-- Auditoría: Último mes y día de corte del 2026
SELECT 
    dne.nombre_entidad,
    du.nombre_uca,
    ftcd.id_fecha,
    ftcd.persona_natural,
    ftcd.persona_juridica,
    dd.descripcion,
    ftcd.valor
FROM datos_tarjetas.fact_tarjetas_credito_debito AS ftcd 
JOIN datos_tarjetas.dim_descripcion AS dd 
    ON dd.id_descripcion = ftcd.id_descripcion
JOIN datos_tarjetas.dim_nombre_entidad AS dne 
    ON dne.id_nombre_identidad = ftcd.id_nombre_identidad
JOIN datos_tarjetas.dim_uca AS du 
    ON du.cod_uca = ftcd.cod_uca 
WHERE dd.descripcion LIKE '%cartera%' 
  AND ftcd.id_fecha = 20260712
ORDER BY ftcd.valor DESC;


-- Auditoría: Días únicos de fechas de corte en la dimensión de fechas
SELECT DISTINCT 
    df.dia_num 
FROM datos_tarjetas.dim_fecha AS df
ORDER BY df.dia_num ASC;


-- Auditoría: Total cartera al 12 de julio de 2026 (Agrupado por descripción)
SELECT 
    dd.descripcion,
    SUM(ftcd.valor) AS total_valor
FROM datos_tarjetas.fact_tarjetas_credito_debito AS ftcd 
JOIN datos_tarjetas.dim_descripcion AS dd 
    ON dd.id_descripcion = ftcd.id_descripcion 
JOIN datos_tarjetas.dim_fecha AS df 
    ON df.id_fecha = ftcd.id_fecha
WHERE dd.descripcion LIKE '%Saldo%' 
  AND df.id_fecha = 20260712
GROUP BY dd.descripcion;


-- Auditoría a Bancolombia: Total de cartera al 12 de julio de 2026
SELECT 
    dd.descripcion,
    SUM(ftcd.valor) AS total_valor
FROM datos_tarjetas.fact_tarjetas_credito_debito AS ftcd 
JOIN datos_tarjetas.dim_descripcion AS dd 
    ON dd.id_descripcion = ftcd.id_descripcion 
JOIN datos_tarjetas.dim_fecha AS df 
    ON df.id_fecha = ftcd.id_fecha
JOIN datos_tarjetas.dim_nombre_entidad AS dne 
    ON dne.id_nombre_identidad = ftcd.id_nombre_identidad
WHERE dne.id_nombre_identidad = 28 
  AND dd.descripcion LIKE '%Saldo%' 
  AND df.id_fecha = 20260712
GROUP BY dd.descripcion;