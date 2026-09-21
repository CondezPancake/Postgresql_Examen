BEGIN;

-- 1. ORGANIZACION Y TENANTS

CREATE TABLE tenant_sizes (
    tenant_size_id BIGINT GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(50) NOT NULL,
    min_employees INTEGER NOT NULL,
    max_employees INTEGER,

    CONSTRAINT pk_tenant_sizes PRIMARY KEY (tenant_size_id),
    CONSTRAINT uq_tenant_sizes_name UNIQUE (name),
    CONSTRAINT ck_tenant_sizes_min_employees
        CHECK (min_employees >= 0),
    CONSTRAINT ck_tenant_sizes_employee_range
        CHECK (max_employees IS NULL OR max_employees >= min_employees)
);

CREATE TABLE countries (
    country_id BIGINT GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(100) NOT NULL,
    iso_code CHAR(2) NOT NULL,

    CONSTRAINT pk_countries PRIMARY KEY (country_id),
    CONSTRAINT uq_countries_name UNIQUE (name),
    CONSTRAINT uq_countries_iso_code UNIQUE (iso_code)
);

CREATE TABLE regions (
    region_id BIGINT GENERATED ALWAYS AS IDENTITY,
    country_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20),

    CONSTRAINT pk_regions PRIMARY KEY (region_id),
    CONSTRAINT uq_regions_country_name UNIQUE (country_id, name),
    CONSTRAINT fk_regions_country
        FOREIGN KEY (country_id)
        REFERENCES countries (country_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

CREATE TABLE municipalities (
    municipality_id BIGINT GENERATED ALWAYS AS IDENTITY,
    region_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20),

    CONSTRAINT pk_municipalities PRIMARY KEY (municipality_id),
    CONSTRAINT uq_municipalities_region_name UNIQUE (region_id, name),
    CONSTRAINT fk_municipalities_region
        FOREIGN KEY (region_id)
        REFERENCES regions (region_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

CREATE TABLE tenants (
    tenant_id BIGINT GENERATED ALWAYS AS IDENTITY,
    tenant_size_id BIGINT NOT NULL,
    municipality_id BIGINT NOT NULL,
    legal_name VARCHAR(200) NOT NULL,
    identification_type VARCHAR(20) NOT NULL,
    identification_number VARCHAR(30) NOT NULL,
    contact_email VARCHAR(254) NOT NULL,
    phone VARCHAR(30) NOT NULL,
    address VARCHAR(250),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_tenants PRIMARY KEY (tenant_id),
    CONSTRAINT uq_tenants_identification
        UNIQUE (identification_type, identification_number),
    CONSTRAINT fk_tenants_tenant_size
        FOREIGN KEY (tenant_size_id)
        REFERENCES tenant_sizes (tenant_size_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_tenants_municipality
        FOREIGN KEY (municipality_id)
        REFERENCES municipalities (municipality_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

CREATE TABLE tenant_settings (
    tenant_id BIGINT,
    settings JSONB NOT NULL DEFAULT '{}'::JSONB,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_tenant_settings PRIMARY KEY (tenant_id),
    CONSTRAINT ck_tenant_settings_object
        CHECK (jsonb_typeof(settings) = 'object'),
    CONSTRAINT fk_tenant_settings_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants (tenant_id)
        ON UPDATE NO ACTION
        ON DELETE CASCADE
);

-- 2. PERSONAS Y CARGOS


CREATE TABLE positions (
    position_id BIGINT GENERATED ALWAYS AS IDENTITY,
    tenant_id BIGINT NOT NULL,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_positions PRIMARY KEY (position_id),
    CONSTRAINT uq_positions_tenant_name UNIQUE (tenant_id, name),
    CONSTRAINT fk_positions_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants (tenant_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

CREATE TABLE persons (
    person_id BIGINT GENERATED ALWAYS AS IDENTITY,
    tenant_id BIGINT NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    identification_number VARCHAR(30) NOT NULL,
    email VARCHAR(254) NOT NULL,
    phone VARCHAR(30),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_persons PRIMARY KEY (person_id),
    CONSTRAINT uq_persons_tenant_identification
        UNIQUE (tenant_id, identification_number),
    CONSTRAINT uq_persons_tenant_email UNIQUE (tenant_id, email),
    CONSTRAINT fk_persons_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants (tenant_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

CREATE TABLE person_position_assignments (
    assignment_id BIGINT GENERATED ALWAYS AS IDENTITY,
    person_id BIGINT NOT NULL,
    position_id BIGINT NOT NULL,
    started_at DATE NOT NULL,
    ended_at DATE,

    CONSTRAINT pk_person_position_assignments PRIMARY KEY (assignment_id),
    CONSTRAINT ck_person_position_assignment_dates
        CHECK (ended_at IS NULL OR ended_at >= started_at),
    CONSTRAINT fk_position_assignments_person
        FOREIGN KEY (person_id)
        REFERENCES persons (person_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_position_assignments_position
        FOREIGN KEY (position_id)
        REFERENCES positions (position_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

-- 3. SISTEMAS, MODULOS Y FORMATOS


CREATE TABLE type_system_sst (
    system_id BIGINT GENERATED ALWAYS AS IDENTITY,
    code VARCHAR(20) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_type_system_sst PRIMARY KEY (system_id),
    CONSTRAINT uq_type_system_sst_code UNIQUE (code),
    CONSTRAINT uq_type_system_sst_name UNIQUE (name)
);

CREATE TABLE modules (
    module_id BIGINT GENERATED ALWAYS AS IDENTITY,
    system_id BIGINT NOT NULL,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    display_order INTEGER NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_modules PRIMARY KEY (module_id),
    CONSTRAINT uq_modules_system_title UNIQUE (system_id, title),
    CONSTRAINT ck_modules_display_order CHECK (display_order > 0),
    CONSTRAINT fk_modules_system
        FOREIGN KEY (system_id)
        REFERENCES type_system_sst (system_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

CREATE TABLE formats_sst (
    format_id BIGINT GENERATED ALWAYS AS IDENTITY,
    module_id BIGINT NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    structure JSONB NOT NULL DEFAULT '{}'::JSONB,
    version INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_formats_sst PRIMARY KEY (format_id),
    CONSTRAINT uq_formats_module_name_version
        UNIQUE (module_id, name, version),
    CONSTRAINT ck_formats_version CHECK (version > 0),
    CONSTRAINT ck_formats_structure_object
        CHECK (jsonb_typeof(structure) = 'object'),
    CONSTRAINT fk_formats_module
        FOREIGN KEY (module_id)
        REFERENCES modules (module_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

CREATE TABLE tenantsystems (
    tenant_id BIGINT NOT NULL,
    system_id BIGINT NOT NULL,
    enabled_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_tenantsystems PRIMARY KEY (tenant_id, system_id),
    CONSTRAINT fk_tenantsystems_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants (tenant_id)
        ON UPDATE NO ACTION
        ON DELETE CASCADE,
    CONSTRAINT fk_tenantsystems_system
        FOREIGN KEY (system_id)
        REFERENCES type_system_sst (system_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

CREATE TABLE tenant_modules (
    tenant_id BIGINT NOT NULL,
    module_id BIGINT NOT NULL,
    enabled_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_tenant_modules PRIMARY KEY (tenant_id, module_id),
    CONSTRAINT fk_tenant_modules_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants (tenant_id)
        ON UPDATE NO ACTION
        ON DELETE CASCADE,
    CONSTRAINT fk_tenant_modules_module
        FOREIGN KEY (module_id)
        REFERENCES modules (module_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

-- 4. PHVA, PLANTILLAS Y DOCUMENTOS


CREATE TABLE phva_stages (
    phva_stage_id BIGINT GENERATED ALWAYS AS IDENTITY,
    code VARCHAR(10) NOT NULL,
    name VARCHAR(30) NOT NULL,
    display_order SMALLINT NOT NULL,

    CONSTRAINT pk_phva_stages PRIMARY KEY (phva_stage_id),
    CONSTRAINT uq_phva_stages_code UNIQUE (code),
    CONSTRAINT uq_phva_stages_name UNIQUE (name),
    CONSTRAINT uq_phva_stages_display_order UNIQUE (display_order),
    CONSTRAINT ck_phva_stages_code
        CHECK (code IN ('PLAN', 'DO', 'CHECK', 'ACT')),
    CONSTRAINT ck_phva_stages_display_order
        CHECK (display_order BETWEEN 1 AND 4)
);

CREATE TABLE templates (
    template_id BIGINT GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(180) NOT NULL,
    description TEXT,
    field_schema JSONB NOT NULL DEFAULT '{}'::JSONB,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_templates PRIMARY KEY (template_id),
    CONSTRAINT uq_templates_name UNIQUE (name),
    CONSTRAINT ck_templates_field_schema_object
        CHECK (jsonb_typeof(field_schema) = 'object')
);

CREATE TABLE tenanttemplates (
    tenant_template_id BIGINT GENERATED ALWAYS AS IDENTITY,
    tenant_id BIGINT NOT NULL,
    template_id BIGINT NOT NULL,
    format_id BIGINT NOT NULL,
    phva_stage_id BIGINT NOT NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_tenanttemplates PRIMARY KEY (tenant_template_id),
    CONSTRAINT uq_tenanttemplates_assignment
        UNIQUE (tenant_id, template_id, format_id, phva_stage_id),
    CONSTRAINT fk_tenanttemplates_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants (tenant_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_tenanttemplates_template
        FOREIGN KEY (template_id)
        REFERENCES templates (template_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_tenanttemplates_format
        FOREIGN KEY (format_id)
        REFERENCES formats_sst (format_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_tenanttemplates_phva_stage
        FOREIGN KEY (phva_stage_id)
        REFERENCES phva_stages (phva_stage_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

CREATE TABLE document_statuses (
    document_status_id BIGINT GENERATED ALWAYS AS IDENTITY,
    code VARCHAR(20) NOT NULL,
    name VARCHAR(60) NOT NULL,
    counts_as_completed BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_document_statuses PRIMARY KEY (document_status_id),
    CONSTRAINT uq_document_statuses_code UNIQUE (code),
    CONSTRAINT uq_document_statuses_name UNIQUE (name),
    CONSTRAINT ck_document_statuses_code
        CHECK (code IN ('NOT_STARTED', 'DRAFT', 'PENDING', 'FINISHED'))
);

CREATE TABLE documents (
    document_id BIGINT GENERATED ALWAYS AS IDENTITY,
    tenant_template_id BIGINT NOT NULL,
    document_status_id BIGINT NOT NULL,
    title VARCHAR(200) NOT NULL,
    period_start DATE,
    period_end DATE,
    due_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_documents PRIMARY KEY (document_id),
    CONSTRAINT ck_documents_period
        CHECK (
            period_end IS NULL
            OR (period_start IS NOT NULL AND period_end >= period_start)
        ),
    CONSTRAINT fk_documents_tenant_template
        FOREIGN KEY (tenant_template_id)
        REFERENCES tenanttemplates (tenant_template_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_documents_status
        FOREIGN KEY (document_status_id)
        REFERENCES document_statuses (document_status_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

CREATE TABLE document_versions (
    document_version_id BIGINT GENERATED ALWAYS AS IDENTITY,
    document_id BIGINT NOT NULL,
    version_number INTEGER NOT NULL,
    content JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_by_person_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_document_versions PRIMARY KEY (document_version_id),
    CONSTRAINT uq_document_versions_number
        UNIQUE (document_id, version_number),
    CONSTRAINT ck_document_versions_number CHECK (version_number > 0),
    CONSTRAINT ck_document_versions_content_object
        CHECK (jsonb_typeof(content) = 'object'),
    CONSTRAINT fk_document_versions_document
        FOREIGN KEY (document_id)
        REFERENCES documents (document_id)
        ON UPDATE NO ACTION
        ON DELETE CASCADE,
    CONSTRAINT fk_document_versions_creator
        FOREIGN KEY (created_by_person_id)
        REFERENCES persons (person_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);


-- 5. EVALUACIONES ORGANIZACIONALES


CREATE TABLE evaluations (
    evaluation_id BIGINT GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(180) NOT NULL,
    description TEXT,
    question_schema JSONB NOT NULL DEFAULT '{}'::JSONB,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_evaluations PRIMARY KEY (evaluation_id),
    CONSTRAINT uq_evaluations_name UNIQUE (name),
    CONSTRAINT ck_evaluations_question_schema_object
        CHECK (jsonb_typeof(question_schema) = 'object')
);

CREATE TABLE tenant_evaluations (
    tenant_evaluation_id BIGINT GENERATED ALWAYS AS IDENTITY,
    tenant_id BIGINT NOT NULL,
    evaluation_id BIGINT NOT NULL,
    system_id BIGINT,
    phva_stage_id BIGINT,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_tenant_evaluations PRIMARY KEY (tenant_evaluation_id),
    CONSTRAINT uq_tenant_evaluations_scope
        UNIQUE NULLS NOT DISTINCT
        (tenant_id, evaluation_id, system_id, phva_stage_id),
    CONSTRAINT fk_tenant_evaluations_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants (tenant_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_tenant_evaluations_evaluation
        FOREIGN KEY (evaluation_id)
        REFERENCES evaluations (evaluation_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_tenant_evaluations_system
        FOREIGN KEY (system_id)
        REFERENCES type_system_sst (system_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_tenant_evaluations_phva_stage
        FOREIGN KEY (phva_stage_id)
        REFERENCES phva_stages (phva_stage_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

CREATE TABLE evaluation_submissions (
    submission_id BIGINT GENERATED ALWAYS AS IDENTITY,
    tenant_evaluation_id BIGINT NOT NULL,
    submitted_by_person_id BIGINT NOT NULL,
    evaluation_period VARCHAR(50) NOT NULL,
    answers JSONB NOT NULL DEFAULT '{}'::JSONB,
    result JSONB,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_evaluation_submissions PRIMARY KEY (submission_id),
    CONSTRAINT ck_evaluation_submissions_answers_object
        CHECK (jsonb_typeof(answers) = 'object'),
    CONSTRAINT ck_evaluation_submissions_result_object
        CHECK (result IS NULL OR jsonb_typeof(result) = 'object'),
    CONSTRAINT fk_evaluation_submissions_assignment
        FOREIGN KEY (tenant_evaluation_id)
        REFERENCES tenant_evaluations (tenant_evaluation_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_evaluation_submissions_submitter
        FOREIGN KEY (submitted_by_person_id)
        REFERENCES persons (person_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

-- 6. CONCURRENCIA Y AUDITORIA


CREATE TABLE editing_locks (
    editing_lock_id BIGINT GENERATED ALWAYS AS IDENTITY,
    document_id BIGINT NOT NULL,
    locked_by_person_id BIGINT NOT NULL,
    locked_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_editing_locks PRIMARY KEY (editing_lock_id),
    CONSTRAINT ck_editing_locks_expiration CHECK (expires_at > locked_at),
    CONSTRAINT fk_editing_locks_document
        FOREIGN KEY (document_id)
        REFERENCES documents (document_id)
        ON UPDATE NO ACTION
        ON DELETE CASCADE,
    CONSTRAINT fk_editing_locks_person
        FOREIGN KEY (locked_by_person_id)
        REFERENCES persons (person_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT
);

CREATE TABLE audit_logs (
    audit_log_id BIGINT GENERATED ALWAYS AS IDENTITY,
    tenant_id BIGINT NOT NULL,
    table_name VARCHAR(63) NOT NULL,
    record_identifier VARCHAR(100) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    old_data JSONB,
    new_data JSONB,
    changed_by_person_id BIGINT,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_audit_logs PRIMARY KEY (audit_log_id),
    CONSTRAINT ck_audit_logs_operation
        CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    CONSTRAINT ck_audit_logs_old_data_object
        CHECK (old_data IS NULL OR jsonb_typeof(old_data) = 'object'),
    CONSTRAINT ck_audit_logs_new_data_object
        CHECK (new_data IS NULL OR jsonb_typeof(new_data) = 'object'),
    CONSTRAINT fk_audit_logs_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants (tenant_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_audit_logs_changed_by_person
        FOREIGN KEY (changed_by_person_id)
        REFERENCES persons (person_id)
        ON UPDATE NO ACTION
        ON DELETE SET NULL
);

-- 7. INDICES PARA CLAVES FORANEAS Y CONSULTAS FRECUENTES


CREATE INDEX ix_regions_country
    ON regions (country_id);

CREATE INDEX ix_municipalities_region
    ON municipalities (region_id);

CREATE INDEX ix_tenants_size
    ON tenants (tenant_size_id);

CREATE INDEX ix_tenants_municipality
    ON tenants (municipality_id);

CREATE INDEX ix_tenants_legal_name
    ON tenants (legal_name);

CREATE INDEX ix_tenants_legal_name_lower
    ON tenants (LOWER(legal_name));

CREATE INDEX ix_tenants_active
    ON tenants (is_active);

CREATE INDEX ix_tenants_created_at
    ON tenants (created_at);

CREATE INDEX ix_positions_tenant
    ON positions (tenant_id);

CREATE INDEX ix_positions_tenant_active
    ON positions (tenant_id, is_active);

CREATE INDEX ix_persons_tenant
    ON persons (tenant_id);

CREATE INDEX ix_persons_tenant_active
    ON persons (tenant_id, is_active);

CREATE INDEX ix_position_assignments_person
    ON person_position_assignments (person_id);

CREATE INDEX ix_position_assignments_position
    ON person_position_assignments (position_id);

CREATE UNIQUE INDEX uq_person_active_position
    ON person_position_assignments (person_id)
    WHERE ended_at IS NULL;

CREATE INDEX ix_modules_system_order
    ON modules (system_id, display_order);

CREATE INDEX ix_formats_module
    ON formats_sst (module_id);

CREATE INDEX ix_tenantsystems_system
    ON tenantsystems (system_id);

CREATE INDEX ix_tenantsystems_tenant_active
    ON tenantsystems (tenant_id, is_active);

CREATE INDEX ix_tenant_modules_module
    ON tenant_modules (module_id);

CREATE INDEX ix_tenant_modules_tenant_active
    ON tenant_modules (tenant_id, is_active);

CREATE INDEX ix_tenanttemplates_tenant_phva
    ON tenanttemplates (tenant_id, phva_stage_id);

CREATE INDEX ix_tenanttemplates_template
    ON tenanttemplates (template_id);

CREATE INDEX ix_tenanttemplates_format
    ON tenanttemplates (format_id);

CREATE INDEX ix_tenanttemplates_updated
    ON tenanttemplates (updated_at);

CREATE INDEX ix_documents_tenant_template
    ON documents (tenant_template_id);

CREATE INDEX ix_documents_status
    ON documents (document_status_id);

CREATE INDEX ix_documents_due_date
    ON documents (due_date);

CREATE INDEX ix_documents_updated
    ON documents (updated_at);

CREATE INDEX ix_documents_template_status
    ON documents (tenant_template_id, document_status_id);

CREATE INDEX ix_document_versions_creator
    ON document_versions (created_by_person_id);

CREATE INDEX ix_tenant_evaluations_tenant
    ON tenant_evaluations (tenant_id);

CREATE INDEX ix_tenant_evaluations_evaluation
    ON tenant_evaluations (evaluation_id);

CREATE INDEX ix_tenant_evaluations_system
    ON tenant_evaluations (system_id);

CREATE INDEX ix_tenant_evaluations_phva
    ON tenant_evaluations (phva_stage_id);

CREATE INDEX ix_evaluation_submissions_assignment
    ON evaluation_submissions (tenant_evaluation_id);

CREATE INDEX ix_evaluation_submissions_submitter
    ON evaluation_submissions (submitted_by_person_id);

CREATE INDEX ix_evaluation_submissions_date
    ON evaluation_submissions (submitted_at);

CREATE INDEX ix_editing_locks_document
    ON editing_locks (document_id);

CREATE INDEX ix_editing_locks_person
    ON editing_locks (locked_by_person_id);

CREATE INDEX ix_editing_locks_expires
    ON editing_locks (expires_at);

CREATE UNIQUE INDEX uq_active_lock_per_document
    ON editing_locks (document_id)
    WHERE is_active;

CREATE INDEX ix_audit_logs_tenant_date
    ON audit_logs (tenant_id, changed_at);

CREATE INDEX ix_audit_logs_record
    ON audit_logs (table_name, record_identifier);

CREATE INDEX ix_audit_logs_person
    ON audit_logs (changed_by_person_id);


-- 8. ACTUALIZACION AUTOMATICA DE updated_at


CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_tenants_set_updated_at
BEFORE UPDATE ON tenants
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_tenant_settings_set_updated_at
BEFORE UPDATE ON tenant_settings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_positions_set_updated_at
BEFORE UPDATE ON positions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_persons_set_updated_at
BEFORE UPDATE ON persons
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_formats_sst_set_updated_at
BEFORE UPDATE ON formats_sst
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_templates_set_updated_at
BEFORE UPDATE ON templates
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_tenanttemplates_set_updated_at
BEFORE UPDATE ON tenanttemplates
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_documents_set_updated_at
BEFORE UPDATE ON documents
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_evaluations_set_updated_at
BEFORE UPDATE ON evaluations
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMIT;

-- Fin del DDL.
