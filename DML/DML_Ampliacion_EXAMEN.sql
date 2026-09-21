-- ============================================================
-- AMPLIACION DE DATOS DE PRUEBA SST / PESV
-- PostgreSQL 16
--
-- REQUISITOS PREVIOS:
-- 1. Ejecutar DDL_SST_PESV_PostgreSQL.sql
-- 2. Ejecutar DML_SST_PESV_Datos_Prueba.sql
--
-- Este archivo NO repite los datos del DML anterior.
-- Agrega nuevos escenarios para consultas y evaluacion.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. NUEVAS UBICACIONES
-- ============================================================

INSERT INTO municipalities (region_id, name, code)
SELECT r.region_id, data.name, data.code
FROM regions AS r
JOIN countries AS c ON c.country_id = r.country_id
CROSS JOIN (
    VALUES
        ('Bucaramanga', '68001'),
        ('Floridablanca', '68276')
) AS data(name, code)
WHERE r.name = 'Santander'
  AND c.iso_code = 'CO'
ON CONFLICT (region_id, name) DO NOTHING;

-- ============================================================
-- 2. NUEVAS ORGANIZACIONES
-- ============================================================

INSERT INTO tenants (
    tenant_size_id,
    municipality_id,
    legal_name,
    identification_type,
    identification_number,
    contact_email,
    phone,
    address,
    is_active
)
SELECT
    ts.tenant_size_id,
    m.municipality_id,
    data.legal_name,
    'NIT',
    data.nit,
    data.email,
    data.phone,
    data.address,
    data.is_active
FROM (
    VALUES
        (
            'Transportes del Magdalena S.A.S.', '901000001-1',
            'Mediana empresa', 'Barrancabermeja',
            'contacto@transportesmagdalena.com', '6076110001',
            'Carrera 20 No. 45-10', TRUE
        ),
        (
            'Construcciones Seguras Ltda.', '901000002-2',
            'Pequena empresa', 'Bucaramanga',
            'contacto@construccionesseguras.com', '6076110002',
            'Calle 36 No. 18-25', TRUE
        ),
        (
            'Agroindustrial del Puerto S.A.S.', '901000003-3',
            'Gran empresa', 'Barrancabermeja',
            'contacto@agroindustrialpuerto.com', '6076110003',
            'Via Puerto Wilches Km 8', TRUE
        ),
        (
            'Servicios Integrales del Oriente S.A.S.', '901000004-4',
            'Microempresa', 'Bucaramanga',
            'contacto@serviciosoriente.com', '6076110004',
            'Carrera 27 No. 52-18', FALSE
        ),
        (
            'Logistica Vial Santander S.A.S.', '901000005-5',
            'Pequena empresa', 'Floridablanca',
            'contacto@logisticavialsantander.com', '6076110005',
            'Anillo Vial No. 15-60', TRUE
        )
) AS data(
    legal_name, nit, size_name, municipality_name,
    email, phone, address, is_active
)
JOIN tenant_sizes AS ts ON ts.name = data.size_name
JOIN municipalities AS m ON m.name = data.municipality_name
JOIN regions AS r ON r.region_id = m.region_id
JOIN countries AS c ON c.country_id = r.country_id AND c.iso_code = 'CO'
ON CONFLICT (identification_type, identification_number) DO NOTHING;

INSERT INTO tenant_settings (tenant_id, settings)
SELECT
    t.tenant_id,
    jsonb_build_object(
        'timezone', 'America/Bogota',
        'language', 'es-CO',
        'notifications_enabled', data.notifications_enabled
    )
FROM tenants AS t
JOIN (
    VALUES
        ('901000001-1', TRUE),
        ('901000002-2', TRUE),
        ('901000003-3', FALSE),
        ('901000004-4', FALSE),
        ('901000005-5', TRUE)
) AS data(nit, notifications_enabled)
  ON data.nit = t.identification_number
WHERE t.identification_type = 'NIT'
ON CONFLICT (tenant_id) DO NOTHING;

-- ============================================================
-- 3. NUEVOS CARGOS, PERSONAS Y ASIGNACIONES
-- Construcciones Seguras queda sin personas intencionalmente.
-- Servicios Integrales queda inactiva y sin personas.
-- ============================================================

INSERT INTO positions (tenant_id, name, description, is_active)
SELECT t.tenant_id, data.position_name, data.description, TRUE
FROM tenants AS t
JOIN (
    VALUES
        ('901000001-1', 'Gerente', 'Direccion general de la empresa'),
        ('901000001-1', 'Responsable SST', 'Administracion del SG-SST'),
        ('901000001-1', 'Coordinador PESV', 'Coordinacion del plan de seguridad vial'),
        ('901000003-3', 'Gerente', 'Direccion general de la empresa'),
        ('901000003-3', 'Responsable SST', 'Administracion del SG-SST'),
        ('901000005-5', 'Coordinador PESV', 'Coordinacion del plan de seguridad vial')
) AS data(nit, position_name, description)
  ON data.nit = t.identification_number
WHERE t.identification_type = 'NIT'
ON CONFLICT (tenant_id, name) DO NOTHING;

INSERT INTO persons (
    tenant_id,
    first_name,
    last_name,
    identification_number,
    email,
    phone,
    is_active
)
SELECT
    t.tenant_id,
    data.first_name,
    data.last_name,
    data.person_document,
    data.email,
    data.phone,
    TRUE
FROM tenants AS t
JOIN (
    VALUES
        ('901000001-1', 'Andrea', 'Martinez', '1098000011', 'andrea.martinez@transportesmagdalena.com', '3001000011'),
        ('901000001-1', 'Miguel', 'Rojas', '1098000012', 'miguel.rojas@transportesmagdalena.com', '3001000012'),
        ('901000001-1', 'Natalia', 'Suarez', '1098000013', 'natalia.suarez@transportesmagdalena.com', '3001000013'),
        -- Segunda persona en el cargo Responsable SST.
        -- Permite probar cargos cuya ocupacion supera el promedio de la organizacion.
        ('901000001-1', 'Camila', 'Gomez', '1098000014', 'camila.gomez@transportesmagdalena.com', '3001000014'),
        ('901000003-3', 'Diana', 'Torres', '1098000021', 'diana.torres@agroindustrialpuerto.com', '3001000021'),
        ('901000003-3', 'Jorge', 'Mendoza', '1098000022', 'jorge.mendoza@agroindustrialpuerto.com', '3001000022'),
        ('901000005-5', 'Paula', 'Ramirez', '1098000031', 'paula.ramirez@logisticavialsantander.com', '3001000031')
) AS data(nit, first_name, last_name, person_document, email, phone)
  ON data.nit = t.identification_number
WHERE t.identification_type = 'NIT'
ON CONFLICT (tenant_id, identification_number) DO NOTHING;

INSERT INTO person_position_assignments (
    person_id,
    position_id,
    started_at,
    ended_at
)
SELECT
    p.person_id,
    po.position_id,
    data.started_at,
    NULL
FROM (
    VALUES
        ('andrea.martinez@transportesmagdalena.com', 'Gerente', DATE '2025-01-15'),
        ('miguel.rojas@transportesmagdalena.com', 'Responsable SST', DATE '2025-02-01'),
        ('natalia.suarez@transportesmagdalena.com', 'Coordinador PESV', DATE '2025-03-10'),
        ('camila.gomez@transportesmagdalena.com', 'Responsable SST', DATE '2025-04-01'),
        ('diana.torres@agroindustrialpuerto.com', 'Gerente', DATE '2024-06-01'),
        ('jorge.mendoza@agroindustrialpuerto.com', 'Responsable SST', DATE '2024-07-01'),
        ('paula.ramirez@logisticavialsantander.com', 'Coordinador PESV', DATE '2026-01-10')
) AS data(person_email, position_name, started_at)
JOIN persons AS p ON p.email = data.person_email
JOIN positions AS po
  ON po.tenant_id = p.tenant_id
 AND po.name = data.position_name
WHERE NOT EXISTS (
    SELECT 1
    FROM person_position_assignments AS existing_assignment
    WHERE existing_assignment.person_id = p.person_id
      AND existing_assignment.ended_at IS NULL
);

-- ============================================================
-- 4. NUEVOS MODULOS Y FORMATOS
-- El modulo Seguimiento vial no se asigna a ninguna empresa.
-- Esto permite probar consultas de modulos sin asignacion.
-- ============================================================

INSERT INTO modules (system_id, title, description, display_order, is_active)
SELECT s.system_id, data.title, data.description, data.display_order, TRUE
FROM type_system_sst AS s
JOIN (
    VALUES
        ('SST', 'Identificacion de peligros', 'Gestion de peligros y valoracion de riesgos', 2),
        ('SST', 'Gestion de emergencias', 'Preparacion y respuesta ante emergencias', 3),
        ('PESV', 'Seguimiento vial', 'Seguimiento de indicadores y acciones del PESV', 2)
) AS data(system_code, title, description, display_order)
  ON data.system_code = s.code
ON CONFLICT (system_id, title) DO NOTHING;

INSERT INTO formats_sst (
    module_id,
    name,
    description,
    structure,
    version,
    is_active
)
SELECT
    m.module_id,
    data.format_name,
    data.description,
    data.structure::JSONB,
    1,
    TRUE
FROM modules AS m
JOIN type_system_sst AS s ON s.system_id = m.system_id
JOIN (
    VALUES
        ('SST', 'Gestion documental SST', 'Programa de capacitacion SST', 'Registro de actividades de capacitacion', '{"fields":["topic","date","responsible","attendees"]}'),
        ('SST', 'Gestion documental SST', 'Lista de verificacion SST', 'Verificacion del cumplimiento documental', '{"fields":["requirement","complies","observation"]}'),
        ('SST', 'Gestion documental SST', 'Plan de mejora SST', 'Registro de acciones correctivas', '{"fields":["finding","action","responsible","due_date"]}'),
        ('SST', 'Identificacion de peligros', 'Matriz de peligros', 'Identificacion y valoracion de peligros', '{"fields":["hazard","probability","impact","control"]}'),
        ('SST', 'Gestion de emergencias', 'Plan de emergencias', 'Preparacion y respuesta ante emergencias', '{"fields":["scenario","response","responsible"]}'),
        ('PESV', 'Planificacion PESV', 'Matriz de riesgos viales', 'Identificacion de riesgos de seguridad vial', '{"fields":["risk","probability","impact","control"]}')
) AS data(system_code, module_title, format_name, description, structure)
  ON data.system_code = s.code
 AND data.module_title = m.title
ON CONFLICT (module_id, name, version) DO NOTHING;

-- ============================================================
-- 5. SISTEMAS Y MODULOS HABILITADOS
-- Transportes tiene todos los modulos SST.
-- Agroindustrial tiene modulos pero no tendra plantillas.
-- ============================================================

INSERT INTO tenantsystems (tenant_id, system_id, is_active)
SELECT t.tenant_id, s.system_id, TRUE
FROM tenants AS t
JOIN (
    VALUES
        ('901000001-1', 'SST'),
        ('901000001-1', 'PESV'),
        ('901000003-3', 'SST'),
        ('901000005-5', 'PESV')
) AS data(nit, system_code)
  ON data.nit = t.identification_number
JOIN type_system_sst AS s ON s.code = data.system_code
WHERE t.identification_type = 'NIT'
ON CONFLICT (tenant_id, system_id) DO NOTHING;

INSERT INTO tenant_modules (tenant_id, module_id, is_active)
SELECT t.tenant_id, m.module_id, TRUE
FROM tenants AS t
JOIN (
    VALUES
        ('901000001-1', 'SST', 'Gestion documental SST'),
        ('901000001-1', 'SST', 'Identificacion de peligros'),
        ('901000001-1', 'SST', 'Gestion de emergencias'),
        ('901000001-1', 'PESV', 'Planificacion PESV'),
        ('901000003-3', 'SST', 'Gestion documental SST'),
        ('901000005-5', 'PESV', 'Planificacion PESV')
) AS data(nit, system_code, module_title)
  ON data.nit = t.identification_number
JOIN type_system_sst AS s ON s.code = data.system_code
JOIN modules AS m
  ON m.system_id = s.system_id
 AND m.title = data.module_title
WHERE t.identification_type = 'NIT'
ON CONFLICT (tenant_id, module_id) DO NOTHING;

-- ============================================================
-- 6. NUEVAS PLANTILLAS
-- ============================================================

INSERT INTO templates (name, description, field_schema, is_active)
VALUES
    ('Plantilla de capacitacion SST', 'Registro de capacitaciones realizadas', '{"required":["topic","date","responsible","attendees"]}'::JSONB, TRUE),
    ('Plantilla de verificacion SST', 'Verificacion de requisitos del SG-SST', '{"required":["requirement","complies"]}'::JSONB, TRUE),
    ('Plantilla de mejora SST', 'Registro y seguimiento de acciones de mejora', '{"required":["finding","action","responsible","due_date"]}'::JSONB, TRUE),
    ('Plantilla de matriz de peligros', 'Valoracion de peligros y riesgos laborales', '{"required":["hazard","probability","impact","control"]}'::JSONB, TRUE),
    ('Plantilla de emergencias', 'Preparacion y respuesta ante emergencias', '{"required":["scenario","response","responsible"]}'::JSONB, TRUE),
    ('Plantilla de riesgos viales', 'Valoracion de riesgos de seguridad vial', '{"required":["risk","probability","impact","control"]}'::JSONB, TRUE)
ON CONFLICT (name) DO NOTHING;

-- Transportes recibe plantillas en las cuatro etapas PHVA.
INSERT INTO tenanttemplates (
    tenant_id,
    template_id,
    format_id,
    phva_stage_id,
    is_active
)
SELECT
    t.tenant_id,
    tp.template_id,
    f.format_id,
    p.phva_stage_id,
    TRUE
FROM tenants AS t
JOIN (
    VALUES
        ('Plantilla del plan anual SST', 'Plan anual de trabajo SST', 'PLAN'),
        ('Plantilla de capacitacion SST', 'Programa de capacitacion SST', 'DO'),
        ('Plantilla de verificacion SST', 'Lista de verificacion SST', 'CHECK'),
        ('Plantilla de mejora SST', 'Plan de mejora SST', 'ACT'),
        ('Plantilla de riesgos viales', 'Matriz de riesgos viales', 'PLAN')
) AS data(template_name, format_name, phva_code) ON TRUE
JOIN templates AS tp ON tp.name = data.template_name
JOIN formats_sst AS f ON f.name = data.format_name AND f.version = 1
JOIN phva_stages AS p ON p.code = data.phva_code
WHERE t.identification_type = 'NIT'
  AND t.identification_number = '901000001-1'
ON CONFLICT (tenant_id, template_id, format_id, phva_stage_id) DO NOTHING;

-- Logistica recibe una plantilla PESV.
INSERT INTO tenanttemplates (
    tenant_id,
    template_id,
    format_id,
    phva_stage_id,
    is_active
)
SELECT
    t.tenant_id,
    tp.template_id,
    f.format_id,
    p.phva_stage_id,
    TRUE
FROM tenants AS t
JOIN templates AS tp ON tp.name = 'Plantilla del plan PESV'
JOIN formats_sst AS f ON f.name = 'Plan estrategico de seguridad vial' AND f.version = 1
JOIN phva_stages AS p ON p.code = 'PLAN'
WHERE t.identification_type = 'NIT'
  AND t.identification_number = '901000005-5'
ON CONFLICT (tenant_id, template_id, format_id, phva_stage_id) DO NOTHING;

-- ============================================================
-- 7. NUEVOS DOCUMENTOS
-- Transportes: 2 finalizados de 4 documentos SST = 50 %.
-- Logistica: 1 finalizado de 1 documento PESV = 100 %.
-- La empresa original conserva 0 % con sus datos anteriores.
-- ============================================================

INSERT INTO documents (
    tenant_template_id,
    document_status_id,
    title,
    period_start,
    period_end,
    due_date
)
SELECT
    tt.tenant_template_id,
    ds.document_status_id,
    data.document_title,
    DATE '2026-01-01',
    DATE '2026-12-31',
    data.due_date
FROM tenants AS t
JOIN (
    VALUES
        ('901000001-1', 'Plantilla del plan anual SST', 'Plan anual SST Transportes 2026', 'FINISHED', DATE '2026-02-28'),
        ('901000001-1', 'Plantilla de capacitacion SST', 'Programa de capacitacion Transportes 2026', 'FINISHED', DATE '2026-04-30'),
        ('901000001-1', 'Plantilla de verificacion SST', 'Verificacion SST Transportes 2026', 'DRAFT', DATE '2026-08-31'),
        ('901000001-1', 'Plantilla de mejora SST', 'Plan de mejora Transportes 2026', 'PENDING', DATE '2026-10-31'),
        ('901000001-1', 'Plantilla de riesgos viales', 'Matriz de riesgos viales Transportes 2026', 'NOT_STARTED', DATE '2026-11-30'),
        ('901000005-5', 'Plantilla del plan PESV', 'Plan PESV Logistica Vial 2026', 'FINISHED', DATE '2026-03-31')
) AS data(nit, template_name, document_title, status_code, due_date)
  ON data.nit = t.identification_number
JOIN tenanttemplates AS tt ON tt.tenant_id = t.tenant_id
JOIN templates AS tp
  ON tp.template_id = tt.template_id
 AND tp.name = data.template_name
JOIN document_statuses AS ds ON ds.code = data.status_code
WHERE t.identification_type = 'NIT'
  AND NOT EXISTS (
      SELECT 1
      FROM documents AS existing_document
      WHERE existing_document.tenant_template_id = tt.tenant_template_id
        AND existing_document.title = data.document_title
  );

INSERT INTO document_versions (
    document_id,
    version_number,
    content,
    created_by_person_id
)
SELECT
    d.document_id,
    1,
    jsonb_build_object(
        'title', d.title,
        'year', 2026,
        'status', ds.code,
        'observation', 'Version inicial de demostracion'
    ),
    p.person_id
FROM documents AS d
JOIN document_statuses AS ds ON ds.document_status_id = d.document_status_id
JOIN tenanttemplates AS tt ON tt.tenant_template_id = d.tenant_template_id
JOIN tenants AS t ON t.tenant_id = tt.tenant_id
JOIN persons AS p
  ON p.tenant_id = t.tenant_id
 AND p.email = CASE t.identification_number
     WHEN '901000001-1' THEN 'miguel.rojas@transportesmagdalena.com'
     WHEN '901000005-5' THEN 'paula.ramirez@logisticavialsantander.com'
 END
WHERE t.identification_number IN ('901000001-1', '901000005-5')
ON CONFLICT (document_id, version_number) DO NOTHING;

-- ============================================================
-- 8. EVALUACIONES Y RESPUESTAS ADICIONALES
-- ============================================================

INSERT INTO tenant_evaluations (
    tenant_id,
    evaluation_id,
    system_id,
    phva_stage_id,
    is_active
)
SELECT
    t.tenant_id,
    e.evaluation_id,
    s.system_id,
    p.phva_stage_id,
    TRUE
FROM tenants AS t
JOIN (
    VALUES
        ('901000001-1', 'Autoevaluacion SG-SST', 'SST', 'CHECK'),
        ('901000001-1', 'Diagnostico PESV', 'PESV', 'CHECK'),
        ('901000005-5', 'Diagnostico PESV', 'PESV', 'CHECK')
) AS data(nit, evaluation_name, system_code, phva_code)
  ON data.nit = t.identification_number
JOIN evaluations AS e ON e.name = data.evaluation_name
JOIN type_system_sst AS s ON s.code = data.system_code
JOIN phva_stages AS p ON p.code = data.phva_code
WHERE t.identification_type = 'NIT'
ON CONFLICT (tenant_id, evaluation_id, system_id, phva_stage_id) DO NOTHING;

INSERT INTO evaluation_submissions (
    tenant_evaluation_id,
    submitted_by_person_id,
    evaluation_period,
    answers,
    result
)
SELECT
    te.tenant_evaluation_id,
    p.person_id,
    '2026',
    data.answers::JSONB,
    data.result::JSONB
FROM tenants AS t
JOIN (
    VALUES
        ('901000001-1', 'Autoevaluacion SG-SST', 'miguel.rojas@transportesmagdalena.com', '{"Q1":true,"Q2":true}', '{"score":100,"status":"cumple"}'),
        ('901000001-1', 'Diagnostico PESV', 'natalia.suarez@transportesmagdalena.com', '{"Q1":true}', '{"score":85,"status":"cumple_parcial"}'),
        ('901000005-5', 'Diagnostico PESV', 'paula.ramirez@logisticavialsantander.com', '{"Q1":true}', '{"score":100,"status":"cumple"}')
) AS data(nit, evaluation_name, person_email, answers, result)
  ON data.nit = t.identification_number
JOIN evaluations AS e ON e.name = data.evaluation_name
JOIN tenant_evaluations AS te
  ON te.tenant_id = t.tenant_id
 AND te.evaluation_id = e.evaluation_id
JOIN persons AS p
  ON p.tenant_id = t.tenant_id
 AND p.email = data.person_email
WHERE t.identification_type = 'NIT'
  AND NOT EXISTS (
      SELECT 1
      FROM evaluation_submissions AS existing_submission
      WHERE existing_submission.tenant_evaluation_id = te.tenant_evaluation_id
        AND existing_submission.submitted_by_person_id = p.person_id
        AND existing_submission.evaluation_period = '2026'
  );

-- ============================================================
-- 9. BLOQUEO DE EDICION Y AUDITORIA
-- ============================================================

INSERT INTO editing_locks (
    document_id,
    locked_by_person_id,
    locked_at,
    expires_at,
    is_active
)
SELECT
    d.document_id,
    p.person_id,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP + INTERVAL '45 minutes',
    TRUE
FROM documents AS d
JOIN tenanttemplates AS tt ON tt.tenant_template_id = d.tenant_template_id
JOIN tenants AS t ON t.tenant_id = tt.tenant_id
JOIN persons AS p
  ON p.tenant_id = t.tenant_id
 AND p.email = 'miguel.rojas@transportesmagdalena.com'
WHERE t.identification_number = '901000001-1'
  AND d.title = 'Verificacion SST Transportes 2026'
  AND NOT EXISTS (
      SELECT 1
      FROM editing_locks AS existing_lock
      WHERE existing_lock.document_id = d.document_id
        AND existing_lock.is_active
  );

INSERT INTO audit_logs (
    tenant_id,
    table_name,
    record_identifier,
    operation,
    old_data,
    new_data,
    changed_by_person_id
)
SELECT
    t.tenant_id,
    'tenants',
    t.tenant_id::VARCHAR,
    'INSERT',
    NULL,
    jsonb_build_object(
        'legal_name', t.legal_name,
        'identification_number', t.identification_number,
        'is_active', t.is_active
    ),
    p.person_id
FROM tenants AS t
JOIN persons AS p
  ON p.tenant_id = t.tenant_id
 AND p.email = CASE t.identification_number
     WHEN '901000001-1' THEN 'andrea.martinez@transportesmagdalena.com'
     WHEN '901000003-3' THEN 'diana.torres@agroindustrialpuerto.com'
     WHEN '901000005-5' THEN 'paula.ramirez@logisticavialsantander.com'
 END
WHERE t.identification_number IN ('901000001-1', '901000003-3', '901000005-5')
  AND NOT EXISTS (
      SELECT 1
      FROM audit_logs AS existing_log
      WHERE existing_log.tenant_id = t.tenant_id
        AND existing_log.table_name = 'tenants'
        AND existing_log.record_identifier = t.tenant_id::VARCHAR
        AND existing_log.operation = 'INSERT'
  );

COMMIT;

-- ============================================================
-- 10. RESUMEN DE LOS ESCENARIOS CREADOS
-- ============================================================

SELECT
    t.legal_name,
    t.is_active,
    ts.name AS tenant_size,
    m.name AS municipality,
    COUNT(DISTINCT p.person_id) AS persons,
    COUNT(DISTINCT tm.module_id) AS enabled_modules,
    COUNT(DISTINCT tt.tenant_template_id) AS assigned_templates,
    COUNT(DISTINCT d.document_id) AS documents,
    COUNT(DISTINCT d.document_id)
        FILTER (WHERE ds.counts_as_completed) AS finished_documents
FROM tenants AS t
JOIN tenant_sizes AS ts ON ts.tenant_size_id = t.tenant_size_id
JOIN municipalities AS m ON m.municipality_id = t.municipality_id
LEFT JOIN persons AS p ON p.tenant_id = t.tenant_id
LEFT JOIN tenant_modules AS tm ON tm.tenant_id = t.tenant_id
LEFT JOIN tenanttemplates AS tt ON tt.tenant_id = t.tenant_id
LEFT JOIN documents AS d ON d.tenant_template_id = tt.tenant_template_id
LEFT JOIN document_statuses AS ds
  ON ds.document_status_id = d.document_status_id
GROUP BY t.tenant_id, t.legal_name, t.is_active, ts.name, m.name
ORDER BY t.legal_name;

-- Fin de la ampliacion de datos.
