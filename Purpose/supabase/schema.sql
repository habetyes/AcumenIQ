-- This file contains the SQL commands to create the database schema for the AccumenIQ application.

-- Tables
CREATE TABLE public.latest (
    casefile_id text,
    patient_id text,
    patient_master_id text,
    first_name text,
    last_name text,
    gender text,
    first_contact_date timestamp with time zone,
    admission_date timestamp with time zone,
    discharge_date timestamp with time zone,
    anticipated_discharge_date timestamp with time zone,
    discharge_type text,
    discharge_type_code text,
    referrer_name text,
    mr_number text,
    payment_method text,
    payment_method_category text,
    created_at timestamp with time zone,
    last_updated_at timestamp with time zone,
    insurance_company text,
    level_of_care text,
    program text,
    location_id double precision,
    location_name text,
    record_source text
);

CREATE TABLE public.ref_discharge_types (
    discharge_type_code text,
    discharge_type text,
    discharge_class text,
    discharge_category text,
    discharge_subcategory text,
    transfer_program text
);


CREATE TABLE public.ref_program_types (
    program text,
    program_level text,
    program_category text,
    program_class text,
    program_location text
);


CREATE TABLE public.stg_admin_discharge (
    form_id bigint,
    name text,
    status text,
    casefile_id text,
    evaluation_id bigint,
    patient_process_id bigint,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    evaluation_content text,
    patient_id text,
    patient_master_id text
);


CREATE TABLE public.stg_ama_forms (
    form_id bigint,
    name text,
    status text,
    casefile_id text,
    evaluation_id bigint,
    patient_process_id bigint,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    evaluation_content text,
    patient_id text,
    patient_master_id text
);


CREATE TABLE public.stg_detox_forms (
    form_id bigint,
    name text,
    status text,
    casefile_id text,
    evaluation_id bigint,
    patient_process_id bigint,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    evaluation_content text,
    patient_id text,
    patient_master_id text,
    step_down_value text,
    transferred text
);


CREATE TABLE public.stg_latest (
    casefile_id text,
    patient_id text,
    patient_master_id text,
    first_name text,
    last_name text,
    gender text,
    first_contact_date timestamp with time zone,
    admission_date timestamp with time zone,
    discharge_date timestamp with time zone,
    anticipated_discharge_date timestamp with time zone,
    discharge_type text,
    discharge_type_code text,
    referrer_name text,
    mr_number text,
    payment_method text,
    payment_method_category text,
    created_at timestamp with time zone,
    last_updated_at timestamp with time zone,
    insurance_company text,
    level_of_care text,
    program text,
    location_id double precision,
    location_name text,
    record_source text
);


CREATE TABLE public.program_history (
    casefile_id text,
    patient_id text,
    patient_master_id text,
    first_name text,
    last_name text,
    program_name text,
    start_date timestamp with time zone,
    logged_by text,
    logged_at timestamp with time zone,
    program_history_pk integer NOT NULL
);


CREATE TABLE public.admin_discharge (
    form_id bigint,
    name text,
    status text,
    casefile_id text,
    evaluation_id bigint,
    patient_process_id bigint,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    evaluation_content text,
    patient_id text,
    patient_master_id text
);


CREATE TABLE public.ama_forms (
    form_id bigint,
    name text,
    status text,
    casefile_id text,
    evaluation_id bigint,
    patient_process_id bigint,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    evaluation_content text,
    patient_id text,
    patient_master_id text
);

CREATE TABLE public.calendar (
    date date,
    year integer,
    month integer,
    day integer,
    quarter integer,
    week bigint,
    day_of_week integer,
    weekday_name text,
    month_name text,
    is_weekend bigint
);


CREATE TABLE public.detox_forms (
    form_id bigint,
    name text,
    status text,
    casefile_id text,
    evaluation_id bigint,
    patient_process_id bigint,
    created_at timestamp with time zone,
    created_by text,
    updated_at timestamp with time zone,
    updated_by text,
    evaluation_content text,
    patient_id text,
    patient_master_id text,
    step_down_value text,
    transferred text
);


CREATE TABLE public.error_log (
    error_log_id integer NOT NULL,
    casefile_id text,
    error_message text NOT NULL,
    error_time timestamp with time zone NOT NULL,
    procedure_name text
);


-- Sequences
CREATE SEQUENCE public.error_log_error_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


CREATE SEQUENCE public.program_history_program_history_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


-- Alter Tables
ALTER TABLE ONLY public.error_log ALTER COLUMN error_log_id SET DEFAULT nextval('public.error_log_error_log_id_seq'::regclass);

ALTER TABLE ONLY public.program_history ALTER COLUMN program_history_pk SET DEFAULT nextval('public.program_history_program_history_pk_seq'::regclass);


ALTER TABLE ONLY public.admin_discharge
    ADD CONSTRAINT admin_unique_form_id UNIQUE (form_id);


ALTER TABLE ONLY public.detox_forms
    ADD CONSTRAINT detox_unique_form_id UNIQUE (form_id);


ALTER TABLE ONLY public.error_log
    ADD CONSTRAINT error_log_pkey PRIMARY KEY (error_log_id);


ALTER TABLE ONLY public.program_history
    ADD CONSTRAINT program_history_pkey PRIMARY KEY (program_history_pk);


ALTER TABLE ONLY public.stg_admin_discharge
    ADD CONSTRAINT stg_admin_unique_form_id UNIQUE (form_id);


ALTER TABLE ONLY public.stg_ama_forms
    ADD CONSTRAINT stg_ama_forms_form_id_key UNIQUE (form_id);


ALTER TABLE ONLY public.stg_detox_forms
    ADD CONSTRAINT stg_detox_unique_form_id UNIQUE (form_id);


ALTER TABLE ONLY public.stg_latest
    ADD CONSTRAINT stg_unique_casefile_id UNIQUE (casefile_id);


ALTER TABLE ONLY public.latest
    ADD CONSTRAINT unique_casefile_id UNIQUE (casefile_id);


ALTER TABLE ONLY public.ama_forms
    ADD CONSTRAINT unique_form_id UNIQUE (form_id);



-- Materialized Views
CREATE MATERIALIZED VIEW public.vw_program_history AS
 WITH ph AS (
         SELECT ph.casefile_id,
            ph.first_name,
            ph.last_name,
            rpt.program_category,
            rpt.program_class,
            rpt.program_level,
                CASE
                    WHEN (rpt.program_class = 'Discharge'::text) THEN max(ph.start_date)
                    ELSE min(ph.start_date)
                END AS start_date,
                CASE
                    WHEN (rpt.program_class = 'Discharge'::text) THEN max(ph.logged_at)
                    ELSE min(ph.logged_at)
                END AS logged_date,
            l.discharge_date
           FROM ((public.program_history ph
             JOIN public.ref_program_types rpt ON ((ph.program_name = rpt.program)))
             JOIN public.latest l ON ((ph.casefile_id = l.casefile_id)))
          WHERE (rpt.program_level <> 'Administrative'::text)
          GROUP BY ph.casefile_id, ph.first_name, ph.last_name, rpt.program_category, l.discharge_date, rpt.program_class, rpt.program_level
          ORDER BY ph.casefile_id,
                CASE
                    WHEN (rpt.program_class = 'Discharge'::text) THEN max(ph.start_date)
                    ELSE min(ph.start_date)
                END
        ), cleaned AS (
         SELECT ph.casefile_id,
            ph.first_name,
            ph.last_name,
            ph.program_category,
            ph.program_class,
            ph.program_level,
            ph.start_date,
            ph.logged_date,
            ph.discharge_date
           FROM ph
          WHERE ((ph.program_class = 'Program'::text) OR ((ph.program_class = 'Discharge'::text) AND (EXISTS ( SELECT 1
                   FROM ph ph2
                  WHERE ((ph.casefile_id = ph2.casefile_id) AND (ph.program_level = ph2.program_level) AND (ph2.program_class = 'Program'::text) AND (ph2.start_date < ph.start_date))))))
        ), remove_interim_discharges AS (
         SELECT c.casefile_id,
            c.first_name,
            c.last_name,
            c.program_category,
            c.program_class,
            c.program_level,
            c.start_date,
            c.logged_date,
            c.discharge_date
           FROM cleaned c
          WHERE (NOT ((c.program_class = 'Discharge'::text) AND (EXISTS ( SELECT 1
                   FROM cleaned c2
                  WHERE ((c.casefile_id = c2.casefile_id) AND (c2.program_class = 'Program'::text) AND ((c2.start_date >= c.start_date) AND (c2.start_date <= (c.start_date + '24:00:00'::interval))))))))
        ), transformed AS (
         SELECT remove_interim_discharges.casefile_id,
            remove_interim_discharges.first_name,
            remove_interim_discharges.last_name,
            remove_interim_discharges.program_category,
            remove_interim_discharges.program_class,
            remove_interim_discharges.program_level,
            remove_interim_discharges.start_date,
            lead(remove_interim_discharges.start_date) OVER (PARTITION BY remove_interim_discharges.casefile_id ORDER BY remove_interim_discharges.start_date, remove_interim_discharges.logged_date) AS end_date,
            remove_interim_discharges.discharge_date,
            remove_interim_discharges.logged_date,
            row_number() OVER (PARTITION BY remove_interim_discharges.casefile_id ORDER BY remove_interim_discharges.start_date, remove_interim_discharges.logged_date) AS ph_version
           FROM remove_interim_discharges
          ORDER BY remove_interim_discharges.casefile_id, remove_interim_discharges.start_date
        ), version_count AS (
         SELECT transformed.casefile_id,
            max(transformed.ph_version) AS total_versions
           FROM transformed
          GROUP BY transformed.casefile_id
        ), final_view AS (
         SELECT t.casefile_id,
            t.first_name,
            t.last_name,
            t.program_level,
            t.program_category,
            t.program_class,
            t.start_date,
                CASE
                    WHEN (t.discharge_date < t.end_date) THEN t.discharge_date
                    WHEN ((t.end_date IS NULL) AND (t.program_class = 'Discharge'::text)) THEN COALESCE(LEAST(t.discharge_date, t.start_date), t.discharge_date, t.start_date)
                    WHEN ((t.end_date IS NULL) AND (t.program_class = 'Program'::text) AND (t.discharge_date IS NOT NULL)) THEN t.discharge_date
                    WHEN ((t.end_date IS NULL) AND (t.program_class = 'Program'::text) AND (t.discharge_date IS NULL)) THEN date_trunc('second'::text, now() AT TIME ZONE 'America/Phoenix')
                    ELSE t.end_date
                END AS end_date,
            t.discharge_date,
            t.ph_version,
            v.total_versions,
                CASE
                    WHEN ((t.end_date IS NULL) AND (t.program_class = 'Program'::text) AND (t.discharge_date IS NULL) AND (t.start_date < now())) THEN 1
                    ELSE 0
                END AS is_active
           FROM (transformed t
             JOIN version_count v ON ((t.casefile_id = v.casefile_id)))
        ), rpt_ph AS (
         SELECT final_view.casefile_id,
            final_view.first_name,
            final_view.last_name,
            final_view.program_level,
            final_view.program_category,
            final_view.program_class,
            final_view.start_date,
            final_view.end_date,
            final_view.discharge_date,
            final_view.ph_version,
            final_view.total_versions,
            final_view.is_active,
            (final_view.start_date)::date AS start_day,
            (final_view.end_date)::date AS end_day,
            (final_view.discharge_date)::date AS discharge_day,
                CASE
                    WHEN ((final_view.start_date < final_view.end_date) AND (final_view.program_class = 'Program'::text)) THEN 1
                    ELSE 0
                END AS admission,
                CASE
                    WHEN ((final_view.start_date < final_view.end_date) AND (final_view.program_class = 'Program'::text)) THEN ((final_view.end_date)::date - (final_view.start_date)::date)
                    ELSE 0
                END AS days_in_program,
                CASE
                    WHEN ((final_view.start_date < final_view.end_date) AND (final_view.program_class = 'Program'::text)) THEN round((EXTRACT(epoch FROM (final_view.end_date - final_view.start_date)) / (3600)::numeric))
                    ELSE (0)::numeric
                END AS hours_in_program,
                CASE
                    WHEN ((lead(final_view.program_class) OVER (PARTITION BY final_view.casefile_id ORDER BY final_view.ph_version) = 'Program'::text) AND (final_view.start_date < final_view.end_date) AND ((final_view.end_date <> final_view.discharge_date) OR (final_view.discharge_date IS NULL)) AND (final_view.program_class = 'Program'::text)) THEN 1
                    ELSE 0
                END AS transferred_out,
                CASE
                    WHEN ((lag(final_view.program_class) OVER (PARTITION BY final_view.casefile_id ORDER BY final_view.ph_version) = 'Program'::text) AND (final_view.start_date < final_view.end_date) AND (final_view.program_class = 'Program'::text)) THEN 1
                    ELSE 0
                END AS transferred_in,
                CASE
                    WHEN ((lead(final_view.program_class) OVER (PARTITION BY final_view.casefile_id ORDER BY final_view.ph_version) = 'Discharge'::text) AND (final_view.start_date < final_view.end_date) AND (final_view.program_class = 'Program'::text)) THEN 1
                    WHEN ((final_view.end_date = final_view.discharge_date) AND (final_view.start_date < final_view.end_date) AND (final_view.program_class = 'Program'::text)) THEN 1
                    ELSE 0
                END AS discharged
           FROM final_view
        )
 SELECT casefile_id,
    first_name,
    last_name,
    program_level,
    program_category,
    program_class,
    start_date,
    end_date,
    discharge_date,
    ph_version,
    total_versions,
    is_active,
    start_day,
    end_day,
    discharge_day,
    admission,
    days_in_program,
    hours_in_program,
    transferred_out,
    transferred_in,
    discharged
   FROM rpt_ph
  WITH NO DATA;


CREATE MATERIALIZED VIEW public.vw_daily_census AS
 WITH calendar AS (
         SELECT (generate_series(('2024-01-01'::date) AT TIME ZONE 'America/Phoenix', (CURRENT_DATE) AT TIME ZONE 'America/Phoenix', '1 day'::interval))::date AS census_date
        ), filtered_programs AS (
         SELECT vw_program_history.casefile_id,
            vw_program_history.program_category,
            (vw_program_history.start_date)::date AS start_date,
            (vw_program_history.end_date)::date AS end_date
           FROM public.vw_program_history
          WHERE (vw_program_history.program_class = 'Program'::text)
        ), daily_census AS (
         SELECT cal.census_date,
            fp.program_category,
            count(DISTINCT fp.casefile_id) AS census_count
           FROM (calendar cal
             JOIN filtered_programs fp ON (((cal.census_date >= fp.start_date) AND (cal.census_date < fp.end_date))))
          GROUP BY cal.census_date, fp.program_category
        ),

		admission_or_xfer_in AS(
			SELECT start_day, program_category, SUM(admission)-SUM(transferred_in) as admissions
			,SUM(transferred_in) as transfer_in
			FROM vw_program_history
			GROUP BY 1,2
		),

		transfer_out_or_discharge AS(
			SELECT end_day, program_category
			,SUM(transferred_out) as transfer_out 
			,SUM(discharged) as discharges
			FROM vw_program_history
			GROUP BY 1,2
		)
		
 SELECT dc.census_date,
    dc.program_category,
    COALESCE(census_count,0) as census
	,COALESCE(admissions,0) as admissions
	,COALESCE(transfer_in,0) as transfer_in
	,COALESCE(transfer_out,0) as transfer_out
	,COALESCE(discharges,0) as discharges
   FROM daily_census dc
   LEFT JOIN admission_or_xfer_in a
   	ON dc.census_date = a.start_day AND dc.program_category = a.program_category
   LEFT JOIN transfer_out_or_discharge t
   	ON dc.census_date = t.end_day AND dc.program_category = t.program_category
  ORDER BY dc.census_date, dc.program_category
  WITH NO DATA;


CREATE MATERIALIZED VIEW public.vw_discharges AS
 WITH discharges AS (
         SELECT ph.casefile_id,
            ph.program_level,
            ph.program_category,
            ph.program_class,
            date_trunc('day'::text, ph.end_date) AS end_date,
            l.discharge_type_code,
            rdt.discharge_class,
            concat(ph.first_name, ' ', ph.last_name) AS full_name
           FROM ((public.vw_program_history ph
             LEFT JOIN public.latest l ON ((ph.casefile_id = l.casefile_id)))
             LEFT JOIN public.ref_discharge_types rdt ON ((rdt.discharge_type_code = l.discharge_type_code)))
          WHERE (ph.discharged = 1)
        )
 SELECT d.casefile_id,
    d.full_name,
    d.program_level,
    d.program_category,
    d.program_class,
    (d.end_date)::date AS discharge_date,
        CASE
            WHEN (ama.casefile_id IS NOT NULL) THEN 'AMA'::text
            WHEN (ad.casefile_id IS NOT NULL) THEN 'Admin'::text
            WHEN (d.discharge_class IS NULL) THEN 'Successful'::text
            ELSE d.discharge_class
        END AS discharge_class
   FROM ((discharges d
     LEFT JOIN ( SELECT DISTINCT ama_forms.casefile_id
           FROM public.ama_forms) ama ON ((d.casefile_id = ama.casefile_id)))
     LEFT JOIN ( SELECT DISTINCT admin_discharge.casefile_id
           FROM public.admin_discharge) ad ON ((d.casefile_id = ad.casefile_id)))
  WITH NO DATA;


-- Procedures

CREATE PROCEDURE public.upsert_admin_discharge_data()
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec stg_admin_discharge%ROWTYPE;
BEGIN
    FOR rec IN SELECT * FROM stg_admin_discharge LOOP
        BEGIN
            INSERT INTO admin_discharge (
                form_id, name, status,casefile_id,evaluation_id,patient_process_id, created_at, 
                created_by,updated_at,updated_by,evaluation_content,patient_id,patient_master_id
            )
            VALUES (
                rec.form_id,rec.name,rec.status,rec.casefile_id,rec.evaluation_id,rec.patient_process_id, 
                rec.created_at, rec.created_by,rec.updated_at,rec.updated_by,rec.evaluation_content, 
                rec.patient_id,rec.patient_master_id
            )
            ON CONFLICT (form_id)
            DO UPDATE SET
                name               = EXCLUDED.name,
                status             = EXCLUDED.status,
                casefile_id        = EXCLUDED.casefile_id,
                evaluation_id      = EXCLUDED.evaluation_id,
                patient_process_id = EXCLUDED.patient_process_id,
                created_at         = EXCLUDED.created_at,
                created_by         = EXCLUDED.created_by,
                updated_at         = EXCLUDED.updated_at,
                updated_by         = EXCLUDED.updated_by,
                evaluation_content = EXCLUDED.evaluation_content,
                patient_id         = EXCLUDED.patient_id,
                patient_master_id  = EXCLUDED.patient_master_id;
        EXCEPTION
            WHEN OTHERS THEN
                -- Log the error for this row along with the form_id
                INSERT INTO error_log (casefile_id, error_message, error_time, procedure_name)
                VALUES (rec.form_id, SQLERRM, NOW(), 'upsert_admin_discharge_data');
        END;
    END LOOP;
END;
$$;


CREATE PROCEDURE public.upsert_ama_forms_data()
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec stg_ama_forms%ROWTYPE;
BEGIN
    FOR rec IN SELECT * FROM stg_ama_forms LOOP
        BEGIN
            INSERT INTO ama_forms (
                form_id, name, status,casefile_id,evaluation_id,patient_process_id, created_at, 
                created_by,updated_at,updated_by,evaluation_content,patient_id,patient_master_id
            )
            VALUES (
                rec.form_id,rec.name,rec.status,rec.casefile_id,rec.evaluation_id,rec.patient_process_id, 
                rec.created_at, rec.created_by,rec.updated_at,rec.updated_by,rec.evaluation_content, 
                rec.patient_id,rec.patient_master_id
            )
            ON CONFLICT (form_id)
            DO UPDATE SET
                name               = EXCLUDED.name,
                status             = EXCLUDED.status,
                casefile_id        = EXCLUDED.casefile_id,
                evaluation_id      = EXCLUDED.evaluation_id,
                patient_process_id = EXCLUDED.patient_process_id,
                created_at         = EXCLUDED.created_at,
                created_by         = EXCLUDED.created_by,
                updated_at         = EXCLUDED.updated_at,
                updated_by         = EXCLUDED.updated_by,
                evaluation_content = EXCLUDED.evaluation_content,
                patient_id         = EXCLUDED.patient_id,
                patient_master_id  = EXCLUDED.patient_master_id;
        EXCEPTION
            WHEN OTHERS THEN
                -- Log the error for this row along with the form_id
                INSERT INTO error_log (casefile_id, error_message, error_time, procedure_name)
                VALUES (rec.form_id, SQLERRM, NOW(), 'upsert_ama_forms_data');
        END;
    END LOOP;
END;
$$;


CREATE PROCEDURE public.upsert_detox_discharge_forms_data()
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec stg_detox_forms%ROWTYPE;
BEGIN
    FOR rec IN SELECT * FROM stg_detox_forms LOOP
        BEGIN
            INSERT INTO detox_forms (
                form_id, name, status,casefile_id,evaluation_id,patient_process_id, created_at, 
                created_by,updated_at,updated_by,evaluation_content,patient_id,patient_master_id, step_down_value, transferred
            )
            VALUES (
                rec.form_id,rec.name,rec.status,rec.casefile_id,rec.evaluation_id,rec.patient_process_id, 
                rec.created_at, rec.created_by,rec.updated_at,rec.updated_by,rec.evaluation_content, 
                rec.patient_id,rec.patient_master_id, rec.step_down_value, rec.transferred
            )
            ON CONFLICT (form_id)
            DO UPDATE SET
                name               = EXCLUDED.name,
                status             = EXCLUDED.status,
                casefile_id        = EXCLUDED.casefile_id,
                evaluation_id      = EXCLUDED.evaluation_id,
                patient_process_id = EXCLUDED.patient_process_id,
                created_at         = EXCLUDED.created_at,
                created_by         = EXCLUDED.created_by,
                updated_at         = EXCLUDED.updated_at,
                updated_by         = EXCLUDED.updated_by,
                evaluation_content = EXCLUDED.evaluation_content,
                patient_id         = EXCLUDED.patient_id,
                patient_master_id  = EXCLUDED.patient_master_id,
                step_down_value    = EXCLUDED.step_down_value,
                transferred        = EXCLUDED.transferred;
        EXCEPTION
            WHEN OTHERS THEN
                -- Log the error for this row along with the form_id
                INSERT INTO error_log (casefile_id, error_message, error_time, procedure_name)
                VALUES (rec.form_id, SQLERRM, NOW(), 'upsert_detox_discharge_forms_data');
        END;
    END LOOP;
END;
$$;


CREATE PROCEDURE public.upsert_latest_data()
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec stg_latest%ROWTYPE;
BEGIN
    FOR rec IN SELECT * FROM stg_latest LOOP
        BEGIN
            INSERT INTO latest (
                casefile_id, patient_id, patient_master_id, first_name, last_name, gender, 
                admission_date, discharge_date, anticipated_discharge_date, discharge_type, 
                discharge_type_code, referrer_name, mr_number, payment_method, 
                payment_method_category, created_at, last_updated_at, insurance_company, 
                level_of_care, program, location_id, location_name, record_source
            )
            VALUES (
                rec.casefile_id, rec.patient_id, rec.patient_master_id, rec.first_name, rec.last_name, rec.gender, 
                rec.admission_date, rec.discharge_date, rec.anticipated_discharge_date, rec.discharge_type, 
                rec.discharge_type_code, rec.referrer_name, rec.mr_number, rec.payment_method, 
                rec.payment_method_category, rec.created_at, rec.last_updated_at, rec.insurance_company, 
                rec.level_of_care, rec.program, rec.location_id, rec.location_name, rec.record_source
            )
            ON CONFLICT (casefile_id)
            DO UPDATE SET
                patient_id = EXCLUDED.patient_id,
                patient_master_id = EXCLUDED.patient_master_id,
                first_name = EXCLUDED.first_name,
                last_name = EXCLUDED.last_name,
                gender = EXCLUDED.gender,
                admission_date = EXCLUDED.admission_date,
                discharge_date = EXCLUDED.discharge_date,
                anticipated_discharge_date = EXCLUDED.anticipated_discharge_date,
                discharge_type = EXCLUDED.discharge_type,
                discharge_type_code = EXCLUDED.discharge_type_code,
                referrer_name = EXCLUDED.referrer_name,
                mr_number = EXCLUDED.mr_number,
                payment_method = EXCLUDED.payment_method,
                payment_method_category = EXCLUDED.payment_method_category,
                created_at = EXCLUDED.created_at,
                last_updated_at = EXCLUDED.last_updated_at,
                insurance_company = EXCLUDED.insurance_company,
                level_of_care = EXCLUDED.level_of_care,
                program = EXCLUDED.program,
                location_id = EXCLUDED.location_id,
                location_name = EXCLUDED.location_name,
                record_source = EXCLUDED.record_source;
        EXCEPTION
            WHEN OTHERS THEN
                INSERT INTO error_log (casefile_id, error_message, error_time, procedure_name)
                VALUES (rec.casefile_id, SQLERRM, NOW(), 'upsert_latest_data');
        END;
    END LOOP;
END;
$$;

-- DB Helper Functions

CREATE OR REPLACE FUNCTION fetch_diff_records()
RETURNS TABLE(casefile_id TEXT, patient_id TEXT, patient_master_id TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT s.casefile_id, s.patient_id, s.patient_master_id
  FROM stg_latest s
  LEFT JOIN latest l ON s.casefile_id = l.casefile_id
  WHERE l.casefile_id IS NULL OR s.program <> l.program;
END;
$$ LANGUAGE plpgsql STABLE;


CREATE OR REPLACE FUNCTION truncate_table_dynamic(p_table_name text)
RETURNS void AS $$
BEGIN
  EXECUTE 'TRUNCATE TABLE ' || quote_ident(p_table_name);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_max_last_updated()
RETURNS text AS $$
    SELECT to_char(max(last_updated_at), 'YYYY-MM-DD') FROM latest;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION form_get_max_last_updated(p_table_name text)
RETURNS text AS $$
DECLARE
    result text;
BEGIN
    EXECUTE format(
        'SELECT to_char(max(updated_at), ''YYYY-MM-DD'') FROM %I',
        p_table_name
    )
    INTO result;
    RETURN result;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION refresh_materialized_view(view_name text)
RETURNS void 
SECURITY DEFINER
AS $$
BEGIN
    EXECUTE 'REFRESH MATERIALIZED VIEW ' || quote_ident(view_name);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION call_proc(p_proc_name text)
RETURNS void AS $$
BEGIN
  EXECUTE format('CALL public.%I()', p_proc_name);
END;
$$ LANGUAGE plpgsql;


-- Change default statement timeouts
alter role anon set statement_timeout = '20s'; 
alter role authenticated set statement_timeout = '60s'; 
alter role service_role set statement_timeout = '2min'; 
NOTIFY pgrst, 'reload config'; -- Must run for Client API calls to observe changes