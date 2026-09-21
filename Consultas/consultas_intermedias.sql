-- 20 CONSULTAS SQL INTERMEDIAS


-- 1. PERSONAS Y ORGANIZACION A LA QUE PERTENECEN
-- INNER JOIN relaciona cada persona con su organizacion.

SELECT
    CONCAT(p.first_name, ' ', p.last_name) AS nombre_completo,
    t.legal_name AS organizacion
FROM persons p
INNER JOIN tenants t
    ON p.tenant_id = t.tenant_id
ORDER BY t.legal_name, nombre_completo;


-- 2. PERSONAS Y CARGO QUE DESEMPENAN
-- ended_at IS NULL indica que la asignacion del cargo sigue activa.

SELECT
    CONCAT(p.first_name, ' ', p.last_name) AS nombre_completo,
    pos.name AS cargo
FROM persons p
INNER JOIN person_position_assignments ppa
    ON p.person_id = ppa.person_id
INNER JOIN positions pos
    ON ppa.position_id = pos.position_id
WHERE ppa.ended_at IS NULL
ORDER BY nombre_completo;


-- 3. ORGANIZACIONES Y TAMANO DE EMPRESA

SELECT
    t.legal_name AS organizacion,
    ts.name AS tamano_empresa
FROM tenants t
INNER JOIN tenant_sizes ts
    ON t.tenant_size_id = ts.tenant_size_id
ORDER BY t.legal_name;


-- 4. UBICACION COMPLETA DE CADA ORGANIZACION
-- Se unen municipio, region y pais para obtener la ubicacion completa.

SELECT
    t.legal_name AS organizacion,
    m.name AS municipio,
    r.name AS departamento_region,
    c.name AS pais
FROM tenants t
INNER JOIN municipalities m
    ON t.municipality_id = m.municipality_id
INNER JOIN regions r
    ON m.region_id = r.region_id
INNER JOIN countries c
    ON r.country_id = c.country_id
ORDER BY t.legal_name;


-- 5. CANTIDAD DE PERSONAS POR ORGANIZACION
-- LEFT JOIN permite mostrar tambien organizaciones con 0 personas.

SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    COUNT(p.person_id) AS cantidad_personas
FROM tenants t
LEFT JOIN persons p
    ON t.tenant_id = p.tenant_id
GROUP BY t.tenant_id, t.legal_name
ORDER BY cantidad_personas DESC, t.legal_name;



-- 6. ORGANIZACIONES CON MAS DE UNA CANTIDAD DE PERSONAS

-- HAVING filtra despues de realizar el conteo.
-- Cambia 2 por la cantidad minima que quieras evaluar.

SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    COUNT(p.person_id) AS cantidad_personas
FROM tenants t
INNER JOIN persons p
    ON t.tenant_id = p.tenant_id
GROUP BY t.tenant_id, t.legal_name
HAVING COUNT(p.person_id) > 2
ORDER BY cantidad_personas DESC;


-- 7. MODULOS HABILITADOS PARA CADA ORGANIZACION
-- tenant_modules conecta las organizaciones con sus modulos.

SELECT
    t.legal_name AS organizacion,
    m.title AS modulo
FROM tenant_modules tm
INNER JOIN tenants t
    ON tm.tenant_id = t.tenant_id
INNER JOIN modules m
    ON tm.module_id = m.module_id
WHERE tm.is_active = TRUE
ORDER BY t.legal_name, m.display_order;


-- 8. CANTIDAD DE MODULOS HABILITADOS POR ORGANIZACION
-- La condicion is_active se coloca en el JOIN para conservar
-- organizaciones que tengan 0 modulos activos.

SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    COUNT(tm.module_id) AS cantidad_modulos
FROM tenants t
LEFT JOIN tenant_modules tm
    ON t.tenant_id = tm.tenant_id
   AND tm.is_active = TRUE
GROUP BY t.tenant_id, t.legal_name
ORDER BY cantidad_modulos DESC, t.legal_name;



-- 9. SISTEMAS SST HABILITADOS PARA CADA ORGANIZACION

SELECT
    t.legal_name AS organizacion,
    s.code AS codigo_sistema,
    s.name AS sistema
FROM tenantsystems ts
INNER JOIN tenants t
    ON ts.tenant_id = t.tenant_id
INNER JOIN type_system_sst s
    ON ts.system_id = s.system_id
WHERE ts.is_active = TRUE
ORDER BY t.legal_name, s.name;


-- 10. MODULOS Y SISTEMA SST AL QUE PERTENECEN

SELECT
    m.title AS modulo,
    s.name AS sistema_sst
FROM modules m
INNER JOIN type_system_sst s
    ON m.system_id = s.system_id
ORDER BY s.name, m.display_order;


-- 11. FORMATOS Y MODULO AL QUE PERTENECEN

SELECT
    f.name AS formato,
    f.version,
    m.title AS modulo
FROM formats_sst f
INNER JOIN modules m
    ON f.module_id = m.module_id
ORDER BY m.title, f.name;


-- 12. CANTIDAD DE FORMATOS POR MODULO
-- LEFT JOIN permite incluir modulos que todavia no tengan formatos.

SELECT
    m.module_id,
    m.title AS modulo,
    COUNT(f.format_id) AS cantidad_formatos
FROM modules m
LEFT JOIN formats_sst f
    ON m.module_id = f.module_id
GROUP BY m.module_id, m.title
ORDER BY cantidad_formatos DESC, m.title;


-- 13. PLANTILLAS ASIGNADAS A CADA ORGANIZACION

SELECT
    t.legal_name AS organizacion,
    temp.name AS plantilla
FROM tenanttemplates tt
INNER JOIN tenants t
    ON tt.tenant_id = t.tenant_id
INNER JOIN templates temp
    ON tt.template_id = temp.template_id
ORDER BY t.legal_name, temp.name;


-- 14. PLANTILLA, ORGANIZACION, SISTEMA SST Y ETAPA PHVA
-- El sistema SST se obtiene siguiendo la relacion:
-- plantilla asignada -> formato -> modulo -> sistema.

SELECT
    t.legal_name AS organizacion,
    temp.name AS plantilla,
    s.name AS sistema_sst,
    ph.name AS etapa_phva
FROM tenanttemplates tt
INNER JOIN tenants t
    ON tt.tenant_id = t.tenant_id
INNER JOIN templates temp
    ON tt.template_id = temp.template_id
INNER JOIN formats_sst f
    ON tt.format_id = f.format_id
INNER JOIN modules m
    ON f.module_id = m.module_id
INNER JOIN type_system_sst s
    ON m.system_id = s.system_id
INNER JOIN phva_stages ph
    ON tt.phva_stage_id = ph.phva_stage_id
ORDER BY t.legal_name, ph.display_order, temp.name;


-- 15. CANTIDAD DE PLANTILLAS ASIGNADAS POR ORGANIZACION
-- LEFT JOIN muestra tambien organizaciones sin plantillas.

SELECT
    t.tenant_id,
    t.legal_name AS organizacion,
    COUNT(tt.tenant_template_id) AS cantidad_plantillas
FROM tenants t
LEFT JOIN tenanttemplates tt
    ON t.tenant_id = tt.tenant_id
GROUP BY t.tenant_id, t.legal_name
ORDER BY cantidad_plantillas DESC, t.legal_name;


-- 16. ORGANIZACIONES SIN PERSONAS REGISTRADAS
-- Si no existe persona relacionada, p.person_id queda en NULL.

SELECT
    t.tenant_id,
    t.legal_name AS organizacion
FROM tenants t
LEFT JOIN persons p
    ON t.tenant_id = p.tenant_id
WHERE p.person_id IS NULL
ORDER BY t.legal_name;


-- 17. MODULOS NO ASIGNADOS A NINGUNA ORGANIZACION
-- Si no existe relacion en tenant_modules, el modulo no ha sido asignado.

SELECT
    m.module_id,
    m.title AS modulo
FROM modules m
LEFT JOIN tenant_modules tm
    ON m.module_id = tm.module_id
WHERE tm.module_id IS NULL
ORDER BY m.title;


-- 18. ETAPAS PHVA Y CANTIDAD DE PLANTILLAS ASOCIADAS
-- LEFT JOIN permite mostrar las cuatro etapas aunque alguna tenga 0 plantillas.

SELECT
    ph.phva_stage_id,
    ph.name AS etapa_phva,
    COUNT(tt.tenant_template_id) AS cantidad_plantillas
FROM phva_stages ph
LEFT JOIN tenanttemplates tt
    ON ph.phva_stage_id = tt.phva_stage_id
GROUP BY ph.phva_stage_id, ph.name, ph.display_order
ORDER BY ph.display_order;


-- 19. CANTIDAD DE ORGANIZACIONES POR MUNICIPIO
-- LEFT JOIN permite mostrar municipios que tengan 0 organizaciones.

SELECT
    m.municipality_id,
    m.name AS municipio,
    COUNT(t.tenant_id) AS cantidad_organizaciones
FROM municipalities m
LEFT JOIN tenants t
    ON m.municipality_id = t.municipality_id
GROUP BY m.municipality_id, m.name
ORDER BY cantidad_organizaciones DESC, m.name;


-- 20. CARGOS DE CADA ORGANIZACION Y PERSONAS QUE LOS OCUPAN
-- ended_at IS NULL cuenta solamente las asignaciones de cargo actuales.

SELECT
    t.legal_name AS organizacion,
    pos.name AS cargo,
    COUNT(ppa.person_id) AS cantidad_personas
FROM positions pos
INNER JOIN tenants t
    ON pos.tenant_id = t.tenant_id
LEFT JOIN person_position_assignments ppa
    ON pos.position_id = ppa.position_id
   AND ppa.ended_at IS NULL
GROUP BY t.tenant_id, t.legal_name, pos.position_id, pos.name
ORDER BY t.legal_name, cantidad_personas DESC, pos.name;
