-- VISTAS Y VISTAS MATERIALIZADAS
-- Estas vistas se crean antes de las consultas avanzadas porque
-- varias de ellas dependen de los resúmenes documentales.


-- 1. VISTA: ORGANIZACIONES, PERSONAS Y CARGOS
-- Muestra cada persona junto con su organización y su cargo actual.
-- ended_at IS NULL identifica la asignación de cargo vigente.

CREATE OR REPLACE VIEW vw_tenant_persons AS
SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    p.person_id,
    p.first_name,
    p.last_name,
    p.email,
    pos.position_id,
    pos.name AS cargo
FROM tenants t
INNER JOIN persons p
    ON t.tenant_id = p.tenant_id
LEFT JOIN person_position_assignments ppa
    ON p.person_id = ppa.person_id
   AND ppa.ended_at IS NULL
LEFT JOIN positions pos
    ON ppa.position_id = pos.position_id;


-- Consulta de prueba:
SELECT *
FROM vw_tenant_persons
ORDER BY organizacion, last_name, first_name;



-- 2. VISTA: UBICACION GEOGRAFICA DE LAS ORGANIZACIONES
-- Une municipio, región y país para mostrar la ubicación completa.

CREATE OR REPLACE VIEW vw_tenant_geography AS
SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    m.municipality_id,
    m.name AS municipio,
    r.region_id,
    r.name AS departamento_region,
    c.country_id,
    c.name AS pais
FROM tenants t
INNER JOIN municipalities m
    ON t.municipality_id = m.municipality_id
INNER JOIN regions r
    ON m.region_id = r.region_id
INNER JOIN countries c
    ON r.country_id = c.country_id;


-- Consulta de prueba:
SELECT *
FROM vw_tenant_geography
ORDER BY organizacion;



-- 3. VISTA: MODULOS HABILITADOS POR ORGANIZACION
-- tenant_modules conecta la organización con el módulo.
-- modules conecta cada módulo con su sistema SST o PESV.

CREATE OR REPLACE VIEW vw_tenant_modules AS
SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    m.module_id,
    m.title AS modulo,
    s.system_id,
    s.code AS codigo_sistema,
    s.name AS sistema
FROM tenant_modules tm
INNER JOIN tenants t
    ON tm.tenant_id = t.tenant_id
INNER JOIN modules m
    ON tm.module_id = m.module_id
INNER JOIN type_system_sst s
    ON m.system_id = s.system_id
WHERE tm.is_active = TRUE;


-- Consulta de prueba:
SELECT *
FROM vw_tenant_modules
ORDER BY organizacion, codigo_sistema, modulo;



-- 4. VISTA: CANTIDAD DE PLANTILLAS POR ORGANIZACION Y ETAPA PHVA
-- GROUP BY agrupa las plantillas de cada empresa según su etapa PHVA.

CREATE OR REPLACE VIEW vw_tenant_templates_phva AS
SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    ph.phva_stage_id,
    ph.code AS codigo_phva,
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
    ph.code,
    ph.name,
    ph.display_order;


-- Consulta de prueba:
SELECT *
FROM vw_tenant_templates_phva
ORDER BY organizacion, phva_stage_id;



-- 5. VISTA: CANTIDAD DE PERSONAS POR ORGANIZACION Y CARGO
-- LEFT JOIN permite mostrar cargos que actualmente tengan 0 personas.

CREATE OR REPLACE VIEW vw_tenant_persons_by_position AS
SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    pos.position_id,
    pos.name AS cargo,
    COUNT(ppa.person_id) AS cantidad_personas
FROM positions pos
INNER JOIN tenants t
    ON pos.tenant_id = t.tenant_id
LEFT JOIN person_position_assignments ppa
    ON pos.position_id = ppa.position_id
   AND ppa.ended_at IS NULL
GROUP BY
    t.tenant_id,
    t.legal_name,
    pos.position_id,
    pos.name;


-- Consulta de prueba:
SELECT *
FROM vw_tenant_persons_by_position
ORDER BY organizacion, cantidad_personas DESC, cargo;



-- 6. VISTA MATERIALIZADA: RESUMEN DOCUMENTAL SST
-- Una vista materializada guarda físicamente el resultado.
-- Por eso es útil para reportes que se consultan muchas veces.
--
-- Se cuentan los documentos SST según su estado y se calcula
-- el porcentaje de documentos que cuentan como completados.

DROP MATERIALIZED VIEW IF EXISTS vm_template_sst_docs_summary;

CREATE MATERIALIZED VIEW vm_template_sst_docs_summary AS
SELECT
    t.tenant_id,
    t.legal_name AS organizacion,

    COUNT(d.document_id)
        FILTER (WHERE s.code = 'SST') AS total_documentos,

    COUNT(d.document_id)
        FILTER (
            WHERE s.code = 'SST'
              AND ds.code = 'FINISHED'
        ) AS documentos_finalizados,

    COUNT(d.document_id)
        FILTER (
            WHERE s.code = 'SST'
              AND ds.code = 'DRAFT'
        ) AS documentos_borrador,

    COUNT(d.document_id)
        FILTER (
            WHERE s.code = 'SST'
              AND ds.code = 'NOT_STARTED'
        ) AS documentos_no_iniciados,

    COUNT(d.document_id)
        FILTER (
            WHERE s.code = 'SST'
              AND ds.code = 'PENDING'
        ) AS documentos_pendientes,

    ROUND(
        CASE
            WHEN COUNT(d.document_id)
                 FILTER (WHERE s.code = 'SST') = 0
            THEN 0
            ELSE
                COUNT(d.document_id)
                    FILTER (
                        WHERE s.code = 'SST'
                          AND ds.counts_as_completed = TRUE
                    ) * 100.0
                /
                COUNT(d.document_id)
                    FILTER (WHERE s.code = 'SST')
        END,
        2
    ) AS porcentaje_cumplimiento,

    MAX(d.updated_at)
        FILTER (WHERE s.code = 'SST') AS ultima_actualizacion

FROM tenants t
LEFT JOIN tenanttemplates tt
    ON t.tenant_id = tt.tenant_id
LEFT JOIN formats_sst f
    ON tt.format_id = f.format_id
LEFT JOIN modules m
    ON f.module_id = m.module_id
LEFT JOIN type_system_sst s
    ON m.system_id = s.system_id
LEFT JOIN documents d
    ON tt.tenant_template_id = d.tenant_template_id
LEFT JOIN document_statuses ds
    ON d.document_status_id = ds.document_status_id
GROUP BY
    t.tenant_id,
    t.legal_name;


-- Índice principal para buscar rápidamente por organización.
CREATE UNIQUE INDEX ux_vm_sst_tenant
    ON vm_template_sst_docs_summary (tenant_id);

-- Ayuda en consultas que filtran u ordenan por cumplimiento.
CREATE INDEX ix_vm_sst_cumplimiento
    ON vm_template_sst_docs_summary (porcentaje_cumplimiento);


-- Consulta de prueba:
SELECT *
FROM vm_template_sst_docs_summary
ORDER BY organizacion;



-- 7. VISTA MATERIALIZADA: RESUMEN DOCUMENTAL PESV
-- Tiene la misma lógica de la anterior, pero solo cuenta
-- documentos relacionados con el sistema PESV.

DROP MATERIALIZED VIEW IF EXISTS vm_template_pesv_docs_summary;

CREATE MATERIALIZED VIEW vm_template_pesv_docs_summary AS
SELECT
    t.tenant_id,
    t.legal_name AS organizacion,

    COUNT(d.document_id)
        FILTER (WHERE s.code = 'PESV') AS total_documentos,

    COUNT(d.document_id)
        FILTER (
            WHERE s.code = 'PESV'
              AND ds.code = 'FINISHED'
        ) AS documentos_finalizados,

    COUNT(d.document_id)
        FILTER (
            WHERE s.code = 'PESV'
              AND ds.code = 'DRAFT'
        ) AS documentos_borrador,

    COUNT(d.document_id)
        FILTER (
            WHERE s.code = 'PESV'
              AND ds.code = 'NOT_STARTED'
        ) AS documentos_no_iniciados,

    COUNT(d.document_id)
        FILTER (
            WHERE s.code = 'PESV'
              AND ds.code = 'PENDING'
        ) AS documentos_pendientes,

    ROUND(
        CASE
            WHEN COUNT(d.document_id)
                 FILTER (WHERE s.code = 'PESV') = 0
            THEN 0
            ELSE
                COUNT(d.document_id)
                    FILTER (
                        WHERE s.code = 'PESV'
                          AND ds.counts_as_completed = TRUE
                    ) * 100.0
                /
                COUNT(d.document_id)
                    FILTER (WHERE s.code = 'PESV')
        END,
        2
    ) AS porcentaje_cumplimiento,

    MAX(d.updated_at)
        FILTER (WHERE s.code = 'PESV') AS ultima_actualizacion

FROM tenants t
LEFT JOIN tenanttemplates tt
    ON t.tenant_id = tt.tenant_id
LEFT JOIN formats_sst f
    ON tt.format_id = f.format_id
LEFT JOIN modules m
    ON f.module_id = m.module_id
LEFT JOIN type_system_sst s
    ON m.system_id = s.system_id
LEFT JOIN documents d
    ON tt.tenant_template_id = d.tenant_template_id
LEFT JOIN document_statuses ds
    ON d.document_status_id = ds.document_status_id
GROUP BY
    t.tenant_id,
    t.legal_name;


CREATE UNIQUE INDEX ux_vm_pesv_tenant
    ON vm_template_pesv_docs_summary (tenant_id);

CREATE INDEX ix_vm_pesv_cumplimiento
    ON vm_template_pesv_docs_summary (porcentaje_cumplimiento);


-- Consulta de prueba:
SELECT *
FROM vm_template_pesv_docs_summary
ORDER BY organizacion;



-- 8. ACTUALIZAR LAS VISTAS MATERIALIZADAS
-- Las vistas normales se actualizan solas al consultar.
-- Las materializadas deben refrescarse después de cambiar los datos.

REFRESH MATERIALIZED VIEW vm_template_sst_docs_summary;
REFRESH MATERIALIZED VIEW vm_template_pesv_docs_summary;


-- Verificación después del REFRESH:
SELECT *
FROM vm_template_sst_docs_summary
ORDER BY tenant_id;

SELECT *
FROM vm_template_pesv_docs_summary
ORDER BY tenant_id;



-- RESUMEN DE INDICES DE LAS VISTAS MATERIALIZADAS

-- tenant_id:
--   Permite buscar rápidamente el resumen de una organización.
--   También deja cada organización identificada una sola vez.

-- porcentaje_cumplimiento:
--   Ayuda cuando se filtran o se ordenan empresas por cumplimiento,
--   algo que será frecuente en las consultas avanzadas.
