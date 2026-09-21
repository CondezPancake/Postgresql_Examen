-- 15 TRIGGERS

-- 1. ACTUALIZAR updated_at DE TENANTS
-- Antes de modificar una organizacion, set_updated_at()
-- coloca automaticamente la fecha y hora actual.

DROP TRIGGER IF EXISTS trg_tenants_set_updated_at ON tenants;

CREATE TRIGGER trg_tenants_set_updated_at
BEFORE UPDATE ON tenants
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();



-- 2. ACTUALIZAR updated_at DE PERSONS

DROP TRIGGER IF EXISTS trg_persons_set_updated_at ON persons;

CREATE TRIGGER trg_persons_set_updated_at
BEFORE UPDATE ON persons
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();



-- 3. IMPEDIR PERSONAS EN ORGANIZACIONES INACTIVAS
-- Se ejecuta al insertar una persona o cambiarla de organizacion.

CREATE OR REPLACE FUNCTION fn_validar_tenant_activo_persona()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM tenants
        WHERE tenant_id = NEW.tenant_id
          AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION
            'No se puede registrar la persona: la organizacion esta inactiva o no existe';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_tenant_activo_persona ON persons;

CREATE TRIGGER trg_validar_tenant_activo_persona
BEFORE INSERT OR UPDATE OF tenant_id ON persons
FOR EACH ROW
EXECUTE FUNCTION fn_validar_tenant_activo_persona();



-- 4. IMPEDIR ASIGNACIONES DUPLICADAS DE MODULOS
-- La PK de tenant_modules ya protege esta regla.
-- El trigger agrega una validacion con un mensaje mas claro.

CREATE OR REPLACE FUNCTION fn_validar_modulo_duplicado()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM tenant_modules
        WHERE tenant_id = NEW.tenant_id
          AND module_id = NEW.module_id
    ) THEN
        RAISE EXCEPTION
            'El modulo ya esta asignado a esta organizacion';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_modulo_duplicado ON tenant_modules;

CREATE TRIGGER trg_validar_modulo_duplicado
BEFORE INSERT ON tenant_modules
FOR EACH ROW
EXECUTE FUNCTION fn_validar_modulo_duplicado();



-- 5. IMPEDIR PLANTILLAS EN ORGANIZACIONES INACTIVAS

CREATE OR REPLACE FUNCTION fn_validar_tenant_activo_plantilla()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM tenants
        WHERE tenant_id = NEW.tenant_id
          AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION
            'No se puede asignar la plantilla: la organizacion esta inactiva o no existe';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_tenant_activo_plantilla ON tenanttemplates;

CREATE TRIGGER trg_validar_tenant_activo_plantilla
BEFORE INSERT OR UPDATE OF tenant_id ON tenanttemplates
FOR EACH ROW
EXECUTE FUNCTION fn_validar_tenant_activo_plantilla();



-- 6. PERSONA Y CARGO DEBEN PERTENECER A LA MISMA ORGANIZACION

CREATE OR REPLACE FUNCTION fn_validar_persona_cargo_tenant()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_tenant_persona BIGINT;
    v_tenant_cargo BIGINT;
BEGIN
    SELECT tenant_id
    INTO v_tenant_persona
    FROM persons
    WHERE person_id = NEW.person_id;

    SELECT tenant_id
    INTO v_tenant_cargo
    FROM positions
    WHERE position_id = NEW.position_id;

    IF v_tenant_persona IS NULL THEN
        RAISE EXCEPTION
            'La persona indicada no existe';
    END IF;

    IF v_tenant_cargo IS NULL THEN
        RAISE EXCEPTION
            'El cargo indicado no existe';
    END IF;

    IF v_tenant_persona <> v_tenant_cargo THEN
        RAISE EXCEPTION
            'La persona y el cargo deben pertenecer a la misma organizacion';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_persona_cargo_tenant
ON person_position_assignments;

CREATE TRIGGER trg_validar_persona_cargo_tenant
BEFORE INSERT OR UPDATE OF person_id, position_id
ON person_position_assignments
FOR EACH ROW
EXECUTE FUNCTION fn_validar_persona_cargo_tenant();



-- 7. ACTUALIZAR updated_at DE TENANTTEMPLATES
-- Este comportamiento ya existia en el DDL.
-- Se reutiliza la misma funcion set_updated_at().

DROP TRIGGER IF EXISTS trg_tenanttemplates_set_updated_at
ON tenanttemplates;

CREATE TRIGGER trg_tenanttemplates_set_updated_at
BEFORE UPDATE ON tenanttemplates
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();



-- 8. IMPEDIR ELIMINAR ORGANIZACION CON PERSONAS ASOCIADAS
-- La FK tambien protege la relacion, pero este trigger
-- devuelve un mensaje mas facil de entender.

CREATE OR REPLACE FUNCTION fn_impedir_eliminar_tenant_con_personas()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM persons
        WHERE tenant_id = OLD.tenant_id
    ) THEN
        RAISE EXCEPTION
            'No se puede eliminar la organizacion: tiene personas asociadas';
    END IF;

    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_impedir_eliminar_tenant_con_personas
ON tenants;

CREATE TRIGGER trg_impedir_eliminar_tenant_con_personas
BEFORE DELETE ON tenants
FOR EACH ROW
EXECUTE FUNCTION fn_impedir_eliminar_tenant_con_personas();



-- 9. IMPEDIR ELIMINAR UN SISTEMA SST/PESV EN USO

CREATE OR REPLACE FUNCTION fn_impedir_eliminar_sistema_en_uso()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM tenantsystems
        WHERE system_id = OLD.system_id
    ) THEN
        RAISE EXCEPTION
            'No se puede eliminar el sistema: existen organizaciones que lo utilizan';
    END IF;

    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_impedir_eliminar_sistema_en_uso
ON type_system_sst;

CREATE TRIGGER trg_impedir_eliminar_sistema_en_uso
BEFORE DELETE ON type_system_sst
FOR EACH ROW
EXECUTE FUNCTION fn_impedir_eliminar_sistema_en_uso();



-- 10. IMPEDIR ELIMINAR UN MODULO ASIGNADO

CREATE OR REPLACE FUNCTION fn_impedir_eliminar_modulo_asignado()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM tenant_modules
        WHERE module_id = OLD.module_id
    ) THEN
        RAISE EXCEPTION
            'No se puede eliminar el modulo: esta asignado a una o mas organizaciones';
    END IF;

    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_impedir_eliminar_modulo_asignado
ON modules;

CREATE TRIGGER trg_impedir_eliminar_modulo_asignado
BEFORE DELETE ON modules
FOR EACH ROW
EXECUTE FUNCTION fn_impedir_eliminar_modulo_asignado();



-- 11. VALIDAR PORCENTAJE DE CUMPLIMIENTO ENTRE 0 Y 100
-- El modelo no guarda el porcentaje en una columna.
-- Se calcula a partir de documents + document_statuses.
--
-- Cada vez que cambia un documento, el trigger recalcula
-- el cumplimiento de su organizacion y verifica el rango.

CREATE OR REPLACE FUNCTION fn_validar_rango_cumplimiento()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_tenant_template_id BIGINT;
    v_tenant_id BIGINT;
    v_total BIGINT;
    v_completados BIGINT;
    v_porcentaje NUMERIC(6,2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_tenant_template_id := OLD.tenant_template_id;
    ELSE
        v_tenant_template_id := NEW.tenant_template_id;
    END IF;

    SELECT tenant_id
    INTO v_tenant_id
    FROM tenanttemplates
    WHERE tenant_template_id = v_tenant_template_id;

    SELECT
        COUNT(d.document_id),
        COUNT(d.document_id)
            FILTER (WHERE ds.counts_as_completed = TRUE)
    INTO
        v_total,
        v_completados
    FROM tenanttemplates tt
    LEFT JOIN documents d
        ON tt.tenant_template_id = d.tenant_template_id
    LEFT JOIN document_statuses ds
        ON d.document_status_id = ds.document_status_id
    WHERE tt.tenant_id = v_tenant_id;

    IF v_total = 0 THEN
        v_porcentaje := 0;
    ELSE
        v_porcentaje := ROUND(
            v_completados * 100.0 / v_total,
            2
        );
    END IF;

    IF v_porcentaje < 0 OR v_porcentaje > 100 THEN
        RAISE EXCEPTION
            'Porcentaje de cumplimiento fuera de rango: %',
            v_porcentaje;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_rango_cumplimiento
ON documents;

CREATE TRIGGER trg_validar_rango_cumplimiento
AFTER INSERT OR UPDATE OR DELETE ON documents
FOR EACH ROW
EXECUTE FUNCTION fn_validar_rango_cumplimiento();



-- 12. AUDITAR CAMBIOS EN DATOS PRINCIPALES DE UNA ORGANIZACION
-- Guarda la fila anterior y la nueva en formato JSONB.
-- is_active se audita aparte en el trigger 13.

CREATE OR REPLACE FUNCTION fn_auditar_datos_tenant()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO audit_logs (
        tenant_id,
        table_name,
        record_identifier,
        operation,
        old_data,
        new_data
    )
    VALUES (
        NEW.tenant_id,
        'tenants',
        NEW.tenant_id::TEXT,
        'UPDATE',
        TO_JSONB(OLD),
        TO_JSONB(NEW)
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auditar_datos_tenant
ON tenants;

CREATE TRIGGER trg_auditar_datos_tenant
AFTER UPDATE OF
    tenant_size_id,
    municipality_id,
    legal_name,
    identification_type,
    identification_number,
    contact_email,
    phone,
    address
ON tenants
FOR EACH ROW
EXECUTE FUNCTION fn_auditar_datos_tenant();



-- 13. AUDITAR CAMBIO DE ESTADO DE UNA ORGANIZACION
-- Guarda especificamente el valor anterior y el nuevo
-- del campo is_active.

CREATE OR REPLACE FUNCTION fn_auditar_estado_tenant()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO audit_logs (
        tenant_id,
        table_name,
        record_identifier,
        operation,
        old_data,
        new_data
    )
    VALUES (
        NEW.tenant_id,
        'tenants',
        NEW.tenant_id::TEXT,
        'UPDATE',
        JSONB_BUILD_OBJECT(
            'is_active',
            OLD.is_active
        ),
        JSONB_BUILD_OBJECT(
            'is_active',
            NEW.is_active
        )
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auditar_estado_tenant
ON tenants;

CREATE TRIGGER trg_auditar_estado_tenant
AFTER UPDATE OF is_active ON tenants
FOR EACH ROW
WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active)
EXECUTE FUNCTION fn_auditar_estado_tenant();



-- 14. REGISTRAR FECHA Y USUARIO AL MODIFICAR UNA PLANTILLA
-- tenanttemplates no tiene una columna modified_by_person_id.
-- Por eso la trazabilidad se registra en audit_logs.
--
-- changed_at guarda la fecha automaticamente.
-- CURRENT_USER guarda el usuario de PostgreSQL que hizo el cambio.

CREATE OR REPLACE FUNCTION fn_auditar_modificacion_plantilla()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO audit_logs (
        tenant_id,
        table_name,
        record_identifier,
        operation,
        old_data,
        new_data
    )
    VALUES (
        NEW.tenant_id,
        'tenanttemplates',
        NEW.tenant_template_id::TEXT,
        'UPDATE',
        TO_JSONB(OLD),
        TO_JSONB(NEW)
            || JSONB_BUILD_OBJECT(
                'database_user',
                CURRENT_USER
            )
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auditar_modificacion_plantilla
ON tenanttemplates;

CREATE TRIGGER trg_auditar_modificacion_plantilla
AFTER UPDATE ON tenanttemplates
FOR EACH ROW
EXECUTE FUNCTION fn_auditar_modificacion_plantilla();



-- 15. MARCAR COMO INACTIVOS LOS BLOQUEOS VENCIDOS
-- Antes de crear un nuevo bloqueo se limpian los anteriores
-- cuya fecha de vencimiento ya paso.
--
-- Se usa BEFORE INSERT para evitar recursividad al actualizar
-- la misma tabla editing_locks.

CREATE OR REPLACE FUNCTION fn_desactivar_bloqueos_vencidos()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE editing_locks
    SET is_active = FALSE
    WHERE is_active = TRUE
      AND expires_at <= CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_desactivar_bloqueos_vencidos
ON editing_locks;

CREATE TRIGGER trg_desactivar_bloqueos_vencidos
BEFORE INSERT ON editing_locks
FOR EACH ROW
EXECUTE FUNCTION fn_desactivar_bloqueos_vencidos();



-- CONSULTA PARA VER LOS TRIGGERS CREADOS
-- Esta consulta es util para verificar la instalacion.

SELECT
    event_object_table AS tabla,
    trigger_name
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;
