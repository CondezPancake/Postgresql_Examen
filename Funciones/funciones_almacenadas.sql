-- 8 FUNCIONES ALMACENADAS
-- Diferencia principal:
-- Un procedimiento realiza una operacion con CALL.
-- Una funcion devuelve un resultado y se consulta con SELECT.


-- 1. CANTIDAD DE PERSONAS DE UNA ORGANIZACION
-- Recibe tenant_id y devuelve un numero entero.

CREATE OR REPLACE FUNCTION fn_total_personas_tenant(
    p_tenant_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_total BIGINT;
BEGIN
    SELECT COUNT(*)
    INTO v_total
    FROM persons
    WHERE tenant_id = p_tenant_id;

    RETURN v_total;
END;
$$;


-- Ejemplo:
-- SELECT fn_total_personas_tenant(1);



-- 2. PORCENTAJE DE CUMPLIMIENTO DOCUMENTAL
-- Cuenta todos los documentos de la organizacion.
-- Los estados que tengan counts_as_completed = TRUE
-- se consideran documentos completados.
-- Si no existen documentos, devuelve 0.

CREATE OR REPLACE FUNCTION fn_porcentaje_cumplimiento(
    p_tenant_id BIGINT
)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total BIGINT;
    v_completados BIGINT;
    v_porcentaje NUMERIC(5,2);
BEGIN
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
    WHERE tt.tenant_id = p_tenant_id;

    IF v_total = 0 THEN
        v_porcentaje := 0;
    ELSE
        v_porcentaje := ROUND(
            v_completados * 100.0 / v_total,
            2
        );
    END IF;

    RETURN v_porcentaje;
END;
$$;


-- Ejemplo:
-- SELECT fn_porcentaje_cumplimiento(1);



-- 3. VERIFICAR SI UNA ORGANIZACION TIENE UN MODULO HABILITADO
-- EXISTS devuelve TRUE si encuentra la relacion.
-- Devuelve FALSE si no la encuentra.

CREATE OR REPLACE FUNCTION fn_tiene_modulo(
    p_tenant_id BIGINT,
    p_module_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM tenant_modules
        WHERE tenant_id = p_tenant_id
          AND module_id = p_module_id
          AND is_active = TRUE
    );
END;
$$;


-- Ejemplo:
-- SELECT fn_tiene_modulo(1, 1);



-- 4. OBTENER EL NOMBRE COMPLETO DE UNA PERSONA
-- CONCAT_WS une nombre y apellido usando un espacio.
-- Si la persona no existe, devuelve NULL.

CREATE OR REPLACE FUNCTION fn_nombre_completo_persona(
    p_person_id BIGINT
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_nombre_completo TEXT;
BEGIN
    SELECT CONCAT_WS(' ', first_name, last_name)
    INTO v_nombre_completo
    FROM persons
    WHERE person_id = p_person_id;

    RETURN v_nombre_completo;
END;
$$;


-- Ejemplo:
-- SELECT fn_nombre_completo_persona(1);



-- 5. CANTIDAD DE PLANTILLAS POR ORGANIZACION Y ETAPA PHVA
-- Recibe la organizacion y la etapa PHVA.
-- Devuelve cuantas plantillas tiene asignadas en esa etapa.

CREATE OR REPLACE FUNCTION fn_total_plantillas_phva(
    p_tenant_id BIGINT,
    p_phva_stage_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_total BIGINT;
BEGIN
    SELECT COUNT(*)
    INTO v_total
    FROM tenanttemplates
    WHERE tenant_id = p_tenant_id
      AND phva_stage_id = p_phva_stage_id;

    RETURN v_total;
END;
$$;


-- Ejemplo:
-- SELECT fn_total_plantillas_phva(1, 1);



-- 6. MODULOS HABILITADOS PARA UNA ORGANIZACION
-- RETURNS TABLE permite devolver varias filas y columnas.
-- RETURN QUERY devuelve el resultado del SELECT.

CREATE OR REPLACE FUNCTION fn_modulos_tenant(
    p_tenant_id BIGINT
)
RETURNS TABLE (
    module_id BIGINT,
    titulo VARCHAR(150),
    sistema VARCHAR(100)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.module_id,
        m.title,
        s.name
    FROM tenant_modules tm
    INNER JOIN modules m
        ON tm.module_id = m.module_id
    INNER JOIN type_system_sst s
        ON m.system_id = s.system_id
    WHERE tm.tenant_id = p_tenant_id
      AND tm.is_active = TRUE
    ORDER BY s.name, m.display_order;
END;
$$;


-- Ejemplo:
-- SELECT * FROM fn_modulos_tenant(1);



-- 7. PERSONAS DE UNA ORGANIZACION CON SU CARGO
-- Devuelve una tabla con las personas y su cargo actual.
-- ended_at IS NULL identifica el cargo vigente.

CREATE OR REPLACE FUNCTION fn_personas_cargos_tenant(
    p_tenant_id BIGINT
)
RETURNS TABLE (
    person_id BIGINT,
    nombre_completo TEXT,
    email VARCHAR(254),
    cargo VARCHAR(120)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.person_id,
        CONCAT_WS(' ', p.first_name, p.last_name),
        p.email,
        pos.name
    FROM persons p
    LEFT JOIN person_position_assignments ppa
        ON p.person_id = ppa.person_id
       AND ppa.ended_at IS NULL
    LEFT JOIN positions pos
        ON ppa.position_id = pos.position_id
    WHERE p.tenant_id = p_tenant_id
    ORDER BY p.last_name, p.first_name;
END;
$$;


-- Ejemplo:
-- SELECT * FROM fn_personas_cargos_tenant(1);



-- 8. CLASIFICAR EL NIVEL DE CUMPLIMIENTO
-- Reutiliza la funcion fn_porcentaje_cumplimiento.
--
-- Menor de 50 = Bajo
-- De 50 a menos de 80 = Medio
-- 80 o mas = Alto

CREATE OR REPLACE FUNCTION fn_nivel_cumplimiento(
    p_tenant_id BIGINT
)
RETURNS VARCHAR(10)
LANGUAGE plpgsql
AS $$
DECLARE
    v_porcentaje NUMERIC(5,2);
BEGIN
    v_porcentaje := fn_porcentaje_cumplimiento(p_tenant_id);

    IF v_porcentaje < 50 THEN
        RETURN 'Bajo';

    ELSIF v_porcentaje < 80 THEN
        RETURN 'Medio';

    ELSE
        RETURN 'Alto';
    END IF;
END;
$$;


-- Ejemplo:
-- SELECT fn_nivel_cumplimiento(1);



-- PRUEBA GENERAL DE LAS FUNCIONES

-- 1. Total de personas:
-- SELECT fn_total_personas_tenant(1);

-- 2. Porcentaje de cumplimiento:
-- SELECT fn_porcentaje_cumplimiento(1);

-- 3. Tiene modulo:
-- SELECT fn_tiene_modulo(1, 1);

-- 4. Nombre completo:
-- SELECT fn_nombre_completo_persona(1);

-- 5. Plantillas por PHVA:
-- SELECT fn_total_plantillas_phva(1, 1);

-- 6. Modulos de la organizacion:
-- SELECT * FROM fn_modulos_tenant(1);

-- 7. Personas y cargos:
-- SELECT * FROM fn_personas_cargos_tenant(1);

-- 8. Nivel de cumplimiento:
-- SELECT fn_nivel_cumplimiento(1);
