BEGIN;

-- 1. CATALOGOS DE ORGANIZACION Y UBICACION

INSERT INTO tenant_sizes (name, min_employees, max_employees)
VALUES
    ('Microempresa', 1, 10),
    ('Pequena empresa', 11, 50),
    ('Mediana empresa', 51, 200),
    ('Gran empresa', 201, NULL)
ON CONFLICT (name) DO NOTHING;

INSERT INTO countries (name, iso_code)
VALUES ('Colombia', 'CO')
ON CONFLICT (iso_code) DO NOTHING;

INSERT INTO regions (country_id, name, code)
SELECT country_id, 'Santander', 'SAN'
FROM countries
WHERE iso_code = 'CO'
ON CONFLICT (country_id, name) DO NOTHING;

INSERT INTO municipalities (region_id, name, code)
SELECT region_id, 'Barrancabermeja', '68081'
FROM regions
WHERE name = 'Santander'
  AND country_id = (SELECT country_id FROM countries WHERE iso_code = 'CO')
ON CONFLICT (region_id, name) DO NOTHING;

-- 2. ORGANIZACION DE PRUEBA

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
    'Empresa Demo SST S.A.S.',
    'NIT',
    '900123456-7',
    'contacto@empresademosst.com',
    '6076000000',
    'Calle 50 No. 20-30',
    TRUE
FROM tenant_sizes AS ts
CROSS JOIN municipalities AS m
JOIN regions AS r ON r.region_id = m.region_id
JOIN countries AS c ON c.country_id = r.country_id
WHERE ts.name = 'Pequena empresa'
  AND m.name = 'Barrancabermeja'
  AND r.name = 'Santander'
  AND c.iso_code = 'CO'
ON CONFLICT (identification_type, identification_number)
DO UPDATE SET
    legal_name = EXCLUDED.legal_name,
    contact_email = EXCLUDED.contact_email,
    phone = EXCLUDED.phone,
    address = EXCLUDED.address,
    is_active = EXCLUDED.is_active;

INSERT INTO tenant_settings (tenant_id, settings)
SELECT
    tenant_id,
    '{
        "timezone": "America/Bogota",
        "language": "es-CO",
        "notifications_enabled": true
    }'::JSONB
FROM tenants
WHERE identification_type = 'NIT'
  AND identification_number = '900123456-7'
ON CONFLICT (tenant_id)
DO UPDATE SET settings = EXCLUDED.settings;

-- 3. CARGOS, PERSONAS Y ASIGNACIONES

INSERT INTO positions (tenant_id, name, description, is_active)
SELECT tenant_id, data.name, data.description, TRUE
FROM tenants
CROSS JOIN (
    VALUES
        ('Gerente', 'Responsable de la direccion general'),
        ('Responsable SST', 'Responsable del Sistema de Gestion SST')
) AS data(name, description)
WHERE identification_type = 'NIT'
  AND identification_number = '900123456-7'
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
SELECT tenant_id, data.first_name, data.last_name,
       data.identification_number, data.email, data.phone, TRUE
FROM tenants
CROSS JOIN (
    VALUES
        ('Laura', 'Gomez', '1098000001', 'laura.gomez@empresademosst.com', '3000000001'),
        ('Carlos', 'Perez', '1098000002', 'carlos.perez@empresademosst.com', '3000000002')
) AS data(first_name, last_name, identification_number, email, phone)
WHERE identification_type = 'NIT'
  AND tenants.identification_number = '900123456-7'
ON CONFLICT (tenant_id, identification_number) DO NOTHING;

INSERT INTO person_position_assignments (
    person_id,
    position_id,
    started_at,
    ended_at
)
SELECT p.person_id, po.position_id, DATE '2026-01-15', NULL
FROM persons AS p
JOIN positions AS po
  ON po.tenant_id = p.tenant_id
JOIN tenants AS t
  ON t.tenant_id = p.tenant_id
WHERE t.identification_type = 'NIT'
  AND t.identification_number = '900123456-7'
  AND (
      (p.email = 'laura.gomez@empresademosst.com' AND po.name = 'Gerente')
      OR
      (p.email = 'carlos.perez@empresademosst.com' AND po.name = 'Responsable SST')
  )
  AND NOT EXISTS (
      SELECT 1
      FROM person_position_assignments AS existing_assignment
      WHERE existing_assignment.person_id = p.person_id
        AND existing_assignment.ended_at IS NULL
  );

-- 4. SISTEMAS, MODULOS Y FORMATOS
-- 

INSERT INTO type_system_sst (code, name, description, is_active)
VALUES
    ('SST', 'Sistema de Gestion de Seguridad y Salud en el Trabajo',
     'Gestion de riesgos laborales y bienestar de los trabajadores', TRUE),
    ('PESV', 'Plan Estrategico de Seguridad Vial',
     'Gestion de la seguridad vial de la organizacion', TRUE)
ON CONFLICT (code) DO NOTHING;

INSERT INTO modules (system_id, title, description, display_order, is_active)
SELECT system_id, data.title, data.description, data.display_order, TRUE
FROM type_system_sst
JOIN (
    VALUES
        ('SST', 'Gestion documental SST', 'Documentos obligatorios del SG-SST', 1),
        ('PESV', 'Planificacion PESV', 'Planeacion de actividades de seguridad vial', 1)
) AS data(system_code, title, description, display_order)
ON data.system_code = type_system_sst.code
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
        (
            'SST',
            'Gestion documental SST',
            'Plan anual de trabajo SST',
            'Formato para registrar objetivos, actividades, responsables y fechas',
            '{"fields":["objective","activity","responsible","due_date"]}'
        ),
        (
            'PESV',
            'Planificacion PESV',
            'Plan estrategico de seguridad vial',
            'Formato general para la planificacion del PESV',
            '{"fields":["objective","action","responsible","indicator"]}'
        )
) AS data(system_code, module_title, format_name, description, structure)
  ON data.system_code = s.code
 AND data.module_title = m.title
ON CONFLICT (module_id, name, version) DO NOTHING;

INSERT INTO tenantsystems (tenant_id, system_id, is_active)
SELECT t.tenant_id, s.system_id, TRUE
FROM tenants AS t
CROSS JOIN type_system_sst AS s
WHERE t.identification_type = 'NIT'
  AND t.identification_number = '900123456-7'
  AND s.code IN ('SST', 'PESV')
ON CONFLICT (tenant_id, system_id)
DO UPDATE SET is_active = EXCLUDED.is_active;

INSERT INTO tenant_modules (tenant_id, module_id, is_active)
SELECT t.tenant_id, m.module_id, TRUE
FROM tenants AS t
CROSS JOIN modules AS m
JOIN type_system_sst AS s ON s.system_id = m.system_id
WHERE t.identification_type = 'NIT'
  AND t.identification_number = '900123456-7'
  AND s.code IN ('SST', 'PESV')
ON CONFLICT (tenant_id, module_id)
DO UPDATE SET is_active = EXCLUDED.is_active;

-- 5. PHVA, PLANTILLAS Y DOCUMENTOS
-- 

INSERT INTO phva_stages (code, name, display_order)
VALUES
    ('PLAN', 'Planear', 1),
    ('DO', 'Hacer', 2),
    ('CHECK', 'Verificar', 3),
    ('ACT', 'Actuar', 4)
ON CONFLICT (code) DO NOTHING;

INSERT INTO templates (name, description, field_schema, is_active)
VALUES
    (
        'Plantilla del plan anual SST',
        'Plantilla para organizar el plan anual de trabajo',
        '{"required":["objective","activity","responsible","due_date"]}'::JSONB,
        TRUE
    ),
    (
        'Plantilla del plan PESV',
        'Plantilla para documentar el plan de seguridad vial',
        '{"required":["objective","action","responsible","indicator"]}'::JSONB,
        TRUE
    )
ON CONFLICT (name) DO NOTHING;

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
        ('Plantilla del plan PESV', 'Plan estrategico de seguridad vial', 'PLAN')
) AS data(template_name, format_name, phva_code) ON TRUE
JOIN templates AS tp ON tp.name = data.template_name
JOIN formats_sst AS f ON f.name = data.format_name AND f.version = 1
JOIN phva_stages AS p ON p.code = data.phva_code
WHERE t.identification_type = 'NIT'
  AND t.identification_number = '900123456-7'
ON CONFLICT (tenant_id, template_id, format_id, phva_stage_id)
DO UPDATE SET is_active = EXCLUDED.is_active;

INSERT INTO document_statuses (code, name, counts_as_completed)
VALUES
    ('NOT_STARTED', 'No iniciado', FALSE),
    ('DRAFT', 'Borrador', FALSE),
    ('PENDING', 'Pendiente de revision', FALSE),
    ('FINISHED', 'Finalizado', TRUE)
ON CONFLICT (code) DO NOTHING;

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
FROM tenanttemplates AS tt
JOIN tenants AS t ON t.tenant_id = tt.tenant_id
JOIN templates AS tp ON tp.template_id = tt.template_id
JOIN (
    VALUES
        ('Plantilla del plan anual SST', 'Plan anual de trabajo SST 2026', 'DRAFT', DATE '2026-02-28'),
        ('Plantilla del plan PESV', 'Plan estrategico de seguridad vial 2026', 'NOT_STARTED', DATE '2026-03-31')
) AS data(template_name, document_title, status_code, due_date)
  ON data.template_name = tp.name
JOIN document_statuses AS ds ON ds.code = data.status_code
WHERE t.identification_type = 'NIT'
  AND t.identification_number = '900123456-7'
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
    '{
        "objective": "Implementar las actividades del SG-SST durante 2026",
        "activity": "Capacitacion mensual en prevencion de riesgos",
        "responsible": "Responsable SST",
        "due_date": "2026-12-15"
    }'::JSONB,
    p.person_id
FROM documents AS d
JOIN tenanttemplates AS tt ON tt.tenant_template_id = d.tenant_template_id
JOIN tenants AS t ON t.tenant_id = tt.tenant_id
JOIN persons AS p ON p.tenant_id = t.tenant_id
WHERE t.identification_type = 'NIT'
  AND t.identification_number = '900123456-7'
  AND d.title = 'Plan anual de trabajo SST 2026'
  AND p.email = 'carlos.perez@empresademosst.com'
ON CONFLICT (document_id, version_number) DO NOTHING;


-- 6. EVALUACIONES


INSERT INTO evaluations (
    name,
    description,
    question_schema,
    is_active
)
VALUES
    (
        'Autoevaluacion SG-SST',
        'Evaluacion basica del cumplimiento del SG-SST',
        '{
            "questions": [
                {"code":"Q1","text":"Existe un responsable del SG-SST","type":"boolean"},
                {"code":"Q2","text":"Existe un plan anual de trabajo","type":"boolean"}
            ]
        }'::JSONB,
        TRUE
    ),
    (
        'Diagnostico PESV',
        'Evaluacion inicial del Plan Estrategico de Seguridad Vial',
        '{
            "questions": [
                {"code":"Q1","text":"La organizacion tiene PESV","type":"boolean"}
            ]
        }'::JSONB,
        TRUE
    )
ON CONFLICT (name) DO NOTHING;

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
        ('Autoevaluacion SG-SST', 'SST', 'CHECK'),
        ('Diagnostico PESV', 'PESV', 'CHECK')
) AS data(evaluation_name, system_code, phva_code) ON TRUE
JOIN evaluations AS e ON e.name = data.evaluation_name
JOIN type_system_sst AS s ON s.code = data.system_code
JOIN phva_stages AS p ON p.code = data.phva_code
WHERE t.identification_type = 'NIT'
  AND t.identification_number = '900123456-7'
ON CONFLICT (tenant_id, evaluation_id, system_id, phva_stage_id)
DO UPDATE SET is_active = EXCLUDED.is_active;

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
    '{"Q1":true,"Q2":true}'::JSONB,
    '{"score":100,"status":"cumple"}'::JSONB
FROM tenant_evaluations AS te
JOIN tenants AS t ON t.tenant_id = te.tenant_id
JOIN evaluations AS e ON e.evaluation_id = te.evaluation_id
JOIN persons AS p ON p.tenant_id = t.tenant_id
WHERE t.identification_type = 'NIT'
  AND t.identification_number = '900123456-7'
  AND e.name = 'Autoevaluacion SG-SST'
  AND p.email = 'carlos.perez@empresademosst.com'
  AND NOT EXISTS (
      SELECT 1
      FROM evaluation_submissions AS existing_submission
      WHERE existing_submission.tenant_evaluation_id = te.tenant_evaluation_id
        AND existing_submission.submitted_by_person_id = p.person_id
        AND existing_submission.evaluation_period = '2026'
  );

-- 7. BLOQUEO DE EDICION Y AUDITORIA

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
    CURRENT_TIMESTAMP + INTERVAL '30 minutes',
    TRUE
FROM documents AS d
JOIN tenanttemplates AS tt ON tt.tenant_template_id = d.tenant_template_id
JOIN tenants AS t ON t.tenant_id = tt.tenant_id
JOIN persons AS p ON p.tenant_id = t.tenant_id
WHERE t.identification_type = 'NIT'
  AND t.identification_number = '900123456-7'
  AND d.title = 'Plan anual de trabajo SST 2026'
  AND p.email = 'carlos.perez@empresademosst.com'
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
JOIN persons AS p ON p.tenant_id = t.tenant_id
WHERE t.identification_type = 'NIT'
  AND t.identification_number = '900123456-7'
  AND p.email = 'laura.gomez@empresademosst.com'
  AND NOT EXISTS (
      SELECT 1
      FROM audit_logs AS existing_log
      WHERE existing_log.tenant_id = t.tenant_id
        AND existing_log.table_name = 'tenants'
        AND existing_log.record_identifier = t.tenant_id::VARCHAR
        AND existing_log.operation = 'INSERT'
  );

COMMIT;

-- COMPROBACION RAPIDA

SELECT 'tenant_sizes' AS table_name, COUNT(*) AS total FROM tenant_sizes
UNION ALL SELECT 'countries', COUNT(*) FROM countries
UNION ALL SELECT 'regions', COUNT(*) FROM regions
UNION ALL SELECT 'municipalities', COUNT(*) FROM municipalities
UNION ALL SELECT 'tenants', COUNT(*) FROM tenants
UNION ALL SELECT 'tenant_settings', COUNT(*) FROM tenant_settings
UNION ALL SELECT 'positions', COUNT(*) FROM positions
UNION ALL SELECT 'persons', COUNT(*) FROM persons
UNION ALL SELECT 'person_position_assignments', COUNT(*) FROM person_position_assignments
UNION ALL SELECT 'type_system_sst', COUNT(*) FROM type_system_sst
UNION ALL SELECT 'modules', COUNT(*) FROM modules
UNION ALL SELECT 'formats_sst', COUNT(*) FROM formats_sst
UNION ALL SELECT 'tenantsystems', COUNT(*) FROM tenantsystems
UNION ALL SELECT 'tenant_modules', COUNT(*) FROM tenant_modules
UNION ALL SELECT 'phva_stages', COUNT(*) FROM phva_stages
UNION ALL SELECT 'templates', COUNT(*) FROM templates
UNION ALL SELECT 'tenanttemplates', COUNT(*) FROM tenanttemplates
UNION ALL SELECT 'document_statuses', COUNT(*) FROM document_statuses
UNION ALL SELECT 'documents', COUNT(*) FROM documents
UNION ALL SELECT 'document_versions', COUNT(*) FROM document_versions
UNION ALL SELECT 'evaluations', COUNT(*) FROM evaluations
UNION ALL SELECT 'tenant_evaluations', COUNT(*) FROM tenant_evaluations
UNION ALL SELECT 'evaluation_submissions', COUNT(*) FROM evaluation_submissions
UNION ALL SELECT 'editing_locks', COUNT(*) FROM editing_locks
UNION ALL SELECT 'audit_logs', COUNT(*) FROM audit_logs
ORDER BY table_name;

-- Fin de los datos de prueba.
