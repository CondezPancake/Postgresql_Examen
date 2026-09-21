# PostgreSQL Examen — Gestión SST y PESV

Proyecto académico de diseño e implementación de una base de datos **PostgreSQL 16** para gestionar procesos de **Seguridad y Salud en el Trabajo (SST)** y **Plan Estratégico de Seguridad Vial (PESV)** en múltiples organizaciones.

El sistema está diseñado como una solución **multi-tenant**: varias empresas comparten la misma base de datos, pero la información operacional queda separada lógicamente mediante `tenant_id` y las relaciones asociadas.

Además, el modelo es **híbrido relacional + documental**: las relaciones, claves, estados y entidades principales se mantienen normalizadas en tablas relacionales, mientras que la información cuyo esquema puede cambiar se almacena en columnas `JSONB`.

## 1. Objetivo del proyecto

Centralizar la información SST/PESV de distintas organizaciones y permitir:

- administrar empresas, ubicación, personas y cargos;
- habilitar sistemas SST/PESV y sus módulos;
- manejar formatos, plantillas y etapas PHVA;
- generar y versionar documentos;
- registrar evaluaciones y resultados;
- calcular indicadores de cumplimiento;
- controlar edición concurrente de documentos;
- auditar cambios;
- ejecutar consultas básicas, intermedias y avanzadas;
- automatizar reglas mediante procedimientos, funciones y triggers.

## 2. Tecnologías

| Tecnología        | Uso                                              |
| ----------------- | ------------------------------------------------ |
| PostgreSQL 16     | Motor de base de datos                           |
| PL/pgSQL          | Procedimientos, funciones y funciones de trigger |
| JSONB             | Parte documental/flexible del modelo híbrido     |
| Docker Compose    | Levantar PostgreSQL y pgAdmin                    |
| pgAdmin 4         | Administración gráfica opcional                  |
| Terminal + `psql` | Método principal de ejecución del proyecto       |

## 3. Estructura del proyecto

```text
Postgresql_Examen-develop/
├── docker-compose.yml
├── .env                         # Archivo local de variables; no publicar contraseñas
├── DDL/
│   └── DDL Examen.sql
├── DML/
│   ├── DML Examen.sql
│   ├── DML UPDATED EXAMEN.sql
│   └── DML_Ampliacion_EXAMEN.sql
├── Consultas/
│   ├── consultas_basicas.sql
│   ├── consultas_intermedias.sql
│   └── consultas_avanzadas.sql
├── Vistas/
│   └── vistas_y_materializadas.sql
├── Procedimientos_Almacenados/
│   └── Procedimientos_almacenados.sql
├── Funciones/
│   └── funciones_almacenadas.sql
├── Triggers/
│   └── triggers.sql
├── MODELOS/
│   ├── Modelo_Logico.png
│   ├── Modelo_fisico.png
│   └── E-R/
│       ├── E-R General.png
│       ├── E-R organizacion.png
│       ├── E-R Personas.png
│       ├── E-R Sistemas.png
│       ├── E-R Documentos.png
│       ├── E-R Evaluaciones.png
│       └── E-R Control.png
└── pruebas_crud_restricciones_funcionamiento.sql
```

> **Importante sobre los DML de ampliación:** `DML UPDATED EXAMEN.sql` y `DML_Ampliacion_EXAMEN.sql` representan la misma ampliación en dos versiones. La versión que debe ejecutarse en la guía es **`DML_Ampliacion_EXAMEN.sql`**, porque es la más completa e incluye el escenario adicional de Camila Gómez como segunda persona en el cargo `Responsable SST`. No ejecute ambos archivos de ampliación en la misma instalación.

## 4. Arquitectura Docker

`docker-compose.yml` define tres servicios:

| Servicio      | Contenedor               | Función                                   |
| ------------- | ------------------------ | ----------------------------------------- |
| `postgres_db` | `postgres_db`            | PostgreSQL 16 y almacenamiento de la base |
| `pgadmin_web` | `pgadmin_web`            | Interfaz pgAdmin opcional                 |
| `workspace`   | `postgres-dev-workspace` | Entorno pensado para VS Code              |

### Nota sobre `workspace`

En la versión analizada del proyecto, `workspace` referencia `.devcontainer/Dockerfile`, pero ese archivo no está incluido en el ZIP. Como todo el examen se ejecutará desde terminal, **no es necesario levantar `workspace`**. La guía usa únicamente:

```bash
docker compose up -d postgres_db pgadmin_web
```

Si posteriormente se agrega `.devcontainer/Dockerfile`, también podrá levantarse el stack completo con `docker compose up -d`.

### Variables esperadas en `.env`

El `docker-compose.yml` utiliza estas variables:

```dotenv
POSTGRES_USER=...
POSTGRES_PASSWORD=...
POSTGRES_DB=...
POSTGRES_PORT=...
PGADMIN_DEFAULT_EMAIL=...
PGADMIN_DEFAULT_PASSWORD=...
PGADMIN_PORT=...
```

No es necesario copiar contraseñas reales dentro de este README. Docker Compose lee `.env` automáticamente cuando se ejecuta desde la raíz del proyecto.

## 5. Guía de ejecución paso a paso desde terminal

Los comandos siguientes se ejecutan **desde la carpeta raíz `Postgresql_Examen-develop`**.

### 5.1 Verificar Docker

```bash
docker --version
docker compose version
```

### 5.2 Verificar que existe `.env`

```bash
ls -la .env
```

### 5.3 Crear la carpeta `init` si todavía no existe

El `docker-compose.yml` monta `./init` en `/docker-entrypoint-initdb.d`. Los SQL de este proyecto se ejecutarán manualmente desde terminal, por lo que puede estar vacía.

```bash
mkdir -p init
```

### 5.4 Validar la configuración de Compose

```bash
docker compose config
```

Si este comando muestra la configuración sin errores, las variables de `.env` fueron reconocidas.

### 5.5 Levantar PostgreSQL y pgAdmin

```bash
docker compose up -d postgres_db pgadmin_web
```

### 5.6 Comprobar estado

```bash
docker compose ps
```

El servicio `postgres_db` debe aparecer como `healthy`.

También puede comprobarse directamente:

```bash
docker compose exec postgres_db sh -lc 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

### 5.7 Entrar a PostgreSQL de forma interactiva

```bash
docker compose exec postgres_db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

Dentro de `psql` son útiles:

```text
\conninfo        -- conexión actual
\dt              -- tablas
\dv              -- vistas normales
\dm              -- vistas materializadas
\di              -- índices
\df              -- funciones
\q               -- salir
```

### 5.8 Forma recomendada de ejecutar archivos SQL

Como los archivos SQL están en el host y no están montados dentro de `postgres_db`, se envían por entrada estándar. En Bash, Git Bash, WSL, Linux o macOS puede definirse esta función una sola vez:

```bash
run_sql() {
  cat "$1" | docker compose exec -T postgres_db sh -lc 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
}
```

Después basta con escribir `run_sql "ruta/archivo.sql"`.

> `ON_ERROR_STOP=1` hace que `psql` detenga un script cuando aparece un error no controlado. Esto ayuda a detectar exactamente en qué paso falló la instalación.

### 5.9 Paso 1 — Crear estructura física: DDL

```bash
run_sql "DDL/DDL Examen.sql"
```

Este archivo crea **25 tablas**, claves primarias y foráneas, restricciones, **45 índices explícitos**, la función `set_updated_at()` y nueve triggers base de actualización automática.

Comprobación:

```bash
docker compose exec postgres_db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT COUNT(*) AS tablas FROM pg_tables WHERE schemaname = current_schema();"'
```

Resultado esperado: `25` tablas.

### 5.10 Paso 2 — Cargar datos base

```bash
run_sql "DML/DML Examen.sql"
```

Carga catálogos y un escenario base: tamaños de empresa, Colombia/Santander/Barrancabermeja, una organización demo, personas, cargos, SST/PESV, módulos, formatos, PHVA, plantillas, estados, documentos, versiones, evaluaciones y datos de control.

### 5.11 Paso 3 — Ampliar datos de prueba

```bash
run_sql "DML/DML_Ampliacion_EXAMEN.sql"
```

La ampliación crea escenarios necesarios para que las consultas devuelvan resultados demostrables, por ejemplo:

- empresas activas e inactivas;
- empresas con y sin personas;
- varios municipios y tamaños empresariales;
- módulos sin asignar;
- empresas con módulos pero sin plantillas;
- las cuatro etapas PHVA en una misma organización;
- documentos `FINISHED`, `DRAFT`, `PENDING` y `NOT_STARTED`;
- diferencias de cumplimiento SST/PESV;
- dos personas ocupando `Responsable SST` en Transportes del Magdalena.

### 5.12 Paso 4 — Ejecutar las 15 consultas básicas

```bash
run_sql "Consultas/consultas_basicas.sql"
```

Demuestran `SELECT`, `WHERE`, `LIKE`, `BETWEEN`, filtros booleanos y `ORDER BY`.

### 5.13 Paso 5 — Ejecutar las 20 consultas intermedias

```bash
run_sql "Consultas/consultas_intermedias.sql"
```

Demuestran `INNER JOIN`, `LEFT JOIN`, `COUNT`, `GROUP BY`, `HAVING` y relaciones entre varias entidades.

### 5.14 Paso 6 — Crear vistas y vistas materializadas

```bash
run_sql "Vistas/vistas_y_materializadas.sql"
```

Se crean cinco vistas normales y dos materializadas. Este paso debe ejecutarse **antes de las consultas avanzadas**, porque varias consultas avanzadas dependen de `vm_template_sst_docs_summary` y `vm_template_pesv_docs_summary`.

### 5.15 Paso 7 — Ejecutar las 25 consultas avanzadas

```bash
run_sql "Consultas/consultas_avanzadas.sql"
```

Incluyen CTE, subconsultas, `CASE`, `EXISTS`, agregaciones condicionales, funciones de ventana, rankings, indicadores y comparación SST/PESV. La consulta avanzada 25 crea además `vw_tenant_summary`.

### 5.16 Paso 8 — Crear los 15 procedimientos almacenados

```bash
run_sql "Procedimientos_Almacenados/Procedimientos_almacenados.sql"
```

### 5.17 Paso 9 — Crear las 8 funciones almacenadas

```bash
run_sql "Funciones/funciones_almacenadas.sql"
```

### 5.18 Paso 10 — Completar los 15 triggers del examen

```bash
run_sql "Triggers/triggers.sql"
```

El archivo recrea de forma segura los triggers `1`, `2` y `7` ya existentes en el DDL y agrega los demás comportamientos de validación, auditoría e integridad.

### 5.19 Paso 11 — Ejecutar pruebas integrales

```bash
run_sql "pruebas_crud_restricciones_funcionamiento.sql"
```

El archivo prueba CRUD, restricciones, procedimientos, funciones, triggers, auditoría, vistas y vistas materializadas. Comienza con `BEGIN` y termina con `ROLLBACK`, por lo que las operaciones de prueba no quedan almacenadas al final.

### 5.20 Refrescar vistas materializadas cuando cambien los datos

Las vistas normales consultan los datos actuales; las materializadas guardan un resultado físico y deben refrescarse.

```bash
docker compose exec postgres_db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "REFRESH MATERIALIZED VIEW vm_template_sst_docs_summary; REFRESH MATERIALIZED VIEW vm_template_pesv_docs_summary;"'
```

## 6. Ejecución completa en orden

Después de definir `run_sql`, la secuencia completa es:

```bash
run_sql "DDL/DDL Examen.sql"
run_sql "DML/DML Examen.sql"
run_sql "DML/DML_Ampliacion_EXAMEN.sql"
run_sql "Consultas/consultas_basicas.sql"
run_sql "Consultas/consultas_intermedias.sql"
run_sql "Vistas/vistas_y_materializadas.sql"
run_sql "Consultas/consultas_avanzadas.sql"
run_sql "Procedimientos_Almacenados/Procedimientos_almacenados.sql"
run_sql "Funciones/funciones_almacenadas.sql"
run_sql "Triggers/triggers.sql"
run_sql "pruebas_crud_restricciones_funcionamiento.sql"
```

## 7. Reiniciar el proyecto desde cero

Si se necesita una instalación totalmente limpia:

```bash
docker compose down -v
docker compose up -d postgres_db pgadmin_web
docker compose ps
```

Después se repite la secuencia del apartado anterior.

> `docker compose down -v` elimina los volúmenes `postgres_data` y `pgadmin_data`. Es destructivo: úselo solo cuando realmente quiera borrar la base y comenzar desde cero.

## 8. Diseño lógico y flujo de información

El flujo principal puede entenderse así:

```text
tenant_sizes ───────────────┐
countries → regions → municipalities ──→ tenants
                                      │
                                      ├─→ tenant_settings
                                      ├─→ positions ←→ persons
                                      │               │
                                      │               └─→ person_position_assignments
                                      │
type_system_sst → modules → formats_sst
       ↑              ↑
       └─ tenantsystems   tenant_modules ←─ tenants

templates ───────┐
formats_sst ─────┼─→ tenanttemplates ←─ tenants
phva_stages ─────┘          │
                            └─→ documents ← document_statuses
                                  │
                                  ├─→ document_versions ← persons
                                  └─→ editing_locks ← persons

evaluations ─→ tenant_evaluations ← tenants
                    ↑        ↑
          type_system_sst  phva_stages
                    │
                    └─→ evaluation_submissions ← persons

tenants ─→ audit_logs ← persons (opcional)
```

### Idea multi-tenant

`tenants` es el centro de aislamiento lógico. Una organización tiene sus propios cargos, personas, sistemas habilitados, módulos, plantillas, evaluaciones y auditoría. Algunas entidades son catálogos globales reutilizables, como países, etapas PHVA, sistemas, módulos, plantillas y estados.

### Idea híbrida

La base sigue siendo PostgreSQL relacional, pero usa `JSONB` cuando la estructura puede variar sin justificar nuevas columnas para cada cambio:

| Tabla                    | Columna JSONB          | Uso                                           |
| ------------------------ | ---------------------- | --------------------------------------------- |
| `tenant_settings`        | `settings`             | Preferencias variables por empresa            |
| `formats_sst`            | `structure`            | Estructura dinámica de cada formato           |
| `templates`              | `field_schema`         | Campos/requisitos de la plantilla             |
| `document_versions`      | `content`              | Contenido versionado del documento            |
| `evaluations`            | `question_schema`      | Esquema variable de preguntas                 |
| `evaluation_submissions` | `answers`              | Respuestas de una evaluación                  |
| `evaluation_submissions` | `result`               | Resultado/puntaje flexible                    |
| `audit_logs`             | `old_data`, `new_data` | Estado anterior y nuevo del registro auditado |

## 9. Diccionario de datos completo

El DDL define **25 tablas**. A continuación se documentan todas las tablas y todos sus atributos.

### 9.1 Organización y ubicación

#### `tenant_sizes`

Catálogo global de tamaños de empresa según rango de trabajadores.

| Atributo         | Definición SQL                        | Descripción                                                  |
| ---------------- | ------------------------------------- | ------------------------------------------------------------ |
| `tenant_size_id` | `BIGINT GENERATED ALWAYS AS IDENTITY` | Identificador interno autogenerado del tamaño empresarial.   |
| `name`           | `VARCHAR(50) NOT NULL`                | Nombre del tamaño empresarial.                               |
| `min_employees`  | `INTEGER NOT NULL`                    | Cantidad mínima de trabajadores del rango.                   |
| `max_employees`  | `INTEGER`                             | Cantidad máxima del rango; puede ser NULL para un rango abierto. |

**Restricciones de la tabla:**

- `CONSTRAINT pk_tenant_sizes PRIMARY KEY (tenant_size_id)`
- `CONSTRAINT uq_tenant_sizes_name UNIQUE (name)`
- `CONSTRAINT ck_tenant_sizes_min_employees CHECK (min_employees >= 0)`
- `CONSTRAINT ck_tenant_sizes_employee_range CHECK (max_employees IS NULL OR max_employees >= min_employees)`

#### `countries`

Catálogo de países usado por la jerarquía geográfica.

| Atributo     | Definición SQL                        | Descripción                                  |
| ------------ | ------------------------------------- | -------------------------------------------- |
| `country_id` | `BIGINT GENERATED ALWAYS AS IDENTITY` | Identificador interno autogenerado del país. |
| `name`       | `VARCHAR(100) NOT NULL`               | Nombre del país.                             |
| `iso_code`   | `CHAR(2) NOT NULL`                    | Código ISO de dos caracteres.                |

**Restricciones de la tabla:**

- `CONSTRAINT pk_countries PRIMARY KEY (country_id)`
- `CONSTRAINT uq_countries_name UNIQUE (name)`
- `CONSTRAINT uq_countries_iso_code UNIQUE (iso_code)`

#### `regions`

Departamentos o regiones pertenecientes a un país.

| Atributo     | Definición SQL                        | Descripción                                                  |
| ------------ | ------------------------------------- | ------------------------------------------------------------ |
| `region_id`  | `BIGINT GENERATED ALWAYS AS IDENTITY` | Identificador interno autogenerado de la región/departamento. |
| `country_id` | `BIGINT NOT NULL`                     | País al que pertenece la región.                             |
| `name`       | `VARCHAR(100) NOT NULL`               | Nombre de la región o departamento.                          |
| `code`       | `VARCHAR(20)`                         | Código administrativo opcional de la región.                 |

**Restricciones de la tabla:**

- `CONSTRAINT pk_regions PRIMARY KEY (region_id)`
- `CONSTRAINT uq_regions_country_name UNIQUE (country_id, name)`
- `CONSTRAINT fk_regions_country FOREIGN KEY (country_id) REFERENCES countries (country_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

#### `municipalities`

Municipios o ciudades pertenecientes a una región.

| Atributo          | Definición SQL                        | Descripción                                       |
| ----------------- | ------------------------------------- | ------------------------------------------------- |
| `municipality_id` | `BIGINT GENERATED ALWAYS AS IDENTITY` | Identificador interno autogenerado del municipio. |
| `region_id`       | `BIGINT NOT NULL`                     | Región/departamento al que pertenece.             |
| `name`            | `VARCHAR(100) NOT NULL`               | Nombre del municipio o ciudad.                    |
| `code`            | `VARCHAR(20)`                         | Código administrativo opcional del municipio.     |

**Restricciones de la tabla:**

- `CONSTRAINT pk_municipalities PRIMARY KEY (municipality_id)`
- `CONSTRAINT uq_municipalities_region_name UNIQUE (region_id, name)`
- `CONSTRAINT fk_municipalities_region FOREIGN KEY (region_id) REFERENCES regions (region_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

#### `tenants`

Entidad central del modelo multi-tenant. Cada fila representa una organización que utiliza la plataforma.

| Atributo                | Definición SQL                                   | Descripción                                                 |
| ----------------------- | ------------------------------------------------ | ----------------------------------------------------------- |
| `tenant_id`             | `BIGINT GENERATED ALWAYS AS IDENTITY`            | Identificador interno autogenerado de la organización.      |
| `tenant_size_id`        | `BIGINT NOT NULL`                                | Tamaño empresarial asignado.                                |
| `municipality_id`       | `BIGINT NOT NULL`                                | Municipio donde se registra la organización.                |
| `legal_name`            | `VARCHAR(200) NOT NULL`                          | Razón social o nombre legal.                                |
| `identification_type`   | `VARCHAR(20) NOT NULL`                           | Tipo de identificación empresarial, por ejemplo NIT.        |
| `identification_number` | `VARCHAR(30) NOT NULL`                           | Número de identificación de la organización.                |
| `contact_email`         | `VARCHAR(254) NOT NULL`                          | Correo principal de contacto.                               |
| `phone`                 | `VARCHAR(30) NOT NULL`                           | Teléfono principal.                                         |
| `address`               | `VARCHAR(250)`                                   | Dirección física opcional.                                  |
| `is_active`             | `BOOLEAN NOT NULL DEFAULT TRUE`                  | Indica si la organización está habilitada en la plataforma. |
| `created_at`            | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de creación.                                   |
| `updated_at`            | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de última actualización.                       |

**Restricciones de la tabla:**

- `CONSTRAINT pk_tenants PRIMARY KEY (tenant_id)`
- `CONSTRAINT uq_tenants_identification UNIQUE (identification_type, identification_number)`
- `CONSTRAINT fk_tenants_tenant_size FOREIGN KEY (tenant_size_id) REFERENCES tenant_sizes (tenant_size_id) ON UPDATE NO ACTION ON DELETE RESTRICT`
- `CONSTRAINT fk_tenants_municipality FOREIGN KEY (municipality_id) REFERENCES municipalities (municipality_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

#### `tenant_settings`

Configuración flexible y específica de cada organización almacenada en JSONB.

| Atributo     | Definición SQL                                   | Descripción                                                  |
| ------------ | ------------------------------------------------ | ------------------------------------------------------------ |
| `tenant_id`  | `BIGINT`                                         | Organización propietaria de la configuración y, al mismo tiempo, PK de la tabla. |
| `settings`   | `JSONB NOT NULL DEFAULT '{}'::JSONB`             | Objeto JSONB con preferencias variables por organización.    |
| `updated_at` | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de última actualización.                        |

**Restricciones de la tabla:**

- `CONSTRAINT pk_tenant_settings PRIMARY KEY (tenant_id)`
- `CONSTRAINT ck_tenant_settings_object CHECK (jsonb_typeof(settings) = 'object')`
- `CONSTRAINT fk_tenant_settings_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (tenant_id) ON UPDATE NO ACTION ON DELETE CASCADE`

### 9.2 Personas y cargos

#### `positions`

Cargos definidos dentro de cada organización.

| Atributo      | Definición SQL                                   | Descripción                                   |
| ------------- | ------------------------------------------------ | --------------------------------------------- |
| `position_id` | `BIGINT GENERATED ALWAYS AS IDENTITY`            | Identificador interno autogenerado del cargo. |
| `tenant_id`   | `BIGINT NOT NULL`                                | Organización a la que pertenece el cargo.     |
| `name`        | `VARCHAR(120) NOT NULL`                          | Nombre del cargo.                             |
| `description` | `TEXT`                                           | Descripción o responsabilidades del cargo.    |
| `is_active`   | `BOOLEAN NOT NULL DEFAULT TRUE`                  | Indica si el cargo puede seguir utilizándose. |
| `created_at`  | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de creación.                     |
| `updated_at`  | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de última actualización.         |

**Restricciones de la tabla:**

- `CONSTRAINT pk_positions PRIMARY KEY (position_id)`
- `CONSTRAINT uq_positions_tenant_name UNIQUE (tenant_id, name)`
- `CONSTRAINT fk_positions_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (tenant_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

#### `persons`

Personas o trabajadores vinculados a una organización.

| Atributo                | Definición SQL                                   | Descripción                                       |
| ----------------------- | ------------------------------------------------ | ------------------------------------------------- |
| `person_id`             | `BIGINT GENERATED ALWAYS AS IDENTITY`            | Identificador interno autogenerado de la persona. |
| `tenant_id`             | `BIGINT NOT NULL`                                | Organización a la que pertenece.                  |
| `first_name`            | `VARCHAR(100) NOT NULL`                          | Nombres de la persona.                            |
| `last_name`             | `VARCHAR(100) NOT NULL`                          | Apellidos de la persona.                          |
| `identification_number` | `VARCHAR(30) NOT NULL`                           | Documento de identificación dentro del tenant.    |
| `email`                 | `VARCHAR(254) NOT NULL`                          | Correo de la persona dentro del tenant.           |
| `phone`                 | `VARCHAR(30)`                                    | Teléfono opcional.                                |
| `is_active`             | `BOOLEAN NOT NULL DEFAULT TRUE`                  | Indica si la persona está activa.                 |
| `created_at`            | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de creación.                         |
| `updated_at`            | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de última actualización.             |

**Restricciones de la tabla:**

- `CONSTRAINT pk_persons PRIMARY KEY (person_id)`
- `CONSTRAINT uq_persons_tenant_identification UNIQUE (tenant_id, identification_number)`
- `CONSTRAINT uq_persons_tenant_email UNIQUE (tenant_id, email)`
- `CONSTRAINT fk_persons_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (tenant_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

#### `person_position_assignments`

Historial de asignación de cargos de cada persona; permite conservar cargos anteriores y uno activo.

| Atributo        | Definición SQL                        | Descripción                                                  |
| --------------- | ------------------------------------- | ------------------------------------------------------------ |
| `assignment_id` | `BIGINT GENERATED ALWAYS AS IDENTITY` | Identificador interno autogenerado de la asignación.         |
| `person_id`     | `BIGINT NOT NULL`                     | Persona a la que se asigna el cargo.                         |
| `position_id`   | `BIGINT NOT NULL`                     | Cargo asignado.                                              |
| `started_at`    | `DATE NOT NULL`                       | Fecha en que inicia la asignación.                           |
| `ended_at`      | `DATE`                                | Fecha de finalización; NULL significa que el cargo sigue activo. |

**Restricciones de la tabla:**

- `CONSTRAINT pk_person_position_assignments PRIMARY KEY (assignment_id)`
- `CONSTRAINT ck_person_position_assignment_dates CHECK (ended_at IS NULL OR ended_at >= started_at)`
- `CONSTRAINT fk_position_assignments_person FOREIGN KEY (person_id) REFERENCES persons (person_id) ON UPDATE NO ACTION ON DELETE RESTRICT`
- `CONSTRAINT fk_position_assignments_position FOREIGN KEY (position_id) REFERENCES positions (position_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

### 9.3 Sistemas, módulos y formatos

#### `type_system_sst`

Catálogo de sistemas de gestión soportados, principalmente SST y PESV.

| Atributo      | Definición SQL                        | Descripción                                     |
| ------------- | ------------------------------------- | ----------------------------------------------- |
| `system_id`   | `BIGINT GENERATED ALWAYS AS IDENTITY` | Identificador interno autogenerado del sistema. |
| `code`        | `VARCHAR(20) NOT NULL`                | Código corto único, por ejemplo SST o PESV.     |
| `name`        | `VARCHAR(100) NOT NULL`               | Nombre completo del sistema.                    |
| `description` | `TEXT`                                | Descripción funcional.                          |
| `is_active`   | `BOOLEAN NOT NULL DEFAULT TRUE`       | Indica si el sistema está disponible.           |

**Restricciones de la tabla:**

- `CONSTRAINT pk_type_system_sst PRIMARY KEY (system_id)`
- `CONSTRAINT uq_type_system_sst_code UNIQUE (code)`
- `CONSTRAINT uq_type_system_sst_name UNIQUE (name)`

#### `modules`

Módulos funcionales que pertenecen a un sistema SST/PESV.

| Atributo        | Definición SQL                        | Descripción                                    |
| --------------- | ------------------------------------- | ---------------------------------------------- |
| `module_id`     | `BIGINT GENERATED ALWAYS AS IDENTITY` | Identificador interno autogenerado del módulo. |
| `system_id`     | `BIGINT NOT NULL`                     | Sistema SST/PESV al que pertenece.             |
| `title`         | `VARCHAR(150) NOT NULL`               | Título del módulo.                             |
| `description`   | `TEXT`                                | Descripción funcional.                         |
| `display_order` | `INTEGER NOT NULL`                    | Orden de presentación dentro del sistema.      |
| `is_active`     | `BOOLEAN NOT NULL DEFAULT TRUE`       | Indica si el módulo está habilitado.           |

**Restricciones de la tabla:**

- `CONSTRAINT pk_modules PRIMARY KEY (module_id)`
- `CONSTRAINT uq_modules_system_title UNIQUE (system_id, title)`
- `CONSTRAINT ck_modules_display_order CHECK (display_order > 0)`
- `CONSTRAINT fk_modules_system FOREIGN KEY (system_id) REFERENCES type_system_sst (system_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

#### `formats_sst`

Formatos asociados a módulos; su estructura dinámica se almacena en JSONB.

| Atributo      | Definición SQL                                   | Descripción                                          |
| ------------- | ------------------------------------------------ | ---------------------------------------------------- |
| `format_id`   | `BIGINT GENERATED ALWAYS AS IDENTITY`            | Identificador interno autogenerado del formato.      |
| `module_id`   | `BIGINT NOT NULL`                                | Módulo al que pertenece.                             |
| `name`        | `VARCHAR(150) NOT NULL`                          | Nombre del formato.                                  |
| `description` | `TEXT`                                           | Descripción del formato.                             |
| `structure`   | `JSONB NOT NULL DEFAULT '{}'::JSONB`             | Objeto JSONB con la estructura dinámica del formato. |
| `version`     | `INTEGER NOT NULL DEFAULT 1`                     | Número de versión del formato.                       |
| `is_active`   | `BOOLEAN NOT NULL DEFAULT TRUE`                  | Indica si la versión puede utilizarse.               |
| `created_at`  | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de creación.                            |
| `updated_at`  | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de última actualización.                |

**Restricciones de la tabla:**

- `CONSTRAINT pk_formats_sst PRIMARY KEY (format_id)`
- `CONSTRAINT uq_formats_module_name_version UNIQUE (module_id, name, version)`
- `CONSTRAINT ck_formats_version CHECK (version > 0)`
- `CONSTRAINT ck_formats_structure_object CHECK (jsonb_typeof(structure) = 'object')`
- `CONSTRAINT fk_formats_module FOREIGN KEY (module_id) REFERENCES modules (module_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

#### `tenantsystems`

Tabla puente que habilita sistemas SST/PESV para cada organización.

| Atributo     | Definición SQL                                   | Descripción                                             |
| ------------ | ------------------------------------------------ | ------------------------------------------------------- |
| `tenant_id`  | `BIGINT NOT NULL`                                | Organización a la que se habilita el sistema.           |
| `system_id`  | `BIGINT NOT NULL`                                | Sistema habilitado.                                     |
| `enabled_at` | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de habilitación.                           |
| `is_active`  | `BOOLEAN NOT NULL DEFAULT TRUE`                  | Indica si la relación organización-sistema está activa. |

**Restricciones de la tabla:**

- `CONSTRAINT pk_tenantsystems PRIMARY KEY (tenant_id, system_id)`
- `CONSTRAINT fk_tenantsystems_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (tenant_id) ON UPDATE NO ACTION ON DELETE CASCADE`
- `CONSTRAINT fk_tenantsystems_system FOREIGN KEY (system_id) REFERENCES type_system_sst (system_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

#### `tenant_modules`

Tabla puente que habilita módulos concretos para cada organización.

| Atributo     | Definición SQL                                   | Descripción                                            |
| ------------ | ------------------------------------------------ | ------------------------------------------------------ |
| `tenant_id`  | `BIGINT NOT NULL`                                | Organización a la que se habilita el módulo.           |
| `module_id`  | `BIGINT NOT NULL`                                | Módulo habilitado.                                     |
| `enabled_at` | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de habilitación.                          |
| `is_active`  | `BOOLEAN NOT NULL DEFAULT TRUE`                  | Indica si la relación organización-módulo está activa. |

**Restricciones de la tabla:**

- `CONSTRAINT pk_tenant_modules PRIMARY KEY (tenant_id, module_id)`
- `CONSTRAINT fk_tenant_modules_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (tenant_id) ON UPDATE NO ACTION ON DELETE CASCADE`
- `CONSTRAINT fk_tenant_modules_module FOREIGN KEY (module_id) REFERENCES modules (module_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

### 9.4 PHVA, plantillas y documentos

#### `phva_stages`

Catálogo de las cuatro etapas PHVA: Planear, Hacer, Verificar y Actuar.

| Atributo        | Definición SQL                        | Descripción                                     |
| --------------- | ------------------------------------- | ----------------------------------------------- |
| `phva_stage_id` | `BIGINT GENERATED ALWAYS AS IDENTITY` | Identificador interno autogenerado de la etapa. |
| `code`          | `VARCHAR(10) NOT NULL`                | Código controlado: PLAN, DO, CHECK o ACT.       |
| `name`          | `VARCHAR(30) NOT NULL`                | Nombre legible de la etapa.                     |
| `display_order` | `SMALLINT NOT NULL`                   | Orden fijo de 1 a 4.                            |

**Restricciones de la tabla:**

- `CONSTRAINT pk_phva_stages PRIMARY KEY (phva_stage_id)`
- `CONSTRAINT uq_phva_stages_code UNIQUE (code)`
- `CONSTRAINT uq_phva_stages_name UNIQUE (name)`
- `CONSTRAINT uq_phva_stages_display_order UNIQUE (display_order)`
- `CONSTRAINT ck_phva_stages_code CHECK (code IN ('PLAN', 'DO', 'CHECK', 'ACT'))`
- `CONSTRAINT ck_phva_stages_display_order CHECK (display_order BETWEEN 1 AND 4)`

#### `templates`

Plantillas documentales reutilizables; define campos dinámicos mediante JSONB.

| Atributo       | Definición SQL                                   | Descripción                                                  |
| -------------- | ------------------------------------------------ | ------------------------------------------------------------ |
| `template_id`  | `BIGINT GENERATED ALWAYS AS IDENTITY`            | Identificador interno autogenerado de la plantilla.          |
| `name`         | `VARCHAR(180) NOT NULL`                          | Nombre único de la plantilla.                                |
| `description`  | `TEXT`                                           | Descripción de su finalidad.                                 |
| `field_schema` | `JSONB NOT NULL DEFAULT '{}'::JSONB`             | Objeto JSONB con campos o requisitos variables de la plantilla. |
| `is_active`    | `BOOLEAN NOT NULL DEFAULT TRUE`                  | Indica si la plantilla está disponible.                      |
| `created_at`   | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de creación.                                    |
| `updated_at`   | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de última actualización.                        |

**Restricciones de la tabla:**

- `CONSTRAINT pk_templates PRIMARY KEY (template_id)`
- `CONSTRAINT uq_templates_name UNIQUE (name)`
- `CONSTRAINT ck_templates_field_schema_object CHECK (jsonb_typeof(field_schema) = 'object')`

#### `tenanttemplates`

Asignación concreta de una plantilla, formato y etapa PHVA a una organización.

| Atributo             | Definición SQL                                   | Descripción                                          |
| -------------------- | ------------------------------------------------ | ---------------------------------------------------- |
| `tenant_template_id` | `BIGINT GENERATED ALWAYS AS IDENTITY`            | Identificador interno autogenerado de la asignación. |
| `tenant_id`          | `BIGINT NOT NULL`                                | Organización que recibe la plantilla.                |
| `template_id`        | `BIGINT NOT NULL`                                | Plantilla base asignada.                             |
| `format_id`          | `BIGINT NOT NULL`                                | Formato concreto utilizado.                          |
| `phva_stage_id`      | `BIGINT NOT NULL`                                | Etapa PHVA en la que se clasifica.                   |
| `assigned_at`        | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de asignación.                          |
| `is_active`          | `BOOLEAN NOT NULL DEFAULT TRUE`                  | Indica si la asignación está activa.                 |
| `updated_at`         | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de última actualización.                |

**Restricciones de la tabla:**

- `CONSTRAINT pk_tenanttemplates PRIMARY KEY (tenant_template_id)`
- `CONSTRAINT uq_tenanttemplates_assignment UNIQUE (tenant_id, template_id, format_id, phva_stage_id)`
- `CONSTRAINT fk_tenanttemplates_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (tenant_id) ON UPDATE NO ACTION ON DELETE RESTRICT`
- `CONSTRAINT fk_tenanttemplates_template FOREIGN KEY (template_id) REFERENCES templates (template_id) ON UPDATE NO ACTION ON DELETE RESTRICT`
- `CONSTRAINT fk_tenanttemplates_format FOREIGN KEY (format_id) REFERENCES formats_sst (format_id) ON UPDATE NO ACTION ON DELETE RESTRICT`
- `CONSTRAINT fk_tenanttemplates_phva_stage FOREIGN KEY (phva_stage_id) REFERENCES phva_stages (phva_stage_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

#### `document_statuses`

Catálogo de estados de documento y marca cuáles cuentan como completados.

| Atributo              | Definición SQL                        | Descripción                                             |
| --------------------- | ------------------------------------- | ------------------------------------------------------- |
| `document_status_id`  | `BIGINT GENERATED ALWAYS AS IDENTITY` | Identificador interno autogenerado del estado.          |
| `code`                | `VARCHAR(20) NOT NULL`                | Código controlado del estado.                           |
| `name`                | `VARCHAR(60) NOT NULL`                | Nombre legible del estado.                              |
| `counts_as_completed` | `BOOLEAN NOT NULL DEFAULT FALSE`      | Indica si el estado cuenta como cumplimiento terminado. |

**Restricciones de la tabla:**

- `CONSTRAINT pk_document_statuses PRIMARY KEY (document_status_id)`
- `CONSTRAINT uq_document_statuses_code UNIQUE (code)`
- `CONSTRAINT uq_document_statuses_name UNIQUE (name)`
- `CONSTRAINT ck_document_statuses_code CHECK (code IN ('NOT_STARTED', 'DRAFT', 'PENDING', 'FINISHED'))`

#### `documents`

Documentos generados o gestionados a partir de las plantillas asignadas a cada organización.

| Atributo             | Definición SQL                                   | Descripción                                       |
| -------------------- | ------------------------------------------------ | ------------------------------------------------- |
| `document_id`        | `BIGINT GENERATED ALWAYS AS IDENTITY`            | Identificador interno autogenerado del documento. |
| `tenant_template_id` | `BIGINT NOT NULL`                                | Plantilla asignada que origina el documento.      |
| `document_status_id` | `BIGINT NOT NULL`                                | Estado actual del documento.                      |
| `title`              | `VARCHAR(200) NOT NULL`                          | Título del documento.                             |
| `period_start`       | `DATE`                                           | Inicio opcional del período que cubre.            |
| `period_end`         | `DATE`                                           | Fin opcional del período que cubre.               |
| `due_date`           | `DATE`                                           | Fecha límite opcional.                            |
| `created_at`         | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de creación.                         |
| `updated_at`         | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de última actualización.             |

**Restricciones de la tabla:**

- `CONSTRAINT pk_documents PRIMARY KEY (document_id)`
- `CONSTRAINT ck_documents_period CHECK ( period_end IS NULL OR (period_start IS NOT NULL AND period_end >= period_start) )`
- `CONSTRAINT fk_documents_tenant_template FOREIGN KEY (tenant_template_id) REFERENCES tenanttemplates (tenant_template_id) ON UPDATE NO ACTION ON DELETE RESTRICT`
- `CONSTRAINT fk_documents_status FOREIGN KEY (document_status_id) REFERENCES document_statuses (document_status_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

#### `document_versions`

Historial de versiones de documentos con contenido flexible en JSONB.

| Atributo               | Definición SQL                                   | Descripción                                        |
| ---------------------- | ------------------------------------------------ | -------------------------------------------------- |
| `document_version_id`  | `BIGINT GENERATED ALWAYS AS IDENTITY`            | Identificador interno autogenerado de la versión.  |
| `document_id`          | `BIGINT NOT NULL`                                | Documento versionado.                              |
| `version_number`       | `INTEGER NOT NULL`                               | Número secuencial de versión dentro del documento. |
| `content`              | `JSONB NOT NULL DEFAULT '{}'::JSONB`             | Contenido estructurado de la versión en JSONB.     |
| `created_by_person_id` | `BIGINT NOT NULL`                                | Persona que creó la versión.                       |
| `created_at`           | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de creación.                          |

**Restricciones de la tabla:**

- `CONSTRAINT pk_document_versions PRIMARY KEY (document_version_id)`
- `CONSTRAINT uq_document_versions_number UNIQUE (document_id, version_number)`
- `CONSTRAINT ck_document_versions_number CHECK (version_number > 0)`
- `CONSTRAINT ck_document_versions_content_object CHECK (jsonb_typeof(content) = 'object')`
- `CONSTRAINT fk_document_versions_document FOREIGN KEY (document_id) REFERENCES documents (document_id) ON UPDATE NO ACTION ON DELETE CASCADE`
- `CONSTRAINT fk_document_versions_creator FOREIGN KEY (created_by_person_id) REFERENCES persons (person_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

### 9.5 Evaluaciones

#### `evaluations`

Plantillas de evaluación con esquema de preguntas dinámico en JSONB.

| Atributo          | Definición SQL                                   | Descripción                                          |
| ----------------- | ------------------------------------------------ | ---------------------------------------------------- |
| `evaluation_id`   | `BIGINT GENERATED ALWAYS AS IDENTITY`            | Identificador interno autogenerado de la evaluación. |
| `name`            | `VARCHAR(180) NOT NULL`                          | Nombre único de la evaluación.                       |
| `description`     | `TEXT`                                           | Descripción de la evaluación.                        |
| `question_schema` | `JSONB NOT NULL DEFAULT '{}'::JSONB`             | Objeto JSONB con preguntas y estructura dinámica.    |
| `is_active`       | `BOOLEAN NOT NULL DEFAULT TRUE`                  | Indica si la evaluación está disponible.             |
| `created_at`      | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de creación.                            |
| `updated_at`      | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de última actualización.                |

**Restricciones de la tabla:**

- `CONSTRAINT pk_evaluations PRIMARY KEY (evaluation_id)`
- `CONSTRAINT uq_evaluations_name UNIQUE (name)`
- `CONSTRAINT ck_evaluations_question_schema_object CHECK (jsonb_typeof(question_schema) = 'object')`

#### `tenant_evaluations`

Asignación de evaluaciones a una organización, opcionalmente ligadas a sistema y etapa PHVA.

| Atributo               | Definición SQL                                   | Descripción                                          |
| ---------------------- | ------------------------------------------------ | ---------------------------------------------------- |
| `tenant_evaluation_id` | `BIGINT GENERATED ALWAYS AS IDENTITY`            | Identificador interno autogenerado de la asignación. |
| `tenant_id`            | `BIGINT NOT NULL`                                | Organización que recibe la evaluación.               |
| `evaluation_id`        | `BIGINT NOT NULL`                                | Evaluación asignada.                                 |
| `system_id`            | `BIGINT`                                         | Sistema SST/PESV opcional al que aplica.             |
| `phva_stage_id`        | `BIGINT`                                         | Etapa PHVA opcional a la que aplica.                 |
| `assigned_at`          | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora de asignación.                          |
| `is_active`            | `BOOLEAN NOT NULL DEFAULT TRUE`                  | Indica si la asignación está activa.                 |

**Restricciones de la tabla:**

- `CONSTRAINT pk_tenant_evaluations PRIMARY KEY (tenant_evaluation_id)`
- `CONSTRAINT uq_tenant_evaluations_scope UNIQUE NULLS NOT DISTINCT (tenant_id, evaluation_id, system_id, phva_stage_id)`
- `CONSTRAINT fk_tenant_evaluations_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (tenant_id) ON UPDATE NO ACTION ON DELETE RESTRICT`
- `CONSTRAINT fk_tenant_evaluations_evaluation FOREIGN KEY (evaluation_id) REFERENCES evaluations (evaluation_id) ON UPDATE NO ACTION ON DELETE RESTRICT`
- `CONSTRAINT fk_tenant_evaluations_system FOREIGN KEY (system_id) REFERENCES type_system_sst (system_id) ON UPDATE NO ACTION ON DELETE RESTRICT`
- `CONSTRAINT fk_tenant_evaluations_phva_stage FOREIGN KEY (phva_stage_id) REFERENCES phva_stages (phva_stage_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

#### `evaluation_submissions`

Respuestas enviadas a evaluaciones y sus resultados, ambos almacenados en JSONB.

| Atributo                 | Definición SQL                                   | Descripción                                                  |
| ------------------------ | ------------------------------------------------ | ------------------------------------------------------------ |
| `submission_id`          | `BIGINT GENERATED ALWAYS AS IDENTITY`            | Identificador interno autogenerado del envío.                |
| `tenant_evaluation_id`   | `BIGINT NOT NULL`                                | Asignación de evaluación respondida.                         |
| `submitted_by_person_id` | `BIGINT NOT NULL`                                | Persona que envía la respuesta.                              |
| `evaluation_period`      | `VARCHAR(50) NOT NULL`                           | Período evaluado, por ejemplo 2026.                          |
| `answers`                | `JSONB NOT NULL DEFAULT '{}'::JSONB`             | Objeto JSONB con las respuestas.                             |
| `result`                 | `JSONB`                                          | Objeto JSONB opcional con resultado, puntaje o clasificación. |
| `submitted_at`           | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora del envío.                                      |

**Restricciones de la tabla:**

- `CONSTRAINT pk_evaluation_submissions PRIMARY KEY (submission_id)`
- `CONSTRAINT ck_evaluation_submissions_answers_object CHECK (jsonb_typeof(answers) = 'object')`
- `CONSTRAINT ck_evaluation_submissions_result_object CHECK (result IS NULL OR jsonb_typeof(result) = 'object')`
- `CONSTRAINT fk_evaluation_submissions_assignment FOREIGN KEY (tenant_evaluation_id) REFERENCES tenant_evaluations (tenant_evaluation_id) ON UPDATE NO ACTION ON DELETE RESTRICT`
- `CONSTRAINT fk_evaluation_submissions_submitter FOREIGN KEY (submitted_by_person_id) REFERENCES persons (person_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

### 9.6 Concurrencia y auditoría

#### `editing_locks`

Bloqueos temporales para evitar edición simultánea de un mismo documento.

| Atributo              | Definición SQL                                   | Descripción                                     |
| --------------------- | ------------------------------------------------ | ----------------------------------------------- |
| `editing_lock_id`     | `BIGINT GENERATED ALWAYS AS IDENTITY`            | Identificador interno autogenerado del bloqueo. |
| `document_id`         | `BIGINT NOT NULL`                                | Documento bloqueado.                            |
| `locked_by_person_id` | `BIGINT NOT NULL`                                | Persona que mantiene el bloqueo.                |
| `locked_at`           | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Inicio del bloqueo.                             |
| `expires_at`          | `TIMESTAMPTZ NOT NULL`                           | Fecha y hora de vencimiento.                    |
| `is_active`           | `BOOLEAN NOT NULL DEFAULT TRUE`                  | Indica si el bloqueo sigue vigente.             |

**Restricciones de la tabla:**

- `CONSTRAINT pk_editing_locks PRIMARY KEY (editing_lock_id)`
- `CONSTRAINT ck_editing_locks_expiration CHECK (expires_at > locked_at)`
- `CONSTRAINT fk_editing_locks_document FOREIGN KEY (document_id) REFERENCES documents (document_id) ON UPDATE NO ACTION ON DELETE CASCADE`
- `CONSTRAINT fk_editing_locks_person FOREIGN KEY (locked_by_person_id) REFERENCES persons (person_id) ON UPDATE NO ACTION ON DELETE RESTRICT`

#### `audit_logs`

Bitácora de auditoría con valores anteriores/nuevos en JSONB y referencia opcional a la persona responsable.

| Atributo               | Definición SQL                                   | Descripción                                                 |
| ---------------------- | ------------------------------------------------ | ----------------------------------------------------------- |
| `audit_log_id`         | `BIGINT GENERATED ALWAYS AS IDENTITY`            | Identificador interno autogenerado del evento de auditoría. |
| `tenant_id`            | `BIGINT NOT NULL`                                | Organización propietaria del registro auditado.             |
| `table_name`           | `VARCHAR(63) NOT NULL`                           | Nombre de la tabla afectada.                                |
| `record_identifier`    | `VARCHAR(100) NOT NULL`                          | Identificador textual del registro afectado.                |
| `operation`            | `VARCHAR(10) NOT NULL`                           | Operación auditada: INSERT, UPDATE o DELETE.                |
| `old_data`             | `JSONB`                                          | Estado anterior del registro en JSONB.                      |
| `new_data`             | `JSONB`                                          | Estado nuevo del registro en JSONB.                         |
| `changed_by_person_id` | `BIGINT`                                         | Persona responsable, si se conoce.                          |
| `changed_at`           | `TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` | Fecha y hora del cambio.                                    |

**Restricciones de la tabla:**

- `CONSTRAINT pk_audit_logs PRIMARY KEY (audit_log_id)`
- `CONSTRAINT ck_audit_logs_operation CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE'))`
- `CONSTRAINT ck_audit_logs_old_data_object CHECK (old_data IS NULL OR jsonb_typeof(old_data) = 'object')`
- `CONSTRAINT ck_audit_logs_new_data_object CHECK (new_data IS NULL OR jsonb_typeof(new_data) = 'object')`
- `CONSTRAINT fk_audit_logs_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (tenant_id) ON UPDATE NO ACTION ON DELETE RESTRICT`
- `CONSTRAINT fk_audit_logs_changed_by_person FOREIGN KEY (changed_by_person_id) REFERENCES persons (person_id) ON UPDATE NO ACTION ON DELETE SET NULL`

## 10. Relaciones y cardinalidades

| Origen               | Cardinalidad | Destino                       | Implementación                                               |
| -------------------- | -----------: | ----------------------------- | ------------------------------------------------------------ |
| `countries`          |          1:N | `regions`                     | `regions.country_id → countries.country_id`                  |
| `regions`            |          1:N | `municipalities`              | `municipalities.region_id → regions.region_id`               |
| `tenant_sizes`       |          1:N | `tenants`                     | `tenants.tenant_size_id → tenant_sizes.tenant_size_id`       |
| `municipalities`     |          1:N | `tenants`                     | `tenants.municipality_id → municipalities.municipality_id`   |
| `tenants`            |          1:1 | `tenant_settings`             | `tenant_settings.tenant_id → tenants.tenant_id`              |
| `tenants`            |          1:N | `positions`                   | `positions.tenant_id → tenants.tenant_id`                    |
| `tenants`            |          1:N | `persons`                     | `persons.tenant_id → tenants.tenant_id`                      |
| `persons`            |          1:N | `person_position_assignments` | `person_position_assignments.person_id → persons.person_id`  |
| `positions`          |          1:N | `person_position_assignments` | `person_position_assignments.position_id → positions.position_id` |
| `type_system_sst`    |          1:N | `modules`                     | `modules.system_id → type_system_sst.system_id`              |
| `modules`            |          1:N | `formats_sst`                 | `formats_sst.module_id → modules.module_id`                  |
| `tenants`            |          N:M | `type_system_sst`             | Resuelta por `tenantsystems`                                 |
| `tenants`            |          N:M | `modules`                     | Resuelta por `tenant_modules`                                |
| `tenants`            |          1:N | `tenanttemplates`             | `tenanttemplates.tenant_id → tenants.tenant_id`              |
| `templates`          |          1:N | `tenanttemplates`             | `tenanttemplates.template_id → templates.template_id`        |
| `formats_sst`        |          1:N | `tenanttemplates`             | `tenanttemplates.format_id → formats_sst.format_id`          |
| `phva_stages`        |          1:N | `tenanttemplates`             | `tenanttemplates.phva_stage_id → phva_stages.phva_stage_id`  |
| `tenanttemplates`    |          1:N | `documents`                   | `documents.tenant_template_id → tenanttemplates.tenant_template_id` |
| `document_statuses`  |          1:N | `documents`                   | `documents.document_status_id → document_statuses.document_status_id` |
| `documents`          |          1:N | `document_versions`           | `document_versions.document_id → documents.document_id`      |
| `persons`            |          1:N | `document_versions`           | `document_versions.created_by_person_id → persons.person_id` |
| `tenants`            |          1:N | `tenant_evaluations`          | `tenant_evaluations.tenant_id → tenants.tenant_id`           |
| `evaluations`        |          1:N | `tenant_evaluations`          | `tenant_evaluations.evaluation_id → evaluations.evaluation_id` |
| `type_system_sst`    |          1:N | `tenant_evaluations`          | `tenant_evaluations.system_id → type_system_sst.system_id`   |
| `phva_stages`        |          1:N | `tenant_evaluations`          | `tenant_evaluations.phva_stage_id → phva_stages.phva_stage_id` |
| `tenant_evaluations` |          1:N | `evaluation_submissions`      | `evaluation_submissions.tenant_evaluation_id → tenant_evaluations.tenant_evaluation_id` |
| `persons`            |          1:N | `evaluation_submissions`      | `evaluation_submissions.submitted_by_person_id → persons.person_id` |
| `documents`          |          1:N | `editing_locks`               | `editing_locks.document_id → documents.document_id`          |
| `persons`            |          1:N | `editing_locks`               | `editing_locks.locked_by_person_id → persons.person_id`      |
| `tenants`            |          1:N | `audit_logs`                  | `audit_logs.tenant_id → tenants.tenant_id`                   |
| `persons`            | 1:N opcional | `audit_logs`                  | `audit_logs.changed_by_person_id → persons.person_id`        |

### Reglas importantes de relación

- Una persona pertenece a un solo `tenant`, pero puede conservar historial de cargos mediante `person_position_assignments`.
- El índice parcial `uq_person_active_position` permite como máximo **un cargo activo** por persona (`ended_at IS NULL`).
- `tenantsystems` resuelve la relación N:M entre organizaciones y sistemas.
- `tenant_modules` resuelve la relación N:M entre organizaciones y módulos.
- `tenanttemplates` une organización + plantilla + formato + etapa PHVA y evita duplicar exactamente la misma asignación.
- `documents` siempre nace de una plantilla previamente asignada a una organización.
- `document_versions` conserva contenido histórico del documento; borrar un documento elimina sus versiones por `ON DELETE CASCADE`.
- `editing_locks` controla concurrencia documental y permite un solo bloqueo activo por documento mediante índice parcial.

## 11. Integridad y restricciones

El modelo aplica:

- `PRIMARY KEY` para identificar registros;
- `FOREIGN KEY` para mantener integridad referencial;
- `UNIQUE` para evitar duplicados de negocio;
- `CHECK` para rangos, códigos y estructuras JSONB;
- `NOT NULL` para datos obligatorios;
- `ON DELETE RESTRICT` cuando no debe borrarse un padre con dependencias;
- `ON DELETE CASCADE` en relaciones donde el hijo pierde sentido sin el padre;
- `ON DELETE SET NULL` para conservar auditoría aunque la persona responsable desaparezca;
- índices parciales únicos para un cargo activo por persona y un bloqueo activo por documento.

## 12. Índices

El DDL crea **45 índices explícitos** para claves foráneas, filtros frecuentes, fechas, búsqueda por estado y reglas de unicidad parcial.

| Índice                                 | Tabla                         | Columnas/expresión                       | Tipo   | Condición          |
| -------------------------------------- | ----------------------------- | ---------------------------------------- | ------ | ------------------ |
| `ix_regions_country`                   | `regions`                     | `country_id`                             | INDEX  | —                  |
| `ix_municipalities_region`             | `municipalities`              | `region_id`                              | INDEX  | —                  |
| `ix_tenants_size`                      | `tenants`                     | `tenant_size_id`                         | INDEX  | —                  |
| `ix_tenants_municipality`              | `tenants`                     | `municipality_id`                        | INDEX  | —                  |
| `ix_tenants_legal_name`                | `tenants`                     | `legal_name`                             | INDEX  | —                  |
| `ix_tenants_legal_name_lower`          | `tenants`                     | `LOWER(legal_name)`                      | INDEX  | —                  |
| `ix_tenants_active`                    | `tenants`                     | `is_active`                              | INDEX  | —                  |
| `ix_tenants_created_at`                | `tenants`                     | `created_at`                             | INDEX  | —                  |
| `ix_positions_tenant`                  | `positions`                   | `tenant_id`                              | INDEX  | —                  |
| `ix_positions_tenant_active`           | `positions`                   | `tenant_id, is_active`                   | INDEX  | —                  |
| `ix_persons_tenant`                    | `persons`                     | `tenant_id`                              | INDEX  | —                  |
| `ix_persons_tenant_active`             | `persons`                     | `tenant_id, is_active`                   | INDEX  | —                  |
| `ix_position_assignments_person`       | `person_position_assignments` | `person_id`                              | INDEX  | —                  |
| `ix_position_assignments_position`     | `person_position_assignments` | `position_id`                            | INDEX  | —                  |
| `uq_person_active_position`            | `person_position_assignments` | `person_id`                              | UNIQUE | `ended_at IS NULL` |
| `ix_modules_system_order`              | `modules`                     | `system_id, display_order`               | INDEX  | —                  |
| `ix_formats_module`                    | `formats_sst`                 | `module_id`                              | INDEX  | —                  |
| `ix_tenantsystems_system`              | `tenantsystems`               | `system_id`                              | INDEX  | —                  |
| `ix_tenantsystems_tenant_active`       | `tenantsystems`               | `tenant_id, is_active`                   | INDEX  | —                  |
| `ix_tenant_modules_module`             | `tenant_modules`              | `module_id`                              | INDEX  | —                  |
| `ix_tenant_modules_tenant_active`      | `tenant_modules`              | `tenant_id, is_active`                   | INDEX  | —                  |
| `ix_tenanttemplates_tenant_phva`       | `tenanttemplates`             | `tenant_id, phva_stage_id`               | INDEX  | —                  |
| `ix_tenanttemplates_template`          | `tenanttemplates`             | `template_id`                            | INDEX  | —                  |
| `ix_tenanttemplates_format`            | `tenanttemplates`             | `format_id`                              | INDEX  | —                  |
| `ix_tenanttemplates_updated`           | `tenanttemplates`             | `updated_at`                             | INDEX  | —                  |
| `ix_documents_tenant_template`         | `documents`                   | `tenant_template_id`                     | INDEX  | —                  |
| `ix_documents_status`                  | `documents`                   | `document_status_id`                     | INDEX  | —                  |
| `ix_documents_due_date`                | `documents`                   | `due_date`                               | INDEX  | —                  |
| `ix_documents_updated`                 | `documents`                   | `updated_at`                             | INDEX  | —                  |
| `ix_documents_template_status`         | `documents`                   | `tenant_template_id, document_status_id` | INDEX  | —                  |
| `ix_document_versions_creator`         | `document_versions`           | `created_by_person_id`                   | INDEX  | —                  |
| `ix_tenant_evaluations_tenant`         | `tenant_evaluations`          | `tenant_id`                              | INDEX  | —                  |
| `ix_tenant_evaluations_evaluation`     | `tenant_evaluations`          | `evaluation_id`                          | INDEX  | —                  |
| `ix_tenant_evaluations_system`         | `tenant_evaluations`          | `system_id`                              | INDEX  | —                  |
| `ix_tenant_evaluations_phva`           | `tenant_evaluations`          | `phva_stage_id`                          | INDEX  | —                  |
| `ix_evaluation_submissions_assignment` | `evaluation_submissions`      | `tenant_evaluation_id`                   | INDEX  | —                  |
| `ix_evaluation_submissions_submitter`  | `evaluation_submissions`      | `submitted_by_person_id`                 | INDEX  | —                  |
| `ix_evaluation_submissions_date`       | `evaluation_submissions`      | `submitted_at`                           | INDEX  | —                  |
| `ix_editing_locks_document`            | `editing_locks`               | `document_id`                            | INDEX  | —                  |
| `ix_editing_locks_person`              | `editing_locks`               | `locked_by_person_id`                    | INDEX  | —                  |
| `ix_editing_locks_expires`             | `editing_locks`               | `expires_at`                             | INDEX  | —                  |
| `uq_active_lock_per_document`          | `editing_locks`               | `document_id`                            | UNIQUE | `is_active`        |
| `ix_audit_logs_tenant_date`            | `audit_logs`                  | `tenant_id, changed_at`                  | INDEX  | —                  |
| `ix_audit_logs_record`                 | `audit_logs`                  | `table_name, record_identifier`          | INDEX  | —                  |
| `ix_audit_logs_person`                 | `audit_logs`                  | `changed_by_person_id`                   | INDEX  | —                  |

Las claves primarias y restricciones `UNIQUE` también generan índices internos de PostgreSQL, por lo que `\di` puede mostrar más objetos que los 45 índices explícitos del script.

## 13. Consultas del examen

| Archivo                               | Cantidad | Nivel / propósito                                       |
| ------------------------------------- | -------: | ------------------------------------------------------- |
| `Consultas/consultas_basicas.sql`     |       15 | SELECT, filtros, LIKE, BETWEEN, ORDER BY                |
| `Consultas/consultas_intermedias.sql` |       20 | JOIN, LEFT JOIN, agregaciones, GROUP BY, HAVING         |
| `Consultas/consultas_avanzadas.sql`   |       25 | CTE, subconsultas, CASE, ventanas, indicadores y vistas |

Las consultas están numeradas en el mismo orden del examen para que sea fácil relacionar cada enunciado con su implementación.

## 14. Vistas y vistas materializadas

| Objeto                          | Tipo                                              | Propósito                                                    |
| ------------------------------- | ------------------------------------------------- | ------------------------------------------------------------ |
| `vw_tenant_persons`             | Vista normal                                      | Organizaciones con sus personas y cargo actual.              |
| `vw_tenant_geography`           | Vista normal                                      | Ubicación completa de cada organización: municipio, región y país. |
| `vw_tenant_modules`             | Vista normal                                      | Módulos activos por organización y sistema.                  |
| `vw_tenant_templates_phva`      | Vista normal                                      | Cantidad de plantillas por organización y etapa PHVA.        |
| `vw_tenant_persons_by_position` | Vista normal                                      | Cantidad de personas por organización y cargo.               |
| `vm_template_sst_docs_summary`  | Vista materializada                               | Resumen documental SST: totales, estados, cumplimiento y última actualización. |
| `vm_template_pesv_docs_summary` | Vista materializada                               | Resumen documental PESV: totales, estados, cumplimiento y última actualización. |
| `vw_tenant_summary`             | Vista normal (se crea en consultas avanzadas #25) | Consolida cantidad de personas, módulos, plantillas y sistemas por organización. |

Las dos vistas materializadas se indexan por `tenant_id` y por `porcentaje_cumplimiento`, porque son columnas usadas con frecuencia para seguimiento y comparación entre organizaciones.

## 15. Procedimientos almacenados

Los 15 procedimientos usan `PL/pgSQL`, parámetros, validaciones, `IF`, variables, `RAISE NOTICE`, `RAISE EXCEPTION` y manejo de errores.

|    # | Procedimiento                     | Parámetros                                                   | Propósito                                                    |
| ---: | --------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
|    1 | `sp_registrar_tenant`             | `p_tenant_size_id BIGINT, p_municipality_id BIGINT, p_legal_name VARCHAR(200), p_identification_type VARCHAR(20), p_identification_number VARCHAR(30), p_contact_email VARCHAR(254), p_phone VARCHAR(30), p_address VARCHAR(250)` | Registra una organización y valida identificación duplicada. |
|    2 | `sp_registrar_persona`            | `p_tenant_id BIGINT, p_position_id BIGINT, p_first_name VARCHAR(100), p_last_name VARCHAR(100), p_identification_number VARCHAR(30), p_email VARCHAR(254), p_phone VARCHAR(30)` | Registra una persona y la asocia a un cargo válido del mismo tenant. |
|    3 | `sp_cambiar_estado_tenant`        | `p_tenant_id BIGINT`                                         | Alterna el estado activo/inactivo de una organización.       |
|    4 | `sp_asignar_modulo`               | `p_tenant_id BIGINT, p_module_id BIGINT`                     | Asigna un módulo evitando duplicados.                        |
|    5 | `sp_habilitar_sistema`            | `p_tenant_id BIGINT, p_system_id BIGINT`                     | Crea o reactiva un sistema para una organización.            |
|    6 | `sp_asignar_plantilla`            | `p_tenant_id BIGINT, p_template_id BIGINT, p_system_id BIGINT, p_phva_stage_id BIGINT, p_format_id BIGINT` | Asigna plantilla validando tenant, sistema, formato, etapa y duplicados. |
|    7 | `sp_cambiar_cargo_persona`        | `p_person_id BIGINT, p_new_position_id BIGINT`               | Cierra el cargo activo anterior y crea una nueva asignación. |
|    8 | `sp_trasladar_persona`            | `p_person_id BIGINT, p_new_tenant_id BIGINT, p_new_position_id BIGINT` | Traslada una persona a otro tenant y le asigna un cargo válido allí. |
|    9 | `sp_deshabilitar_modulos_tenant`  | `p_tenant_id BIGINT`                                         | Desactiva módulos de una organización previamente inactiva.  |
|   10 | `sp_eliminar_asignacion_modulo`   | `p_tenant_id BIGINT, p_module_id BIGINT`                     | Elimina una asignación de módulo solo si no tiene dependencias. |
|   11 | `sp_total_plantillas_tenant`      | `p_tenant_id BIGINT`                                         | Cuenta plantillas del tenant y muestra el total con RAISE NOTICE. |
|   12 | `sp_calcular_cumplimiento_tenant` | `p_tenant_id BIGINT`                                         | Calcula y muestra total, finalizados, pendientes y porcentaje. |
|   13 | `sp_documentos_por_phva`          | `p_tenant_id BIGINT, p_phva_stage_id BIGINT`                 | Cuenta documentos de una organización en una etapa PHVA.     |
|   14 | `sp_actualizar_contacto_tenant`   | `p_tenant_id BIGINT, p_contact_email VARCHAR(254), p_phone VARCHAR(30), p_address VARCHAR(250)` | Actualiza correo, teléfono, dirección y fecha de actualización. |
|   15 | `sp_asignar_plantilla_segura`     | `p_tenant_id BIGINT, p_template_id BIGINT, p_system_id BIGINT, p_phva_stage_id BIGINT, p_format_id BIGINT` | Envuelve la asignación de plantilla con manejo de excepciones. |

Se invocan con `CALL`, por ejemplo:

```sql
CALL sp_total_plantillas_tenant(1);
```

## 16. Funciones almacenadas

|    # | Función                      | Parámetros                                   | Retorno        | Propósito                                           |
| ---: | ---------------------------- | -------------------------------------------- | -------------- | --------------------------------------------------- |
|    1 | `fn_total_personas_tenant`   | `p_tenant_id BIGINT`                         | `BIGINT`       | Cantidad total de personas de una organización.     |
|    2 | `fn_porcentaje_cumplimiento` | `p_tenant_id BIGINT`                         | `NUMERIC(5,2)` | Porcentaje documental completado del tenant.        |
|    3 | `fn_tiene_modulo`            | `p_tenant_id BIGINT, p_module_id BIGINT`     | `BOOLEAN`      | Indica si un módulo está habilitado para el tenant. |
|    4 | `fn_nombre_completo_persona` | `p_person_id BIGINT`                         | `TEXT`         | Devuelve nombre y apellido de una persona.          |
|    5 | `fn_total_plantillas_phva`   | `p_tenant_id BIGINT, p_phva_stage_id BIGINT` | `BIGINT`       | Cuenta plantillas de un tenant en una etapa PHVA.   |
|    6 | `fn_modulos_tenant`          | `p_tenant_id BIGINT`                         | `TABLE`        | Devuelve módulos activos del tenant con su sistema. |
|    7 | `fn_personas_cargos_tenant`  | `p_tenant_id BIGINT`                         | `TABLE`        | Devuelve personas de un tenant con su cargo actual. |
|    8 | `fn_nivel_cumplimiento`      | `p_tenant_id BIGINT`                         | `VARCHAR(10)`  | Clasifica cumplimiento como Bajo, Medio o Alto.     |

Se consultan con `SELECT`, por ejemplo:

```sql
SELECT fn_porcentaje_cumplimiento(1);
SELECT * FROM fn_modulos_tenant(1);
```

## 17. Triggers

### 17.1 Triggers base creados por el DDL

El DDL crea nueve triggers que reutilizan `set_updated_at()`:

| Trigger                              | Tabla             |
| ------------------------------------ | ----------------- |
| `trg_tenants_set_updated_at`         | `tenants`         |
| `trg_tenant_settings_set_updated_at` | `tenant_settings` |
| `trg_positions_set_updated_at`       | `positions`       |
| `trg_persons_set_updated_at`         | `persons`         |
| `trg_formats_sst_set_updated_at`     | `formats_sst`     |
| `trg_templates_set_updated_at`       | `templates`       |
| `trg_tenanttemplates_set_updated_at` | `tenanttemplates` |
| `trg_documents_set_updated_at`       | `documents`       |
| `trg_evaluations_set_updated_at`     | `evaluations`     |

### 17.2 Los 15 comportamientos exigidos por el examen

|    # | Trigger                                    | Tabla                         | Momento                           | Regla                                                        |
| ---: | ------------------------------------------ | ----------------------------- | --------------------------------- | ------------------------------------------------------------ |
|    1 | `trg_tenants_set_updated_at`               | `tenants`                     | BEFORE UPDATE                     | Actualiza `updated_at` automáticamente.                      |
|    2 | `trg_persons_set_updated_at`               | `persons`                     | BEFORE UPDATE                     | Actualiza `updated_at` automáticamente.                      |
|    3 | `trg_validar_tenant_activo_persona`        | `persons`                     | BEFORE INSERT / UPDATE tenant_id  | Impide registrar o mover una persona hacia un tenant inactivo. |
|    4 | `trg_validar_modulo_duplicado`             | `tenant_modules`              | BEFORE INSERT                     | Impide asignar dos veces el mismo módulo a una organización. |
|    5 | `trg_validar_tenant_activo_plantilla`      | `tenanttemplates`             | BEFORE INSERT / UPDATE tenant_id  | Impide asignar plantillas a tenants inactivos.               |
|    6 | `trg_validar_persona_cargo_tenant`         | `person_position_assignments` | BEFORE INSERT / UPDATE            | Valida que persona y cargo pertenezcan a la misma organización. |
|    7 | `trg_tenanttemplates_set_updated_at`       | `tenanttemplates`             | BEFORE UPDATE                     | Actualiza la fecha de modificación de una plantilla asignada. |
|    8 | `trg_impedir_eliminar_tenant_con_personas` | `tenants`                     | BEFORE DELETE                     | Impide borrar una organización que todavía tiene personas.   |
|    9 | `trg_impedir_eliminar_sistema_en_uso`      | `type_system_sst`             | BEFORE DELETE                     | Impide borrar un sistema usado por organizaciones.           |
|   10 | `trg_impedir_eliminar_modulo_asignado`     | `modules`                     | BEFORE DELETE                     | Impide borrar un módulo asignado.                            |
|   11 | `trg_validar_rango_cumplimiento`           | `documents`                   | AFTER INSERT / UPDATE / DELETE    | Recalcula y valida que cumplimiento permanezca entre 0 y 100. |
|   12 | `trg_auditar_datos_tenant`                 | `tenants`                     | AFTER UPDATE de datos principales | Registra cambios generales del tenant en `audit_logs`.       |
|   13 | `trg_auditar_estado_tenant`                | `tenants`                     | AFTER UPDATE is_active            | Guarda estado anterior y nuevo cuando cambia `is_active`.    |
|   14 | `trg_auditar_modificacion_plantilla`       | `tenanttemplates`             | AFTER UPDATE                      | Registra modificación, fecha y usuario PostgreSQL en auditoría. |
|   15 | `trg_desactivar_bloqueos_vencidos`         | `editing_locks`               | BEFORE INSERT                     | Marca como inactivos los bloqueos cuyo `expires_at` ya pasó. |

> Los triggers 1, 2 y 7 del archivo `Triggers/triggers.sql` tienen los mismos nombres de tres triggers ya creados en el DDL. El archivo hace `DROP TRIGGER IF EXISTS` y los recrea; no quedan duplicados. Al final existen los triggers base de `updated_at` para las demás tablas más los nuevos triggers de validación/auditoría.

## 18. Datos de prueba y escenarios

### DML base

`DML/DML Examen.sql` crea el escenario inicial con:

- catálogo de tamaños empresariales;
- Colombia → Santander → Barrancabermeja;
- `Empresa Demo SST S.A.S.`;
- cargos y personas;
- sistemas `SST` y `PESV`;
- módulos y formatos base;
- las cuatro etapas PHVA;
- plantillas y documentos;
- estados documentales;
- versiones, evaluaciones y datos de control.

### DML de ampliación

`DML/DML_Ampliacion_EXAMEN.sql` agrega Bucaramanga y Floridablanca, cinco organizaciones adicionales y escenarios deliberados para probar consultas.

| Organización                            | Escenario principal                                          |
| --------------------------------------- | ------------------------------------------------------------ |
| Transportes del Magdalena S.A.S.        | Personas, SST+PESV, todos los módulos SST, PHVA completo y estados documentales variados |
| Construcciones Seguras Ltda.            | Organización sin personas                                    |
| Agroindustrial del Puerto S.A.S.        | Tiene módulos SST pero no plantillas                         |
| Servicios Integrales del Oriente S.A.S. | Organización inactiva y sin personas                         |
| Logística Vial Santander S.A.S.         | Escenario PESV con cumplimiento completo                     |

Transportes del Magdalena incluye dos personas en `Responsable SST` (Miguel Rojas y Camila Gómez), escenario utilizado por la consulta avanzada que compara ocupación de cargos contra el promedio del tenant.

## 19. Pruebas de funcionamiento

`pruebas_crud_restricciones_funcionamiento.sql` es un archivo de evidencia. No aparece como una sección independiente del examen, pero demuestra que los requisitos implementados funcionan.

Incluye pruebas de:

- CRUD;
- `UNIQUE`, `NOT NULL`, `FOREIGN KEY` y `CHECK`;
- validación de objetos JSONB;
- índice único parcial de cargo activo;
- 15 procedimientos;
- 8 funciones;
- 15 triggers;
- auditoría;
- vistas;
- vistas materializadas.

Las pruebas negativas se ejecutan dentro de bloques `DO ... EXCEPTION`, por lo que un error esperado se captura y el archivo puede continuar.

## 20. Verificación final desde terminal

### Contar tablas

```bash
docker compose exec postgres_db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname = current_schema();"'
```

Esperado: `25`.

### Listar tablas

```bash
docker compose exec postgres_db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt"'
```

### Listar vistas normales

```bash
docker compose exec postgres_db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dv"'
```

Después de ejecutar consultas avanzadas deben aparecer las cinco vistas de `Vistas/` más `vw_tenant_summary`.

### Listar vistas materializadas

```bash
docker compose exec postgres_db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dm"'
```

Esperado:

```text
vm_template_sst_docs_summary
vm_template_pesv_docs_summary
```

### Listar procedimientos y funciones

```bash
docker compose exec postgres_db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT routine_name, routine_type FROM information_schema.routines WHERE specific_schema = current_schema() ORDER BY routine_type, routine_name;"'
```

### Listar triggers

```bash
docker compose exec postgres_db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT DISTINCT trigger_name, event_object_table FROM information_schema.triggers WHERE trigger_schema = current_schema() ORDER BY event_object_table, trigger_name;"'
```

### Revisar datos principales

```bash
docker compose exec postgres_db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT tenant_id, legal_name, is_active FROM tenants ORDER BY tenant_id;"'
```

### Revisar cumplimiento SST

```bash
docker compose exec postgres_db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT * FROM vm_template_sst_docs_summary ORDER BY tenant_id;"'
```

### Revisar cumplimiento PESV

```bash
docker compose exec postgres_db sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT * FROM vm_template_pesv_docs_summary ORDER BY tenant_id;"'
```

## 21. pgAdmin opcional

Aunque la ejecución oficial de esta guía se hace desde terminal, pgAdmin queda disponible mediante el puerto definido en `PGADMIN_PORT`.

Para registrar el servidor en pgAdmin:

- **Host:** `postgres_db`
- **Port:** `5432`
- **Maintenance database:** valor de `POSTGRES_DB`
- **Username:** valor de `POSTGRES_USER`
- **Password:** valor de `POSTGRES_PASSWORD`

Desde el navegador se accede a `http://localhost:<PGADMIN_PORT>`.

## 22. Errores frecuentes

### `workspace` no construye

Causa: falta `.devcontainer/Dockerfile` en la versión actual. Para el examen use:

```bash
docker compose up -d postgres_db pgadmin_web
```

### `relation ... already exists` al ejecutar DDL

El DDL crea objetos desde cero y no usa `CREATE TABLE IF NOT EXISTS`. Reinicie la base con `docker compose down -v` y vuelva a ejecutar la secuencia.

### Datos repetidos o escenarios extraños

No ejecute juntos `DML UPDATED EXAMEN.sql` y `DML_Ampliacion_EXAMEN.sql`. Use únicamente la ampliación indicada en esta guía.

### La vista materializada no refleja un cambio

Ejecute:

```sql
REFRESH MATERIALIZED VIEW vm_template_sst_docs_summary;
REFRESH MATERIALIZED VIEW vm_template_pesv_docs_summary;
```

### PostgreSQL no aparece como `healthy`

```bash
docker compose logs postgres_db --tail=100
```

Revise `.env`, puertos ocupados y credenciales.

### Puerto ocupado

Cambie `POSTGRES_PORT` o `PGADMIN_PORT` en `.env` y vuelva a levantar los servicios.

## 23. Correspondencia con el examen

| Requisito                  | Implementación del proyecto                                  |
| -------------------------- | ------------------------------------------------------------ |
| Modelo físico PostgreSQL   | `DDL/DDL Examen.sql`                                         |
| Multi-tenant               | `tenants` y relaciones por `tenant_id`                       |
| Normalización e integridad | PK, FK, UNIQUE, CHECK, NOT NULL                              |
| CRUD                       | DML, procedimientos y archivo de pruebas                     |
| 15 consultas básicas       | `Consultas/consultas_basicas.sql`                            |
| 20 consultas intermedias   | `Consultas/consultas_intermedias.sql`                        |
| 25 consultas avanzadas     | `Consultas/consultas_avanzadas.sql`                          |
| Vistas y materializadas    | `Vistas/vistas_y_materializadas.sql` + `vw_tenant_summary`   |
| 15 procedimientos          | `Procedimientos_Almacenados/Procedimientos_almacenados.sql`  |
| 8 funciones                | `Funciones/funciones_almacenadas.sql`                        |
| 15 triggers requeridos     | `Triggers/triggers.sql`                                      |
| Índices                    | 45 índices explícitos en el DDL más índices de PK/UNIQUE     |
| Concurrencia               | `editing_locks` + índice de bloqueo activo + trigger de vencimiento |
| Auditoría                  | `audit_logs` + triggers de auditoría                         |
| Indicadores                | vistas materializadas y consultas de cumplimiento            |
| Documentación técnica      | este README + modelos lógico/físico/E-R                      |

## 24. Resumen para sustentación

La idea central puede explicarse así:

> La base administra varias organizaciones en una sola instancia PostgreSQL. `tenants` identifica cada empresa y el resto del modelo mantiene la separación mediante relaciones directas o indirectas con ese tenant. La información estructurada se normaliza en tablas relacionales y los datos variables se guardan en JSONB. SST y PESV comparten catálogos de sistemas, módulos, formatos, plantillas y PHVA; las organizaciones habilitan únicamente lo que necesitan. Los documentos se generan a partir de plantillas asignadas, tienen estados y versiones, y su cumplimiento puede consolidarse mediante vistas materializadas. Los procedimientos ejecutan operaciones de negocio, las funciones retornan cálculos o conjuntos de datos y los triggers automatizan validaciones, fechas, auditoría y concurrencia.

---

**Motor objetivo:** PostgreSQL 16  
**Ejecución principal:** terminal + Docker Compose + `psql`  
**Modelo:** multi-tenant, relacional e híbrido mediante JSONB