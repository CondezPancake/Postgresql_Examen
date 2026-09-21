-- 15 PROCEDIMIENTOS ALMACENADOS
-- Objetivo:
-- Usar PL/pgSQL con parametros, variables, IF, validaciones,
-- RAISE NOTICE / EXCEPTION y manejo de errores.


-- 1. REGISTRAR UNA NUEVA ORGANIZACION
-- Valida que no exista otra empresa con el mismo tipo y numero
-- de identificacion antes de insertar.

CREATE OR REPLACE PROCEDURE sp_registrar_tenant(
    p_tenant_size_id BIGINT,
    p_municipality_id BIGINT,
    p_legal_name VARCHAR(200),
    p_identification_type VARCHAR(20),
    p_identification_number VARCHAR(30),
    p_contact_email VARCHAR(254),
    p_phone VARCHAR(30),
    p_address VARCHAR(250)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tenant_id BIGINT;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM tenants
        WHERE identification_type = p_identification_type
          AND identification_number = p_identification_number
    ) THEN
        RAISE EXCEPTION
            'Ya existe una organizacion con esa identificacion';
    END IF;

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
        p_tenant_size_id,
        p_municipality_id,
        p_legal_name,
        p_identification_type,
        p_identification_number,
        p_contact_email,
        p_phone,
        p_address
    )
    RETURNING tenant_id INTO v_tenant_id;

    RAISE NOTICE
        'Organizacion registrada con tenant_id = %',
        v_tenant_id;
END;
$$;


-- Ejemplo:
-- CALL sp_registrar_tenant(
--     1, 1, 'Empresa Ejemplo SAS', 'NIT', '900999999-1',
--     'contacto@ejemplo.com', '3000000000', 'Calle 1 # 1-01'
-- );



-- 2. REGISTRAR UNA PERSONA Y ASOCIARLA A UN CARGO
-- Primero valida que el cargo pertenezca a la misma organizacion.
-- Despues crea la persona y registra su cargo actual.

CREATE OR REPLACE PROCEDURE sp_registrar_persona(
    p_tenant_id BIGINT,
    p_position_id BIGINT,
    p_first_name VARCHAR(100),
    p_last_name VARCHAR(100),
    p_identification_number VARCHAR(30),
    p_email VARCHAR(254),
    p_phone VARCHAR(30)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_person_id BIGINT;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM positions
        WHERE position_id = p_position_id
          AND tenant_id = p_tenant_id
    ) THEN
        RAISE EXCEPTION
            'El cargo no pertenece a la organizacion indicada';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM persons
        WHERE tenant_id = p_tenant_id
          AND (
              identification_number = p_identification_number
              OR email = p_email
          )
    ) THEN
        RAISE EXCEPTION
            'La persona ya existe en esta organizacion';
    END IF;

    INSERT INTO persons (
        tenant_id,
        first_name,
        last_name,
        identification_number,
        email,
        phone
    )
    VALUES (
        p_tenant_id,
        p_first_name,
        p_last_name,
        p_identification_number,
        p_email,
        p_phone
    )
    RETURNING person_id INTO v_person_id;

    INSERT INTO person_position_assignments (
        person_id,
        position_id,
        started_at
    )
    VALUES (
        v_person_id,
        p_position_id,
        CURRENT_DATE
    );

    RAISE NOTICE
        'Persona registrada con person_id = %',
        v_person_id;
END;
$$;


-- Ejemplo:
-- CALL sp_registrar_persona(
--     1, 1, 'Laura', 'Perez', '1099000001',
--     'laura.perez@correo.com', '3000000001'
-- );



-- 3. CAMBIAR EL ESTADO DE UNA ORGANIZACION

-- Lee el estado actual y lo invierte:
-- TRUE pasa a FALSE y FALSE pasa a TRUE.

CREATE OR REPLACE PROCEDURE sp_cambiar_estado_tenant(
    p_tenant_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_actual BOOLEAN;
    v_nuevo_estado BOOLEAN;
BEGIN
    SELECT is_active
    INTO v_estado_actual
    FROM tenants
    WHERE tenant_id = p_tenant_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La organizacion no existe';
    END IF;

    v_nuevo_estado := NOT v_estado_actual;

    UPDATE tenants
    SET is_active = v_nuevo_estado
    WHERE tenant_id = p_tenant_id;

    RAISE NOTICE
        'Nuevo estado de la organizacion: %',
        v_nuevo_estado;
END;
$$;


-- Ejemplo:
-- CALL sp_cambiar_estado_tenant(1);



-- 4. ASIGNAR UN MODULO A UNA ORGANIZACION
-- Evita crear dos veces la misma relacion tenant-modulo.

CREATE OR REPLACE PROCEDURE sp_asignar_modulo(
    p_tenant_id BIGINT,
    p_module_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM tenants
        WHERE tenant_id = p_tenant_id
    ) THEN
        RAISE EXCEPTION
            'La organizacion no existe';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM modules
        WHERE module_id = p_module_id
    ) THEN
        RAISE EXCEPTION
            'El modulo no existe';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM tenant_modules
        WHERE tenant_id = p_tenant_id
          AND module_id = p_module_id
    ) THEN
        RAISE EXCEPTION
            'El modulo ya esta asignado a esta organizacion';
    END IF;

    INSERT INTO tenant_modules (
        tenant_id,
        module_id
    )
    VALUES (
        p_tenant_id,
        p_module_id
    );

    RAISE NOTICE
        'Modulo asignado correctamente';
END;
$$;


-- Ejemplo:
-- CALL sp_asignar_modulo(1, 1);



-- 5. HABILITAR UN SISTEMA SST/PESV PARA UNA ORGANIZACION
-- Si la relacion ya existe, la vuelve a activar.
-- Si no existe, crea una nueva.

CREATE OR REPLACE PROCEDURE sp_habilitar_sistema(
    p_tenant_id BIGINT,
    p_system_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM tenants
        WHERE tenant_id = p_tenant_id
    ) THEN
        RAISE EXCEPTION
            'La organizacion no existe';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM type_system_sst
        WHERE system_id = p_system_id
    ) THEN
        RAISE EXCEPTION
            'El sistema no existe';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM tenantsystems
        WHERE tenant_id = p_tenant_id
          AND system_id = p_system_id
    ) THEN

        UPDATE tenantsystems
        SET is_active = TRUE,
            enabled_at = CURRENT_TIMESTAMP
        WHERE tenant_id = p_tenant_id
          AND system_id = p_system_id;

    ELSE

        INSERT INTO tenantsystems (
            tenant_id,
            system_id
        )
        VALUES (
            p_tenant_id,
            p_system_id
        );

    END IF;

    RAISE NOTICE
        'Sistema habilitado correctamente';
END;
$$;


-- Ejemplo:
-- CALL sp_habilitar_sistema(1, 1);



-- 6. ASIGNAR UNA PLANTILLA A UNA ORGANIZACION
-- Valida:
-- 1. Que la organizacion este activa.
-- 2. Que el sistema este habilitado.
-- 3. Que el formato pertenezca al sistema indicado.
-- 4. Que no exista la misma asignacion.

CREATE OR REPLACE PROCEDURE sp_asignar_plantilla(
    p_tenant_id BIGINT,
    p_template_id BIGINT,
    p_system_id BIGINT,
    p_phva_stage_id BIGINT,
    p_format_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM tenants
        WHERE tenant_id = p_tenant_id
          AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION
            'La organizacion no existe o se encuentra inactiva';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM templates
        WHERE template_id = p_template_id
          AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION
            'La plantilla no existe o esta inactiva';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM phva_stages
        WHERE phva_stage_id = p_phva_stage_id
    ) THEN
        RAISE EXCEPTION
            'La etapa PHVA no existe';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM tenantsystems
        WHERE tenant_id = p_tenant_id
          AND system_id = p_system_id
          AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION
            'El sistema no esta habilitado para esta organizacion';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM formats_sst f
        INNER JOIN modules m
            ON f.module_id = m.module_id
        WHERE f.format_id = p_format_id
          AND m.system_id = p_system_id
          AND f.is_active = TRUE
    ) THEN
        RAISE EXCEPTION
            'El formato no pertenece al sistema indicado';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM tenanttemplates
        WHERE tenant_id = p_tenant_id
          AND template_id = p_template_id
          AND format_id = p_format_id
          AND phva_stage_id = p_phva_stage_id
    ) THEN
        RAISE EXCEPTION
            'La plantilla ya fue asignada con esa configuracion';
    END IF;

    INSERT INTO tenanttemplates (
        tenant_id,
        template_id,
        format_id,
        phva_stage_id
    )
    VALUES (
        p_tenant_id,
        p_template_id,
        p_format_id,
        p_phva_stage_id
    );

    RAISE NOTICE
        'Plantilla asignada correctamente';
END;
$$;


-- Ejemplo:
-- CALL sp_asignar_plantilla(1, 1, 1, 1, 1);



-- 7. CAMBIAR EL CARGO DE UNA PERSONA
-- No borra el cargo anterior.
-- Le coloca fecha de finalizacion y crea la nueva asignacion.

CREATE OR REPLACE PROCEDURE sp_cambiar_cargo_persona(
    p_person_id BIGINT,
    p_new_position_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tenant_id BIGINT;
    v_position_actual BIGINT;
BEGIN
    SELECT tenant_id
    INTO v_tenant_id
    FROM persons
    WHERE person_id = p_person_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La persona no existe';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM positions
        WHERE position_id = p_new_position_id
          AND tenant_id = v_tenant_id
          AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION
            'El nuevo cargo no pertenece a la organizacion de la persona';
    END IF;

    SELECT position_id
    INTO v_position_actual
    FROM person_position_assignments
    WHERE person_id = p_person_id
      AND ended_at IS NULL;

    IF FOUND AND v_position_actual = p_new_position_id THEN
        RAISE EXCEPTION
            'La persona ya tiene asignado ese cargo';
    END IF;

    UPDATE person_position_assignments
    SET ended_at = CURRENT_DATE
    WHERE person_id = p_person_id
      AND ended_at IS NULL;

    INSERT INTO person_position_assignments (
        person_id,
        position_id,
        started_at
    )
    VALUES (
        p_person_id,
        p_new_position_id,
        CURRENT_DATE
    );

    RAISE NOTICE
        'Cargo actualizado correctamente';
END;
$$;


-- Ejemplo:
-- CALL sp_cambiar_cargo_persona(1, 2);



-- 8. TRASLADAR UNA PERSONA A OTRA ORGANIZACION
-- Cierra su cargo actual, cambia la organizacion y crea una
-- nueva asignacion de cargo en la empresa destino.

CREATE OR REPLACE PROCEDURE sp_trasladar_persona(
    p_person_id BIGINT,
    p_new_tenant_id BIGINT,
    p_new_position_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_identification_number VARCHAR(30);
    v_email VARCHAR(254);
BEGIN
    SELECT
        identification_number,
        email
    INTO
        v_identification_number,
        v_email
    FROM persons
    WHERE person_id = p_person_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La persona no existe';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM tenants
        WHERE tenant_id = p_new_tenant_id
          AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION
            'La organizacion destino no existe o esta inactiva';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM positions
        WHERE position_id = p_new_position_id
          AND tenant_id = p_new_tenant_id
          AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION
            'El cargo no pertenece a la organizacion destino';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM persons
        WHERE tenant_id = p_new_tenant_id
          AND person_id <> p_person_id
          AND (
              identification_number = v_identification_number
              OR email = v_email
          )
    ) THEN
        RAISE EXCEPTION
            'Ya existe una persona con esa identificacion o correo en la organizacion destino';
    END IF;

    UPDATE person_position_assignments
    SET ended_at = CURRENT_DATE
    WHERE person_id = p_person_id
      AND ended_at IS NULL;

    UPDATE persons
    SET tenant_id = p_new_tenant_id
    WHERE person_id = p_person_id;

    INSERT INTO person_position_assignments (
        person_id,
        position_id,
        started_at
    )
    VALUES (
        p_person_id,
        p_new_position_id,
        CURRENT_DATE
    );

    RAISE NOTICE
        'Persona trasladada correctamente';
END;
$$;


-- Ejemplo:
-- CALL sp_trasladar_persona(1, 2, 5);



-- 9. DESHABILITAR MODULOS DE UNA ORGANIZACION INACTIVA
-- Solo permite ejecutar la operacion si la empresa ya esta inactiva.

CREATE OR REPLACE PROCEDURE sp_deshabilitar_modulos_tenant(
    p_tenant_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_is_active BOOLEAN;
    v_cantidad INTEGER;
BEGIN
    SELECT is_active
    INTO v_is_active
    FROM tenants
    WHERE tenant_id = p_tenant_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La organizacion no existe';
    END IF;

    IF v_is_active = TRUE THEN
        RAISE EXCEPTION
            'La organizacion todavia se encuentra activa';
    END IF;

    UPDATE tenant_modules
    SET is_active = FALSE
    WHERE tenant_id = p_tenant_id
      AND is_active = TRUE;

    GET DIAGNOSTICS v_cantidad = ROW_COUNT;

    RAISE NOTICE
        'Modulos deshabilitados: %',
        v_cantidad;
END;
$$;


-- Ejemplo:
-- CALL sp_deshabilitar_modulos_tenant(5);



-- 10. ELIMINAR UNA ASIGNACION DE MODULO DE FORMA CONTROLADA
-- No elimina la relacion si existen plantillas de esa empresa
-- que dependan de formatos pertenecientes al modulo.

CREATE OR REPLACE PROCEDURE sp_eliminar_asignacion_modulo(
    p_tenant_id BIGINT,
    p_module_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM tenant_modules
        WHERE tenant_id = p_tenant_id
          AND module_id = p_module_id
    ) THEN
        RAISE EXCEPTION
            'La asignacion del modulo no existe';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM tenanttemplates tt
        INNER JOIN formats_sst f
            ON tt.format_id = f.format_id
        WHERE tt.tenant_id = p_tenant_id
          AND f.module_id = p_module_id
    ) THEN
        RAISE EXCEPTION
            'No se puede eliminar: existen plantillas dependientes del modulo';
    END IF;

    DELETE FROM tenant_modules
    WHERE tenant_id = p_tenant_id
      AND module_id = p_module_id;

    RAISE NOTICE
        'Asignacion del modulo eliminada correctamente';
END;
$$;


-- Ejemplo:
-- CALL sp_eliminar_asignacion_modulo(1, 1);



-- 11. TOTAL DE PLANTILLAS DE UNA ORGANIZACION
-- COUNT obtiene el total y RAISE NOTICE lo muestra en pantalla.

CREATE OR REPLACE PROCEDURE sp_total_plantillas_tenant(
    p_tenant_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total INTEGER;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM tenants
        WHERE tenant_id = p_tenant_id
    ) THEN
        RAISE EXCEPTION
            'La organizacion no existe';
    END IF;

    SELECT COUNT(*)
    INTO v_total
    FROM tenanttemplates
    WHERE tenant_id = p_tenant_id;

    RAISE NOTICE
        'Total de plantillas asociadas: %',
        v_total;
END;
$$;


-- Ejemplo:
-- CALL sp_total_plantillas_tenant(1);



-- 12. PORCENTAJE DE CUMPLIMIENTO DOCUMENTAL
-- Finalizados = documentos con estado FINISHED.
-- Pendientes = todos los documentos que aun no estan FINISHED.
-- Porcentaje = finalizados / total * 100.

CREATE OR REPLACE PROCEDURE sp_calcular_cumplimiento_tenant(
    p_tenant_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total INTEGER;
    v_finalizados INTEGER;
    v_pendientes INTEGER;
    v_porcentaje NUMERIC(5,2);
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM tenants
        WHERE tenant_id = p_tenant_id
    ) THEN
        RAISE EXCEPTION
            'La organizacion no existe';
    END IF;

    SELECT
        COUNT(d.document_id),
        COUNT(d.document_id)
            FILTER (WHERE ds.code = 'FINISHED'),
        COUNT(d.document_id)
            FILTER (WHERE ds.code <> 'FINISHED')
    INTO
        v_total,
        v_finalizados,
        v_pendientes
    FROM tenanttemplates tt
    LEFT JOIN documents d
        ON tt.tenant_template_id = d.tenant_template_id
    LEFT JOIN document_statuses ds
        ON d.document_status_id = ds.document_status_id
    WHERE tt.tenant_id = p_tenant_id;

    IF v_total = 0 THEN
        v_porcentaje := 0;
    ELSE
        v_porcentaje := ROUND(
            v_finalizados * 100.0 / v_total,
            2
        );
    END IF;

    RAISE NOTICE
        'Total: %, Finalizados: %, Pendientes: %, Cumplimiento: % %',
        v_total,
        v_finalizados,
        v_pendientes,
        v_porcentaje,
        '%';
END;
$$;


-- Ejemplo:
-- CALL sp_calcular_cumplimiento_tenant(1);



-- 13. DOCUMENTOS DE UNA ORGANIZACION POR ETAPA PHVA
-- Cuenta los documentos relacionados con la etapa recibida.

CREATE OR REPLACE PROCEDURE sp_documentos_por_phva(
    p_tenant_id BIGINT,
    p_phva_stage_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total INTEGER;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM tenants
        WHERE tenant_id = p_tenant_id
    ) THEN
        RAISE EXCEPTION
            'La organizacion no existe';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM phva_stages
        WHERE phva_stage_id = p_phva_stage_id
    ) THEN
        RAISE EXCEPTION
            'La etapa PHVA no existe';
    END IF;

    SELECT COUNT(d.document_id)
    INTO v_total
    FROM tenanttemplates tt
    LEFT JOIN documents d
        ON tt.tenant_template_id = d.tenant_template_id
    WHERE tt.tenant_id = p_tenant_id
      AND tt.phva_stage_id = p_phva_stage_id;

    RAISE NOTICE
        'Cantidad de documentos para la etapa PHVA: %',
        v_total;
END;
$$;


-- Ejemplo:
-- CALL sp_documentos_por_phva(1, 1);



-- 14. ACTUALIZAR DATOS DE CONTACTO DE UNA ORGANIZACION
-- Modifica correo, telefono y direccion.
-- Tambien actualiza updated_at.
-- El trigger existente de updated_at refuerza este comportamiento.

CREATE OR REPLACE PROCEDURE sp_actualizar_contacto_tenant(
    p_tenant_id BIGINT,
    p_contact_email VARCHAR(254),
    p_phone VARCHAR(30),
    p_address VARCHAR(250)
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM tenants
        WHERE tenant_id = p_tenant_id
    ) THEN
        RAISE EXCEPTION
            'La organizacion no existe';
    END IF;

    UPDATE tenants
    SET contact_email = p_contact_email,
        phone = p_phone,
        address = p_address,
        updated_at = CURRENT_TIMESTAMP
    WHERE tenant_id = p_tenant_id;

    RAISE NOTICE
        'Datos de contacto actualizados correctamente';
END;
$$;


-- Ejemplo:
-- CALL sp_actualizar_contacto_tenant(
--     1,
--     'nuevo@correo.com',
--     '3100000000',
--     'Nueva direccion'
-- );



-- 15. ASIGNAR PLANTILLA CON MANEJO DE EXCEPCIONES
-- Reutiliza el procedimiento 6.
-- EXCEPTION permite controlar errores sin dejar una operacion
-- incompleta dentro de este bloque.

CREATE OR REPLACE PROCEDURE sp_asignar_plantilla_segura(
    p_tenant_id BIGINT,
    p_template_id BIGINT,
    p_system_id BIGINT,
    p_phva_stage_id BIGINT,
    p_format_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    BEGIN
        CALL sp_asignar_plantilla(
            p_tenant_id,
            p_template_id,
            p_system_id,
            p_phva_stage_id,
            p_format_id
        );

    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE
                'No se pudo asignar: la asignacion ya existe';

        WHEN foreign_key_violation THEN
            RAISE NOTICE
                'No se pudo asignar: existe una referencia invalida';

        WHEN OTHERS THEN
            RAISE NOTICE
                'No se pudo asignar la plantilla: %',
                SQLERRM;
    END;
END;
$$;


-- Ejemplo:
-- CALL sp_asignar_plantilla_segura(1, 1, 1, 1, 1);
