-- 15 CONSULTAS SQL BASICAS


-- 1. Consultar todas las organizaciones registradas.
-- SELECT * muestra todas las columnas de la tabla.
SELECT *
FROM tenants
ORDER BY tenant_id;


-- 2. Mostrar nombre, correo y telefono de todas las organizaciones.
-- Se seleccionan solamente las columnas solicitadas.
SELECT
    legal_name,
    contact_email,
    phone
FROM tenants
ORDER BY legal_name;


-- 3. Listar nombres, apellidos y correo de todas las personas.
SELECT
    first_name,
    last_name,
    email
FROM persons
ORDER BY last_name, first_name;


-- 4. Consultar solamente las personas activas.
-- TRUE indica que el registro esta activo.
SELECT
    person_id,
    first_name,
    last_name,
    email
FROM persons
WHERE is_active = TRUE
ORDER BY last_name, first_name;


-- 5. Buscar organizaciones cuyo nombre contenga una palabra.
-- Cambia 'Transportes' por la palabra que quieras buscar.
SELECT
    tenant_id,
    legal_name,
    contact_email
FROM tenants
WHERE legal_name LIKE '%Transportes%'
ORDER BY legal_name;


-- 6. Listar todos los paises en orden alfabetico.
SELECT
    country_id,
    name,
    iso_code
FROM countries
ORDER BY name;


-- 7. Consultar regiones o departamentos de un pais.
-- Cambia 1 por el country_id que quieras consultar.
SELECT
    region_id,
    country_id,
    name,
    code
FROM regions
WHERE country_id = 1
ORDER BY name;


-- 8. Consultar municipios de una region o departamento.
-- Cambia 1 por el region_id que quieras consultar.
SELECT
    municipality_id,
    region_id,
    name,
    code
FROM municipalities
WHERE region_id = 1
ORDER BY name;


-- 9. Listar todos los cargos ordenados por su descripcion.
SELECT
    position_id,
    tenant_id,
    name,
    description
FROM positions
ORDER BY description;


-- 10. Consultar las personas de una organizacion determinada.
-- Cambia 1 por el tenant_id de la organizacion que quieras consultar.
SELECT
    person_id,
    tenant_id,
    first_name,
    last_name,
    email
FROM persons
WHERE tenant_id = 1
ORDER BY last_name, first_name;


-- 11. Consultar solamente las organizaciones activas.
SELECT
    tenant_id,
    legal_name,
    contact_email,
    is_active
FROM tenants
WHERE is_active = TRUE
ORDER BY legal_name;


-- 12. Consultar organizaciones creadas dentro de un periodo.
-- Cambia las dos fechas por el rango que quieras evaluar.
SELECT
    tenant_id,
    legal_name,
    created_at
FROM tenants
WHERE created_at::date
      BETWEEN DATE '2026-01-01' AND DATE '2026-12-31'
ORDER BY created_at;


-- 13. Listar los tamaños de empresa registrados.
SELECT
    tenant_size_id,
    name,
    min_employees,
    max_employees
FROM tenant_sizes
ORDER BY min_employees;


-- 14. Consultar los tipos de sistemas SST registrados.
SELECT
    system_id,
    code,
    name,
    description
FROM type_system_sst
ORDER BY name;


-- 15. Listar los modulos mostrando titulo, descripcion y orden.
SELECT
    title,
    description,
    display_order
FROM modules
ORDER BY display_order, title;
