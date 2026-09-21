-- 25 CONSULTAS SQL AVANZADAS


-- 1. ORGANIZACION CON MAYOR CANTIDAD DE PERSONAS
-- Se cuentan las personas por empresa, se ordena de mayor a menor
-- y LIMIT 1 devuelve solamente la primera.

SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    COUNT(p.person_id) AS cantidad_personas
FROM tenants t
LEFT JOIN persons p
    ON t.tenant_id = p.tenant_id
GROUP BY t.tenant_id, t.legal_name
ORDER BY cantidad_personas DESC
LIMIT 1;



-- 2. ORGANIZACIONES CON MAS PERSONAS QUE EL PROMEDIO
-- Primero el CTE calcula cuantas personas tiene cada empresa.
-- Luego se compara cada resultado con el promedio general.

WITH personas_por_organizacion AS (
    SELECT
        t.tenant_id,
        t.legal_name AS organizacion,
        COUNT(p.person_id) AS cantidad_personas
    FROM tenants t
    LEFT JOIN persons p
        ON t.tenant_id = p.tenant_id
    GROUP BY t.tenant_id, t.legal_name
)
SELECT
    tenant_id,
    organizacion,
    cantidad_personas
FROM personas_por_organizacion
WHERE cantidad_personas > (
    SELECT AVG(cantidad_personas)
    FROM personas_por_organizacion
)
ORDER BY cantidad_personas DESC;


-- 3. ORGANIZACIONES QUE TIENEN TODOS LOS MODULOS DE UN SISTEMA
-- En este ejemplo se consulta el sistema SST.
-- Para consultar PESV cambia 'SST' por 'PESV'.
-- HAVING compara los modulos que tiene la empresa contra
-- la cantidad total de modulos existentes para ese sistema.

SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    COUNT(DISTINCT tm.module_id) AS modulos_habilitados
FROM tenants t
INNER JOIN tenant_modules tm
    ON t.tenant_id = tm.tenant_id
   AND tm.is_active = TRUE
INNER JOIN modules m
    ON tm.module_id = m.module_id
INNER JOIN type_system_sst s
    ON m.system_id = s.system_id
WHERE s.code = 'SST'
  AND m.is_active = TRUE
GROUP BY t.tenant_id, t.legal_name
HAVING COUNT(DISTINCT tm.module_id) = (
    SELECT COUNT(*)
    FROM modules m2
    INNER JOIN type_system_sst s2
        ON m2.system_id = s2.system_id
    WHERE s2.code = 'SST'
      AND m2.is_active = TRUE
)
ORDER BY t.legal_name;


-- 4. ORGANIZACIONES CON MODULOS PERO SIN PLANTILLAS
-- EXISTS verifica que tenga al menos un modulo.
-- NOT EXISTS verifica que no tenga plantillas asignadas.

SELECT
    t.tenant_id,
    t.legal_name AS organizacion
FROM tenants t
WHERE EXISTS (
    SELECT 1
    FROM tenant_modules tm
    WHERE tm.tenant_id = t.tenant_id
      AND tm.is_active = TRUE
)
AND NOT EXISTS (
    SELECT 1
    FROM tenanttemplates tt
    WHERE tt.tenant_id = t.tenant_id
)
ORDER BY t.legal_name;


-- 5. ORGANIZACIONES CON PLANTILLAS EN TODAS LAS ETAPAS PHVA
-- Se cuenta cuantas etapas diferentes tiene cada empresa.
-- Debe ser igual al total de etapas existentes en phva_stages.

SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    COUNT(DISTINCT tt.phva_stage_id) AS etapas_configuradas
FROM tenants t
INNER JOIN tenanttemplates tt
    ON t.tenant_id = tt.tenant_id
GROUP BY t.tenant_id, t.legal_name
HAVING COUNT(DISTINCT tt.phva_stage_id) = (
    SELECT COUNT(*)
    FROM phva_stages
)
ORDER BY t.legal_name;


-- 6. CANTIDAD DE PLANTILLAS POR ORGANIZACION Y ETAPA PHVA
-- CROSS JOIN genera las cuatro etapas para cada empresa.
-- LEFT JOIN permite mostrar 0 cuando no haya plantillas.

SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    ph.code AS codigo_phva,
    ph.name AS etapa_phva,
    COUNT(tt.tenant_template_id) AS cantidad_plantillas
FROM tenants t
CROSS JOIN phva_stages ph
LEFT JOIN tenanttemplates tt
    ON tt.tenant_id = t.tenant_id
   AND tt.phva_stage_id = ph.phva_stage_id
GROUP BY
    t.tenant_id,
    t.legal_name,
    ph.phva_stage_id,
    ph.code,
    ph.name,
    ph.display_order
ORDER BY t.legal_name, ph.display_order;


-- 7. PHVA EN COLUMNAS: PLANEAR, HACER, VERIFICAR Y ACTUAR
-- FILTER permite contar solamente la etapa indicada.

SELECT
    t.tenant_id,
    t.legal_name AS organizacion,

    COUNT(tt.tenant_template_id)
        FILTER (WHERE ph.code = 'PLAN') AS planear,

    COUNT(tt.tenant_template_id)
        FILTER (WHERE ph.code = 'DO') AS hacer,

    COUNT(tt.tenant_template_id)
        FILTER (WHERE ph.code = 'CHECK') AS verificar,

    COUNT(tt.tenant_template_id)
        FILTER (WHERE ph.code = 'ACT') AS actuar

FROM tenants t
LEFT JOIN tenanttemplates tt
    ON t.tenant_id = tt.tenant_id
LEFT JOIN phva_stages ph
    ON tt.phva_stage_id = ph.phva_stage_id
GROUP BY t.tenant_id, t.legal_name
ORDER BY t.legal_name;


-- 8. PORCENTAJE DE CADA ETAPA PHVA DENTRO DE UNA ORGANIZACION
-- El CTE obtiene primero el total de plantillas por empresa.
-- Luego cada etapa se divide entre ese total.

WITH total_plantillas AS (
    SELECT
        tenant_id,
        COUNT(*) AS total
    FROM tenanttemplates
    GROUP BY tenant_id
)
SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    ph.name AS etapa_phva,
    COUNT(tt.tenant_template_id) AS cantidad_plantillas,
    ROUND(
        COUNT(tt.tenant_template_id) * 100.0 / tp.total,
        2
    ) AS porcentaje
FROM tenants t
INNER JOIN total_plantillas tp
    ON t.tenant_id = tp.tenant_id
INNER JOIN tenanttemplates tt
    ON t.tenant_id = tt.tenant_id
INNER JOIN phva_stages ph
    ON tt.phva_stage_id = ph.phva_stage_id
GROUP BY
    t.tenant_id,
    t.legal_name,
    ph.phva_stage_id,
    ph.name,
    ph.display_order,
    tp.total
ORDER BY t.legal_name, ph.display_order;


-- 9. ETAPA PHVA CON MAS PLANTILLAS EN CADA ORGANIZACION
-- El primer CTE cuenta plantillas por etapa.
-- RANK ordena las etapas desde la mayor cantidad.
-- posicion = 1 representa la etapa con mayor cantidad.
-- Si hay empate, muestra todas las etapas empatadas.

WITH plantillas_por_etapa AS (
    SELECT
        t.tenant_id,
        t.legal_name AS organizacion,
        ph.name AS etapa_phva,
        COUNT(tt.tenant_template_id) AS cantidad_plantillas
    FROM tenants t
    INNER JOIN tenanttemplates tt
        ON t.tenant_id = tt.tenant_id
    INNER JOIN phva_stages ph
        ON tt.phva_stage_id = ph.phva_stage_id
    GROUP BY
        t.tenant_id,
        t.legal_name,
        ph.phva_stage_id,
        ph.name
),
ranking AS (
    SELECT
        *,
        RANK() OVER (
            PARTITION BY tenant_id
            ORDER BY cantidad_plantillas DESC
        ) AS posicion
    FROM plantillas_por_etapa
)
SELECT
    tenant_id,
    organizacion,
    etapa_phva,
    cantidad_plantillas
FROM ranking
WHERE posicion = 1
ORDER BY organizacion, etapa_phva;


-- 10. PORCENTAJE DE DOCUMENTOS FINALIZADOS POR ORGANIZACION
-- Se suman los documentos SST y PESV de las vistas materializadas.
-- El porcentaje se calcula con documentos finalizados / total.

SELECT
    sst.tenant_id,
    sst.organizacion,

    sst.total_documentos
        + pesv.total_documentos AS total_documentos,

    sst.documentos_finalizados
        + pesv.documentos_finalizados AS documentos_finalizados,

    ROUND(
        CASE
            WHEN sst.total_documentos + pesv.total_documentos = 0
            THEN 0
            ELSE
                (
                    sst.documentos_finalizados
                    + pesv.documentos_finalizados
                ) * 100.0
                /
                (
                    sst.total_documentos
                    + pesv.total_documentos
                )
        END,
        2
    ) AS porcentaje_cumplimiento

FROM vm_template_sst_docs_summary sst
INNER JOIN vm_template_pesv_docs_summary pesv
    ON sst.tenant_id = pesv.tenant_id
ORDER BY porcentaje_cumplimiento DESC;


-- 11. ORGANIZACIONES POR DEBAJO DEL PROMEDIO DE CUMPLIMIENTO
-- El CTE calcula primero el porcentaje de cada empresa.
-- Después se compara contra AVG, que calcula el promedio general.

WITH cumplimiento AS (
    SELECT
        sst.tenant_id,
        sst.organizacion,
        ROUND(
            CASE
                WHEN sst.total_documentos + pesv.total_documentos = 0
                THEN 0
                ELSE
                    (
                        sst.documentos_finalizados
                        + pesv.documentos_finalizados
                    ) * 100.0
                    /
                    (
                        sst.total_documentos
                        + pesv.total_documentos
                    )
            END,
            2
        ) AS porcentaje
    FROM vm_template_sst_docs_summary sst
    INNER JOIN vm_template_pesv_docs_summary pesv
        ON sst.tenant_id = pesv.tenant_id
)
SELECT
    tenant_id,
    organizacion,
    porcentaje
FROM cumplimiento
WHERE porcentaje < (
    SELECT AVG(porcentaje)
    FROM cumplimiento
)
ORDER BY porcentaje;


-- 12. CLASIFICAR ORGANIZACIONES POR NIVEL DE CUMPLIMIENTO
-- Criterio usado:
-- menor de 50  = Bajo
-- 50 a 79.99   = Medio
-- 80 o mas     = Alto

WITH cumplimiento AS (
    SELECT
        sst.tenant_id,
        sst.organizacion,
        ROUND(
            CASE
                WHEN sst.total_documentos + pesv.total_documentos = 0
                THEN 0
                ELSE
                    (
                        sst.documentos_finalizados
                        + pesv.documentos_finalizados
                    ) * 100.0
                    /
                    (
                        sst.total_documentos
                        + pesv.total_documentos
                    )
            END,
            2
        ) AS porcentaje
    FROM vm_template_sst_docs_summary sst
    INNER JOIN vm_template_pesv_docs_summary pesv
        ON sst.tenant_id = pesv.tenant_id
)
SELECT
    tenant_id,
    organizacion,
    porcentaje,
    CASE
        WHEN porcentaje < 50 THEN 'Bajo'
        WHEN porcentaje < 80 THEN 'Medio'
        ELSE 'Alto'
    END AS nivel_cumplimiento
FROM cumplimiento
ORDER BY porcentaje DESC;


-- 13. RANKING DE ORGANIZACIONES POR CUMPLIMIENTO
-- RANK asigna una posicion según el porcentaje obtenido.

WITH cumplimiento AS (
    SELECT
        sst.tenant_id,
        sst.organizacion,
        ROUND(
            CASE
                WHEN sst.total_documentos + pesv.total_documentos = 0
                THEN 0
                ELSE
                    (
                        sst.documentos_finalizados
                        + pesv.documentos_finalizados
                    ) * 100.0
                    /
                    (
                        sst.total_documentos
                        + pesv.total_documentos
                    )
            END,
            2
        ) AS porcentaje
    FROM vm_template_sst_docs_summary sst
    INNER JOIN vm_template_pesv_docs_summary pesv
        ON sst.tenant_id = pesv.tenant_id
)
SELECT
    tenant_id,
    organizacion,
    porcentaje,
    RANK() OVER (
        ORDER BY porcentaje DESC
    ) AS posicion
FROM cumplimiento
ORDER BY posicion, organizacion;



-- 14. CUMPLIMIENTO Y DIFERENCIA FRENTE AL PROMEDIO GENERAL
-- AVG(...) OVER () calcula el promedio sin perder las filas.
-- La resta muestra cuantos puntos esta cada empresa por encima
-- o por debajo del promedio.

WITH cumplimiento AS (
    SELECT
        sst.tenant_id,
        sst.organizacion,
        ROUND(
            CASE
                WHEN sst.total_documentos + pesv.total_documentos = 0
                THEN 0
                ELSE
                    (
                        sst.documentos_finalizados
                        + pesv.documentos_finalizados
                    ) * 100.0
                    /
                    (
                        sst.total_documentos
                        + pesv.total_documentos
                    )
            END,
            2
        ) AS porcentaje
    FROM vm_template_sst_docs_summary sst
    INNER JOIN vm_template_pesv_docs_summary pesv
        ON sst.tenant_id = pesv.tenant_id
)
SELECT
    tenant_id,
    organizacion,
    porcentaje,
    ROUND(AVG(porcentaje) OVER (), 2) AS promedio_general,
    ROUND(
        porcentaje - AVG(porcentaje) OVER (),
        2
    ) AS diferencia_promedio
FROM cumplimiento
ORDER BY porcentaje DESC;


-- 15. CANTIDAD ACUMULADA DE DOCUMENTOS FINALIZADOS
-- La funcion de ventana trabaja por separado para cada empresa.
-- Cada documento FINISHED suma 1 al acumulado de su organizacion.

SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    d.title AS documento,
    ds.name AS estado,
    d.updated_at,

    SUM(
        CASE
            WHEN ds.code = 'FINISHED' THEN 1
            ELSE 0
        END
    ) OVER (
        PARTITION BY t.tenant_id
        ORDER BY d.updated_at, d.document_id
    ) AS finalizados_acumulados

FROM tenants t
INNER JOIN tenanttemplates tt
    ON t.tenant_id = tt.tenant_id
INNER JOIN documents d
    ON tt.tenant_template_id = d.tenant_template_id
INNER JOIN document_statuses ds
    ON d.document_status_id = ds.document_status_id
ORDER BY t.legal_name, d.updated_at, d.document_id;


-- 16. ORGANIZACIONES DEL MISMO MUNICIPIO CON DIFERENTE TAMANO
-- La tabla tenants se usa dos veces.
-- t1.tenant_id < t2.tenant_id evita mostrar el mismo par dos veces.

SELECT
    m.name AS municipio,
    t1.legal_name AS organizacion_1,
    ts1.name AS tamano_1,
    t2.legal_name AS organizacion_2,
    ts2.name AS tamano_2
FROM tenants t1
INNER JOIN tenants t2
    ON t1.municipality_id = t2.municipality_id
   AND t1.tenant_id < t2.tenant_id
   AND t1.tenant_size_id <> t2.tenant_size_id
INNER JOIN municipalities m
    ON t1.municipality_id = m.municipality_id
INNER JOIN tenant_sizes ts1
    ON t1.tenant_size_id = ts1.tenant_size_id
INNER JOIN tenant_sizes ts2
    ON t2.tenant_size_id = ts2.tenant_size_id
ORDER BY municipio, organizacion_1;


-- 17. PERSONAS EN CARGOS CON OCUPACION SUPERIOR AL PROMEDIO
-- 1. cargo_ocupacion cuenta personas por cargo.
-- 2. promedio_ocupacion calcula el promedio dentro de cada empresa.
-- 3. Se muestran personas cuyo cargo supera ese promedio.

WITH cargo_ocupacion AS (
    SELECT
        pos.position_id,
        pos.tenant_id,
        pos.name AS cargo,
        COUNT(ppa.person_id) AS cantidad_personas
    FROM positions pos
    LEFT JOIN person_position_assignments ppa
        ON pos.position_id = ppa.position_id
       AND ppa.ended_at IS NULL
    GROUP BY
        pos.position_id,
        pos.tenant_id,
        pos.name
),
promedio_ocupacion AS (
    SELECT
        tenant_id,
        AVG(cantidad_personas) AS promedio
    FROM cargo_ocupacion
    GROUP BY tenant_id
)
SELECT
    t.legal_name AS organizacion,
    CONCAT(p.first_name, ' ', p.last_name) AS persona,
    co.cargo,
    co.cantidad_personas,
    ROUND(po.promedio, 2) AS promedio_cargos
FROM persons p
INNER JOIN tenants t
    ON p.tenant_id = t.tenant_id
INNER JOIN person_position_assignments ppa
    ON p.person_id = ppa.person_id
   AND ppa.ended_at IS NULL
INNER JOIN cargo_ocupacion co
    ON ppa.position_id = co.position_id
INNER JOIN promedio_ocupacion po
    ON co.tenant_id = po.tenant_id
WHERE co.cantidad_personas > po.promedio
ORDER BY t.legal_name, co.cargo, persona;


-- 18. CTE: EMPRESAS CON MAS PERSONAS QUE EL PROMEDIO
-- El ejercicio pide expresamente utilizar un CTE.

WITH cantidad_personas AS (
    SELECT
        t.tenant_id,
        t.legal_name AS organizacion,
        COUNT(p.person_id) AS total_personas
    FROM tenants t
    LEFT JOIN persons p
        ON t.tenant_id = p.tenant_id
    GROUP BY t.tenant_id, t.legal_name
)
SELECT
    tenant_id,
    organizacion,
    total_personas
FROM cantidad_personas
WHERE total_personas > (
    SELECT AVG(total_personas)
    FROM cantidad_personas
)
ORDER BY total_personas DESC;


-- 19. CTE: PERSONAS, MODULOS Y PLANTILLAS POR ORGANIZACION
-- Cada CTE cuenta una entidad por separado.
-- Esto evita multiplicar resultados al unir varias relaciones.

WITH personas AS (
    SELECT
        tenant_id,
        COUNT(*) AS cantidad_personas
    FROM persons
    GROUP BY tenant_id
),
modulos AS (
    SELECT
        tenant_id,
        COUNT(*) AS cantidad_modulos
    FROM tenant_modules
    WHERE is_active = TRUE
    GROUP BY tenant_id
),
plantillas AS (
    SELECT
        tenant_id,
        COUNT(*) AS cantidad_plantillas
    FROM tenanttemplates
    GROUP BY tenant_id
)
SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    COALESCE(p.cantidad_personas, 0) AS cantidad_personas,
    COALESCE(m.cantidad_modulos, 0) AS cantidad_modulos,
    COALESCE(pt.cantidad_plantillas, 0) AS cantidad_plantillas
FROM tenants t
LEFT JOIN personas p
    ON t.tenant_id = p.tenant_id
LEFT JOIN modulos m
    ON t.tenant_id = m.tenant_id
LEFT JOIN plantillas pt
    ON t.tenant_id = pt.tenant_id
ORDER BY t.legal_name;


-- 20. ORGANIZACIONES QUE NO TIENEN TODAS LAS ETAPAS PHVA
-- Se compara el numero de etapas usadas en las plantillas de
-- cada empresa contra las cuatro etapas existentes.

SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    COUNT(DISTINCT tt.phva_stage_id) AS etapas_configuradas,
    (SELECT COUNT(*) FROM phva_stages) AS etapas_requeridas
FROM tenants t
LEFT JOIN tenanttemplates tt
    ON t.tenant_id = tt.tenant_id
GROUP BY t.tenant_id, t.legal_name
HAVING COUNT(DISTINCT tt.phva_stage_id) < (
    SELECT COUNT(*)
    FROM phva_stages
)
ORDER BY etapas_configuradas, t.legal_name;



-- 21. ULTIMA ACTUALIZACION DE PLANTILLAS POR ORGANIZACION
-- MAX devuelve la fecha mas reciente entre las plantillas
-- asociadas a cada empresa.

SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    MAX(tt.updated_at) AS ultima_actualizacion
FROM tenants t
LEFT JOIN tenanttemplates tt
    ON t.tenant_id = tt.tenant_id
GROUP BY t.tenant_id, t.legal_name
ORDER BY ultima_actualizacion DESC NULLS LAST;


-- 22. ORGANIZACIONES CON DOCUMENTOS PENDIENTES
-- Se usan las dos vistas materializadas solicitadas por el examen.
-- Se muestran empresas con al menos un documento PENDING.

SELECT
    sst.tenant_id,
    sst.organizacion,
    sst.documentos_pendientes AS pendientes_sst,
    pesv.documentos_pendientes AS pendientes_pesv,
    sst.documentos_pendientes
        + pesv.documentos_pendientes AS total_pendientes
FROM vm_template_sst_docs_summary sst
INNER JOIN vm_template_pesv_docs_summary pesv
    ON sst.tenant_id = pesv.tenant_id
WHERE sst.documentos_pendientes > 0
   OR pesv.documentos_pendientes > 0
ORDER BY total_pendientes DESC, sst.organizacion;


-- 23. INFORME DOCUMENTAL CONSOLIDADO POR ORGANIZACION
-- Se suman SST y PESV para obtener un único resumen por empresa.

SELECT
    sst.tenant_id,
    sst.organizacion,

    sst.total_documentos
        + pesv.total_documentos AS total_documentos,

    sst.documentos_finalizados
        + pesv.documentos_finalizados AS documentos_finalizados,

    sst.documentos_borrador
        + pesv.documentos_borrador AS documentos_borrador,

    sst.documentos_no_iniciados
        + pesv.documentos_no_iniciados AS documentos_no_iniciados,

    sst.documentos_pendientes
        + pesv.documentos_pendientes AS documentos_pendientes,

    ROUND(
        CASE
            WHEN sst.total_documentos + pesv.total_documentos = 0
            THEN 0
            ELSE
                (
                    sst.documentos_finalizados
                    + pesv.documentos_finalizados
                ) * 100.0
                /
                (
                    sst.total_documentos
                    + pesv.total_documentos
                )
        END,
        2
    ) AS porcentaje_cumplimiento

FROM vm_template_sst_docs_summary sst
INNER JOIN vm_template_pesv_docs_summary pesv
    ON sst.tenant_id = pesv.tenant_id
ORDER BY porcentaje_cumplimiento DESC;


-- 24. COMPARAR CUMPLIMIENTO SST Y PESV
-- ABS obtiene la diferencia sin importar cual porcentaje sea mayor.
-- Cambia 20 por el valor minimo de diferencia que quieras evaluar.

SELECT
    sst.tenant_id,
    sst.organizacion,
    sst.porcentaje_cumplimiento AS cumplimiento_sst,
    pesv.porcentaje_cumplimiento AS cumplimiento_pesv,
    ABS(
        sst.porcentaje_cumplimiento
        - pesv.porcentaje_cumplimiento
    ) AS diferencia
FROM vm_template_sst_docs_summary sst
INNER JOIN vm_template_pesv_docs_summary pesv
    ON sst.tenant_id = pesv.tenant_id
WHERE ABS(
    sst.porcentaje_cumplimiento
    - pesv.porcentaje_cumplimiento
) > 20
ORDER BY diferencia DESC;


-- 25. VISTA CONSOLIDADA DE ORGANIZACIONES
-- La vista muestra personas, modulos, plantillas y sistemas.
-- Cada conteo se hace por separado para evitar duplicar registros.

CREATE OR REPLACE VIEW vw_tenant_summary AS
SELECT
    t.tenant_id,
    t.legal_name AS organizacion,

    (
        SELECT COUNT(*)
        FROM persons p
        WHERE p.tenant_id = t.tenant_id
    ) AS cantidad_personas,

    (
        SELECT COUNT(*)
        FROM tenant_modules tm
        WHERE tm.tenant_id = t.tenant_id
          AND tm.is_active = TRUE
    ) AS cantidad_modulos,

    (
        SELECT COUNT(*)
        FROM tenanttemplates tt
        WHERE tt.tenant_id = t.tenant_id
    ) AS cantidad_plantillas,

    (
        SELECT COUNT(*)
        FROM tenantsystems ts
        WHERE ts.tenant_id = t.tenant_id
          AND ts.is_active = TRUE
    ) AS cantidad_sistemas

FROM tenants t;


-- Consulta de prueba de la vista:
SELECT *
FROM vw_tenant_summary
ORDER BY organizacion;
