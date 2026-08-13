# superfinanciera-credit-risk-analytics
Análisis de riesgo de crédito y dashboard interactivo de la cartera bancaria con datos oficiales de la Superintendencia Financiera de Colombia.

---

## 💡 Filosofía del Proyecto, Lecciones Aprendidas y Enfoque Técnico

### 🔄 Del Descubrimiento a la Refactorización (v1 vs. v2)
Este proyecto fue diseñado con el objetivo de abordar un dataset del mundo real (Superintendencia Financiera de Colombia) no como un ejercicio estático de consulta, sino como un **ciclo de ingeniería iterativo**:

1. **Modelado Inicial (v1):** En la primera fase se estructuraron las entidades relacionales básicas. Sin embargo, al ejecutar consultas de auditoría (*Data Profiling*), se detectaron problemas críticos en la fuente original, como la **sobrecarga semántica** en métricas (mezcla de montos financieros `$` con cantidades físicas `#`) y riesgo de llaves huérfanas en dimensiones cualitativas.
2. **Refactorización en Estrella (v2):** En lugar de aplicar parches superficiales, se tomó la decisión de rediseñar la arquitectura. Se implementó una dimensión de métrica (`dim_metrica`) para desambiguar cálculos, se unificaron descripciones redundantes y se adoptó una clave *surrogate* temporal entera (`YYYYMMDD`) en `dim_fecha` para optimizar el rendimiento de agregación y garantizar la integridad referencial en Power BI.

### 🛠️ Decisiones Técnicas
* **SQL Nativo en PostgreSQL:** Se priorizó el desarrollo de transformaciones completamente dentro del motor de base de datos para maximizar la eficiencia de las consultas, aplicar restricciones de integridad referencial explícitas (`FOREIGN KEYS`) y construir Vistas Materializadas optimizadas para consumo analítico.

### 🎯 Conclusiones del Proyecto y Siguiente Paso
Este repositorio cumple el objetivo de consolidar bases sólidas en **Modelado Dimensional (Kimball), Diseño de Bases de Datos Relacionales y Auditoría de Calidad de Datos (Data Profiling)** utilizando SQL nativo. 

Habiendo dominado la estructuración y limpieza profunda de datos a nivel de base de datos, el siguiente hito en mi ruta de aprendizaje es la integración de **Python** para la automatización de pipelines y la ingesta programática en mis próximos proyectos.

---

# 💳 Analítica e Ingeniería de Datos: Tarjetas de Crédito y Débito (SFC)

## 📌 Resumen del Proyecto

Este proyecto aborda el diseño, limpieza, reestructuración y auditoría de datos del sector financiero colombiano (fuente: *Superintendencia Financiera de Colombia - SFC*).

A través de un ciclo de ingeniería de datos iterativo, se transformó una estructura relacional rígida y con sobrecarga semántica en un **Modelo Dimensional en Estrella (Star Schema)** optimizado para consumo en inteligencia de negocios (Power BI). El pipeline garantiza la integridad referencial, elimina redundancias de granularidad y normaliza las métricas financieras para el análisis de riesgo de cartera.

---

## 🏗️ Arquitectura y Flujo del Pipeline (ETL)

El ciclo de desarrollo está organizado en cuatro fases secuenciales dentro de la carpeta `/scripts`:

```
┌─────────────────┐      ┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  01_primer_etl  │ ───► │ 02_pre_etl_prof  │ ───► │ 02_segundo_etl   │ ───► │  03_consultas    │
│  &_modelado.sql │      │  _diagnostico.sql│      │  _refactor.sql   │      │  _negocio.sql    │
└─────────────────┘      └──────────────────┘      └──────────────────┘      └──────────────────┘
   Modelo Estrella         Auditoría & Lossless      Reestructuración          Métricas & Vista
   Inicial (v1)            Data Discovery            Modelado Final (v2)       Materializada

```

### 📋 Descripción de los Scripts

1. **`01_primer_etl_y_modelado_inicial.sql`**:
* Aislamiento de entidades cualitativas (`dim_tipo_entidad`, `dim_nombre_entidad`, `dim_uca`, `dim_concepto`, `dim_descr_detallada`).
* Reemplazo de texto descriptivo por claves surrogate numéricas (`SERIAL PRIMARY KEY`).
* Normalización de atributos de la fuente original.


2. **`02_pre_etl_profiling_y_diagnostico.sql`** *(Script de Auditoría Histórica)*:
* Pruebas de pérdida de datos (*Lossless Data Check*) y consultas `LEFT JOIN ... IS NULL` para detectar llaves huérfanas.
* **Hallazgo Clave:** Sobrecarga semántica en el atributo `total_tarjetas` y redundancia entre `dim_concepto` y `dim_descr_detallada`.


3. **`02_segundo_etl_y_refactorizacion.sql`**:
* Creación de la dimensión `dim_metrica` para desambiguar montos financieros de conteos físicos.
* Deprecación de `dim_concepto` y refactorización a `dim_descripcion`.
* Construcción de la dimensión de tiempo `dim_fecha` con surrogate clave `YYYYMMDD` y atributos temporales derivados (`dia_name`, `mes_name`, `final_mes`).


4. **`03_consultas_negocio_y_vista_materializada.sql`**:
* Creación de la vista materializada `IndiceDeRiesgo` con cálculos de deterioro de cartera por entidad y franquicia.
* Consultas de concentración de mercado (Top 5 bancos) y salud financiera global.



---

## 🔎 Hallazgos de Calidad de Datos y Soluciones

| Problema Detectado en Origen | Impacto en Negocio / BI | Solución Implementada en SQL |
| --- | --- | --- |
| **Sobrecarga Semántica:** La columna `total_tarjetas` agrupaba tanto montos ($) como cantidades (#). | Inconsistencia en gráficos de agregación en Power BI. | Creación de `dim_metrica` y separación del campo en `valor` clasificado por `id_tipo_metrica`. |
| **Pérdida de Granularidad:** Atributos huérfanos entre subcuentas y descripciones de tarjetas. | Celdas en blanco `(Blank)` en tarjetas visuales de Power BI. | Unificación de dimensiones redundantes en `dim_descripcion` basada en los registros originales. |
| **Estructura de Fechas Ineficiente:** Uso de campos `DATE` naturales en la tabla de hechos. | Consultas lentas y falta de inteligencia de tiempo en análisis acumulados. | Creación de clave Surrogate entera (`YYYYMMDD`) mediante `TO_CHAR` y extracción de componentes de fecha en `dim_fecha`. |

---

## 🗂️ Modelo Dimensional Final (Star Schema)

El modelo final optimizado consta de las siguientes tablas:

* **`fact_tarjetas_credito_debito` (Tabla de Hechos)**
* `id_nombre_entidad` (FK)
* `cod_uca` (FK - Franquicia)
* `id_descripcion` (FK)
* `id_tipo_metrica` (FK)
* `id_fecha` (FK - Formato YYYYMMDD)
* `persona_natural` (NUMERIC)
* `persona_juridica` (NUMERIC)
* `valor` (NUMERIC)


* **Tablas de Dimensiones:** `dim_nombre_entidad`, `dim_tipo_entidad`, `dim_uca`, `dim_descripcion`, `dim_metrica`, `dim_fecha`.

---

## 📖 Glosario de Nomenclatura

Para facilitar la lectura del código y el mantenimiento del repositorio:

* **`FTCD`**: `fact_tarjetas_credito_debito` (Tabla de Hechos principal).
* **`DNE`**: `dim_nombre_entidad` (Bancos y entidades financieras).
* **`DU` / `UCA**`: `dim_uca` (Unidad de comercialización/franquicia: Visa, Mastercard, etc.).
* **`PCT` / `%**`: Porcentaje calculado.
* **`IR`**: Índice de Riesgo de Cartera.
* **`DC`**: Deterioro de Cartera (Suma de moras y castigos).

---

## 🚀 Instrucciones de Ejecución

Para replicar la base de datos localmente:

1. Importar el dataset crudo en la base de datos PostgreSQL en la tabla `datos_originales.tarjetas_de_crédito_y_débito`.
2. Ejecutar los scripts en el orden estricto de la carpeta `/scripts`:
```bash
psql -d mi_base_datos -f scripts/01_primer_etl_y_modelado_inicial.sql
psql -d mi_base_datos -f scripts/02_segundo_etl_y_refactorizacion.sql
psql -d mi_base_datos -f scripts/03_consultas_negocio_y_vista_materializada.sql

```


3. Consultar la vista final creada:
```sql
SELECT * FROM IndiceDeRiesgo LIMIT 10;

```

## 🌐 Fuente de Datos y Descarga (Data Source)

Los datos crudos utilizados en este proyecto provienen del portal oficial de Datos Abiertos del Gobierno de Colombia, suministrados por la **Superintendencia Financiera de Colombia (SFC)**.

* **Dataset Oficial:** [Tarjetas de crédito y débito - Datos Abiertos Colombia](https://www.datos.gov.co/Econom-a-y-Finanzas/Tarjetas-de-cr-dito-y-d-bito/h2jg-r3zg/about_data)
* **Entidad Emisora:** Superintendencia Financiera de Colombia - SUPERFINANCIERA.
* **Categoría:** Economía y Finanzas.

---

### 📥 Instrucciones para Descargar el Dataset Crudo

Para replicar el pipeline de datos localmente desde la base original:

1. Ingresa al portal oficial mediante el siguiente enlace: [Abrir Dataset en Datos.gov.co](https://www.datos.gov.co/Econom-a-y-Finanzas/Tarjetas-de-cr-dito-y-d-bito/h2jg-r3zg/about_data).
2. En la parte superior derecha de la interfaz del portal, ubica y haz clic en el botón **Exportar**.
3. En el menú desplegable, selecciona la opción **CSV** para descargar la base de datos completa.
4. Guarda el archivo descargado en la carpeta local de tu proyecto para iniciar la ejecución de los scripts de ingesta en PostgreSQL.

![Exportar datos CSV desde Datos.gov.co]

```
---
