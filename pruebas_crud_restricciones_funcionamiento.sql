--PRUEBAS_CRUD_RESTRICCIONES_FUNCIONAMIENTO.sql
-- Proyecto SST / PESV - PostgreSQL
-- ============================================================
-- OBJETIVO
-- Demostrar:
--   1. Operaciones CRUD.
--   2. Restricciones de integridad.
--   3. Procedimientos almacenados.
--   4. Funciones.
--   5. Triggers.
--   6. Auditoria.
--   7. Vistas y vistas materializadas.
--
-- IMPORTANTE:
-- El archivo inicia con BEGIN y termina con ROLLBACK.
-- Por eso las pruebas se ejecutan, pero al final NO quedan
-- guardados los datos de prueba.
--
-- ORDEN RECOMENDADO ANTES DE EJECUTAR ESTE ARCHIVO:
--   1. DDL
--   2. DML
--   3. DML UPDATED
--   4. Vistas y vistas materializadas
--   5. Procedimientos
--   6. Funciones
--   7. Triggers
-- ============================================================


BEGIN;


-- ============================================================
-- 0. VERIFICACION INICIAL
-- ============================================================

SELECT 'Tenants existentes' AS prueba, COUNT(*) AS resultado
FROM tenants;

SELECT 'Personas existentes' AS prueba, COUNT(*) AS resultado
FROM persons;

SELECT 'Modulos existentes' AS prueba, COUNT(*) AS resultado
FROM modules;

SELECT 'Plantillas asignadas' AS prueba, COUNT(*) AS resultado
FROM tenanttemplates;



-- ============================================================
-- 1. PRUEBAS CRUD
-- ============================================================


-- ------------------------------------------------------------
-- 1.1 CREATE - Crear una organizacion de prueba
-- DEBE FUNCIONAR
-- ------------------------------------------------------------

INSERT INTO tenants (
    tenant_size_id,
    municipality_id,
    legal_name,
    identification_type,
    identification_number,
    contact_email,
    phone,
    address
)
VALUES (
    (SELECT tenant_size_id
     FROM tenant_sizes
     ORDER BY tenant_size_id
     LIMIT 1),

    (SELECT municipality_id
     FROM municipalities
     ORDER BY municipality_id
     LIMIT 1),

    'Empresa CRUD Prueba SAS',
    'NIT',
    'TEST-CRUD-001',
    'crud@prueba.com',
    '3009990001',
    'Direccion inicial'
);


-- ------------------------------------------------------------
-- 1.2 READ - Consultar la organizacion creada
-- DEBE DEVOLVER 1 FILA
-- ------------------------------------------------------------

SELECT
    tenant_id,
    legal_name,
    identification_number,
    contact_email,
    phone,
    address,
    is_active
FROM tenants
WHERE identification_number = 'TEST-CRUD-001';



-- ------------------------------------------------------------
-- 1.3 UPDATE - Modificar datos de contacto
-- DEBE FUNCIONAR
-- Tambien prueba el trigger updated_at y la auditoria.
-- ------------------------------------------------------------

UPDATE tenants
SET contact_email = 'crud.actualizado@prueba.com',
    phone = '3009990002',
    address = 'Direccion actualizada'
WHERE identification_number = 'TEST-CRUD-001';


SELECT
    legal_name,
    contact_email,
    phone,
    address,
    updated_at
FROM tenants
WHERE identification_number = 'TEST-CRUD-001';



-- ------------------------------------------------------------
-- Crear dos cargos para las siguientes pruebas
-- ------------------------------------------------------------

INSERT INTO positions (
    tenant_id,
    name,
    description
)
SELECT
    tenant_id,
    'Cargo Prueba A',
    'Cargo utilizado en las pruebas'
FROM tenants
WHERE identification_number = 'TEST-CRUD-001';


INSERT INTO positions (
    tenant_id,
    name,
    description
)
SELECT
    tenant_id,
    'Cargo Prueba B',
    'Segundo cargo utilizado en las pruebas'
FROM tenants
WHERE identification_number = 'TEST-CRUD-001';



-- ------------------------------------------------------------
-- Crear una persona para las pruebas
-- ------------------------------------------------------------

INSERT INTO persons (
    tenant_id,
    first_name,
    last_name,
    identification_number,
    email,
    phone
)
SELECT
    tenant_id,
    'Persona',
    'CRUD',
    'TEST-PERSON-001',
    'persona.crud@prueba.com',
    '3010000001'
FROM tenants
WHERE identification_number = 'TEST-CRUD-001';


INSERT INTO person_position_assignments (
    person_id,
    position_id,
    started_at
)
VALUES (
    (
        SELECT person_id
        FROM persons
        WHERE email = 'persona.crud@prueba.com'
    ),
    (
        SELECT p.position_id
        FROM positions p
        INNER JOIN tenants t
            ON p.tenant_id = t.tenant_id
        WHERE t.identification_number = 'TEST-CRUD-001'
          AND p.name = 'Cargo Prueba A'
    ),
    CURRENT_DATE
);



-- ------------------------------------------------------------
-- 1.4 DELETE - Crear y eliminar una persona temporal
-- DEBE FUNCIONAR
-- ------------------------------------------------------------

INSERT INTO persons (
    tenant_id,
    first_name,
    last_name,
    identification_number,
    email
)
SELECT
    tenant_id,
    'Temporal',
    'Eliminar',
    'TEST-PERSON-DELETE',
    'temporal.eliminar@prueba.com'
FROM tenants
WHERE identification_number = 'TEST-CRUD-001';


DELETE FROM persons
WHERE email = 'temporal.eliminar@prueba.com';


SELECT
    COUNT(*) AS registros_restantes
FROM persons
WHERE email = 'temporal.eliminar@prueba.com';

-- Resultado esperado: 0



-- ============================================================
-- 2. PRUEBAS DE RESTRICCIONES
-- ============================================================
-- Las siguientes pruebas DEBEN FALLAR.
-- Se usa EXCEPTION para capturar el error esperado y continuar.


-- ------------------------------------------------------------
-- 2.1 UNIQUE - Identificacion de organizacion duplicada
-- DEBE FALLAR
-- ------------------------------------------------------------

DO $$
BEGIN
    BEGIN
        INSERT INTO tenants (
            tenant_size_id,
            municipality_id,
            legal_name,
            identification_type,
            identification_number,
            contact_email,
            phone
        )
        VALUES (
            (SELECT tenant_size_id
             FROM tenant_sizes
             ORDER BY tenant_size_id
             LIMIT 1),

            (SELECT municipality_id
             FROM municipalities
             ORDER BY municipality_id
             LIMIT 1),

            'Empresa Duplicada',
            'NIT',
            'TEST-CRUD-001',
            'duplicado@prueba.com',
            '3001111111'
        );

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se permitio una identificacion duplicada';

    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE
                'OK UNIQUE: la identificacion duplicada fue rechazada';
    END;
END;
$$;



-- ------------------------------------------------------------
-- 2.2 NOT NULL - legal_name obligatorio
-- DEBE FALLAR
-- ------------------------------------------------------------

DO $$
BEGIN
    BEGIN
        INSERT INTO tenants (
            tenant_size_id,
            municipality_id,
            legal_name,
            identification_type,
            identification_number,
            contact_email,
            phone
        )
        VALUES (
            (SELECT tenant_size_id
             FROM tenant_sizes
             ORDER BY tenant_size_id
             LIMIT 1),

            (SELECT municipality_id
             FROM municipalities
             ORDER BY municipality_id
             LIMIT 1),

            NULL,
            'NIT',
            'TEST-NULL-001',
            'null@prueba.com',
            '3001111112'
        );

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se permitio legal_name NULL';

    EXCEPTION
        WHEN not_null_violation THEN
            RAISE NOTICE
                'OK NOT NULL: PostgreSQL rechazo legal_name NULL';
    END;
END;
$$;



-- ------------------------------------------------------------
-- 2.3 FOREIGN KEY - municipio inexistente
-- DEBE FALLAR
-- ------------------------------------------------------------

DO $$
BEGIN
    BEGIN
        INSERT INTO tenants (
            tenant_size_id,
            municipality_id,
            legal_name,
            identification_type,
            identification_number,
            contact_email,
            phone
        )
        VALUES (
            (SELECT tenant_size_id
             FROM tenant_sizes
             ORDER BY tenant_size_id
             LIMIT 1),

            999999999,
            'Empresa FK Prueba',
            'NIT',
            'TEST-FK-001',
            'fk@prueba.com',
            '3001111113'
        );

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se permitio una FK inexistente';

    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE
                'OK FOREIGN KEY: el municipio inexistente fue rechazado';
    END;
END;
$$;



-- ------------------------------------------------------------
-- 2.4 CHECK - rango de empleados invalido
-- DEBE FALLAR
-- ------------------------------------------------------------

DO $$
BEGIN
    BEGIN
        INSERT INTO tenant_sizes (
            name,
            min_employees,
            max_employees
        )
        VALUES (
            'TAMANO CHECK PRUEBA',
            -1,
            10
        );

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se permitio min_employees negativo';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK CHECK: min_employees negativo fue rechazado';
    END;
END;
$$;



-- ------------------------------------------------------------
-- 2.5 CHECK - fecha final anterior a fecha inicial
-- DEBE FALLAR
-- ------------------------------------------------------------

DO $$
BEGIN
    BEGIN
        INSERT INTO person_position_assignments (
            person_id,
            position_id,
            started_at,
            ended_at
        )
        VALUES (
            (
                SELECT person_id
                FROM persons
                WHERE email = 'persona.crud@prueba.com'
            ),
            (
                SELECT p.position_id
                FROM positions p
                INNER JOIN tenants t
                    ON p.tenant_id = t.tenant_id
                WHERE t.identification_number = 'TEST-CRUD-001'
                  AND p.name = 'Cargo Prueba B'
            ),
            DATE '2026-09-20',
            DATE '2026-09-19'
        );

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se permitio una fecha final invalida';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK CHECK: ended_at anterior a started_at fue rechazado';
    END;
END;
$$;



-- ------------------------------------------------------------
-- 2.6 CHECK JSONB - settings debe ser un objeto JSON
-- DEBE FALLAR
-- ------------------------------------------------------------

DO $$
BEGIN
    BEGIN
        INSERT INTO tenant_settings (
            tenant_id,
            settings
        )
        VALUES (
            (
                SELECT tenant_id
                FROM tenants
                WHERE identification_number = 'TEST-CRUD-001'
            ),
            '[]'::JSONB
        );

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se permitio JSONB que no es objeto';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK JSONB CHECK: settings que no era objeto fue rechazado';
    END;
END;
$$;



-- ------------------------------------------------------------
-- 2.7 INDICE UNICO PARCIAL - un solo cargo activo por persona
-- DEBE FALLAR
-- ------------------------------------------------------------

DO $$
BEGIN
    BEGIN
        INSERT INTO person_position_assignments (
            person_id,
            position_id,
            started_at
        )
        VALUES (
            (
                SELECT person_id
                FROM persons
                WHERE email = 'persona.crud@prueba.com'
            ),
            (
                SELECT p.position_id
                FROM positions p
                INNER JOIN tenants t
                    ON p.tenant_id = t.tenant_id
                WHERE t.identification_number = 'TEST-CRUD-001'
                  AND p.name = 'Cargo Prueba B'
            ),
            CURRENT_DATE
        );

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se permitieron dos cargos activos';

    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE
                'OK INDICE UNICO: no se permitieron dos cargos activos';
    END;
END;
$$;



-- ============================================================
-- 3. PRUEBAS DE PROCEDIMIENTOS ALMACENADOS
-- ============================================================


-- ------------------------------------------------------------
-- PROCEDIMIENTO 1
-- Registrar nueva organizacion
-- DEBE FUNCIONAR
-- ------------------------------------------------------------

CALL sp_registrar_tenant(
    (SELECT tenant_size_id
     FROM tenant_sizes
     ORDER BY tenant_size_id
     LIMIT 1),

    (SELECT municipality_id
     FROM municipalities
     ORDER BY municipality_id
     LIMIT 1),

    'Empresa Procedimientos SAS',
    'NIT',
    'TEST-PROC-001',
    'procedimientos@prueba.com',
    '3020000001',
    'Direccion procedimientos'
);


SELECT
    tenant_id,
    legal_name,
    identification_number
FROM tenants
WHERE identification_number = 'TEST-PROC-001';



-- Crear dos cargos para probar procedimientos 2, 7 y 8.

INSERT INTO positions (
    tenant_id,
    name,
    description
)
SELECT
    tenant_id,
    'Analista Procedimientos',
    'Cargo inicial de prueba'
FROM tenants
WHERE identification_number = 'TEST-PROC-001';


INSERT INTO positions (
    tenant_id,
    name,
    description
)
SELECT
    tenant_id,
    'Coordinador Procedimientos',
    'Cargo para cambio de cargo'
FROM tenants
WHERE identification_number = 'TEST-PROC-001';



-- ------------------------------------------------------------
-- PROCEDIMIENTO 2
-- Registrar persona y asociarla a un cargo
-- DEBE FUNCIONAR
-- ------------------------------------------------------------

CALL sp_registrar_persona(
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-PROC-001'
    ),
    (
        SELECT p.position_id
        FROM positions p
        INNER JOIN tenants t
            ON p.tenant_id = t.tenant_id
        WHERE t.identification_number = 'TEST-PROC-001'
          AND p.name = 'Analista Procedimientos'
    ),
    'Carlos',
    'Procedimiento',
    'TEST-PROC-PERSON-001',
    'carlos.procedimiento@prueba.com',
    '3020000002'
);



-- ------------------------------------------------------------
-- PROCEDIMIENTO 3
-- Cambiar estado de organizacion
-- Se ejecuta dos veces para regresar al estado original.
-- ------------------------------------------------------------

CALL sp_cambiar_estado_tenant(
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-PROC-001'
    )
);

CALL sp_cambiar_estado_tenant(
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-PROC-001'
    )
);



-- ------------------------------------------------------------
-- PROCEDIMIENTO 5
-- Habilitar sistema SST
-- DEBE FUNCIONAR
-- ------------------------------------------------------------

CALL sp_habilitar_sistema(
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-PROC-001'
    ),
    (
        SELECT system_id
        FROM type_system_sst
        WHERE code = 'SST'
    )
);



-- ------------------------------------------------------------
-- PROCEDIMIENTO 4
-- Asignar modulo SST
-- DEBE FUNCIONAR
-- ------------------------------------------------------------

CALL sp_asignar_modulo(
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-PROC-001'
    ),
    (
        SELECT m.module_id
        FROM modules m
        INNER JOIN type_system_sst s
            ON m.system_id = s.system_id
        WHERE s.code = 'SST'
        ORDER BY m.display_order
        LIMIT 1
    )
);



-- ------------------------------------------------------------
-- PROCEDIMIENTO 6
-- Asignar plantilla
-- DEBE FUNCIONAR
-- ------------------------------------------------------------

CALL sp_asignar_plantilla(
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-PROC-001'
    ),
    (
        SELECT template_id
        FROM templates
        WHERE is_active = TRUE
        ORDER BY template_id
        LIMIT 1
    ),
    (
        SELECT system_id
        FROM type_system_sst
        WHERE code = 'SST'
    ),
    (
        SELECT phva_stage_id
        FROM phva_stages
        WHERE code = 'PLAN'
    ),
    (
        SELECT f.format_id
        FROM formats_sst f
        INNER JOIN modules m
            ON f.module_id = m.module_id
        INNER JOIN type_system_sst s
            ON m.system_id = s.system_id
        WHERE s.code = 'SST'
          AND f.is_active = TRUE
        ORDER BY f.format_id
        LIMIT 1
    )
);



-- ------------------------------------------------------------
-- PROCEDIMIENTO 7
-- Cambiar cargo de persona
-- DEBE CERRAR EL CARGO ANTERIOR Y CREAR EL NUEVO.
-- ------------------------------------------------------------

CALL sp_cambiar_cargo_persona(
    (
        SELECT person_id
        FROM persons
        WHERE email = 'carlos.procedimiento@prueba.com'
    ),
    (
        SELECT p.position_id
        FROM positions p
        INNER JOIN tenants t
            ON p.tenant_id = t.tenant_id
        WHERE t.identification_number = 'TEST-PROC-001'
          AND p.name = 'Coordinador Procedimientos'
    )
);


SELECT
    p.email,
    pos.name AS cargo,
    ppa.started_at,
    ppa.ended_at
FROM persons p
INNER JOIN person_position_assignments ppa
    ON p.person_id = ppa.person_id
INNER JOIN positions pos
    ON ppa.position_id = pos.position_id
WHERE p.email = 'carlos.procedimiento@prueba.com'
ORDER BY ppa.assignment_id;



-- ------------------------------------------------------------
-- PROCEDIMIENTO 8
-- Trasladar persona a otra organizacion
-- DEBE FUNCIONAR
-- ------------------------------------------------------------

CALL sp_trasladar_persona(
    (
        SELECT person_id
        FROM persons
        WHERE email = 'carlos.procedimiento@prueba.com'
    ),
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-CRUD-001'
    ),
    (
        SELECT p.position_id
        FROM positions p
        INNER JOIN tenants t
            ON p.tenant_id = t.tenant_id
        WHERE t.identification_number = 'TEST-CRUD-001'
          AND p.name = 'Cargo Prueba B'
    )
);


SELECT
    p.first_name,
    p.last_name,
    t.legal_name AS nueva_organizacion,
    pos.name AS nuevo_cargo
FROM persons p
INNER JOIN tenants t
    ON p.tenant_id = t.tenant_id
LEFT JOIN person_position_assignments ppa
    ON p.person_id = ppa.person_id
   AND ppa.ended_at IS NULL
LEFT JOIN positions pos
    ON ppa.position_id = pos.position_id
WHERE p.email = 'carlos.procedimiento@prueba.com';



-- ------------------------------------------------------------
-- PROCEDIMIENTO 11
-- Mostrar total de plantillas
-- ------------------------------------------------------------

CALL sp_total_plantillas_tenant(
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-PROC-001'
    )
);



-- ------------------------------------------------------------
-- PROCEDIMIENTO 12
-- Mostrar porcentaje de cumplimiento
-- ------------------------------------------------------------

CALL sp_calcular_cumplimiento_tenant(
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-PROC-001'
    )
);



-- ------------------------------------------------------------
-- PROCEDIMIENTO 13
-- Documentos por etapa PHVA
-- ------------------------------------------------------------

CALL sp_documentos_por_phva(
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-PROC-001'
    ),
    (
        SELECT phva_stage_id
        FROM phva_stages
        WHERE code = 'PLAN'
    )
);



-- ------------------------------------------------------------
-- PROCEDIMIENTO 14
-- Actualizar contacto
-- ------------------------------------------------------------

CALL sp_actualizar_contacto_tenant(
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-PROC-001'
    ),
    'procedimientos.actualizado@prueba.com',
    '3020000099',
    'Direccion actualizada por procedimiento'
);



-- ------------------------------------------------------------
-- PROCEDIMIENTO 15
-- Manejo de excepciones al asignar plantilla
-- Se intenta asignar nuevamente la misma plantilla.
-- El procedimiento debe controlar el error.
-- ------------------------------------------------------------

CALL sp_asignar_plantilla_segura(
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-PROC-001'
    ),
    (
        SELECT template_id
        FROM templates
        WHERE is_active = TRUE
        ORDER BY template_id
        LIMIT 1
    ),
    (
        SELECT system_id
        FROM type_system_sst
        WHERE code = 'SST'
    ),
    (
        SELECT phva_stage_id
        FROM phva_stages
        WHERE code = 'PLAN'
    ),
    (
        SELECT f.format_id
        FROM formats_sst f
        INNER JOIN modules m
            ON f.module_id = m.module_id
        INNER JOIN type_system_sst s
            ON m.system_id = s.system_id
        WHERE s.code = 'SST'
          AND f.is_active = TRUE
        ORDER BY f.format_id
        LIMIT 1
    )
);



-- ------------------------------------------------------------
-- PROCEDIMIENTO 10
-- Eliminar asignacion de modulo con dependencias
-- DEBE FALLAR porque la plantilla utiliza un formato del modulo.
-- ------------------------------------------------------------

DO $$
DECLARE
    v_tenant_id BIGINT;
    v_module_id BIGINT;
BEGIN
    SELECT tenant_id
    INTO v_tenant_id
    FROM tenants
    WHERE identification_number = 'TEST-PROC-001';

    SELECT m.module_id
    INTO v_module_id
    FROM modules m
    INNER JOIN type_system_sst s
        ON m.system_id = s.system_id
    WHERE s.code = 'SST'
    ORDER BY m.display_order
    LIMIT 1;

    BEGIN
        CALL sp_eliminar_asignacion_modulo(
            v_tenant_id,
            v_module_id
        );

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se elimino un modulo con dependencias';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE
                'OK PROCEDIMIENTO 10: eliminacion controlada -> %',
                SQLERRM;
    END;
END;
$$;



-- ------------------------------------------------------------
-- PROCEDIMIENTO 9
-- Deshabilitar modulos de una organizacion inactiva
-- ------------------------------------------------------------

-- Primero se marca inactiva.
UPDATE tenants
SET is_active = FALSE
WHERE identification_number = 'TEST-PROC-001';


CALL sp_deshabilitar_modulos_tenant(
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-PROC-001'
    )
);


SELECT
    t.legal_name,
    tm.module_id,
    tm.is_active
FROM tenants t
INNER JOIN tenant_modules tm
    ON t.tenant_id = tm.tenant_id
WHERE t.identification_number = 'TEST-PROC-001';



-- Se reactiva para continuar otras pruebas.
UPDATE tenants
SET is_active = TRUE
WHERE identification_number = 'TEST-PROC-001';



-- ============================================================
-- 4. PRUEBAS DE LAS 8 FUNCIONES
-- ============================================================
-- Se usa Transportes del Magdalena porque tiene datos completos.


-- 4.1 Total de personas
SELECT
    fn_total_personas_tenant(
        (
            SELECT tenant_id
            FROM tenants
            WHERE identification_number = '901000001-1'
        )
    ) AS total_personas;


-- 4.2 Porcentaje de cumplimiento
SELECT
    fn_porcentaje_cumplimiento(
        (
            SELECT tenant_id
            FROM tenants
            WHERE identification_number = '901000001-1'
        )
    ) AS porcentaje_cumplimiento;


-- 4.3 Verificar modulo habilitado
SELECT
    fn_tiene_modulo(
        (
            SELECT tenant_id
            FROM tenants
            WHERE identification_number = '901000001-1'
        ),
        (
            SELECT tm.module_id
            FROM tenant_modules tm
            INNER JOIN tenants t
                ON tm.tenant_id = t.tenant_id
            WHERE t.identification_number = '901000001-1'
              AND tm.is_active = TRUE
            LIMIT 1
        )
    ) AS tiene_modulo;


-- 4.4 Nombre completo de persona
SELECT
    fn_nombre_completo_persona(
        (
            SELECT person_id
            FROM persons
            WHERE tenant_id = (
                SELECT tenant_id
                FROM tenants
                WHERE identification_number = '901000001-1'
            )
            ORDER BY person_id
            LIMIT 1
        )
    ) AS nombre_completo;


-- 4.5 Plantillas por etapa PHVA
SELECT
    fn_total_plantillas_phva(
        (
            SELECT tenant_id
            FROM tenants
            WHERE identification_number = '901000001-1'
        ),
        (
            SELECT phva_stage_id
            FROM phva_stages
            WHERE code = 'PLAN'
        )
    ) AS plantillas_planear;


-- 4.6 Funcion tabular: modulos
SELECT *
FROM fn_modulos_tenant(
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = '901000001-1'
    )
);


-- 4.7 Funcion tabular: personas y cargos
SELECT *
FROM fn_personas_cargos_tenant(
    (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = '901000001-1'
    )
);


-- 4.8 Nivel de cumplimiento
SELECT
    fn_nivel_cumplimiento(
        (
            SELECT tenant_id
            FROM tenants
            WHERE identification_number = '901000001-1'
        )
    ) AS nivel_cumplimiento;



-- ============================================================
-- 5. PRUEBAS DE TRIGGERS
-- ============================================================


-- ------------------------------------------------------------
-- TRIGGER 1
-- updated_at de tenants
-- DEBE CAMBIAR AUTOMATICAMENTE
-- ------------------------------------------------------------

DO $$
DECLARE
    v_tenant_id BIGINT;
    v_antes TIMESTAMPTZ;
    v_despues TIMESTAMPTZ;
BEGIN
    SELECT tenant_id, updated_at
    INTO v_tenant_id, v_antes
    FROM tenants
    WHERE identification_number = 'TEST-CRUD-001';

    PERFORM pg_sleep(0.02);

    UPDATE tenants
    SET phone = '3009990099'
    WHERE tenant_id = v_tenant_id;

    SELECT updated_at
    INTO v_despues
    FROM tenants
    WHERE tenant_id = v_tenant_id;

    IF v_despues > v_antes THEN
        RAISE NOTICE
            'OK TRIGGER 1: updated_at de tenants fue actualizado';
    ELSE
        RAISE EXCEPTION
            'FALLO TRIGGER 1: updated_at no cambio';
    END IF;
END;
$$;



-- ------------------------------------------------------------
-- TRIGGER 2
-- updated_at de persons
-- ------------------------------------------------------------

DO $$
DECLARE
    v_person_id BIGINT;
    v_antes TIMESTAMPTZ;
    v_despues TIMESTAMPTZ;
BEGIN
    SELECT person_id, updated_at
    INTO v_person_id, v_antes
    FROM persons
    WHERE email = 'persona.crud@prueba.com';

    PERFORM pg_sleep(0.02);

    UPDATE persons
    SET phone = '3010000099'
    WHERE person_id = v_person_id;

    SELECT updated_at
    INTO v_despues
    FROM persons
    WHERE person_id = v_person_id;

    IF v_despues > v_antes THEN
        RAISE NOTICE
            'OK TRIGGER 2: updated_at de persons fue actualizado';
    ELSE
        RAISE EXCEPTION
            'FALLO TRIGGER 2: updated_at no cambio';
    END IF;
END;
$$;



-- ------------------------------------------------------------
-- TRIGGER 3
-- No registrar personas en organizacion inactiva
-- DEBE FALLAR
-- ------------------------------------------------------------

UPDATE tenants
SET is_active = FALSE
WHERE identification_number = 'TEST-CRUD-001';


DO $$
BEGIN
    BEGIN
        INSERT INTO persons (
            tenant_id,
            first_name,
            last_name,
            identification_number,
            email
        )
        SELECT
            tenant_id,
            'Persona',
            'Bloqueada',
            'TEST-INACTIVE-001',
            'inactiva@prueba.com'
        FROM tenants
        WHERE identification_number = 'TEST-CRUD-001';

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se permitio persona en tenant inactivo';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE
                'OK TRIGGER 3: persona rechazada -> %',
                SQLERRM;
    END;
END;
$$;


UPDATE tenants
SET is_active = TRUE
WHERE identification_number = 'TEST-CRUD-001';



-- ------------------------------------------------------------
-- TRIGGER 4
-- Modulo duplicado
-- DEBE FALLAR
-- ------------------------------------------------------------

DO $$
DECLARE
    v_tenant_id BIGINT;
    v_module_id BIGINT;
BEGIN
    SELECT tenant_id
    INTO v_tenant_id
    FROM tenants
    WHERE identification_number = 'TEST-PROC-001';

    SELECT module_id
    INTO v_module_id
    FROM tenant_modules
    WHERE tenant_id = v_tenant_id
    LIMIT 1;

    BEGIN
        INSERT INTO tenant_modules (
            tenant_id,
            module_id
        )
        VALUES (
            v_tenant_id,
            v_module_id
        );

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se permitio modulo duplicado';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE
                'OK TRIGGER 4: modulo duplicado rechazado -> %',
                SQLERRM;
    END;
END;
$$;



-- ------------------------------------------------------------
-- TRIGGER 5
-- Plantilla en organizacion inactiva
-- DEBE FALLAR
-- ------------------------------------------------------------

UPDATE tenants
SET is_active = FALSE
WHERE identification_number = 'TEST-CRUD-001';


DO $$
BEGIN
    BEGIN
        INSERT INTO tenanttemplates (
            tenant_id,
            template_id,
            format_id,
            phva_stage_id
        )
        VALUES (
            (
                SELECT tenant_id
                FROM tenants
                WHERE identification_number = 'TEST-CRUD-001'
            ),
            (
                SELECT template_id
                FROM templates
                ORDER BY template_id
                LIMIT 1
            ),
            (
                SELECT format_id
                FROM formats_sst
                ORDER BY format_id
                LIMIT 1
            ),
            (
                SELECT phva_stage_id
                FROM phva_stages
                WHERE code = 'PLAN'
            )
        );

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se permitio plantilla en tenant inactivo';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE
                'OK TRIGGER 5: plantilla rechazada -> %',
                SQLERRM;
    END;
END;
$$;


UPDATE tenants
SET is_active = TRUE
WHERE identification_number = 'TEST-CRUD-001';



-- ------------------------------------------------------------
-- TRIGGER 6
-- Persona y cargo deben pertenecer al mismo tenant
-- DEBE FALLAR
-- ------------------------------------------------------------

DO $$
BEGIN
    BEGIN
        INSERT INTO person_position_assignments (
            person_id,
            position_id,
            started_at
        )
        VALUES (
            (
                SELECT person_id
                FROM persons
                WHERE email = 'persona.crud@prueba.com'
            ),
            (
                SELECT p.position_id
                FROM positions p
                INNER JOIN tenants t
                    ON p.tenant_id = t.tenant_id
                WHERE t.identification_number = 'TEST-PROC-001'
                ORDER BY p.position_id
                LIMIT 1
            ),
            CURRENT_DATE
        );

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se permitio cargo de otro tenant';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE
                'OK TRIGGER 6: cargo de otro tenant rechazado -> %',
                SQLERRM;
    END;
END;
$$;



-- ------------------------------------------------------------
-- TRIGGER 7
-- updated_at de tenanttemplates
-- ------------------------------------------------------------

DO $$
DECLARE
    v_id BIGINT;
    v_antes TIMESTAMPTZ;
    v_despues TIMESTAMPTZ;
BEGIN
    SELECT tenant_template_id, updated_at
    INTO v_id, v_antes
    FROM tenanttemplates tt
    INNER JOIN tenants t
        ON tt.tenant_id = t.tenant_id
    WHERE t.identification_number = 'TEST-PROC-001'
    LIMIT 1;

    PERFORM pg_sleep(0.02);

    UPDATE tenanttemplates
    SET is_active = NOT is_active
    WHERE tenant_template_id = v_id;

    SELECT updated_at
    INTO v_despues
    FROM tenanttemplates
    WHERE tenant_template_id = v_id;

    IF v_despues > v_antes THEN
        RAISE NOTICE
            'OK TRIGGER 7: updated_at de tenanttemplates fue actualizado';
    ELSE
        RAISE EXCEPTION
            'FALLO TRIGGER 7: updated_at no cambio';
    END IF;
END;
$$;



-- ------------------------------------------------------------
-- TRIGGER 8
-- No eliminar tenant con personas
-- DEBE FALLAR
-- ------------------------------------------------------------

DO $$
BEGIN
    BEGIN
        DELETE FROM tenants
        WHERE identification_number = 'TEST-CRUD-001';

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se elimino tenant con personas';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE
                'OK TRIGGER 8: tenant con personas no fue eliminado -> %',
                SQLERRM;
    END;
END;
$$;



-- ------------------------------------------------------------
-- TRIGGER 9
-- No eliminar sistema utilizado por organizaciones
-- DEBE FALLAR
-- ------------------------------------------------------------

DO $$
BEGIN
    BEGIN
        DELETE FROM type_system_sst
        WHERE code = 'SST';

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se elimino sistema en uso';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE
                'OK TRIGGER 9: sistema en uso no fue eliminado -> %',
                SQLERRM;
    END;
END;
$$;



-- ------------------------------------------------------------
-- TRIGGER 10
-- No eliminar modulo asignado
-- DEBE FALLAR
-- ------------------------------------------------------------

DO $$
DECLARE
    v_module_id BIGINT;
BEGIN
    SELECT module_id
    INTO v_module_id
    FROM tenant_modules
    LIMIT 1;

    BEGIN
        DELETE FROM modules
        WHERE module_id = v_module_id;

        RAISE EXCEPTION
            'ERROR DE PRUEBA: se elimino modulo asignado';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE
                'OK TRIGGER 10: modulo asignado no fue eliminado -> %',
                SQLERRM;
    END;
END;
$$;



-- ------------------------------------------------------------
-- TRIGGER 11
-- Cumplimiento debe permanecer entre 0 y 100
-- La formula del modelo no puede producir un valor fuera del rango.
-- Se modifica un documento para ejecutar el trigger y se verifica
-- el resultado calculado.
-- ------------------------------------------------------------

DO $$
DECLARE
    v_document_id BIGINT;
    v_tenant_id BIGINT;
    v_porcentaje NUMERIC(5,2);
BEGIN
    SELECT d.document_id, tt.tenant_id
    INTO v_document_id, v_tenant_id
    FROM documents d
    INNER JOIN tenanttemplates tt
        ON d.tenant_template_id = tt.tenant_template_id
    ORDER BY d.document_id
    LIMIT 1;

    UPDATE documents
    SET document_status_id = document_status_id
    WHERE document_id = v_document_id;

    v_porcentaje := fn_porcentaje_cumplimiento(v_tenant_id);

    IF v_porcentaje BETWEEN 0 AND 100 THEN
        RAISE NOTICE
            'OK TRIGGER 11: cumplimiento valido = %',
            v_porcentaje;
    ELSE
        RAISE EXCEPTION
            'FALLO TRIGGER 11: porcentaje fuera de rango';
    END IF;
END;
$$;



-- ------------------------------------------------------------
-- TRIGGER 12
-- Auditoria de datos principales de tenants
-- ------------------------------------------------------------

UPDATE tenants
SET contact_email = 'auditoria@prueba.com'
WHERE identification_number = 'TEST-CRUD-001';


SELECT
    audit_log_id,
    tenant_id,
    table_name,
    operation,
    old_data,
    new_data,
    changed_at
FROM audit_logs
WHERE tenant_id = (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-CRUD-001'
    )
  AND table_name = 'tenants'
ORDER BY audit_log_id DESC
LIMIT 5;



-- ------------------------------------------------------------
-- TRIGGER 13
-- Auditoria del cambio de estado
-- ------------------------------------------------------------

UPDATE tenants
SET is_active = FALSE
WHERE identification_number = 'TEST-CRUD-001';

UPDATE tenants
SET is_active = TRUE
WHERE identification_number = 'TEST-CRUD-001';


SELECT
    audit_log_id,
    old_data,
    new_data,
    changed_at
FROM audit_logs
WHERE tenant_id = (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-CRUD-001'
    )
  AND table_name = 'tenants'
  AND old_data ? 'is_active'
ORDER BY audit_log_id DESC
LIMIT 5;



-- ------------------------------------------------------------
-- TRIGGER 14
-- Auditoria de modificacion de plantilla
-- Debe registrar fecha y CURRENT_USER.
-- ------------------------------------------------------------

UPDATE tenanttemplates
SET is_active = NOT is_active
WHERE tenant_template_id = (
    SELECT tt.tenant_template_id
    FROM tenanttemplates tt
    INNER JOIN tenants t
        ON tt.tenant_id = t.tenant_id
    WHERE t.identification_number = 'TEST-PROC-001'
    LIMIT 1
);


SELECT
    audit_log_id,
    table_name,
    record_identifier,
    new_data ->> 'database_user' AS usuario_bd,
    changed_at
FROM audit_logs
WHERE table_name = 'tenanttemplates'
  AND tenant_id = (
        SELECT tenant_id
        FROM tenants
        WHERE identification_number = 'TEST-PROC-001'
    )
ORDER BY audit_log_id DESC
LIMIT 5;



-- ------------------------------------------------------------
-- TRIGGER 15
-- Desactivar bloqueos vencidos
-- ------------------------------------------------------------
-- Se crea primero un documento de prueba.

INSERT INTO documents (
    tenant_template_id,
    document_status_id,
    title
)
VALUES (
    (
        SELECT tt.tenant_template_id
        FROM tenanttemplates tt
        INNER JOIN tenants t
            ON tt.tenant_id = t.tenant_id
        WHERE t.identification_number = 'TEST-PROC-001'
        LIMIT 1
    ),
    (
        SELECT document_status_id
        FROM document_statuses
        WHERE code = 'DRAFT'
    ),
    'Documento para prueba de bloqueos'
);


-- Se crea un bloqueo que ya esta vencido.
-- locked_at y expires_at estan en el pasado,
-- pero expires_at sigue siendo posterior a locked_at.

INSERT INTO editing_locks (
    document_id,
    locked_by_person_id,
    locked_at,
    expires_at,
    is_active
)
VALUES (
    (
        SELECT document_id
        FROM documents
        WHERE title = 'Documento para prueba de bloqueos'
        ORDER BY document_id DESC
        LIMIT 1
    ),
    (
        SELECT person_id
        FROM persons
        WHERE email = 'persona.crud@prueba.com'
    ),
    CURRENT_TIMESTAMP - INTERVAL '2 hours',
    CURRENT_TIMESTAMP - INTERVAL '1 hour',
    TRUE
);


-- Al insertar un nuevo bloqueo, el trigger debe marcar
-- el bloqueo anterior como inactivo.

INSERT INTO editing_locks (
    document_id,
    locked_by_person_id,
    expires_at,
    is_active
)
VALUES (
    (
        SELECT document_id
        FROM documents
        WHERE title = 'Documento para prueba de bloqueos'
        ORDER BY document_id DESC
        LIMIT 1
    ),
    (
        SELECT person_id
        FROM persons
        WHERE email = 'persona.crud@prueba.com'
    ),
    CURRENT_TIMESTAMP + INTERVAL '30 minutes',
    TRUE
);


SELECT
    editing_lock_id,
    document_id,
    locked_at,
    expires_at,
    is_active
FROM editing_locks
WHERE document_id = (
    SELECT document_id
    FROM documents
    WHERE title = 'Documento para prueba de bloqueos'
    ORDER BY document_id DESC
    LIMIT 1
)
ORDER BY editing_lock_id;

-- Resultado esperado:
-- bloqueo vencido    -> is_active = FALSE
-- bloqueo nuevo      -> is_active = TRUE



-- ============================================================
-- 6. PRUEBA DE VISTAS
-- ============================================================

SELECT *
FROM vw_tenant_persons
LIMIT 10;


SELECT *
FROM vw_tenant_geography
LIMIT 10;


SELECT *
FROM vw_tenant_modules
LIMIT 10;


SELECT *
FROM vw_tenant_templates_phva
LIMIT 10;


SELECT *
FROM vw_tenant_persons_by_position
LIMIT 10;


SELECT *
FROM vw_tenant_summary
LIMIT 10;



-- ============================================================
-- 7. PRUEBA DE VISTAS MATERIALIZADAS
-- ============================================================
-- Primero se actualizan para reflejar los cambios de la prueba.

REFRESH MATERIALIZED VIEW vm_template_sst_docs_summary;
REFRESH MATERIALIZED VIEW vm_template_pesv_docs_summary;


SELECT *
FROM vm_template_sst_docs_summary
ORDER BY tenant_id;


SELECT *
FROM vm_template_pesv_docs_summary
ORDER BY tenant_id;



-- ============================================================
-- 8. VERIFICACION DE AUDITORIA
-- ============================================================

SELECT
    audit_log_id,
    tenant_id,
    table_name,
    record_identifier,
    operation,
    changed_at
FROM audit_logs
ORDER BY audit_log_id DESC
LIMIT 20;



-- ============================================================
-- 9. VERIFICAR TRIGGERS INSTALADOS
-- ============================================================

SELECT
    event_object_table AS tabla,
    trigger_name,
    action_timing,
    event_manipulation AS evento
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name, event_manipulation;



-- ============================================================
-- 10. RESULTADO FINAL DE LA PRUEBA
-- ============================================================

SELECT
    'PRUEBAS EJECUTADAS' AS estado,
    'Se realizara ROLLBACK para no modificar los datos reales' AS detalle;



-- ============================================================
-- IMPORTANTE
-- ============================================================
-- ROLLBACK deshace todos los INSERT, UPDATE y DELETE ejecutados
-- durante este archivo.
--
-- Los SELECT y mensajes NOTICE permiten observar los resultados
-- antes de finalizar.
-- ============================================================

ROLLBACK;


-- ============================================================
-- FIN DEL ARCHIVO DE PRUEBAS
-- ============================================================
