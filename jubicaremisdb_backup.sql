--
-- PostgreSQL database dump
--

\restrict rCiHejZ99aMwKgPtTFEu6TNJ7KcvrK4GhKndXbXiJEULG2gTXqXrInY1F3iUh5W

-- Dumped from database version 18.4
-- Dumped by pg_dump version 18.4

-- Started on 2026-08-12 12:00:00

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 30248)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 5947 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS '';


--
-- TOC entry 1020 (class 1247 OID 30258)
-- Name: appointment_status_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.appointment_status_t AS ENUM (
    'registered',
    'with_doctor',
    'with_lab',
    'with_pharma',
    'completed',
    'denied',
    'lama',
    'with_counsellor'
);


ALTER TYPE public.appointment_status_t OWNER TO postgres;

--
-- TOC entry 1041 (class 1247 OID 30338)
-- Name: attachment_kind_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.attachment_kind_t AS ENUM (
    'Prescription',
    'Report',
    'Other'
);


ALTER TYPE public.attachment_kind_t OWNER TO postgres;

--
-- TOC entry 1044 (class 1247 OID 30346)
-- Name: attendance_status_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.attendance_status_t AS ENUM (
    'Present',
    'Absent',
    'Leave',
    'Holiday'
);


ALTER TYPE public.attendance_status_t OWNER TO postgres;

--
-- TOC entry 1047 (class 1247 OID 30356)
-- Name: camp_type_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.camp_type_t AS ENUM (
    'Community',
    'School',
    'Workplace',
    'Health Awareness'
);


ALTER TYPE public.camp_type_t OWNER TO postgres;

--
-- TOC entry 1053 (class 1247 OID 30378)
-- Name: delivery_status_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.delivery_status_t AS ENUM (
    'accept',
    'denied',
    'NA'
);


ALTER TYPE public.delivery_status_t OWNER TO postgres;

--
-- TOC entry 1038 (class 1247 OID 30328)
-- Name: device_state_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.device_state_t AS ENUM (
    'Working',
    'Not Working',
    'Not Applicable',
    'Purchase Requested'
);


ALTER TYPE public.device_state_t OWNER TO postgres;

--
-- TOC entry 1059 (class 1247 OID 30398)
-- Name: entity_status_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.entity_status_t AS ENUM (
    'active',
    'inactive',
    'suspended'
);


ALTER TYPE public.entity_status_t OWNER TO postgres;

--
-- TOC entry 1026 (class 1247 OID 30290)
-- Name: facility_type_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.facility_type_t AS ENUM (
    'mmu',
    'static_clinic',
    'standalone_clinic'
);


ALTER TYPE public.facility_type_t OWNER TO postgres;

--
-- TOC entry 1032 (class 1247 OID 30304)
-- Name: frequency_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.frequency_t AS ENUM (
    'OD',
    'BD',
    'TDS',
    'QID',
    'SOS',
    'HS'
);


ALTER TYPE public.frequency_t OWNER TO postgres;

--
-- TOC entry 1017 (class 1247 OID 30250)
-- Name: gender_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.gender_t AS ENUM (
    'Male',
    'Female',
    'Other'
);


ALTER TYPE public.gender_t OWNER TO postgres;

--
-- TOC entry 1056 (class 1247 OID 30386)
-- Name: lab_category_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.lab_category_t AS ENUM (
    'Blood',
    'Urine',
    'Imaging',
    'ECG',
    'Other'
);


ALTER TYPE public.lab_category_t OWNER TO postgres;

--
-- TOC entry 1035 (class 1247 OID 30318)
-- Name: marital_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.marital_t AS ENUM (
    'Single',
    'Married',
    'Widowed',
    'Divorced'
);


ALTER TYPE public.marital_t OWNER TO postgres;

--
-- TOC entry 1029 (class 1247 OID 30298)
-- Name: payment_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.payment_t AS ENUM (
    'Free',
    'Paid'
);


ALTER TYPE public.payment_t OWNER TO postgres;

--
-- TOC entry 1050 (class 1247 OID 30366)
-- Name: requisition_status_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.requisition_status_t AS ENUM (
    'Requested',
    'Pending',
    'Partial',
    'Received',
    'Delivered',
    'Approved',
    'Rejected'
);


ALTER TYPE public.requisition_status_t OWNER TO postgres;

--
-- TOC entry 1023 (class 1247 OID 30274)
-- Name: role_t; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.role_t AS ENUM (
    'super_admin',
    'org_admin',
    'counsellor',
    'driver',
    'doctor',
    'pharmacist',
    'lab',
    'cmo',
    'zonal_incharge'
);


ALTER TYPE public.role_t OWNER TO postgres;

--
-- TOC entry 327 (class 1255 OID 31663)
-- Name: restore_deleted(text, bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.restore_deleted(p_table text, p_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE pk_col text;
BEGIN
    SELECT a.attname INTO pk_col
    FROM   pg_index i
    JOIN   pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
    WHERE  i.indrelid = p_table::regclass AND i.indisprimary;

    EXECUTE format(
        'UPDATE %I SET deleted_at = NULL, deleted_by = NULL, delete_reason = NULL
          WHERE %I = $1', p_table, pk_col)
    USING p_id;
END;
$_$;


ALTER FUNCTION public.restore_deleted(p_table text, p_id bigint) OWNER TO postgres;

--
-- TOC entry 314 (class 1255 OID 31487)
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_updated_at() OWNER TO postgres;

--
-- TOC entry 326 (class 1255 OID 31662)
-- Name: soft_delete(text, bigint, bigint, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.soft_delete(p_table text, p_id bigint, p_user bigint, p_reason text) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
    pk_col text;
    n      integer;
BEGIN
    IF p_reason IS NULL OR p_reason = '' THEN
        RAISE EXCEPTION 'a delete reason is required';
    END IF;

    -- Composite-PK tables (appointment_symptom, appointment_diagnosis) can't be
    -- addressed by a single id — reject them rather than deleting the wrong row.
    SELECT a.attname, count(*) OVER () INTO pk_col, n
    FROM   pg_index i
    JOIN   pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
    WHERE  i.indrelid = p_table::regclass AND i.indisprimary;

    IF pk_col IS NULL THEN
        RAISE EXCEPTION 'table % has no primary key', p_table;
    ELSIF n > 1 THEN
        RAISE EXCEPTION
            'table % has a composite primary key — soft-delete it with a direct UPDATE', p_table;
    END IF;

    EXECUTE format(
        'UPDATE %I SET deleted_at = now(), deleted_by = $1, delete_reason = $2
          WHERE %I = $3 AND deleted_at IS NULL', p_table, pk_col)
    USING p_user, p_reason, p_id;

    GET DIAGNOSTICS n = ROW_COUNT;
    IF n = 0 THEN
        RAISE EXCEPTION 'no live row % in %', p_id, p_table;
    END IF;
END;
$_$;


ALTER FUNCTION public.soft_delete(p_table text, p_id bigint, p_user bigint, p_reason text) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 245 (class 1259 OID 30735)
-- Name: app_user; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.app_user (
    user_id bigint NOT NULL,
    username text NOT NULL,
    password_hash text NOT NULL,
    full_name text NOT NULL,
    role public.role_t NOT NULL,
    org_id bigint,
    facility_id bigint,
    staff_id bigint,
    is_active boolean DEFAULT true NOT NULL,
    last_login_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    legacy_id text,
    legacy_source text,
    token_version integer DEFAULT 0 NOT NULL,
    CONSTRAINT app_user_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text)))),
    CONSTRAINT user_org_chk CHECK (((role = 'super_admin'::public.role_t) OR (org_id IS NOT NULL)))
);


ALTER TABLE public.app_user OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 30734)
-- Name: app_user_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.app_user ALTER COLUMN user_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.app_user_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 265 (class 1259 OID 30969)
-- Name: appointment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointment (
    appointment_id bigint NOT NULL,
    patient_id bigint NOT NULL,
    facility_id bigint NOT NULL,
    org_id bigint,
    source public.facility_type_t NOT NULL,
    appointment_date date DEFAULT CURRENT_DATE NOT NULL,
    month character(7) GENERATED ALWAYS AS (((lpad((EXTRACT(year FROM appointment_date))::text, 4, '0'::text) || '-'::text) || lpad((EXTRACT(month FROM appointment_date))::text, 2, '0'::text))) STORED,
    status public.appointment_status_t DEFAULT 'registered'::public.appointment_status_t NOT NULL,
    registered_by bigint,
    attended_by bigint,
    lab_by bigint,
    dispensed_by bigint,
    assigned_doctor_id bigint,
    taken_prescribed_medicine boolean DEFAULT false NOT NULL,
    pregnant boolean DEFAULT false NOT NULL,
    lmp_date date,
    edd_date date,
    counsellor_remarks text DEFAULT ''::text NOT NULL,
    height numeric(5,2),
    weight numeric(5,2),
    systolic_bp smallint,
    diastolic_bp smallint,
    blood_sugar smallint,
    body_temp numeric(4,1),
    oxygen numeric(4,1),
    hemoglobin numeric(4,1),
    bp_category text GENERATED ALWAYS AS (
CASE
    WHEN ((systolic_bp IS NULL) OR (diastolic_bp IS NULL)) THEN NULL::text
    WHEN ((systolic_bp < 120) AND (diastolic_bp < 80)) THEN 'Normal'::text
    WHEN ((systolic_bp < 140) AND (diastolic_bp < 90)) THEN 'Pre-hypertension'::text
    WHEN ((systolic_bp < 160) AND (diastolic_bp < 100)) THEN 'Stage 1'::text
    ELSE 'Stage 2'::text
END) STORED,
    observation text DEFAULT ''::text NOT NULL,
    doctor_remarks text DEFAULT ''::text NOT NULL,
    follow_up_date date,
    follow_up_done boolean DEFAULT false NOT NULL,
    referred boolean DEFAULT false NOT NULL,
    referral_destination_id bigint,
    counselled boolean DEFAULT false NOT NULL,
    counselling_topic_id bigint,
    lab_report_date date,
    payment_type public.payment_t DEFAULT 'Free'::public.payment_t NOT NULL,
    paid_amount numeric(10,2) DEFAULT 0 NOT NULL,
    delivery_status public.delivery_status_t DEFAULT 'NA'::public.delivery_status_t NOT NULL,
    denial_reason text,
    lama_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    legacy_id text,
    legacy_source text,
    fee_collected_at timestamp with time zone,
    fee_collected_by bigint,
    test_payment_total numeric(10,2) DEFAULT 0 NOT NULL,
    test_paid_at timestamp with time zone,
    test_paid_by bigint,
    parent_appointment_id bigint,
    CONSTRAINT appointment_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text)))),
    CONSTRAINT appt_amount_chk CHECK ((paid_amount >= (0)::numeric)),
    CONSTRAINT appt_bp_order CHECK (((systolic_bp IS NULL) OR (diastolic_bp IS NULL) OR (systolic_bp > diastolic_bp))),
    CONSTRAINT appt_counsel_chk CHECK ((counselled = (counselling_topic_id IS NOT NULL))),
    CONSTRAINT appt_denial_chk CHECK ((((status = 'denied'::public.appointment_status_t) AND (denial_reason IS NOT NULL) AND (denial_reason <> ''::text)) OR ((status <> 'denied'::public.appointment_status_t) AND (denial_reason IS NULL)))),
    CONSTRAINT appt_dia_chk CHECK (((diastolic_bp IS NULL) OR ((diastolic_bp >= 20) AND (diastolic_bp <= 200)))),
    CONSTRAINT appt_edd_chk CHECK (((lmp_date IS NULL) OR (edd_date IS NULL) OR (edd_date > lmp_date))),
    CONSTRAINT appt_followup_chk CHECK (((follow_up_date IS NULL) OR (follow_up_date >= appointment_date))),
    CONSTRAINT appt_hb_chk CHECK (((hemoglobin IS NULL) OR ((hemoglobin >= (1)::numeric) AND (hemoglobin <= (30)::numeric)))),
    CONSTRAINT appt_height_chk CHECK (((height IS NULL) OR ((height >= (30)::numeric) AND (height <= (250)::numeric)))),
    CONSTRAINT appt_lama_chk CHECK (((status = 'lama'::public.appointment_status_t) = (lama_at IS NOT NULL))),
    CONSTRAINT appt_oxygen_chk CHECK (((oxygen IS NULL) OR ((oxygen >= (50)::numeric) AND (oxygen <= (100)::numeric)))),
    CONSTRAINT appt_paid_chk CHECK (((payment_type <> 'Paid'::public.payment_t) OR (paid_amount > (0)::numeric))),
    CONSTRAINT appt_referral_chk CHECK ((referred = (referral_destination_id IS NOT NULL))),
    CONSTRAINT appt_sugar_chk CHECK (((blood_sugar IS NULL) OR ((blood_sugar >= 20) AND (blood_sugar <= 999)))),
    CONSTRAINT appt_sys_chk CHECK (((systolic_bp IS NULL) OR ((systolic_bp >= 40) AND (systolic_bp <= 300)))),
    CONSTRAINT appt_temp_chk CHECK (((body_temp IS NULL) OR ((body_temp >= (80)::numeric) AND (body_temp <= (115)::numeric)))),
    CONSTRAINT appt_weight_chk CHECK (((weight IS NULL) OR ((weight >= (1)::numeric) AND (weight <= (400)::numeric))))
);


ALTER TABLE public.appointment OWNER TO postgres;

--
-- TOC entry 264 (class 1259 OID 30968)
-- Name: appointment_appointment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.appointment ALTER COLUMN appointment_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.appointment_appointment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 273 (class 1259 OID 31192)
-- Name: appointment_attachment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointment_attachment (
    attachment_id bigint NOT NULL,
    appointment_id bigint NOT NULL,
    file_path text NOT NULL,
    file_url text,
    kind public.attachment_kind_t DEFAULT 'Other'::public.attachment_kind_t NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    legacy_id text,
    legacy_source text,
    CONSTRAINT appointment_attachment_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.appointment_attachment OWNER TO postgres;

--
-- TOC entry 272 (class 1259 OID 31191)
-- Name: appointment_attachment_attachment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.appointment_attachment ALTER COLUMN attachment_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.appointment_attachment_attachment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 267 (class 1259 OID 31103)
-- Name: appointment_diagnosis; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointment_diagnosis (
    appointment_id bigint NOT NULL,
    disease_id bigint,
    diagnosis_text text NOT NULL,
    icd11_code text,
    is_primary boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    CONSTRAINT appointment_diagnosis_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.appointment_diagnosis OWNER TO postgres;

--
-- TOC entry 269 (class 1259 OID 31126)
-- Name: appointment_lab_test; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointment_lab_test (
    appointment_lab_id bigint NOT NULL,
    appointment_id bigint NOT NULL,
    lab_test_id bigint,
    test_name text NOT NULL,
    sample_done boolean,
    sample_reason text,
    assigned_handover_date date,
    handover_date date,
    handover_delay_reason text,
    result text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    legacy_id text,
    legacy_source text,
    price numeric(10,2) DEFAULT 0 NOT NULL,
    paid boolean DEFAULT false NOT NULL,
    paid_at timestamp with time zone,
    paid_by bigint,
    CONSTRAINT alt_paid_chk CHECK (((paid = false) OR (paid_at IS NOT NULL))),
    CONSTRAINT appointment_lab_test_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text)))),
    CONSTRAINT lab_handover_chk CHECK (((handover_date IS NULL) OR (assigned_handover_date IS NULL) OR (handover_date >= assigned_handover_date) OR ((handover_delay_reason IS NOT NULL) AND (handover_delay_reason <> ''::text)))),
    CONSTRAINT lab_skip_reason_chk CHECK (((sample_done IS NOT FALSE) OR ((sample_reason IS NOT NULL) AND (sample_reason <> ''::text))))
);


ALTER TABLE public.appointment_lab_test OWNER TO postgres;

--
-- TOC entry 268 (class 1259 OID 31125)
-- Name: appointment_lab_test_appointment_lab_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.appointment_lab_test ALTER COLUMN appointment_lab_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.appointment_lab_test_appointment_lab_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 266 (class 1259 OID 31086)
-- Name: appointment_symptom; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointment_symptom (
    appointment_id bigint NOT NULL,
    symptom_id bigint NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    CONSTRAINT appointment_symptom_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.appointment_symptom OWNER TO postgres;

--
-- TOC entry 279 (class 1259 OID 31275)
-- Name: attendance; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.attendance (
    attendance_id bigint NOT NULL,
    user_id bigint NOT NULL,
    facility_id bigint,
    role public.role_t NOT NULL,
    attendance_date date NOT NULL,
    check_in time without time zone,
    check_out time without time zone,
    location text,
    status public.attendance_status_t DEFAULT 'Present'::public.attendance_status_t NOT NULL,
    start_km numeric(10,1),
    end_km numeric(10,1),
    total_run numeric(10,1),
    collection numeric(10,2),
    notes text DEFAULT ''::text NOT NULL,
    photo_path text,
    latitude double precision,
    longitude double precision,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    legacy_id text,
    legacy_source text,
    camp_anchor_id bigint,
    CONSTRAINT att_km_chk CHECK (((end_km IS NULL) OR (start_km IS NULL) OR (end_km >= start_km))),
    CONSTRAINT att_lat_chk CHECK (((latitude IS NULL) OR ((latitude >= ('-90'::integer)::double precision) AND (latitude <= (90)::double precision)))),
    CONSTRAINT att_lng_chk CHECK (((longitude IS NULL) OR ((longitude >= ('-180'::integer)::double precision) AND (longitude <= (180)::double precision)))),
    CONSTRAINT att_out_chk CHECK (((check_out IS NULL) OR (check_in IS NULL) OR (check_out >= check_in))),
    CONSTRAINT attendance_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.attendance OWNER TO postgres;

--
-- TOC entry 278 (class 1259 OID 31274)
-- Name: attendance_attendance_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.attendance ALTER COLUMN attendance_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.attendance_attendance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 229 (class 1259 OID 30506)
-- Name: block_ref; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.block_ref (
    block_id bigint NOT NULL,
    district_id bigint NOT NULL,
    block_name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.block_ref OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 30505)
-- Name: block_ref_block_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.block_ref ALTER COLUMN block_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.block_ref_block_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 277 (class 1259 OID 31245)
-- Name: camp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.camp (
    camp_id bigint NOT NULL,
    facility_id bigint,
    village_id bigint,
    camp_type public.camp_type_t,
    camp_name text NOT NULL,
    venue text,
    camp_date date NOT NULL,
    attendees integer,
    services text,
    notes text,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    legacy_id text,
    legacy_source text,
    CONSTRAINT camp_attendees_chk CHECK (((attendees IS NULL) OR (attendees >= 0))),
    CONSTRAINT camp_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.camp OWNER TO postgres;

--
-- TOC entry 309 (class 1259 OID 57386)
-- Name: camp_anchor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.camp_anchor (
    camp_anchor_id bigint NOT NULL,
    facility_id bigint NOT NULL,
    anchor_name text NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    CONSTRAINT camp_anchor_soft_delete CHECK ((((deleted_at IS NULL) AND (deleted_by IS NULL) AND (delete_reason IS NULL)) OR ((deleted_at IS NOT NULL) AND (deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL))))
);


ALTER TABLE public.camp_anchor OWNER TO postgres;

--
-- TOC entry 308 (class 1259 OID 57385)
-- Name: camp_anchor_camp_anchor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.camp_anchor_camp_anchor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.camp_anchor_camp_anchor_id_seq OWNER TO postgres;

--
-- TOC entry 5949 (class 0 OID 0)
-- Dependencies: 308
-- Name: camp_anchor_camp_anchor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.camp_anchor_camp_anchor_id_seq OWNED BY public.camp_anchor.camp_anchor_id;


--
-- TOC entry 276 (class 1259 OID 31244)
-- Name: camp_camp_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.camp ALTER COLUMN camp_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.camp_camp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 261 (class 1259 OID 30881)
-- Name: category_master; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.category_master (
    category_id bigint NOT NULL,
    category_name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.category_master OWNER TO postgres;

--
-- TOC entry 260 (class 1259 OID 30880)
-- Name: category_master_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.category_master ALTER COLUMN category_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.category_master_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 257 (class 1259 OID 30853)
-- Name: counselling_topic_master; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.counselling_topic_master (
    topic_id bigint NOT NULL,
    topic_name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.counselling_topic_master OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 30852)
-- Name: counselling_topic_master_topic_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.counselling_topic_master ALTER COLUMN topic_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.counselling_topic_master_topic_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 255 (class 1259 OID 30839)
-- Name: device_master; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.device_master (
    device_id bigint NOT NULL,
    device_name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.device_master OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 30838)
-- Name: device_master_device_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.device_master ALTER COLUMN device_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.device_master_device_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 281 (class 1259 OID 31313)
-- Name: device_status_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.device_status_history (
    device_status_id bigint NOT NULL,
    device_id bigint NOT NULL,
    facility_id bigint NOT NULL,
    status_date date NOT NULL,
    status public.device_state_t DEFAULT 'Working'::public.device_state_t NOT NULL,
    reported_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    CONSTRAINT device_status_history_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.device_status_history OWNER TO postgres;

--
-- TOC entry 280 (class 1259 OID 31312)
-- Name: device_status_history_device_status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.device_status_history ALTER COLUMN device_status_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.device_status_history_device_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 249 (class 1259 OID 30789)
-- Name: disease_master; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.disease_master (
    disease_id bigint NOT NULL,
    disease_name text NOT NULL,
    icd11_code text,
    synonyms text[] DEFAULT '{}'::text[] NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.disease_master OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 30788)
-- Name: disease_master_disease_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.disease_master ALTER COLUMN disease_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.disease_master_disease_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 227 (class 1259 OID 30486)
-- Name: district_ref; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.district_ref (
    district_id bigint NOT NULL,
    state_id bigint NOT NULL,
    district_name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.district_ref OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 30485)
-- Name: district_ref_district_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.district_ref ALTER COLUMN district_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.district_ref_district_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 233 (class 1259 OID 30549)
-- Name: facility; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.facility (
    facility_id bigint NOT NULL,
    facility_code text NOT NULL,
    facility_type public.facility_type_t NOT NULL,
    org_id bigint,
    facility_name text NOT NULL,
    state_id bigint,
    district_id bigint,
    block_id bigint,
    city text,
    latitude double precision,
    longitude double precision,
    vehicle_no text,
    icon_type text,
    route_color character(7),
    doctor_name text,
    tier_id text,
    subscription_start date,
    subscription_end date,
    joined_date date DEFAULT CURRENT_DATE NOT NULL,
    status public.entity_status_t DEFAULT 'active'::public.entity_status_t NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    legacy_id text,
    legacy_source text,
    CONSTRAINT facility_color_chk CHECK (((route_color IS NULL) OR (route_color ~ '^#[0-9A-Fa-f]{6}$'::text))),
    CONSTRAINT facility_lat_chk CHECK (((latitude IS NULL) OR ((latitude >= ('-90'::integer)::double precision) AND (latitude <= (90)::double precision)))),
    CONSTRAINT facility_lng_chk CHECK (((longitude IS NULL) OR ((longitude >= ('-180'::integer)::double precision) AND (longitude <= (180)::double precision)))),
    CONSTRAINT facility_org_chk CHECK ((((facility_type = 'standalone_clinic'::public.facility_type_t) AND (org_id IS NULL)) OR ((facility_type <> 'standalone_clinic'::public.facility_type_t) AND (org_id IS NOT NULL)))),
    CONSTRAINT facility_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text)))),
    CONSTRAINT facility_sub_range_chk CHECK (((subscription_end IS NULL) OR (subscription_start IS NULL) OR (subscription_end >= subscription_start))),
    CONSTRAINT facility_tier_chk CHECK (((facility_type = 'standalone_clinic'::public.facility_type_t) OR (tier_id IS NULL)))
);


ALTER TABLE public.facility OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 30548)
-- Name: facility_facility_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.facility ALTER COLUMN facility_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.facility_facility_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 253 (class 1259 OID 30823)
-- Name: lab_test_master; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lab_test_master (
    lab_test_id bigint NOT NULL,
    test_name text NOT NULL,
    category public.lab_category_t DEFAULT 'Other'::public.lab_category_t NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    price numeric(10,2) DEFAULT 0 NOT NULL
);


ALTER TABLE public.lab_test_master OWNER TO postgres;

--
-- TOC entry 5950 (class 0 OID 0)
-- Dependencies: 253
-- Name: COLUMN lab_test_master.price; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.lab_test_master.price IS 'Current rate. Historical charges live on appointment_lab_test.price, which is stamped at billing time so a reprint shows what the patient actually paid.';


--
-- TOC entry 252 (class 1259 OID 30822)
-- Name: lab_test_master_lab_test_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.lab_test_master ALTER COLUMN lab_test_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.lab_test_master_lab_test_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 243 (class 1259 OID 30706)
-- Name: leave_record; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.leave_record (
    leave_id bigint NOT NULL,
    staff_id bigint NOT NULL,
    from_date date NOT NULL,
    to_date date NOT NULL,
    reason text,
    replacement_staff_id bigint,
    status text DEFAULT 'Pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    CONSTRAINT leave_range_chk CHECK ((to_date >= from_date)),
    CONSTRAINT leave_record_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text)))),
    CONSTRAINT leave_self_chk CHECK (((replacement_staff_id IS NULL) OR (replacement_staff_id <> staff_id)))
);


ALTER TABLE public.leave_record OWNER TO postgres;

--
-- TOC entry 242 (class 1259 OID 30705)
-- Name: leave_record_leave_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.leave_record ALTER COLUMN leave_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.leave_record_leave_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 251 (class 1259 OID 30807)
-- Name: medicine_master; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.medicine_master (
    medicine_id bigint NOT NULL,
    medicine_name text NOT NULL,
    strength text DEFAULT ''::text NOT NULL,
    form text,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.medicine_master OWNER TO postgres;

--
-- TOC entry 250 (class 1259 OID 30806)
-- Name: medicine_master_medicine_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.medicine_master ALTER COLUMN medicine_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.medicine_master_medicine_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 292 (class 1259 OID 31679)
-- Name: migration_quarantine; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.migration_quarantine (
    quarantine_id bigint NOT NULL,
    target_table text NOT NULL,
    legacy_source text NOT NULL,
    legacy_id text,
    payload jsonb NOT NULL,
    error_message text NOT NULL,
    error_detail text,
    resolved boolean DEFAULT false NOT NULL,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.migration_quarantine OWNER TO postgres;

--
-- TOC entry 291 (class 1259 OID 31678)
-- Name: migration_quarantine_quarantine_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.migration_quarantine ALTER COLUMN quarantine_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.migration_quarantine_quarantine_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 294 (class 1259 OID 31698)
-- Name: migration_run; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.migration_run (
    run_id bigint NOT NULL,
    source_system text NOT NULL,
    target_table text NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    rows_read bigint DEFAULT 0 NOT NULL,
    rows_loaded bigint DEFAULT 0 NOT NULL,
    rows_quarantined bigint DEFAULT 0 NOT NULL,
    notes text,
    CONSTRAINT run_counts_chk CHECK (((rows_loaded + rows_quarantined) <= rows_read))
);


ALTER TABLE public.migration_run OWNER TO postgres;

--
-- TOC entry 293 (class 1259 OID 31697)
-- Name: migration_run_run_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.migration_run ALTER COLUMN run_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.migration_run_run_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 288 (class 1259 OID 31431)
-- Name: mmu_current_position; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mmu_current_position (
    facility_id bigint NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    accuracy_meters real,
    recorded_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.mmu_current_position OWNER TO postgres;

--
-- TOC entry 287 (class 1259 OID 31406)
-- Name: mmu_location_track; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mmu_location_track (
    track_id bigint NOT NULL,
    facility_id bigint NOT NULL,
    user_id bigint,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    accuracy_meters real,
    recorded_at timestamp with time zone NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT track_lat_chk CHECK (((latitude >= ('-90'::integer)::double precision) AND (latitude <= (90)::double precision))),
    CONSTRAINT track_lng_chk CHECK (((longitude >= ('-180'::integer)::double precision) AND (longitude <= (180)::double precision)))
);


ALTER TABLE public.mmu_location_track OWNER TO postgres;

--
-- TOC entry 286 (class 1259 OID 31405)
-- Name: mmu_location_track_track_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.mmu_location_track ALTER COLUMN track_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.mmu_location_track_track_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 235 (class 1259 OID 30605)
-- Name: mmu_route_stop; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mmu_route_stop (
    route_stop_id bigint NOT NULL,
    facility_id bigint NOT NULL,
    stop_seq smallint NOT NULL,
    location_name text,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    visit_date date NOT NULL,
    patient_count integer DEFAULT 0 NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    CONSTRAINT mmu_route_stop_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text)))),
    CONSTRAINT stop_lat_chk CHECK (((latitude >= ('-90'::integer)::double precision) AND (latitude <= (90)::double precision))),
    CONSTRAINT stop_lng_chk CHECK (((longitude >= ('-180'::integer)::double precision) AND (longitude <= (180)::double precision)))
);


ALTER TABLE public.mmu_route_stop OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 30604)
-- Name: mmu_route_stop_route_stop_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.mmu_route_stop ALTER COLUMN route_stop_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.mmu_route_stop_route_stop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 223 (class 1259 OID 30448)
-- Name: offer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.offer (
    offer_id bigint NOT NULL,
    offer_code text NOT NULL,
    description text,
    discount_pct numeric(5,2) NOT NULL,
    valid_from date NOT NULL,
    valid_to date NOT NULL,
    applies_to public.facility_type_t,
    status public.entity_status_t DEFAULT 'active'::public.entity_status_t NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    CONSTRAINT offer_pct_chk CHECK (((discount_pct > (0)::numeric) AND (discount_pct <= (100)::numeric))),
    CONSTRAINT offer_range_chk CHECK ((valid_to >= valid_from)),
    CONSTRAINT offer_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.offer OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 30447)
-- Name: offer_offer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.offer ALTER COLUMN offer_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.offer_offer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 220 (class 1259 OID 30406)
-- Name: organization; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organization (
    org_id bigint NOT NULL,
    org_code text NOT NULL,
    org_name text NOT NULL,
    contact_email text,
    joined_date date DEFAULT CURRENT_DATE NOT NULL,
    status public.entity_status_t DEFAULT 'active'::public.entity_status_t NOT NULL,
    logo_color character(7),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    legacy_id text,
    legacy_source text,
    CONSTRAINT org_color_chk CHECK (((logo_color IS NULL) OR (logo_color ~ '^#[0-9A-Fa-f]{6}$'::text))),
    CONSTRAINT org_email_chk CHECK (((contact_email IS NULL) OR (contact_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'::text))),
    CONSTRAINT organization_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.organization OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 30405)
-- Name: organization_org_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.organization ALTER COLUMN org_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.organization_org_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 263 (class 1259 OID 30895)
-- Name: patient; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.patient (
    patient_id bigint NOT NULL,
    unique_code text,
    org_id bigint,
    facility_id bigint,
    registered_by bigint,
    patient_name text NOT NULL,
    gender public.gender_t NOT NULL,
    age smallint,
    dob date,
    marital_status public.marital_t,
    contact_number character varying(10),
    aadhar_number character(12),
    blood_group character varying(3),
    category_id bigint,
    disability boolean DEFAULT false NOT NULL,
    pin_code character(6),
    address text,
    state_id bigint,
    district_id bigint,
    block_id bigint,
    village_id bigint,
    past_history text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    legacy_id text,
    legacy_source text,
    CONSTRAINT patient_aadhar_chk CHECK (((aadhar_number IS NULL) OR (aadhar_number ~ '^[0-9]{12}$'::text))),
    CONSTRAINT patient_age_chk CHECK (((age IS NULL) OR ((age >= 0) AND (age <= 130)))),
    CONSTRAINT patient_age_or_dob CHECK (((age IS NOT NULL) OR (dob IS NOT NULL))),
    CONSTRAINT patient_blood_chk CHECK (((blood_group IS NULL) OR ((blood_group)::text = ANY ((ARRAY['O+'::character varying, 'O-'::character varying, 'A+'::character varying, 'A-'::character varying, 'B+'::character varying, 'B-'::character varying, 'AB+'::character varying, 'AB-'::character varying])::text[])))),
    CONSTRAINT patient_contact_chk CHECK (((contact_number IS NULL) OR ((contact_number)::text ~ '^[6-9][0-9]{9}$'::text))),
    CONSTRAINT patient_dob_chk CHECK (((dob IS NULL) OR (dob <= CURRENT_DATE))),
    CONSTRAINT patient_pin_chk CHECK (((pin_code IS NULL) OR (pin_code ~ '^[1-9][0-9]{5}$'::text))),
    CONSTRAINT patient_reachable CHECK (((contact_number IS NOT NULL) OR (unique_code IS NOT NULL))),
    CONSTRAINT patient_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.patient OWNER TO postgres;

--
-- TOC entry 290 (class 1259 OID 31448)
-- Name: patient_monthly_aggregate; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.patient_monthly_aggregate (
    aggregate_id bigint NOT NULL,
    org_id bigint NOT NULL,
    source public.facility_type_t NOT NULL,
    month character(7) NOT NULL,
    total integer DEFAULT 0 NOT NULL,
    male integer DEFAULT 0 NOT NULL,
    female integer DEFAULT 0 NOT NULL,
    other integer DEFAULT 0 NOT NULL,
    age_0_5 integer DEFAULT 0 NOT NULL,
    age_6_17 integer DEFAULT 0 NOT NULL,
    age_18_45 integer DEFAULT 0 NOT NULL,
    age_46_60 integer DEFAULT 0 NOT NULL,
    age_60_plus integer DEFAULT 0 NOT NULL,
    computed_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT agg_gender_chk CHECK ((((male + female) + other) = total)),
    CONSTRAINT agg_month_chk CHECK ((month ~ '^\d{4}-(0[1-9]|1[0-2])$'::text))
);


ALTER TABLE public.patient_monthly_aggregate OWNER TO postgres;

--
-- TOC entry 289 (class 1259 OID 31447)
-- Name: patient_monthly_aggregate_aggregate_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.patient_monthly_aggregate ALTER COLUMN aggregate_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.patient_monthly_aggregate_aggregate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 262 (class 1259 OID 30894)
-- Name: patient_patient_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.patient ALTER COLUMN patient_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.patient_patient_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 271 (class 1259 OID 31152)
-- Name: prescription_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prescription_item (
    prescription_item_id bigint NOT NULL,
    appointment_id bigint NOT NULL,
    medicine_id bigint,
    medicine_name text NOT NULL,
    dosage text DEFAULT ''::text NOT NULL,
    frequency public.frequency_t DEFAULT 'TDS'::public.frequency_t NOT NULL,
    duration_days smallint DEFAULT 5 NOT NULL,
    qty integer DEFAULT 0 NOT NULL,
    dispensed_qty integer DEFAULT 0 NOT NULL,
    dispensed boolean DEFAULT false NOT NULL,
    qty_change_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    legacy_id text,
    legacy_source text,
    CONSTRAINT prescription_item_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text)))),
    CONSTRAINT rx_duration_chk CHECK ((duration_days > 0)),
    CONSTRAINT rx_qty_chk CHECK (((qty >= 0) AND (dispensed_qty >= 0))),
    CONSTRAINT rx_reason_chk CHECK (((dispensed_qty = qty) OR ((qty_change_reason IS NOT NULL) AND (qty_change_reason <> ''::text))))
);


ALTER TABLE public.prescription_item OWNER TO postgres;

--
-- TOC entry 270 (class 1259 OID 31151)
-- Name: prescription_item_prescription_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.prescription_item ALTER COLUMN prescription_item_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.prescription_item_prescription_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 275 (class 1259 OID 31215)
-- Name: previous_prescription; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.previous_prescription (
    previous_rx_id bigint NOT NULL,
    patient_id bigint NOT NULL,
    appointment_id bigint,
    medicine_name text NOT NULL,
    dosage text DEFAULT ''::text NOT NULL,
    frequency text DEFAULT ''::text NOT NULL,
    duration text DEFAULT ''::text NOT NULL,
    prescribed_on date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    legacy_id text,
    legacy_source text,
    CONSTRAINT previous_prescription_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.previous_prescription OWNER TO postgres;

--
-- TOC entry 274 (class 1259 OID 31214)
-- Name: previous_prescription_previous_rx_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.previous_prescription ALTER COLUMN previous_rx_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.previous_prescription_previous_rx_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 259 (class 1259 OID 30867)
-- Name: referral_destination_master; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.referral_destination_master (
    destination_id bigint NOT NULL,
    destination_name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.referral_destination_master OWNER TO postgres;

--
-- TOC entry 258 (class 1259 OID 30866)
-- Name: referral_destination_master_destination_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.referral_destination_master ALTER COLUMN destination_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.referral_destination_master_destination_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 307 (class 1259 OID 57363)
-- Name: refresh_session; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.refresh_session (
    session_id bigint NOT NULL,
    user_id bigint NOT NULL,
    token_hash text NOT NULL,
    issued_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    last_used_at timestamp with time zone,
    revoked_at timestamp with time zone,
    user_agent text
);


ALTER TABLE public.refresh_session OWNER TO postgres;

--
-- TOC entry 306 (class 1259 OID 57362)
-- Name: refresh_session_session_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.refresh_session_session_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.refresh_session_session_id_seq OWNER TO postgres;

--
-- TOC entry 5951 (class 0 OID 0)
-- Dependencies: 306
-- Name: refresh_session_session_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.refresh_session_session_id_seq OWNED BY public.refresh_session.session_id;


--
-- TOC entry 283 (class 1259 OID 31345)
-- Name: requisition; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.requisition (
    requisition_id bigint NOT NULL,
    facility_id bigint,
    raised_by bigint,
    requisition_date date DEFAULT CURRENT_DATE NOT NULL,
    status public.requisition_status_t DEFAULT 'Requested'::public.requisition_status_t NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    legacy_id text,
    legacy_source text,
    reviewed_by bigint,
    reviewed_at timestamp with time zone,
    remarks text DEFAULT ''::text NOT NULL,
    CONSTRAINT requisition_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.requisition OWNER TO postgres;

--
-- TOC entry 285 (class 1259 OID 31370)
-- Name: requisition_line; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.requisition_line (
    requisition_line_id bigint NOT NULL,
    requisition_id bigint NOT NULL,
    medicine_id bigint,
    medicine_name text NOT NULL,
    dosage text DEFAULT ''::text NOT NULL,
    requested_qty integer DEFAULT 0 NOT NULL,
    dispatched_qty integer DEFAULT 0 NOT NULL,
    received_qty integer DEFAULT 0 NOT NULL,
    received boolean DEFAULT false NOT NULL,
    status public.requisition_status_t DEFAULT 'Pending'::public.requisition_status_t NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    legacy_id text,
    legacy_source text,
    approved_qty integer,
    review_note text DEFAULT ''::text NOT NULL,
    added_by_cmo boolean DEFAULT false NOT NULL,
    CONSTRAINT req_qty_chk CHECK (((requested_qty >= 0) AND (dispatched_qty >= 0) AND (received_qty >= 0))),
    CONSTRAINT reqline_added_chk CHECK (((added_by_cmo = false) OR (requested_qty = 0))),
    CONSTRAINT reqline_qty_chk CHECK (((requested_qty >= 0) AND (dispatched_qty >= 0) AND (received_qty >= 0) AND ((approved_qty IS NULL) OR (approved_qty >= 0)) AND ((approved_qty IS NULL) OR added_by_cmo OR (approved_qty <= requested_qty)))),
    CONSTRAINT requisition_line_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.requisition_line OWNER TO postgres;

--
-- TOC entry 5952 (class 0 OID 0)
-- Dependencies: 285
-- Name: COLUMN requisition_line.approved_qty; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.requisition_line.approved_qty IS 'NULL = not yet reviewed. 0 = reviewed and rejected. The two are different states and must not be collapsed.';


--
-- TOC entry 5953 (class 0 OID 0)
-- Dependencies: 285
-- Name: COLUMN requisition_line.added_by_cmo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.requisition_line.added_by_cmo IS 'The CMO added this medicine; the pharmacist did not request it. Such a line has requested_qty 0, so stock reports can tell requested from directed.';


--
-- TOC entry 284 (class 1259 OID 31369)
-- Name: requisition_line_requisition_line_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.requisition_line ALTER COLUMN requisition_line_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.requisition_line_requisition_line_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 282 (class 1259 OID 31344)
-- Name: requisition_requisition_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.requisition ALTER COLUMN requisition_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.requisition_requisition_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 241 (class 1259 OID 30682)
-- Name: roster; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roster (
    roster_id bigint NOT NULL,
    org_id bigint NOT NULL,
    facility_id bigint,
    roster_month character(7) NOT NULL,
    file_path text,
    uploaded_by bigint,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    CONSTRAINT roster_month_chk CHECK ((roster_month ~ '^\d{4}-(0[1-9]|1[0-2])$'::text)),
    CONSTRAINT roster_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.roster OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 30681)
-- Name: roster_roster_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.roster ALTER COLUMN roster_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.roster_roster_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 237 (class 1259 OID 30631)
-- Name: staff; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.staff (
    staff_id bigint NOT NULL,
    org_id bigint,
    staff_name text NOT NULL,
    role public.role_t NOT NULL,
    phone character varying(10),
    facility_id bigint,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    legacy_id text,
    legacy_source text,
    CONSTRAINT staff_phone_chk CHECK (((phone IS NULL) OR ((phone)::text ~ '^[6-9][0-9]{9}$'::text))),
    CONSTRAINT staff_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.staff OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 30659)
-- Name: staff_assignment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.staff_assignment (
    assignment_id bigint NOT NULL,
    staff_id bigint NOT NULL,
    facility_id bigint NOT NULL,
    role public.role_t NOT NULL,
    from_date date NOT NULL,
    to_date date,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text,
    CONSTRAINT assignment_range_chk CHECK (((to_date IS NULL) OR (to_date >= from_date))),
    CONSTRAINT staff_assignment_soft_del_chk CHECK (((deleted_at IS NULL) OR ((deleted_by IS NOT NULL) AND (delete_reason IS NOT NULL) AND (delete_reason <> ''::text))))
);


ALTER TABLE public.staff_assignment OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 30658)
-- Name: staff_assignment_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.staff_assignment ALTER COLUMN assignment_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.staff_assignment_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 236 (class 1259 OID 30630)
-- Name: staff_staff_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.staff ALTER COLUMN staff_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.staff_staff_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 225 (class 1259 OID 30469)
-- Name: state_ref; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.state_ref (
    state_id bigint NOT NULL,
    state_code character(2) NOT NULL,
    state_name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.state_ref OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 30468)
-- Name: state_ref_state_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.state_ref ALTER COLUMN state_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.state_ref_state_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 221 (class 1259 OID 30430)
-- Name: subscription_tier; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.subscription_tier (
    tier_id text NOT NULL,
    label text NOT NULL,
    months smallint NOT NULL,
    patient_limit integer NOT NULL,
    price numeric(10,2) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT tier_limit_chk CHECK ((patient_limit > 0)),
    CONSTRAINT tier_months_chk CHECK ((months >= 0)),
    CONSTRAINT tier_price_chk CHECK ((price >= (0)::numeric))
);


ALTER TABLE public.subscription_tier OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 30771)
-- Name: symptom_master; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.symptom_master (
    symptom_id bigint NOT NULL,
    symptom_name text NOT NULL,
    aliases text[] DEFAULT '{}'::text[] NOT NULL,
    is_custom boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.symptom_master OWNER TO postgres;

--
-- TOC entry 246 (class 1259 OID 30770)
-- Name: symptom_master_symptom_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.symptom_master ALTER COLUMN symptom_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.symptom_master_symptom_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 312 (class 1259 OID 57424)
-- Name: sync_action; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sync_action (
    sync_action_id bigint NOT NULL,
    user_id bigint NOT NULL,
    client_action_id text NOT NULL,
    client_batch_id text,
    kind text NOT NULL,
    status text NOT NULL,
    server_id bigint,
    result jsonb,
    error_code text,
    error_message text,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sync_action OWNER TO postgres;

--
-- TOC entry 311 (class 1259 OID 57423)
-- Name: sync_action_sync_action_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sync_action_sync_action_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sync_action_sync_action_id_seq OWNER TO postgres;

--
-- TOC entry 5954 (class 0 OID 0)
-- Dependencies: 311
-- Name: sync_action_sync_action_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sync_action_sync_action_id_seq OWNED BY public.sync_action.sync_action_id;


--
-- TOC entry 297 (class 1259 OID 32817)
-- Name: user_zone; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_zone (
    user_zone_id bigint NOT NULL,
    user_id bigint NOT NULL,
    state_id bigint NOT NULL,
    district_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by bigint,
    delete_reason text
);


ALTER TABLE public.user_zone OWNER TO postgres;

--
-- TOC entry 5955 (class 0 OID 0)
-- Dependencies: 297
-- Name: TABLE user_zone; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.user_zone IS 'Geographies a zonal incharge supervises. district_id NULL = the whole state.';


--
-- TOC entry 296 (class 1259 OID 32816)
-- Name: user_zone_user_zone_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.user_zone ALTER COLUMN user_zone_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.user_zone_user_zone_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 302 (class 1259 OID 32877)
-- Name: v_app_user_active; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_app_user_active AS
 SELECT user_id,
    username,
    password_hash,
    full_name,
    role,
    org_id,
    facility_id,
    staff_id,
    is_active,
    last_login_at,
    created_at,
    deleted_at,
    deleted_by,
    delete_reason,
    legacy_id,
    legacy_source
   FROM public.app_user
  WHERE (deleted_at IS NULL);


ALTER VIEW public.v_app_user_active OWNER TO postgres;

--
-- TOC entry 298 (class 1259 OID 32859)
-- Name: v_appointment_active; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_appointment_active AS
 SELECT appointment_id,
    patient_id,
    facility_id,
    org_id,
    source,
    appointment_date,
    month,
    status,
    registered_by,
    attended_by,
    lab_by,
    dispensed_by,
    assigned_doctor_id,
    taken_prescribed_medicine,
    pregnant,
    lmp_date,
    edd_date,
    counsellor_remarks,
    height,
    weight,
    systolic_bp,
    diastolic_bp,
    blood_sugar,
    body_temp,
    oxygen,
    hemoglobin,
    bp_category,
    observation,
    doctor_remarks,
    follow_up_date,
    follow_up_done,
    referred,
    referral_destination_id,
    counselled,
    counselling_topic_id,
    lab_report_date,
    payment_type,
    paid_amount,
    delivery_status,
    denial_reason,
    lama_at,
    created_at,
    updated_at,
    deleted_at,
    deleted_by,
    delete_reason,
    legacy_id,
    legacy_source,
    fee_collected_at,
    fee_collected_by,
    test_payment_total,
    test_paid_at,
    test_paid_by
   FROM public.appointment
  WHERE (deleted_at IS NULL);


ALTER VIEW public.v_appointment_active OWNER TO postgres;

--
-- TOC entry 313 (class 1259 OID 57457)
-- Name: v_attendance_active; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_attendance_active AS
 SELECT attendance_id,
    user_id,
    facility_id,
    role,
    attendance_date,
    check_in,
    check_out,
    location,
    status,
    start_km,
    end_km,
    total_run,
    collection,
    notes,
    photo_path,
    latitude,
    longitude,
    created_at,
    updated_at,
    camp_anchor_id
   FROM public.attendance
  WHERE (deleted_at IS NULL);


ALTER VIEW public.v_attendance_active OWNER TO postgres;

--
-- TOC entry 310 (class 1259 OID 57419)
-- Name: v_camp_anchor_active; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_camp_anchor_active AS
 SELECT camp_anchor_id,
    facility_id,
    anchor_name,
    latitude,
    longitude,
    is_active,
    created_at,
    updated_at
   FROM public.camp_anchor
  WHERE (deleted_at IS NULL);


ALTER VIEW public.v_camp_anchor_active OWNER TO postgres;

--
-- TOC entry 303 (class 1259 OID 32881)
-- Name: v_facility_active; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_facility_active AS
 SELECT facility_id,
    facility_code,
    facility_type,
    org_id,
    facility_name,
    state_id,
    district_id,
    block_id,
    city,
    latitude,
    longitude,
    vehicle_no,
    icon_type,
    route_color,
    doctor_name,
    tier_id,
    subscription_start,
    subscription_end,
    joined_date,
    status,
    created_at,
    updated_at,
    deleted_at,
    deleted_by,
    delete_reason,
    legacy_id,
    legacy_source
   FROM public.facility
  WHERE (deleted_at IS NULL);


ALTER VIEW public.v_facility_active OWNER TO postgres;

--
-- TOC entry 299 (class 1259 OID 32864)
-- Name: v_lab_test_active; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_lab_test_active AS
 SELECT appointment_lab_id,
    appointment_id,
    lab_test_id,
    test_name,
    sample_done,
    sample_reason,
    assigned_handover_date,
    handover_date,
    handover_delay_reason,
    result,
    created_at,
    deleted_at,
    deleted_by,
    delete_reason,
    legacy_id,
    legacy_source,
    price,
    paid,
    paid_at,
    paid_by
   FROM public.appointment_lab_test
  WHERE (deleted_at IS NULL);


ALTER VIEW public.v_lab_test_active OWNER TO postgres;

--
-- TOC entry 301 (class 1259 OID 32872)
-- Name: v_patient_active; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_patient_active AS
 SELECT patient_id,
    unique_code,
    org_id,
    facility_id,
    registered_by,
    patient_name,
    gender,
    age,
    dob,
    marital_status,
    contact_number,
    aadhar_number,
    blood_group,
    category_id,
    disability,
    pin_code,
    address,
    state_id,
    district_id,
    block_id,
    village_id,
    past_history,
    created_at,
    updated_at,
    deleted_at,
    deleted_by,
    delete_reason,
    legacy_id,
    legacy_source
   FROM public.patient
  WHERE (deleted_at IS NULL);


ALTER VIEW public.v_patient_active OWNER TO postgres;

--
-- TOC entry 300 (class 1259 OID 32868)
-- Name: v_prescription_item_active; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_prescription_item_active AS
 SELECT prescription_item_id,
    appointment_id,
    medicine_id,
    medicine_name,
    dosage,
    frequency,
    duration_days,
    qty,
    dispensed_qty,
    dispensed,
    qty_change_reason,
    created_at,
    deleted_at,
    deleted_by,
    delete_reason,
    legacy_id,
    legacy_source
   FROM public.prescription_item
  WHERE (deleted_at IS NULL);


ALTER VIEW public.v_prescription_item_active OWNER TO postgres;

--
-- TOC entry 304 (class 1259 OID 32886)
-- Name: v_requisition_active; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_requisition_active AS
 SELECT requisition_id,
    facility_id,
    raised_by,
    requisition_date,
    status,
    created_at,
    updated_at,
    deleted_at,
    deleted_by,
    delete_reason,
    legacy_id,
    legacy_source,
    reviewed_by,
    reviewed_at,
    remarks
   FROM public.requisition
  WHERE (deleted_at IS NULL);


ALTER VIEW public.v_requisition_active OWNER TO postgres;

--
-- TOC entry 295 (class 1259 OID 31732)
-- Name: v_staff_active; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_staff_active AS
 SELECT staff_id,
    org_id,
    staff_name,
    role,
    phone,
    facility_id,
    is_active,
    created_at,
    deleted_at,
    deleted_by,
    delete_reason,
    legacy_id,
    legacy_source
   FROM public.staff
  WHERE (deleted_at IS NULL);


ALTER VIEW public.v_staff_active OWNER TO postgres;

--
-- TOC entry 305 (class 1259 OID 32890)
-- Name: v_user_zone_active; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_user_zone_active AS
 SELECT user_zone_id,
    user_id,
    state_id,
    district_id,
    created_at,
    deleted_at,
    deleted_by,
    delete_reason
   FROM public.user_zone
  WHERE (deleted_at IS NULL);


ALTER VIEW public.v_user_zone_active OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 30526)
-- Name: village_ref; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.village_ref (
    village_id bigint NOT NULL,
    block_id bigint NOT NULL,
    village_name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.village_ref OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 30525)
-- Name: village_ref_village_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.village_ref ALTER COLUMN village_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.village_ref_village_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 5278 (class 2604 OID 57389)
-- Name: camp_anchor camp_anchor_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camp_anchor ALTER COLUMN camp_anchor_id SET DEFAULT nextval('public.camp_anchor_camp_anchor_id_seq'::regclass);


--
-- TOC entry 5276 (class 2604 OID 57366)
-- Name: refresh_session session_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.refresh_session ALTER COLUMN session_id SET DEFAULT nextval('public.refresh_session_session_id_seq'::regclass);


--
-- TOC entry 5282 (class 2604 OID 57427)
-- Name: sync_action sync_action_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sync_action ALTER COLUMN sync_action_id SET DEFAULT nextval('public.sync_action_sync_action_id_seq'::regclass);


--
-- TOC entry 5884 (class 0 OID 30735)
-- Dependencies: 245
-- Data for Name: app_user; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.app_user (user_id, username, password_hash, full_name, role, org_id, facility_id, staff_id, is_active, last_login_at, created_at, deleted_at, deleted_by, delete_reason, legacy_id, legacy_source, token_version) FROM stdin;
20	zonal_north	$2b$12$gWvNqCLAofrQ1okFkFTLI.y84tKR9aPVTTbSx3xnX4WMH19Selg.u	Rakesh Verma (North Zone)	zonal_incharge	1	\N	\N	t	2026-08-11 14:32:59.386664+05:30	2026-08-10 00:16:14.489338+05:30	\N	\N	\N	\N	\N	0
19	cmo_jubicare	$2b$12$yC3CNdM7SqV0Kl//5w8c9.vNrkaNrGF5AWwF95hpdiVVOJQahOAhW	Dr. Sunita Rao (CMO)	cmo	1	\N	\N	t	2026-08-11 14:33:06.364013+05:30	2026-08-10 00:16:14.489338+05:30	\N	\N	\N	\N	\N	0
18	admin_jubicare	$2b$12$mBY4P7.Ur39dm6DkkwSR/O5DbnvgfQXFhTqAO4xMpxdCbzgxBvO2S	JubiCare Admin	org_admin	1	\N	\N	t	2026-08-12 10:09:55.33009+05:30	2026-08-10 00:16:14.489338+05:30	\N	\N	\N	\N	\N	0
7	cmo_test	$2b$12$G8I4RhWlCO/.9ZesDQ7bvu/WXnUT.MT4TBOV/YLE4gU0U8H0Q1yMK	Dr. Sunita Rao	cmo	1	\N	\N	t	2026-08-11 15:54:02.330365+05:30	2026-08-09 22:35:19.466323+05:30	\N	\N	\N	\N	\N	0
3	pha_test	$2b$12$5yUcPc1OUnRi51XvIw3maOIukGVxaF4OQ3G6orbK0v7JwREtytl3W	Kedar Dash	pharmacist	1	1	3	t	2026-08-11 15:54:01.952032+05:30	2026-08-03 14:50:13.85991+05:30	\N	\N	\N	\N	\N	0
15	cmo_af54e1	$2b$12$l00jfutM2AdWkaqEqNTxq..RL.KETAyJk7PcyGgIhZQPpUXPN7vbu	Test CMO	cmo	1	\N	\N	f	2026-08-09 23:40:25.391306+05:30	2026-08-09 23:40:24.661198+05:30	\N	\N	\N	\N	\N	0
16	zon_af54e1	$2b$12$XwtWdpigN.KvR6JjH/xDG.p0Uq8IJxiMySpwqRHjBAxH4h1EMeLXO	Test Zonal	zonal_incharge	1	\N	\N	f	2026-08-09 23:40:25.795644+05:30	2026-08-09 23:40:25.011448+05:30	\N	\N	\N	\N	\N	0
9	cmo_905526	$2b$12$7mHkhT5a7PCGuMNfgwjJguL5zAg0lVnzEH6ZO.BKJ3OJH/X8r1.4W	Test CMO	cmo	1	\N	\N	f	2026-08-09 22:38:21.213388+05:30	2026-08-09 22:38:20.33148+05:30	\N	\N	\N	\N	\N	0
17	super_admin	$2b$12$rF6RAdgeq5MrA2gH3NXmFe3oCpEPVt.oMIH3m3kkcwr82cyPI9Kv.	JBF Super Admin	super_admin	1	\N	\N	t	2026-08-11 15:54:29.765937+05:30	2026-08-10 00:16:14.489338+05:30	\N	\N	\N	\N	\N	0
10	zon_905526	$2b$12$lj7rk57o8dq9v24NBAvhleZPSjrxKKJzge70x2i2vmjqjhHGJgzre	Test Zonal	zonal_incharge	1	\N	\N	f	2026-08-09 22:38:21.659039+05:30	2026-08-09 22:38:20.774764+05:30	\N	\N	\N	\N	\N	0
13	cmo_2153df	$2b$12$pBPoXKKawZS6H5Bg1nX4xuP7SQhvute0TKOxf7woz.VTMkaGkFxRG	Test CMO	cmo	1	\N	\N	f	2026-08-09 23:17:00.350705+05:30	2026-08-09 23:16:59.452067+05:30	\N	\N	\N	\N	\N	0
14	zon_2153df	$2b$12$IHIOVndoCDlveATwfSEgZ.MUpmWbXw43sRETa8X5TMeZRusxm8V16	Test Zonal	zonal_incharge	1	\N	\N	f	2026-08-09 23:17:00.772329+05:30	2026-08-09 23:16:59.902235+05:30	\N	\N	\N	\N	\N	0
11	cmo_710b17	$2b$12$qAd4aFuusp70lwxPvZQ7hO/Ogoo393YYZmIKVOLLeDRXEndiaL8LW	Test CMO	cmo	1	\N	\N	f	2026-08-09 22:52:49.279364+05:30	2026-08-09 22:52:48.05277+05:30	\N	\N	\N	\N	\N	0
12	zon_710b17	$2b$12$pyQ/N2NDuoApdPbHAaJELOorAnA1KQ.qtAiBYvpmftu7GFE5GIOt2	Test Zonal	zonal_incharge	1	\N	\N	f	2026-08-09 22:52:49.713567+05:30	2026-08-09 22:52:48.827341+05:30	\N	\N	\N	\N	\N	0
178	admin_d641	$2b$12$Mw7JYMhx0doi5jmh4XKVIeebHJ81yK8rLrZ2bt82mQGnGj0iamQrO	Dash Test 641 Admin	org_admin	61	\N	\N	t	2026-08-11 14:03:15.500732+05:30	2026-08-11 14:03:13.158761+05:30	\N	\N	\N	\N	\N	0
8	zonal_test	$2b$12$mCv3A4LCg1aHTl0UpScOhegdor0m7e.jcgoNKMTZFE7qNiuTzdj/y	Rakesh Verma	zonal_incharge	1	\N	\N	t	2026-08-11 15:54:03.119349+05:30	2026-08-09 22:35:20.023315+05:30	\N	\N	\N	\N	\N	0
21	cmo_005898	$2b$12$Czg6etXHNniUt7/atXsnVuvrl43rhZmfQ0e1uwCqs3MJABHig8cM.	Test CMO	cmo	1	\N	\N	t	2026-08-10 11:09:20.640482+05:30	2026-08-10 11:09:19.513597+05:30	\N	\N	\N	\N	\N	0
22	zon_005898	$2b$12$VtUukYd55DtdUKQDx3zl.OZqFsA5bKyWTjt.0yle5/b2Ig2GFKi4e	Test Zonal	zonal_incharge	1	\N	\N	t	2026-08-10 11:09:21.007639+05:30	2026-08-10 11:09:20.118162+05:30	\N	\N	\N	\N	\N	0
5	admin	$2b$12$Au4aAg0gEJjvx3BxUGthDOOsvKmdW12ckFwcCZCcIBTWJeGKT6Rz2	JubiCare Admin	org_admin	1	\N	\N	t	2026-08-11 15:54:01.045317+05:30	2026-08-03 14:50:13.85991+05:30	\N	\N	\N	\N	\N	0
23	cmo_54adeb	$2b$12$je056CKv3zKSRe6/VxO/ZO8DyxMdQngL86e30Et3lDfWejD/U/i4W	Test CMO	cmo	1	\N	\N	t	2026-08-10 11:41:55.959874+05:30	2026-08-10 11:41:55.291522+05:30	\N	\N	\N	\N	\N	0
182	t.worker18	$2b$12$bT6Ub3f7jfpX..lAv19Dq.wc2MiJdoIfUd1fYixp/xm2/TQX5KZiS	Temp Worker 1241	lab	1	\N	229	f	2026-08-11 14:03:28.46279+05:30	2026-08-11 14:03:25.692362+05:30	\N	\N	\N	\N	\N	0
24	zon_54adeb	$2b$12$1vR2ZDN74wFPXFpV2EaDnuwz/cLtiqhhRwWiF7gINZFOgOMQ5448e	Test Zonal	zonal_incharge	1	\N	\N	t	2026-08-10 11:41:56.387571+05:30	2026-08-10 11:41:55.62485+05:30	\N	\N	\N	\N	\N	0
25	admin_t992	$2b$12$oZwjiRim9F8A2MAr0BpNnuoEwxj814hvkmuo.Y718.Efsq3hc7aze	Test Foundation 992 Admin	org_admin	5	\N	\N	f	\N	2026-08-10 16:31:35.445055+05:30	\N	\N	\N	\N	\N	0
26	admin_q518	$2b$12$qTPPJV.v6Twt2.TBnc/6hu0SsiiTnEossNYI5/DLVBLhtH8V16Ofe	Quick Org 518 Admin	org_admin	6	\N	\N	f	2026-08-10 16:32:09.686592+05:30	2026-08-10 16:32:02.324839+05:30	\N	\N	\N	\N	\N	0
29	cmo_515e16	$2b$12$/Je3vaI6bqX1dVecQ2xC1.Y9f4R5xR1iM9OuN.9AVVwD6ItP5eu7e	Test CMO	cmo	1	\N	\N	t	2026-08-10 16:36:12.27563+05:30	2026-08-10 16:36:11.362646+05:30	\N	\N	\N	\N	\N	0
27	admin_d723	$2b$12$I9cKCt5X1KcQDUDcoGu1pOgPgMPcIqrKI813Qp9l69/T/uRQaVaIq	Dash Test 723 Admin	org_admin	7	\N	\N	f	2026-08-10 16:34:57.494218+05:30	2026-08-10 16:34:54.781954+05:30	\N	\N	\N	\N	\N	0
28	admin_d929	$2b$12$M58LclU9umK44UJkxA.Fge6dh2NIni8Hzyy.9dW/paSHCvti/3Yq2	Dash Test 929 Admin	org_admin	8	\N	\N	f	2026-08-10 16:35:06.543307+05:30	2026-08-10 16:35:03.492904+05:30	\N	\N	\N	\N	\N	0
40	admin_d740	$2b$12$ShLr6Wdt23ae6ocMPP2d2uYsGhrttzVzU6Jz7jZawsFfbygBF1nH6	Dash Test 740 Admin	org_admin	13	\N	\N	t	2026-08-10 16:56:47.657732+05:30	2026-08-10 16:56:45.384598+05:30	\N	\N	\N	\N	\N	0
30	zon_515e16	$2b$12$M/9u.9Dk4LrFC6tOGThFnu9nxyKIftYE/TSJuKtYN4IoHE/BfOyiu	Test Zonal	zonal_incharge	1	\N	\N	t	2026-08-10 16:36:12.701648+05:30	2026-08-10 16:36:11.761412+05:30	\N	\N	\N	\N	\N	0
31	admin_d839	$2b$12$gl6rmhqezYuvlKuzUbzvHOOuF/nmMgR5vfae01yrY/xuMfK5Dz2mC	Dash Test 839 Admin	org_admin	9	\N	\N	f	2026-08-10 16:36:31.86634+05:30	2026-08-10 16:36:29.392392+05:30	\N	\N	\N	\N	\N	0
32	admin_rf	$2b$12$/IfbB0QdGHQ2h3cuH.KxXO1vUFDZkbH1xXkPYhl/pg6IWx3hb/BN2	Reliance Foundation Admin	org_admin	2	\N	\N	t	2026-08-10 16:37:54.3464+05:30	2026-08-10 16:37:35.522131+05:30	\N	\N	\N	\N	\N	0
33	admin_tt	$2b$12$hpKioKZUT3mfzNyy5Ytfluu1yqsoQPNUAbaxo/yethPZTfQz1HIhK	Tata Trusts Admin	org_admin	3	\N	\N	t	2026-08-10 16:37:54.932723+05:30	2026-08-10 16:37:35.522131+05:30	\N	\N	\N	\N	\N	0
34	admin_fgdf	$2b$12$/ijI.0L8T5gJxSySWzHLjuLhkFScqFu4RVnNeyFCaAi0lkUgaMvZ.	Indev abc test Admin	org_admin	4	\N	\N	t	2026-08-10 16:37:55.700693+05:30	2026-08-10 16:37:35.522131+05:30	\N	\N	\N	\N	\N	0
35	cmo_3b6d39	$2b$12$53fUorXomn6xaaxPyGdTaOJQnBz4oKqAsSEFZqLioAxv8pN7IsQPO	Test CMO	cmo	1	\N	\N	t	2026-08-10 16:38:13.232171+05:30	2026-08-10 16:38:12.452064+05:30	\N	\N	\N	\N	\N	0
36	zon_3b6d39	$2b$12$s.Vi/VT/p.dmX92tdBttNeJDbSmSixK.IL2DmKQC/4C0PXkJkS3pO	Test Zonal	zonal_incharge	1	\N	\N	t	2026-08-10 16:38:13.647468+05:30	2026-08-10 16:38:12.844582+05:30	\N	\N	\N	\N	\N	0
37	admin_d373	$2b$12$XemrkAECOMp8fCLrfvzdqO82MUqycAvrFPFnyBSQSE.vl0dqE347K	Dash Test 373 Admin	org_admin	10	\N	\N	t	2026-08-10 16:38:35.098779+05:30	2026-08-10 16:38:31.467467+05:30	\N	\N	\N	\N	\N	0
41	cmo_d1d118	$2b$12$CIkAivwp7SDZIYR.nNpNY.MbSblRi76kS.9Y/nCyiQLNBnGDL21bi	Test CMO	cmo	1	\N	\N	t	2026-08-10 16:57:03.478571+05:30	2026-08-10 16:57:02.791558+05:30	\N	\N	\N	\N	\N	0
39	admin_d721	$2b$12$CF2NqpIjuY2sGcIzEO2auuH2DyC5Xq6.nBVBbJcP0XX7wEx6QXe8m	Dash Test 721 Admin	org_admin	12	\N	\N	t	2026-08-10 16:51:33.691783+05:30	2026-08-10 16:51:31.021166+05:30	\N	\N	\N	\N	\N	0
42	zon_d1d118	$2b$12$5P63c7NTujzwuTUE1OK8D.V7UlfXxUA/0O4XYIV4CiHU2mAqcyC2C	Test Zonal	zonal_incharge	1	\N	\N	t	2026-08-10 16:57:03.907043+05:30	2026-08-10 16:57:03.125732+05:30	\N	\N	\N	\N	\N	0
43	admin_d612	$2b$12$C.EW5fMS32m1jdz7eCemieY20S83ql/PllGwN6zpI55KQFcX5gAIO	Dash Test 612 Admin	org_admin	14	\N	\N	t	2026-08-10 16:57:22.073757+05:30	2026-08-10 16:57:19.007864+05:30	\N	\N	\N	\N	\N	0
44	admin_d810	$2b$12$4JlPZb.rcOD4Yx0n/OuDbu9iVfbHfEGED7r.u0RdLwDRRWvlWPAhm	Dash Test 810 Admin	org_admin	15	\N	\N	t	2026-08-10 17:14:10.330825+05:30	2026-08-10 17:14:07.861222+05:30	\N	\N	\N	\N	\N	0
38	demo	$2b$12$FSgZ1L9ugO99Dvk4mZAim.XodqVjcwmgzclBiFFcWtu8LMmqT.lay	demo Admin	org_admin	11	\N	\N	t	2026-08-10 17:44:58.976423+05:30	2026-08-10 16:40:13.099778+05:30	\N	\N	\N	\N	\N	0
45	cmo_3fe3ba	$2b$12$uZ29w.03o1aAuV7URMihwekRkNVNwhb1HB4BLRPrrAly8.cPR.NOy	Test CMO	cmo	1	\N	\N	t	2026-08-10 17:14:36.313494+05:30	2026-08-10 17:14:35.417349+05:30	\N	\N	\N	\N	\N	0
46	zon_3fe3ba	$2b$12$A8ZCLGacRFPMP6q9/AAEDOXSLRc2qaXzFCdYr1dXtmgPULuqkH2HW	Test Zonal	zonal_incharge	1	\N	\N	t	2026-08-10 17:14:36.708944+05:30	2026-08-10 17:14:35.891475+05:30	\N	\N	\N	\N	\N	0
179	t.nurse22	$2b$12$1cGdhhecHGTVndmz4F1N3.Cz7wTTZp4k4Hkm5PzU.4p4fVTHNB2he	Test Nurse 781	counsellor	1	\N	225	t	\N	2026-08-11 14:03:17.384597+05:30	\N	\N	\N	\N	\N	0
82	t.nurse6	$2b$12$PB5iZ8u5cI.qHSicRqYPFOXy2mPB0pHGxM5GwT7i0Q0t16LgyNaXq	Test Nurse 254	counsellor	1	\N	144	t	\N	2026-08-10 19:39:53.045492+05:30	\N	\N	\N	\N	\N	0
59	admin_d198	$2b$12$S3ktdm8qPsH2K6kPOBBSeuqIIRVrIAliLKgdY2bYo4wD8TgINU7RC	Dash Test 198 Admin	org_admin	23	\N	\N	t	2026-08-10 18:00:23.404595+05:30	2026-08-10 18:00:20.747394+05:30	\N	\N	\N	\N	\N	0
47	admin_d113	$2b$12$uGojTsBKYGZF1J893/Qy5e3jJSXIAdIGrWmOFQNBxR.H2Dm/85B52	Dash Test 113 Admin	org_admin	16	\N	\N	t	2026-08-10 17:15:02.230467+05:30	2026-08-10 17:14:58.249277+05:30	\N	\N	\N	\N	\N	0
60	t.nurse	$2b$12$RJQEOcytpiVnyiWT5NGThuqkGxZru2vN.3yXSkq4Ibub4Fm1kWoFm	Test Nurse 644	counsellor	1	\N	123	t	\N	2026-08-10 18:00:25.580493+05:30	\N	\N	\N	\N	\N	0
48	admin_d792	$2b$12$G3EqNBofh8jLa3aRqN22yOPkzxGZA6e1q1BEqraezx2YIhqbNxk4q	Dash Test 792 Admin	org_admin	17	\N	\N	t	2026-08-10 17:31:13.626156+05:30	2026-08-10 17:31:10.453759+05:30	\N	\N	\N	\N	\N	0
49	admin_d797	$2b$12$K7iz7Y812dZVB7PnQbGyheAnbXp9F17f5NjZ0KuPrAgbeMpTzPUPG	Dash Test 797 Admin	org_admin	18	\N	\N	t	2026-08-10 17:31:46.420634+05:30	2026-08-10 17:31:43.59525+05:30	\N	\N	\N	\N	\N	0
62	r.kumar2	$2b$12$eK48iK9NQPqSG4hnQIYFMeD3Pq9syoi6mO8OLFTqrwftyypTMa.JK	Rohit Kumar 1835	doctor	1	\N	125	t	2026-08-10 18:00:32.3843+05:30	2026-08-10 18:00:30.821275+05:30	\N	\N	\N	\N	\N	0
71	admin_d574	$2b$12$X8OdvTrODNVv6UKGzGmfdukbjiSSqSisdSmuH7FjDvkXg6UcM1OeK	Dash Test 574 Admin	org_admin	26	\N	\N	t	2026-08-10 19:16:47.161689+05:30	2026-08-10 19:16:44.372768+05:30	\N	\N	\N	\N	\N	0
50	admin_d421	$2b$12$u1tqm.tnaTKTyBqO7ap3AOMkleWvHJMDIpxziY9SpxDN3fBI1f9r6	Dash Test 421 Admin	org_admin	19	\N	\N	t	2026-08-10 17:35:11.267911+05:30	2026-08-10 17:35:06.947003+05:30	\N	\N	\N	\N	\N	0
61	r.kumar	$2b$12$bjNAVTqCGNeeAFt1gttq6.zsPWIsxUFAFB4e7BEd/aegOtcqh8d/K	Ravi Kumar 1835	counsellor	1	\N	124	t	2026-08-10 18:00:35.145649+05:30	2026-08-10 18:00:28.832493+05:30	\N	\N	\N	\N	\N	0
51	admin_d843	$2b$12$Qtk0Snqtc4WhhFRIZfJFUeloya1e85xp9CsQYhAwL/ge0t7t.9xfy	Dash Test 843 Admin	org_admin	20	\N	\N	t	2026-08-10 17:39:22.691171+05:30	2026-08-10 17:39:17.904567+05:30	\N	\N	\N	\N	\N	0
72	t.nurse4	$2b$12$s2/xmpQO.XlBxNX7BTr.yOMwELAbScamr8fRB.VvdCAEoSkkrOFni	Test Nurse 953	counsellor	1	\N	135	t	\N	2026-08-10 19:16:49.84612+05:30	\N	\N	\N	\N	\N	0
52	cmo_aa122f	$2b$12$i4kmoN8BTuXbgxUjYwkaueE77zUpPLZA2GzRX3/aAaQY45gDisFYq	Test CMO	cmo	1	\N	\N	t	2026-08-10 17:42:42.060356+05:30	2026-08-10 17:42:40.696039+05:30	\N	\N	\N	\N	\N	0
53	zon_aa122f	$2b$12$7UvqjFg41KqeIRGqiSr73.r0KDwwv4oHQMbosDJpTmun0cQ2V73B.	Test Zonal	zonal_incharge	1	\N	\N	t	2026-08-10 17:42:42.471564+05:30	2026-08-10 17:42:41.223121+05:30	\N	\N	\N	\N	\N	0
78	r.kumar10	$2b$12$ge3X0b7e4c5AJPqgelvv4uuTsXqy6ANgHZr/7/tJUJ6AtVq9xeBcO	Rohit Kumar 6089	doctor	1	\N	141	t	2026-08-10 19:36:07.98846+05:30	2026-08-10 19:36:06.932617+05:30	\N	\N	\N	\N	\N	0
63	admin_d623	$2b$12$QkUIYpaOLYOn/IKZLVBKNeM7ndtU4MDZKSlUO1QDWDMDdT0CBp0pu	Dash Test 623 Admin	org_admin	24	\N	\N	t	2026-08-10 18:00:46.28622+05:30	2026-08-10 18:00:43.44851+05:30	\N	\N	\N	\N	\N	0
54	admin_d885	$2b$12$5Of/H1R3SrFSgHgz9aZiJ.C//I8qn8lGJPTwOmOdkUN84UXbA1s/6	Dash Test 885 Admin	org_admin	21	\N	\N	t	2026-08-10 17:43:05.953376+05:30	2026-08-10 17:43:03.26788+05:30	\N	\N	\N	\N	\N	0
64	t.nurse2	$2b$12$pPidOhyVSwO1XPNqsbkWg.83dpmkkxqTfcBrvVk/XQHzEJrs7O66a	Test Nurse 251	counsellor	1	\N	127	t	\N	2026-08-10 18:00:48.30441+05:30	\N	\N	\N	\N	\N	0
55	admin_d201	$2b$12$HE0uan7RjmIjWyRcgCGwLOpvx1igBVzYoENEPorUnlv0elAnFzCXi	Dash Test 201 Admin	org_admin	22	\N	\N	t	2026-08-10 17:53:05.447258+05:30	2026-08-10 17:53:02.095128+05:30	\N	\N	\N	\N	\N	0
56	t.357	$2b$12$L/EM9XxWKaQO.bbhpKkMqONp2e5JX.Iug8EZmEPv4uZAscGoTxDFO	Test Nurse 357	counsellor	1	\N	119	t	\N	2026-08-10 17:53:08.182432+05:30	\N	\N	\N	\N	\N	0
58	r.13172	$2b$12$ql.tqeyyeU3GKESvSHzmouGSiuBpaSi3cdh/5WtCt7Q8Y0W7wTz8O	Rohit Kumar 1317	doctor	1	\N	121	t	2026-08-10 17:53:14.99798+05:30	2026-08-10 17:53:13.770441+05:30	\N	\N	\N	\N	\N	0
57	r.1317	$2b$12$poug.UHn4TQ0AZd.IzRki.Bwsy7SBPjTAMVSH0EtbOBE7zkbgzJ7e	Ravi Kumar 1317	counsellor	1	\N	120	t	2026-08-10 17:53:17.457239+05:30	2026-08-10 17:53:12.027839+05:30	\N	\N	\N	\N	\N	0
74	r.kumar8	$2b$12$tw0p7tYAaZBTIzepwXP6O.g.to8ftohcmSwpTV0PG6SI8S1sBRjBu	Rohit Kumar 8755	doctor	1	\N	137	t	2026-08-10 19:16:56.018118+05:30	2026-08-10 19:16:54.899639+05:30	\N	\N	\N	\N	\N	0
66	r.kumar4	$2b$12$FdULvfupJpNJmRijus6IAu7ovs1lS9BPit.5Q/4gSktNmNXM9BBlK	Rohit Kumar 8790	doctor	1	\N	129	t	2026-08-10 18:00:54.153498+05:30	2026-08-10 18:00:53.039166+05:30	\N	\N	\N	\N	\N	0
65	r.kumar3	$2b$12$P/OEO28JeNIC2OrlLaMiaOq69dlDuGsd.qz2L58krCkiA8eIpL4Ay	Ravi Kumar 8790	counsellor	1	\N	128	t	2026-08-10 18:00:56.314621+05:30	2026-08-10 18:00:51.582549+05:30	\N	\N	\N	\N	\N	0
73	r.kumar7	$2b$12$L0U3wG9bw98zSkrDucnNEuPoMb.tIzBfKgO4sGRHIvcOXcCGdp5ea	Ravi Kumar 8755	counsellor	1	\N	136	t	2026-08-10 19:16:58.0376+05:30	2026-08-10 19:16:53.402697+05:30	\N	\N	\N	\N	\N	0
67	admin_d914	$2b$12$e8f8YcT1tqV/j12/z6pnoOHySmx/Swe4Qc1sMUPWHI3ER6YOaaQCK	Dash Test 914 Admin	org_admin	25	\N	\N	t	2026-08-10 19:16:23.368653+05:30	2026-08-10 19:16:20.186717+05:30	\N	\N	\N	\N	\N	0
68	t.nurse3	$2b$12$OofC3Ae09N0Edrz0mWau.OyYGCsiT7cxya47M70c.JGUn4qXRXvGG	Test Nurse 177	counsellor	1	\N	131	t	\N	2026-08-10 19:16:26.003903+05:30	\N	\N	\N	\N	\N	0
70	r.kumar6	$2b$12$RZwC42AXc1XGyow/MieA7uvsQlsMUYqXGcjDXgrfpUwT5mkbJUck.	Rohit Kumar 3247	doctor	1	\N	133	t	2026-08-10 19:16:32.578118+05:30	2026-08-10 19:16:31.634567+05:30	\N	\N	\N	\N	\N	0
77	r.kumar9	$2b$12$3VMryvpDK57wWG1Zy/0nlOVD92IwVvO9A2PeoyJZF0T3tzgmQMeLu	Ravi Kumar 6089	counsellor	1	\N	140	t	2026-08-10 19:36:10.097673+05:30	2026-08-10 19:36:05.134975+05:30	\N	\N	\N	\N	\N	0
69	r.kumar5	$2b$12$fkLpEJumx4Q5xunUU90m0O9A8arcX1Ga5.LfYSV3Tm3RigKN3UqmO	Ravi Kumar 3247	counsellor	1	\N	132	t	2026-08-10 19:16:34.844218+05:30	2026-08-10 19:16:30.138735+05:30	\N	\N	\N	\N	\N	0
75	admin_d390	$2b$12$PSFF4w/dy1em6aKzRU3sTuwuatkEw9DUG8wc2Ga4.YdF6Gy91YK0.	Dash Test 390 Admin	org_admin	27	\N	\N	t	2026-08-10 19:35:57.281604+05:30	2026-08-10 19:35:54.03427+05:30	\N	\N	\N	\N	\N	0
76	t.nurse5	$2b$12$Bbi6Ubmnq/epIAHoCrrOQ.tN2QPiC71z68RNi58y47gCbejV7F4g2	Test Nurse 208	counsellor	1	\N	139	t	\N	2026-08-10 19:36:00.53519+05:30	\N	\N	\N	\N	\N	0
79	t.worker	$2b$12$gZRELT0TaRrUSF1ESaVwzO2ODlD1kkppS6mmz6UobDaYfQlyJlO5S	Temp Worker 9424	lab	1	\N	143	f	2026-08-10 19:36:17.871873+05:30	2026-08-10 19:36:13.649873+05:30	\N	\N	\N	\N	\N	0
80	admin_crud4544	$2b$12$HdpOvo/.p1uoK5ExxTz5cu4xISGIxx3F14Sf3lcLjSCL0MT9HnomG	CRUD Test 4544 Admin	org_admin	28	\N	\N	t	\N	2026-08-10 19:36:21.277312+05:30	\N	\N	\N	\N	\N	0
6	drv_ram	$2b$12$zMyVhu6thwnVZ7q3TYegfOBnrmJOMYPKcKJxrd4yYmKW11we./mXW	Ram Prasad	driver	1	\N	5	t	\N	2026-08-03 15:44:07.114211+05:30	\N	\N	\N	\N	\N	0
83	r.kumar11	$2b$12$ngXSd6XGFCg2WiWB89nZSOgyayNAIjHkcJMaZrM/MxmD79n2jnpx6	Ravi Kumar 8140	counsellor	1	\N	145	t	2026-08-10 19:40:02.356386+05:30	2026-08-10 19:39:57.403178+05:30	\N	\N	\N	\N	\N	0
84	r.kumar12	$2b$12$6YSdWoZNzNVpn9zFitupTe42kfE0ulbYEC8M5jTY8Ad2dxnVa7xKO	Rohit Kumar 8140	doctor	1	\N	146	t	2026-08-10 19:40:00.122036+05:30	2026-08-10 19:39:59.109521+05:30	\N	\N	\N	\N	\N	0
81	admin_d869	$2b$12$5S6Tk7j8VcRIUSkxYyiAb.k1pVxP.ZW81q4fLhpv0TjyjKAk6hLJe	Dash Test 869 Admin	org_admin	29	\N	\N	t	2026-08-10 19:39:50.197522+05:30	2026-08-10 19:39:46.448413+05:30	\N	\N	\N	\N	\N	0
85	t.worker2	$2b$12$CEXISWS6AjFACdCxXyClDueU0FH7Qxdbl1qUKkgIzseeL4eLm4yja	Temp Worker 9371	lab	1	\N	148	f	2026-08-10 19:40:10.180881+05:30	2026-08-10 19:40:05.88101+05:30	\N	\N	\N	\N	\N	0
86	admin_crud2242	$2b$12$iuc2w.1nazHSlyfvCxvcou4kT4BywnlQ8PfCcg9rVFBmdA0LXXFim	CRUD Test 2242 Admin	org_admin	30	\N	\N	f	2026-08-10 19:40:16.004445+05:30	2026-08-10 19:40:12.716837+05:30	\N	\N	\N	\N	\N	0
87	admin_d286	$2b$12$R2Ad/aCaaxbS/BbqXOBqDebaxvz0vxeMwAqzSpDt6/ZAXsnWOUNzS	Dash Test 286 Admin	org_admin	31	\N	\N	t	2026-08-10 19:41:18.703116+05:30	2026-08-10 19:41:15.783799+05:30	\N	\N	\N	\N	\N	0
88	t.nurse7	$2b$12$osBt3AbxPOysSTKJGJZ17OUTULUQ5WhTlsNQMNIIthSPlADNlfQHS	Test Nurse 457	counsellor	1	\N	149	t	\N	2026-08-10 19:41:21.098181+05:30	\N	\N	\N	\N	\N	0
89	r.kumar13	$2b$12$bbV9NoIYVbKZWPpOlr29Ee4glKBK/Xr8ovAtQPv5tZ28bnDIG0DwS	Ravi Kumar 2665	counsellor	1	\N	150	t	2026-08-10 19:41:29.289523+05:30	2026-08-10 19:41:24.923756+05:30	\N	\N	\N	\N	\N	0
180	r.kumar43	$2b$12$sZq9.pmZ6J9qcWrYZ/2hTOyIVpG4YCVRBtEoG4wGi2X2Apxoa5YqO	Ravi Kumar 7199	counsellor	1	\N	226	t	2026-08-11 14:03:23.399981+05:30	2026-08-11 14:03:19.888512+05:30	\N	\N	\N	\N	\N	0
112	t.nurse11	$2b$12$RKmvHQvHbrHcIYQBeTXBE.m6XRNRWtkntnabFMxeZtxSmYITpVw6u	Test Nurse 850	counsellor	1	\N	169	t	\N	2026-08-10 20:34:41.209188+05:30	\N	\N	\N	\N	\N	0
91	t.worker3	$2b$12$Ok8ZAhjkSaa5yw9GBq/HLuheTMKfnG0Ak5F7o3.zQ1Omm1kJ8nz7a	Temp Worker 7733	lab	1	\N	153	f	2026-08-10 19:41:35.915735+05:30	2026-08-10 19:41:32.625734+05:30	\N	\N	\N	\N	\N	0
131	r.kumar27	$2b$12$9khAWPVybmEx2.1fIJU6K.JtJKqWlcKJ5gbUFaNrM1aai6myUTcw.	Ravi Kumar 4313	counsellor	1	\N	185	t	2026-08-10 21:20:28.25065+05:30	2026-08-10 21:20:22.933932+05:30	\N	\N	\N	\N	\N	0
113	r.kumar21	$2b$12$y0ngdHpcK4snt/fNexiV/.OywZvdaX4.s6trMBiX3lwmYBl2uUBC.	Ravi Kumar 7610	counsellor	1	\N	170	t	2026-08-10 20:34:48.343873+05:30	2026-08-10 20:34:44.331186+05:30	\N	\N	\N	\N	\N	0
118	t.nurse12	$2b$12$ooJpt76JuTHzObl/VzQPyORE1m/UzT2x/1V2iVWNgYy1d28I79yRu	Test Nurse 630	counsellor	1	\N	174	t	\N	2026-08-10 20:47:47.19328+05:30	\N	\N	\N	\N	\N	0
183	admin_crud2955	$2b$12$3s4Z031SDwozZHh2FtozoOH6Q86LOtMIQKoIKjURsyB7AIK74qIIm	CRUD Test 2955 Admin	org_admin	62	\N	\N	f	2026-08-11 14:03:32.408471+05:30	2026-08-11 14:03:30.131169+05:30	\N	\N	\N	\N	\N	0
92	admin_crud1275	$2b$12$oLe.5XEVeTN4vs/0z53Vmeu9m5N3XcCD2pdmd3wlwFWhqfyrdhHN2	CRUD Test 1275 Admin	org_admin	32	\N	\N	f	2026-08-10 19:41:41.100001+05:30	2026-08-10 19:41:38.299979+05:30	\N	\N	\N	\N	\N	0
93	admin_d964	$2b$12$ltuqB16MD9nREg8saXDnAuXSmD3WPKyLx5qNvr6bsDAtI0tM7SAPa	Dash Test 964 Admin	org_admin	33	\N	\N	t	2026-08-10 19:41:58.523309+05:30	2026-08-10 19:41:55.257426+05:30	\N	\N	\N	\N	\N	0
94	t.nurse8	$2b$12$00zs4Wdr3vTF0F6TzxN8re1giaRGPeEVQQ4N0VXa7M7sH9AObwePO	Test Nurse 834	counsellor	1	\N	154	t	\N	2026-08-10 19:42:00.900416+05:30	\N	\N	\N	\N	\N	0
96	r.kumar16	$2b$12$CE17lm.GWRC3tIBss9JSjOa.wB8sElTdmxyeaQnX4IAfwrP95IjSe	Rohit Kumar 6432	doctor	1	\N	156	t	2026-08-10 19:42:07.020494+05:30	2026-08-10 19:42:05.961043+05:30	\N	\N	\N	\N	\N	0
184	admin_d148	$2b$12$L2xv8SsMDUaNzfpXKs/TxeDMAbjtD3Ek20NDzUx0hBp./46fJDASe	Dash Test 148 Admin	org_admin	63	\N	\N	t	2026-08-11 14:04:21.110493+05:30	2026-08-11 14:04:18.89064+05:30	\N	\N	\N	\N	\N	0
187	t.nurse24	$2b$12$/7Lr.lAuOYEPn0zXiEX6ruVtXPkKKmu2blOKOIjF0VTz7E0gbilWi	Test Nurse 827	counsellor	1	\N	231	t	\N	2026-08-11 14:04:42.405224+05:30	\N	\N	\N	\N	\N	0
121	t.worker8	$2b$12$YGvFsrEsp/MaFhoxHUCXyePSvdqdoF2y6vx.BZ868/QK5xkicsMZC	Temp Worker 1701	lab	1	\N	178	f	2026-08-10 20:48:00.763682+05:30	2026-08-10 20:47:57.26639+05:30	\N	\N	\N	\N	\N	0
134	admin_crud9285	$2b$12$VyHP8eULSCX9Xa/fFTFdTecrkWa4vJSgz7ZbXba5d.IUJm/oFe.bm	CRUD Test 9285 Admin	org_admin	46	\N	\N	f	2026-08-10 21:20:42.357768+05:30	2026-08-10 21:20:38.90918+05:30	\N	\N	\N	\N	\N	0
123	admin_d688	$2b$12$dWn7Y8q..jXei.BQgSxNZeam9O93KRoZ1V/bfW5QeDpfpjTqLijy2	Dash Test 688 Admin	org_admin	43	\N	\N	t	2026-08-10 21:13:52.895997+05:30	2026-08-10 21:13:46.917006+05:30	\N	\N	\N	\N	\N	0
136	t.nurse15	$2b$12$IETeb1GhUbhP9Cp.JlqQquILAImDlpXVyrHGMmZ9cNNzCaoe8HFMO	Test Nurse 292	counsellor	1	\N	189	t	\N	2026-08-10 21:38:29.02013+05:30	\N	\N	\N	\N	\N	0
126	r.kumar26	$2b$12$MzsWieSUQNvtStmazEg2qOaDmnxhnEnmuW/Yg2gHkj0zWDwVgbPUS	Rohit Kumar 6559	doctor	1	\N	181	t	2026-08-10 21:14:03.97414+05:30	2026-08-10 21:14:02.901957+05:30	\N	\N	\N	\N	\N	0
125	r.kumar25	$2b$12$Por8gGxHbTMcrUYGkcD58.ZVlim8Px7e0vxusmB64zagsVmB0sAEK	Ravi Kumar 6559	counsellor	1	\N	180	t	2026-08-10 21:14:05.962289+05:30	2026-08-10 21:14:00.956875+05:30	\N	\N	\N	\N	\N	0
138	r.kumar30	$2b$12$PDoLMF.rgIkUXrJL8SCm8O/tjFQIeMltqfSBTrvOSx5oV1tArOV8K	Rohit Kumar 1547	doctor	1	\N	191	t	2026-08-10 21:38:37.028394+05:30	2026-08-10 21:38:35.551814+05:30	\N	\N	\N	\N	\N	0
129	admin_d441	$2b$12$kHSRYt7HdOQpzk6yXfR5ne2ZccJrn.4H5RK/z7dIL817RzNTOfK1.	Dash Test 441 Admin	org_admin	45	\N	\N	t	2026-08-10 21:20:16.006642+05:30	2026-08-10 21:20:12.893808+05:30	\N	\N	\N	\N	\N	0
146	admin_crud1726	$2b$12$FhX2VcWIPm897LlpkpOjlO9kItm8l7YyVme3Sg3LSXYKfhEDPIGTa	CRUD Test 1726 Admin	org_admin	50	\N	\N	f	2026-08-10 21:49:23.784839+05:30	2026-08-10 21:49:20.631167+05:30	\N	\N	\N	\N	\N	0
132	r.kumar28	$2b$12$yfoRz/rEwZt6JGrFTHLU1uAuV4FjN3aAj4fYiaG1GgOmkYvnip/AK	Rohit Kumar 4313	doctor	1	\N	186	t	2026-08-10 21:20:25.526486+05:30	2026-08-10 21:20:24.523305+05:30	\N	\N	\N	\N	\N	0
148	t.nurse17	$2b$12$mQHm6T.Ajrb/820maE4OHeG04S/I8PYDJJvyLOcfJPpGCOe3JY//W	Test Nurse 893	counsellor	1	\N	199	t	\N	2026-08-11 09:30:21.206621+05:30	\N	\N	\N	\N	\N	0
140	admin_crud1459	$2b$12$SbNF7RxgYkDRXKKMsjOUD.pEeIcb04eRbLKnTYByRAJ0hnybZQOsG	CRUD Test 1459 Admin	org_admin	48	\N	\N	f	2026-08-10 21:38:56.786388+05:30	2026-08-10 21:38:53.170588+05:30	\N	\N	\N	\N	\N	0
142	t.nurse16	$2b$12$NXEtykYD16dzawRBqIvpr.5Xw0J1/dNPAxED9xeVOuLIE/OfBlB8K	Test Nurse 562	counsellor	1	\N	194	t	\N	2026-08-10 21:48:59.966187+05:30	\N	\N	\N	\N	\N	0
144	r.kumar32	$2b$12$f/1nju8CV9kzk1WgaOIr6.4VIBHarvx/5RdMl3Qdtx65kLGrHqKhK	Rohit Kumar 6249	doctor	1	\N	196	t	2026-08-10 21:49:08.172641+05:30	2026-08-10 21:49:06.954403+05:30	\N	\N	\N	\N	\N	0
152	admin_crud7243	$2b$12$JYoDCnRDHl7tfUvgrLgHDOgYASRIFPUdc1/VcN2hZ1cf.0QHc6SAy	CRUD Test 7243 Admin	org_admin	52	\N	\N	f	2026-08-11 09:30:42.462725+05:30	2026-08-11 09:30:40.021276+05:30	\N	\N	\N	\N	\N	0
151	t.worker13	$2b$12$8Isi2o8HfqjNT0ZQGOFskekFIov9qmvlJ7BOdnG2pEyAGLfysVw0C	Temp Worker 2378	lab	1	\N	203	f	2026-08-11 09:30:37.898809+05:30	2026-08-11 09:30:33.342506+05:30	\N	\N	\N	\N	\N	0
153	admin_d749	$2b$12$6Ef9BkKvUDR9Wp3n9o4mtuLIxE66L5sd4IEZUuTs6/0cXeW9j.dde	Dash Test 749 Admin	org_admin	53	\N	\N	t	2026-08-11 09:36:18.924015+05:30	2026-08-11 09:36:16.357+05:30	\N	\N	\N	\N	\N	0
159	admin_d806	$2b$12$XSriGp9HIuVONsQhV/Qmkee0WVENiPelV4k4oS43bNFzmcPNoq.eS	Dash Test 806 Admin	org_admin	55	\N	\N	t	2026-08-11 09:52:19.291738+05:30	2026-08-11 09:52:17.191376+05:30	\N	\N	\N	\N	\N	0
156	r.kumar36	$2b$12$z2oeL/DPTFEhc/.B6a0Mc.Puqvzb4O86FDdpf.wID0wtTPLWHo0oW	Rohit Kumar 2014	doctor	1	\N	206	t	2026-08-11 09:36:27.129436+05:30	2026-08-11 09:36:26.364665+05:30	\N	\N	\N	\N	\N	0
155	r.kumar35	$2b$12$3TgwA7Tg0O8FlPxejvBfn.SELOe3MqFn83iXWbyjHDCVWd0VV6WrS	Ravi Kumar 2014	counsellor	1	\N	205	t	2026-08-11 09:36:29.070143+05:30	2026-08-11 09:36:24.994538+05:30	\N	\N	\N	\N	\N	0
161	r.kumar37	$2b$12$bhkubfjk/IoVSWOsENPcDeSGDemAGtdYz8U9nJqTuCEx0uxuVr3Da	Ravi Kumar 6870	counsellor	1	\N	210	t	2026-08-11 09:52:27.729464+05:30	2026-08-11 09:52:23.96172+05:30	\N	\N	\N	\N	\N	0
163	t.worker15	$2b$12$vvCyKsgCcF91eXK17dBnK.X4znyzXO.KSZUgytmV.CIleLNd0UzG2	Temp Worker 1188	lab	1	\N	213	f	2026-08-11 09:52:34.344308+05:30	2026-08-11 09:52:30.487983+05:30	\N	\N	\N	\N	\N	0
166	admin_d617	$2b$12$TiMCB2J.qVevtvk08ZkSXufJoHvxjMAW5aTwRs7C6Yz/aDsAPPGo2	Dash Test 617 Admin	org_admin	57	\N	\N	t	2026-08-11 11:14:14.151768+05:30	2026-08-11 11:14:11.854487+05:30	\N	\N	\N	\N	\N	0
167	t.nurse20	$2b$12$kZ3w8KpdsecWAx5xhZsggeGy/y8V0qD.Hvyl9rJqpsStROEUlUDy2	Test Nurse 284	counsellor	1	\N	215	t	\N	2026-08-11 11:14:16.150759+05:30	\N	\N	\N	\N	\N	0
169	r.kumar40	$2b$12$wE6xhdsI/5NAeSzdc0m4peUvouhrufExEPw56L3casr8U1uawSf6e	Rohit Kumar 5738	doctor	1	\N	217	t	2026-08-11 11:14:21.065378+05:30	2026-08-11 11:14:20.346603+05:30	\N	\N	\N	\N	\N	0
168	r.kumar39	$2b$12$mjyX3Gh9458btcKjKZts3eOn3zPXyyV7uAKDTF0AnphyDxVt77c2y	Ravi Kumar 5738	counsellor	1	\N	216	t	2026-08-11 11:14:22.562983+05:30	2026-08-11 11:14:19.185686+05:30	\N	\N	\N	\N	\N	0
170	t.worker16	$2b$12$gvnN6p5fcwvlapu3XfdxJOA88HP3jSSZdIL39ovmBUYbKOjpLLsOi	Temp Worker 1539	lab	1	\N	219	f	2026-08-11 11:14:27.567319+05:30	2026-08-11 11:14:24.95331+05:30	\N	\N	\N	\N	\N	0
171	admin_crud9166	$2b$12$12odvEjC6XBnzqks03EUiOZKlzagb.nJfXwVNwivWUOL8XNMNajqC	CRUD Test 9166 Admin	org_admin	58	\N	\N	f	2026-08-11 11:14:31.668803+05:30	2026-08-11 11:14:29.413818+05:30	\N	\N	\N	\N	\N	0
172	admin_d514	$2b$12$DGCXuoEmwr0BoPq74gsHZO3EdBNhUEUkRKqQUNC42.yCFnVNUBjLu	Dash Test 514 Admin	org_admin	59	\N	\N	t	2026-08-11 13:59:32.801688+05:30	2026-08-11 13:59:30.519097+05:30	\N	\N	\N	\N	\N	0
173	t.nurse21	$2b$12$BNjUyAyuXhVGa6MfI9jepOG3nq1cyNmhfcVqLfbQ3B2AA8zMmFC12	Test Nurse 563	counsellor	1	\N	220	t	\N	2026-08-11 13:59:34.715348+05:30	\N	\N	\N	\N	\N	0
95	r.kumar15	$2b$12$5w4jxBhdjGvBazSUn/Tk1.gWQuqEp5fYjliG6o/T3sQ/vvD1vpLCa	Ravi Kumar 6432	counsellor	1	\N	155	t	2026-08-10 19:42:09.123398+05:30	2026-08-10 19:42:04.540253+05:30	\N	\N	\N	\N	\N	0
120	r.kumar24	$2b$12$67q4Jhjsz0G2NZWSHYfdJuaQoH1Px5wyatal3zEArl3vIw02yc0L2	Rohit Kumar 7160	doctor	1	\N	176	t	2026-08-10 20:47:52.580769+05:30	2026-08-10 20:47:51.75114+05:30	\N	\N	\N	\N	\N	0
143	r.kumar31	$2b$12$TWT57GWdKbhOO6lV.YZw5uFdGLLcFL8Zm9hguyFqiSaSAC19H.hCO	Ravi Kumar 6249	counsellor	1	\N	195	t	2026-08-10 21:49:10.871097+05:30	2026-08-10 21:49:04.893219+05:30	\N	\N	\N	\N	\N	0
111	admin_d961	$2b$12$1r2zHd6m0u5pQ4yDF9ydleNzqhQUlqww29oqqOr4k80tsWT4sx22u	Dash Test 961 Admin	org_admin	39	\N	\N	t	2026-08-10 20:34:38.326508+05:30	2026-08-10 20:34:35.728893+05:30	\N	\N	\N	\N	\N	0
105	admin_d527	$2b$12$7DORCGE4SM9XRXF3BuhjzO4Ze2.w29w3AfK/bXZiU018Ji3PiVE4y	Dash Test 527 Admin	org_admin	37	\N	\N	t	2026-08-10 20:22:58.411561+05:30	2026-08-10 20:22:54.772977+05:30	\N	\N	\N	\N	\N	0
106	t.nurse10	$2b$12$jZlNeBlZIwiQTuzqgxTkde5voT3H6RdIyL6mopKOl6KQSD68nJrLy	Test Nurse 306	counsellor	1	\N	164	t	\N	2026-08-10 20:23:00.872109+05:30	\N	\N	\N	\N	\N	0
97	t.worker4	$2b$12$l49Hl7y8RE4/.ZDEMkHDGundXGTeWVO3LXtwP5fvHeqmSezZOozNi	Temp Worker 9609	lab	1	\N	158	f	2026-08-10 19:42:15.919138+05:30	2026-08-10 19:42:12.53779+05:30	\N	\N	\N	\N	\N	0
114	r.kumar22	$2b$12$dDMtV4Tf2yp6TJ0Gd50Xa.5u1nFEB3zx0MTK0U8vsbLxu4rqx1T7m	Rohit Kumar 7610	doctor	1	\N	171	t	2026-08-10 20:34:46.563607+05:30	2026-08-10 20:34:45.728485+05:30	\N	\N	\N	\N	\N	0
119	r.kumar23	$2b$12$4GqZuytvw/rQwZuq5NSrwuFi8Mpue1Bea8VTJa1YcIp08QMc88qTe	Ravi Kumar 7160	counsellor	1	\N	175	t	2026-08-10 20:47:54.413155+05:30	2026-08-10 20:47:50.363608+05:30	\N	\N	\N	\N	\N	0
98	admin_crud8568	$2b$12$ZGkZiqXJgf9dEK0rAZIhpOzFRyesjTIuZDp/PPGVicoRIu8nDf.Hy	CRUD Test 8568 Admin	org_admin	34	\N	\N	f	2026-08-10 19:42:21.26443+05:30	2026-08-10 19:42:18.333341+05:30	\N	\N	\N	\N	\N	0
108	r.kumar20	$2b$12$YIz5wjyvU6BOoiN1xRB0nO4XpcBUv0FKXF15JfuMtkeBkcpAOfZae	Rohit Kumar 2255	doctor	1	\N	166	t	2026-08-10 20:23:07.431923+05:30	2026-08-10 20:23:06.461904+05:30	\N	\N	\N	\N	\N	0
99	admin_d355	$2b$12$yP8d6h0td2a5Vld9edLaX.DgY5stcj8e3u3Wz6uqlKoB6oHeR5LWW	Dash Test 355 Admin	org_admin	35	\N	\N	t	2026-08-10 20:19:03.023033+05:30	2026-08-10 20:19:00.451447+05:30	\N	\N	\N	\N	\N	0
100	t.nurse9	$2b$12$bHBfH1h1WSazv0gDrlzrtOdDagnvMXR3Thk19x5tBloP4euJTHFQy	Test Nurse 269	counsellor	1	\N	159	t	\N	2026-08-10 20:19:05.055891+05:30	\N	\N	\N	\N	\N	0
102	r.kumar18	$2b$12$239O6z2RbY6xefLuYs3HIOYqxmBP4vzSnxQ2zBNw.SDwpvnEItCRi	Rohit Kumar 2825	doctor	1	\N	161	t	2026-08-10 20:19:10.408391+05:30	2026-08-10 20:19:09.671944+05:30	\N	\N	\N	\N	\N	0
107	r.kumar19	$2b$12$BBaQAg6y5WMwAtaf4.0MAeseEtskIcqny7OzvTLFA8F0ns7WUzin6	Ravi Kumar 2255	counsellor	1	\N	165	t	2026-08-10 20:23:09.435259+05:30	2026-08-10 20:23:04.718696+05:30	\N	\N	\N	\N	\N	0
101	r.kumar17	$2b$12$8P6d/QUvihKLQwBFOEDOJuIHslnwOaSu45KYpDOzEvDtd78U8ENqi	Ravi Kumar 2825	counsellor	1	\N	160	t	2026-08-10 20:19:12.091932+05:30	2026-08-10 20:19:08.398786+05:30	\N	\N	\N	\N	\N	0
115	t.worker7	$2b$12$bxVDdIMVhnDCuij17F685OFezFhhWPYC2NIBAr19tP410PNPEUuSK	Temp Worker 2986	lab	1	\N	173	f	2026-08-10 20:34:54.693563+05:30	2026-08-10 20:34:51.19058+05:30	\N	\N	\N	\N	\N	0
103	t.worker5	$2b$12$IzToZyHGE.GSs7Z73wrb2.Fwt0pmJNS6vcHuMiiBWUkZ321vpm1rW	Temp Worker 2350	lab	1	\N	163	f	2026-08-10 20:19:18.015051+05:30	2026-08-10 20:19:14.753196+05:30	\N	\N	\N	\N	\N	0
116	admin_crud7978	$2b$12$pRP6c4dQV8p.IK8HLzm0v.0JtPasRY/ux9myPjsG9PZjTdWAQmEvm	CRUD Test 7978 Admin	org_admin	40	\N	\N	f	2026-08-10 20:34:59.164935+05:30	2026-08-10 20:34:56.719222+05:30	\N	\N	\N	\N	\N	0
122	admin_crud2129	$2b$12$Icu003QUpJEjuv9oNuE8oO4khEHYdV/bL1jrho1ZGzvMcrvVkPQbm	CRUD Test 2129 Admin	org_admin	42	\N	\N	f	2026-08-10 20:48:06.262718+05:30	2026-08-10 20:48:03.34152+05:30	\N	\N	\N	\N	\N	0
104	admin_crud3668	$2b$12$ugLwSEKmYTIGMIVpKw0YxuNUY9xbAezU2JedSnrK9iO2O6PORxXja	CRUD Test 3668 Admin	org_admin	36	\N	\N	f	2026-08-10 20:19:22.773638+05:30	2026-08-10 20:19:20.185583+05:30	\N	\N	\N	\N	\N	0
124	t.nurse13	$2b$12$jaCUDIdkPjnqgONhK9dheOQh61plrLO2bKghLj6LYM0Zxq4UGKq5G	Test Nurse 531	counsellor	1	\N	179	t	\N	2026-08-10 21:13:56.286573+05:30	\N	\N	\N	\N	\N	0
109	t.worker6	$2b$12$soRohLznU2qAyvez9AuVZuAJFJV7I89.13YeFnRVV.Op3apv78NmC	Temp Worker 6719	lab	1	\N	168	f	2026-08-10 20:23:17.469657+05:30	2026-08-10 20:23:13.360937+05:30	\N	\N	\N	\N	\N	0
117	admin_d142	$2b$12$wu7RaOUA.5HVaUQtS4d1Pebt.nXfwnjIQVxrYyqnyZHb9oAjmKd1G	Dash Test 142 Admin	org_admin	41	\N	\N	t	2026-08-10 20:47:44.955448+05:30	2026-08-10 20:47:42.076928+05:30	\N	\N	\N	\N	\N	0
110	admin_crud7298	$2b$12$dS/onmh1.WZZMXA3VSZFTOrEbKk1rHdrFCMyI7McIOWiTkNoeNciK	CRUD Test 7298 Admin	org_admin	38	\N	\N	f	2026-08-10 20:23:23.112622+05:30	2026-08-10 20:23:19.86681+05:30	\N	\N	\N	\N	\N	0
128	admin_crud5742	$2b$12$FlkQNDiJY9bujzr/s5Y7f.lfwoYrRmKq/c21oY5fXcpdjpeSRfc3y	CRUD Test 5742 Admin	org_admin	44	\N	\N	f	2026-08-10 21:14:26.63139+05:30	2026-08-10 21:14:21.53515+05:30	\N	\N	\N	\N	\N	0
130	t.nurse14	$2b$12$mT6TC1854g9Tw2bl6gcd.OqyAAJC.7fz0UOnESZiTxf/4LeqtW4yG	Test Nurse 214	counsellor	1	\N	184	t	\N	2026-08-10 21:20:18.90493+05:30	\N	\N	\N	\N	\N	0
135	admin_d816	$2b$12$maj6CXJ6VHsZrqllvvKcqOFLIFE4gR7trayejoxSdm18fe5kc7Mgi	Dash Test 816 Admin	org_admin	47	\N	\N	t	2026-08-10 21:38:26.178901+05:30	2026-08-10 21:38:18.91855+05:30	\N	\N	\N	\N	\N	0
127	t.worker9	$2b$12$Qb5b/WF35TLkSSb0Hzuz7uYhd9M5UPTSqtbhenKim5yD/q2K4XXBm	Temp Worker 3005	lab	1	\N	183	f	2026-08-10 21:14:16.206431+05:30	2026-08-10 21:14:09.383956+05:30	\N	\N	\N	\N	\N	0
139	t.worker11	$2b$12$YD1flKfwXsaYL1.HeJqJreNaBSTndLfu27DEJMSTvuzsaCO8uh19W	Temp Worker 4454	lab	1	\N	193	f	2026-08-10 21:38:50.381314+05:30	2026-08-10 21:38:45.595629+05:30	\N	\N	\N	\N	\N	0
133	t.worker10	$2b$12$B/m4tdv4qUU1hiqJPKI4qOcvgXhPoAKxEymvrzTbeRq1qfSSOz0R6	Temp Worker 6582	lab	1	\N	188	f	2026-08-10 21:20:36.010754+05:30	2026-08-10 21:20:31.801994+05:30	\N	\N	\N	\N	\N	0
137	r.kumar29	$2b$12$s7zSTgSfzpc3C2stPFtqMezeNzZE23KP/XgEeg4tTx0./SDNl92AO	Ravi Kumar 1547	counsellor	1	\N	190	t	2026-08-10 21:38:41.072924+05:30	2026-08-10 21:38:33.311784+05:30	\N	\N	\N	\N	\N	0
145	t.worker12	$2b$12$86q.bW7uxESbimuHNzZJjuC67KQwk5LY0iejyReH7HhZF.CJk2m0W	Temp Worker 9650	lab	1	\N	198	f	2026-08-10 21:49:18.2149+05:30	2026-08-10 21:49:14.162246+05:30	\N	\N	\N	\N	\N	0
141	admin_d157	$2b$12$29wz9AAY3xlqk5kH01mwaOVYDJo9s2t81ZpkBTm8wRTyteKY/rytm	Dash Test 157 Admin	org_admin	49	\N	\N	t	2026-08-10 21:48:56.947906+05:30	2026-08-10 21:48:53.232982+05:30	\N	\N	\N	\N	\N	0
150	r.kumar34	$2b$12$xYzA4WEB/xYdD2iTpJ/7euub9llhzTqaVjZ.B0OuQT2l9R/W0P5x2	Rohit Kumar 9753	doctor	1	\N	201	t	2026-08-11 09:30:28.069202+05:30	2026-08-11 09:30:26.995879+05:30	\N	\N	\N	\N	\N	0
147	admin_d462	$2b$12$PeRnKUFX45N4BWhEmMvfQedHshvjqjHjczguEBfQ8Wo8jgiavSEcy	Dash Test 462 Admin	org_admin	51	\N	\N	t	2026-08-11 09:30:18.277672+05:30	2026-08-11 09:30:15.510638+05:30	\N	\N	\N	\N	\N	0
149	r.kumar33	$2b$12$qWpCRM5vG2Liu/O0q1wsru5j/iWbNITlWUvJ5f.NqjGEOKl064afC	Ravi Kumar 9753	counsellor	1	\N	200	t	2026-08-11 09:30:30.368278+05:30	2026-08-11 09:30:25.638681+05:30	\N	\N	\N	\N	\N	0
154	t.nurse18	$2b$12$d0SexNJK4zPUrBDp4PCTZOp1wqpj/D0jDOZRwVh/MCoJOnJL4KUFO	Test Nurse 982	counsellor	1	\N	204	t	\N	2026-08-11 09:36:21.280715+05:30	\N	\N	\N	\N	\N	0
157	t.worker14	$2b$12$ZR4sid6vhXAas73nyHYqi.qFwcXQc7aJUveDuxCtFfMgixc0OR0X6	Temp Worker 5593	lab	1	\N	208	f	2026-08-11 09:36:35.261186+05:30	2026-08-11 09:36:31.960351+05:30	\N	\N	\N	\N	\N	0
160	t.nurse19	$2b$12$iYMIjS7YVVAKRUH30fNNjuNeEYIi.3ikUOv.CO5Kq/5P1UoH529XO	Test Nurse 320	counsellor	1	\N	209	t	\N	2026-08-11 09:52:21.460419+05:30	\N	\N	\N	\N	\N	0
158	admin_crud6889	$2b$12$qjh9UMcjffzR7gtFdj2tqOXFFuumbpB1Z8w/Pb/wS2LK.hnb6um3m	CRUD Test 6889 Admin	org_admin	54	\N	\N	f	2026-08-11 09:36:39.919882+05:30	2026-08-11 09:36:37.395252+05:30	\N	\N	\N	\N	\N	0
162	r.kumar38	$2b$12$bMa4gFrv4s.wXBnlZUHo1eWK7qUvBzbg8qCvuZ8eLBJkYxfuZRI8K	Rohit Kumar 6870	doctor	1	\N	211	t	2026-08-11 09:52:26.274599+05:30	2026-08-11 09:52:25.324722+05:30	\N	\N	\N	\N	\N	0
164	admin_crud1330	$2b$12$JRNRzhbd1YljhglvCSucxu/rcOQVVv6Ii.IHvsnbNiegBLu9MvMuu	CRUD Test 1330 Admin	org_admin	56	\N	\N	f	2026-08-11 09:52:39.477412+05:30	2026-08-11 09:52:36.631711+05:30	\N	\N	\N	\N	\N	0
175	r.kumar42	$2b$12$0K1FBJ3daNfrXkT9.KSYmegZNLElJTkrbMBMkVqDno3A0Udx2Iao6	Rohit Kumar 2820	doctor	1	\N	222	t	2026-08-11 13:59:39.948077+05:30	2026-08-11 13:59:39.164657+05:30	\N	\N	\N	\N	\N	0
191	admin_crud1906	$2b$12$ugaczWSiAwhQkubyM1sozuQNWTk8ltF03qOM4aCWKjuOaF9DJfG2a	CRUD Test 1906 Admin	org_admin	65	\N	\N	f	2026-08-11 14:04:58.134564+05:30	2026-08-11 14:04:56.054034+05:30	\N	\N	\N	\N	\N	0
174	r.kumar41	$2b$12$gNDp1U23VLbaoBVEUE4ZUu1FpEk4xYDOqM5zyac2tJf2v7YwXLTDO	Ravi Kumar 2820	counsellor	1	\N	221	t	2026-08-11 13:59:41.39558+05:30	2026-08-11 13:59:37.999694+05:30	\N	\N	\N	\N	\N	0
181	r.kumar44	$2b$12$uz2pi/TMC/qWU3wWGnQMH.xbsJfICjtNZV9A2USBcljqWz0HzTbzO	Rohit Kumar 7199	doctor	1	\N	227	t	2026-08-11 14:03:21.775436+05:30	2026-08-11 14:03:21.089048+05:30	\N	\N	\N	\N	\N	0
165	coun_test	$2b$12$hz1jBOhs/7rwKijrSGfnOecdCOwLNwr7En51H/LVjKoHdI.bv9jkm	Counsellor	counsellor	1	1	214	t	2026-08-11 10:44:25.4773+05:30	2026-08-11 10:43:42.049668+05:30	\N	\N	\N	\N	\N	0
202	t.worker21	$2b$12$yJBQcQGzVoXFBw5vdHeuju.TzaQ8I1UHesNxRzNudYtq9J/094Qby	Temp Worker 1238	lab	1	\N	245	f	2026-08-11 14:06:04.787809+05:30	2026-08-11 14:06:01.708349+05:30	\N	\N	\N	\N	\N	0
196	t.worker20	$2b$12$MwbVqlquyLAdFCaftvk7JOZ3QhbxJ3ED0.xUXfvkXaQo/0QjNEQry	Temp Worker 1263	lab	1	\N	240	f	2026-08-11 14:05:23.55614+05:30	2026-08-11 14:05:20.739088+05:30	\N	\N	\N	\N	\N	0
176	t.worker17	$2b$12$1eq861QuWLL6sInAp0AU0O03CAJBy/btX9egpcedwLaAHL9qtw6Fu	Temp Worker 5556	lab	1	\N	224	f	2026-08-11 13:59:46.49991+05:30	2026-08-11 13:59:43.624095+05:30	\N	\N	\N	\N	\N	0
185	t.nurse23	$2b$12$tq0xRHLRHHmh8./f0waSLedOqmDVvbjdmmP688as7dLqmVhYahHAm	Test Nurse 271	counsellor	1	\N	230	t	\N	2026-08-11 14:04:23.230805+05:30	\N	\N	\N	\N	\N	0
198	admin_d101	$2b$12$gh4bU0aTBbmVnqTn7OfZs.7Epvfl5MM7n5JGUWh/.payO9YefpftK	Dash Test 101 Admin	org_admin	68	\N	\N	t	2026-08-11 14:05:51.437254+05:30	2026-08-11 14:05:49.252945+05:30	\N	\N	\N	\N	\N	0
186	admin_d313	$2b$12$54cKMmCC7V0pc/ZHlrjuKOntPyaG/vTWDFgFbCNYny4MIHa.Fcobq	Dash Test 313 Admin	org_admin	64	\N	\N	t	2026-08-11 14:04:40.428959+05:30	2026-08-11 14:04:38.143495+05:30	\N	\N	\N	\N	\N	0
177	admin_crud1973	$2b$12$gzO14Z0rq.n3owZ/q.zcLekIips5o3AjatvTdxio18EI8Fn6eAs9G	CRUD Test 1973 Admin	org_admin	60	\N	\N	f	2026-08-11 13:59:50.363397+05:30	2026-08-11 13:59:48.301404+05:30	\N	\N	\N	\N	\N	0
90	r.kumar14	$2b$12$cfgHog.GasyQEB.LFmw0aewqYTdMq1hzurTb6RHW/5xtjV/xXfXAC	Rohit Kumar 2665	doctor	1	\N	151	t	2026-08-10 19:41:27.359576+05:30	2026-08-10 19:41:26.394045+05:30	\N	\N	\N	\N	\N	0
199	t.nurse26	$2b$12$J1IroaZCa8ESGGf.85k5SeuNyzP1vqDh4U/bykzaL50iEbqYN8JKS	Test Nurse 887	counsellor	1	\N	241	t	\N	2026-08-11 14:05:53.178037+05:30	\N	\N	\N	\N	\N	0
189	r.kumar46	$2b$12$C3mhAQNZJuaUu1HybrdHru7FQrRFEa/GfvLEu/Q18mAutUTNBLmZq	Rohit Kumar 4690	doctor	1	\N	233	t	2026-08-11 14:04:47.437666+05:30	2026-08-11 14:04:46.547321+05:30	\N	\N	\N	\N	\N	0
188	r.kumar45	$2b$12$bHwCxck0iIRVagjvnCoyVOIc.jyO9a2MSh.fWYT4M6oBXsDMQ2V5q	Ravi Kumar 4690	counsellor	1	\N	232	t	2026-08-11 14:04:49.03096+05:30	2026-08-11 14:04:45.359799+05:30	\N	\N	\N	\N	\N	0
190	t.worker19	$2b$12$BtfN.a3mrdI0NtTX4h2ICuqn0TCz4NXevG.OD24.ZMxXDzSAr0kIS	Temp Worker 9249	lab	1	\N	235	f	2026-08-11 14:04:54.409142+05:30	2026-08-11 14:04:51.438118+05:30	\N	\N	\N	\N	\N	0
192	admin_d504	$2b$12$OIX6sPtkalsQwhKUHmJ.zub4/7sy2NUBwL4uOuWLaJiiz9SSlw5qi	Dash Test 504 Admin	org_admin	66	\N	\N	t	2026-08-11 14:05:09.753868+05:30	2026-08-11 14:05:07.417607+05:30	\N	\N	\N	\N	\N	0
197	admin_crud3015	$2b$12$AnhiHz1unWDmX/QYi6BnXebKHcCVimn2EOMLgLQxKXUa40e5YHJgG	CRUD Test 3015 Admin	org_admin	67	\N	\N	f	2026-08-11 14:05:27.390761+05:30	2026-08-11 14:05:25.186346+05:30	\N	\N	\N	\N	\N	0
193	t.nurse25	$2b$12$beWNTkije9U3daFr9GMhuO0opkjyCJKw4FlBDx3XTsisKb76dEqN2	Test Nurse 457	counsellor	1	\N	236	t	\N	2026-08-11 14:05:11.824636+05:30	\N	\N	\N	\N	\N	0
201	r.kumar50	$2b$12$.L5GR6So9BKXFdVkD5hOpe9NicYDYQO.UWmzU7U3V44HVhn2jEUnq	Rohit Kumar 3776	doctor	1	\N	243	t	2026-08-11 14:05:57.792768+05:30	2026-08-11 14:05:56.935538+05:30	\N	\N	\N	\N	\N	0
195	r.kumar48	$2b$12$iZ/g9JcUV9BBEKztyDlSTOJLiCLpkEUcB0AA6A1YsJBYUy1F7pAN2	Rohit Kumar 9933	doctor	1	\N	238	t	2026-08-11 14:05:16.840429+05:30	2026-08-11 14:05:16.071565+05:30	\N	\N	\N	\N	\N	0
194	r.kumar47	$2b$12$5GSK8tcIS1JA9LZvK7/S2ekFwOgTEeBAL5JVhKfG8Wg4G/D72Tefe	Ravi Kumar 9933	counsellor	1	\N	237	t	2026-08-11 14:05:18.32704+05:30	2026-08-11 14:05:14.872879+05:30	\N	\N	\N	\N	\N	0
200	r.kumar49	$2b$12$HIcJ2IFGeeSF.M/ZmjnSVuAf2d2a1zda9WqR.hWct0U2XeXl5b5.6	Ravi Kumar 3776	counsellor	1	\N	242	t	2026-08-11 14:05:59.33093+05:30	2026-08-11 14:05:55.717608+05:30	\N	\N	\N	\N	\N	0
2	doc_test	$2b$12$RA.uAAJjliEyBTtX.b2Iwu44474DhRHrHPHr98Z6SdooSuo6Ma60y	Dr. Aakanksha Dua	doctor	1	1	2	t	2026-08-11 15:53:56.714937+05:30	2026-08-03 14:50:13.85991+05:30	\N	\N	\N	\N	\N	0
207	r.kumar52	$2b$12$SjEzEOFNXP2VVChPfTD.jukvBYTSJ4Wge3Fbo3iAOM93HSRUQTpQe	Rohit Kumar 1262	doctor	1	\N	248	t	2026-08-11 14:06:26.974986+05:30	2026-08-11 14:06:26.262163+05:30	\N	\N	\N	\N	\N	0
204	admin_d728	$2b$12$A.TokhStSPDOvLxZMvh7s.c4AWCLME4gqsHoyuVqOgLVF3CfL0nj.	Dash Test 728 Admin	org_admin	70	\N	\N	t	2026-08-11 14:06:20.538651+05:30	2026-08-11 14:06:18.292773+05:30	\N	\N	\N	\N	\N	0
203	admin_crud7448	$2b$12$uRG1Q.a7uLSwYHZEV/7/4Oi4.FiqxGDR21iasaCjd97EZYGGLfMsC	CRUD Test 7448 Admin	org_admin	69	\N	\N	f	2026-08-11 14:06:08.945126+05:30	2026-08-11 14:06:06.652131+05:30	\N	\N	\N	\N	\N	0
206	r.kumar51	$2b$12$PcCNdrd.RlwumyHseAZSVOV7mYHykiNR2wqv9YxIGbuCgTWAy4vFy	Ravi Kumar 1262	counsellor	1	\N	247	t	2026-08-11 14:06:28.540218+05:30	2026-08-11 14:06:25.10046+05:30	\N	\N	\N	\N	\N	0
205	t.nurse27	$2b$12$3KqTKbwMNcMOi35c9g6ZEezng5vQB.wc7A0PhO6EsaSdzyCq8zMZC	Test Nurse 928	counsellor	1	\N	246	t	\N	2026-08-11 14:06:22.297619+05:30	\N	\N	\N	\N	\N	0
208	t.worker22	$2b$12$Eg7z069xGu.zsc6OVRaF/.lKRinBii5quMFwLmrDRq1WlY5aeusSK	Temp Worker 3914	lab	1	\N	250	f	2026-08-11 14:06:33.834313+05:30	2026-08-11 14:06:30.888186+05:30	\N	\N	\N	\N	\N	0
212	r.kumar53	$2b$12$6.LdFPdlPJvhE.b3aj2lreYc97j8DDi7TSbQ4HdMTIw4KktM8mUYK	Ravi Kumar 3632	counsellor	1	\N	252	t	2026-08-11 14:06:58.499293+05:30	2026-08-11 14:06:55.095073+05:30	\N	\N	\N	\N	\N	0
209	admin_crud3793	$2b$12$eq/x.WiPF6YMydip6M8lqO9RkCnpue9QPVM4xSBKhRInQeablU/F6	CRUD Test 3793 Admin	org_admin	71	\N	\N	f	2026-08-11 14:06:38.176967+05:30	2026-08-11 14:06:35.802095+05:30	\N	\N	\N	\N	\N	0
210	admin_d468	$2b$12$aM4b.JTvrh2NEXhdMPraNuDtCG08RdyiR99Eb70SQtm.NfmeRyOI6	Dash Test 468 Admin	org_admin	72	\N	\N	t	2026-08-11 14:06:50.228859+05:30	2026-08-11 14:06:47.927227+05:30	\N	\N	\N	\N	\N	0
211	t.nurse28	$2b$12$2nPDNOscdUKTPjZTCj0R0OKhtM9WYs/oFyGfxiJ5b9l3fJna1ezqq	Test Nurse 312	counsellor	1	\N	251	t	\N	2026-08-11 14:06:52.07378+05:30	\N	\N	\N	\N	\N	0
213	r.kumar54	$2b$12$KKvtONMYEa2AEJIMSugXd.VQAZcbILeORTDXQWbjZHetuwDyLItq.	Rohit Kumar 3632	doctor	1	\N	253	t	2026-08-11 14:06:57.010342+05:30	2026-08-11 14:06:56.277889+05:30	\N	\N	\N	\N	\N	0
214	t.worker23	$2b$12$bY437IGBCWVci0I9ZJNA5eAQZu16F108rDRCog8ZNd41wlfJPZNxe	Temp Worker 5717	lab	1	\N	255	f	2026-08-11 14:07:04.306995+05:30	2026-08-11 14:07:00.79967+05:30	\N	\N	\N	\N	\N	0
215	admin_crud9584	$2b$12$43lA.Bz6kDWcAojYK1Jt3uxAmRIWAq7AgWzTkdiahhIuwZ2qcsbzG	CRUD Test 9584 Admin	org_admin	73	\N	\N	f	2026-08-11 14:07:09.171683+05:30	2026-08-11 14:07:06.427566+05:30	\N	\N	\N	\N	\N	0
246	t.worker26	$2b$12$w/YR6hlhtaGwFGx5zdRbuuhz0n8S0lshRBYhKee8RwahjIAwN.Nre	Temp Worker 5481	lab	1	\N	288	f	2026-08-11 14:31:33.428403+05:30	2026-08-11 14:31:30.25289+05:30	\N	\N	\N	\N	\N	0
248	admin_d978	$2b$12$0ScIwskNXSq.uYQ.Ol3yGeKp5dsvplClJOQEYyeLMyI3wp/oIYbhC	Dash Test 978 Admin	org_admin	106	\N	\N	t	2026-08-11 14:32:26.320346+05:30	2026-08-11 14:32:23.724137+05:30	\N	\N	\N	\N	\N	0
230	admin_d746	$2b$12$KGJrQJLDelqCf/vpsJVbU.qkYRmKpVzYgcVdVtUoep6b7FLjS9KFe	Dash Test 746 Admin	org_admin	100	\N	\N	t	2026-08-11 14:20:41.179365+05:30	2026-08-11 14:20:38.252777+05:30	\N	\N	\N	\N	\N	0
231	t.nurse29	$2b$12$u42xY0waJM0ZQCh3QHoUH.0FiLM1CnY4uYAO8sQIOqo7BI8OM/QdK	Test Nurse 395	counsellor	1	\N	274	t	\N	2026-08-11 14:20:44.030498+05:30	\N	\N	\N	\N	\N	0
233	r.kumar56	$2b$12$OMAW4eVTo0jwXZiIcH4sbe4fzrEE5SWmY4fpoWDsvGMDQJw.JSy8q	Rohit Kumar 7839	doctor	1	\N	276	t	2026-08-11 14:20:50.061588+05:30	2026-08-11 14:20:49.121618+05:30	\N	\N	\N	\N	\N	0
236	admin_d175	$2b$12$GiK3YzR5cLP1dtz72WLN1eb43NiOBeFr4JzYwet0M4xJanD2qdJ.y	Dash Test 175 Admin	org_admin	102	\N	\N	t	2026-08-11 14:26:35.60189+05:30	2026-08-11 14:26:32.973217+05:30	\N	\N	\N	\N	\N	0
232	r.kumar55	$2b$12$THFasDN9ba8aZ0UflZOPwenO0ulvSYRQGGi2HLi5Y6JcfHxBiZp8q	Ravi Kumar 7839	counsellor	1	\N	275	t	2026-08-11 14:20:52.113809+05:30	2026-08-11 14:20:47.518129+05:30	\N	\N	\N	\N	\N	0
237	t.nurse30	$2b$12$j0TLzXLtn55cWgi4vIVicu6awTAjs/8DbY1FceBT7yOSexEY.SJpK	Test Nurse 456	counsellor	1	\N	279	t	\N	2026-08-11 14:26:37.885144+05:30	\N	\N	\N	\N	\N	0
239	r.kumar58	$2b$12$5coJzS.rMZiGLRfABkhHSOzHzWNBOdZ9p2syyLhMahj03hl03PSFy	Rohit Kumar 1300	doctor	1	\N	281	t	2026-08-11 14:26:44.407639+05:30	2026-08-11 14:26:43.285779+05:30	\N	\N	\N	\N	\N	0
234	t.worker24	$2b$12$Ag9xuN/y4CW1bRoUButytON2qpKcwIEOR9WAtuXuJUcgZGHmkFZYe	Temp Worker 8389	lab	1	\N	278	f	2026-08-11 14:20:58.642013+05:30	2026-08-11 14:20:55.063926+05:30	\N	\N	\N	\N	\N	0
249	t.nurse32	$2b$12$pjdMCmW54gQD9WcMSDZY6.nqk1FACUsHhZ8vw05NeKYT2n2.5WfZS	Test Nurse 649	counsellor	1	\N	289	t	\N	2026-08-11 14:32:28.565966+05:30	\N	\N	\N	\N	\N	0
238	r.kumar57	$2b$12$tNHyBdnHfJALpa7t66oqxeUdc9LFhboy55eQ/0pyIEQspVVama9Pm	Ravi Kumar 1300	counsellor	1	\N	280	t	2026-08-11 14:26:46.314782+05:30	2026-08-11 14:26:41.791244+05:30	\N	\N	\N	\N	\N	0
235	admin_crud4486	$2b$12$xtHZZPtgplRhak.OtXTZ2eClbQg1rCc1eqVv0Lt4FUbntvMv72bHO	CRUD Test 4486 Admin	org_admin	101	\N	\N	f	2026-08-11 14:21:03.738006+05:30	2026-08-11 14:21:01.023711+05:30	\N	\N	\N	\N	\N	0
247	admin_crud7810	$2b$12$aNdlnmiC2vksSGRnKTz2ie3pG90of8Z55Y/KU/40iLRcXiFdzzuT.	CRUD Test 7810 Admin	org_admin	105	\N	\N	f	2026-08-11 14:31:38.00442+05:30	2026-08-11 14:31:35.423547+05:30	\N	\N	\N	\N	\N	0
256	r.kumar63	$2b$12$T8jv12o9VydfBw.ucWnj4uqoQz/hQYkwa456/FrTBDWOiysL7P6YW	Ravi Kumar 7509	counsellor	1	\N	295	t	2026-08-11 15:10:19.156946+05:30	2026-08-11 15:10:15.258602+05:30	\N	\N	\N	\N	\N	0
242	admin_d439	$2b$12$Ygexk0yCbMyKEx.L7EMWIu/rW2xhElnQ8KgCUmo2Jn4bAv5q3IJAu	Dash Test 439 Admin	org_admin	104	\N	\N	t	2026-08-11 14:31:17.920682+05:30	2026-08-11 14:31:15.487908+05:30	\N	\N	\N	\N	\N	0
243	t.nurse31	$2b$12$dM6cuyUB490IfD2Oiegeg.u3yQBUjXNuz.RrqG6UXI8QgTkuOiW7q	Test Nurse 356	counsellor	1	\N	284	t	\N	2026-08-11 14:31:20.01339+05:30	\N	\N	\N	\N	\N	0
240	t.worker25	$2b$12$j0EkdSH5bpMUeK6lO5YxfeFxAdreRg18R0RpATi9bBIWMgkFd3rqq	Temp Worker 3702	lab	1	\N	283	f	2026-08-11 14:26:52.344266+05:30	2026-08-11 14:26:49.107694+05:30	\N	\N	\N	\N	\N	0
241	admin_crud4325	$2b$12$zObomqD0sOcWBpcUAc1wCeOmu.Yb.NRL0DA9sgsWsNcr8wcjh7csW	CRUD Test 4325 Admin	org_admin	103	\N	\N	f	2026-08-11 14:26:56.672477+05:30	2026-08-11 14:26:54.368128+05:30	\N	\N	\N	\N	\N	0
245	r.kumar60	$2b$12$fXjUiJ4GFoZK0rUi4x6be.9QtTFCSt80i9GySNsU.U03X1a9Vbblq	Rohit Kumar 4850	doctor	1	\N	286	t	2026-08-11 14:31:25.580824+05:30	2026-08-11 14:31:24.568622+05:30	\N	\N	\N	\N	\N	0
251	r.kumar62	$2b$12$Rd3J7IHwNCWTtpioZ225cext2ZPovHdGRNbQRgKGLO0Ywl5jt5FrG	Rohit Kumar 9027	doctor	1	\N	291	t	2026-08-11 14:32:33.838994+05:30	2026-08-11 14:32:33.074099+05:30	\N	\N	\N	\N	\N	0
244	r.kumar59	$2b$12$h5c/T41ZtsclNPTYw5LVy.xTqR0rGQwnk2Ku6miUVcIhuvIfr1eSC	Ravi Kumar 4850	counsellor	1	\N	285	t	2026-08-11 14:31:27.395193+05:30	2026-08-11 14:31:23.159893+05:30	\N	\N	\N	\N	\N	0
250	r.kumar61	$2b$12$aVk/gazmIg406t1nGiUAZeWym1Q9Y0J4UTUupH9HJc5wDzxxXSTwi	Ravi Kumar 9027	counsellor	1	\N	290	t	2026-08-11 14:32:35.548359+05:30	2026-08-11 14:32:31.707113+05:30	\N	\N	\N	\N	\N	0
258	t.worker28	$2b$12$koBGadRVrS3SL.s6Dr0JM.EXP1Siu.d1PY6WUOFbavpHGfy6xQxVa	Temp Worker 4935	lab	1	\N	298	f	2026-08-11 15:10:24.775858+05:30	2026-08-11 15:10:21.690387+05:30	\N	\N	\N	\N	\N	0
253	admin_crud5007	$2b$12$H0HnpT.PHYj.zECXyUKOm.YnBqAIGLAeseuNr8mCKRjqyITrYFXBC	CRUD Test 5007 Admin	org_admin	107	\N	\N	f	2026-08-11 14:32:45.795103+05:30	2026-08-11 14:32:43.162214+05:30	\N	\N	\N	\N	\N	0
4	lab_test	$2b$12$4kOBlW8p7358CpQDOrFayOQTx05ploqXeoPXmawm79VI9Hmuwt2ES	Anil Yadav	lab	1	1	4	t	2026-08-10 18:31:58.84941+05:30	2026-08-03 14:50:13.85991+05:30	\N	\N	\N	\N	\N	0
252	t.worker27	$2b$12$ZdhWz9y6t8HvnkNIEGgTG.hq3O6c.QNM3HSinWkmyxGj2IyjDsCQG	Temp Worker 5923	lab	1	\N	293	f	2026-08-11 14:32:41.178036+05:30	2026-08-11 14:32:38.213456+05:30	\N	\N	\N	\N	\N	0
254	admin_d921	$2b$12$et.lPERJlmypghGLFLkAz.xM0v7D2xJIGnatsx8lo69RFwuEi1EUK	Dash Test 921 Admin	org_admin	108	\N	\N	t	2026-08-11 15:10:10.329674+05:30	2026-08-11 15:10:07.78149+05:30	\N	\N	\N	\N	\N	0
255	t.nurse33	$2b$12$AoH0mHQpx8kNk380sP8qV.CldTNGO7Vsaw5eWOPEjX1eLwgGgkR6e	Test Nurse 662	counsellor	1	\N	294	t	\N	2026-08-11 15:10:12.345259+05:30	\N	\N	\N	\N	\N	0
257	r.kumar64	$2b$12$mCx8BRPLSrz4D5eHhVZ4quOVUpGSLGmDP1U07nrddHGEaqW0wz2sm	Rohit Kumar 7509	doctor	1	\N	296	t	2026-08-11 15:10:17.493772+05:30	2026-08-11 15:10:16.708194+05:30	\N	\N	\N	\N	\N	0
262	r.kumar65	$2b$12$UruBm0Jikh7ht2wWrQix3OafCJb1G6OuEmNs2K/i3cdBuQ/aHnIFu	Ravi Kumar 9073	counsellor	1	\N	300	t	2026-08-11 15:54:14.453701+05:30	2026-08-11 15:54:10.775258+05:30	\N	\N	\N	\N	\N	0
259	admin_crud5980	$2b$12$FJSOQEI9UQzXBlIIQXrRh.6Q9kQOeCM9Qwrpzt5B2XhiTtLVM2c/G	CRUD Test 5980 Admin	org_admin	109	\N	\N	f	2026-08-11 15:10:28.987447+05:30	2026-08-11 15:10:26.604541+05:30	\N	\N	\N	\N	\N	0
260	admin_d176	$2b$12$0.A9u1WonOnFA0KrJbrpLe4/grkhVqVnFlIhxotQC6hrhDSma00uu	Dash Test 176 Admin	org_admin	110	\N	\N	t	2026-08-11 15:54:05.843234+05:30	2026-08-11 15:54:03.574301+05:30	\N	\N	\N	\N	\N	0
261	t.nurse34	$2b$12$A8a4Qu5uwcQRxL19tSVPfe/a2PGRSF3at4vCMgaB9QmNwRwdy3YNm	Test Nurse 976	counsellor	1	\N	299	t	\N	2026-08-11 15:54:07.814497+05:30	\N	\N	\N	\N	\N	0
263	r.kumar66	$2b$12$DvfF2BGqx67kxSPttAgovOBtihJF2OQQIpiefNj0YDDuCuitAmbbK	Rohit Kumar 9073	doctor	1	\N	301	t	2026-08-11 15:54:12.828435+05:30	2026-08-11 15:54:12.049981+05:30	\N	\N	\N	\N	\N	0
264	t.worker29	$2b$12$Sfkpp/VBEN8HViVLMUW8aukgPIDHuQvX.b6u7cTUfiiKSPH9wrAxa	Temp Worker 5516	lab	1	\N	303	f	2026-08-11 15:54:20.116621+05:30	2026-08-11 15:54:16.932526+05:30	\N	\N	\N	\N	\N	0
1	con_test	$2b$12$hwc5mGPtQQ6ZXspvUD61UOKB7XqNMfSaN.j879kvXSVdQXtGm/eiq	Sanjeev Mahto	counsellor	1	1	1	t	2026-08-12 10:15:07.622516+05:30	2026-08-03 14:50:13.85991+05:30	\N	\N	\N	\N	\N	13
265	admin_crud2212	$2b$12$FVJ902dz9foeiJPLt2PXrOmjSO/vFzKTKzkrVh1T5CKhFl6KVZv0O	CRUD Test 2212 Admin	org_admin	111	\N	\N	f	2026-08-11 15:54:24.867591+05:30	2026-08-11 15:54:22.073887+05:30	\N	\N	\N	\N	\N	0
\.


--
-- TOC entry 5904 (class 0 OID 30969)
-- Dependencies: 265
-- Data for Name: appointment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointment (appointment_id, patient_id, facility_id, org_id, source, appointment_date, status, registered_by, attended_by, lab_by, dispensed_by, assigned_doctor_id, taken_prescribed_medicine, pregnant, lmp_date, edd_date, counsellor_remarks, height, weight, systolic_bp, diastolic_bp, blood_sugar, body_temp, oxygen, hemoglobin, observation, doctor_remarks, follow_up_date, follow_up_done, referred, referral_destination_id, counselled, counselling_topic_id, lab_report_date, payment_type, paid_amount, delivery_status, denial_reason, lama_at, created_at, updated_at, deleted_at, deleted_by, delete_reason, legacy_id, legacy_source, fee_collected_at, fee_collected_by, test_payment_total, test_paid_at, test_paid_by, parent_appointment_id) FROM stdin;
64	65	1	1	mmu	2026-08-10	with_pharma	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:18:59.519689+05:30	2026-08-10 18:19:00.128613+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
1	1	1	1	mmu	2026-08-03	completed	1	2	\N	3	\N	f	f	\N	\N	weakness 3 days	\N	\N	148	95	\N	99.4	97.0	11.2	Throat congested	Rest and fluids	\N	f	f	\N	f	\N	\N	Paid	20.00	accept	\N	\N	2026-08-03 14:56:14.188967+05:30	2026-08-03 15:14:55.981538+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
2	3	1	1	mmu	2026-08-03	registered	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	135	88	\N	\N	\N	13.5			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-03 15:56:38.258945+05:30	2026-08-03 15:56:38.258945+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
3	4	1	1	mmu	2026-08-03	registered	1	\N	\N	\N	\N	f	t	2026-05-01	\N	weakness since 3 days	158.50	52.40	118	76	94	98.6	98.0	10.8			\N	f	f	\N	f	\N	\N	Paid	10.00	NA	\N	\N	2026-08-03 16:16:59.222928+05:30	2026-08-03 16:16:59.222928+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
4	5	1	1	mmu	2026-08-09	registered	1	\N	\N	\N	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-09 22:46:48.887313+05:30	2026-08-09 22:46:48.986648+05:30	\N	\N	\N	\N	\N	2026-08-09 22:46:48.986648+05:30	1	0.00	\N	\N	\N
66	67	1	1	mmu	2026-08-10	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:21:29.775811+05:30	2026-08-10 18:21:30.406394+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
5	6	1	1	mmu	2026-08-09	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N	Febrile, no rash	Fluids, review if platelets drop	2026-08-16	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-09 22:48:25.730239+05:30	2026-08-09 22:48:26.012835+05:30	\N	\N	\N	\N	\N	2026-08-09 22:48:25.879067+05:30	1	0.00	\N	\N	\N
68	69	1	1	mmu	2026-08-10	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:22:07.731863+05:30	2026-08-10 18:22:08.33214+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
72	73	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:22:17.664117+05:30	2026-08-10 18:22:17.664117+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
77	78	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:23:40.588714+05:30	2026-08-10 18:23:40.588714+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
79	80	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:23:41.208511+05:30	2026-08-10 18:23:41.208511+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
80	81	1	1	mmu	2026-08-10	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:23:41.554502+05:30	2026-08-10 18:23:42.199693+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
6	7	1	1	mmu	2026-08-09	completed	1	2	4	3	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N	Platelets stable		\N	f	f	\N	f	\N	2026-08-09	Paid	50.00	accept	\N	\N	2026-08-09 22:50:01.388164+05:30	2026-08-09 22:50:03.110126+05:30	\N	\N	\N	\N	\N	2026-08-09 22:50:01.517456+05:30	1	210.00	2026-08-09 22:50:02.104207+05:30	1	\N
81	82	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:23:42.816993+05:30	2026-08-10 18:23:42.816993+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
8	9	1	1	mmu	2026-08-09	completed	1	2	4	3	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	2026-08-09	Paid	50.00	accept	\N	\N	2026-08-09 22:52:30.937147+05:30	2026-08-09 22:52:32.936211+05:30	\N	\N	\N	\N	\N	2026-08-09 22:52:31.060343+05:30	1	210.00	2026-08-09 22:52:31.682405+05:30	1	\N
7	8	1	1	mmu	2026-08-09	with_doctor	1	2	4	\N	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N	Febrile, no rash	Fluids, review if platelets drop	2026-08-16	f	f	\N	f	\N	2026-08-09	Paid	50.00	NA	\N	\N	2026-08-09 22:51:23.598184+05:30	2026-08-09 22:51:25.194325+05:30	\N	\N	\N	\N	\N	2026-08-09 22:51:23.699687+05:30	1	210.00	2026-08-09 22:51:24.517163+05:30	1	\N
83	84	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:24:06.690413+05:30	2026-08-10 18:24:08.120441+05:30	\N	\N	\N	\N	\N	\N	\N	250.00	2026-08-10 18:24:08.120441+05:30	1	\N
85	86	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:24:08.755176+05:30	2026-08-10 18:24:08.755176+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
86	87	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:24:09.22509+05:30	2026-08-10 18:24:09.22509+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
87	88	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:24:09.533889+05:30	2026-08-10 18:24:09.533889+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
82	83	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:24:05.135799+05:30	2026-08-10 18:24:11.741441+05:30	\N	\N	\N	\N	\N	\N	\N	300.00	2026-08-10 18:24:11.741441+05:30	1	\N
91	92	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:26:58.79999+05:30	2026-08-10 18:27:00.668642+05:30	\N	\N	\N	\N	\N	\N	\N	250.00	2026-08-10 18:27:00.668642+05:30	1	\N
92	93	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:27:01.208644+05:30	2026-08-10 18:27:01.208644+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
9	10	1	1	mmu	2026-08-09	completed	1	2	4	3	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	2026-08-09	Paid	50.00	accept	\N	\N	2026-08-09 22:52:53.060326+05:30	2026-08-09 22:52:55.121159+05:30	\N	\N	\N	\N	\N	2026-08-09 22:52:53.469197+05:30	1	210.00	2026-08-09 22:52:53.963142+05:30	1	\N
10	11	1	1	mmu	2026-08-09	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-09 23:02:00.191897+05:30	2026-08-09 23:02:00.191897+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
11	12	1	1	mmu	2026-08-09	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-09 23:04:04.932963+05:30	2026-08-09 23:04:04.932963+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
12	13	1	1	mmu	2026-08-09	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-09 23:16:51.471978+05:30	2026-08-09 23:16:51.471978+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
93	94	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:27:01.699531+05:30	2026-08-10 18:27:01.699531+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
13	14	1	1	mmu	2026-08-09	completed	1	2	4	3	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	2026-08-09	Paid	50.00	accept	\N	\N	2026-08-09 23:17:04.067743+05:30	2026-08-09 23:17:06.637613+05:30	\N	\N	\N	\N	\N	2026-08-09 23:17:04.222586+05:30	1	210.00	2026-08-09 23:17:04.903458+05:30	1	\N
20	21	1	1	mmu	2026-08-09	completed	1	2	4	3	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	2026-08-09	Paid	50.00	accept	\N	\N	2026-08-09 23:40:29.213787+05:30	2026-08-09 23:40:30.929799+05:30	\N	\N	\N	\N	\N	2026-08-09 23:40:29.322919+05:30	1	210.00	2026-08-09 23:40:29.930998+05:30	1	\N
14	15	1	1	mmu	2026-08-09	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-09 23:36:58.670198+05:30	2026-08-09 23:36:58.670198+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
15	16	1	1	mmu	2026-08-09	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-09 23:37:31.561067+05:30	2026-08-09 23:37:31.561067+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
16	17	1	1	mmu	2026-08-09	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-09 23:37:59.540218+05:30	2026-08-09 23:37:59.540218+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
17	18	1	1	mmu	2026-08-09	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-09 23:38:53.900196+05:30	2026-08-09 23:38:53.900196+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
18	19	1	1	mmu	2026-08-09	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-09 23:39:56.104822+05:30	2026-08-09 23:39:56.104822+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
19	20	1	1	mmu	2026-08-09	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-09 23:40:15.823758+05:30	2026-08-09 23:40:15.823758+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
21	22	1	1	mmu	2026-08-09	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-09 23:54:33.087144+05:30	2026-08-09 23:54:33.087144+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
22	23	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	Dolorem tempore dui	\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 00:06:21.903089+05:30	2026-08-10 00:06:21.903089+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
23	24	1	1	mmu	2026-08-10	completed	1	2	4	3	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	2026-08-10	Paid	50.00	accept	\N	\N	2026-08-10 11:09:23.986017+05:30	2026-08-10 11:09:25.778236+05:30	\N	\N	\N	\N	\N	2026-08-10 11:09:24.089918+05:30	1	210.00	2026-08-10 11:09:24.539154+05:30	1	\N
24	25	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 11:09:54.275303+05:30	2026-08-10 11:09:54.275303+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
65	66	1	1	mmu	2026-08-10	with_pharma	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:20:03.94709+05:30	2026-08-10 18:20:04.746101+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
67	68	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:21:31.60629+05:30	2026-08-10 18:21:33.10561+05:30	\N	\N	\N	\N	\N	\N	\N	250.00	2026-08-10 18:21:33.10561+05:30	1	\N
36	37	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	105	80	\N	97.2	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
37	38	9	1	static_clinic	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	122	90	\N	97.2	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
38	39	10	1	static_clinic	2026-08-08	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N	Fever three days	\N	\N	135	74	\N	99.1	\N	\N	Stable, no acute distress		\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
69	70	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:22:09.789816+05:30	2026-08-10 18:22:11.354336+05:30	\N	\N	\N	\N	\N	\N	\N	250.00	2026-08-10 18:22:11.354336+05:30	1	\N
39	40	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	113	83	\N	101.4	\N	\N	Stable, no acute distress		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	\N	\N	150.00	2026-08-10 11:23:29.404891+05:30	1	\N
70	71	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:22:16.754361+05:30	2026-08-10 18:22:16.754361+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
40	41	9	1	static_clinic	2026-08-10	with_pharma	1	2	\N	\N	\N	f	f	\N	\N	Fever three days	\N	\N	124	88	\N	99.1	\N	\N	Stable, no acute distress		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	\N	\N	1100.00	2026-08-10 11:23:29.404891+05:30	1	\N
71	72	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:22:17.342772+05:30	2026-08-10 18:22:17.342772+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
73	74	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:22:18.049364+05:30	2026-08-10 18:22:18.049364+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
41	42	10	1	static_clinic	2026-08-08	completed	1	2	\N	1	\N	f	f	\N	\N	Cough and cold	\N	\N	130	85	\N	99.0	\N	\N	Stable, no acute distress		\N	f	f	\N	f	\N	\N	Paid	50.00	accept	\N	\N	2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	\N	\N	150.00	2026-08-10 11:23:29.404891+05:30	1	\N
42	43	1	1	mmu	2026-08-08	completed	1	2	\N	1	\N	f	f	\N	\N	Cough and cold	\N	\N	141	91	\N	98.3	\N	\N	Stable, no acute distress		\N	f	f	\N	f	\N	\N	Free	0.00	accept	\N	\N	2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	\N	\N	300.00	2026-08-10 11:23:29.404891+05:30	1	\N
43	44	9	1	static_clinic	2026-08-07	lama	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	131	93	\N	98.5	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	2026-08-08 11:23:29.538757+05:30	2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
44	45	10	1	static_clinic	2026-08-04	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	128	79	\N	97.5	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
45	46	1	1	mmu	2026-08-04	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	112	85	\N	98.2	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
46	47	9	1	static_clinic	2026-08-04	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N	Cough and cold	\N	\N	115	74	\N	100.9	\N	\N	Stable, no acute distress		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
47	48	10	1	static_clinic	2026-08-04	with_lab	1	2	\N	\N	\N	f	f	\N	\N	Fever three days	\N	\N	132	79	\N	97.5	\N	\N	Stable, no acute distress		\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	\N	\N	150.00	2026-08-10 11:23:29.404891+05:30	1	\N
75	76	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:23:38.620922+05:30	2026-08-10 18:23:39.920531+05:30	\N	\N	\N	\N	\N	\N	\N	250.00	2026-08-10 18:23:39.920531+05:30	1	\N
76	77	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:23:40.273302+05:30	2026-08-10 18:23:40.273302+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
78	79	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:23:40.920188+05:30	2026-08-10 18:23:40.920188+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
48	49	1	1	mmu	2026-08-10	completed	1	2	4	3	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	2026-08-10	Paid	50.00	accept	\N	\N	2026-08-10 11:41:59.465638+05:30	2026-08-10 11:42:00.910858+05:30	\N	\N	\N	\N	\N	2026-08-10 11:41:59.590971+05:30	1	210.00	2026-08-10 11:42:00.109701+05:30	1	\N
49	50	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 11:42:05.209372+05:30	2026-08-10 11:42:05.209372+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
74	75	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:23:37.076197+05:30	2026-08-10 18:23:43.358305+05:30	\N	\N	\N	\N	\N	\N	\N	300.00	2026-08-10 18:23:43.358305+05:30	1	\N
84	85	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:24:08.437883+05:30	2026-08-10 18:24:08.437883+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
88	89	1	1	mmu	2026-08-10	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:24:09.852194+05:30	2026-08-10 18:24:10.516296+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
89	90	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:24:11.254574+05:30	2026-08-10 18:24:11.254574+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
50	51	1	1	mmu	2026-08-10	completed	1	2	4	3	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	2026-08-10	Paid	50.00	accept	\N	\N	2026-08-10 16:36:16.644911+05:30	2026-08-10 16:36:19.525126+05:30	\N	\N	\N	\N	\N	2026-08-10 16:36:16.960461+05:30	1	210.00	2026-08-10 16:36:17.72495+05:30	1	\N
51	52	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 16:36:23.39535+05:30	2026-08-10 16:36:23.39535+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
52	53	1	1	mmu	2026-08-10	completed	1	2	4	3	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	2026-08-10	Paid	50.00	accept	\N	\N	2026-08-10 16:38:16.861673+05:30	2026-08-10 16:38:19.222245+05:30	\N	\N	\N	\N	\N	2026-08-10 16:38:17.043106+05:30	1	210.00	2026-08-10 16:38:17.68476+05:30	1	\N
53	54	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 16:38:23.868907+05:30	2026-08-10 16:38:23.868907+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
54	55	1	1	mmu	2026-08-10	completed	1	2	4	3	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	2026-08-10	Paid	50.00	accept	\N	\N	2026-08-10 16:57:06.810432+05:30	2026-08-10 16:57:08.929509+05:30	\N	\N	\N	\N	\N	2026-08-10 16:57:07.106812+05:30	1	210.00	2026-08-10 16:57:07.67748+05:30	1	\N
55	56	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 16:57:12.587864+05:30	2026-08-10 16:57:12.587864+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
56	57	1	1	mmu	2026-08-10	completed	1	2	4	3	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	2026-08-10	Paid	50.00	accept	\N	\N	2026-08-10 17:14:40.936119+05:30	2026-08-10 17:14:43.611223+05:30	\N	\N	\N	\N	\N	2026-08-10 17:14:41.054954+05:30	1	210.00	2026-08-10 17:14:41.969939+05:30	1	\N
57	58	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 17:14:47.684251+05:30	2026-08-10 17:14:47.684251+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
58	59	1	1	mmu	2026-08-10	completed	1	2	4	3	\N	f	f	\N	\N	Fever three days	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	2026-08-10	Paid	50.00	accept	\N	\N	2026-08-10 17:42:48.115663+05:30	2026-08-10 17:42:50.937786+05:30	\N	\N	\N	\N	\N	2026-08-10 17:42:48.301392+05:30	1	210.00	2026-08-10 17:42:49.204156+05:30	1	\N
59	60	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 17:42:56.458153+05:30	2026-08-10 17:42:56.458153+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
60	61	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:01:07.888019+05:30	2026-08-10 18:01:07.888019+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
61	62	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:16:59.673681+05:30	2026-08-10 18:16:59.673681+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
62	63	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:17:50.710372+05:30	2026-08-10 18:17:50.710372+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
63	64	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:18:11.226575+05:30	2026-08-10 18:18:11.226575+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
94	95	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:27:02.273433+05:30	2026-08-10 18:27:02.273433+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
95	96	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:27:02.706359+05:30	2026-08-10 18:27:02.706359+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
96	97	1	1	mmu	2026-08-10	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:27:03.137702+05:30	2026-08-10 18:27:04.003758+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
97	98	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:27:04.819524+05:30	2026-08-10 18:27:04.819524+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
90	91	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:26:56.627474+05:30	2026-08-10 18:27:05.464956+05:30	\N	\N	\N	\N	\N	\N	\N	300.00	2026-08-10 18:27:05.464956+05:30	1	\N
99	100	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:27:29.570088+05:30	2026-08-10 18:27:31.517893+05:30	\N	\N	\N	\N	\N	\N	\N	250.00	2026-08-10 18:27:31.517893+05:30	1	\N
100	101	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:27:32.181117+05:30	2026-08-10 18:27:32.181117+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
101	102	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:27:32.800828+05:30	2026-08-10 18:27:32.800828+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
102	103	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:27:33.376853+05:30	2026-08-10 18:27:33.376853+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
103	104	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:27:33.891139+05:30	2026-08-10 18:27:33.891139+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
104	105	1	1	mmu	2026-08-10	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:27:34.366619+05:30	2026-08-10 18:27:35.273821+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
105	106	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:27:36.226259+05:30	2026-08-10 18:27:36.226259+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
98	99	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:27:27.492608+05:30	2026-08-10 18:27:36.953735+05:30	\N	\N	\N	\N	\N	\N	\N	300.00	2026-08-10 18:27:36.953735+05:30	1	\N
107	108	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:28:00.929539+05:30	2026-08-10 18:28:02.994365+05:30	\N	\N	\N	\N	\N	\N	\N	250.00	2026-08-10 18:28:02.994365+05:30	1	\N
108	109	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:28:03.537626+05:30	2026-08-10 18:28:03.537626+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
109	110	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:28:04.031291+05:30	2026-08-10 18:28:04.031291+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
110	111	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:28:04.59509+05:30	2026-08-10 18:28:04.59509+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
111	112	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:28:05.094613+05:30	2026-08-10 18:28:05.094613+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
112	113	1	1	mmu	2026-08-10	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:28:05.587055+05:30	2026-08-10 18:28:06.470358+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
113	114	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:28:07.442244+05:30	2026-08-10 18:28:07.442244+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
106	107	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:27:58.940804+05:30	2026-08-10 18:28:08.078859+05:30	\N	\N	\N	\N	\N	\N	\N	300.00	2026-08-10 18:28:08.078859+05:30	1	\N
115	116	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:29:39.48144+05:30	2026-08-10 18:29:41.443723+05:30	\N	\N	\N	\N	\N	\N	\N	250.00	2026-08-10 18:29:41.443723+05:30	1	\N
116	117	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:29:42.160755+05:30	2026-08-10 18:29:42.160755+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
117	118	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:29:42.775445+05:30	2026-08-10 18:29:42.775445+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
118	119	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:29:43.422665+05:30	2026-08-10 18:29:43.422665+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
119	120	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:29:43.963813+05:30	2026-08-10 18:29:43.963813+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
120	121	1	1	mmu	2026-08-10	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:29:44.482774+05:30	2026-08-10 18:29:45.402544+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
121	122	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:29:46.523774+05:30	2026-08-10 18:29:46.523774+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
114	115	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:29:36.342656+05:30	2026-08-10 18:29:47.394185+05:30	\N	\N	\N	\N	\N	\N	\N	300.00	2026-08-10 18:29:47.394185+05:30	1	\N
123	124	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:30:51.210999+05:30	2026-08-10 18:30:53.578446+05:30	\N	\N	\N	\N	\N	\N	\N	250.00	2026-08-10 18:30:53.578446+05:30	1	\N
124	125	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:30:54.223151+05:30	2026-08-10 18:30:54.223151+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
125	126	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:30:54.9446+05:30	2026-08-10 18:30:54.9446+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
126	127	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:30:55.511927+05:30	2026-08-10 18:30:55.511927+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
127	128	1	1	mmu	2026-08-10	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:30:56.072442+05:30	2026-08-10 18:30:57.255646+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
128	129	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:30:58.249146+05:30	2026-08-10 18:30:58.249146+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
122	123	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:30:48.866109+05:30	2026-08-10 18:30:59.071104+05:30	\N	\N	\N	\N	\N	\N	\N	300.00	2026-08-10 18:30:59.071104+05:30	1	\N
130	131	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:31:11.865918+05:30	2026-08-10 18:31:14.063853+05:30	\N	\N	\N	\N	\N	\N	\N	250.00	2026-08-10 18:31:14.063853+05:30	1	\N
131	132	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:31:14.666387+05:30	2026-08-10 18:31:14.666387+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
132	133	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:31:15.384045+05:30	2026-08-10 18:31:15.384045+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
133	134	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:31:16.004353+05:30	2026-08-10 18:31:16.004353+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
134	135	1	1	mmu	2026-08-10	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:31:16.598485+05:30	2026-08-10 18:31:17.731984+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
135	136	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:31:19.061659+05:30	2026-08-10 18:31:19.061659+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
129	130	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:31:09.460658+05:30	2026-08-10 18:31:20.049792+05:30	\N	\N	\N	\N	\N	\N	\N	300.00	2026-08-10 18:31:20.049792+05:30	1	\N
137	138	1	1	mmu	2026-08-10	with_lab	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:31:47.758231+05:30	2026-08-10 18:31:50.458623+05:30	\N	\N	\N	\N	\N	\N	\N	250.00	2026-08-10 18:31:50.458623+05:30	1	\N
138	139	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:31:51.180379+05:30	2026-08-10 18:31:51.180379+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
139	140	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:31:51.878486+05:30	2026-08-10 18:31:51.878486+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
140	141	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 18:31:52.497491+05:30	2026-08-10 18:31:52.497491+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
141	142	1	1	mmu	2026-08-10	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:31:53.190665+05:30	2026-08-10 18:31:54.418138+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
142	143	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 18:31:55.558172+05:30	2026-08-10 18:31:55.558172+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
136	137	1	1	mmu	2026-08-10	with_counsellor	1	2	4	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	2026-08-07	Paid	50.00	NA	\N	\N	2026-08-10 18:31:45.3929+05:30	2026-08-10 18:32:00.415542+05:30	\N	\N	\N	\N	\N	\N	\N	300.00	2026-08-10 18:31:56.334303+05:30	1	\N
143	145	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 19:17:41.873601+05:30	2026-08-10 19:17:41.873601+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
144	147	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-10 20:16:36.984804+05:30	2026-08-10 20:16:36.984804+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
145	148	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 20:19:31.437113+05:30	2026-08-10 20:19:31.437113+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
146	149	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 20:23:32.555111+05:30	2026-08-10 20:23:32.555111+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
147	150	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 20:35:06.93161+05:30	2026-08-10 20:35:06.93161+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
148	151	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 20:48:14.054485+05:30	2026-08-10 20:48:14.054485+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
149	152	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 21:14:35.932985+05:30	2026-08-10 21:14:35.932985+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
150	153	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 21:20:52.209095+05:30	2026-08-10 21:20:52.209095+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
151	154	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 21:39:07.528707+05:30	2026-08-10 21:39:07.528707+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
152	155	1	1	mmu	2026-08-10	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-10 21:49:33.104833+05:30	2026-08-10 21:49:33.104833+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
153	156	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-11 09:30:51.397893+05:30	2026-08-11 09:30:51.397893+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
154	157	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-11 09:36:46.391441+05:30	2026-08-11 09:36:46.391441+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
155	158	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 09:37:45.426357+05:30	2026-08-11 09:37:45.426357+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
156	159	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-11 09:52:48.456069+05:30	2026-08-11 09:52:48.456069+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
157	161	1	1	mmu	2026-08-11	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Recorded offline in the field		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 13:46:03.131467+05:30	2026-08-11 13:46:27.293393+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
159	161	1	1	mmu	2026-08-11	registered	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Previous diagnosis (2026-08-11): Fever\nRecorded offline in the field		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 13:52:51.223907+05:30	2026-08-11 13:52:51.223907+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	157
160	162	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-11 13:56:37.775258+05:30	2026-08-11 13:56:37.775258+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
161	163	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-11 13:58:20.957352+05:30	2026-08-11 13:58:20.957352+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
162	168	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-11 14:02:41.250601+05:30	2026-08-11 14:02:41.250601+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
163	169	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-11 14:03:40.435058+05:30	2026-08-11 14:03:40.435058+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
164	170	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:08:49.314049+05:30	2026-08-11 14:08:49.314049+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
165	171	1	1	mmu	2026-08-11	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Seen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:08:49.362553+05:30	2026-08-11 14:08:49.795904+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
166	171	1	1	mmu	2026-08-11	registered	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Previous diagnosis (2026-08-11): Fever\nSeen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:08:50.044444+05:30	2026-08-11 14:08:50.044444+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	165
167	172	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:09:11.152466+05:30	2026-08-11 14:09:11.152466+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
168	173	1	1	mmu	2026-08-11	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Seen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:09:11.178983+05:30	2026-08-11 14:09:11.67428+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
169	173	1	1	mmu	2026-08-11	registered	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Previous diagnosis (2026-08-11): Fever\nSeen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:09:11.863774+05:30	2026-08-11 14:09:11.863774+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	168
197	203	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:17:35.04409+05:30	2026-08-11 14:17:35.04409+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
198	204	1	1	mmu	2026-08-11	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Seen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:17:35.204171+05:30	2026-08-11 14:17:35.750507+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
199	204	1	1	mmu	2026-08-11	registered	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Previous diagnosis (2026-08-11): Fever\nSeen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:17:36.448812+05:30	2026-08-11 14:17:36.448812+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	198
200	205	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:18:04.222418+05:30	2026-08-11 14:18:04.222418+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
201	206	1	1	mmu	2026-08-11	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Seen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:18:04.398274+05:30	2026-08-11 14:18:05.08614+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
202	206	1	1	mmu	2026-08-11	registered	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Previous diagnosis (2026-08-11): Fever\nSeen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:18:05.563177+05:30	2026-08-11 14:18:05.563177+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	201
203	207	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:19:21.535256+05:30	2026-08-11 14:19:21.535256+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
204	208	1	1	mmu	2026-08-11	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Seen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:19:21.586573+05:30	2026-08-11 14:19:22.175698+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
205	208	1	1	mmu	2026-08-11	registered	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Previous diagnosis (2026-08-11): Fever\nSeen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:19:22.729733+05:30	2026-08-11 14:19:22.729733+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	204
206	209	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:19:51.592955+05:30	2026-08-11 14:19:51.592955+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
207	210	1	1	mmu	2026-08-11	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Seen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:19:51.624074+05:30	2026-08-11 14:19:52.360643+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
208	210	1	1	mmu	2026-08-11	registered	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Previous diagnosis (2026-08-11): Fever\nSeen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:19:52.777109+05:30	2026-08-11 14:19:52.777109+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	207
209	211	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-11 14:21:14.951272+05:30	2026-08-11 14:21:14.951272+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
210	212	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:25:52.201002+05:30	2026-08-11 14:25:52.201002+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
211	213	1	1	mmu	2026-08-11	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Seen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:25:52.27171+05:30	2026-08-11 14:25:52.733902+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
212	213	1	1	mmu	2026-08-11	registered	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Previous diagnosis (2026-08-11): Fever\nSeen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:25:53.342512+05:30	2026-08-11 14:25:53.342512+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	211
213	214	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-11 14:27:07.875671+05:30	2026-08-11 14:27:07.875671+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
214	215	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:31:08.291688+05:30	2026-08-11 14:31:08.291688+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
215	216	1	1	mmu	2026-08-11	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Seen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:31:08.362517+05:30	2026-08-11 14:31:08.923963+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
216	216	1	1	mmu	2026-08-11	registered	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Previous diagnosis (2026-08-11): Fever\nSeen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:31:09.291038+05:30	2026-08-11 14:31:09.291038+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	215
217	217	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-11 14:31:46.762292+05:30	2026-08-11 14:31:46.762292+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
218	218	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:32:16.676047+05:30	2026-08-11 14:32:16.676047+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
219	219	1	1	mmu	2026-08-11	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Seen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:32:16.710495+05:30	2026-08-11 14:32:17.224017+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
220	219	1	1	mmu	2026-08-11	registered	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Previous diagnosis (2026-08-11): Fever\nSeen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 14:32:17.453399+05:30	2026-08-11 14:32:17.453399+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	219
221	220	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-11 14:32:54.586789+05:30	2026-08-11 14:32:54.586789+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
222	221	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 15:10:01.03179+05:30	2026-08-11 15:10:01.03179+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
223	222	1	1	mmu	2026-08-11	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Seen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 15:10:01.075613+05:30	2026-08-11 15:10:01.555864+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
224	222	1	1	mmu	2026-08-11	registered	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Previous diagnosis (2026-08-11): Fever\nSeen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 15:10:01.921808+05:30	2026-08-11 15:10:01.921808+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	223
225	223	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-11 15:10:37.023994+05:30	2026-08-11 15:10:37.023994+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
226	224	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N			\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 15:53:56.171116+05:30	2026-08-11 15:53:56.171116+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
227	225	1	1	mmu	2026-08-11	with_counsellor	1	2	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Seen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 15:53:56.242083+05:30	2026-08-11 15:53:56.811231+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
228	225	1	1	mmu	2026-08-11	registered	1	\N	\N	\N	\N	f	f	\N	\N		\N	\N	\N	\N	\N	\N	\N	\N	Previous diagnosis (2026-08-11): Fever\nSeen offline		\N	f	f	\N	f	\N	\N	Free	0.00	NA	\N	\N	2026-08-11 15:53:57.075533+05:30	2026-08-11 15:53:57.075533+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	227
229	226	1	1	mmu	2026-08-11	with_doctor	1	\N	\N	\N	\N	f	f	\N	\N	via portal store	\N	\N	120	80	\N	98.6	\N	\N			\N	f	f	\N	f	\N	\N	Paid	50.00	NA	\N	\N	2026-08-11 15:54:33.539511+05:30	2026-08-11 15:54:33.539511+05:30	\N	\N	\N	\N	\N	\N	\N	0.00	\N	\N	\N
\.


--
-- TOC entry 5912 (class 0 OID 31192)
-- Dependencies: 273
-- Data for Name: appointment_attachment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointment_attachment (attachment_id, appointment_id, file_path, file_url, kind, description, created_at, deleted_at, deleted_by, delete_reason, legacy_id, legacy_source) FROM stdin;
\.


--
-- TOC entry 5906 (class 0 OID 31103)
-- Dependencies: 267
-- Data for Name: appointment_diagnosis; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointment_diagnosis (appointment_id, disease_id, diagnosis_text, icd11_code, is_primary, deleted_at, deleted_by, delete_reason) FROM stdin;
1	97	Dengue	\N	t	\N	\N	\N
5	\N	Dengue fever	\N	t	\N	\N	\N
6	\N	Dengue fever	\N	t	\N	\N	\N
7	\N	Dengue fever	\N	t	\N	\N	\N
8	\N	Dengue fever	\N	t	\N	\N	\N
9	\N	Dengue fever	\N	t	\N	\N	\N
13	\N	Dengue fever	\N	t	\N	\N	\N
20	\N	Dengue fever	\N	t	\N	\N	\N
23	\N	Dengue fever	\N	t	\N	\N	\N
38	\N	Acute nasopharyngitis	\N	t	\N	\N	\N
39	\N	Type 2 diabetes mellitus	\N	t	\N	\N	\N
40	\N	Hypertension	\N	t	\N	\N	\N
41	\N	Acute nasopharyngitis	\N	t	\N	\N	\N
42	\N	Acute pharyngitis	\N	t	\N	\N	\N
46	\N	Acute nasopharyngitis	\N	t	\N	\N	\N
47	\N	Acute pharyngitis	\N	t	\N	\N	\N
48	\N	Dengue fever	\N	t	\N	\N	\N
50	\N	Dengue fever	\N	t	\N	\N	\N
52	\N	Dengue fever	\N	t	\N	\N	\N
54	\N	Dengue fever	\N	t	\N	\N	\N
56	\N	Dengue fever	\N	t	\N	\N	\N
58	\N	Dengue fever	\N	t	\N	\N	\N
64	\N	Fever	\N	f	\N	\N	\N
65	\N	Fever	\N	f	\N	\N	\N
66	\N	Fever	\N	f	\N	\N	\N
67	\N	x	\N	f	\N	\N	\N
68	\N	Fever	\N	f	\N	\N	\N
69	\N	x	\N	f	\N	\N	\N
74	\N	Fever	\N	f	\N	\N	\N
75	\N	x	\N	f	\N	\N	\N
80	\N	x	\N	f	\N	\N	\N
82	\N	Fever	\N	f	\N	\N	\N
83	\N	x	\N	f	\N	\N	\N
88	\N	x	\N	f	\N	\N	\N
90	\N	Fever	\N	f	\N	\N	\N
91	\N	x	\N	f	\N	\N	\N
96	\N	x	\N	f	\N	\N	\N
98	\N	Fever	\N	f	\N	\N	\N
99	\N	x	\N	f	\N	\N	\N
104	\N	x	\N	f	\N	\N	\N
106	\N	Fever	\N	f	\N	\N	\N
107	\N	x	\N	f	\N	\N	\N
112	\N	x	\N	f	\N	\N	\N
114	\N	Fever	\N	f	\N	\N	\N
115	\N	x	\N	f	\N	\N	\N
120	\N	x	\N	f	\N	\N	\N
122	\N	Fever	\N	f	\N	\N	\N
123	\N	x	\N	f	\N	\N	\N
127	\N	x	\N	f	\N	\N	\N
129	\N	Fever	\N	f	\N	\N	\N
130	\N	x	\N	f	\N	\N	\N
134	\N	x	\N	f	\N	\N	\N
136	\N	Fever	\N	f	\N	\N	\N
137	\N	x	\N	f	\N	\N	\N
141	\N	x	\N	f	\N	\N	\N
136	\N	Dengue	\N	f	\N	\N	\N
157	\N	Fever	\N	f	\N	\N	\N
159	\N	Fever	\N	f	\N	\N	\N
165	\N	Fever	\N	f	\N	\N	\N
166	\N	Fever	\N	f	\N	\N	\N
168	\N	Fever	\N	f	\N	\N	\N
169	\N	Fever	\N	f	\N	\N	\N
198	\N	Fever	\N	f	\N	\N	\N
199	\N	Fever	\N	f	\N	\N	\N
201	\N	Fever	\N	f	\N	\N	\N
202	\N	Fever	\N	f	\N	\N	\N
204	\N	Fever	\N	f	\N	\N	\N
205	\N	Fever	\N	f	\N	\N	\N
207	\N	Fever	\N	f	\N	\N	\N
208	\N	Fever	\N	f	\N	\N	\N
211	\N	Fever	\N	f	\N	\N	\N
212	\N	Fever	\N	f	\N	\N	\N
215	\N	Fever	\N	f	\N	\N	\N
216	\N	Fever	\N	f	\N	\N	\N
219	\N	Fever	\N	f	\N	\N	\N
220	\N	Fever	\N	f	\N	\N	\N
223	\N	Fever	\N	f	\N	\N	\N
224	\N	Fever	\N	f	\N	\N	\N
227	\N	Fever	\N	f	\N	\N	\N
228	\N	Fever	\N	f	\N	\N	\N
\.


--
-- TOC entry 5908 (class 0 OID 31126)
-- Dependencies: 269
-- Data for Name: appointment_lab_test; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointment_lab_test (appointment_lab_id, appointment_id, lab_test_id, test_name, sample_done, sample_reason, assigned_handover_date, handover_date, handover_delay_reason, result, created_at, deleted_at, deleted_by, delete_reason, legacy_id, legacy_source, price, paid, paid_at, paid_by) FROM stdin;
1	5	14	ANC Profile	\N	\N	\N	\N	\N	\N	2026-08-09 22:48:26.012835+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
2	5	5	B.sugar	\N	\N	\N	\N	\N	\N	2026-08-09 22:48:26.012835+05:30	\N	\N	\N	\N	\N	60.00	f	\N	\N
28	40	3	Kidney Profile	t	\N	\N	2026-08-10	\N	Within normal limits	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	600.00	t	2026-08-10 11:23:29.516102+05:30	1
29	40	2	Lipid Profile	t	\N	\N	2026-08-10	\N	Within normal limits	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	500.00	t	2026-08-10 11:23:29.516865+05:30	1
3	6	14	ANC Profile	t		2026-08-09	2026-08-09		Positive	2026-08-09 22:50:01.657731+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-09 22:50:02.104207+05:30	1
4	6	5	B.sugar	t		2026-08-09	2026-08-09		140/90 mmHg	2026-08-09 22:50:01.657731+05:30	\N	\N	\N	\N	\N	60.00	t	2026-08-09 22:50:02.104207+05:30	1
30	41	6	HB	t	\N	\N	2026-08-08	\N	Within normal limits	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 11:23:29.526005+05:30	1
31	42	6	HB	t	\N	\N	2026-08-08	\N	Within normal limits	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 11:23:29.532817+05:30	1
5	7	14	ANC Profile	t		2026-08-09	2026-08-09		Positive	2026-08-09 22:51:24.046393+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-09 22:51:24.517163+05:30	1
6	7	5	B.sugar	t		2026-08-09	2026-08-09		140/90 mmHg	2026-08-09 22:51:24.046393+05:30	\N	\N	\N	\N	\N	60.00	t	2026-08-09 22:51:24.517163+05:30	1
32	42	1	CBC	t	\N	\N	2026-08-08	\N	Within normal limits	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 11:23:29.533403+05:30	1
33	46	2	Lipid Profile	\N	\N	\N	\N	\N	\N	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	500.00	f	\N	\N
7	8	14	ANC Profile	t		2026-08-09	2026-08-09		Positive	2026-08-09 22:52:31.260973+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-09 22:52:31.682405+05:30	1
8	8	5	B.sugar	t		2026-08-09	2026-08-09		140/90 mmHg	2026-08-09 22:52:31.260973+05:30	\N	\N	\N	\N	\N	60.00	t	2026-08-09 22:52:31.682405+05:30	1
34	47	6	HB	t	\N	\N	\N	\N	\N	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 11:23:29.557275+05:30	1
9	9	14	ANC Profile	t		2026-08-09	2026-08-09		Positive	2026-08-09 22:52:53.554363+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-09 22:52:53.963142+05:30	1
10	9	5	B.sugar	t		2026-08-09	2026-08-09		140/90 mmHg	2026-08-09 22:52:53.554363+05:30	\N	\N	\N	\N	\N	60.00	t	2026-08-09 22:52:53.963142+05:30	1
11	13	14	ANC Profile	t		2026-08-09	2026-08-09		Positive	2026-08-09 23:17:04.365151+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-09 23:17:04.903458+05:30	1
12	13	5	B.sugar	t		2026-08-09	2026-08-09		140/90 mmHg	2026-08-09 23:17:04.365151+05:30	\N	\N	\N	\N	\N	60.00	t	2026-08-09 23:17:04.903458+05:30	1
43	56	14	ANC Profile	t		2026-08-10	2026-08-10		Positive	2026-08-10 17:14:41.325702+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 17:14:41.969939+05:30	1
13	20	14	ANC Profile	t		2026-08-09	2026-08-09		Positive	2026-08-09 23:40:29.512298+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-09 23:40:29.930998+05:30	1
14	20	5	B.sugar	t		2026-08-09	2026-08-09		140/90 mmHg	2026-08-09 23:40:29.512298+05:30	\N	\N	\N	\N	\N	60.00	t	2026-08-09 23:40:29.930998+05:30	1
44	56	5	B.sugar	t		2026-08-10	2026-08-10		140/90 mmHg	2026-08-10 17:14:41.325702+05:30	\N	\N	\N	\N	\N	60.00	t	2026-08-10 17:14:41.969939+05:30	1
35	48	14	ANC Profile	t		2026-08-10	2026-08-10		Positive	2026-08-10 11:41:59.723669+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 11:42:00.109701+05:30	1
15	23	14	ANC Profile	t		2026-08-10	2026-08-10		Positive	2026-08-10 11:09:24.182336+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 11:09:24.539154+05:30	1
16	23	5	B.sugar	t		2026-08-10	2026-08-10		140/90 mmHg	2026-08-10 11:09:24.182336+05:30	\N	\N	\N	\N	\N	60.00	t	2026-08-10 11:09:24.539154+05:30	1
25	38	6	HB	\N	\N	\N	\N	\N	\N	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
26	38	5	B.sugar	\N	\N	\N	\N	\N	\N	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	60.00	f	\N	\N
27	39	6	HB	t	\N	\N	\N	\N	\N	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 11:23:29.503357+05:30	1
36	48	5	B.sugar	t		2026-08-10	2026-08-10		140/90 mmHg	2026-08-10 11:41:59.723669+05:30	\N	\N	\N	\N	\N	60.00	t	2026-08-10 11:42:00.109701+05:30	1
37	50	14	ANC Profile	t		2026-08-10	2026-08-10		Positive	2026-08-10 16:36:17.317082+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 16:36:17.72495+05:30	1
38	50	5	B.sugar	t		2026-08-10	2026-08-10		140/90 mmHg	2026-08-10 16:36:17.317082+05:30	\N	\N	\N	\N	\N	60.00	t	2026-08-10 16:36:17.72495+05:30	1
39	52	14	ANC Profile	t		2026-08-10	2026-08-10		Positive	2026-08-10 16:38:17.155942+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 16:38:17.68476+05:30	1
40	52	5	B.sugar	t		2026-08-10	2026-08-10		140/90 mmHg	2026-08-10 16:38:17.155942+05:30	\N	\N	\N	\N	\N	60.00	t	2026-08-10 16:38:17.68476+05:30	1
59	80	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:23:42.199693+05:30	\N	\N	\N	\N	\N	100.00	f	\N	\N
55	74	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-10 18:23:37.797365+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:23:43.358305+05:30	1
41	54	14	ANC Profile	t		2026-08-10	2026-08-10		Positive	2026-08-10 16:57:07.258038+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 16:57:07.67748+05:30	1
42	54	5	B.sugar	t		2026-08-10	2026-08-10		140/90 mmHg	2026-08-10 16:57:07.258038+05:30	\N	\N	\N	\N	\N	60.00	t	2026-08-10 16:57:07.67748+05:30	1
56	74	13	NS1 Antigen	\N	\N	\N	\N	\N	\N	2026-08-10 18:23:37.797365+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:23:43.358305+05:30	1
45	58	14	ANC Profile	t		2026-08-10	2026-08-10		Positive	2026-08-10 17:42:48.607865+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 17:42:49.204156+05:30	1
46	58	5	B.sugar	t		2026-08-10	2026-08-10		140/90 mmHg	2026-08-10 17:42:48.607865+05:30	\N	\N	\N	\N	\N	60.00	t	2026-08-10 17:42:49.204156+05:30	1
47	66	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-10 18:21:30.406394+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
48	66	13	NS1 Antigen	\N	\N	\N	\N	\N	\N	2026-08-10 18:21:30.406394+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
49	67	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:21:32.251676+05:30	\N	\N	\N	\N	\N	100.00	t	2026-08-10 18:21:33.10561+05:30	1
50	67	6	HB	\N	\N	\N	\N	\N	\N	2026-08-10 18:21:32.251676+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:21:33.10561+05:30	1
51	68	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-10 18:22:08.33214+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
52	68	13	NS1 Antigen	\N	\N	\N	\N	\N	\N	2026-08-10 18:22:08.33214+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
53	69	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:22:10.535891+05:30	\N	\N	\N	\N	\N	100.00	t	2026-08-10 18:22:11.354336+05:30	1
54	69	6	HB	\N	\N	\N	\N	\N	\N	2026-08-10 18:22:10.535891+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:22:11.354336+05:30	1
57	75	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:23:39.368029+05:30	\N	\N	\N	\N	\N	100.00	t	2026-08-10 18:23:39.920531+05:30	1
58	75	6	HB	\N	\N	\N	\N	\N	\N	2026-08-10 18:23:39.368029+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:23:39.920531+05:30	1
62	83	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:24:07.301552+05:30	\N	\N	\N	\N	\N	100.00	t	2026-08-10 18:24:08.120441+05:30	1
63	83	6	HB	\N	\N	\N	\N	\N	\N	2026-08-10 18:24:07.301552+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:24:08.120441+05:30	1
64	88	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:24:10.516296+05:30	\N	\N	\N	\N	\N	100.00	f	\N	\N
60	82	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-10 18:24:05.965459+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:24:11.741441+05:30	1
61	82	13	NS1 Antigen	\N	\N	\N	\N	\N	\N	2026-08-10 18:24:05.965459+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:24:11.741441+05:30	1
67	91	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:26:59.762684+05:30	\N	\N	\N	\N	\N	100.00	t	2026-08-10 18:27:00.668642+05:30	1
68	91	6	HB	\N	\N	\N	\N	\N	\N	2026-08-10 18:26:59.762684+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:27:00.668642+05:30	1
69	96	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:27:04.003758+05:30	\N	\N	\N	\N	\N	100.00	f	\N	\N
65	90	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-10 18:26:57.639489+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:27:05.464956+05:30	1
66	90	13	NS1 Antigen	\N	\N	\N	\N	\N	\N	2026-08-10 18:26:57.639489+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:27:05.464956+05:30	1
72	99	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:27:30.596516+05:30	\N	\N	\N	\N	\N	100.00	t	2026-08-10 18:27:31.517893+05:30	1
73	99	6	HB	\N	\N	\N	\N	\N	\N	2026-08-10 18:27:30.596516+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:27:31.517893+05:30	1
74	104	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:27:35.273821+05:30	\N	\N	\N	\N	\N	100.00	f	\N	\N
70	98	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-10 18:27:28.360022+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:27:36.953735+05:30	1
71	98	13	NS1 Antigen	\N	\N	\N	\N	\N	\N	2026-08-10 18:27:28.360022+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:27:36.953735+05:30	1
79	112	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:28:06.470358+05:30	\N	\N	\N	\N	\N	100.00	f	\N	\N
75	106	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-10 18:27:59.83734+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:28:08.078859+05:30	1
77	107	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:28:01.777478+05:30	\N	\N	\N	\N	\N	100.00	t	2026-08-10 18:28:02.994365+05:30	1
78	107	6	HB	\N	\N	\N	\N	\N	\N	2026-08-10 18:28:01.777478+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:28:02.994365+05:30	1
76	106	13	NS1 Antigen	\N	\N	\N	\N	\N	\N	2026-08-10 18:27:59.83734+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:28:08.078859+05:30	1
87	123	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:30:52.410899+05:30	\N	\N	\N	\N	\N	100.00	t	2026-08-10 18:30:53.578446+05:30	1
88	123	6	HB	\N	\N	\N	\N	\N	\N	2026-08-10 18:30:52.410899+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:30:53.578446+05:30	1
82	115	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:29:40.488423+05:30	\N	\N	\N	\N	\N	100.00	t	2026-08-10 18:29:41.443723+05:30	1
83	115	6	HB	\N	\N	\N	\N	\N	\N	2026-08-10 18:29:40.488423+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:29:41.443723+05:30	1
84	120	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:29:45.402544+05:30	\N	\N	\N	\N	\N	100.00	f	\N	\N
80	114	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-10 18:29:37.764904+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:29:47.394185+05:30	1
81	114	13	NS1 Antigen	\N	\N	\N	\N	\N	\N	2026-08-10 18:29:37.764904+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:29:47.394185+05:30	1
89	127	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:30:57.255646+05:30	\N	\N	\N	\N	\N	100.00	f	\N	\N
85	122	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-10 18:30:50.022602+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:30:59.071104+05:30	1
86	122	13	NS1 Antigen	\N	\N	\N	\N	\N	\N	2026-08-10 18:30:50.022602+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:30:59.071104+05:30	1
92	130	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:31:12.862352+05:30	\N	\N	\N	\N	\N	100.00	t	2026-08-10 18:31:14.063853+05:30	1
93	130	6	HB	\N	\N	\N	\N	\N	\N	2026-08-10 18:31:12.862352+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:31:14.063853+05:30	1
94	134	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:31:17.731984+05:30	\N	\N	\N	\N	\N	100.00	f	\N	\N
90	129	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-10 18:31:10.528909+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:31:20.049792+05:30	1
91	129	13	NS1 Antigen	\N	\N	\N	\N	\N	\N	2026-08-10 18:31:10.528909+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:31:20.049792+05:30	1
97	137	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:31:49.228266+05:30	\N	\N	\N	\N	\N	100.00	t	2026-08-10 18:31:50.458623+05:30	1
98	137	6	HB	\N	\N	\N	\N	\N	\N	2026-08-10 18:31:49.228266+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:31:50.458623+05:30	1
99	141	7	ESR	\N	\N	\N	\N	\N	\N	2026-08-10 18:31:54.418138+05:30	\N	\N	\N	\N	\N	100.00	f	\N	\N
95	136	1	CBC	t		\N	2026-08-07		\N	2026-08-10 18:31:46.509697+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:31:56.334303+05:30	1
96	136	13	NS1 Antigen	t		\N	2026-08-07		\N	2026-08-10 18:31:46.509697+05:30	\N	\N	\N	\N	\N	150.00	t	2026-08-10 18:31:56.334303+05:30	1
100	157	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-11 13:46:27.293393+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
101	165	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-11 14:08:49.795904+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
102	168	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-11 14:09:11.67428+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
134	198	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-11 14:17:35.750507+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
135	201	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-11 14:18:05.08614+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
136	204	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-11 14:19:22.175698+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
137	207	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-11 14:19:52.360643+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
138	211	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-11 14:25:52.733902+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
139	215	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-11 14:31:08.923963+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
140	219	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-11 14:32:17.224017+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
141	223	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-11 15:10:01.555864+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
142	227	1	CBC	\N	\N	\N	\N	\N	\N	2026-08-11 15:53:56.811231+05:30	\N	\N	\N	\N	\N	150.00	f	\N	\N
\.


--
-- TOC entry 5905 (class 0 OID 31086)
-- Dependencies: 266
-- Data for Name: appointment_symptom; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointment_symptom (appointment_id, symptom_id, deleted_at, deleted_by, delete_reason) FROM stdin;
36	1	\N	\N	\N
37	4	\N	\N	\N
38	2	\N	\N	\N
38	4	\N	\N	\N
38	6	\N	\N	\N
39	6	\N	\N	\N
40	5	\N	\N	\N
40	1	\N	\N	\N
40	2	\N	\N	\N
41	6	\N	\N	\N
41	2	\N	\N	\N
42	2	\N	\N	\N
42	6	\N	\N	\N
42	4	\N	\N	\N
43	2	\N	\N	\N
43	4	\N	\N	\N
44	4	\N	\N	\N
44	2	\N	\N	\N
45	2	\N	\N	\N
45	5	\N	\N	\N
46	6	\N	\N	\N
47	2	\N	\N	\N
47	5	\N	\N	\N
\.


--
-- TOC entry 5918 (class 0 OID 31275)
-- Dependencies: 279
-- Data for Name: attendance; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.attendance (attendance_id, user_id, facility_id, role, attendance_date, check_in, check_out, location, status, start_km, end_km, total_run, collection, notes, photo_path, latitude, longitude, created_at, updated_at, deleted_at, deleted_by, delete_reason, legacy_id, legacy_source, camp_anchor_id) FROM stdin;
5	1	1	counsellor	2026-08-09	23:54:33.675766	23:54:33.719595	Gajraula	Present	12000.0	12090.0	90.0	750.00		\N	\N	\N	2026-08-09 23:54:33.675766+05:30	2026-08-09 23:54:33.719595+05:30	\N	\N	\N	\N	\N	\N
36	1	1	counsellor	2026-08-11	15:54:35.000951	15:54:35.04308	Gajraula	Present	12000.0	12090.0	90.0	750.00		\N	\N	\N	2026-08-11 15:54:35.000951+05:30	2026-08-11 15:54:35.04308+05:30	\N	\N	\N	\N	\N	\N
22	1	1	counsellor	2026-08-10	21:49:34.760467	21:49:34.799546	Gajraula	Present	12000.0	12090.0	90.0	750.00		\N	\N	\N	2026-08-10 21:49:34.760467+05:30	2026-08-10 21:49:34.799546+05:30	\N	\N	\N	\N	\N	\N
\.


--
-- TOC entry 5868 (class 0 OID 30506)
-- Dependencies: 229
-- Data for Name: block_ref; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.block_ref (block_id, district_id, block_name, is_active) FROM stdin;
1	1	Dimoria	t
2	2	Guwahati City	t
3	3	Ashiana Nagar	t
4	4	Daman	t
5	5	Bicholim	t
6	6	AHMEDABAD - Urban(BB)	t
7	6	Ahmedabad(BB)	t
8	7	Ankleshwar	t
9	8	Bharuch	t
10	8	Other	t
11	8	Vagra	t
12	9	Other	t
13	9	Savli	t
14	10	Gurgaon	t
15	11	Bawal	t
16	11	Pataudi	t
17	11	Rewari	t
18	11	gurugram	t
19	11	tauru	t
20	12	Sector 15(Gurugram)	t
21	13	Badli	t
22	13	Jhajjar	t
23	13	Other	t
24	13	Salhawas	t
25	14	Manesar	t
26	15	Dadri Toe	t
27	16	Nihon MMU	t
28	17	Reliance Clinic	t
29	18	Badli	t
30	18	Jhajjar	t
31	19	Ranchi(BB)	t
32	20	Malleswaram	t
33	21	Devanahalli	t
34	21	Dodaballapur	t
35	21	Hoskote	t
36	22	Chitradurga	t
37	23	HD Kote	t
38	23	Hunsur	t
39	23	KR Nagar	t
40	23	Mysore taluk	t
41	23	Nanjangud	t
42	23	Other	t
43	23	Peeriyapatna	t
44	23	Saligrama	t
45	23	Sarguru	t
46	23	Tn pura	t
47	24	Mysore REC	t
48	25	Yelahanka	t
49	26	INDORE - RURAL	t
50	26	INDORE - URBAN	t
51	27	Isambe	t
52	28	Khalapur	t
53	28	Palghar	t
54	29	Panvel(BB)	t
55	30	Nagpur	t
56	31	Baramati	t
57	31	Khed	t
58	31	Other	t
59	31	Purandar	t
60	32	Pune Panasonic	t
61	33	Mumbai - Urban (Panvel)(BB)	t
62	33	Pune - Rural(BB)	t
63	33	Pune - Urban(BB)	t
64	34	Ranjangaon Blok	t
65	35	Butibori	t
66	36	Seloo	t
67	37	Bamra	t
68	38	Sambalpur(BB)	t
69	39	Ambala	t
70	40	Mohali	t
71	40	SAS Nagar	t
72	41	Kapasan	t
73	42	Thiruporur	t
74	43	Chennai Urban and Rural	t
75	44	Dothiguddem	t
76	45	Balanagar	t
77	45	Hyderabad	t
78	45	Isambe	t
79	45	Maula Ali	t
80	45	Yousufguda	t
81	46	Jubilee Hills	t
82	47	Ramalingampally	t
83	48	Gajraula	t
84	48	Hasanpur	t
85	48	Other	t
86	49	Tulsipur	t
87	50	Araniya	t
88	51	Anamika Sugar	t
89	52	Noida Location	t
90	53	Dadri	t
91	53	Dankaur	t
92	54	SNS Block	t
93	55	Padrauna	t
94	56	Vibhutikhand	t
95	57	Bhagatpur Tanda	t
96	58	KHATAULI	t
97	59	Tanda	t
98	60	Deoband	t
99	60	Rampur	t
100	60	Sarsawa	t
101	61	Roorkee	t
102	62	Purulia	t
103	63	Bolpur	t
104	64	Siliguri Town	t
105	65	Domjur	t
106	65	Kandua	t
107	65	Panchla	t
108	65	Pashchim Medinipur	t
109	66	Howrah	t
110	67	Mullick Bazar	t
111	68	South 24 Parganas	t
112	69	Test Block 3776	f
113	71	Test Block 9398	f
116	77	Test Block 7797	f
114	73	Test Block 5497	f
118	81	Test Block 9426	f
115	75	Test Block 3913	f
117	79	Test Block 8247	f
119	83	Test Block 8160	f
121	87	Test Block 6717	f
120	85	Test Block 7509	f
122	89	Test Block 3153	f
123	91	Test Block 7800	f
124	93	Test Block 5908	f
125	95	Test Block 6988	f
126	97	Test Block 4967	f
127	99	Test Block 2177	f
128	101	Test Block 7731	f
129	103	Test Block 7357	f
130	105	Test Block 8082	f
131	107	Test Block 1669	f
132	109	Test Block 2660	f
133	111	Test Block 1650	f
134	113	Test Block 9071	f
135	115	Test Block 5879	f
136	117	Test Block 1178	f
137	119	Test Block 5826	f
138	121	Test Block 7686	f
139	123	Test Block 9419	f
140	125	Test Block 4068	f
141	127	Test Block 4454	f
172	156	Test Block 2468	f
173	158	Test Block 4271	f
174	160	Test Block 5493	f
175	162	Test Block 6612	f
176	164	Test Block 2527	f
177	166	Test Block 1381	f
\.


--
-- TOC entry 5916 (class 0 OID 31245)
-- Dependencies: 277
-- Data for Name: camp; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.camp (camp_id, facility_id, village_id, camp_type, camp_name, venue, camp_date, attendees, services, notes, created_by, created_at, deleted_at, deleted_by, delete_reason, legacy_id, legacy_source) FROM stdin;
1	1	2138	Community	Gajraula Health Camp		2026-08-09	42	BP, sugar		1	2026-08-09 23:35:20.380598+05:30	\N	\N	\N	\N	\N
2	1	2138	Community	Camp xue1u		2026-08-09	55	BP, sugar	test	1	2026-08-09 23:37:32.119666+05:30	\N	\N	\N	\N	\N
3	1	2138	Community	Camp fzki2		2026-08-09	55	BP, sugar	test	1	2026-08-09 23:37:59.88536+05:30	\N	\N	\N	\N	\N
4	1	2138	Community	Camp vwzah		2026-08-09	55	BP, sugar	test	1	2026-08-09 23:38:54.438575+05:30	\N	\N	\N	\N	\N
5	1	2138	Community	Camp wqpq0		2026-08-09	55	BP, sugar	test	1	2026-08-09 23:39:56.606658+05:30	\N	\N	\N	\N	\N
6	1	2138	Community	Camp tgnv6		2026-08-09	55	BP, sugar	test	1	2026-08-09 23:40:16.269205+05:30	\N	\N	\N	\N	\N
7	1	2138	Community	Camp 1x5b1		2026-08-09	55	BP, sugar	test	1	2026-08-09 23:54:33.500706+05:30	\N	\N	\N	\N	\N
8	1	2138	Community	Camp e2r31		2026-08-10	55	BP, sugar	test	1	2026-08-10 11:09:56.384192+05:30	\N	\N	\N	\N	\N
9	1	2138	Community	Camp lod6f		2026-08-10	55	BP, sugar	test	1	2026-08-10 11:42:05.615578+05:30	\N	\N	\N	\N	\N
10	1	2138	Community	Camp oao2q		2026-08-10	55	BP, sugar	test	1	2026-08-10 16:36:23.763853+05:30	\N	\N	\N	\N	\N
11	1	2138	Community	Camp zsbot		2026-08-10	55	BP, sugar	test	1	2026-08-10 16:38:24.959249+05:30	\N	\N	\N	\N	\N
12	1	2138	Community	Camp 28q5u		2026-08-10	55	BP, sugar	test	1	2026-08-10 16:57:13.172263+05:30	\N	\N	\N	\N	\N
13	1	2138	Community	Camp kzjyr		2026-08-10	55	BP, sugar	test	1	2026-08-10 17:14:48.350198+05:30	\N	\N	\N	\N	\N
14	1	2138	Community	Camp zd56b		2026-08-10	55	BP, sugar	test	1	2026-08-10 17:42:57.213262+05:30	\N	\N	\N	\N	\N
15	1	2138	Community	Camp okw7e		2026-08-10	55	BP, sugar	test	1	2026-08-10 18:01:08.739196+05:30	\N	\N	\N	\N	\N
16	1	2138	Community	Camp kpecp		2026-08-10	55	BP, sugar	test	1	2026-08-10 19:17:46.904495+05:30	\N	\N	\N	\N	\N
17	1	2138	Community	Camp w4ify		2026-08-10	55	BP, sugar	test	1	2026-08-10 20:19:32.635231+05:30	\N	\N	\N	\N	\N
18	1	2138	Community	Camp e61iv		2026-08-10	55	BP, sugar	test	1	2026-08-10 20:23:33.927072+05:30	\N	\N	\N	\N	\N
19	1	2138	Community	Camp xed92		2026-08-10	55	BP, sugar	test	1	2026-08-10 20:35:07.947522+05:30	\N	\N	\N	\N	\N
20	1	2138	Community	Camp irj16		2026-08-10	55	BP, sugar	test	1	2026-08-10 20:48:15.326625+05:30	\N	\N	\N	\N	\N
21	1	2138	Community	Camp 681z2		2026-08-10	55	BP, sugar	test	1	2026-08-10 21:14:37.151609+05:30	\N	\N	\N	\N	\N
22	1	2138	Community	Camp aaxx0		2026-08-10	55	BP, sugar	test	1	2026-08-10 21:20:53.421943+05:30	\N	\N	\N	\N	\N
23	1	2138	Community	Camp 1cu09		2026-08-10	55	BP, sugar	test	1	2026-08-10 21:39:09.120527+05:30	\N	\N	\N	\N	\N
24	1	2138	Community	Camp sj41n		2026-08-10	55	BP, sugar	test	1	2026-08-10 21:49:34.523992+05:30	\N	\N	\N	\N	\N
25	1	2138	Community	Camp u68pv		2026-08-11	55	BP, sugar	test	1	2026-08-11 09:30:52.398167+05:30	\N	\N	\N	\N	\N
26	1	2138	Community	Camp 2gd07		2026-08-11	55	BP, sugar	test	1	2026-08-11 09:36:47.280276+05:30	\N	\N	\N	\N	\N
27	1	2138	Community	Camp fzpac		2026-08-11	55	BP, sugar	test	1	2026-08-11 09:52:49.357569+05:30	\N	\N	\N	\N	\N
28	1	2138	Community	Camp js93w		2026-08-11	55	BP, sugar	test	1	2026-08-11 13:56:40.2269+05:30	\N	\N	\N	\N	\N
29	1	2138	Community	Camp 61z58		2026-08-11	55	BP, sugar	test	1	2026-08-11 13:58:22.114107+05:30	\N	\N	\N	\N	\N
30	1	2138	Community	Camp vfksa		2026-08-11	55	BP, sugar	test	1	2026-08-11 14:02:42.203143+05:30	\N	\N	\N	\N	\N
31	1	2138	Community	Camp nbb4m		2026-08-11	55	BP, sugar	test	1	2026-08-11 14:03:41.441129+05:30	\N	\N	\N	\N	\N
32	1	2138	Community	Camp gmn85		2026-08-11	55	BP, sugar	test	1	2026-08-11 14:21:16.339185+05:30	\N	\N	\N	\N	\N
33	1	2138	Community	Camp xgb27		2026-08-11	55	BP, sugar	test	1	2026-08-11 14:27:09.254121+05:30	\N	\N	\N	\N	\N
34	1	2138	Community	Camp gvlhh		2026-08-11	55	BP, sugar	test	1	2026-08-11 14:31:47.972471+05:30	\N	\N	\N	\N	\N
35	1	2138	Community	Camp 4vwet		2026-08-11	55	BP, sugar	test	1	2026-08-11 14:32:55.650381+05:30	\N	\N	\N	\N	\N
36	1	2138	Community	Camp 5xdas		2026-08-11	55	BP, sugar	test	1	2026-08-11 15:10:38.240699+05:30	\N	\N	\N	\N	\N
37	1	2138	Community	Camp cdf1a		2026-08-11	55	BP, sugar	test	1	2026-08-11 15:54:34.878321+05:30	\N	\N	\N	\N	\N
\.


--
-- TOC entry 5939 (class 0 OID 57386)
-- Dependencies: 309
-- Data for Name: camp_anchor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.camp_anchor (camp_anchor_id, facility_id, anchor_name, latitude, longitude, is_active, created_at, updated_at, deleted_at, deleted_by, delete_reason) FROM stdin;
1	1	Gajraula Camp	28.845	78.24	t	2026-08-11 13:37:45.115165+05:30	2026-08-11 13:37:45.115165+05:30	\N	\N	\N
2	1	Hasanpur Camp	28.721	78.286	t	2026-08-11 13:37:45.120601+05:30	2026-08-11 13:37:45.120601+05:30	\N	\N	\N
3	1	Amroha Town Camp	28.903	78.467	t	2026-08-11 13:37:45.122522+05:30	2026-08-11 13:37:45.122522+05:30	\N	\N	\N
\.


--
-- TOC entry 5900 (class 0 OID 30881)
-- Dependencies: 261
-- Data for Name: category_master; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.category_master (category_id, category_name, is_active) FROM stdin;
1	General	t
2	OBC	t
3	SC	t
4	ST	t
5	N/A	t
\.


--
-- TOC entry 5896 (class 0 OID 30853)
-- Dependencies: 257
-- Data for Name: counselling_topic_master; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.counselling_topic_master (topic_id, topic_name, is_active) FROM stdin;
1	Nutrition	t
2	Hygiene	t
3	Chronic Disease	t
4	Family Planning	t
5	Adolescent Health	t
6	Mental Health	t
\.


--
-- TOC entry 5894 (class 0 OID 30839)
-- Dependencies: 255
-- Data for Name: device_master; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.device_master (device_id, device_name, is_active) FROM stdin;
1	Sphygmomanometer	t
2	Glucometer	t
3	Haemoglobinometer	t
4	Weighing Machine	t
\.


--
-- TOC entry 5920 (class 0 OID 31313)
-- Dependencies: 281
-- Data for Name: device_status_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.device_status_history (device_status_id, device_id, facility_id, status_date, status, reported_by, created_at, deleted_at, deleted_by, delete_reason) FROM stdin;
1	2	1	2026-08-09	Working	1	2026-08-09 23:35:22.887191+05:30	\N	\N	\N
29	1	1	2026-08-10	Working	1	2026-08-10 20:16:37.469645+05:30	\N	\N	\N
11	2	1	2026-08-10	Working	1	2026-08-10 11:09:56.598061+05:30	\N	\N	\N
46	2	1	2026-08-11	Working	1	2026-08-11 09:30:52.567289+05:30	\N	\N	\N
\.


--
-- TOC entry 5888 (class 0 OID 30789)
-- Dependencies: 249
-- Data for Name: disease_master; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.disease_master (disease_id, disease_name, icd11_code, synonyms, is_active) FROM stdin;
1	Acute nasopharyngitis	CA00	{"common cold",coryza,"head cold","acute rhinitis","runny nose","blocked nose",sardi,zukam,sardi-zukam,nazla,"naak behna"}	t
2	Acute sinusitis	CA01	{"sinus infection",rhinosinusitis,sinusitis,"naak band","sinus ki samasya",sinus}	t
3	Acute pharyngitis	CA02	{"sore throat","throat infection",pharyngitis,"gale me kharaash","gala kharab","gale me dard"}	t
4	Acute tonsillitis	CA03	{"tonsil infection",tonsillitis,tonsils,"gale ki granthi soojan","tonsil badhna","throat infection","gala kharab"}	t
5	Acute laryngitis or tracheitis	CA05	{laryngitis,tracheitis,hoarseness,"voice loss","awaaz baithna","gala baithna"}	t
6	Acute bronchitis	CA20	{"chest cold","chest infection",bronchitis,"seene me sankraman","balgam wali khaansi"}	t
7	Pneumonia	CA40	{"lung infection","chest infection",pneumonia,nimoniya,"phephdon ka sankraman"}	t
8	Influenza	1E32	{flu,influenza,"viral fever",viral,"mausami bukhar","flu bukhar"}	t
9	Acute URI	CA07	{URI,URTI,RTI,"upper respiratory infection","saans naali ka sankraman"}	t
10	Infectious gastroenteritis/colitis	1A40	{gastroenteritis,GE,AGE,"loose motions",diarrhoea,dysentery,"food poisoning","stomach infection","stomach flu",enteritis,vomiting,dast,"pet kharab",pechish,ulti-dast}	t
11	Open wound of the head	NA0Z	{"head wound","scalp cut","head injury","laceration of head","sir par chot","sir ka ghaav","sir kat-na"}	t
12	Open wound of the neck	NA8Z	{"neck wound","neck injury","gardan par chot","gardan ka ghaav"}	t
13	Open wound of the thorax	NB3Z	{"chest wound","chest injury","seene par chot","seene ka ghaav"}	t
14	Open wound of the abdomen	NC5Z	{"abdominal wound","belly injury","pet par chot","pet ka ghaav"}	t
15	Open wound of the shoulder or upper arm	ND2Z	{"arm wound","shoulder injury","baazu par chot","kandhe ki chot"}	t
16	Open wound of the wrist or hand	ND56	{"hand cut","wrist laceration","haath par chot","haath kat-na","kalai ki chot"}	t
17	Open wound of the lower limb	ND7Z	{"leg wound","thigh injury","taang par chot","jangh ki chot","paer ka ghaav"}	t
18	Open wound of the ankle or foot	ND9Z	{"foot wound","ankle injury","pair par chot","takhne ki chot","pair kat-na"}	t
19	Traumatic wound	NF2Z	{cut,laceration,abrasion,"open wound",graze,chot,ghaav,zakhm,kat}	t
20	Protein-energy malnutrition	5B53	{malnutrition,PEM,undernutrition,"low weight",kuposhan,kamzori,weakness}	t
21	Severe protein-energy malnutrition	5B52	{SAM,marasmus,kwashiorkor,"severe malnutrition","gambhir kuposhan"}	t
22	Iron deficiency anaemia	3A00	{anaemia,anemia,"low haemoglobin","low Hb","khoon ki kami",pandu,"khoon ghatna"}	t
23	Vitamin A deficiency	5B55	{"night blindness","vitamin A ki kami",ratondhi}	t
24	Vitamin D deficiency	5B57	{rickets,osteomalacia,"vitamin D ki kami","haddi kamzori","sukha rog"}	t
25	Vitamin B12 or folate deficiency anaemia	3A01	{"megaloblastic anaemia","B12 ki kami","vitamin B12 deficiency"}	t
26	Iodine deficiency	5B5K	{goitre,"iodine ki kami",ghengha,"gale ki soojan"}	t
27	Scabies	1G04	{itching,scabies,"mite infestation",khujli,kharish,khaaj}	t
28	Dermatophytosis	1F28	{ringworm,tinea,"fungal infection",daad,daad-khaaj,"fungal sankraman"}	t
29	Atopic eczema	EA80	{eczema,dermatitis,"itchy rash",atopic,"khujli wala chakatta",eczema}	t
30	Contact dermatitis	EK00	{"allergic rash","contact dermatitis",allergy,"allergy ke daane"}	t
31	Urticaria	EB00	{hives,urticaria,"allergy welts",sheet-pitt,pitti,chakatte}	t
32	Cellulitis	1B70	{"skin infection","soft tissue infection",cellulitis,"twacha sankraman"}	t
33	Impetigo	1B72	{impetigo,pyoderma,"skin sores",boil,phoda,phunsi,ghaav}	t
34	Acne	ED80	{pimples,acne,muhase,kil-muhase}	t
35	Osteoarthritis	FA0Z	{OA,"joint pain","knee pain",osteoarthritis,"jodon ka dard","ghutne ka dard",gathiya}	t
36	Rheumatoid arthritis	FA20	{RA,"rheumatoid arthritis","joint pain",arthritis,gathiya,"jodon ki soojan"}	t
37	Gout	FA25	{gout,"high uric acid","joint pain",gathiya,"uric acid badhna"}	t
38	Low back pain	ME84	{"back pain",lumbago,LBP,"kamar dard","peeth dard"}	t
39	Sprain or strain	NC3Z	{sprain,strain,"muscle pull",moch,"maans peshi khinchav"}	t
40	Myalgia	FB56	{"body ache","muscle pain",myalgia,"badan dard","shareer dard","muscle dard"}	t
41	Osteoporosis	FB83	{"weak bones",osteoporosis,"haddi kamzori","haddi bhurbhuri"}	t
42	Dental caries	DA08	{cavity,"tooth decay",caries,"daant me keeda","daant sadna"}	t
43	Pulpitis	DA09	{toothache,"tooth pain",pulpitis,"daant me dard"}	t
44	Gingivitis	DA0C	{"gum inflammation","bleeding gums",gingivitis,"masude me soojan","masude se khoon"}	t
45	Periodontitis	DA0D	{"gum disease",periodontitis,"masude ki bimari"}	t
46	Mouth ulcers	DA01.15	{"canker sore","aphthous ulcer","muh ke chhale","muh me chhala","oral ulcer","mouth sore","mouth ulcer","jeebh ke chhale"}	t
47	Gastritis	DA42.Z	{acidity,gastric,gastritis,"stomach inflammation",gas,"pet me jalan",amlapitta,hyperacidity,heartburn,"acid reflux",indigestion}	t
48	Gastro-oesophageal reflux disease	DA22	{"acid reflux",heartburn,GERD,"seene me jalan","khatti dakaar"}	t
49	Functional dyspepsia	DD90.3	{indigestion,gas,bloating,dyspepsia,badhazmi,"pet phoolna"}	t
50	Peptic ulcer	DA61	{"stomach ulcer","duodenal ulcer","peptic ulcer","aamashay ka ghaav"}	t
51	Constipation	ME05	{"hard stools","no motion",constipation,kabz,kabzi,"pet saaf na hona"}	t
52	Irritable bowel syndrome	DD91	{IBS,"irritable bowel","baar-baar dast ya kabz"}	t
53	Conjunctivitis	9A60	{"red eye","eye infection","pink eye",conjunctivitis,"aankh aana","aankh laal","aankh me sankraman"}	t
54	Refractive error	9D00	{"vision problem","weak eyesight","refractive error","najar kamzor","chashma number"}	t
55	Cataract	9B10	{cataract,"clouding of lens","white in eye",motiyabind,"safed motiya"}	t
56	Hordeolum	9A01	{stye,"eyelid boil",hordeolum,"aankh ki phunsi",bilni,guhanjani}	t
57	Glaucoma	9C61	{glaucoma,"high eye pressure","kala motiya","aankh ka dabaav"}	t
58	Dry eye disease	9A06	{"dry eye","watering eyes","eye irritation","aankh me jalan","aankh sookhna"}	t
59	Otitis media	AB0Z	{"ear infection","ear pain",earache,"otitis media","kaan dard","kaan me sankraman","kaan baha"}	t
60	Otitis externa	AA0Z	{"outer ear infection","ear discharge","otitis externa","kaan baha","kaan se paani"}	t
61	Rhinitis	CA08	{"nasal block",sneezing,"runny nose","allergic rhinitis","naak band",chheenk,"naak behna"}	t
62	Hearing impairment	AB50	{"hearing problem",deafness,"hearing loss","kam sunai dena",behrapan}	t
63	Dysmenorrhoea	GA34.3	{"period pain","painful periods"}	t
64	Abnormal uterine bleeding	GA20	{"heavy periods","irregular periods",AUB,"jyada mahwari","anyamit mahwari"}	t
65	Abnormal vaginal discharge	MF3A	{"white discharge",leucorrhoea,"PV discharge","safed paani",likoria}	t
66	Vaginitis	GA02	{"vaginal infection",vaginitis,"yoni sankraman"}	t
67	Polycystic ovary syndrome	5A80.1	{PCOS,PCOD,"polycystic ovary","ovary me cyst"}	t
68	Pelvic inflammatory disease	GA05	{PID,"pelvic inflammatory disease","pet ke neeche sankraman"}	t
69	Essential hypertension	BA00	{"high BP","high blood pressure",HTN,BP,"uchch raktchaap","BP badhna",hypertension,"blood pressure",raktchaap}	t
70	Angina pectoris	BA40	{"chest pain",IHD,CAD,angina,"seene me dard","dil ka dard"}	t
71	Acute myocardial infarction	BA41	{"heart attack","cardiac arrest",MI,"myocardial infarction","dil ka daura"}	t
72	Heart failure	BD10	{CHF,"cardiac failure","heart failure","dil ki kamzori"}	t
73	Cardiac arrhythmia	BC9Z	{palpitations,"irregular heartbeat",arrhythmia,"dhadkan tej"}	t
74	Rheumatic heart disease	BB40	{RHD,"rheumatic heart disease"}	t
75	Cerebral ischaemic stroke	8B11	{stroke,paralysis,"brain attack",lakwa}	t
76	Epilepsy	8A6Z	{fits,convulsions,seizure,epilepsy,mirgi,daura}	t
77	Migraine	8A80	{migraine,"half-head pain","aadha sir dard",adhkapari}	t
78	Tension-type headache	8A81	{headache,"tension headache","sir dard"}	t
79	Vertigo	AB31	{giddiness,dizziness,vertigo,chakkar,"sir ghoomna"}	t
80	Peripheral neuropathy	8C0Z	{numbness,tingling,"nerve pain",neuropathy,jhunjhuni,sunnpan,jhanjhanahat}	t
81	Facial palsy	8B88	{"facial weakness","facial palsy","Bell palsy","chehre ka lakwa","muh tedha"}	t
82	Depressive disorder	6A7Z	{depression,"low mood",sadness,avsaad,udaasi,"man udaas"}	t
83	Anxiety or fear-related disorder	6B0Z	{anxiety,tension,stress,ghabrahat,chinta,bechaini}	t
84	Insomnia disorder	7A0Z	{sleeplessness,"no sleep",insomnia,"neend na aana",anidra}	t
85	Stress-related symptoms	6C20	{stress,tension,"bodily distress",tanaav}	t
86	Disorder due to substance use	6C4Z	{addiction,alcohol,tobacco,nasha,sharab,tambaaku,lat}	t
87	Urinary tract infection	GC08	{UTI,"burning urination","urine infection","peshab me jalan","peshab sankraman","mutra sankraman"}	t
88	Chronic kidney disease	GB61	{CKD,"kidney failure","renal failure","gurde ki kharabi","gurda fail"}	t
89	Acute kidney failure	GB60	{AKI,"acute renal failure","gurde ki kharabi"}	t
90	Urolithiasis	GC00	{"kidney stone","renal calculi",stone,pathri,"gurde ki pathri",calculi}	t
91	Benign prostatic hyperplasia	GA91	{BPH,"prostate enlargement","prostate badhna"}	t
92	Prostatitis	GA90	{"prostate infection",prostatitis,"prostate soojan"}	t
93	Diabetes mellitus	5A14	{diabetes,sugar,"high blood sugar",DM,T1DM,T2DM,"sugar ki bimari",madhumeh,"shakkar ki bimari"}	t
94	Chronic obstructive pulmonary disease	CA22	{COPD,"chronic bronchitis",emphysema,breathlessness,"saans phoolna",dama}	t
95	Asthma	CA23	{asthma,"bronchial asthma",wheezing,breathlessness,dama,"saans ki bimari","saans phoolna","saans ukhadna"}	t
96	Burn	NE2Z	{burn,scald,"thermal injury","thermal burn",jalna,"jal jana","aag se jalna"}	t
97	Dengue	1D2Z	{dengue,"dengue fever",DHF,"dengue bukhar","haddi tod bukhar","break bone fever"}	t
98	Hepatitis A	1E50.0	{"hepatitis A","viral hepatitis A",HAV,"jaundice (viral)",piliya,kamla}	t
99	Hepatitis C	1E50.2	{"hepatitis C",HCV,"viral hepatitis C",piliya}	t
100	Hepatitis E	1E50.4	{"hepatitis E",HEV,"viral hepatitis E",piliya}	t
101	Anal fissure	DB50.0	{fissure-in-ano,"rectal fissure","anal tear",fissure}	t
102	Wheezing	MD11.C	{wheeze,"wheezy breathing","whistling breath","saans me seeti",ghar-ghar,"saans phoolna"}	t
103	Diarrhoea	ME05.1	{diarrhoea,"loose stools","loose motions",dast,"patli tatti","pet kharab",motions}	t
104	Fever	MG26	{fever,pyrexia,"raised temperature","high temperature",bukhar,taap,jvar}	t
105	Covid-19	RA01	{COVID-19,coronavirus,corona,SARS-CoV-2,covid,"corona bimari"}	t
106	Fracture	NC72	{"broken bone",fracture,"haddi tutna"}	t
107	Cough	MD12	{cough,"dry cough","wet cough",khaansi,"sookhi khaansi","balgam wali khaansi"}	t
108	Fatigue	MG22	{weakness,fatigue,tiredness,asthenia,lethargy,kamzori,thakaan,susti}	t
109	Headache	8A8Z	{headache,"head pain",migraine,"tension headache","sir dard"}	t
110	Dehydration	5C70.0	{dehydration,"fluid loss","volume depletion","paani ki kami"}	t
111	Cracked heels / heel fissures	ED54	{"cracked heels","heel fissures","fissured feet","dry skin","edi phatna","phati ediyan","pair phatna"}	t
\.


--
-- TOC entry 5866 (class 0 OID 30486)
-- Dependencies: 227
-- Data for Name: district_ref; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.district_ref (district_id, state_id, district_name, is_active) FROM stdin;
1	1	Kamrup	t
2	1	Kamrup Metro	t
3	2	Patna	t
4	3	Daman	t
5	4	North Goa	t
6	5	Ahmedabad(BB)	t
7	5	Ankleshwar	t
8	5	Bharuch	t
9	5	Vadodara	t
10	6	Gurugram	t
11	6	Gurugram New	t
12	6	Gurugram(BB)	t
13	6	Jhajjar	t
14	6	Manesar	t
15	6	Nihon India	t
16	6	Nihon MMU	t
17	6	Reliance Clinic	t
18	6	Reliance MMU	t
19	7	Ranchi(BB)	t
20	8	Bangalore catchment	t
21	8	Bengaluru REC	t
22	8	Chitradurga	t
23	8	Mysore	t
24	8	Mysore REC	t
25	8	Panasonic BLR	t
26	9	Indore	t
27	10	Isambe	t
28	10	Mumbai	t
29	10	Mumbai(BB)	t
30	10	Nagpur	t
31	10	Nira	t
32	10	Panasonic PUNE	t
33	10	Pune(BB)	t
34	10	Ranjangaon Pune	t
35	10	Rural Nagpur	t
36	10	Wardha	t
37	11	Sambalpur	t
38	11	Sambalpur(BB)	t
39	12	Chandigarh	t
40	12	Mohali	t
41	13	Chittaurgarh	t
42	14	Chengalpattu	t
43	14	Chennai Catchment	t
44	15	Dothiguddem	t
45	15	Hyderabad	t
46	15	Hyderabad Catchment	t
47	15	Ramalingapally	t
48	16	Amroha	t
49	16	Amroha (Triveni)	t
50	16	Bulandshahr	t
51	16	Bulandshahr (Anamika)	t
52	16	Gautam Buddha Nagar(BB)	t
53	16	Gautam Budh Nagar	t
54	16	Gautam Budh Nagar(sns)	t
55	16	Kushinagar	t
56	16	Lucknow - Vibhutikhand	t
57	16	Moradabad	t
58	16	Muzaffarnagar	t
59	16	Rampur	t
60	16	Saharanpur	t
61	17	Roorkee	t
62	18	Asansol	t
63	18	Birbhum	t
64	18	Darjeeling	t
65	18	Howrah	t
66	18	Kolkata	t
67	18	Kolkata(BB)	t
68	18	South Bengal	t
88	1	Test District 6717	f
69	19	Test District 3776	f
70	1	Test District 3776	f
71	20	Test District 9398	f
72	1	Test District 9398	f
73	21	Test District 5497	f
74	1	Test District 5497	f
75	22	Test District 3913	f
76	1	Test District 3913	f
89	29	Test District 3153	f
77	23	Test District 7797	f
78	1	Test District 7797	f
90	1	Test District 3153	f
79	24	Test District 8247	f
80	1	Test District 8247	f
81	25	Test District 9426	f
82	1	Test District 9426	f
83	26	Test District 8160	f
84	1	Test District 8160	f
85	27	Test District 7509	f
86	1	Test District 7509	f
99	34	Test District 2177	f
87	28	Test District 6717	f
91	30	Test District 7800	f
92	1	Test District 7800	f
100	1	Test District 2177	f
93	31	Test District 5908	f
94	1	Test District 5908	f
95	32	Test District 6988	f
96	1	Test District 6988	f
97	33	Test District 4967	f
98	1	Test District 4967	f
105	37	Test District 8082	f
101	35	Test District 7731	f
102	1	Test District 7731	f
106	1	Test District 8082	f
103	36	Test District 7357	f
104	1	Test District 7357	f
107	38	Test District 1669	f
108	1	Test District 1669	f
109	39	Test District 2660	f
110	1	Test District 2660	f
111	40	Test District 1650	f
112	1	Test District 1650	f
114	1	Test District 9071	f
113	41	Test District 9071	f
116	1	Test District 5879	f
115	43	Test District 5879	f
118	1	Test District 1178	f
117	44	Test District 1178	f
120	1	Test District 5826	f
119	45	Test District 5826	f
122	1	Test District 7686	f
121	46	Test District 7686	f
124	1	Test District 9419	f
123	47	Test District 9419	f
126	1	Test District 4068	f
125	48	Test District 4068	f
127	49	Test District 4454	f
128	1	Test District 4454	f
156	80	Test District 2468	f
157	1	Test District 2468	f
158	81	Test District 4271	f
159	1	Test District 4271	f
160	82	Test District 5493	f
161	1	Test District 5493	f
162	83	Test District 6612	f
163	1	Test District 6612	f
164	84	Test District 2527	f
165	1	Test District 2527	f
166	85	Test District 1381	f
167	1	Test District 1381	f
\.


--
-- TOC entry 5872 (class 0 OID 30549)
-- Dependencies: 233
-- Data for Name: facility; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.facility (facility_id, facility_code, facility_type, org_id, facility_name, state_id, district_id, block_id, city, latitude, longitude, vehicle_no, icon_type, route_color, doctor_name, tier_id, subscription_start, subscription_end, joined_date, status, created_at, updated_at, deleted_at, deleted_by, delete_reason, legacy_id, legacy_source) FROM stdin;
16	MMU-NIRA-01	mmu	2	MMU-Nira-01	10	31	56	\N	18.15	74.58	MH 15 EF 1111	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:28:25.630716+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
17	MMU-BHARUCH-02	mmu	2	MMU-Bharuch-02	5	8	11	\N	21.74	72.8	GJ 05 GH 2222	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:28:25.630716+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
84	MMU-TEST-860	mmu	1	MMU-Test-860	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 21:48:58.316698+05:30	2026-08-10 21:48:58.71666+05:30	2026-08-10 21:48:58.71666+05:30	17	test	\N	\N
9	GAJRAULA-STATIC	static_clinic	1	Gajraula Static	16	48	83	\N	28.848	78.257	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:21:51.929567+05:30	2026-08-11 09:32:59.388343+05:30	\N	\N	\N	\N	\N
1	MMU001	mmu	1	MMU-Gajraula-01	16	48	83	\N	28.845	78.24	UP 23 AB 1234	\N	#0b2e5c	\N	\N	\N	\N	2026-08-03	active	2026-08-03 14:50:13.85991+05:30	2026-08-11 12:11:02.820629+05:30	\N	\N	\N	\N	\N
18	MMU-AHMEDABAD-03	mmu	2	MMU-Ahmedabad-03	5	6	7	\N	23.03	72.585	GJ 10 IJ 3333	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:28:25.630716+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
19	MMU-MYSORE-01	mmu	3	MMU-Mysore-01	8	23	41	\N	12.12	76.68	KA 09 KL 4444	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:28:25.630716+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
20	MMU-SAMBALPUR-02	mmu	3	MMU-Sambalpur-02	11	37	67	\N	21.47	84.02	OD 02 MN 5555	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:28:25.630716+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
10	HASANPUR-STATIC	static_clinic	1	Hasanpur Static	16	48	84	\N	28.719	78.302	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:21:51.929567+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
11	ROORKEE-STATIC	static_clinic	1	Roorkee Static	17	61	101	\N	29.867	77.895	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:21:51.929567+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
21	BARAMATI-HEALTH-CENTRE	static_clinic	2	Baramati Health Centre	10	31	56	\N	18.152	74.577	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:28:25.630716+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
22	BHARUCH-HEALTH-POINT	static_clinic	2	Bharuch Health Point	5	8	9	\N	21.705	72.995	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:28:25.630716+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
23	MYSORE-CLINIC	static_clinic	3	Mysore Clinic	8	23	40	\N	12.295	76.639	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:28:25.630716+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
3	MMU003	mmu	1	MMU-Haridwar-03	17	\N	\N	\N	29.87	77.892	UK 08 CD 4321	\N	#4FC3F7	\N	\N	\N	\N	2026-08-03	active	2026-08-03 14:50:13.85991+05:30	2026-08-10 11:29:37.399938+05:30	2026-08-10 11:29:37.399938+05:30	18	superseded by remapped demo geography	\N	\N
4	MMU-NASHIK-01	mmu	2	MMU-Nashik-01	10	\N	\N	\N	19.7	73.56	MH 15 EF 1111	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:21:51.929567+05:30	2026-08-10 11:29:37.399938+05:30	2026-08-10 11:29:37.399938+05:30	18	superseded by remapped demo geography	\N	\N
5	MMU-SURAT-02	mmu	2	MMU-Surat-02	5	\N	\N	\N	21.12	73.11	GJ 05 GH 2222	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:21:51.929567+05:30	2026-08-10 11:29:37.399938+05:30	2026-08-10 11:29:37.399938+05:30	18	superseded by remapped demo geography	\N	\N
6	MMU-JAMNAGAR-03	mmu	2	MMU-Jamnagar-03	5	\N	\N	\N	22.22	70.27	GJ 10 IJ 3333	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:21:51.929567+05:30	2026-08-10 11:29:37.399938+05:30	2026-08-10 11:29:37.399938+05:30	18	superseded by remapped demo geography	\N	\N
7	MMU-MYSURU-01	mmu	3	MMU-Mysuru-01	8	\N	\N	\N	12.12	76.68	KA 09 KL 4444	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:21:51.929567+05:30	2026-08-10 11:29:37.399938+05:30	2026-08-10 11:29:37.399938+05:30	18	superseded by remapped demo geography	\N	\N
27	MMU-TEST-506	mmu	1	MMU-Test-506	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 16:57:23.04606+05:30	2026-08-10 16:57:23.283232+05:30	2026-08-10 16:57:23.283232+05:30	17	test	\N	\N
28	CLINIC-TEST-506	static_clinic	1	Clinic-Test-506	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 16:57:23.23341+05:30	2026-08-10 16:57:23.283232+05:30	2026-08-10 16:57:23.283232+05:30	17	test	\N	\N
29	MMU-TEST-291	mmu	1	MMU-Test-291	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:14:11.3531+05:30	2026-08-10 17:14:11.641209+05:30	2026-08-10 17:14:11.641209+05:30	17	test	\N	\N
30	CLINIC-TEST-291	static_clinic	1	Clinic-Test-291	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:14:11.59581+05:30	2026-08-10 17:14:11.641209+05:30	2026-08-10 17:14:11.641209+05:30	17	test	\N	\N
31	MMU-TEST-806	mmu	1	MMU-Test-806	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:15:04.080756+05:30	2026-08-10 17:15:04.330709+05:30	2026-08-10 17:15:04.330709+05:30	17	test	\N	\N
32	CLINIC-TEST-806	static_clinic	1	Clinic-Test-806	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:15:04.262257+05:30	2026-08-10 17:15:04.330709+05:30	2026-08-10 17:15:04.330709+05:30	17	test	\N	\N
33	MMU-TEST-964	mmu	1	MMU-Test-964	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:31:15.447256+05:30	2026-08-10 17:31:16.123749+05:30	2026-08-10 17:31:16.123749+05:30	17	test	\N	\N
34	CLINIC-TEST-964	static_clinic	1	Clinic-Test-964	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:31:15.975852+05:30	2026-08-10 17:31:16.123749+05:30	2026-08-10 17:31:16.123749+05:30	17	test	\N	\N
2	MMU002	mmu	1	MMU-Hasanpur-02	16	48	84	\N	28.72	78.29	UP 23 AB 5678	\N	#007FB5	\N	\N	\N	\N	2026-08-03	active	2026-08-03 14:50:13.85991+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
15	MMU-ROORKEE-03	mmu	1	MMU-Roorkee-03	17	61	101	\N	29.87	77.892	UK 08 CD 4321	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:28:25.630716+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
8	MMU-BHUBANESWAR-02	mmu	3	MMU-Bhubaneswar-02	11	\N	\N	\N	20.29	85.84	OD 02 MN 5555	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:21:51.929567+05:30	2026-08-10 11:29:37.399938+05:30	2026-08-10 11:29:37.399938+05:30	18	superseded by remapped demo geography	\N	\N
12	NASHIK-HEALTH-CENTRE	static_clinic	2	Nashik Health Centre	10	\N	\N	\N	19.997	73.79	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:21:51.929567+05:30	2026-08-10 11:29:37.399938+05:30	2026-08-10 11:29:37.399938+05:30	18	superseded by remapped demo geography	\N	\N
13	SURAT-HEALTH-POINT	static_clinic	2	Surat Health Point	5	\N	\N	\N	21.17	72.831	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:21:51.929567+05:30	2026-08-10 11:29:37.399938+05:30	2026-08-10 11:29:37.399938+05:30	18	superseded by remapped demo geography	\N	\N
14	MYSURU-CLINIC	static_clinic	3	Mysuru Clinic	8	\N	\N	\N	12.1	76.68	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 11:21:51.929567+05:30	2026-08-10 11:29:37.399938+05:30	2026-08-10 11:29:37.399938+05:30	18	superseded by remapped demo geography	\N	\N
25	MMU-TEST-946	mmu	1	MMU-Test-946	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 16:56:48.600223+05:30	2026-08-10 16:56:48.838893+05:30	2026-08-10 16:56:48.838893+05:30	17	test	\N	\N
26	CLINIC-TEST-946	static_clinic	1	Clinic-Test-946	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 16:56:48.804985+05:30	2026-08-10 16:56:48.838893+05:30	2026-08-10 16:56:48.838893+05:30	17	test	\N	\N
35	MMU-TEST-941	mmu	1	MMU-Test-941	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:31:47.392948+05:30	2026-08-10 17:31:47.595813+05:30	2026-08-10 17:31:47.595813+05:30	17	test	\N	\N
36	CLINIC-TEST-941	static_clinic	1	Clinic-Test-941	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:31:47.538986+05:30	2026-08-10 17:31:47.595813+05:30	2026-08-10 17:31:47.595813+05:30	17	test	\N	\N
37	MMU-TEST-979	mmu	1	MMU-Test-979	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:35:13.948359+05:30	2026-08-10 17:35:14.665509+05:30	2026-08-10 17:35:14.665509+05:30	17	test	\N	\N
38	CLINIC-TEST-979	static_clinic	1	Clinic-Test-979	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:35:14.380237+05:30	2026-08-10 17:35:14.665509+05:30	2026-08-10 17:35:14.665509+05:30	17	test	\N	\N
39	MMU-TEST-415	mmu	1	MMU-Test-415	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:39:24.936745+05:30	2026-08-10 17:39:25.176858+05:30	2026-08-10 17:39:25.176858+05:30	17	test	\N	\N
40	CLINIC-TEST-415	static_clinic	1	Clinic-Test-415	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:39:25.094062+05:30	2026-08-10 17:39:25.176858+05:30	2026-08-10 17:39:25.176858+05:30	17	test	\N	\N
41	MMU-TEST-130	mmu	1	MMU-Test-130	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:43:06.970937+05:30	2026-08-10 17:43:07.274222+05:30	2026-08-10 17:43:07.274222+05:30	17	test	\N	\N
42	CLINIC-TEST-130	static_clinic	1	Clinic-Test-130	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:43:07.19086+05:30	2026-08-10 17:43:07.274222+05:30	2026-08-10 17:43:07.274222+05:30	17	test	\N	\N
43	MMU-TEST-974	mmu	1	MMU-Test-974	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:53:06.757231+05:30	2026-08-10 17:53:07.032416+05:30	2026-08-10 17:53:07.032416+05:30	17	test	\N	\N
44	CLINIC-TEST-974	static_clinic	1	Clinic-Test-974	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 17:53:06.971388+05:30	2026-08-10 17:53:07.032416+05:30	2026-08-10 17:53:07.032416+05:30	17	test	\N	\N
85	CLINIC-TEST-860	static_clinic	1	Clinic-Test-860	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 21:48:58.602739+05:30	2026-08-10 21:48:58.71666+05:30	2026-08-10 21:48:58.71666+05:30	17	test	\N	\N
45	MMU-TEST-534	mmu	1	MMU-Test-534	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 18:00:24.486945+05:30	2026-08-10 18:00:24.672541+05:30	2026-08-10 18:00:24.672541+05:30	17	test	\N	\N
46	CLINIC-TEST-534	static_clinic	1	Clinic-Test-534	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 18:00:24.626154+05:30	2026-08-10 18:00:24.672541+05:30	2026-08-10 18:00:24.672541+05:30	17	test	\N	\N
47	MMU-TEST-579	mmu	1	MMU-Test-579	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 18:00:47.225602+05:30	2026-08-10 18:00:47.471142+05:30	2026-08-10 18:00:47.471142+05:30	17	test	\N	\N
48	CLINIC-TEST-579	static_clinic	1	Clinic-Test-579	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 18:00:47.404943+05:30	2026-08-10 18:00:47.471142+05:30	2026-08-10 18:00:47.471142+05:30	17	test	\N	\N
86	UNIT-TEST-3073	mmu	1	Unit Test 3073	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-10	active	2026-08-10 21:49:26.317856+05:30	2026-08-10 21:49:26.752408+05:30	2026-08-10 21:49:26.752408+05:30	18	created by a test	\N	\N
87	MMU-TEST-819	mmu	1	MMU-Test-819	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 09:30:19.555557+05:30	2026-08-11 09:30:19.951513+05:30	2026-08-11 09:30:19.951513+05:30	17	test	\N	\N
49	MMU-TEST-137	mmu	1	MMU-Test-137	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 19:16:24.477154+05:30	2026-08-10 19:16:25.04676+05:30	2026-08-10 19:16:25.04676+05:30	17	test	\N	\N
50	CLINIC-TEST-137	static_clinic	1	Clinic-Test-137	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 19:16:24.899461+05:30	2026-08-10 19:16:25.04676+05:30	2026-08-10 19:16:25.04676+05:30	17	test	\N	\N
88	CLINIC-TEST-819	static_clinic	1	Clinic-Test-819	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 09:30:19.828539+05:30	2026-08-11 09:30:19.951513+05:30	2026-08-11 09:30:19.951513+05:30	17	test	\N	\N
51	MMU-TEST-879	mmu	1	MMU-Test-879	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 19:16:48.315666+05:30	2026-08-10 19:16:48.904137+05:30	2026-08-10 19:16:48.904137+05:30	17	test	\N	\N
52	CLINIC-TEST-879	static_clinic	1	Clinic-Test-879	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 19:16:48.548525+05:30	2026-08-10 19:16:48.904137+05:30	2026-08-10 19:16:48.904137+05:30	17	test	\N	\N
53	MMU-TEST-411	mmu	1	MMU-Test-411	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 19:35:58.399828+05:30	2026-08-10 19:35:59.285512+05:30	2026-08-10 19:35:59.285512+05:30	17	test	\N	\N
54	CLINIC-TEST-411	static_clinic	1	Clinic-Test-411	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 19:35:59.152305+05:30	2026-08-10 19:35:59.285512+05:30	2026-08-10 19:35:59.285512+05:30	17	test	\N	\N
55	MMU-TEST-330	mmu	1	MMU-Test-330	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 19:39:51.438857+05:30	2026-08-10 19:39:51.841343+05:30	2026-08-10 19:39:51.841343+05:30	17	test	\N	\N
56	CLINIC-TEST-330	static_clinic	1	Clinic-Test-330	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 19:39:51.759452+05:30	2026-08-10 19:39:51.841343+05:30	2026-08-10 19:39:51.841343+05:30	17	test	\N	\N
57	MMU-TEST-399	mmu	1	MMU-Test-399	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 19:41:19.683548+05:30	2026-08-10 19:41:19.967237+05:30	2026-08-10 19:41:19.967237+05:30	17	test	\N	\N
58	CLINIC-TEST-399	static_clinic	1	Clinic-Test-399	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 19:41:19.886747+05:30	2026-08-10 19:41:19.967237+05:30	2026-08-10 19:41:19.967237+05:30	17	test	\N	\N
59	UNIT-TEST-1531	mmu	1	Unit Test 1531	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-10	active	2026-08-10 19:41:43.322836+05:30	2026-08-10 19:41:43.747575+05:30	2026-08-10 19:41:43.747575+05:30	18	created by a test	\N	\N
60	MMU-TEST-214	mmu	1	MMU-Test-214	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 19:41:59.539009+05:30	2026-08-10 19:41:59.806832+05:30	2026-08-10 19:41:59.806832+05:30	17	test	\N	\N
61	CLINIC-TEST-214	static_clinic	1	Clinic-Test-214	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 19:41:59.734014+05:30	2026-08-10 19:41:59.806832+05:30	2026-08-10 19:41:59.806832+05:30	17	test	\N	\N
65	UNIT-TEST-5563	mmu	1	Unit Test 5563	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-10	active	2026-08-10 20:19:24.611793+05:30	2026-08-10 20:19:24.986+05:30	2026-08-10 20:19:24.986+05:30	18	created by a test	\N	\N
62	UNIT-TEST-6447	mmu	1	Unit Test 6447	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-10	active	2026-08-10 19:42:23.709446+05:30	2026-08-10 19:42:24.087678+05:30	2026-08-10 19:42:24.087678+05:30	18	created by a test	\N	\N
63	MMU-TEST-855	mmu	1	MMU-Test-855	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 20:19:03.816426+05:30	2026-08-10 20:19:04.125458+05:30	2026-08-10 20:19:04.125458+05:30	17	test	\N	\N
64	CLINIC-TEST-855	static_clinic	1	Clinic-Test-855	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 20:19:04.045762+05:30	2026-08-10 20:19:04.125458+05:30	2026-08-10 20:19:04.125458+05:30	17	test	\N	\N
66	MMU-TEST-413	mmu	1	MMU-Test-413	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 20:22:59.451097+05:30	2026-08-10 20:22:59.822418+05:30	2026-08-10 20:22:59.822418+05:30	17	test	\N	\N
67	CLINIC-TEST-413	static_clinic	1	Clinic-Test-413	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 20:22:59.65714+05:30	2026-08-10 20:22:59.822418+05:30	2026-08-10 20:22:59.822418+05:30	17	test	\N	\N
74	UNIT-TEST-1896	mmu	1	Unit Test 1896	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-10	active	2026-08-10 20:48:08.481683+05:30	2026-08-10 20:48:08.797609+05:30	2026-08-10 20:48:08.797609+05:30	18	created by a test	\N	\N
68	UNIT-TEST-2851	mmu	1	Unit Test 2851	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-10	active	2026-08-10 20:23:25.660969+05:30	2026-08-10 20:23:26.56907+05:30	2026-08-10 20:23:26.56907+05:30	18	created by a test	\N	\N
69	MMU-TEST-287	mmu	1	MMU-Test-287	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 20:34:39.643698+05:30	2026-08-10 20:34:40.218283+05:30	2026-08-10 20:34:40.218283+05:30	17	test	\N	\N
70	CLINIC-TEST-287	static_clinic	1	Clinic-Test-287	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 20:34:39.788313+05:30	2026-08-10 20:34:40.218283+05:30	2026-08-10 20:34:40.218283+05:30	17	test	\N	\N
71	UNIT-TEST-3408	mmu	1	Unit Test 3408	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-10	active	2026-08-10 20:35:01.261967+05:30	2026-08-10 20:35:01.787996+05:30	2026-08-10 20:35:01.787996+05:30	18	created by a test	\N	\N
72	MMU-TEST-856	mmu	1	MMU-Test-856	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 20:47:45.935699+05:30	2026-08-10 20:47:46.22112+05:30	2026-08-10 20:47:46.22112+05:30	17	test	\N	\N
73	CLINIC-TEST-856	static_clinic	1	Clinic-Test-856	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 20:47:46.135506+05:30	2026-08-10 20:47:46.22112+05:30	2026-08-10 20:47:46.22112+05:30	17	test	\N	\N
75	MMU-TEST-716	mmu	1	MMU-Test-716	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 21:13:54.514732+05:30	2026-08-10 21:13:54.765444+05:30	2026-08-10 21:13:54.765444+05:30	17	test	\N	\N
76	CLINIC-TEST-716	static_clinic	1	Clinic-Test-716	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 21:13:54.692243+05:30	2026-08-10 21:13:54.765444+05:30	2026-08-10 21:13:54.765444+05:30	17	test	\N	\N
78	MMU-TEST-988	mmu	1	MMU-Test-988	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 21:20:17.248718+05:30	2026-08-10 21:20:17.455647+05:30	2026-08-10 21:20:17.455647+05:30	17	test	\N	\N
79	CLINIC-TEST-988	static_clinic	1	Clinic-Test-988	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 21:20:17.399373+05:30	2026-08-10 21:20:17.455647+05:30	2026-08-10 21:20:17.455647+05:30	17	test	\N	\N
77	UNIT-TEST-8935	mmu	1	Unit Test 8935	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-10	active	2026-08-10 21:14:29.142453+05:30	2026-08-10 21:14:29.662825+05:30	2026-08-10 21:14:29.662825+05:30	18	created by a test	\N	\N
80	UNIT-TEST-1258	mmu	1	Unit Test 1258	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-10	active	2026-08-10 21:20:45.101749+05:30	2026-08-10 21:20:45.55425+05:30	2026-08-10 21:20:45.55425+05:30	18	created by a test	\N	\N
81	MMU-TEST-353	mmu	1	MMU-Test-353	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-10	active	2026-08-10 21:38:27.585982+05:30	2026-08-10 21:38:27.911053+05:30	2026-08-10 21:38:27.911053+05:30	17	test	\N	\N
82	CLINIC-TEST-353	static_clinic	1	Clinic-Test-353	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-10	active	2026-08-10 21:38:27.814332+05:30	2026-08-10 21:38:27.911053+05:30	2026-08-10 21:38:27.911053+05:30	17	test	\N	\N
83	UNIT-TEST-9396	mmu	1	Unit Test 9396	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-10	active	2026-08-10 21:38:59.253809+05:30	2026-08-10 21:39:00.025522+05:30	2026-08-10 21:39:00.025522+05:30	18	created by a test	\N	\N
89	UNIT-TEST-2344	mmu	1	Unit Test 2344	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 09:30:44.817842+05:30	2026-08-11 09:30:45.197055+05:30	2026-08-11 09:30:45.197055+05:30	18	created by a test	\N	\N
90	MMU-TEST-468	mmu	1	MMU-Test-468	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 09:36:19.877068+05:30	2026-08-11 09:36:20.360277+05:30	2026-08-11 09:36:20.360277+05:30	17	test	\N	\N
91	CLINIC-TEST-468	static_clinic	1	Clinic-Test-468	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 09:36:20.19015+05:30	2026-08-11 09:36:20.360277+05:30	2026-08-11 09:36:20.360277+05:30	17	test	\N	\N
107	CLINIC-TEST-222	static_clinic	1	Clinic-Test-222	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:04:22.348086+05:30	2026-08-11 14:04:22.470311+05:30	2026-08-11 14:04:22.470311+05:30	17	test	\N	\N
106	MMU-TEST-222	mmu	1	MMU-Test-222	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:04:22.131926+05:30	2026-08-11 14:04:22.470311+05:30	2026-08-11 14:04:22.470311+05:30	17	test	\N	\N
92	UNIT-TEST-8433	mmu	1	Unit Test 8433	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 09:36:41.833696+05:30	2026-08-11 09:36:42.295497+05:30	2026-08-11 09:36:42.295497+05:30	18	created by a test	\N	\N
93	SDDDDD	mmu	1	sddddd	2	3	3	\N	\N	\N	\N	\N	#e91e63	\N	\N	\N	\N	2026-08-11	active	2026-08-11 09:41:00.818793+05:30	2026-08-11 09:41:36.401951+05:30	2026-08-11 09:41:36.401951+05:30	18	dscdsc	\N	\N
94	MMU-TEST-340	mmu	1	MMU-Test-340	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 09:52:20.384977+05:30	2026-08-11 09:52:20.647479+05:30	2026-08-11 09:52:20.647479+05:30	17	test	\N	\N
95	CLINIC-TEST-340	static_clinic	1	Clinic-Test-340	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 09:52:20.605055+05:30	2026-08-11 09:52:20.647479+05:30	2026-08-11 09:52:20.647479+05:30	17	test	\N	\N
96	UNIT-TEST-3069	mmu	1	Unit Test 3069	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 09:52:41.49907+05:30	2026-08-11 09:52:41.881504+05:30	2026-08-11 09:52:41.881504+05:30	18	created by a test	\N	\N
97	MMU-TEST-590	mmu	1	MMU-Test-590	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 11:14:14.997628+05:30	2026-08-11 11:14:15.428158+05:30	2026-08-11 11:14:15.428158+05:30	17	test	\N	\N
98	CLINIC-TEST-590	static_clinic	1	Clinic-Test-590	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 11:14:15.351747+05:30	2026-08-11 11:14:15.428158+05:30	2026-08-11 11:14:15.428158+05:30	17	test	\N	\N
108	MMU-TEST-839	mmu	1	MMU-Test-839	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:04:41.396925+05:30	2026-08-11 14:04:41.597186+05:30	2026-08-11 14:04:41.597186+05:30	17	test	\N	\N
109	CLINIC-TEST-839	static_clinic	1	Clinic-Test-839	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:04:41.534243+05:30	2026-08-11 14:04:41.597186+05:30	2026-08-11 14:04:41.597186+05:30	17	test	\N	\N
99	UNIT-TEST-2432	mmu	1	Unit Test 2432	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 11:14:33.302707+05:30	2026-08-11 11:14:33.670572+05:30	2026-08-11 11:14:33.670572+05:30	18	created by a test	\N	\N
100	MMU-TEST-750	mmu	1	MMU-Test-750	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 13:59:33.600731+05:30	2026-08-11 13:59:33.912459+05:30	2026-08-11 13:59:33.912459+05:30	17	test	\N	\N
101	CLINIC-TEST-750	static_clinic	1	Clinic-Test-750	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 13:59:33.855088+05:30	2026-08-11 13:59:33.912459+05:30	2026-08-11 13:59:33.912459+05:30	17	test	\N	\N
116	UNIT-TEST-7237	mmu	1	Unit Test 7237	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:06:10.843777+05:30	2026-08-11 14:06:11.310094+05:30	2026-08-11 14:06:11.310094+05:30	18	created by a test	\N	\N
102	UNIT-TEST-3992	mmu	1	Unit Test 3992	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 13:59:52.104555+05:30	2026-08-11 13:59:52.416126+05:30	2026-08-11 13:59:52.416126+05:30	18	created by a test	\N	\N
103	MMU-TEST-576	mmu	1	MMU-Test-576	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:03:16.312998+05:30	2026-08-11 14:03:16.469091+05:30	2026-08-11 14:03:16.469091+05:30	17	test	\N	\N
104	CLINIC-TEST-576	static_clinic	1	Clinic-Test-576	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:03:16.42049+05:30	2026-08-11 14:03:16.469091+05:30	2026-08-11 14:03:16.469091+05:30	17	test	\N	\N
110	UNIT-TEST-3907	mmu	1	Unit Test 3907	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:04:59.769724+05:30	2026-08-11 14:05:00.158973+05:30	2026-08-11 14:05:00.158973+05:30	18	created by a test	\N	\N
105	UNIT-TEST-2863	mmu	1	Unit Test 2863	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:03:34.21599+05:30	2026-08-11 14:03:34.618705+05:30	2026-08-11 14:03:34.618705+05:30	18	created by a test	\N	\N
111	MMU-TEST-732	mmu	1	MMU-Test-732	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:05:10.566538+05:30	2026-08-11 14:05:11.017143+05:30	2026-08-11 14:05:11.017143+05:30	17	test	\N	\N
112	CLINIC-TEST-732	static_clinic	1	Clinic-Test-732	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:05:10.891963+05:30	2026-08-11 14:05:11.017143+05:30	2026-08-11 14:05:11.017143+05:30	17	test	\N	\N
117	MMU-TEST-166	mmu	1	MMU-Test-166	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:06:21.292979+05:30	2026-08-11 14:06:21.500513+05:30	2026-08-11 14:06:21.500513+05:30	17	test	\N	\N
113	UNIT-TEST-1188	mmu	1	Unit Test 1188	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:05:29.378411+05:30	2026-08-11 14:05:29.673509+05:30	2026-08-11 14:05:29.673509+05:30	18	created by a test	\N	\N
114	MMU-TEST-394	mmu	1	MMU-Test-394	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:05:52.216853+05:30	2026-08-11 14:05:52.408648+05:30	2026-08-11 14:05:52.408648+05:30	17	test	\N	\N
115	CLINIC-TEST-394	static_clinic	1	Clinic-Test-394	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:05:52.340318+05:30	2026-08-11 14:05:52.408648+05:30	2026-08-11 14:05:52.408648+05:30	17	test	\N	\N
118	CLINIC-TEST-166	static_clinic	1	Clinic-Test-166	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:06:21.426019+05:30	2026-08-11 14:06:21.500513+05:30	2026-08-11 14:06:21.500513+05:30	17	test	\N	\N
150	CLINIC-TEST-127	static_clinic	1	Clinic-Test-127	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:26:36.847178+05:30	2026-08-11 14:26:36.952667+05:30	2026-08-11 14:26:36.952667+05:30	17	test	\N	\N
122	UNIT-TEST-4710	mmu	1	Unit Test 4710	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:07:11.28512+05:30	2026-08-11 14:07:11.748833+05:30	2026-08-11 14:07:11.748833+05:30	18	created by a test	\N	\N
119	UNIT-TEST-9142	mmu	1	Unit Test 9142	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:06:40.09857+05:30	2026-08-11 14:06:40.516255+05:30	2026-08-11 14:06:40.516255+05:30	18	created by a test	\N	\N
120	MMU-TEST-717	mmu	1	MMU-Test-717	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:06:51.023103+05:30	2026-08-11 14:06:51.277358+05:30	2026-08-11 14:06:51.277358+05:30	17	test	\N	\N
121	CLINIC-TEST-717	static_clinic	1	Clinic-Test-717	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:06:51.218259+05:30	2026-08-11 14:06:51.277358+05:30	2026-08-11 14:06:51.277358+05:30	17	test	\N	\N
146	MMU-TEST-618	mmu	1	MMU-Test-618	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:20:42.546146+05:30	2026-08-11 14:20:42.969424+05:30	2026-08-11 14:20:42.969424+05:30	17	test	\N	\N
147	CLINIC-TEST-618	static_clinic	1	Clinic-Test-618	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:20:42.872712+05:30	2026-08-11 14:20:42.969424+05:30	2026-08-11 14:20:42.969424+05:30	17	test	\N	\N
148	UNIT-TEST-9296	mmu	1	Unit Test 9296	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:21:05.932144+05:30	2026-08-11 14:21:06.424712+05:30	2026-08-11 14:21:06.424712+05:30	18	created by a test	\N	\N
149	MMU-TEST-127	mmu	1	MMU-Test-127	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:26:36.602585+05:30	2026-08-11 14:26:36.952667+05:30	2026-08-11 14:26:36.952667+05:30	17	test	\N	\N
151	UNIT-TEST-2921	mmu	1	Unit Test 2921	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:26:58.611969+05:30	2026-08-11 14:26:59.155001+05:30	2026-08-11 14:26:59.155001+05:30	18	created by a test	\N	\N
152	MMU-TEST-656	mmu	1	MMU-Test-656	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:31:18.905536+05:30	2026-08-11 14:31:19.113944+05:30	2026-08-11 14:31:19.113944+05:30	17	test	\N	\N
153	CLINIC-TEST-656	static_clinic	1	Clinic-Test-656	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:31:19.045876+05:30	2026-08-11 14:31:19.113944+05:30	2026-08-11 14:31:19.113944+05:30	17	test	\N	\N
154	UNIT-TEST-1322	mmu	1	Unit Test 1322	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:31:39.948832+05:30	2026-08-11 14:31:40.346745+05:30	2026-08-11 14:31:40.346745+05:30	18	created by a test	\N	\N
155	MMU-TEST-800	mmu	1	MMU-Test-800	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:32:27.228357+05:30	2026-08-11 14:32:27.614669+05:30	2026-08-11 14:32:27.614669+05:30	17	test	\N	\N
156	CLINIC-TEST-800	static_clinic	1	Clinic-Test-800	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:32:27.387752+05:30	2026-08-11 14:32:27.614669+05:30	2026-08-11 14:32:27.614669+05:30	17	test	\N	\N
157	UNIT-TEST-9348	mmu	1	Unit Test 9348	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 14:32:47.706216+05:30	2026-08-11 14:32:48.105592+05:30	2026-08-11 14:32:48.105592+05:30	18	created by a test	\N	\N
158	MMU-TEST-870	mmu	1	MMU-Test-870	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 15:10:11.215023+05:30	2026-08-11 15:10:11.563585+05:30	2026-08-11 15:10:11.563585+05:30	17	test	\N	\N
159	CLINIC-TEST-870	static_clinic	1	Clinic-Test-870	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 15:10:11.450138+05:30	2026-08-11 15:10:11.563585+05:30	2026-08-11 15:10:11.563585+05:30	17	test	\N	\N
160	UNIT-TEST-7373	mmu	1	Unit Test 7373	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 15:10:30.815605+05:30	2026-08-11 15:10:31.19442+05:30	2026-08-11 15:10:31.19442+05:30	18	created by a test	\N	\N
161	MMU-TEST-364	mmu	1	MMU-Test-364	16	48	83	\N	\N	\N	\N	\N	#FF0000	\N	\N	\N	\N	2026-08-11	active	2026-08-11 15:54:06.664273+05:30	2026-08-11 15:54:06.905536+05:30	2026-08-11 15:54:06.905536+05:30	17	test	\N	\N
162	CLINIC-TEST-364	static_clinic	1	Clinic-Test-364	16	48	83	\N	28.85	78.26	\N	\N	\N	\N	\N	\N	\N	2026-08-11	active	2026-08-11 15:54:06.815617+05:30	2026-08-11 15:54:06.905536+05:30	2026-08-11 15:54:06.905536+05:30	17	test	\N	\N
163	UNIT-TEST-3054	mmu	1	Unit Test 3054	1	1	1	\N	\N	\N	\N	\N	#00A8E8	\N	\N	\N	\N	2026-08-11	active	2026-08-11 15:54:26.690211+05:30	2026-08-11 15:54:27.233293+05:30	2026-08-11 15:54:27.233293+05:30	18	created by a test	\N	\N
\.


--
-- TOC entry 5892 (class 0 OID 30823)
-- Dependencies: 253
-- Data for Name: lab_test_master; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.lab_test_master (lab_test_id, test_name, category, is_active, price) FROM stdin;
1	CBC	Blood	t	150.00
2	Lipid Profile	Blood	t	500.00
3	Kidney Profile	Blood	t	600.00
4	Liver Profile	Blood	t	600.00
5	B.sugar	Blood	t	60.00
6	HB	Blood	t	150.00
7	ESR	Blood	t	100.00
8	Blood Group	Blood	t	100.00
9	Urine R/E	Urine	t	150.00
10	Dengue Test	Blood	t	600.00
11	Malaria Smear	Blood	t	200.00
12	Platelets Count	Blood	t	150.00
13	NS1 Antigen	Blood	t	150.00
14	ANC Profile	Blood	t	150.00
15	CRP	Blood	t	150.00
16	HbA1c	Blood	t	450.00
17	Stool Test	Other	t	150.00
18	ECG	ECG	t	250.00
19	X-Ray	Imaging	t	300.00
\.


--
-- TOC entry 5882 (class 0 OID 30706)
-- Dependencies: 243
-- Data for Name: leave_record; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.leave_record (leave_id, staff_id, from_date, to_date, reason, replacement_staff_id, status, created_at, deleted_at, deleted_by, delete_reason) FROM stdin;
69	214	2026-08-14	2026-08-16	Family function	247	Leave	2026-08-11 15:54:08.312226+05:30	\N	\N	\N
\.


--
-- TOC entry 5890 (class 0 OID 30807)
-- Dependencies: 251
-- Data for Name: medicine_master; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.medicine_master (medicine_id, medicine_name, strength, form, is_active) FROM stdin;
1	T.Paracetamol	500 mg	Tablet	t
2	T.Paracetamol	650 mg	Tablet	t
3	T.Cetirizine	10mg	Tablet	t
4	T.Calcium		Tablet	t
5	T.Ciprofloxacin	500 mg	Tablet	t
6	T.Doxycycline	100 mg	Tablet	t
7	T.Ofloxacin	200 mg	Tablet	t
8	T.Metronidazole	400 mg	Tablet	t
9	T.Cefixime	200mg	Tablet	t
10	Cap.Pantoprazole	40 mg	Capsule	t
11	T.Domperidone	10mg	Tablet	t
12	T.Amlodipine	5mg	Tablet	t
13	T.Metformin	500 mg	Tablet	t
14	T.B-Complex		Tablet	t
15	T.IFA		Tablet	t
16	T.Azithromycin	500 mg	Tablet	t
17	T.Amoxicillin	500 mg	Tablet	t
18	ORS Sachets		Sachet	t
19	Syp.Amoxycillin		Syrup	t
20	Syp.Cefixime		Syrup	t
21	Syp.PCM		Syrup	t
22	Syp.Cetirizine		Syrup	t
23	E/d.Ciplox		Eye Drops	t
24	Oint.Betadine		Ointment	t
25	Cream Clotrimazole		Cream	t
26	Lotion Calamine		Lotion	t
27	Tab.Telmisartan	40mg	Tablet	t
28	Cap.Vitamin D3	60000 IU	Capsule	t
29	Zinc	20mg	\N	t
30	Nitrofurantoin	100mg	\N	t
31	Ondansetron	4mg	\N	t
32	Ambroxol	30mg	\N	t
\.


--
-- TOC entry 5931 (class 0 OID 31679)
-- Dependencies: 292
-- Data for Name: migration_quarantine; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.migration_quarantine (quarantine_id, target_table, legacy_source, legacy_id, payload, error_message, error_detail, resolved, resolved_at, created_at) FROM stdin;
\.


--
-- TOC entry 5933 (class 0 OID 31698)
-- Dependencies: 294
-- Data for Name: migration_run; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.migration_run (run_id, source_system, target_table, started_at, finished_at, rows_read, rows_loaded, rows_quarantined, notes) FROM stdin;
\.


--
-- TOC entry 5927 (class 0 OID 31431)
-- Dependencies: 288
-- Data for Name: mmu_current_position; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.mmu_current_position (facility_id, latitude, longitude, accuracy_meters, recorded_at, updated_at) FROM stdin;
\.


--
-- TOC entry 5926 (class 0 OID 31406)
-- Dependencies: 287
-- Data for Name: mmu_location_track; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.mmu_location_track (track_id, facility_id, user_id, latitude, longitude, accuracy_meters, recorded_at, received_at) FROM stdin;
\.


--
-- TOC entry 5874 (class 0 OID 30605)
-- Dependencies: 235
-- Data for Name: mmu_route_stop; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.mmu_route_stop (route_stop_id, facility_id, stop_seq, location_name, latitude, longitude, visit_date, patient_count, deleted_at, deleted_by, delete_reason) FROM stdin;
\.


--
-- TOC entry 5862 (class 0 OID 30448)
-- Dependencies: 223
-- Data for Name: offer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.offer (offer_id, offer_code, description, discount_pct, valid_from, valid_to, applies_to, status, created_at, deleted_at, deleted_by, delete_reason) FROM stdin;
1	LAUNCH25	Launch discount	25.00	2026-08-01	2026-12-31	standalone_clinic	active	2026-08-10 22:01:37.222742+05:30	\N	\N	\N
\.


--
-- TOC entry 5859 (class 0 OID 30406)
-- Dependencies: 220
-- Data for Name: organization; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.organization (org_id, org_code, org_name, contact_email, joined_date, status, logo_color, created_at, updated_at, deleted_at, deleted_by, delete_reason, legacy_id, legacy_source) FROM stdin;
37	D527	Dash Test 527	x@test.org	2026-08-10	active	\N	2026-08-10 20:22:54.772977+05:30	2026-08-10 20:22:54.772977+05:30	\N	\N	\N	\N	\N
46	CRUD9285	CRUD Renamed 9285	a@b.org	2026-08-10	active	\N	2026-08-10 21:20:38.90918+05:30	2026-08-10 21:20:43.692+05:30	2026-08-10 21:20:43.692+05:30	17	test organisation	\N	\N
47	D816	Dash Test 816	x@test.org	2026-08-10	active	\N	2026-08-10 21:38:18.91855+05:30	2026-08-10 21:38:18.91855+05:30	\N	\N	\N	\N	\N
38	CRUD7298	CRUD Renamed 7298	a@b.org	2026-08-10	active	\N	2026-08-10 20:23:19.86681+05:30	2026-08-10 20:23:24.149959+05:30	2026-08-10 20:23:24.149959+05:30	17	test organisation	\N	\N
39	D961	Dash Test 961	x@test.org	2026-08-10	active	\N	2026-08-10 20:34:35.728893+05:30	2026-08-10 20:34:35.728893+05:30	\N	\N	\N	\N	\N
1	JC	JubiCare	contact@jubicare.in	2026-08-03	active	#007FB5	2026-08-03 14:50:13.85991+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
2	RF	Reliance Foundation	health@reliancefoundation.org	2024-01-15	active	#0B2E5C	2026-08-10 11:21:51.929567+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
3	TT	Tata Trusts	contact@tatatrusts.org	2024-06-20	active	#E91E63	2026-08-10 11:21:51.929567+05:30	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
4	FGDF	Indev abc test	hovep98526@modirosa.com	2026-08-10	active	#00a8e8	2026-08-10 15:56:55.674734+05:30	2026-08-10 15:56:55.674734+05:30	\N	\N	\N	\N	\N
5	T992	Test Foundation 992	x@test.org	2026-08-10	active	\N	2026-08-10 16:31:35.445055+05:30	2026-08-10 16:37:38.298323+05:30	2026-08-10 16:37:38.298323+05:30	17	test organisation	\N	\N
6	Q518	Quick Org 518	\N	2026-08-10	active	\N	2026-08-10 16:32:02.324839+05:30	2026-08-10 16:37:38.298323+05:30	2026-08-10 16:37:38.298323+05:30	17	test organisation	\N	\N
7	D723	Dash Test 723	x@test.org	2026-08-10	active	\N	2026-08-10 16:34:54.781954+05:30	2026-08-10 16:37:38.298323+05:30	2026-08-10 16:37:38.298323+05:30	17	test organisation	\N	\N
8	D929	Dash Test 929	x@test.org	2026-08-10	active	\N	2026-08-10 16:35:03.492904+05:30	2026-08-10 16:37:38.298323+05:30	2026-08-10 16:37:38.298323+05:30	17	test organisation	\N	\N
9	D839	Dash Test 839	x@test.org	2026-08-10	active	\N	2026-08-10 16:36:29.392392+05:30	2026-08-10 16:37:38.298323+05:30	2026-08-10 16:37:38.298323+05:30	17	test organisation	\N	\N
10	D373	Dash Test 373	x@test.org	2026-08-10	active	\N	2026-08-10 16:38:31.467467+05:30	2026-08-10 16:38:31.467467+05:30	\N	\N	\N	\N	\N
11	D	demo	vikash.cprindev@gmail.com	2026-08-10	active	#00a8e8	2026-08-10 16:40:13.099778+05:30	2026-08-10 16:40:13.099778+05:30	\N	\N	\N	\N	\N
12	D721	Dash Test 721	x@test.org	2026-08-10	active	\N	2026-08-10 16:51:31.021166+05:30	2026-08-10 16:51:31.021166+05:30	\N	\N	\N	\N	\N
13	D740	Dash Test 740	x@test.org	2026-08-10	active	\N	2026-08-10 16:56:45.384598+05:30	2026-08-10 16:56:45.384598+05:30	\N	\N	\N	\N	\N
14	D612	Dash Test 612	x@test.org	2026-08-10	active	\N	2026-08-10 16:57:19.007864+05:30	2026-08-10 16:57:19.007864+05:30	\N	\N	\N	\N	\N
15	D810	Dash Test 810	x@test.org	2026-08-10	active	\N	2026-08-10 17:14:07.861222+05:30	2026-08-10 17:14:07.861222+05:30	\N	\N	\N	\N	\N
16	D113	Dash Test 113	x@test.org	2026-08-10	active	\N	2026-08-10 17:14:58.249277+05:30	2026-08-10 17:14:58.249277+05:30	\N	\N	\N	\N	\N
17	D792	Dash Test 792	x@test.org	2026-08-10	active	\N	2026-08-10 17:31:10.453759+05:30	2026-08-10 17:31:10.453759+05:30	\N	\N	\N	\N	\N
18	D797	Dash Test 797	x@test.org	2026-08-10	active	\N	2026-08-10 17:31:43.59525+05:30	2026-08-10 17:31:43.59525+05:30	\N	\N	\N	\N	\N
19	D421	Dash Test 421	x@test.org	2026-08-10	active	\N	2026-08-10 17:35:06.947003+05:30	2026-08-10 17:35:06.947003+05:30	\N	\N	\N	\N	\N
20	D843	Dash Test 843	x@test.org	2026-08-10	active	\N	2026-08-10 17:39:17.904567+05:30	2026-08-10 17:39:17.904567+05:30	\N	\N	\N	\N	\N
21	D885	Dash Test 885	x@test.org	2026-08-10	active	\N	2026-08-10 17:43:03.26788+05:30	2026-08-10 17:43:03.26788+05:30	\N	\N	\N	\N	\N
22	D201	Dash Test 201	x@test.org	2026-08-10	active	\N	2026-08-10 17:53:02.095128+05:30	2026-08-10 17:53:02.095128+05:30	\N	\N	\N	\N	\N
23	D198	Dash Test 198	x@test.org	2026-08-10	active	\N	2026-08-10 18:00:20.747394+05:30	2026-08-10 18:00:20.747394+05:30	\N	\N	\N	\N	\N
24	D623	Dash Test 623	x@test.org	2026-08-10	active	\N	2026-08-10 18:00:43.44851+05:30	2026-08-10 18:00:43.44851+05:30	\N	\N	\N	\N	\N
25	D914	Dash Test 914	x@test.org	2026-08-10	active	\N	2026-08-10 19:16:20.186717+05:30	2026-08-10 19:16:20.186717+05:30	\N	\N	\N	\N	\N
26	D574	Dash Test 574	x@test.org	2026-08-10	active	\N	2026-08-10 19:16:44.372768+05:30	2026-08-10 19:16:44.372768+05:30	\N	\N	\N	\N	\N
27	D390	Dash Test 390	x@test.org	2026-08-10	active	\N	2026-08-10 19:35:54.03427+05:30	2026-08-10 19:35:54.03427+05:30	\N	\N	\N	\N	\N
28	CRUD4544	CRUD Test 4544	a@b.org	2026-08-10	active	\N	2026-08-10 19:36:21.277312+05:30	2026-08-10 19:36:21.277312+05:30	\N	\N	\N	\N	\N
29	D869	Dash Test 869	x@test.org	2026-08-10	active	\N	2026-08-10 19:39:46.448413+05:30	2026-08-10 19:39:46.448413+05:30	\N	\N	\N	\N	\N
30	CRUD2242	CRUD Renamed 2242	a@b.org	2026-08-10	active	\N	2026-08-10 19:40:12.716837+05:30	2026-08-10 19:40:17.155697+05:30	2026-08-10 19:40:17.155697+05:30	17	test organisation	\N	\N
31	D286	Dash Test 286	x@test.org	2026-08-10	active	\N	2026-08-10 19:41:15.783799+05:30	2026-08-10 19:41:15.783799+05:30	\N	\N	\N	\N	\N
32	CRUD1275	CRUD Renamed 1275	a@b.org	2026-08-10	active	\N	2026-08-10 19:41:38.299979+05:30	2026-08-10 19:41:42.120512+05:30	2026-08-10 19:41:42.120512+05:30	17	test organisation	\N	\N
33	D964	Dash Test 964	x@test.org	2026-08-10	active	\N	2026-08-10 19:41:55.257426+05:30	2026-08-10 19:41:55.257426+05:30	\N	\N	\N	\N	\N
40	CRUD7978	CRUD Renamed 7978	a@b.org	2026-08-10	active	\N	2026-08-10 20:34:56.719222+05:30	2026-08-10 20:35:00.267243+05:30	2026-08-10 20:35:00.267243+05:30	17	test organisation	\N	\N
41	D142	Dash Test 142	x@test.org	2026-08-10	active	\N	2026-08-10 20:47:42.076928+05:30	2026-08-10 20:47:42.076928+05:30	\N	\N	\N	\N	\N
34	CRUD8568	CRUD Renamed 8568	a@b.org	2026-08-10	active	\N	2026-08-10 19:42:18.333341+05:30	2026-08-10 19:42:22.507677+05:30	2026-08-10 19:42:22.507677+05:30	17	test organisation	\N	\N
35	D355	Dash Test 355	x@test.org	2026-08-10	active	\N	2026-08-10 20:19:00.451447+05:30	2026-08-10 20:19:00.451447+05:30	\N	\N	\N	\N	\N
36	CRUD3668	CRUD Renamed 3668	a@b.org	2026-08-10	active	\N	2026-08-10 20:19:20.185583+05:30	2026-08-10 20:19:23.671355+05:30	2026-08-10 20:19:23.671355+05:30	17	test organisation	\N	\N
52	CRUD7243	CRUD Renamed 7243	a@b.org	2026-08-11	active	\N	2026-08-11 09:30:40.021276+05:30	2026-08-11 09:30:43.656861+05:30	2026-08-11 09:30:43.656861+05:30	17	test organisation	\N	\N
53	D749	Dash Test 749	x@test.org	2026-08-11	active	\N	2026-08-11 09:36:16.357+05:30	2026-08-11 09:36:16.357+05:30	\N	\N	\N	\N	\N
42	CRUD2129	CRUD Renamed 2129	a@b.org	2026-08-10	active	\N	2026-08-10 20:48:03.34152+05:30	2026-08-10 20:48:07.33962+05:30	2026-08-10 20:48:07.33962+05:30	17	test organisation	\N	\N
43	D688	Dash Test 688	x@test.org	2026-08-10	active	\N	2026-08-10 21:13:46.917006+05:30	2026-08-10 21:13:46.917006+05:30	\N	\N	\N	\N	\N
48	CRUD1459	CRUD Renamed 1459	a@b.org	2026-08-10	active	\N	2026-08-10 21:38:53.170588+05:30	2026-08-10 21:38:57.853328+05:30	2026-08-10 21:38:57.853328+05:30	17	test organisation	\N	\N
49	D157	Dash Test 157	x@test.org	2026-08-10	active	\N	2026-08-10 21:48:53.232982+05:30	2026-08-10 21:48:53.232982+05:30	\N	\N	\N	\N	\N
44	CRUD5742	CRUD Renamed 5742	a@b.org	2026-08-10	active	\N	2026-08-10 21:14:21.53515+05:30	2026-08-10 21:14:27.838607+05:30	2026-08-10 21:14:27.838607+05:30	17	test organisation	\N	\N
45	D441	Dash Test 441	x@test.org	2026-08-10	active	\N	2026-08-10 21:20:12.893808+05:30	2026-08-10 21:20:12.893808+05:30	\N	\N	\N	\N	\N
58	CRUD9166	CRUD Renamed 9166	a@b.org	2026-08-11	active	\N	2026-08-11 11:14:29.413818+05:30	2026-08-11 11:14:32.505059+05:30	2026-08-11 11:14:32.505059+05:30	17	test organisation	\N	\N
50	CRUD1726	CRUD Renamed 1726	a@b.org	2026-08-10	active	\N	2026-08-10 21:49:20.631167+05:30	2026-08-10 21:49:25.117913+05:30	2026-08-10 21:49:25.117913+05:30	17	test organisation	\N	\N
51	D462	Dash Test 462	x@test.org	2026-08-11	active	\N	2026-08-11 09:30:15.510638+05:30	2026-08-11 09:30:15.510638+05:30	\N	\N	\N	\N	\N
56	CRUD1330	CRUD Renamed 1330	a@b.org	2026-08-11	active	\N	2026-08-11 09:52:36.631711+05:30	2026-08-11 09:52:40.533903+05:30	2026-08-11 09:52:40.533903+05:30	17	test organisation	\N	\N
57	D617	Dash Test 617	x@test.org	2026-08-11	active	\N	2026-08-11 11:14:11.854487+05:30	2026-08-11 11:14:11.854487+05:30	\N	\N	\N	\N	\N
54	CRUD6889	CRUD Renamed 6889	a@b.org	2026-08-11	active	\N	2026-08-11 09:36:37.395252+05:30	2026-08-11 09:36:40.814985+05:30	2026-08-11 09:36:40.814985+05:30	17	test organisation	\N	\N
55	D806	Dash Test 806	x@test.org	2026-08-11	active	\N	2026-08-11 09:52:17.191376+05:30	2026-08-11 09:52:17.191376+05:30	\N	\N	\N	\N	\N
59	D514	Dash Test 514	x@test.org	2026-08-11	active	\N	2026-08-11 13:59:30.519097+05:30	2026-08-11 13:59:30.519097+05:30	\N	\N	\N	\N	\N
60	CRUD1973	CRUD Renamed 1973	a@b.org	2026-08-11	active	\N	2026-08-11 13:59:48.301404+05:30	2026-08-11 13:59:51.181182+05:30	2026-08-11 13:59:51.181182+05:30	17	test organisation	\N	\N
61	D641	Dash Test 641	x@test.org	2026-08-11	active	\N	2026-08-11 14:03:13.158761+05:30	2026-08-11 14:03:13.158761+05:30	\N	\N	\N	\N	\N
62	CRUD2955	CRUD Renamed 2955	a@b.org	2026-08-11	active	\N	2026-08-11 14:03:30.131169+05:30	2026-08-11 14:03:33.21079+05:30	2026-08-11 14:03:33.21079+05:30	17	test organisation	\N	\N
63	D148	Dash Test 148	x@test.org	2026-08-11	active	\N	2026-08-11 14:04:18.89064+05:30	2026-08-11 14:04:18.89064+05:30	\N	\N	\N	\N	\N
64	D313	Dash Test 313	x@test.org	2026-08-11	active	\N	2026-08-11 14:04:38.143495+05:30	2026-08-11 14:04:38.143495+05:30	\N	\N	\N	\N	\N
65	CRUD1906	CRUD Renamed 1906	a@b.org	2026-08-11	active	\N	2026-08-11 14:04:56.054034+05:30	2026-08-11 14:04:58.906123+05:30	2026-08-11 14:04:58.906123+05:30	17	test organisation	\N	\N
66	D504	Dash Test 504	x@test.org	2026-08-11	active	\N	2026-08-11 14:05:07.417607+05:30	2026-08-11 14:05:07.417607+05:30	\N	\N	\N	\N	\N
68	D101	Dash Test 101	x@test.org	2026-08-11	active	\N	2026-08-11 14:05:49.252945+05:30	2026-08-11 14:05:49.252945+05:30	\N	\N	\N	\N	\N
67	CRUD3015	CRUD Renamed 3015	a@b.org	2026-08-11	active	\N	2026-08-11 14:05:25.186346+05:30	2026-08-11 14:05:28.471698+05:30	2026-08-11 14:05:28.471698+05:30	17	test organisation	\N	\N
69	CRUD7448	CRUD Renamed 7448	a@b.org	2026-08-11	active	\N	2026-08-11 14:06:06.652131+05:30	2026-08-11 14:06:09.882978+05:30	2026-08-11 14:06:09.882978+05:30	17	test organisation	\N	\N
70	D728	Dash Test 728	x@test.org	2026-08-11	active	\N	2026-08-11 14:06:18.292773+05:30	2026-08-11 14:06:18.292773+05:30	\N	\N	\N	\N	\N
71	CRUD3793	CRUD Renamed 3793	a@b.org	2026-08-11	active	\N	2026-08-11 14:06:35.802095+05:30	2026-08-11 14:06:39.037941+05:30	2026-08-11 14:06:39.037941+05:30	17	test organisation	\N	\N
72	D468	Dash Test 468	x@test.org	2026-08-11	active	\N	2026-08-11 14:06:47.927227+05:30	2026-08-11 14:06:47.927227+05:30	\N	\N	\N	\N	\N
73	CRUD9584	CRUD Renamed 9584	a@b.org	2026-08-11	active	\N	2026-08-11 14:07:06.427566+05:30	2026-08-11 14:07:10.176767+05:30	2026-08-11 14:07:10.176767+05:30	17	test organisation	\N	\N
100	D746	Dash Test 746	x@test.org	2026-08-11	active	\N	2026-08-11 14:20:38.252777+05:30	2026-08-11 14:20:38.252777+05:30	\N	\N	\N	\N	\N
101	CRUD4486	CRUD Renamed 4486	a@b.org	2026-08-11	active	\N	2026-08-11 14:21:01.023711+05:30	2026-08-11 14:21:04.74902+05:30	2026-08-11 14:21:04.74902+05:30	17	test organisation	\N	\N
102	D175	Dash Test 175	x@test.org	2026-08-11	active	\N	2026-08-11 14:26:32.973217+05:30	2026-08-11 14:26:32.973217+05:30	\N	\N	\N	\N	\N
103	CRUD4325	CRUD Renamed 4325	a@b.org	2026-08-11	active	\N	2026-08-11 14:26:54.368128+05:30	2026-08-11 14:26:57.591353+05:30	2026-08-11 14:26:57.591353+05:30	17	test organisation	\N	\N
104	D439	Dash Test 439	x@test.org	2026-08-11	active	\N	2026-08-11 14:31:15.487908+05:30	2026-08-11 14:31:15.487908+05:30	\N	\N	\N	\N	\N
105	CRUD7810	CRUD Renamed 7810	a@b.org	2026-08-11	active	\N	2026-08-11 14:31:35.423547+05:30	2026-08-11 14:31:38.884199+05:30	2026-08-11 14:31:38.884199+05:30	17	test organisation	\N	\N
106	D978	Dash Test 978	x@test.org	2026-08-11	active	\N	2026-08-11 14:32:23.724137+05:30	2026-08-11 14:32:23.724137+05:30	\N	\N	\N	\N	\N
107	CRUD5007	CRUD Renamed 5007	a@b.org	2026-08-11	active	\N	2026-08-11 14:32:43.162214+05:30	2026-08-11 14:32:46.641793+05:30	2026-08-11 14:32:46.641793+05:30	17	test organisation	\N	\N
108	D921	Dash Test 921	x@test.org	2026-08-11	active	\N	2026-08-11 15:10:07.78149+05:30	2026-08-11 15:10:07.78149+05:30	\N	\N	\N	\N	\N
109	CRUD5980	CRUD Renamed 5980	a@b.org	2026-08-11	active	\N	2026-08-11 15:10:26.604541+05:30	2026-08-11 15:10:29.755863+05:30	2026-08-11 15:10:29.755863+05:30	17	test organisation	\N	\N
110	D176	Dash Test 176	x@test.org	2026-08-11	active	\N	2026-08-11 15:54:03.574301+05:30	2026-08-11 15:54:03.574301+05:30	\N	\N	\N	\N	\N
111	CRUD2212	CRUD Renamed 2212	a@b.org	2026-08-11	active	\N	2026-08-11 15:54:22.073887+05:30	2026-08-11 15:54:25.817554+05:30	2026-08-11 15:54:25.817554+05:30	17	test organisation	\N	\N
\.


--
-- TOC entry 5902 (class 0 OID 30895)
-- Dependencies: 263
-- Data for Name: patient; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.patient (patient_id, unique_code, org_id, facility_id, registered_by, patient_name, gender, age, dob, marital_status, contact_number, aadhar_number, blood_group, category_id, disability, pin_code, address, state_id, district_id, block_id, village_id, past_history, created_at, updated_at, deleted_at, deleted_by, delete_reason, legacy_id, legacy_source) FROM stdin;
1	GN-0001	1	1	1	Rajwati Devi	Female	69	\N	Widowed	9696767646	\N	O+	\N	f	\N	\N	16	48	83	2137		2026-08-03 14:56:13.570458+05:30	2026-08-03 14:56:13.570458+05:30	\N	\N	\N	\N	\N
2	GN-0002	1	1	1	Web Test Patient	Female	32	\N	\N	9812345670	\N	B+	\N	f	\N	\N	16	48	83	2137		2026-08-03 15:50:54.086112+05:30	2026-08-03 15:50:54.086112+05:30	\N	\N	\N	\N	\N
3	GN-0003	1	1	1	React Web Patient	Male	45	\N	\N	9700112233	\N	A+	\N	f	\N	\N	16	48	83	2137		2026-08-03 15:56:38.062476+05:30	2026-08-03 15:56:38.062476+05:30	\N	\N	\N	\N	\N
4	GN-0004	1	1	1	Mobile App Patient	Female	28	\N	\N	9123456780	\N	O+	\N	f	244235	Ward 4	16	48	83	2144		2026-08-03 16:16:58.853463+05:30	2026-08-03 16:16:58.853463+05:30	\N	\N	\N	\N	\N
5	GN-0005	1	1	1	Flow Test 6b73a8	Male	34	\N	\N	9627318000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 22:46:48.740714+05:30	2026-08-09 22:46:48.740714+05:30	\N	\N	\N	\N	\N
6	GN-0006	1	1	1	Flow Test 404847	Male	34	\N	\N	9404847000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 22:48:25.492044+05:30	2026-08-09 22:48:25.492044+05:30	\N	\N	\N	\N	\N
7	GN-0007	1	1	1	Flow Test eff5c9	Male	34	\N	\N	9566539000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 22:50:01.21088+05:30	2026-08-09 22:50:01.21088+05:30	\N	\N	\N	\N	\N
8	GN-0008	1	1	1	Flow Test 471862	Male	34	\N	\N	9471862000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 22:51:23.408831+05:30	2026-08-09 22:51:23.408831+05:30	\N	\N	\N	\N	\N
9	GN-0009	1	1	1	Flow Test b851ba	Male	34	\N	\N	9285121000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 22:52:30.680789+05:30	2026-08-09 22:52:30.680789+05:30	\N	\N	\N	\N	\N
10	GN-0010	1	1	1	Flow Test 52a9bc	Male	34	\N	\N	9521923000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 22:52:52.945077+05:30	2026-08-09 22:52:52.945077+05:30	\N	\N	\N	\N	\N
11	GN-0011	1	1	1	Portal API 2jj406	Male	41	\N	\N	9296720151	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 23:02:00.170978+05:30	2026-08-09 23:02:00.170978+05:30	\N	\N	\N	\N	\N
12	GN-0012	1	1	1	Portal API wr6ops	Male	41	\N	\N	9296844867	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 23:04:04.893708+05:30	2026-08-09 23:04:04.893708+05:30	\N	\N	\N	\N	\N
13	GN-0013	1	1	1	Portal API van2jm	Male	41	\N	\N	9297611352	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 23:16:51.36485+05:30	2026-08-09 23:16:51.36485+05:30	\N	\N	\N	\N	\N
14	GN-0014	1	1	1	Flow Test f68981	Male	34	\N	\N	9668981000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 23:17:03.959572+05:30	2026-08-09 23:17:03.959572+05:30	\N	\N	\N	\N	\N
15	GN-0015	1	1	1	Portal API zst6hq	Male	41	\N	\N	9298818577	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 23:36:58.611143+05:30	2026-08-09 23:36:58.611143+05:30	\N	\N	\N	\N	\N
16	GN-0016	1	1	1	Portal API opxb60	Male	41	\N	\N	9298851518	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 23:37:31.535833+05:30	2026-08-09 23:37:31.535833+05:30	\N	\N	\N	\N	\N
17	GN-0017	1	1	1	Portal API eqqyxr	Male	41	\N	\N	9298879490	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 23:37:59.50936+05:30	2026-08-09 23:37:59.50936+05:30	\N	\N	\N	\N	\N
18	GN-0018	1	1	1	Portal API es2oa5	Male	41	\N	\N	9298933814	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 23:38:53.843364+05:30	2026-08-09 23:38:53.843364+05:30	\N	\N	\N	\N	\N
19	GN-0019	1	1	1	Portal API 2hg16t	Male	41	\N	\N	9298996047	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 23:39:56.074177+05:30	2026-08-09 23:39:56.074177+05:30	\N	\N	\N	\N	\N
20	GN-0020	1	1	1	Portal API mbtufr	Male	41	\N	\N	9299015794	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 23:40:15.806228+05:30	2026-08-09 23:40:15.806228+05:30	\N	\N	\N	\N	\N
21	GN-0021	1	1	1	Flow Test 8dfc4e	Male	34	\N	\N	9846345000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 23:40:29.106591+05:30	2026-08-09 23:40:29.106591+05:30	\N	\N	\N	\N	\N
22	GN-0022	1	1	1	Portal API 8lp5qy	Male	41	\N	\N	9299873035	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-09 23:54:33.05982+05:30	2026-08-09 23:54:33.05982+05:30	\N	\N	\N	\N	\N
23	GN-0023	1	1	1	Omnis soluta consect	Male	32	\N	\N	9090909098	\N	\N	\N	f	\N	\N	12	39	69	1925		2026-08-10 00:06:21.778221+05:30	2026-08-10 00:06:21.778221+05:30	\N	\N	\N	\N	\N
24	GN-0024	1	1	1	Flow Test f33035	Male	34	\N	\N	9633035000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 11:09:23.84953+05:30	2026-08-10 11:09:23.84953+05:30	\N	\N	\N	\N	\N
25	GN-0025	1	1	1	Portal API 63xvn5	Male	41	\N	\N	9340394240	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 11:09:54.264168+05:30	2026-08-10 11:09:54.264168+05:30	\N	\N	\N	\N	\N
37	\N	\N	\N	\N	Ramesh Kumar	Male	42	\N	\N	9446772675	\N	\N	\N	f	\N	\N	16	48	83	2137		2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
38	\N	\N	\N	\N	Sunita Devi	Female	35	\N	\N	9548452043	\N	\N	\N	f	\N	\N	16	48	83	2137		2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
39	\N	\N	\N	\N	Mohan Lal	Male	58	\N	\N	9102987516	\N	\N	\N	f	\N	\N	16	48	84	2268		2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
40	\N	\N	\N	\N	Anita Sharma	Female	29	\N	\N	9408110233	\N	\N	\N	f	\N	\N	16	48	83	2137		2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
41	\N	\N	\N	\N	Vikash Singh	Male	31	\N	\N	9507663431	\N	\N	\N	f	\N	\N	16	48	83	2137		2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
42	\N	\N	\N	\N	Meena Kumari	Female	47	\N	\N	9296439209	\N	\N	\N	f	\N	\N	16	48	84	2268		2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
43	\N	\N	\N	\N	Rajesh Yadav	Male	26	\N	\N	9248400598	\N	\N	\N	f	\N	\N	16	48	83	2137		2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
44	\N	\N	\N	\N	Kavita Patel	Female	52	\N	\N	9569783428	\N	\N	\N	f	\N	\N	16	48	83	2137		2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
45	\N	\N	\N	\N	Suresh Chand	Male	63	\N	\N	9252318885	\N	\N	\N	f	\N	\N	16	48	84	2268		2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
46	\N	\N	\N	\N	Pooja Verma	Female	24	\N	\N	9422665043	\N	\N	\N	f	\N	\N	16	48	83	2137		2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
47	\N	\N	\N	\N	Arun Mishra	Male	38	\N	\N	9606225512	\N	\N	\N	f	\N	\N	16	48	83	2137		2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
48	\N	\N	\N	\N	Geeta Rani	Female	41	\N	\N	9193638107	\N	\N	\N	f	\N	\N	16	48	84	2268		2026-08-10 11:23:29.404891+05:30	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
49	GN-0026	1	1	1	Flow Test 60ee0f	Male	34	\N	\N	9605506000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 11:41:59.018045+05:30	2026-08-10 11:41:59.018045+05:30	\N	\N	\N	\N	\N
50	GN-0027	1	1	1	Portal API lkpy4f	Male	41	\N	\N	9342325148	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 11:42:05.171968+05:30	2026-08-10 11:42:05.171968+05:30	\N	\N	\N	\N	\N
51	GN-0028	1	1	1	Flow Test a005b7	Male	34	\N	\N	9100527000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 16:36:16.408924+05:30	2026-08-10 16:36:16.408924+05:30	\N	\N	\N	\N	\N
52	GN-0029	1	1	1	Portal API p8a4tp	Male	41	\N	\N	9359983362	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 16:36:23.377062+05:30	2026-08-10 16:36:23.377062+05:30	\N	\N	\N	\N	\N
53	GN-0030	1	1	1	Flow Test 94ec52	Male	34	\N	\N	9945352000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 16:38:16.672692+05:30	2026-08-10 16:38:16.672692+05:30	\N	\N	\N	\N	\N
54	GN-0031	1	1	1	Portal API qamqp4	Male	41	\N	\N	9360103845	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 16:38:23.857017+05:30	2026-08-10 16:38:23.857017+05:30	\N	\N	\N	\N	\N
55	GN-0032	1	1	1	Flow Test 57cbae	Male	34	\N	\N	9573215000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 16:57:06.601621+05:30	2026-08-10 16:57:06.601621+05:30	\N	\N	\N	\N	\N
56	GN-0033	1	1	1	Portal API 20lr4x	Male	41	\N	\N	9361232561	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 16:57:12.576631+05:30	2026-08-10 16:57:12.576631+05:30	\N	\N	\N	\N	\N
57	GN-0034	1	1	1	Flow Test 259dc1	Male	34	\N	\N	9259431000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 17:14:40.804742+05:30	2026-08-10 17:14:40.804742+05:30	\N	\N	\N	\N	\N
58	GN-0035	1	1	1	Portal API oyz88r	Male	41	\N	\N	9362287643	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 17:14:47.665046+05:30	2026-08-10 17:14:47.665046+05:30	\N	\N	\N	\N	\N
59	GN-0036	1	1	1	Flow Test c80ec9	Male	34	\N	\N	9380539000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 17:42:47.522421+05:30	2026-08-10 17:42:47.522421+05:30	\N	\N	\N	\N	\N
60	GN-0037	1	1	1	Portal API pshjeh	Male	41	\N	\N	9363976441	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 17:42:56.45069+05:30	2026-08-10 17:42:56.45069+05:30	\N	\N	\N	\N	\N
61	GN-0038	1	1	1	Portal API n7sgjl	Male	41	\N	\N	9365067835	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:01:07.857435+05:30	2026-08-10 18:01:07.857435+05:30	\N	\N	\N	\N	\N
62	GN-0039	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:16:59.591725+05:30	2026-08-10 18:16:59.591725+05:30	\N	\N	\N	\N	\N
63	GN-0040	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:17:50.676802+05:30	2026-08-10 18:17:50.676802+05:30	\N	\N	\N	\N	\N
64	GN-0041	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:18:11.162313+05:30	2026-08-10 18:18:11.162313+05:30	\N	\N	\N	\N	\N
65	GN-0042	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:18:59.511139+05:30	2026-08-10 18:18:59.511139+05:30	\N	\N	\N	\N	\N
66	GN-0043	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:20:03.803033+05:30	2026-08-10 18:20:03.803033+05:30	\N	\N	\N	\N	\N
67	GN-0044	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:21:29.767629+05:30	2026-08-10 18:21:29.767629+05:30	\N	\N	\N	\N	\N
68	GN-0045	1	1	1	Menu Case	Male	50	\N	\N	9666666666	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:21:31.565395+05:30	2026-08-10 18:21:31.565395+05:30	\N	\N	\N	\N	\N
69	GN-0046	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:22:07.708555+05:30	2026-08-10 18:22:07.708555+05:30	\N	\N	\N	\N	\N
70	GN-0047	1	1	1	Menu Case	Male	50	\N	\N	9666666666	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:22:09.76868+05:30	2026-08-10 18:22:09.76868+05:30	\N	\N	\N	\N	\N
71	GN-0048	1	1	1	Simple Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:22:16.73287+05:30	2026-08-10 18:22:16.73287+05:30	\N	\N	\N	\N	\N
72	GN-0049	1	1	1	Referral Case	Male	23	\N	\N	9097513232	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:22:17.289122+05:30	2026-08-10 18:22:17.289122+05:30	\N	\N	\N	\N	\N
73	GN-0050	1	1	1	Legacy Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:22:17.646657+05:30	2026-08-10 18:22:17.646657+05:30	\N	\N	\N	\N	\N
74	GN-0051	1	1	1	Audit A	Male	30	\N	\N	9700000001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:22:18.039477+05:30	2026-08-10 18:22:18.039477+05:30	\N	\N	\N	\N	\N
75	GN-0052	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:23:37.057148+05:30	2026-08-10 18:23:37.057148+05:30	\N	\N	\N	\N	\N
76	GN-0053	1	1	1	Menu Case	Male	50	\N	\N	9666666666	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:23:38.605548+05:30	2026-08-10 18:23:38.605548+05:30	\N	\N	\N	\N	\N
77	GN-0054	1	1	1	Simple Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:23:40.193593+05:30	2026-08-10 18:23:40.193593+05:30	\N	\N	\N	\N	\N
78	GN-0055	1	1	1	Referral Case	Male	23	\N	\N	9097513232	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:23:40.574916+05:30	2026-08-10 18:23:40.574916+05:30	\N	\N	\N	\N	\N
79	GN-0056	1	1	1	Legacy Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:23:40.90754+05:30	2026-08-10 18:23:40.90754+05:30	\N	\N	\N	\N	\N
80	GN-0057	1	1	1	Audit A	Male	30	\N	\N	9700000001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:23:41.19929+05:30	2026-08-10 18:23:41.19929+05:30	\N	\N	\N	\N	\N
81	GN-0058	1	1	1	Audit B	Female	31	\N	\N	9700000002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:23:41.474463+05:30	2026-08-10 18:23:41.474463+05:30	\N	\N	\N	\N	\N
82	GN-0059	1	1	1	Audit C	Male	32	\N	\N	9700000003	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:23:42.804726+05:30	2026-08-10 18:23:42.804726+05:30	\N	\N	\N	\N	\N
83	GN-0060	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:24:05.124802+05:30	2026-08-10 18:24:05.124802+05:30	\N	\N	\N	\N	\N
84	GN-0061	1	1	1	Menu Case	Male	50	\N	\N	9666666666	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:24:06.679273+05:30	2026-08-10 18:24:06.679273+05:30	\N	\N	\N	\N	\N
85	GN-0062	1	1	1	Simple Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:24:08.427224+05:30	2026-08-10 18:24:08.427224+05:30	\N	\N	\N	\N	\N
86	GN-0063	1	1	1	Referral Case	Male	23	\N	\N	9097513232	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:24:08.740654+05:30	2026-08-10 18:24:08.740654+05:30	\N	\N	\N	\N	\N
87	GN-0064	1	1	1	Legacy Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:24:09.210878+05:30	2026-08-10 18:24:09.210878+05:30	\N	\N	\N	\N	\N
88	GN-0065	1	1	1	Audit A	Male	30	\N	\N	9700000001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:24:09.522716+05:30	2026-08-10 18:24:09.522716+05:30	\N	\N	\N	\N	\N
89	GN-0066	1	1	1	Audit B	Female	31	\N	\N	9700000002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:24:09.834181+05:30	2026-08-10 18:24:09.834181+05:30	\N	\N	\N	\N	\N
90	GN-0067	1	1	1	Audit C	Male	32	\N	\N	9700000003	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:24:11.243126+05:30	2026-08-10 18:24:11.243126+05:30	\N	\N	\N	\N	\N
91	GN-0068	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:26:56.448901+05:30	2026-08-10 18:26:56.448901+05:30	\N	\N	\N	\N	\N
92	GN-0069	1	1	1	Menu Case	Male	50	\N	\N	9666666666	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:26:58.73004+05:30	2026-08-10 18:26:58.73004+05:30	\N	\N	\N	\N	\N
93	GN-0070	1	1	1	Simple Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:01.183183+05:30	2026-08-10 18:27:01.183183+05:30	\N	\N	\N	\N	\N
94	GN-0071	1	1	1	Referral Case	Male	23	\N	\N	9097513232	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:01.674898+05:30	2026-08-10 18:27:01.674898+05:30	\N	\N	\N	\N	\N
95	GN-0072	1	1	1	Legacy Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:02.17399+05:30	2026-08-10 18:27:02.17399+05:30	\N	\N	\N	\N	\N
96	GN-0073	1	1	1	Audit A	Male	30	\N	\N	9700000001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:02.694497+05:30	2026-08-10 18:27:02.694497+05:30	\N	\N	\N	\N	\N
97	GN-0074	1	1	1	Audit B	Female	31	\N	\N	9700000002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:03.125232+05:30	2026-08-10 18:27:03.125232+05:30	\N	\N	\N	\N	\N
98	GN-0075	1	1	1	Audit C	Male	32	\N	\N	9700000003	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:04.807459+05:30	2026-08-10 18:27:04.807459+05:30	\N	\N	\N	\N	\N
99	GN-0076	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:27.414803+05:30	2026-08-10 18:27:27.414803+05:30	\N	\N	\N	\N	\N
101	GN-0078	1	1	1	Simple Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:31.956057+05:30	2026-08-10 18:27:31.956057+05:30	\N	\N	\N	\N	\N
100	GN-0077	1	1	1	Menu Case	Male	50	\N	\N	9666666666	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:29.54279+05:30	2026-08-10 18:27:29.54279+05:30	\N	\N	\N	\N	\N
106	GN-0083	1	1	1	Audit C	Male	32	\N	\N	9700000003	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:36.214091+05:30	2026-08-10 18:27:36.214091+05:30	\N	\N	\N	\N	\N
102	GN-0079	1	1	1	Referral Case	Male	23	\N	\N	9097513232	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:32.786101+05:30	2026-08-10 18:27:32.786101+05:30	\N	\N	\N	\N	\N
103	GN-0080	1	1	1	Legacy Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:33.303183+05:30	2026-08-10 18:27:33.303183+05:30	\N	\N	\N	\N	\N
104	GN-0081	1	1	1	Audit A	Male	30	\N	\N	9700000001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:33.87283+05:30	2026-08-10 18:27:33.87283+05:30	\N	\N	\N	\N	\N
105	GN-0082	1	1	1	Audit B	Female	31	\N	\N	9700000002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:34.35445+05:30	2026-08-10 18:27:34.35445+05:30	\N	\N	\N	\N	\N
109	GN-0086	1	1	1	Simple Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:28:03.523497+05:30	2026-08-10 18:28:03.523497+05:30	\N	\N	\N	\N	\N
113	GN-0090	1	1	1	Audit B	Female	31	\N	\N	9700000002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:28:05.574111+05:30	2026-08-10 18:28:05.574111+05:30	\N	\N	\N	\N	\N
107	GN-0084	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:27:58.924135+05:30	2026-08-10 18:27:58.924135+05:30	\N	\N	\N	\N	\N
108	GN-0085	1	1	1	Menu Case	Male	50	\N	\N	9666666666	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:28:00.888295+05:30	2026-08-10 18:28:00.888295+05:30	\N	\N	\N	\N	\N
110	GN-0087	1	1	1	Referral Case	Male	23	\N	\N	9097513232	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:28:04.018188+05:30	2026-08-10 18:28:04.018188+05:30	\N	\N	\N	\N	\N
111	GN-0088	1	1	1	Legacy Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:28:04.512432+05:30	2026-08-10 18:28:04.512432+05:30	\N	\N	\N	\N	\N
112	GN-0089	1	1	1	Audit A	Male	30	\N	\N	9700000001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:28:05.084006+05:30	2026-08-10 18:28:05.084006+05:30	\N	\N	\N	\N	\N
114	GN-0091	1	1	1	Audit C	Male	32	\N	\N	9700000003	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:28:07.427813+05:30	2026-08-10 18:28:07.427813+05:30	\N	\N	\N	\N	\N
115	GN-0092	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:29:36.282205+05:30	2026-08-10 18:29:36.282205+05:30	\N	\N	\N	\N	\N
116	GN-0093	1	1	1	Menu Case	Male	50	\N	\N	9666666666	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:29:39.395899+05:30	2026-08-10 18:29:39.395899+05:30	\N	\N	\N	\N	\N
117	GN-0094	1	1	1	Simple Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:29:42.077825+05:30	2026-08-10 18:29:42.077825+05:30	\N	\N	\N	\N	\N
118	GN-0095	1	1	1	Referral Case	Male	23	\N	\N	9097513232	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:29:42.754684+05:30	2026-08-10 18:29:42.754684+05:30	\N	\N	\N	\N	\N
119	GN-0096	1	1	1	Legacy Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:29:43.386483+05:30	2026-08-10 18:29:43.386483+05:30	\N	\N	\N	\N	\N
120	GN-0097	1	1	1	Audit A	Male	30	\N	\N	9700000001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:29:43.943661+05:30	2026-08-10 18:29:43.943661+05:30	\N	\N	\N	\N	\N
121	GN-0098	1	1	1	Audit B	Female	31	\N	\N	9700000002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:29:44.473764+05:30	2026-08-10 18:29:44.473764+05:30	\N	\N	\N	\N	\N
122	GN-0099	1	1	1	Audit C	Male	32	\N	\N	9700000003	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:29:46.512327+05:30	2026-08-10 18:29:46.512327+05:30	\N	\N	\N	\N	\N
123	GN-0100	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:30:48.847743+05:30	2026-08-10 18:30:48.847743+05:30	\N	\N	\N	\N	\N
124	GN-0101	1	1	1	Menu Case	Male	50	\N	\N	9666666666	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:30:51.201358+05:30	2026-08-10 18:30:51.201358+05:30	\N	\N	\N	\N	\N
125	GN-0102	1	1	1	Simple Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:30:54.200515+05:30	2026-08-10 18:30:54.200515+05:30	\N	\N	\N	\N	\N
126	GN-0103	1	1	1	Legacy Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:30:54.870969+05:30	2026-08-10 18:30:54.870969+05:30	\N	\N	\N	\N	\N
127	GN-0104	1	1	1	Audit A	Male	30	\N	\N	9700000001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:30:55.499834+05:30	2026-08-10 18:30:55.499834+05:30	\N	\N	\N	\N	\N
128	GN-0105	1	1	1	Audit B	Female	31	\N	\N	9700000002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:30:56.010119+05:30	2026-08-10 18:30:56.010119+05:30	\N	\N	\N	\N	\N
129	GN-0106	1	1	1	Audit C	Male	32	\N	\N	9700000003	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:30:58.234721+05:30	2026-08-10 18:30:58.234721+05:30	\N	\N	\N	\N	\N
130	GN-0107	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:31:09.447866+05:30	2026-08-10 18:31:09.447866+05:30	\N	\N	\N	\N	\N
131	GN-0108	1	1	1	Menu Case	Male	50	\N	\N	9666666666	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:31:11.843793+05:30	2026-08-10 18:31:11.843793+05:30	\N	\N	\N	\N	\N
132	GN-0109	1	1	1	Simple Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:31:14.657075+05:30	2026-08-10 18:31:14.657075+05:30	\N	\N	\N	\N	\N
133	GN-0110	1	1	1	Legacy Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:31:15.284168+05:30	2026-08-10 18:31:15.284168+05:30	\N	\N	\N	\N	\N
134	GN-0111	1	1	1	Audit A	Male	30	\N	\N	9700000001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:31:15.992389+05:30	2026-08-10 18:31:15.992389+05:30	\N	\N	\N	\N	\N
135	GN-0112	1	1	1	Audit B	Female	31	\N	\N	9700000002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:31:16.567575+05:30	2026-08-10 18:31:16.567575+05:30	\N	\N	\N	\N	\N
136	GN-0113	1	1	1	Audit C	Male	32	\N	\N	9700000003	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:31:19.049657+05:30	2026-08-10 18:31:19.049657+05:30	\N	\N	\N	\N	\N
137	GN-0114	1	1	1	Test Patient	Male	34	\N	\N	9000000000	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:31:45.378418+05:30	2026-08-10 18:31:45.378418+05:30	\N	\N	\N	\N	\N
138	GN-0115	1	1	1	Menu Case	Male	50	\N	\N	9666666666	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:31:47.739867+05:30	2026-08-10 18:31:47.739867+05:30	\N	\N	\N	\N	\N
139	GN-0116	1	1	1	Simple Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:31:51.167455+05:30	2026-08-10 18:31:51.167455+05:30	\N	\N	\N	\N	\N
140	GN-0117	1	1	1	Legacy Case	Male	30	\N	\N	\N	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:31:51.820878+05:30	2026-08-10 18:31:51.820878+05:30	\N	\N	\N	\N	\N
141	GN-0118	1	1	1	Audit A	Male	30	\N	\N	9700000001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:31:52.482673+05:30	2026-08-10 18:31:52.482673+05:30	\N	\N	\N	\N	\N
142	GN-0119	1	1	1	Audit B	Female	31	\N	\N	9700000002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:31:53.12886+05:30	2026-08-10 18:31:53.12886+05:30	\N	\N	\N	\N	\N
143	GN-0120	1	1	1	Audit C	Male	32	\N	\N	9700000003	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:31:55.545854+05:30	2026-08-10 18:31:55.545854+05:30	\N	\N	\N	\N	\N
144	GN-0121	1	1	1	Final Print	Female	28	\N	\N	9111111111	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 18:32:01.436883+05:30	2026-08-10 18:32:01.436883+05:30	\N	\N	\N	\N	\N
145	GN-0122	1	1	1	Portal API 75ql7c	Male	41	\N	\N	9369661745	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 19:17:41.802501+05:30	2026-08-10 19:17:41.802501+05:30	\N	\N	\N	\N	\N
147	GN-0123	1	1	1	Offline Test	Male	33	\N	\N	9812345670	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 20:16:36.984804+05:30	2026-08-10 20:16:36.984804+05:30	\N	\N	\N	\N	\N
148	GN-0124	1	1	1	Portal API c36cfj	Male	41	\N	\N	9373371378	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 20:19:31.403552+05:30	2026-08-10 20:19:31.403552+05:30	\N	\N	\N	\N	\N
149	GN-0125	1	1	1	Portal API 2fd2nc	Male	41	\N	\N	9373612470	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 20:23:32.479659+05:30	2026-08-10 20:23:32.479659+05:30	\N	\N	\N	\N	\N
150	GN-0126	1	1	1	Portal API 1175hv	Male	41	\N	\N	9374306814	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 20:35:06.827885+05:30	2026-08-10 20:35:06.827885+05:30	\N	\N	\N	\N	\N
151	GN-0127	1	1	1	Portal API isw8xa	Male	41	\N	\N	9375094028	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 20:48:14.037587+05:30	2026-08-10 20:48:14.037587+05:30	\N	\N	\N	\N	\N
152	GN-0128	1	1	1	Portal API gug3eq	Male	41	\N	\N	9376675889	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 21:14:35.900548+05:30	2026-08-10 21:14:35.900548+05:30	\N	\N	\N	\N	\N
153	GN-0129	1	1	1	Portal API q77slv	Male	41	\N	\N	9377052096	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 21:20:52.108853+05:30	2026-08-10 21:20:52.108853+05:30	\N	\N	\N	\N	\N
154	GN-0130	1	1	1	Portal API 8qp39s	Male	41	\N	\N	9378147484	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 21:39:07.495358+05:30	2026-08-10 21:39:07.495358+05:30	\N	\N	\N	\N	\N
155	GN-0131	1	1	1	Portal API g6wpi1	Male	41	\N	\N	9378773019	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-10 21:49:33.053176+05:30	2026-08-10 21:49:33.053176+05:30	\N	\N	\N	\N	\N
156	GN-0132	1	1	1	Portal API lpy3k8	Male	41	\N	\N	9420851266	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 09:30:51.318534+05:30	2026-08-11 09:30:51.318534+05:30	\N	\N	\N	\N	\N
157	GN-0133	1	1	1	Portal API xf42x6	Male	41	\N	\N	9421206373	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 09:36:46.379757+05:30	2026-08-11 09:36:46.379757+05:30	\N	\N	\N	\N	\N
158	GN-0134	1	1	1	Rakesh kumar	Male	32	\N	\N	9097513232	\N	\N	\N	f	\N	\N	5	6	7	77		2026-08-11 09:37:45.402609+05:30	2026-08-11 09:37:45.402609+05:30	\N	\N	\N	\N	\N
159	GN-0135	1	1	1	Portal API ngvfzi	Male	41	\N	\N	9422168394	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 09:52:48.414237+05:30	2026-08-11 09:52:48.414237+05:30	\N	\N	\N	\N	\N
160	GN-0136	1	\N	1	Portal API wf9vfj	Male	41	\N	\N	9427205216	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 11:16:45.234974+05:30	2026-08-11 11:16:45.234974+05:30	\N	\N	\N	\N	\N
161	GN-0137	1	1	1	Sync Test	Female	29	\N	\N	9811122233	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 13:46:03.131467+05:30	2026-08-11 13:46:03.131467+05:30	\N	\N	\N	\N	\N
162	GN-0138	1	1	1	Portal API mbxg6f	Male	41	\N	\N	9436797628	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 13:56:37.660448+05:30	2026-08-11 13:56:37.660448+05:30	\N	\N	\N	\N	\N
163	GN-0139	1	1	1	Portal API rt3oin	Male	41	\N	\N	9436900927	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 13:58:20.944827+05:30	2026-08-11 13:58:20.944827+05:30	\N	\N	\N	\N	\N
164	GN-0140	1	\N	1	Portal API g7z6gl	Male	41	\N	\N	9436997641	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 13:59:57.651078+05:30	2026-08-11 13:59:57.651078+05:30	\N	\N	\N	\N	\N
165	GN-0141	1	\N	1	Portal API s89pwu	Male	41	\N	\N	9437038597	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:00:38.605665+05:30	2026-08-11 14:00:38.605665+05:30	\N	\N	\N	\N	\N
166	GN-0142	1	\N	1	Portal API 9t1q04	Male	41	\N	\N	9437054925	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:00:54.938505+05:30	2026-08-11 14:00:54.938505+05:30	\N	\N	\N	\N	\N
167	GN-0143	1	\N	1	Portal API 5k44he	Male	41	\N	\N	9437094240	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:01:34.254971+05:30	2026-08-11 14:01:34.254971+05:30	\N	\N	\N	\N	\N
168	GN-0144	1	1	1	Portal API 8t4tpa	Male	41	\N	\N	9437161227	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:02:41.236579+05:30	2026-08-11 14:02:41.236579+05:30	\N	\N	\N	\N	\N
169	GN-0145	1	1	1	Portal API ajnxif	Male	41	\N	\N	9437220393	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:03:40.403112+05:30	2026-08-11 14:03:40.403112+05:30	\N	\N	\N	\N	\N
170	GN-0146	1	1	1	Push Test	Female	31	\N	\N	9812300001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:08:49.314049+05:30	2026-08-11 14:08:49.314049+05:30	\N	\N	\N	\N	\N
171	GN-0147	1	1	1	Good Row	Male	40	\N	\N	9812300002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:08:49.362553+05:30	2026-08-11 14:08:49.362553+05:30	\N	\N	\N	\N	\N
172	GN-0148	1	1	1	Push Test	Female	31	\N	\N	9812300001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:09:11.152466+05:30	2026-08-11 14:09:11.152466+05:30	\N	\N	\N	\N	\N
173	GN-0149	1	1	1	Good Row	Male	40	\N	\N	9812300002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:09:11.178983+05:30	2026-08-11 14:09:11.178983+05:30	\N	\N	\N	\N	\N
203	GN-0150	1	1	1	Push Test	Female	31	\N	\N	9812300001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:17:35.04409+05:30	2026-08-11 14:17:35.04409+05:30	\N	\N	\N	\N	\N
204	GN-0151	1	1	1	Good Row	Male	40	\N	\N	9812300002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:17:35.204171+05:30	2026-08-11 14:17:35.204171+05:30	\N	\N	\N	\N	\N
205	GN-0152	1	1	1	Push Test	Female	31	\N	\N	9812300001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:18:04.222418+05:30	2026-08-11 14:18:04.222418+05:30	\N	\N	\N	\N	\N
206	GN-0153	1	1	1	Good Row	Male	40	\N	\N	9812300002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:18:04.398274+05:30	2026-08-11 14:18:04.398274+05:30	\N	\N	\N	\N	\N
207	GN-0154	1	1	1	Push Test	Female	31	\N	\N	9812300001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:19:21.535256+05:30	2026-08-11 14:19:21.535256+05:30	\N	\N	\N	\N	\N
208	GN-0155	1	1	1	Good Row	Male	40	\N	\N	9812300002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:19:21.586573+05:30	2026-08-11 14:19:21.586573+05:30	\N	\N	\N	\N	\N
209	GN-0156	1	1	1	Push Test	Female	31	\N	\N	9812300001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:19:51.592955+05:30	2026-08-11 14:19:51.592955+05:30	\N	\N	\N	\N	\N
210	GN-0157	1	1	1	Good Row	Male	40	\N	\N	9812300002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:19:51.624074+05:30	2026-08-11 14:19:51.624074+05:30	\N	\N	\N	\N	\N
211	GN-0158	1	1	1	Portal API l2yjfm	Male	41	\N	\N	9438274865	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:21:14.887194+05:30	2026-08-11 14:21:14.887194+05:30	\N	\N	\N	\N	\N
212	GN-0159	1	1	1	Push Test	Female	31	\N	\N	9812300001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:25:52.201002+05:30	2026-08-11 14:25:52.201002+05:30	\N	\N	\N	\N	\N
213	GN-0160	1	1	1	Good Row	Male	40	\N	\N	9812300002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:25:52.27171+05:30	2026-08-11 14:25:52.27171+05:30	\N	\N	\N	\N	\N
214	GN-0161	1	1	1	Portal API 71q43f	Male	41	\N	\N	9438627834	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:27:07.853677+05:30	2026-08-11 14:27:07.853677+05:30	\N	\N	\N	\N	\N
215	GN-0162	1	1	1	Push Test	Female	31	\N	\N	9812300001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:31:08.291688+05:30	2026-08-11 14:31:08.291688+05:30	\N	\N	\N	\N	\N
216	GN-0163	1	1	1	Good Row	Male	40	\N	\N	9812300002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:31:08.362517+05:30	2026-08-11 14:31:08.362517+05:30	\N	\N	\N	\N	\N
217	GN-0164	1	1	1	Portal API 4bzko5	Male	41	\N	\N	9438906740	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:31:46.747999+05:30	2026-08-11 14:31:46.747999+05:30	\N	\N	\N	\N	\N
218	GN-0165	1	1	1	Push Test	Female	31	\N	\N	9812300001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:32:16.676047+05:30	2026-08-11 14:32:16.676047+05:30	\N	\N	\N	\N	\N
219	GN-0166	1	1	1	Good Row	Male	40	\N	\N	9812300002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:32:16.710495+05:30	2026-08-11 14:32:16.710495+05:30	\N	\N	\N	\N	\N
220	GN-0167	1	1	1	Portal API vzc6nv	Male	41	\N	\N	9438974563	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 14:32:54.573925+05:30	2026-08-11 14:32:54.573925+05:30	\N	\N	\N	\N	\N
221	GN-0168	1	1	1	Push Test	Female	31	\N	\N	9812300001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 15:10:01.03179+05:30	2026-08-11 15:10:01.03179+05:30	\N	\N	\N	\N	\N
222	GN-0169	1	1	1	Good Row	Male	40	\N	\N	9812300002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 15:10:01.075613+05:30	2026-08-11 15:10:01.075613+05:30	\N	\N	\N	\N	\N
223	GN-0170	1	1	1	Portal API evb4ra	Male	41	\N	\N	9441236901	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 15:10:36.911413+05:30	2026-08-11 15:10:36.911413+05:30	\N	\N	\N	\N	\N
224	GN-0171	1	1	1	Push Test	Female	31	\N	\N	9812300001	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 15:53:56.171116+05:30	2026-08-11 15:53:56.171116+05:30	\N	\N	\N	\N	\N
225	GN-0172	1	1	1	Good Row	Male	40	\N	\N	9812300002	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 15:53:56.242083+05:30	2026-08-11 15:53:56.242083+05:30	\N	\N	\N	\N	\N
226	GN-0173	1	1	1	Portal API vttahb	Male	41	\N	\N	9443873431	\N	\N	\N	f	\N	\N	16	48	83	2138		2026-08-11 15:54:33.456876+05:30	2026-08-11 15:54:33.456876+05:30	\N	\N	\N	\N	\N
\.


--
-- TOC entry 5929 (class 0 OID 31448)
-- Dependencies: 290
-- Data for Name: patient_monthly_aggregate; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.patient_monthly_aggregate (aggregate_id, org_id, source, month, total, male, female, other, age_0_5, age_6_17, age_18_45, age_46_60, age_60_plus, computed_at) FROM stdin;
\.


--
-- TOC entry 5910 (class 0 OID 31152)
-- Dependencies: 271
-- Data for Name: prescription_item; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.prescription_item (prescription_item_id, appointment_id, medicine_id, medicine_name, dosage, frequency, duration_days, qty, dispensed_qty, dispensed, qty_change_reason, created_at, deleted_at, deleted_by, delete_reason, legacy_id, legacy_source) FROM stdin;
1	1	\N	T.Paracetamol	500 mg	TDS	3	9	5	t	stock short	2026-08-03 15:14:55.133419+05:30	\N	\N	\N	\N	\N
2	5	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-09 22:48:26.012835+05:30	\N	\N	\N	\N	\N
4	6	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-09 22:50:02.953468+05:30	\N	\N	\N	\N	\N
3	6	\N	Paracetamol 500mg	650mg	TDS	5	15	10	t	Only 10 in stock	2026-08-09 22:50:01.657731+05:30	\N	\N	\N	\N	\N
5	7	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-09 22:51:24.046393+05:30	\N	\N	\N	\N	\N
6	8	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-09 22:52:31.260973+05:30	2026-08-09 22:52:32.514691+05:30	2	revised by doctor	\N	\N
7	8	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-09 22:52:32.514691+05:30	2026-08-09 22:52:32.776645+05:30	2	revised by doctor	\N	\N
8	8	\N	Paracetamol 500mg	650mg	TDS	5	15	10	t	Only 10 in stock	2026-08-09 22:52:32.776645+05:30	\N	\N	\N	\N	\N
9	9	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-09 22:52:53.554363+05:30	2026-08-09 22:52:54.671783+05:30	2	revised by doctor	\N	\N
10	9	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-09 22:52:54.671783+05:30	2026-08-09 22:52:54.971048+05:30	2	revised by doctor	\N	\N
11	9	\N	Paracetamol 500mg	650mg	TDS	5	15	10	t	Only 10 in stock	2026-08-09 22:52:54.971048+05:30	\N	\N	\N	\N	\N
12	13	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-09 23:17:04.365151+05:30	2026-08-09 23:17:05.796388+05:30	2	revised by doctor	\N	\N
13	13	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-09 23:17:05.796388+05:30	2026-08-09 23:17:06.398764+05:30	2	revised by doctor	\N	\N
14	13	\N	Paracetamol 500mg	650mg	TDS	5	15	10	t	Only 10 in stock	2026-08-09 23:17:06.398764+05:30	\N	\N	\N	\N	\N
15	20	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-09 23:40:29.512298+05:30	2026-08-09 23:40:30.529809+05:30	2	revised by doctor	\N	\N
16	20	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-09 23:40:30.529809+05:30	2026-08-09 23:40:30.757028+05:30	2	revised by doctor	\N	\N
17	20	\N	Paracetamol 500mg	650mg	TDS	5	15	10	t	Only 10 in stock	2026-08-09 23:40:30.757028+05:30	\N	\N	\N	\N	\N
18	23	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 11:09:24.182336+05:30	2026-08-10 11:09:25.442812+05:30	2	revised by doctor	\N	\N
19	23	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 11:09:25.442812+05:30	2026-08-10 11:09:25.626033+05:30	2	revised by doctor	\N	\N
20	23	\N	Paracetamol 500mg	650mg	TDS	5	15	10	t	Only 10 in stock	2026-08-10 11:09:25.626033+05:30	\N	\N	\N	\N	\N
27	38	\N	Iron Folic Acid	1 tab	OD	30	30	30	f	\N	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
28	39	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
29	40	\N	Amoxicillin 250mg	250mg	BD	5	10	10	f	\N	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
30	41	\N	Iron Folic Acid	1 tab	OD	30	30	30	t	\N	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
31	42	\N	Iron Folic Acid	1 tab	OD	30	30	30	t	\N	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
32	46	\N	ORS Sachet	1 sachet	SOS	3	6	6	f	\N	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
33	47	\N	Iron Folic Acid	1 tab	OD	30	30	30	f	\N	2026-08-10 11:23:29.404891+05:30	\N	\N	\N	\N	\N
34	48	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 11:41:59.723669+05:30	2026-08-10 11:42:00.563415+05:30	2	revised by doctor	\N	\N
35	48	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 11:42:00.563415+05:30	2026-08-10 11:42:00.740961+05:30	2	revised by doctor	\N	\N
36	48	\N	Paracetamol 500mg	650mg	TDS	5	15	10	t	Only 10 in stock	2026-08-10 11:42:00.740961+05:30	\N	\N	\N	\N	\N
37	50	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 16:36:17.317082+05:30	2026-08-10 16:36:18.473475+05:30	2	revised by doctor	\N	\N
38	50	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 16:36:18.473475+05:30	2026-08-10 16:36:19.179518+05:30	2	revised by doctor	\N	\N
39	50	\N	Paracetamol 500mg	650mg	TDS	5	15	10	t	Only 10 in stock	2026-08-10 16:36:19.179518+05:30	\N	\N	\N	\N	\N
40	52	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 16:38:17.155942+05:30	2026-08-10 16:38:18.31455+05:30	2	revised by doctor	\N	\N
41	52	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 16:38:18.31455+05:30	2026-08-10 16:38:18.629348+05:30	2	revised by doctor	\N	\N
42	52	\N	Paracetamol 500mg	650mg	TDS	5	15	10	t	Only 10 in stock	2026-08-10 16:38:18.629348+05:30	\N	\N	\N	\N	\N
43	54	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 16:57:07.258038+05:30	2026-08-10 16:57:08.397988+05:30	2	revised by doctor	\N	\N
44	54	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 16:57:08.397988+05:30	2026-08-10 16:57:08.724806+05:30	2	revised by doctor	\N	\N
45	54	\N	Paracetamol 500mg	650mg	TDS	5	15	10	t	Only 10 in stock	2026-08-10 16:57:08.724806+05:30	\N	\N	\N	\N	\N
46	56	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 17:14:41.325702+05:30	2026-08-10 17:14:42.675126+05:30	2	revised by doctor	\N	\N
47	56	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 17:14:42.675126+05:30	2026-08-10 17:14:43.232144+05:30	2	revised by doctor	\N	\N
48	56	\N	Paracetamol 500mg	650mg	TDS	5	15	10	t	Only 10 in stock	2026-08-10 17:14:43.232144+05:30	\N	\N	\N	\N	\N
49	58	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 17:42:48.607865+05:30	2026-08-10 17:42:50.269283+05:30	2	revised by doctor	\N	\N
50	58	\N	Paracetamol 500mg	650mg	TDS	5	15	15	f	\N	2026-08-10 17:42:50.269283+05:30	2026-08-10 17:42:50.707728+05:30	2	revised by doctor	\N	\N
51	58	\N	Paracetamol 500mg	650mg	TDS	5	15	10	t	Only 10 in stock	2026-08-10 17:42:50.707728+05:30	\N	\N	\N	\N	\N
52	64	\N	Paracetamol		TDS	5	0	0	f	\N	2026-08-10 18:19:00.128613+05:30	\N	\N	\N	\N	\N
53	65	\N	Paracetamol		TDS	5	0	0	f	\N	2026-08-10 18:20:04.746101+05:30	\N	\N	\N	\N	\N
54	66	\N	Paracetamol		TDS	5	0	0	f	\N	2026-08-10 18:21:30.406394+05:30	\N	\N	\N	\N	\N
55	68	\N	Paracetamol		TDS	5	0	0	f	\N	2026-08-10 18:22:08.33214+05:30	\N	\N	\N	\N	\N
56	74	\N	Paracetamol		TDS	5	0	0	f	\N	2026-08-10 18:23:37.797365+05:30	\N	\N	\N	\N	\N
57	82	\N	Paracetamol		TDS	5	0	0	f	\N	2026-08-10 18:24:05.965459+05:30	\N	\N	\N	\N	\N
58	90	\N	Paracetamol		TDS	5	0	0	f	\N	2026-08-10 18:26:57.639489+05:30	\N	\N	\N	\N	\N
59	98	\N	Paracetamol		TDS	5	0	0	f	\N	2026-08-10 18:27:28.360022+05:30	\N	\N	\N	\N	\N
60	106	\N	Paracetamol		TDS	5	0	0	f	\N	2026-08-10 18:27:59.83734+05:30	\N	\N	\N	\N	\N
61	114	\N	Paracetamol		TDS	5	0	0	f	\N	2026-08-10 18:29:37.764904+05:30	\N	\N	\N	\N	\N
62	122	\N	Paracetamol		TDS	5	0	0	f	\N	2026-08-10 18:30:50.022602+05:30	\N	\N	\N	\N	\N
63	129	\N	Paracetamol		TDS	5	0	0	f	\N	2026-08-10 18:31:10.528909+05:30	\N	\N	\N	\N	\N
64	136	\N	Paracetamol		TDS	5	0	0	f	\N	2026-08-10 18:31:46.509697+05:30	2026-08-10 18:32:00.415542+05:30	2	revised by doctor	\N	\N
65	136	\N	Paracetamol		TDS	5	0	0	f	\N	2026-08-10 18:32:00.415542+05:30	\N	\N	\N	\N	\N
66	157	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 13:46:27.293393+05:30	\N	\N	\N	\N	\N
68	159	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 13:52:51.223907+05:30	\N	\N	\N	\N	\N
69	165	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:08:49.795904+05:30	\N	\N	\N	\N	\N
70	166	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:08:50.044444+05:30	\N	\N	\N	\N	\N
71	168	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:09:11.67428+05:30	\N	\N	\N	\N	\N
72	169	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:09:11.863774+05:30	\N	\N	\N	\N	\N
102	198	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:17:35.750507+05:30	\N	\N	\N	\N	\N
103	199	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:17:36.448812+05:30	\N	\N	\N	\N	\N
104	201	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:18:05.08614+05:30	\N	\N	\N	\N	\N
105	202	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:18:05.563177+05:30	\N	\N	\N	\N	\N
106	204	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:19:22.175698+05:30	\N	\N	\N	\N	\N
107	205	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:19:22.729733+05:30	\N	\N	\N	\N	\N
108	207	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:19:52.360643+05:30	\N	\N	\N	\N	\N
109	208	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:19:52.777109+05:30	\N	\N	\N	\N	\N
110	211	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:25:52.733902+05:30	\N	\N	\N	\N	\N
111	212	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:25:53.342512+05:30	\N	\N	\N	\N	\N
112	215	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:31:08.923963+05:30	\N	\N	\N	\N	\N
113	216	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:31:09.291038+05:30	\N	\N	\N	\N	\N
114	219	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:32:17.224017+05:30	\N	\N	\N	\N	\N
115	220	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 14:32:17.453399+05:30	\N	\N	\N	\N	\N
116	223	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 15:10:01.555864+05:30	\N	\N	\N	\N	\N
117	224	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 15:10:01.921808+05:30	\N	\N	\N	\N	\N
118	227	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 15:53:56.811231+05:30	\N	\N	\N	\N	\N
119	228	\N	Paracetamol	500mg	TDS	5	15	15	f	\N	2026-08-11 15:53:57.075533+05:30	\N	\N	\N	\N	\N
\.


--
-- TOC entry 5914 (class 0 OID 31215)
-- Dependencies: 275
-- Data for Name: previous_prescription; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.previous_prescription (previous_rx_id, patient_id, appointment_id, medicine_name, dosage, frequency, duration, prescribed_on, created_at, deleted_at, deleted_by, delete_reason, legacy_id, legacy_source) FROM stdin;
\.


--
-- TOC entry 5898 (class 0 OID 30867)
-- Dependencies: 259
-- Data for Name: referral_destination_master; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.referral_destination_master (destination_id, destination_name, is_active) FROM stdin;
1	District Hospital	t
2	PHC	t
3	Specialist	t
4	Diagnostic Lab	t
5	Ophthalmology	t
\.


--
-- TOC entry 5937 (class 0 OID 57363)
-- Dependencies: 307
-- Data for Name: refresh_session; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.refresh_session (session_id, user_id, token_hash, issued_at, expires_at, last_used_at, revoked_at, user_agent) FROM stdin;
1	1	a562907262ec8065479158493540b8e4b0e4735bea6e937a59b344223ad690b6	2026-08-11 13:18:08.105277+05:30	2026-09-10 13:18:08.104457+05:30	2026-08-11 13:18:08.417476+05:30	2026-08-11 13:18:08.417476+05:30	curl/8.14.1
4	1	fe45fd65b022a7c38c866ea8d50844a9e6eeb74a9aafc85af53135d1b64f1feb	2026-08-11 13:18:09.485558+05:30	2026-09-10 13:18:09.485405+05:30	2026-08-11 13:18:09.605939+05:30	2026-08-11 13:18:09.605939+05:30	PhoneB
6	1	4b7bcbeb71918b49ce5287e6dbfc07298d6f3c01b73aa60647fde76c19918074	2026-08-11 13:18:25.123574+05:30	2026-09-10 13:18:25.123408+05:30	2026-08-11 13:18:25.415003+05:30	2026-08-11 13:18:25.415003+05:30	curl/8.14.1
8	1	6797dbade8c07f1c453043d7dec4c18e756a2dcb5ca08ad4b4298dcfd8a88543	2026-08-11 13:19:54.368721+05:30	2026-09-10 13:19:54.368429+05:30	2026-08-11 13:19:55.097711+05:30	2026-08-11 13:19:55.097711+05:30	PhoneA
9	1	4a4b1ac3bbf0944a3d3f23cdd81bde6c796da1618e0cff5858b50e50e883bb56	2026-08-11 13:19:54.900333+05:30	2026-09-10 13:19:54.900123+05:30	2026-08-11 13:19:55.307637+05:30	2026-08-11 13:19:55.307637+05:30	PhoneB
10	1	464da896161092cd38b1a9f627c89e85086490e72152108c62cffe66fe3a35ce	2026-08-11 13:19:55.102815+05:30	2026-09-10 13:19:55.102621+05:30	\N	2026-08-11 13:20:20.234934+05:30	curl/8.14.1
11	1	e21403f777ee6dbbc3467313dbe60a74ba93d456cef2241ee73cdfac6d9f9c1a	2026-08-11 13:19:55.309356+05:30	2026-09-10 13:19:55.309216+05:30	\N	2026-08-11 13:20:20.234934+05:30	curl/8.14.1
12	1	0f403158a5a12a5a5669eae3079760af4aea2c29330e25c5daf3ad3a788aea59	2026-08-11 13:20:19.74167+05:30	2026-09-10 13:20:19.741263+05:30	\N	2026-08-11 13:20:20.234934+05:30	curl/8.14.1
13	1	6c0d136f1e9615aea8edad7fc2f292d097262d0c7e6170cabca60889ff5af2e3	2026-08-11 13:20:21.016622+05:30	2026-09-10 13:20:21.016394+05:30	\N	2026-08-11 13:20:21.816981+05:30	curl/8.14.1
19	2	efe943b6d0a73f386e6ca505784eb75a60cf392c581495a66c92bec1d5460739	2026-08-11 13:39:33.762767+05:30	2026-09-10 13:39:33.762593+05:30	\N	\N	curl/8.14.1
21	2	03c020236d4b9e1c63ba8c7cb43a2a5285898fa99f344ea260134ea321b56226	2026-08-11 13:46:26.728815+05:30	2026-09-10 13:46:26.728513+05:30	\N	\N	curl/8.14.1
28	5	1a86aa44a7f6d2f454d389955dc955e228eb6402d6dcf0c897d6217873490c18	2026-08-11 13:56:31.375881+05:30	2026-09-10 13:56:31.375727+05:30	\N	\N	node
29	3	b5a7d316b315f00a1a2857e29d064cbcbcadd3904b8388c46421c000be00f33c	2026-08-11 13:56:31.958348+05:30	2026-09-10 13:56:31.957474+05:30	\N	\N	node
30	3	a34303081c11775803c13566548042bbf3f8fd12e10075c14a6f41324f07e808	2026-08-11 13:56:32.430392+05:30	2026-09-10 13:56:32.430128+05:30	\N	\N	node
32	19	eff8b99e1cafcf121eb822441121961cc9f05d7169dfc70b9a6ba0c17027ff7e	2026-08-11 13:56:44.248656+05:30	2026-09-10 13:56:44.248442+05:30	\N	\N	node
33	20	32200ead2f80c8c0ee39845bde77efed64f599014e4f30c7fb08f604b27a6701	2026-08-11 13:56:45.766963+05:30	2026-09-10 13:56:45.766648+05:30	\N	\N	node
34	18	bc7b76a0e5a33344bb36c18c22f4b48b87a12287b01e2644a3630eb11bd6961f	2026-08-11 13:56:47.686259+05:30	2026-09-10 13:56:47.686029+05:30	\N	\N	node
35	18	972f5f07ca6282c9dfce8b08e3d84b8cfbc43935c8a74c04b00ee7d141e6fefa	2026-08-11 13:56:49.194612+05:30	2026-09-10 13:56:49.194439+05:30	\N	\N	node
36	17	d7725bc405a9fbd74d777d68d7944e2f87ebd333197da0adecaa5107aedfada0	2026-08-11 13:56:50.026799+05:30	2026-09-10 13:56:50.026612+05:30	\N	\N	node
37	18	e10f155a2d0ed946c77dccaad8c15f6f03b49ce17fc5d2013f00e884cae5b977	2026-08-11 13:56:50.948453+05:30	2026-09-10 13:56:50.948111+05:30	\N	\N	node
38	18	07c1b2379187737365b11dad97d39981bb345ab4634f157b37a0c4e448c00ef2	2026-08-11 13:56:52.031647+05:30	2026-09-10 13:56:52.031483+05:30	\N	\N	node
39	18	9c0feadb635dd71554a64f113ad29fc7954edd7043e640fff6f7f113f7b0f1e7	2026-08-11 13:56:53.253812+05:30	2026-09-10 13:56:53.253573+05:30	\N	\N	node
40	17	150e092c833f7c94ef8f8289380924c22d8022ad49bbd9211af0e8a9a83507c5	2026-08-11 13:56:54.198391+05:30	2026-09-10 13:56:54.198071+05:30	\N	\N	node
41	18	bdc8353e1f6e442a5161cce3140b786d88dee817cc841341eb9bb9bae04ee2f2	2026-08-11 13:56:54.697487+05:30	2026-09-10 13:56:54.697251+05:30	\N	\N	node
42	18	a55ddf933828090f3f4dd81c06532be10eae3cd9658812d4709e69188b378209	2026-08-11 13:56:55.13529+05:30	2026-09-10 13:56:55.135124+05:30	\N	\N	node
43	19	0a53fb65c90a60ae5dba805f341fd10e5b1f4ed336b8fd303dcce2d2c50f86c9	2026-08-11 13:56:55.51361+05:30	2026-09-10 13:56:55.513449+05:30	\N	\N	node
44	18	f6b0614d5ac12edaca81c646cd2351566c8a0b606ee6a9bb6a9933a38f5bb419	2026-08-11 13:56:55.909074+05:30	2026-09-10 13:56:55.908909+05:30	\N	\N	node
45	17	cc5828ec4b6a3563b9d4b64430bd50dafeb8f71b8d286fa8cc9b8467b3ddf711	2026-08-11 13:56:56.428401+05:30	2026-09-10 13:56:56.428238+05:30	\N	\N	node
46	17	4c90d27eba03fc96856f6104e74f64cd7f87daf1c41a0cbdec07b569bcd403bf	2026-08-11 13:56:56.801162+05:30	2026-09-10 13:56:56.800995+05:30	\N	\N	node
14	1	f7276aff3638d4dc7fd948b3d0848e645dd798f534d15f9a546a3d9bf1bc88f4	2026-08-11 13:20:22.606069+05:30	2026-09-10 13:20:22.605749+05:30	\N	2026-08-11 14:08:50.774999+05:30	curl/8.14.1
15	1	1847d9b395ebb4b22ab03f690a1aca39539e74f65e267f6211678b6e0c983279	2026-08-11 13:21:01.280297+05:30	2026-09-10 13:21:01.280152+05:30	\N	2026-08-11 14:08:50.774999+05:30	curl/8.14.1
16	1	c92e153e94e1fe76780d75b84008874a24eeff992d332d4b8052ffde4ac75656	2026-08-11 13:37:19.21661+05:30	2026-09-10 13:37:19.216102+05:30	\N	2026-08-11 14:08:50.774999+05:30	curl/8.14.1
17	1	429809cab79a934b644bf09e7e6266fef45075e821751111637513d06dbdc5c0	2026-08-11 13:37:45.629265+05:30	2026-09-10 13:37:45.629077+05:30	\N	2026-08-11 14:08:50.774999+05:30	curl/8.14.1
18	1	1b60d52d72dc52571d171d731b52a677f7a588adee31abcb2b64c6ea84d39b6b	2026-08-11 13:39:32.759074+05:30	2026-09-10 13:39:32.75875+05:30	\N	2026-08-11 14:08:50.774999+05:30	curl/8.14.1
20	1	3ccbb0d438b9a6c8530ee74cbcd0eae1dc2de27d8feb1fe9ba21d958e14d3a24	2026-08-11 13:46:02.213005+05:30	2026-09-10 13:46:02.212613+05:30	\N	2026-08-11 14:08:50.774999+05:30	curl/8.14.1
22	1	5cf145349cda2e7a7f7740f7bc7970bfca2d6c6d38ecda1d7731a4ab71abebe3	2026-08-11 13:47:52.485764+05:30	2026-09-10 13:47:52.485119+05:30	\N	2026-08-11 14:08:50.774999+05:30	curl/8.14.1
23	1	f4ab83183a81ae5e49798f155d821f1d8f803060e5281529209b5b641fad1ea2	2026-08-11 13:49:37.789838+05:30	2026-09-10 13:49:37.789546+05:30	\N	2026-08-11 14:08:50.774999+05:30	curl/8.14.1
24	1	9e46304dba1c93c1242db5b1f9be2e1762450a1e7ed343deda3a2855d69fffbf	2026-08-11 13:51:42.035142+05:30	2026-09-10 13:51:42.034138+05:30	\N	2026-08-11 14:08:50.774999+05:30	curl/8.14.1
25	1	dae26bfcfe580be2e6e85a8440eadef80cfe5a369b910699aabb8403e8d75ca4	2026-08-11 13:52:51.05526+05:30	2026-09-10 13:52:51.054929+05:30	\N	2026-08-11 14:08:50.774999+05:30	curl/8.14.1
26	1	bfd9a98a8a16d725cd4a7c6c14c310219f1f87bbd59000ea4e837e0283e7ac7f	2026-08-11 13:54:51.351217+05:30	2026-09-10 13:54:51.35097+05:30	\N	2026-08-11 14:08:50.774999+05:30	curl/8.14.1
27	1	4ddc57a289fd160b9c0691121a281da3dfb0eb3c0f80981aee002e8cef2f8f0f	2026-08-11 13:55:32.364683+05:30	2026-09-10 13:55:32.364495+05:30	\N	2026-08-11 14:08:50.774999+05:30	curl/8.14.1
624	2	2ff1d026526f9c43d3d414570a794615a50198245dcda88c91361cefb128ead1	2026-08-11 14:17:35.655676+05:30	2026-09-10 14:17:35.655358+05:30	\N	\N	node
625	1	6308f62d13aa78d550ac002db76c5a0dc1796f79acb085995154efa4ce5c6be4	2026-08-11 14:17:36.911561+05:30	2026-09-10 14:17:36.911348+05:30	\N	2026-08-11 14:17:37.385895+05:30	node
626	1	cee01f26caa66c7e591f2648a9bcb0b72fa868d7e3aca871bec6716e6ce3db2b	2026-08-11 14:17:37.378929+05:30	2026-09-10 14:17:37.378739+05:30	\N	2026-08-11 14:17:37.385895+05:30	node
622	1	e7984181d8e361d544cce51e649de21b21dff31f8874e31115deffd4b6485257	2026-08-11 14:17:34.517836+05:30	2026-09-10 14:17:34.517498+05:30	\N	2026-08-11 14:17:37.385895+05:30	node
623	1	db94d43999ba486e8522d899f7899fa0f4c5115f0e8728c5893980dba91b2010	2026-08-11 14:17:34.530544+05:30	2026-09-10 14:17:34.530329+05:30	\N	2026-08-11 14:17:37.385895+05:30	node
627	1	3714b3c4690c7814663dba89bb2bdb8019f1eb84ef4c86b89e21edd250ec04c5	2026-08-11 14:18:02.248915+05:30	2026-09-10 14:18:02.248647+05:30	2026-08-11 14:18:03.039725+05:30	2026-08-11 14:18:03.039725+05:30	node
629	1	91a774e78cb4658b3b3a54420b89c701e5bb77443cc62e617a5591cd8de7d9c3	2026-08-11 14:18:03.607845+05:30	2026-09-10 14:18:03.607551+05:30	2026-08-11 14:18:04.090565+05:30	2026-08-11 14:18:04.090565+05:30	node
630	1	0f59dd0cd55c9127a96db5423ec2d7a4d1fe6da327278eae7d9f729d5d40f018	2026-08-11 14:18:04.080759+05:30	2026-09-10 14:18:04.080519+05:30	2026-08-11 14:18:04.101809+05:30	2026-08-11 14:18:04.101809+05:30	node
633	2	485a2579c6f517873b039abc7e35021adfa80ea77f1f31da090d508e74a761aa	2026-08-11 14:18:04.925686+05:30	2026-09-10 14:18:04.925428+05:30	\N	\N	node
628	1	1f77e5f3aaeb456cbcd8886058fac5a9a281e1e754fa2c5753267127340bc46c	2026-08-11 14:18:03.042762+05:30	2026-09-10 14:18:03.042474+05:30	\N	2026-08-11 14:18:06.551415+05:30	node
47	18	6f463bab3d3cfcdd87416f1960711ad1a4b61b6a62c1bfcd2ad1a32347fa92b7	2026-08-11 13:57:00.681471+05:30	2026-09-10 13:57:00.681161+05:30	\N	\N	node
48	19	6c4eca0aa59990f77387769976d73bd3cfd98aafbe33b1d32f23fb34b9a6fcc6	2026-08-11 13:57:04.407263+05:30	2026-09-10 13:57:04.407095+05:30	\N	\N	node
49	20	e519014051e0b7287ccbc34c2649e412c9f7f3a3112c65974de03a785007a0c2	2026-08-11 13:57:06.063245+05:30	2026-09-10 13:57:06.062954+05:30	\N	\N	node
50	17	6c1f3cc976be9884c623778356c507299ed8b0720cbf76f26bde118d429ebe65	2026-08-11 13:57:07.805604+05:30	2026-09-10 13:57:07.805132+05:30	\N	\N	node
51	19	3ff80ae28d9eb3bfefcb5f89db44ca753a20c2014fd4e843f52184dd87b7c532	2026-08-11 13:57:08.126006+05:30	2026-09-10 13:57:08.125832+05:30	\N	\N	node
52	20	77dbd3c52b0212edcb44eb19377992da660dcaf4c2703fadaa21ae1c15eaf733	2026-08-11 13:57:08.515994+05:30	2026-09-10 13:57:08.515835+05:30	\N	\N	node
53	17	d84eb74867f47a6ed992a5ef773d05d8723769d636f69ca5150a1a26af50f4b8	2026-08-11 13:57:09.232471+05:30	2026-09-10 13:57:09.232174+05:30	\N	\N	node
54	18	d923dc26ae9c33cc745ec704f5dbbdfbce629b8499c6ac1a3b439a4681ae262c	2026-08-11 13:57:09.633938+05:30	2026-09-10 13:57:09.633727+05:30	\N	\N	node
55	19	83b06b2fea77095554c5acf01f023396348a0b3bdacfb2e39770061c840e879a	2026-08-11 13:57:10.330744+05:30	2026-09-10 13:57:10.330541+05:30	\N	\N	node
56	20	32be5d47c6c8e53150c7c600989e7f8712cd9b8a0a2736efcba7cffa827f1225	2026-08-11 13:57:10.777758+05:30	2026-09-10 13:57:10.777586+05:30	\N	\N	node
57	19	978c9d04bb6d07ab2fa9f4192aa30a8d3d6d556f6c06a53ead666744844e140e	2026-08-11 13:57:11.194665+05:30	2026-09-10 13:57:11.194501+05:30	\N	\N	node
58	5	0e578bba661e96170b95443084dd85632cce507b85106ab00c8794be62dc034f	2026-08-11 13:57:23.58594+05:30	2026-09-10 13:57:23.585733+05:30	\N	\N	node
59	3	a07773406916854e008f9b33842122ceaa4bc4405b564bb668f3b9e7d08e7f54	2026-08-11 13:57:24.06464+05:30	2026-09-10 13:57:24.064472+05:30	\N	\N	node
60	3	8b2b706f5a09082d60ab176527dcdf9d57d8f5469fce4d4082d9299c02a7da68	2026-08-11 13:57:24.387437+05:30	2026-09-10 13:57:24.387268+05:30	\N	\N	node
61	5	18c5bc72487659e0aeb1e3f0740c2e3e3695b0d6dab76b69ac684e17004377fb	2026-08-11 13:57:34.3915+05:30	2026-09-10 13:57:34.391329+05:30	\N	\N	node
62	3	beafc544d9598726c7fec1c2222a66fde70ee4b1c80e3d78c5528989c9be517b	2026-08-11 13:57:34.836897+05:30	2026-09-10 13:57:34.836701+05:30	\N	\N	node
63	3	15db56e3abe772cdb9dcff722a0bdd543bf846a10b98007def32d99b9754706c	2026-08-11 13:57:35.164542+05:30	2026-09-10 13:57:35.16437+05:30	\N	\N	node
64	5	aaf90391c5eb50294bfed13a35f668179fbd021fa51f1bc46ea3b16d439f877e	2026-08-11 13:58:17.499665+05:30	2026-09-10 13:58:17.499446+05:30	\N	\N	node
65	3	bf8712d8cf780163d98cbfdc5e5db6b38c12740077aa5e08bc4837b8b4c93e33	2026-08-11 13:58:17.971043+05:30	2026-09-10 13:58:17.970862+05:30	\N	\N	node
66	3	ba6f3dffc3110e29715c21c4a4341fc3b059ea31716190449934c0f870ad8e0e	2026-08-11 13:58:18.293704+05:30	2026-09-10 13:58:18.293515+05:30	\N	\N	node
68	19	fadaaddd30e08453d83a2d3c6300d0f8d275ee55d63f1f0317b5dab4d7612c7d	2026-08-11 13:58:24.202631+05:30	2026-09-10 13:58:24.202268+05:30	\N	\N	node
69	20	d580122f95c0f013d70f5a192069a0915189253402b5942c9c4fe91724d34f8a	2026-08-11 13:58:25.084622+05:30	2026-09-10 13:58:25.084421+05:30	\N	\N	node
70	18	380cb544d2bdefe79309276b0affec6566e22e8cadf1101baf17eb712d6f05fc	2026-08-11 13:58:25.642377+05:30	2026-09-10 13:58:25.642081+05:30	\N	\N	node
71	18	4056a4994b699aa11600a78c4d1d7b6740c52caebb029e703c62c6b1507ba501	2026-08-11 13:58:26.854031+05:30	2026-09-10 13:58:26.853585+05:30	\N	\N	node
72	17	20bf824eaf4a2c5686181919cfca7157195c48d76c8710401e6e8d91b373824f	2026-08-11 13:58:27.549362+05:30	2026-09-10 13:58:27.54919+05:30	\N	\N	node
73	18	3a16770ac125d3352e2e6c1f1eec0bfc5e0b2a997800cd9260a1d09d539e647b	2026-08-11 13:58:28.245988+05:30	2026-09-10 13:58:28.24582+05:30	\N	\N	node
74	18	41d23ae6e88ea9d081db142bd50c831b939a96bcb8375afb2741b728fb6fedbc	2026-08-11 13:58:28.899665+05:30	2026-09-10 13:58:28.899479+05:30	\N	\N	node
75	18	56e9b677786c059336d7850b9b35a173ec7a0cd2d4df9db2decbd6593652a506	2026-08-11 13:58:29.614017+05:30	2026-09-10 13:58:29.613774+05:30	\N	\N	node
76	17	fd1cd23c618ea41c2845bd8efce82f9a9b9180dbc09ca571f30924b5b369c10a	2026-08-11 13:58:30.074294+05:30	2026-09-10 13:58:30.074031+05:30	\N	\N	node
77	18	fce5144a031de7bfa0e7ca6636f10b328bd7669f2d1e7acd39541dcbfa35e4ef	2026-08-11 13:58:30.494096+05:30	2026-09-10 13:58:30.493926+05:30	\N	\N	node
78	18	36ccabaa3a94cc75a8cf248b7a431d67fa2938f58a942354a276b766bd340237	2026-08-11 13:58:30.942067+05:30	2026-09-10 13:58:30.941608+05:30	\N	\N	node
79	19	d53ed1496ab9e790a60c62b942211cdb01f8e7116c32e5778b7f26f5d53302a9	2026-08-11 13:58:31.341627+05:30	2026-09-10 13:58:31.34138+05:30	\N	\N	node
80	18	0b89a090c54f23a0acf32214dd23fb4feba4de05c7d56eb167c558de954f7433	2026-08-11 13:58:31.785332+05:30	2026-09-10 13:58:31.785192+05:30	\N	\N	node
81	17	ec4063d87672f5640e03afc653cb079675fc2107ad30bdc60c5de90ad1530969	2026-08-11 13:58:32.246177+05:30	2026-09-10 13:58:32.245995+05:30	\N	\N	node
82	17	40fc605ac612e1205379198ce655008956ed4c1ceab6e01e75cba3ddef1ce163	2026-08-11 13:58:32.566318+05:30	2026-09-10 13:58:32.566162+05:30	\N	\N	node
83	18	40b6d261862e0281e638cd92ff164aa20929a6c082cefb605c30ecd29e460389	2026-08-11 13:58:36.51719+05:30	2026-09-10 13:58:36.516904+05:30	\N	\N	node
84	19	c77828ffb782a71b25385f491e1a2d96242423e8f9cd9621129cc06dcd3f07bf	2026-08-11 13:58:40.281066+05:30	2026-09-10 13:58:40.280896+05:30	\N	\N	node
85	20	dcf5c398bb07d24448dd5a16a1b9ec8f6e7ca7ecb167f28da3be2620b68c1643	2026-08-11 13:58:41.978315+05:30	2026-09-10 13:58:41.978122+05:30	\N	\N	node
86	17	7193793dd31e7ae9a719d4241b44954fd6649d851fca3f31548ed2c291df5e23	2026-08-11 13:58:43.642262+05:30	2026-09-10 13:58:43.642106+05:30	\N	\N	node
87	19	d81a49676db1c3fe32b6b9b2f8bc31f4a4ddc108be8198a022563166f6c37dab	2026-08-11 13:58:43.977237+05:30	2026-09-10 13:58:43.977071+05:30	\N	\N	node
88	20	ebf64e0e6d826008315def679659fe901659eac5f29c6543a0dbde598b64bbe0	2026-08-11 13:58:44.293575+05:30	2026-09-10 13:58:44.293353+05:30	\N	\N	node
89	17	867de931880ff4e6ce45b7b5d4a426d1263062ddb3c3dbae70563ea11c8edcb4	2026-08-11 13:58:44.694635+05:30	2026-09-10 13:58:44.694361+05:30	\N	\N	node
90	18	61e712ab4f3b494c66754148e137bdcc5fae3066ccb05eb6b3964f2f6150db95	2026-08-11 13:58:45.035462+05:30	2026-09-10 13:58:45.035233+05:30	\N	\N	node
91	19	b4d924d72534eda7543555eaff33cd5f2170c016965726cf13268dedc30ee7f8	2026-08-11 13:58:45.869825+05:30	2026-09-10 13:58:45.869661+05:30	\N	\N	node
92	20	8c9b6dfc0b69f0eb49d8e151dd829685bacf7223e50530581e99ebecb22008c4	2026-08-11 13:58:46.24843+05:30	2026-09-10 13:58:46.248247+05:30	\N	\N	node
93	19	daa2c9342a9a2b4bee5ebbd70fec35884e88589ea56d02339fa960a93e558d7d	2026-08-11 13:58:46.734513+05:30	2026-09-10 13:58:46.734258+05:30	\N	\N	node
94	5	b30fcaae07115ffbf35db4b528bc39a7486ac42137efde93808f01eac5de83f0	2026-08-11 13:58:55.750594+05:30	2026-09-10 13:58:55.750288+05:30	\N	\N	node
95	3	e4e5b72d47a5089711d1c8f305ab1f3bc5cbe9d22a9b9ab6f45ca6ee80feeba4	2026-08-11 13:58:56.295099+05:30	2026-09-10 13:58:56.29493+05:30	\N	\N	node
96	3	e6e68a6dc14953064af6016d092fd43132d6737f56e16e33ee13f5e0108a3730	2026-08-11 13:58:56.610339+05:30	2026-09-10 13:58:56.610173+05:30	\N	\N	node
97	5	892b267a4eaf72c3705a96e94c74616e6872fc003e71d928b2f58ad1d4565f54	2026-08-11 13:59:28.143727+05:30	2026-09-10 13:59:28.143512+05:30	\N	\N	node
98	3	3843810d1cee898c4e3551232ff2cbbfd2640c8fd1f892889f8c82391096f929	2026-08-11 13:59:28.527554+05:30	2026-09-10 13:59:28.527373+05:30	\N	\N	node
99	3	7cd3415120c3403babca0ab2affc41cd66af449372e0e1f6076c4a27c40a4bb5	2026-08-11 13:59:28.926027+05:30	2026-09-10 13:59:28.925736+05:30	\N	\N	node
100	7	40494b4d86c040c2b11a36244971ceb56627a5337a2b76dac1956b98764a1973	2026-08-11 13:59:29.476765+05:30	2026-09-10 13:59:29.47659+05:30	\N	\N	node
101	8	7e7700249b7b2a1808e1dd6946f31bee0b6e250c9b2578f7eca1589ef90ca4fc	2026-08-11 13:59:30.015266+05:30	2026-09-10 13:59:30.015086+05:30	\N	\N	node
102	17	de1f7f719f192097deecb0b2956a4740dcc715e0d907f938585a4c5151f62212	2026-08-11 13:59:30.50399+05:30	2026-09-10 13:59:30.503693+05:30	\N	\N	node
103	172	8b175e41bfc5a1838c8691ef02311d92fdeae3791b78a071822b0ed6176adc0a	2026-08-11 13:59:31.334999+05:30	2026-09-10 13:59:31.334837+05:30	\N	\N	node
104	17	82c174f82deb4d571eb82d45ac4f0e3ad3c3081bf0a2f10b6c19dc2ad4e79697	2026-08-11 13:59:31.7486+05:30	2026-09-10 13:59:31.748287+05:30	\N	\N	node
105	172	1a45eae7667aed0116a131f3ea9e41eced989e8f8489e5e04d3c4220b85a3e99	2026-08-11 13:59:32.861084+05:30	2026-09-10 13:59:32.860909+05:30	\N	\N	node
113	17	6d99370293b6ad689214d07f587a4a89b6d9c5d523bddcd988e11720e50c642a	2026-08-11 13:59:37.591814+05:30	2026-09-10 13:59:37.59146+05:30	\N	\N	node
137	17	2998d21bbbdca110a62786aac271c1d3d7228e19ce558f0e65107a50f7b8f265	2026-08-11 13:59:49.580322+05:30	2026-09-10 13:59:49.579708+05:30	\N	\N	node
146	18	121c114e7384b12a6064f2f978a00bd0fcc364c8457b9898c0f3c12701a48164	2026-08-11 13:59:53.88877+05:30	2026-09-10 13:59:53.888591+05:30	\N	\N	node
152	18	edaf01f543448e91d3404aeeae04b1bf9c5babd044eb5ae3a5371d484563bda2	2026-08-11 14:00:02.056782+05:30	2026-09-10 14:00:02.056361+05:30	\N	\N	node
148	1	e6f6bd4c57da74b6849c887425f02953028af39224940008f4e25d3249ccfea3	2026-08-11 13:59:56.829771+05:30	2026-09-10 13:59:56.829493+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
106	17	71915803ca451960b6f70dce23b2f1375acb9922da612ffa7d0941507ed8ac3b	2026-08-11 13:59:33.183489+05:30	2026-09-10 13:59:33.183259+05:30	\N	\N	node
108	17	bf90bb780b2c1fa4d7964895926cac4e4ea160be5b18997a4b9588591dfd25e5	2026-08-11 13:59:34.316843+05:30	2026-09-10 13:59:34.316675+05:30	\N	\N	node
124	17	bfce6f660ab110c356110814e8f7ef5cc783eefb51166e7bec8dcb404a5fe655	2026-08-11 13:59:43.192989+05:30	2026-09-10 13:59:43.192568+05:30	\N	\N	node
130	18	55dcae17d2360a83e65edab9771bf1e694245ba9bf07c49f561e145533130d7e	2026-08-11 13:59:46.064814+05:30	2026-09-10 13:59:46.064642+05:30	\N	\N	node
138	17	1b76d897ca241a3b1d981619a87d61a705f5ed012d2cb0fb7aef4c83dc28b8b6	2026-08-11 13:59:49.987346+05:30	2026-09-10 13:59:49.987197+05:30	\N	\N	node
142	17	a72f6738de76c757026b651f960af3ceb7226bdb17ce55f5990c73cbf58290e5	2026-08-11 13:59:51.60238+05:30	2026-09-10 13:59:51.602206+05:30	\N	\N	node
147	17	a76ae01eb25783ef576e23262e2d2be139a6649804e1f346a4086cd31e439d7e	2026-08-11 13:59:54.58683+05:30	2026-09-10 13:59:54.586601+05:30	\N	\N	node
107	18	0dd31a21ab335deda84511748d7faa83b535a4609c8ffcd440c7da4efde94c35	2026-08-11 13:59:33.519455+05:30	2026-09-10 13:59:33.519236+05:30	\N	\N	node
116	18	1717b5a4dab7572a733cde9fa0356f84be07f585330a40711ef24edda2c2a3c2	2026-08-11 13:59:39.090392+05:30	2026-09-10 13:59:39.089754+05:30	\N	\N	node
117	175	c4d138d4146dd39db1999653f883a1c8975a8ea7bbf03e0c0839ba1ef0a41fa0	2026-08-11 13:59:39.949301+05:30	2026-09-10 13:59:39.94913+05:30	\N	\N	node
123	1	635b07ccee0b2c76682994e4c8530641ed257a38715d84e93dee54682d467490	2026-08-11 13:59:42.816987+05:30	2026-09-10 13:59:42.816813+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
109	18	f973c4d354edb8575e563126d35e5d04ec3ea7496c2d0b5c1c7a5b322f35ec01	2026-08-11 13:59:34.647668+05:30	2026-09-10 13:59:34.64749+05:30	\N	\N	node
128	18	132ac6f09d7f2a6857ced478fbb0c86f5dfb82675d0091bf1f77a02966810551	2026-08-11 13:59:45.277395+05:30	2026-09-10 13:59:45.277251+05:30	\N	\N	node
129	176	d7fbf7f7afb86e7db8a076608deddb49c8271c703f9dc6bb7b4bdc4bd26e5bdb	2026-08-11 13:59:45.751409+05:30	2026-09-10 13:59:45.751224+05:30	\N	\N	node
136	177	eadc3b987617500885b020557b12d5c479795271ac31297e76d37afcee706dc3	2026-08-11 13:59:49.191487+05:30	2026-09-10 13:59:49.191132+05:30	\N	\N	node
143	18	9557927347353cb97718d590ea440c1f59bc8cbf4f0c0cdaf3df1caa5faeb108	2026-08-11 13:59:52.024167+05:30	2026-09-10 13:59:52.023707+05:30	\N	\N	node
151	18	8c4e3a51c2dca562cc577e1a442f1ee50b0c2b9cea7b15093490ce6284ac20a2	2026-08-11 14:00:00.770383+05:30	2026-09-10 14:00:00.770189+05:30	\N	\N	node
110	17	d696d74dbb5f2c68ce9b801fbd37e70c49278509d2f403a77b1cf64e14405344	2026-08-11 13:59:36.043178+05:30	2026-09-10 13:59:36.042711+05:30	\N	\N	node
115	174	07dffd0febf92c96094bb1b6b874a3e866fdb7efd1b12bff09ca39f8288086e5	2026-08-11 13:59:38.78099+05:30	2026-09-10 13:59:38.780817+05:30	\N	\N	node
119	174	37a2d978381bd7eb6fca2d6880a8748c70b77cf453223643ba4b4ffde55f1e32	2026-08-11 13:59:41.397082+05:30	2026-09-10 13:59:41.396851+05:30	\N	\N	node
125	18	dc86686f7ec810e274ba801be80c20534cc388150af1ab8bbe034f029af61e60	2026-08-11 13:59:43.548345+05:30	2026-09-10 13:59:43.548189+05:30	\N	\N	node
111	17	b19b9bf90fdba1732d38aa7611dc33c923394ad6e98891e389244baf0a0aa356	2026-08-11 13:59:36.426612+05:30	2026-09-10 13:59:36.425742+05:30	\N	\N	node
122	18	dd5e1ed031dffcb2f26f9ddd6472922513e2a5933e3b2e79d667bedd6d3c64e0	2026-08-11 13:59:42.449328+05:30	2026-09-10 13:59:42.44913+05:30	\N	\N	node
145	17	152550927b919e579687c70614e8d809c2c09e2273f6626ad66d1ab2ca69db79	2026-08-11 13:59:53.5769+05:30	2026-09-10 13:59:53.576724+05:30	\N	\N	node
112	18	d3189f8bcdecd01e6975ee238ab9eba326cc9009a70c0e73e6512d5c51d64e75	2026-08-11 13:59:37.254211+05:30	2026-09-10 13:59:37.253883+05:30	\N	\N	node
144	18	81117c658673c2f10aa769c8b082a7182a1d16dfe7d151f688a1d61d68a5db8f	2026-08-11 13:59:53.230557+05:30	2026-09-10 13:59:53.230322+05:30	\N	\N	node
114	18	f344092d324963e4de251a462b464fc872febe1e2dc11c020bae3db6cc7a88fe	2026-08-11 13:59:37.922114+05:30	2026-09-10 13:59:37.921935+05:30	\N	\N	node
127	18	4f5e077fae8a63769316ab81b5d0330b2f1d177c9778a910b42787ba8b573bdb	2026-08-11 13:59:44.750918+05:30	2026-09-10 13:59:44.750746+05:30	\N	\N	node
131	176	070bcf45a51e13552273483ac76ba3ff98ab287e16f4a0417c8c0337337395ea	2026-08-11 13:59:46.5014+05:30	2026-09-10 13:59:46.501206+05:30	\N	\N	node
135	17	c6852bc0ccd355f720a209c6499fbb66de709cf669038ba84a4fdd9307cc1ad1	2026-08-11 13:59:48.245885+05:30	2026-09-10 13:59:48.245701+05:30	\N	\N	node
139	177	092fc7db54f2a69feb59f06e69d439e6638b986f745caae62d02d7e6131a6a5d	2026-08-11 13:59:50.364989+05:30	2026-09-10 13:59:50.364776+05:30	\N	\N	node
149	19	27d1c6c623dbe5da341fa09bac1cf64ca5fa8b39644bcab7191ff588d057fc1d	2026-08-11 13:59:59.451499+05:30	2026-09-10 13:59:59.451276+05:30	\N	\N	node
118	18	b9a890184a5558fbfb1b14cffb7bf7dabbd9743ae6698d8a087a26606d33f271	2026-08-11 13:59:40.257411+05:30	2026-09-10 13:59:40.257152+05:30	\N	\N	node
121	17	17a6d24b6573e9970b8de09651e925d1297e57e3cbb1918073621e821c014243	2026-08-11 13:59:42.089299+05:30	2026-09-10 13:59:42.089085+05:30	\N	\N	node
126	176	146eb9bcc7b1c9b9b109d661fe9fb5f2312deab455fd010d5297a0a36319048a	2026-08-11 13:59:44.438234+05:30	2026-09-10 13:59:44.438073+05:30	\N	\N	node
134	17	db2f103d03687dbce53f2b7e8430ee97fe23d807146ede8d133f17174cf277ef	2026-08-11 13:59:47.873276+05:30	2026-09-10 13:59:47.873012+05:30	\N	\N	node
120	18	f22ab2527955bc01428d978cbb781ac66d7b357e2b58bb86ca6a8d8e7b449357	2026-08-11 13:59:41.730263+05:30	2026-09-10 13:59:41.730075+05:30	\N	\N	node
132	18	a21b05d94bddabe0e04458dbe6097eaabb5171586090eb8999bd542ef4bbf88c	2026-08-11 13:59:46.883795+05:30	2026-09-10 13:59:46.88353+05:30	\N	\N	node
133	18	b0d80907d4c969dd8c179658467f4560351d37a07f5696e85a82dd8d5dea6175	2026-08-11 13:59:47.544031+05:30	2026-09-10 13:59:47.543861+05:30	\N	\N	node
140	17	514459763f2b9299c9679fdde0b7c41a7e28b12fbd50988c6a0e140b899f6638	2026-08-11 13:59:50.783769+05:30	2026-09-10 13:59:50.783502+05:30	\N	\N	node
141	17	e5b8d9df8d9a85032dd28e1887956714ff9416f7c4478b2aa1bd4f7f62241527	2026-08-11 13:59:51.17546+05:30	2026-09-10 13:59:51.175173+05:30	\N	\N	node
150	20	7cf43f727425d4523f536c600cf4e4f577b80ed14a3692a1521e89c07280f067	2026-08-11 14:00:00.235219+05:30	2026-09-10 14:00:00.235032+05:30	\N	\N	node
153	17	d59ca01faa0cf571163050b0bcbb752c82d4e90bc49c61ff33682f62559768cf	2026-08-11 14:00:02.884641+05:30	2026-09-10 14:00:02.884345+05:30	\N	\N	node
154	18	c65ff5f3fafe6a6b4e5851c0939b3ae4d887dcfea55c9e2740ad7ab75c30f323	2026-08-11 14:00:03.561206+05:30	2026-09-10 14:00:03.561046+05:30	\N	\N	node
155	18	31fe1e0ac964fd4a103374d7c5c96cf04c804c4af0095601f97bd2eb1c66a0db	2026-08-11 14:00:04.230384+05:30	2026-09-10 14:00:04.230121+05:30	\N	\N	node
156	18	8acdd1edfa36a148c4643210559cd9d907f3bab8c8257e934c1c20fd2bb8043d	2026-08-11 14:00:04.877563+05:30	2026-09-10 14:00:04.877374+05:30	\N	\N	node
157	17	a34ff9cb6430b8f88ab2b2064c4a685cdf15f9ee115b75d884607e4c985ee9c8	2026-08-11 14:00:05.350127+05:30	2026-09-10 14:00:05.349817+05:30	\N	\N	node
158	18	3ee0991020c4a66def43dcf3449d7870be2d5a02ed6e03836dcd1677bd1f878e	2026-08-11 14:00:05.748617+05:30	2026-09-10 14:00:05.748446+05:30	\N	\N	node
159	18	0172072c85cd6f91a4394751e6385da9fd558d8c839430c134d6e055507ed9aa	2026-08-11 14:00:06.189828+05:30	2026-09-10 14:00:06.189649+05:30	\N	\N	node
160	19	a7e071501fd95bf0409e6ec27517992a1e7b2a24b48852c457af6dd18d3d500c	2026-08-11 14:00:06.564257+05:30	2026-09-10 14:00:06.56402+05:30	\N	\N	node
161	18	cf8a8af249075def0f3c820f8798d93fa3a6c6d6b6c259c3eaaa465b9b6f9f01	2026-08-11 14:00:07.026588+05:30	2026-09-10 14:00:07.026338+05:30	\N	\N	node
162	17	d73c9c67567b9ee99ce46f2549f3e2fa030b654bbc48ae4e49608409454be494	2026-08-11 14:00:07.536453+05:30	2026-09-10 14:00:07.536277+05:30	\N	\N	node
163	17	3bde755e0aa5fece475a0293aaa3b744a816bafb758ca21a2bb9db9dbedf75e2	2026-08-11 14:00:07.978052+05:30	2026-09-10 14:00:07.977805+05:30	\N	\N	node
164	18	80cdf503f06dcf8533afd1c9c171a9cdb492ceff4c8d751870d0dea50ad6fe0c	2026-08-11 14:00:12.012624+05:30	2026-09-10 14:00:12.012423+05:30	\N	\N	node
165	19	842707b69db702d28554f947b9aed21bf937dc46318e454ec0297126703e9705	2026-08-11 14:00:15.864632+05:30	2026-09-10 14:00:15.864226+05:30	\N	\N	node
166	20	c4f4fd9956f976e17c75e6eeabe940b2de5e4e5fb138376e3031580330e0ff0c	2026-08-11 14:00:17.587462+05:30	2026-09-10 14:00:17.587223+05:30	\N	\N	node
167	17	095e95186ed5a967450ca8eb44b5da8d4331d09ff2777556ec688a81b466a2da	2026-08-11 14:00:19.351111+05:30	2026-09-10 14:00:19.350957+05:30	\N	\N	node
168	19	31c1e78966f610cdd6a718d2babb91e70f4052c3f7f42371cb82558eb1518328	2026-08-11 14:00:19.66381+05:30	2026-09-10 14:00:19.66367+05:30	\N	\N	node
169	20	bac68c25590d2e71a996c9253509986a77459a9089a0c88d78d3e9193e7bd47d	2026-08-11 14:00:19.980321+05:30	2026-09-10 14:00:19.980148+05:30	\N	\N	node
170	17	82c7b1a637bee76e0d2e9e8276e1705489b52b86a5df5ca6a45ca337b183c53c	2026-08-11 14:00:20.33706+05:30	2026-09-10 14:00:20.336855+05:30	\N	\N	node
171	18	ecefa96208134e32d6f783fa6b685e2cc1c0f9526e1985e8e1f19195a7abe8e8	2026-08-11 14:00:20.677268+05:30	2026-09-10 14:00:20.677079+05:30	\N	\N	node
172	19	d1294056d2191307e06c5e096c8fea8810c67bbe3339d0d0448b43a9f28bc478	2026-08-11 14:00:21.385915+05:30	2026-09-10 14:00:21.385607+05:30	\N	\N	node
173	20	e3c6911144c2403e7d56ac37d67a1f9f5114c926362d3acf5db528e88ea57045	2026-08-11 14:00:21.869598+05:30	2026-09-10 14:00:21.869373+05:30	\N	\N	node
174	19	634d340bcf9daad74070705ef6238b648bcb2171c87b4453720878fa2c13886c	2026-08-11 14:00:22.2632+05:30	2026-09-10 14:00:22.262998+05:30	\N	\N	node
177	5	666c9da74f94e5fdce1ef3a1f949ae8ff07595e9a57d8968c6615e8cf876c11c	2026-08-11 14:01:29.83339+05:30	2026-09-10 14:01:29.833149+05:30	\N	\N	node
178	3	1cc4f2c6fc57d6f6cf27b06ba8d418a12c60cdc30d90f955d5e7d62b05497f3f	2026-08-11 14:01:30.412156+05:30	2026-09-10 14:01:30.411902+05:30	\N	\N	node
179	3	98f1804d574ef6d62066c4e98b287debc0b824988c9987ab02cc2746866d9e7d	2026-08-11 14:01:30.744165+05:30	2026-09-10 14:01:30.743745+05:30	\N	\N	node
181	19	8066368d87dd2ebe6537aded33a5a4fb55941647964228e65a40342887a82e74	2026-08-11 14:01:36.578434+05:30	2026-09-10 14:01:36.578179+05:30	\N	\N	node
182	20	59ee97aa2d1f2f3bc5d248a466c0f12dd756bad7869dd1892413023cad39bfb2	2026-08-11 14:01:37.519576+05:30	2026-09-10 14:01:37.519401+05:30	\N	\N	node
183	18	0ab3635695e26c299961f7d02ed0580da9b7c244f85d0f473ef3603260a12a1b	2026-08-11 14:01:38.058694+05:30	2026-09-10 14:01:38.05834+05:30	\N	\N	node
184	18	d38819fc9cc8b97e43a1aa4af857601d69f60c9d9819705fa7c8dbab0e2a5049	2026-08-11 14:01:39.202611+05:30	2026-09-10 14:01:39.202412+05:30	\N	\N	node
185	17	fc023d484bb823776a5ff9e0ec2961d220a36deb157a50d888dfb8348908c660	2026-08-11 14:01:39.934894+05:30	2026-09-10 14:01:39.934698+05:30	\N	\N	node
186	18	b8092c2b1b5997e0b83c0041584308f15a815a24aad087d51d3bb3dc487c041b	2026-08-11 14:01:40.714539+05:30	2026-09-10 14:01:40.714349+05:30	\N	\N	node
187	18	02c74c7cb154a9736a6fd9d3e9c9ae3c10564e379fad42e6a5ad4b9d7c5214fe	2026-08-11 14:01:41.420306+05:30	2026-09-10 14:01:41.420153+05:30	\N	\N	node
188	18	93c5fce7c21085c2619cd4442a22ff0ddac7fe39d6c4f44ec8f8915f518941d6	2026-08-11 14:01:42.115394+05:30	2026-09-10 14:01:42.11526+05:30	\N	\N	node
189	17	c3647881e6e8daee33e3a667d34fb7fc55eb382281b632f10e8aaf5e8375a0da	2026-08-11 14:01:42.576216+05:30	2026-09-10 14:01:42.575526+05:30	\N	\N	node
190	18	69182a09fea4214415622f0d00c35ba0df5fa1da2702e662b3b6cdf9cc02533e	2026-08-11 14:01:43.112478+05:30	2026-09-10 14:01:43.112096+05:30	\N	\N	node
191	18	d62880dda9dc36ddbda26def5740ee0a830552a0fadc5ae60c7cb090d981a8ae	2026-08-11 14:01:43.541095+05:30	2026-09-10 14:01:43.540732+05:30	\N	\N	node
192	19	9e587f480a24d3c1a63177caddaebfecd62bb7a04164dcf907c96542becd617d	2026-08-11 14:01:44.196749+05:30	2026-09-10 14:01:44.196408+05:30	\N	\N	node
193	18	f48936515648f5395b4b8213987146338f84e47cdfe3d62e4eb44ff7f1605f0c	2026-08-11 14:01:44.664854+05:30	2026-09-10 14:01:44.664701+05:30	\N	\N	node
194	17	dcc42bb55b166d6bf40ef14eb629be0e65486113b25fef2f47d3ac54e488389c	2026-08-11 14:01:45.172463+05:30	2026-09-10 14:01:45.172203+05:30	\N	\N	node
195	17	682a90fd3b0a6f717517fb0c3f1b5a5b3827453727cf00639ee94fa2b6b29ad7	2026-08-11 14:01:45.591761+05:30	2026-09-10 14:01:45.591425+05:30	\N	\N	node
196	18	2db9f3481cfc612598b0a997b1787a4939f97e06b2a7a14f2b65012e3619af65	2026-08-11 14:01:49.464132+05:30	2026-09-10 14:01:49.463907+05:30	\N	\N	node
197	19	d0ef00f698ba6cb905d40d28c85af7bd5019bda89e33fa74e10648372af02000	2026-08-11 14:01:53.212058+05:30	2026-09-10 14:01:53.211854+05:30	\N	\N	node
198	20	c85ce5ffe514f8b53cf2fd61061f890d83d7d4a080ceb0c5d855b8b7e48ce70a	2026-08-11 14:01:55.018889+05:30	2026-09-10 14:01:55.018661+05:30	\N	\N	node
199	17	68bcc92126d1e5b48cad7d141e40ddce82d10bfe1d714fe39f8dd91a9e6b9e9f	2026-08-11 14:01:56.729406+05:30	2026-09-10 14:01:56.729141+05:30	\N	\N	node
200	19	f3273c3960f568d12e692e4dd1fa1a3ba7c14b84988ea1909f7230e4bc40a93c	2026-08-11 14:01:57.122537+05:30	2026-09-10 14:01:57.122368+05:30	\N	\N	node
201	20	5f069017d1f71f93d1105af08748ea624d96017816faac2d520c37e5a8a14952	2026-08-11 14:01:57.612278+05:30	2026-09-10 14:01:57.611919+05:30	\N	\N	node
202	17	7969089c136d6f595b41743c45eecd9e9c546613b19322b45d327e446f918856	2026-08-11 14:01:58.030852+05:30	2026-09-10 14:01:58.030608+05:30	\N	\N	node
203	18	935d67ca40564e5de441c45a331a44201547d7025fa92e72dcaddd529aa6aa23	2026-08-11 14:01:58.38591+05:30	2026-09-10 14:01:58.385697+05:30	\N	\N	node
204	19	34d7ce6c275ea9fe18959f6169309aab7fe4e8643b8d0b1fa500dea6b9a74f2e	2026-08-11 14:01:59.222676+05:30	2026-09-10 14:01:59.222131+05:30	\N	\N	node
631	1	47fd7748880c983d531a9e5473c56c4726f1a975b03c1f6cefd4840060f59763	2026-08-11 14:18:04.093163+05:30	2026-09-10 14:18:04.09292+05:30	\N	2026-08-11 14:18:06.551415+05:30	node
632	1	0ec4eaf674b2a0faa48d6bf38c9fd8112d0206b6efbc9e6c727dc1d49e18fb91	2026-08-11 14:18:04.104797+05:30	2026-09-10 14:18:04.103786+05:30	\N	2026-08-11 14:18:06.551415+05:30	node
205	20	435d1ec7f9e5b997d99ecab629055c036c8fe79c1e915191d17cc160004c0e49	2026-08-11 14:01:59.817758+05:30	2026-09-10 14:01:59.817445+05:30	\N	\N	node
222	18	17c8f32e2d32b073ba33207dcf1916fdcb58ca9e69797cfb5ee683a249e73930	2026-08-11 14:02:48.394717+05:30	2026-09-10 14:02:48.394439+05:30	\N	\N	node
226	18	566e4e95d6b928ac588796b7ffaf9d6abdb94eb448f1038ef3769724ed8cdc6f	2026-08-11 14:02:50.74004+05:30	2026-09-10 14:02:50.739821+05:30	\N	\N	node
233	19	12eee2eb8be7b73666f648ee4290169dfd652a1e17fc017858a6e73c5027233c	2026-08-11 14:03:00.762717+05:30	2026-09-10 14:03:00.762441+05:30	\N	\N	node
206	19	14e84b0d07540b8cf99253ec6642dc9055c4294c0663a5cc33b6269a368d45c8	2026-08-11 14:02:00.427408+05:30	2026-09-10 14:02:00.427103+05:30	\N	\N	node
229	18	c3ea95ebd3a21d3c9a43a5ecf7cc9933a642f25627adfc7e35e322753b58ef49	2026-08-11 14:02:52.123885+05:30	2026-09-10 14:02:52.123692+05:30	\N	\N	node
207	5	82c09a8b87566acb5e5f739ac8fd1d8a6a7b19929a3b7739cef6b83c38a2590a	2026-08-11 14:02:12.803276+05:30	2026-09-10 14:02:12.803014+05:30	\N	\N	node
221	17	37d8d6bfe556cdfc7c921e093cc6840256623407ab1c66ee8ec1ffe69220f028	2026-08-11 14:02:47.694588+05:30	2026-09-10 14:02:47.693809+05:30	\N	\N	node
224	18	7fe10f104c2637c8b64ad0372a6cf4b4ebcbebf29d6900fc0bb4e6a090be143e	2026-08-11 14:02:49.783449+05:30	2026-09-10 14:02:49.78324+05:30	\N	\N	node
232	18	fce874c362738a33e180080d113a411d89516f43d773cf0af917301e9a496c19	2026-08-11 14:02:56.969074+05:30	2026-09-10 14:02:56.968898+05:30	\N	\N	node
208	3	565eec7f878e3e0ad5715810db0506501997afecea34b951eda1476132e66c27	2026-08-11 14:02:13.220526+05:30	2026-09-10 14:02:13.220347+05:30	\N	\N	node
213	7	007296accee99b0f4a76b211c534b6cc218a67258e105b444d356ee43f254846	2026-08-11 14:02:36.07141+05:30	2026-09-10 14:02:36.071164+05:30	\N	\N	node
214	8	db3b78dd1a7c52b27386a5a5ea235e9314283a1db99782ee35d047a80938cdcd	2026-08-11 14:02:36.934382+05:30	2026-09-10 14:02:36.934131+05:30	\N	\N	node
209	3	787ca8e022684b5412b2470f8d88c425fb8d904263d172656a7157712eb14c78	2026-08-11 14:02:13.61229+05:30	2026-09-10 14:02:13.612044+05:30	\N	\N	node
210	5	ec87b0e879ec0ecc74c9d37cc0118d9336a3d3639c39c30f04043e29c4263f29	2026-08-11 14:02:34.570618+05:30	2026-09-10 14:02:34.57037+05:30	\N	\N	node
219	18	6b03dba3c9a5e785e9f1d0ec307796dc75cdb975f1d53849105518d56e82f389	2026-08-11 14:02:45.681859+05:30	2026-09-10 14:02:45.681666+05:30	\N	\N	node
223	18	646bd45535a27ac4624376a0a786fc6c1895933834ab021e3734172cc5065118	2026-08-11 14:02:49.082536+05:30	2026-09-10 14:02:49.082333+05:30	\N	\N	node
228	19	9569137323af68e42ae5b382e203ca9d2332dd52531aeb4bccd325dc8138f8ca	2026-08-11 14:02:51.666738+05:30	2026-09-10 14:02:51.666426+05:30	\N	\N	node
211	3	e0cf33a2a8d9f13edc603666456814d3cbb56f11cb7884b18a1b93e990e67e5d	2026-08-11 14:02:35.115271+05:30	2026-09-10 14:02:35.115069+05:30	\N	\N	node
227	18	907ef90686059f687121d2ac6c43e875d352a332fc764d0021b7ce79ed72d56e	2026-08-11 14:02:51.192635+05:30	2026-09-10 14:02:51.192457+05:30	\N	\N	node
216	1	32fbd7e03af96b3e6f95bbc097161373805e626c5fa25158927619da89fd8fa3	2026-08-11 14:02:40.420753+05:30	2026-09-10 14:02:40.420502+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
212	3	b6cc504f6182a0458b815fc9a0fde443d996865960db27289c8285a3a0e81e05	2026-08-11 14:02:35.535494+05:30	2026-09-10 14:02:35.535261+05:30	\N	\N	node
215	17	1f487bae077f891d5f2fea304824f0ed6a4c7c57587aeffbcb0746ec1274fd99	2026-08-11 14:02:37.412062+05:30	2026-09-10 14:02:37.41171+05:30	\N	\N	node
220	18	45521a8121a1d7473817937fca8ced403d0cd2ac9c4c7792e25481cf9af6d3e9	2026-08-11 14:02:47.013282+05:30	2026-09-10 14:02:47.013062+05:30	\N	\N	node
225	17	b3091a91a753e814e0f43825c3906d6b2ba38dcf0c111e5ae8442b73faa268fe	2026-08-11 14:02:50.232844+05:30	2026-09-10 14:02:50.232581+05:30	\N	\N	node
230	17	0231ee4a8b2a077b6223f70d7a1a2e5b040786e10ec6c324c28ab1752514685d	2026-08-11 14:02:52.640993+05:30	2026-09-10 14:02:52.640761+05:30	\N	\N	node
217	19	37c41d0725977d7d94f91f3a129139cbb9a4268d5b15eb9fd482df7c12771710	2026-08-11 14:02:44.306795+05:30	2026-09-10 14:02:44.306591+05:30	\N	\N	node
231	17	868fe9d13024c31ffed4d68600ca06e6a2e87c92bf42ea0e7f285f7f7489252b	2026-08-11 14:02:53.056021+05:30	2026-09-10 14:02:53.055777+05:30	\N	\N	node
218	20	2c60e6f6b268c80d424627df53a7f6b31b9f66cab0db50f6c305d6068b31f29f	2026-08-11 14:02:45.087295+05:30	2026-09-10 14:02:45.087108+05:30	\N	\N	node
234	20	112cfa7a566255d5fb26025bda37702ba80296cb0d84553f00ae3a5eeb458d5d	2026-08-11 14:03:02.553+05:30	2026-09-10 14:03:02.552836+05:30	\N	\N	node
235	17	928576a36a82ed6cfcf378a10245d8ace057ed48562952d067d91b318593a19f	2026-08-11 14:03:04.316716+05:30	2026-09-10 14:03:04.31652+05:30	\N	\N	node
236	19	23f2116d52cc3242a51406ad5b723e29c5ae574aa1b1c7a88fbe3a5affeedfe8	2026-08-11 14:03:04.752089+05:30	2026-09-10 14:03:04.751936+05:30	\N	\N	node
237	20	dfe59c7658e8b8aade5abdd3640e8d7b0e66004d8b8304b9e461b19063544a28	2026-08-11 14:03:05.121733+05:30	2026-09-10 14:03:05.121533+05:30	\N	\N	node
238	17	bf541a1bd1af8dc51cb4aff3efefd4fa213c9502b5a7f1a889ed2e2844123aab	2026-08-11 14:03:05.511246+05:30	2026-09-10 14:03:05.510223+05:30	\N	\N	node
239	18	71075bb336c1eb07b2304d45318986104394bd17f3b7d3bba3dd02599365b950	2026-08-11 14:03:05.996158+05:30	2026-09-10 14:03:05.996005+05:30	\N	\N	node
240	19	71f1e963f02e43b965413c4da62ec19856a164c8c372b22feb7567d1a6230c6a	2026-08-11 14:03:06.71507+05:30	2026-09-10 14:03:06.714867+05:30	\N	\N	node
241	20	502315530dcb4c14fd10c33cdbd3c01c0696cadffd410fc972d0b654dcff9607	2026-08-11 14:03:07.207505+05:30	2026-09-10 14:03:07.207257+05:30	\N	\N	node
242	19	f6d4c32e8f14eede43f686c0cd36e3de8c397b4dcb425acbb36f04edcd859ca9	2026-08-11 14:03:07.640205+05:30	2026-09-10 14:03:07.640054+05:30	\N	\N	node
243	5	94bc4b148eaedbde5fc8e5706f18d7326e3e302c6da1b45c53cf80f4fda260c7	2026-08-11 14:03:10.375374+05:30	2026-09-10 14:03:10.375216+05:30	\N	\N	node
244	3	a42c70d2f6151410790a759d8396c86f35fb67bf80fc496bc2c57a039a5c8618	2026-08-11 14:03:10.847655+05:30	2026-09-10 14:03:10.847433+05:30	\N	\N	node
245	3	b798a567d7f9f1942151d15ab205d0b39fd59b6959838691cbafddb642f905ab	2026-08-11 14:03:11.197318+05:30	2026-09-10 14:03:11.197105+05:30	\N	\N	node
246	7	012e351b2e011eec7888d65120f9bcf2157b3ef547d5bbd6ef77473047c9d48d	2026-08-11 14:03:11.921283+05:30	2026-09-10 14:03:11.921079+05:30	\N	\N	node
247	8	45ebcee1e869af7785ec789933d6928fa9eb89938e2ef2d4a58a33080c39f508	2026-08-11 14:03:12.604224+05:30	2026-09-10 14:03:12.604006+05:30	\N	\N	node
248	17	bd5601902966b42e554edc3c3d1407bae6801f42288ffa972d660471d08c51c8	2026-08-11 14:03:13.149497+05:30	2026-09-10 14:03:13.149243+05:30	\N	\N	node
249	178	b5e8e008f0466a10704f029692109a182404c8a16dcb65d95fe9e302e089b1e4	2026-08-11 14:03:14.064745+05:30	2026-09-10 14:03:14.06454+05:30	\N	\N	node
250	17	31ef148f90ecbde9a740d6fea1d80af5186923e232298bc9e445d24bc0a4dad2	2026-08-11 14:03:14.433363+05:30	2026-09-10 14:03:14.433208+05:30	\N	\N	node
251	178	d261891399b5ea8858c27e337b08d9ff5490ad6ec1fb06582f66703b078f125f	2026-08-11 14:03:15.502351+05:30	2026-09-10 14:03:15.502125+05:30	\N	\N	node
252	17	c2c82a243291beb1cbd1326cd4bb28abb202c6bd1adcd9be4684bbccf8a766ad	2026-08-11 14:03:15.89589+05:30	2026-09-10 14:03:15.895588+05:30	\N	\N	node
253	18	a3c20185368c4ad3e4f354f8fc4fd13c5569ca4f1f82f43e8e82917340a3e370	2026-08-11 14:03:16.2362+05:30	2026-09-10 14:03:16.236056+05:30	\N	\N	node
254	17	5344c4566cd36b6ca1041cd3d292c042116a17636256cde9a48f450c754ccda7	2026-08-11 14:03:16.936333+05:30	2026-09-10 14:03:16.936163+05:30	\N	\N	node
255	18	e67e75e5344c9df4925b23b5af137d4de920aac7b3dfed85939d971abeec3626	2026-08-11 14:03:17.320804+05:30	2026-09-10 14:03:17.32062+05:30	\N	\N	node
256	17	8030dfa897908ec7f5978137b97058eac280b4806270331a8cee3f727b8f967a	2026-08-11 14:03:18.291559+05:30	2026-09-10 14:03:18.291229+05:30	\N	\N	node
257	17	4a6a575af629f71bda1c872a7ad8f6db62a591d72a575f63dc53d64b2d3bace4	2026-08-11 14:03:18.633201+05:30	2026-09-10 14:03:18.633046+05:30	\N	\N	node
258	18	1d189daff2224870fa6c8f9157707cb9be7b12fdb7fee4c8da41e9d587f9bb21	2026-08-11 14:03:19.056244+05:30	2026-09-10 14:03:19.056072+05:30	\N	\N	node
259	17	f9b11cbfbe7bbb8080f7f49439eb5846e4a5cf7c37beda66551e2a07375ff399	2026-08-11 14:03:19.455059+05:30	2026-09-10 14:03:19.454892+05:30	\N	\N	node
260	18	4a42c24a2722a8227da3b66757dd3373b3908ee811e62e16f8005eda6910c2cc	2026-08-11 14:03:19.806947+05:30	2026-09-10 14:03:19.80676+05:30	\N	\N	node
261	180	78e34397fafd2f9b32f313f4671345de01ac0fc5b59486fd4cb6cca08f09ffc6	2026-08-11 14:03:20.671746+05:30	2026-09-10 14:03:20.671543+05:30	\N	\N	node
262	18	2d2c53004c297607cc76554e5786672e65674d5026b0f559723441886e625a3c	2026-08-11 14:03:21.028805+05:30	2026-09-10 14:03:21.028519+05:30	\N	\N	node
263	181	33cc86f57e7c61d9d494fcb27506ef2c9c3c9fd594fd23af43b9d292a89b56f2	2026-08-11 14:03:21.931832+05:30	2026-09-10 14:03:21.931553+05:30	\N	\N	node
264	18	9076cd4b678d48183891972513e9b606852a02c49ea8c24105d255f5dcbca326	2026-08-11 14:03:22.285038+05:30	2026-09-10 14:03:22.284864+05:30	\N	\N	node
265	180	e46158fb84b6a73ac15b005e9ee6ba1e05f22a1e24a3af9f1fec5a268cddfc0e	2026-08-11 14:03:23.4586+05:30	2026-09-10 14:03:23.45843+05:30	\N	\N	node
266	18	92a32f55d7dd8c65953bfd739e952cbb0458cb95251e41415464fadfc77c476c	2026-08-11 14:03:23.770997+05:30	2026-09-10 14:03:23.770814+05:30	\N	\N	node
267	17	10053ec42138f29afc8126b198b1a1a45baf21a5441fbef0931e9bdce75fd52c	2026-08-11 14:03:24.149753+05:30	2026-09-10 14:03:24.149581+05:30	\N	\N	node
268	18	7f3bb604bc0f7c7cac67a45d378550c85dd57f38e281b8b550b223b81096b864	2026-08-11 14:03:24.513779+05:30	2026-09-10 14:03:24.513531+05:30	\N	\N	node
270	17	40bc006b97be01736d35f95dbcad8747b6cae68376425c7b7e6778fcf1ed8502	2026-08-11 14:03:25.189471+05:30	2026-09-10 14:03:25.189248+05:30	\N	\N	node
271	18	72d1f6170b7febf265e507cd944eee0594733319452e2ef4eb51c0e8b6e68fa0	2026-08-11 14:03:25.609645+05:30	2026-09-10 14:03:25.609354+05:30	\N	\N	node
272	182	3bf7b447b4218dce75b06464cae4fa07f45b554a866b8f82d805211e36241894	2026-08-11 14:03:26.435675+05:30	2026-09-10 14:03:26.435505+05:30	\N	\N	node
273	18	c581f72fac971659341af8b6fda9c4fdbeb862bc80571b68d7142ddb70b4d2bf	2026-08-11 14:03:26.831912+05:30	2026-09-10 14:03:26.831621+05:30	\N	\N	node
274	18	89f4164ec27b688b3ca5e1567bec52f540cb17fbc52cac7b4979ad7013b341be	2026-08-11 14:03:27.259292+05:30	2026-09-10 14:03:27.259087+05:30	\N	\N	node
275	182	82aa754b0b31eecbf09cbe55fc5153ce9bc17f411e6ab50236f9a90114e628ae	2026-08-11 14:03:27.70222+05:30	2026-09-10 14:03:27.701969+05:30	\N	\N	node
276	18	ff492e22470c59fbfcf6dd12347b6c87206aeb2902f9889c120eb3466a3270ec	2026-08-11 14:03:28.08645+05:30	2026-09-10 14:03:28.086228+05:30	\N	\N	node
277	182	a5b466defbb9ce73310766cf49bae7be9bfa27088c08497faafa77c3aed80a4a	2026-08-11 14:03:28.464312+05:30	2026-09-10 14:03:28.464145+05:30	\N	\N	node
278	18	3a60006c8cd8cf1741fe418e8a1616f09e9525447ad8ad1d9bd1bb0086d1ade4	2026-08-11 14:03:28.792268+05:30	2026-09-10 14:03:28.792118+05:30	\N	\N	node
279	18	864740ec483bd699c9894b8f86a05aa7f28ec52654601f6cd497975effbddc96	2026-08-11 14:03:29.399276+05:30	2026-09-10 14:03:29.399114+05:30	\N	\N	node
280	17	75b949f4d9b3de6df6179098b764094f180bbc3f44df0a62649bdab8ffbd2ca5	2026-08-11 14:03:29.722188+05:30	2026-09-10 14:03:29.721981+05:30	\N	\N	node
281	17	caafa1e8ca4103a5d783fc9d3892e1f8fd9b3b58946852f480f5f566b696ec93	2026-08-11 14:03:30.055574+05:30	2026-09-10 14:03:30.055436+05:30	\N	\N	node
282	183	3749149c70d7e415d99eb484680c8729c40a6e0008b638345f724f26fcb2d8c0	2026-08-11 14:03:31.106738+05:30	2026-09-10 14:03:31.106535+05:30	\N	\N	node
283	17	912c4ba0ecc6b727dc7232eea79d003158a4c25f2d4aac24f544814ef4d0dc31	2026-08-11 14:03:31.477777+05:30	2026-09-10 14:03:31.477117+05:30	\N	\N	node
284	17	c87f528c5f3b7ef4fd35c0cd1acea451df8dc96be4d8d2d73ff73514d99059a8	2026-08-11 14:03:31.978869+05:30	2026-09-10 14:03:31.978593+05:30	\N	\N	node
285	183	6d9c9957f35b7043c2e6f6e3c652ba800d2bbd6c81aefcd27b4ab804bf285698	2026-08-11 14:03:32.438302+05:30	2026-09-10 14:03:32.438015+05:30	\N	\N	node
286	17	fe1a47399327ec5e370b9502aebb3dc187a0064276d099ddb4c9451586ad8012	2026-08-11 14:03:32.770025+05:30	2026-09-10 14:03:32.769814+05:30	\N	\N	node
287	17	09ad55ac62381124620cd78f79358637b454e59b64c2d31d08fcd177fff371a3	2026-08-11 14:03:33.202573+05:30	2026-09-10 14:03:33.202325+05:30	\N	\N	node
288	17	f3be27deedabbce4c5d3b19726d0eddeeae38fbe283d4e6df85fa335a1a4a2ae	2026-08-11 14:03:33.755491+05:30	2026-09-10 14:03:33.7553+05:30	\N	\N	node
289	18	8b041111c3635d126c7fcb28af1843d013be21286c5c2d2d1d8a8ec7be290606	2026-08-11 14:03:34.147989+05:30	2026-09-10 14:03:34.147801+05:30	\N	\N	node
290	18	874ac0c2b022bcf21abcb59ea7f11afa3f21286c32cb314853e1d52206863f1d	2026-08-11 14:03:35.252191+05:30	2026-09-10 14:03:35.252031+05:30	\N	\N	node
634	1	ae6ba9ccbaf486358dd8271ff81d3fd777cc80b4ecd34e14dbad99b3c3b47077	2026-08-11 14:18:06.021788+05:30	2026-09-10 14:18:06.021233+05:30	\N	2026-08-11 14:18:06.551415+05:30	node
291	17	ba67eeff191558d49e6c485e9cb13627152aee5a4c801ab09c26665c04dfd343	2026-08-11 14:03:35.604497+05:30	2026-09-10 14:03:35.604301+05:30	\N	\N	node
307	18	8249518f59da3bec152b3e3234ef75fa1ecb49fdeee3f85a953729f9bbb88bfb	2026-08-11 14:03:51.275648+05:30	2026-09-10 14:03:51.275405+05:30	\N	\N	node
292	18	31fae5c04d4e876925d06130670ff19facd168d6e01c88f512ffe6e36ae279ba	2026-08-11 14:03:36.04239+05:30	2026-09-10 14:03:36.04216+05:30	\N	\N	node
294	1	f45bde8127f37c3f230afc948b7a9b32c5c2e4469805d7f34f6b925fbe4fca6d	2026-08-11 14:03:39.467913+05:30	2026-09-10 14:03:39.467732+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
293	17	20c5f9b91fa2c3c0dab2fc90aa8d472fdd986301aa3b2d2874621e464954c2b2	2026-08-11 14:03:36.949208+05:30	2026-09-10 14:03:36.948884+05:30	\N	\N	node
300	18	c18dea894964e86a0aa9ce15e20dd3bbf1f34ecd32a22bf35222db887f179879	2026-08-11 14:03:47.857073+05:30	2026-09-10 14:03:47.856891+05:30	\N	\N	node
304	18	62def603e1e3ac4b03f3d146108be18b6c6951fbdaf256183a6ad20aff1e0b42	2026-08-11 14:03:50.019151+05:30	2026-09-10 14:03:50.018945+05:30	\N	\N	node
310	18	953cea27d24b51b3da1436924bd9b9a90654e0a6f61f684e7490efd4766f53fe	2026-08-11 14:03:56.143324+05:30	2026-09-10 14:03:56.143138+05:30	\N	\N	node
295	19	4b205d97138007c6ce7a7314bc64393c9e7f45051e7835b05288ac2a72f3a39c	2026-08-11 14:03:44.081212+05:30	2026-09-10 14:03:44.081039+05:30	\N	\N	node
298	18	35037cc102bc7921df51d0b8f245484918151ab44456d4b8bb3261711e1e31a0	2026-08-11 14:03:46.558497+05:30	2026-09-10 14:03:46.55832+05:30	\N	\N	node
296	20	51119b5188968d86014b9a6d525b75bd3b9e50f010c8dfe6fd4ad0570b67e897	2026-08-11 14:03:44.866209+05:30	2026-09-10 14:03:44.866056+05:30	\N	\N	node
301	18	1aa446060e959e4bfb2316b081a31a76fb6720a7b1c6b41b54c54f467de46c92	2026-08-11 14:03:48.498696+05:30	2026-09-10 14:03:48.498527+05:30	\N	\N	node
297	18	30ba5af13cb03763d24997302630e48be4d0815b3b36e033b6a43cffb7cbac29	2026-08-11 14:03:45.406535+05:30	2026-09-10 14:03:45.406333+05:30	\N	\N	node
306	19	e9e7febffbca85977687e83a82faa2e4afc690bced252bee1dccbdd8a766c0d0	2026-08-11 14:03:50.896138+05:30	2026-09-10 14:03:50.895414+05:30	\N	\N	node
311	19	123057da0699c2d012598802b3e077bcb4cca21ec7c1fa9a4fa4d23a3d54bb19	2026-08-11 14:03:59.911716+05:30	2026-09-10 14:03:59.911025+05:30	\N	\N	node
312	20	281a6df9db3bbff9a390c5b4373cd873ee3dfaabad427582b3e815e5f45e1dcd	2026-08-11 14:04:01.625109+05:30	2026-09-10 14:04:01.624954+05:30	\N	\N	node
299	17	c8677fad277d7950aa22d5edfef9fac2db4479d25f2828d83f00cb797be86071	2026-08-11 14:03:47.20397+05:30	2026-09-10 14:03:47.203801+05:30	\N	\N	node
302	18	12dba48c7be23343d8c928d371ccc3b007de06abecd175958ab3fbcd298b8150	2026-08-11 14:03:49.126835+05:30	2026-09-10 14:03:49.126635+05:30	\N	\N	node
303	17	2d828068d6a8caeb2aebc00cd7c8355c8fe5cfe10b30e668296c15b0a5640f7e	2026-08-11 14:03:49.616476+05:30	2026-09-10 14:03:49.616187+05:30	\N	\N	node
308	17	bbc0f9fc99039dde0e404664a33a92dd93c3096662964d7dbabeb1eac16e8db6	2026-08-11 14:03:51.985187+05:30	2026-09-10 14:03:51.98477+05:30	\N	\N	node
305	18	d2e46f761ce9d111b499c1dd65944699683ff13166a0db0ec8e15ceb24e0aa70	2026-08-11 14:03:50.437718+05:30	2026-09-10 14:03:50.437557+05:30	\N	\N	node
309	17	35d32e38889f4800b63f2d0e9b2c075b5a5a72906963e5164882534bc335f127	2026-08-11 14:03:52.340139+05:30	2026-09-10 14:03:52.33996+05:30	\N	\N	node
313	17	85d1cd5e771e7ce881fc9879c61edd6de0b06e9d86d3c774613f63e1bf9f8ddf	2026-08-11 14:04:03.331273+05:30	2026-09-10 14:04:03.331008+05:30	\N	\N	node
314	19	f94a7b30473d6beb57fdc0b290d80b2c389b209da9798bd421576029e5fd2f1b	2026-08-11 14:04:03.709492+05:30	2026-09-10 14:04:03.709275+05:30	\N	\N	node
315	20	1092e03191b4e51ccada42d8fcb04731a5a0c97c3b1b7df6bd715fcd9253762c	2026-08-11 14:04:04.076274+05:30	2026-09-10 14:04:04.076124+05:30	\N	\N	node
316	17	d59518d6766b2c1ee177d5d26bcf85ae542039462d2f2efc9a05bb9fe3f04d78	2026-08-11 14:04:04.438565+05:30	2026-09-10 14:04:04.438366+05:30	\N	\N	node
317	18	5b888a7fa17e7ddea8b2eadf6cba1c53fe7f4dbfa95a9ca741a8a7ec31439c34	2026-08-11 14:04:04.886594+05:30	2026-09-10 14:04:04.886414+05:30	\N	\N	node
318	19	4fc025d3f67bf6ddb42f9a70de20d729f29b5206116d20a98e599f8c94d92749	2026-08-11 14:04:05.572638+05:30	2026-09-10 14:04:05.572426+05:30	\N	\N	node
319	20	dd0f99dda819b778cac2e67b7d3ae5105c3121506597abdd8bcaae327a5458f4	2026-08-11 14:04:06.034371+05:30	2026-09-10 14:04:06.034182+05:30	\N	\N	node
320	19	4c0d6560bd2755f6412f9d118cd91ba92f0d70cc9b58a375507b1eef7578d599	2026-08-11 14:04:06.485138+05:30	2026-09-10 14:04:06.484928+05:30	\N	\N	node
321	5	9231a00339537a39793903cfb2b2c204d2b48bd9691ec52119f10f1649f87186	2026-08-11 14:04:16.554512+05:30	2026-09-10 14:04:16.554306+05:30	\N	\N	node
322	3	9a12bcd4f335fbfee4bdf49ca103616f48237b3da21e3243ad5bf24a00362fd9	2026-08-11 14:04:17.026878+05:30	2026-09-10 14:04:17.026643+05:30	\N	\N	node
323	3	5c188592b5306c631438c07798483ac228216a52ec02259971e5ab3c85d8cfb1	2026-08-11 14:04:17.363636+05:30	2026-09-10 14:04:17.363444+05:30	\N	\N	node
324	7	3bead05de43831193f422c5a7a9f215bbef0eb25c09b976e5fb8afe1d51b2125	2026-08-11 14:04:17.751885+05:30	2026-09-10 14:04:17.751689+05:30	\N	\N	node
325	8	66a704c7532edfb03c7fe820233717a35cc40f9d0dfca3b9e7ea7c35e4d02386	2026-08-11 14:04:18.438701+05:30	2026-09-10 14:04:18.438477+05:30	\N	\N	node
326	17	6d916475fd212f61aaa76084190ca7e39d6e582c09e73216dab2c7796aba96b5	2026-08-11 14:04:18.876372+05:30	2026-09-10 14:04:18.876084+05:30	\N	\N	node
327	184	e1534a2fb8e68132b5c79dd09b2de2d01598be02d66bc99c4ed8c1cd0da505dd	2026-08-11 14:04:19.653882+05:30	2026-09-10 14:04:19.653666+05:30	\N	\N	node
328	17	d5b8ad93fe94514647cf2b5d0579d5e3e23d7e7aab08e6e229c773abdfc0d669	2026-08-11 14:04:20.029761+05:30	2026-09-10 14:04:20.02956+05:30	\N	\N	node
329	184	7a95f2ab173eb4ae8af5adf45338639b72342e3919ee27016573734aeeae949a	2026-08-11 14:04:21.1695+05:30	2026-09-10 14:04:21.169345+05:30	\N	\N	node
330	17	9d66ab9a445577a691a39fbe448ba0ba5333d24cb6dae2c9febcd7b58395b15a	2026-08-11 14:04:21.484901+05:30	2026-09-10 14:04:21.484701+05:30	\N	\N	node
331	18	b950c7e506470920b87097e15cab83db6d443cd49a8455435e5d65bb39ed1b46	2026-08-11 14:04:22.039386+05:30	2026-09-10 14:04:22.039147+05:30	\N	\N	node
332	17	4bfddd30bd4ada05f2d2db569dc466335b83ddc770d73f7d7e5f666f05a2bc12	2026-08-11 14:04:22.797225+05:30	2026-09-10 14:04:22.796956+05:30	\N	\N	node
333	18	e9d2efa1e3738996ddb01928b35a21019c5fc0923864f40b82911015c201621a	2026-08-11 14:04:23.150677+05:30	2026-09-10 14:04:23.150458+05:30	\N	\N	node
334	17	ddc300b479496e416407473806b97cc80b9a146cb4cb2715b18697002a020e6e	2026-08-11 14:04:24.443217+05:30	2026-09-10 14:04:24.442998+05:30	\N	\N	node
335	17	4d7168e72d26c18ae5b712da6a0eca1e9c5f32d4d0ef5e974288cd3aa1b1aaae	2026-08-11 14:04:24.765211+05:30	2026-09-10 14:04:24.765042+05:30	\N	\N	node
336	5	837ccb98a7ef6b695f34ee79b6eafc691c9406d67916682570af58ae1d3e0548	2026-08-11 14:04:35.540879+05:30	2026-09-10 14:04:35.540688+05:30	\N	\N	node
337	3	8f42f6cda388d1a9cfe9e40fce1bfb27192a7307711c15d0a7c91251f80422c8	2026-08-11 14:04:36.059748+05:30	2026-09-10 14:04:36.059553+05:30	\N	\N	node
338	3	8cc07937fd5fabeab57d945806cc76d304e0729e43263279c261971dc2ef45bb	2026-08-11 14:04:36.393278+05:30	2026-09-10 14:04:36.393038+05:30	\N	\N	node
339	7	aa35576428fab99ff1150554cd19fdf8cba25a7004a9436c8fcce8d0a173243f	2026-08-11 14:04:37.033892+05:30	2026-09-10 14:04:37.033683+05:30	\N	\N	node
340	8	eb57abdb45260697158fd033b880bb7fdd541575a6f91d009b37dc4725df01be	2026-08-11 14:04:37.684636+05:30	2026-09-10 14:04:37.684443+05:30	\N	\N	node
341	17	ab339f43eaf8efaf9c7cff1fa344cf1d4fff488c88b90901f2e9565fe7c2f249	2026-08-11 14:04:38.13398+05:30	2026-09-10 14:04:38.133664+05:30	\N	\N	node
342	186	7ae64daafd959c886a5bd666c75bc34263078feeff3a969cf398c0ae73651ef6	2026-08-11 14:04:38.932963+05:30	2026-09-10 14:04:38.932801+05:30	\N	\N	node
343	17	890de4afed5630900246c67da66dc0399aa7fdb6381fea16f56fb0ab6b46dca3	2026-08-11 14:04:39.261507+05:30	2026-09-10 14:04:39.260966+05:30	\N	\N	node
344	186	1ccc0c0ad1981101b92b922c3bc420a0067951de0e056b18764cb8d63402f28d	2026-08-11 14:04:40.496875+05:30	2026-09-10 14:04:40.496368+05:30	\N	\N	node
345	17	65cf8dcb5da439d65cb0114b0ff05a6ee3181b99d0d51da1c713148aa67d870d	2026-08-11 14:04:40.992344+05:30	2026-09-10 14:04:40.992181+05:30	\N	\N	node
346	18	76c1c8596684354e2d40923c6d5e87a2d44ca9608cb368bc09978991a490ad17	2026-08-11 14:04:41.316685+05:30	2026-09-10 14:04:41.316482+05:30	\N	\N	node
347	17	7d501e366896337e52c249000b29cd6c76c3f284e46fc867d53bcf16c7f8611c	2026-08-11 14:04:41.964265+05:30	2026-09-10 14:04:41.963977+05:30	\N	\N	node
348	18	4e55e4df06f635d7e50b4f094c39ec252a173bf0b1898c167ae84051fdc36cca	2026-08-11 14:04:42.337965+05:30	2026-09-10 14:04:42.337812+05:30	\N	\N	node
349	17	1a9d4a3c3ea90e1045859a855d7df31d9aa2ad059407c0e8c6340d6f98fde77e	2026-08-11 14:04:43.613504+05:30	2026-09-10 14:04:43.613139+05:30	\N	\N	node
350	17	63021fc2d1522bd27cc652a93d709d23b6014d333054771ed041b4dcb1db33ae	2026-08-11 14:04:43.955736+05:30	2026-09-10 14:04:43.955595+05:30	\N	\N	node
351	18	453310b5bba36e4c409a2f0ed8e4cdd454f3a2f58049d61df2d8d1b91e20feee	2026-08-11 14:04:44.538653+05:30	2026-09-10 14:04:44.538409+05:30	\N	\N	node
352	17	91f730cad849e5362f0d0e8ca77fa99f57a8eb3cf46a67eb803312b68ff8800a	2026-08-11 14:04:44.907476+05:30	2026-09-10 14:04:44.907328+05:30	\N	\N	node
353	18	cab9f925f12039ddff068d1bcb1d0435a106cf59370935c1833637353054a90c	2026-08-11 14:04:45.268685+05:30	2026-09-10 14:04:45.2685+05:30	\N	\N	node
354	188	dd16e1b96e6716efb878c66ad781ce096151c12dde6ab49267b6b2a077f7b9a1	2026-08-11 14:04:46.133405+05:30	2026-09-10 14:04:46.133182+05:30	\N	\N	node
355	18	4df83a8e32d755514b4fa4d872836fdf1038f873d5af62e47d5cb70339ce81b1	2026-08-11 14:04:46.467051+05:30	2026-09-10 14:04:46.466836+05:30	\N	\N	node
356	189	4cb26b7144a1d50f75817a6d77fb8d0c1986b8a83bfd073d44df04da526fe059	2026-08-11 14:04:47.496799+05:30	2026-09-10 14:04:47.496543+05:30	\N	\N	node
357	18	d68c70fd99ddb2f93332647087d8af62430bec0d269c3c2719b0f352d326141c	2026-08-11 14:04:47.850006+05:30	2026-09-10 14:04:47.849622+05:30	\N	\N	node
358	188	6f249b3293fce7f225b84cef8d63ac1f311017eaae1c9347fd08c1d106183b61	2026-08-11 14:04:49.089546+05:30	2026-09-10 14:04:49.089258+05:30	\N	\N	node
359	18	f56800338d015dba553c501c630596980d859841ebd1b263d9246162cf13d650	2026-08-11 14:04:49.460301+05:30	2026-09-10 14:04:49.460116+05:30	\N	\N	node
360	17	82340f969ffd34b0cee0307ce4b79e401eb9f9157e0eed9c9003f0b4c54ad84d	2026-08-11 14:04:49.938118+05:30	2026-09-10 14:04:49.937817+05:30	\N	\N	node
361	18	bf5b76ea1e6eaf98bd0bdf6edc01bdaeba2c073768a2d15338de9582f2110aa1	2026-08-11 14:04:50.368027+05:30	2026-09-10 14:04:50.367677+05:30	\N	\N	node
363	17	630f0e8f335197b26ed1b95657e4c60de7fe9e9fd36719a33b3485ae57324ecf	2026-08-11 14:04:51.031329+05:30	2026-09-10 14:04:51.03106+05:30	\N	\N	node
364	18	df64f95d4967af8a823498a75a3caa1b707d4f00e72c5b2f029200d585f079eb	2026-08-11 14:04:51.374146+05:30	2026-09-10 14:04:51.373938+05:30	\N	\N	node
365	190	0d7b072149d281f277bf550ea88269b26d971918860a01bdd939aeffa8e5d47b	2026-08-11 14:04:52.451114+05:30	2026-09-10 14:04:52.450943+05:30	\N	\N	node
366	18	8f80e60ae7436e81c7a6c554c0777ac4937f84fd3483966bd57d9d14bcb85f15	2026-08-11 14:04:52.826854+05:30	2026-09-10 14:04:52.826691+05:30	\N	\N	node
367	18	e155aacaf95e48289332b1a6d0a70f42aeb9da64bf4784e15e093aa9509d80e0	2026-08-11 14:04:53.235796+05:30	2026-09-10 14:04:53.235636+05:30	\N	\N	node
368	190	d97724e32dbb0942ce140fa736eaf83657205907b977d4a41db2ea9667ffa664	2026-08-11 14:04:53.67491+05:30	2026-09-10 14:04:53.674746+05:30	\N	\N	node
635	1	f0d2aa30d702f9092215fbf81a27586058556bbe824d61c7350e23e8763d8de0	2026-08-11 14:18:06.512005+05:30	2026-09-10 14:18:06.511737+05:30	\N	2026-08-11 14:18:06.551415+05:30	node
369	18	db3bc29da7da8ea2f3760d96c6036ebbff03d17bcabae3ce35d5967f4a69b00c	2026-08-11 14:04:53.994532+05:30	2026-09-10 14:04:53.994282+05:30	\N	\N	node
376	17	b74649736e5ffa7d3129ebd34d8fd55d8a81f7be4838c8f4b616274e9a83c571	2026-08-11 14:04:57.387239+05:30	2026-09-10 14:04:57.387067+05:30	\N	\N	node
380	17	cd7719a388414966bde33c79476055eb9fd007b1ebbbd0c28efff01edb9c80f6	2026-08-11 14:04:58.900224+05:30	2026-09-10 14:04:58.89986+05:30	\N	\N	node
384	17	d7a11717b79fa8542025ab143979e61bfdafedf44ce7fb974facb971f5d8a9a1	2026-08-11 14:05:01.12615+05:30	2026-09-10 14:05:01.125921+05:30	\N	\N	node
386	17	2c338f2445d28c8194f9d7a88132e002e4069f0bae536a6d33fb9be831d2818e	2026-08-11 14:05:02.26067+05:30	2026-09-10 14:05:02.260468+05:30	\N	\N	node
409	194	32f3bfde19f633f4dd2926d1c39b61f71bdcec1d5220409e7e84acce1ef81df9	2026-08-11 14:05:18.396808+05:30	2026-09-10 14:05:18.394827+05:30	\N	\N	node
415	18	fa104396df088babc284d2aa47c711e5e2ff9a27e8b374bc1032f6193ad1367a	2026-08-11 14:05:20.682249+05:30	2026-09-10 14:05:20.681903+05:30	\N	\N	node
417	18	deea82ee3a2ea66159117ab899cd0a3cd8203c03654a32e6daf2bcffabecb324	2026-08-11 14:05:21.856087+05:30	2026-09-10 14:05:21.855805+05:30	\N	\N	node
446	198	bee4a0399dfcb45f401c938a495c1b4dc99f1058cc1e960fb974e28d7ccfc351	2026-08-11 14:05:51.496848+05:30	2026-09-10 14:05:51.495973+05:30	\N	\N	node
451	17	b14284383ce473fcd8213c88399b332297703b3bde2c1c1c9ad7f8348e660f44	2026-08-11 14:05:54.091078+05:30	2026-09-10 14:05:54.090893+05:30	\N	\N	node
464	1	5963a3235be561cada157b568ce91fa75b31e45785007a7d306a729ae2c880a1	2026-08-11 14:06:00.855932+05:30	2026-09-10 14:06:00.855743+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
370	190	698d9d2ff5e2f09600a3d6849b889086b7e4aee3d70550681a427250f71d2d61	2026-08-11 14:04:54.41043+05:30	2026-09-10 14:04:54.410248+05:30	\N	\N	node
374	17	7fee9b1afc142df2401bbd777c1a24a871e8e621fa0c13d1c39bc76928bd4414	2026-08-11 14:04:55.998234+05:30	2026-09-10 14:04:55.997982+05:30	\N	\N	node
375	191	51b91a4b7b61d85213fe6abf3ca51f0fcea1b5364ac5a6165f12afac87786671	2026-08-11 14:04:57.070411+05:30	2026-09-10 14:04:57.070188+05:30	\N	\N	node
378	191	634e3bd13a3ac651855a6e041ad40f9da98df1ca0f9b435606eda900a4ff39ac	2026-08-11 14:04:58.136669+05:30	2026-09-10 14:04:58.136388+05:30	\N	\N	node
397	18	f9db9c917fa51fde1245e9bb621fb99ffec3363c49c90df67709e65064645987	2026-08-11 14:05:10.454869+05:30	2026-09-10 14:05:10.454642+05:30	\N	\N	node
399	18	f43052029f1b36648dfb8fda4717674b73420e3c1e081fdee46a45b53d18bc00	2026-08-11 14:05:11.723081+05:30	2026-09-10 14:05:11.722831+05:30	\N	\N	node
403	17	9fe8f164486011464e63bc6d13b3980526489ee764c54514d5de99a8e41833bd	2026-08-11 14:05:14.401942+05:30	2026-09-10 14:05:14.401794+05:30	\N	\N	node
416	196	544cdb3ba042e2a80915ceec4c42ce1cc2e4cfa727bb95e715df6110cabc33d3	2026-08-11 14:05:21.457388+05:30	2026-09-10 14:05:21.457159+05:30	\N	\N	node
418	18	fdea39e9fe3d9d8f3718f28db7be07032211cfa45f2c8cc32b0627708094c79d	2026-08-11 14:05:22.240418+05:30	2026-09-10 14:05:22.240217+05:30	\N	\N	node
419	196	e316d816e4d63da5158524d32ae42307a0757bf62241eabfde1c8064129aa455	2026-08-11 14:05:22.70893+05:30	2026-09-10 14:05:22.708637+05:30	\N	\N	node
422	18	efbaeb5e870c8e37b999c783c42af1b81e1bb2d575fb46c9b07ee5569e5ea314	2026-08-11 14:05:23.891731+05:30	2026-09-10 14:05:23.891549+05:30	\N	\N	node
443	17	aab470fe95bebcda1c93f8628c3c2fb008564db3bb6162711f2e0d46f19ff98d	2026-08-11 14:05:49.242715+05:30	2026-09-10 14:05:49.242354+05:30	\N	\N	node
450	18	fc65058be9d98dc7923b9a690fa1ed849da8965322b76bc1dcf1559508d5e843	2026-08-11 14:05:53.109577+05:30	2026-09-10 14:05:53.109429+05:30	\N	\N	node
452	17	0b68aa1be8d24646ee2760c78615b3aa0c518939085b7e4f7b77c66b2cb49226	2026-08-11 14:05:54.42375+05:30	2026-09-10 14:05:54.423532+05:30	\N	\N	node
371	18	cb4544ba953ee262115ff06c42e8621bc7df0c9a006a45fded5c3cf82087a352	2026-08-11 14:04:54.742548+05:30	2026-09-10 14:04:54.74232+05:30	\N	\N	node
372	18	5b804595bec4a153f27150db5dd92eea281682a578962ba556b0e31e35f542e7	2026-08-11 14:04:55.24133+05:30	2026-09-10 14:04:55.241131+05:30	\N	\N	node
402	18	a5b40f68e1ebbbd5c56b0161efb4913517fb40f9486e8a222cd39fcd3421c087	2026-08-11 14:05:14.03161+05:30	2026-09-10 14:05:14.03138+05:30	\N	\N	node
436	18	825c76a112aa7a36b79aaf40a1467778c10503f0b2fa3ca2566d0e833e87c0d2	2026-08-11 14:05:30.97341+05:30	2026-09-10 14:05:30.973055+05:30	\N	\N	node
438	5	e2d914b68d09d0005e25977e23c0fc0d1d5cc15b2f2d5dfd7e563094d12f11f0	2026-08-11 14:05:46.705915+05:30	2026-09-10 14:05:46.705687+05:30	\N	\N	node
441	7	e25db8c851887db78f72140f187dadf7d7241a9c4cfc1636a9bb901acca08c23	2026-08-11 14:05:48.202881+05:30	2026-09-10 14:05:48.202735+05:30	\N	\N	node
442	8	f264d8856a4e90246214fddfc5be4415d7a1f9376494f45940465abf8af87cd6	2026-08-11 14:05:48.750636+05:30	2026-09-10 14:05:48.750462+05:30	\N	\N	node
459	18	79d3256bc6ae5ea486241d25571e04379cf0e80bb52b78c8d943c6ee19467f5e	2026-08-11 14:05:58.13573+05:30	2026-09-10 14:05:58.135569+05:30	\N	\N	node
373	17	861736db0f7128bd3c439d554a0f2c7a713586f33fdc65d41ef813ca0241d803	2026-08-11 14:04:55.584503+05:30	2026-09-10 14:04:55.584275+05:30	\N	\N	node
383	18	f01b6ec5b3414da2dcf1ce4d51fb17dee7f0d7d967d7721a9f05e30ecd68c766	2026-08-11 14:05:00.722267+05:30	2026-09-10 14:05:00.722115+05:30	\N	\N	node
389	3	adc0fb3ef095610b264ad6f257ba5582fdb2ab80a5022622194858fc96817749	2026-08-11 14:05:05.853424+05:30	2026-09-10 14:05:05.853228+05:30	\N	\N	node
392	17	d73e0fe32484bef0b28f6f88ef2561d777dacbc9315ef53dbfe6c901031510a9	2026-08-11 14:05:07.407756+05:30	2026-09-10 14:05:07.407548+05:30	\N	\N	node
395	192	f6cf69231a95de9e317310d11fea696c67d3d2378a456e94330618d006421254	2026-08-11 14:05:09.755182+05:30	2026-09-10 14:05:09.754967+05:30	\N	\N	node
401	17	8c3c92c3a111e30785c3766928206e691e68acd2bfcfd04d3a80f19f00f88e12	2026-08-11 14:05:13.600659+05:30	2026-09-10 14:05:13.60049+05:30	\N	\N	node
405	194	e645725ac4434710e36fa571d2f290c1956b397fcfc53eed206dd7169b646bbb	2026-08-11 14:05:15.665439+05:30	2026-09-10 14:05:15.66516+05:30	\N	\N	node
407	195	1ef82e823b95198010b51f9d47205fa0bbc916b890b3ec32e23f524c2eafd0b2	2026-08-11 14:05:16.899498+05:30	2026-09-10 14:05:16.89926+05:30	\N	\N	node
432	17	1682640ba7dbf61b8e7c0a55e1d311f817987beab66fd9a0a3b9a392b2c241fb	2026-08-11 14:05:28.99093+05:30	2026-09-10 14:05:28.990745+05:30	\N	\N	node
440	3	0a8bfea5c141fe036f3d1ca20ab1cda35f998a65aa535e64905879e0dd642bc7	2026-08-11 14:05:47.799466+05:30	2026-09-10 14:05:47.799211+05:30	\N	\N	node
447	17	c4bf8e5cc6b811f3de1f1d51c1cd4298376d24372a8481ce92d43ce321ec837e	2026-08-11 14:05:51.815136+05:30	2026-09-10 14:05:51.81496+05:30	\N	\N	node
455	18	18585ca2b007cfa869830cba45a8336816e9d768963999dca9907782b2c7ccf1	2026-08-11 14:05:55.643877+05:30	2026-09-10 14:05:55.643709+05:30	\N	\N	node
465	17	c32747ce4195023576990f596f0b913f0fc963cff81b05f70592157564e6cb22	2026-08-11 14:06:01.208701+05:30	2026-09-10 14:06:01.208521+05:30	\N	\N	node
413	1	dd9916650ab0dbaead8cecd469e6ff100a3357911916e5de9bf4169423b9bcba	2026-08-11 14:05:19.904136+05:30	2026-09-10 14:05:19.903987+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
377	17	5fb59fbcb6386b14b8324d44183301b93994f573f38d30c70d228c2f4d70c1e0	2026-08-11 14:04:57.753467+05:30	2026-09-10 14:04:57.753258+05:30	\N	\N	node
385	18	835c91e018a49e7797a4a334c6ab03a572d57360dda88d139fc44a6e468f3dc3	2026-08-11 14:05:01.483381+05:30	2026-09-10 14:05:01.48317+05:30	\N	\N	node
387	5	6686eaa2f54bf8748c3a96256111309d94e13407ebdd1bb601fa6a89e3fc7541	2026-08-11 14:05:04.881192+05:30	2026-09-10 14:05:04.880915+05:30	\N	\N	node
430	17	04996eb8653a27e5b5421da190ddb4238b66494b6f0df9630b76b0b4ece60104	2026-08-11 14:05:28.072089+05:30	2026-09-10 14:05:28.071889+05:30	\N	\N	node
435	17	218ea0352e66fe8e3156d5e6d9da9464bdc231a5bc5a8f9358327312c711ccf5	2026-08-11 14:05:30.607324+05:30	2026-09-10 14:05:30.607162+05:30	\N	\N	node
379	17	de3e6454f7a774921ef81445d3e3378d329cbae17c48228a5efcc50e91f9087d	2026-08-11 14:04:58.488054+05:30	2026-09-10 14:04:58.487885+05:30	\N	\N	node
393	192	d4c050824b0147015949a6b86ee0c45c6fc2491ff2d55f28b7b229d3bd8335e8	2026-08-11 14:05:08.218836+05:30	2026-09-10 14:05:08.218682+05:30	\N	\N	node
420	18	2e91882230fc6d56c68c82a66c637abd6badfbb408381b99628909c25312fa8c	2026-08-11 14:05:23.136958+05:30	2026-09-10 14:05:23.136693+05:30	\N	\N	node
427	17	ab1fa91198f1becaca4ecfb2294dfdde0b3176430ac85b528d094d381696aa08	2026-08-11 14:05:26.508011+05:30	2026-09-10 14:05:26.507845+05:30	\N	\N	node
433	18	9566d6a39f90a4499d7c4d5de63f07be5204079a1aa3bb8a0e30b9b054cbee32	2026-08-11 14:05:29.324405+05:30	2026-09-10 14:05:29.324221+05:30	\N	\N	node
437	17	473b1f9ad19091e2d0ad0510c2423dd0c4b80de6393a7909c74770741040652c	2026-08-11 14:05:31.824946+05:30	2026-09-10 14:05:31.824695+05:30	\N	\N	node
444	198	1b2268ce44a95bd421e786c3a4ba61b6f1e4c8fcd1ef344ee345007eb37c6161	2026-08-11 14:05:49.971255+05:30	2026-09-10 14:05:49.97107+05:30	\N	\N	node
449	17	113275994cb924e9854ae8ddf66728dcc9bf56c0a3263350bbbebc89fe1ae789	2026-08-11 14:05:52.788863+05:30	2026-09-10 14:05:52.788646+05:30	\N	\N	node
463	18	c6db2b85b0903ab3acc34e76a7c0e7f7c9f888809b0e9b8427fcfce0913700c3	2026-08-11 14:06:00.47853+05:30	2026-09-10 14:06:00.478365+05:30	\N	\N	node
467	202	b6d45d2f47893fbaf391193221345b9b0fe05dac159004cb57e7d6a584cb591c	2026-08-11 14:06:02.442174+05:30	2026-09-10 14:06:02.441988+05:30	\N	\N	node
381	17	0205887a4b5ce68203288f0f6105f85c44270bb3e60377532325905cbff4a676	2026-08-11 14:04:59.35925+05:30	2026-09-10 14:04:59.359092+05:30	\N	\N	node
388	3	a1994fb80382673b206e2990f0424c07c707e4a6ae89887051e021937f56731d	2026-08-11 14:05:05.430745+05:30	2026-09-10 14:05:05.43053+05:30	\N	\N	node
394	17	74059ab43ec5592c291ff267a7898bca02ac4d714a162144716990f3e742ac24	2026-08-11 14:05:08.615502+05:30	2026-09-10 14:05:08.615344+05:30	\N	\N	node
414	17	809afe24975ca7d1f0ad2cb25c793a5f6ec8f0c48a3e35d4b01389f7a921ea8d	2026-08-11 14:05:20.273117+05:30	2026-09-10 14:05:20.272911+05:30	\N	\N	node
431	17	b74652665d590e6fdd2f08bb9c850c9f879953bd9e1ad187cfcc9becafdc1b25	2026-08-11 14:05:28.465275+05:30	2026-09-10 14:05:28.465103+05:30	\N	\N	node
454	17	c74b8174db1095f6ab64fb668940e9367e95dc86f1e5d763b39b38340ea43237	2026-08-11 14:05:55.316772+05:30	2026-09-10 14:05:55.316607+05:30	\N	\N	node
460	200	1edd89b8f034ece5b5492195a59facd7a45265d323c7a6d11c5f2df8520f7d4e	2026-08-11 14:05:59.332216+05:30	2026-09-10 14:05:59.332031+05:30	\N	\N	node
466	18	b733163c6ac7cc87266c754347dcf17f1c36a276a0aa8c38ddf96dc53f6c6199	2026-08-11 14:06:01.638324+05:30	2026-09-10 14:06:01.638151+05:30	\N	\N	node
382	18	a69de7ac6cb7ae113ae8de67c12c088dacbcef02743eadd24c52286af3bccb36	2026-08-11 14:04:59.690328+05:30	2026-09-10 14:04:59.690143+05:30	\N	\N	node
410	18	5b42955be642571943dc712875c05e91a7c34f46d1ce68af10f8ea169e1b2125	2026-08-11 14:05:18.745398+05:30	2026-09-10 14:05:18.744935+05:30	\N	\N	node
421	196	370e726d86239a114470680b5e0bc0497783459cc09f161f04be0948aafe1463	2026-08-11 14:05:23.557701+05:30	2026-09-10 14:05:23.557492+05:30	\N	\N	node
425	17	f4b519f22b76b5dd674787e551802f268b611d7c5fff4af565f184495241e32b	2026-08-11 14:05:25.128276+05:30	2026-09-10 14:05:25.128099+05:30	\N	\N	node
445	17	3fafe33798a3ab9d95ded46447355b7c687037d0052c721e5f3e30f66e3dbe15	2026-08-11 14:05:50.376499+05:30	2026-09-10 14:05:50.376214+05:30	\N	\N	node
448	18	fc1940aafeead59a66cdadd86c208aededa24a9e70c1e4e221d8ccdc9d8b2046	2026-08-11 14:05:52.149992+05:30	2026-09-10 14:05:52.149856+05:30	\N	\N	node
457	18	2ca5d767d031029a24f408dde9b7de3ac11b9b304e28c9cfd455c837657fbca3	2026-08-11 14:05:56.852659+05:30	2026-09-10 14:05:56.852518+05:30	\N	\N	node
462	17	f04c94401ee72ee7a5f2d119261c02bcd4ecd2abc14b58588d68fb4b18fca1dc	2026-08-11 14:06:00.111702+05:30	2026-09-10 14:06:00.111529+05:30	\N	\N	node
390	7	8bf6c309d24754fd1d7c696d7618c6731e001062a8924e6d2359390f5ce7b3d7	2026-08-11 14:05:06.290448+05:30	2026-09-10 14:05:06.290231+05:30	\N	\N	node
391	8	f5572e3889169ce2322689a16193b94337953d108cd8d1064cea631995e16d4f	2026-08-11 14:05:06.977979+05:30	2026-09-10 14:05:06.97777+05:30	\N	\N	node
404	18	c7bbfc296ecc25d536761680de04517d83fbce3d0e1d30e082b46fd9f971c6c4	2026-08-11 14:05:14.772022+05:30	2026-09-10 14:05:14.771813+05:30	\N	\N	node
408	18	5b3d3ba1352b3e29ca198c72cf4a801b79e9c979ebcd8557884d422e65571b38	2026-08-11 14:05:17.211304+05:30	2026-09-10 14:05:17.211148+05:30	\N	\N	node
411	17	d152cd8bf188db359538394332ceede13bc4bc9dfb0c383c530b556da9dfa2d2	2026-08-11 14:05:19.19108+05:30	2026-09-10 14:05:19.190895+05:30	\N	\N	node
423	18	07d3821f7ddbfba269f649260a6eb522c0e9d95230b70067057392f14d9f8955	2026-08-11 14:05:24.496657+05:30	2026-09-10 14:05:24.496272+05:30	\N	\N	node
426	197	b171210a87c3d554f6c25e8a0b64b28329fb80f6a1e77991738819a9c67d4d4f	2026-08-11 14:05:26.137911+05:30	2026-09-10 14:05:26.13776+05:30	\N	\N	node
429	197	e16252adc01aaea609bca036ec3014219f825a8f4f77a4d54a6a9cd022f4918d	2026-08-11 14:05:27.697989+05:30	2026-09-10 14:05:27.697657+05:30	\N	\N	node
434	18	4bfc29d3cf12b0580d4bffe3486759eed3810f7ec2abdcfbef83635d4679217e	2026-08-11 14:05:30.250713+05:30	2026-09-10 14:05:30.250494+05:30	\N	\N	node
458	201	a33d692c3472a091061053f59a5ee692a44627abaeceddbb8b66c826cd8dbb17	2026-08-11 14:05:57.79401+05:30	2026-09-10 14:05:57.793837+05:30	\N	\N	node
461	18	aef9708451fa542e48b66dc2442ce1a0bd81eb84f3c92e06185f4fc7e525f831	2026-08-11 14:05:59.714657+05:30	2026-09-10 14:05:59.712403+05:30	\N	\N	node
396	17	a2ac48b6403435e480bb0a360bfd3fdf3c061684c7e1bd070bac374c3253ddc6	2026-08-11 14:05:10.087829+05:30	2026-09-10 14:05:10.087574+05:30	\N	\N	node
398	17	b868cb324dfbf3417715516b73f1151cc2c0fca973ae20cf74e502d420fb5ec5	2026-08-11 14:05:11.367913+05:30	2026-09-10 14:05:11.367677+05:30	\N	\N	node
400	17	2e622cc97db57ef3fedf7c6c8eb25623e96da75fe6d4de1aef558c4d92ea26b8	2026-08-11 14:05:13.234748+05:30	2026-09-10 14:05:13.234555+05:30	\N	\N	node
406	18	341f06ff599e334c72c6469941bb560304452342198ede87d7266c20e866812a	2026-08-11 14:05:15.987464+05:30	2026-09-10 14:05:15.987312+05:30	\N	\N	node
412	18	0001262b00e09e6f4c5b7ee95d4eb26780c0583edce9df02b2b32b2bbe4267c8	2026-08-11 14:05:19.563031+05:30	2026-09-10 14:05:19.562514+05:30	\N	\N	node
424	17	cf3a858bee758ba48db1a0cfd5b9fe68e5104fa653a8aabb45097b1c9b108901	2026-08-11 14:05:24.81515+05:30	2026-09-10 14:05:24.814924+05:30	\N	\N	node
428	17	333ae1795264629f228664857bd3de90b27346ae811712fa869f213f2cf5d106	2026-08-11 14:05:26.955317+05:30	2026-09-10 14:05:26.955018+05:30	\N	\N	node
439	3	8062c7e336c601cc364b98aaf253923d9856bffc6b0805072b4e734cbdfe0dcf	2026-08-11 14:05:47.18396+05:30	2026-09-10 14:05:47.183786+05:30	\N	\N	node
453	18	79184ae531b276bd0b9fe736ce2a9ef7b57406eb13a3d4751240f940da86ad41	2026-08-11 14:05:54.976291+05:30	2026-09-10 14:05:54.975988+05:30	\N	\N	node
456	200	ff2e7b992b6fcc55c9faf08a134b59d63ee9464ba75c7da800b97e5bc53d8cee	2026-08-11 14:05:56.531424+05:30	2026-09-10 14:05:56.531235+05:30	\N	\N	node
468	18	c4d30fa11eae34e9919f0ff8c188d7597b87f579750fc2680a4a2912bfe6e9a3	2026-08-11 14:06:02.908237+05:30	2026-09-10 14:06:02.908017+05:30	\N	\N	node
469	18	3e007eb27d7d3d53e8b300d47e3100a871da97ae9cd08048aa92ac90372c923f	2026-08-11 14:06:03.402006+05:30	2026-09-10 14:06:03.401769+05:30	\N	\N	node
470	202	08a058e55007c2c8c57a683e8bd2179cc396997ca09c0905bf4735caf34fb718	2026-08-11 14:06:03.904946+05:30	2026-09-10 14:06:03.904723+05:30	\N	\N	node
471	18	1dc8a2aee771e7b263fd8ce3c6ee90210208f21298ac22aa64040d789c6c8433	2026-08-11 14:06:04.356239+05:30	2026-09-10 14:06:04.356072+05:30	\N	\N	node
472	202	affda15aa470c45715aaef0b393f7362133745130494e60e9eb40ff0fa3d0a97	2026-08-11 14:06:04.789141+05:30	2026-09-10 14:06:04.788975+05:30	\N	\N	node
473	18	07a52d4c24e672db8368f9f7aa4eee84085ddba4ed50dd9147140508cb52cc34	2026-08-11 14:06:05.209981+05:30	2026-09-10 14:06:05.20982+05:30	\N	\N	node
474	18	be38d09cf9d03791bb971f5719b73bd12fb7128808851da50e742a8952af5661	2026-08-11 14:06:05.831519+05:30	2026-09-10 14:06:05.831302+05:30	\N	\N	node
475	17	01103dff3d9b52a9719496479828acd7be2194e9feab27185a04f3b1e227965a	2026-08-11 14:06:06.172898+05:30	2026-09-10 14:06:06.172653+05:30	\N	\N	node
476	17	5b1f133d84b979b7705eac7475e723296dad6a4bedd340c9764247137b72e16a	2026-08-11 14:06:06.544519+05:30	2026-09-10 14:06:06.544334+05:30	\N	\N	node
477	203	12fc9f823b5fea50b5f2cff294d394abd6b8c788d6a88ea58591a6662d7b070f	2026-08-11 14:06:07.658431+05:30	2026-09-10 14:06:07.658272+05:30	\N	\N	node
478	17	4e3d96eb3b242df5726d0b5215923e5da6cd7a9562178627da2e268275c0e1b0	2026-08-11 14:06:08.033441+05:30	2026-09-10 14:06:08.033204+05:30	\N	\N	node
479	17	894f13a9a5e53ae1a10cb5a531805a5f03b31ce5ceb12fc464da12236ddd8334	2026-08-11 14:06:08.516207+05:30	2026-09-10 14:06:08.51596+05:30	\N	\N	node
480	203	7acdc0e6ef7b041cb71ccaf83a91460ff464a509083b50883f0f4f5c30ca5c06	2026-08-11 14:06:08.947953+05:30	2026-09-10 14:06:08.947551+05:30	\N	\N	node
481	17	df253ae3a2d663ba7e3e936ed498c85fbbd90340c39a4b02a66a7eef05dc0a61	2026-08-11 14:06:09.309422+05:30	2026-09-10 14:06:09.309225+05:30	\N	\N	node
482	17	bce8207658d736bb30e67a827bc21a0567d18010e73c6ae6f9c8374551ce0796	2026-08-11 14:06:09.866801+05:30	2026-09-10 14:06:09.866602+05:30	\N	\N	node
483	17	31633d2913eb1a0e4a6e1a8cae39dd9adfc5917e5278dedef61bc62e2aaf354f	2026-08-11 14:06:10.379622+05:30	2026-09-10 14:06:10.379099+05:30	\N	\N	node
484	18	56c46cc32736f89e23096209f98759147a102734842f1db3e9f4426c7a67edf7	2026-08-11 14:06:10.719854+05:30	2026-09-10 14:06:10.719606+05:30	\N	\N	node
485	18	ee7f5af9fc3e359f95284acb45e0654d7d4a4b074277771a3d3956e0fdb58be7	2026-08-11 14:06:11.883198+05:30	2026-09-10 14:06:11.882833+05:30	\N	\N	node
486	17	75237e59735189e4c29e7753177c6558a3aef7dd8b7abd06263eb7f5b2666747	2026-08-11 14:06:12.373075+05:30	2026-09-10 14:06:12.372654+05:30	\N	\N	node
487	18	febe0d63c5c88db975dd511e3f7f53af1cd5710e33a8a61142af0069e84396b5	2026-08-11 14:06:12.711998+05:30	2026-09-10 14:06:12.711729+05:30	\N	\N	node
488	17	ce0203a94a34867ac85201c01923dc2deb87337eba708c679840cb7cf3c71d4a	2026-08-11 14:06:13.469406+05:30	2026-09-10 14:06:13.469137+05:30	\N	\N	node
489	5	64ea4bed5bd9557b71013a4e072a5a1b86e4379166db9bf893b9f4ef46d12ec5	2026-08-11 14:06:16.070076+05:30	2026-09-10 14:06:16.069858+05:30	\N	\N	node
490	3	1f9874653692a81eb501f105f6d8fa76898bab0072af27a25b8487698ec6c150	2026-08-11 14:06:16.491685+05:30	2026-09-10 14:06:16.491519+05:30	\N	\N	node
491	3	9b3128a68adb3d6717a7358836cdc51f08045e06d2dd26a86e9a227c2265914b	2026-08-11 14:06:16.882978+05:30	2026-09-10 14:06:16.88269+05:30	\N	\N	node
492	7	65097946dd5c5ec4312be8be5c0e0aedc6f9c49036630c333f06e50d00be6e0d	2026-08-11 14:06:17.232819+05:30	2026-09-10 14:06:17.232611+05:30	\N	\N	node
493	8	00edf0775f964d8b1e1f1dcf6c5b97b6dc1bd4bbdfd4a3fbe1fbc7f01d36bd9e	2026-08-11 14:06:17.780793+05:30	2026-09-10 14:06:17.780145+05:30	\N	\N	node
494	17	05aa0b662ac5e6872eb23c363cd26e0c98c2ea1e8cb7b2931a10fee74976066a	2026-08-11 14:06:18.286124+05:30	2026-09-10 14:06:18.28582+05:30	\N	\N	node
495	204	70cf797e9e8b5ddf45a2d6aeaf9e5e79be69d5022e7de485de539f2bb38ac23c	2026-08-11 14:06:18.980001+05:30	2026-09-10 14:06:18.97969+05:30	\N	\N	node
496	17	c000be84bb7954a20b4f316939446bb5a12d392127176352dc36956fd19c05f1	2026-08-11 14:06:19.435974+05:30	2026-09-10 14:06:19.43563+05:30	\N	\N	node
497	204	f0e533f5598e868439256db7fa0341a1b71f4086825c98130289fbfa123538a2	2026-08-11 14:06:20.59815+05:30	2026-09-10 14:06:20.597916+05:30	\N	\N	node
498	17	7bccc0b7fd0fc6df43776450527c68146320d49d827a6e07d6eb4dced3a49864	2026-08-11 14:06:20.911456+05:30	2026-09-10 14:06:20.911301+05:30	\N	\N	node
499	18	51d2eed0977b6372fe5e780942c6b79b08fbbf730bd16e68706182e797ec068d	2026-08-11 14:06:21.231422+05:30	2026-09-10 14:06:21.231182+05:30	\N	\N	node
500	17	39f6a22c90ef2470d5ff860c53a79b917da5c42cc82486afe27d3b180d7ca342	2026-08-11 14:06:21.922625+05:30	2026-09-10 14:06:21.922351+05:30	\N	\N	node
501	18	3ad041b7e88298f9f1fbf0b75fd61fa0d085046590886d32f049a27bb1377459	2026-08-11 14:06:22.239856+05:30	2026-09-10 14:06:22.23966+05:30	\N	\N	node
502	17	775876e0799050fe56c9b6af11a44f24c9671b0daa3aade0d775c8a4f1156d47	2026-08-11 14:06:23.48136+05:30	2026-09-10 14:06:23.481022+05:30	\N	\N	node
503	17	48d65c1efbc286e490f7aee6b1767d76adceecc41171c59221952bcb2eef7168	2026-08-11 14:06:23.819604+05:30	2026-09-10 14:06:23.819472+05:30	\N	\N	node
504	18	2312c7a2dfc39d192a16c0af680b3c4c2b0da49ef3fadef1aaa8d4777f0f5fd3	2026-08-11 14:06:24.310862+05:30	2026-09-10 14:06:24.310688+05:30	\N	\N	node
505	17	a6d2a401bb96d9e88f5724c497e2365ff8667ed4958cb698f67e5429fd92dde6	2026-08-11 14:06:24.684165+05:30	2026-09-10 14:06:24.683992+05:30	\N	\N	node
506	18	161a4767422162762c59a5319fb767c59f31730db8d51dd18cff484f5a8fb212	2026-08-11 14:06:25.034381+05:30	2026-09-10 14:06:25.03422+05:30	\N	\N	node
507	206	a3e46159526a0e43a5fe5cd4c9ee2784bae56d887542f097c18cd7006078ff3a	2026-08-11 14:06:25.852496+05:30	2026-09-10 14:06:25.852281+05:30	\N	\N	node
508	18	e18a2ce11cf89d27cd92f3828f469b0dbbbf62a73ce09cd7cdbdf358183142fa	2026-08-11 14:06:26.202992+05:30	2026-09-10 14:06:26.202776+05:30	\N	\N	node
509	207	47493c4d3f7efb82a282e930691ad400e41e85449d73878bfb45f3fce3ecb001	2026-08-11 14:06:26.976191+05:30	2026-09-10 14:06:26.976037+05:30	\N	\N	node
510	18	ce579195fd64fdbab4c4801eb79b4eb3e9a2ea4d736eb1a002c56cc927a2bb0c	2026-08-11 14:06:27.376146+05:30	2026-09-10 14:06:27.375949+05:30	\N	\N	node
511	206	8592f664e6c7743b66c88b5ab944624ef1ce2f0ade23aaf5ddad4407a012d63b	2026-08-11 14:06:28.541886+05:30	2026-09-10 14:06:28.541688+05:30	\N	\N	node
512	18	fe36808e31757b4eaf1ba4c5ea0e50ec3110fbf42c8ed0cbabd3f8307dbef1eb	2026-08-11 14:06:28.94869+05:30	2026-09-10 14:06:28.94835+05:30	\N	\N	node
513	17	364d1b273748971b002d4a3fa9b8d13eeba16078a23999c35db93ef61a69861b	2026-08-11 14:06:29.321328+05:30	2026-09-10 14:06:29.321136+05:30	\N	\N	node
514	18	57600d1ace231ad5953aa51e6824b2643bd726dd7ed6d65b236963484c07fbcd	2026-08-11 14:06:29.666559+05:30	2026-09-10 14:06:29.666324+05:30	\N	\N	node
516	17	4ed6e544784f1ca3943c054006d31ff207ebd716e8f7f84d4a2331d0ead8a3bd	2026-08-11 14:06:30.443967+05:30	2026-09-10 14:06:30.443745+05:30	\N	\N	node
535	18	3ca7f539d608232e2f502f8864dcf7f572aa211adb1b92ccf69ce25306c4d396	2026-08-11 14:06:39.974514+05:30	2026-09-10 14:06:39.974233+05:30	\N	\N	node
540	5	c726ef067624ec4a953b75a57fef273ea93b794a51b91a5fbd159f3ac6446f85	2026-08-11 14:06:45.341822+05:30	2026-09-10 14:06:45.341654+05:30	\N	\N	node
541	3	f1a97af597bb4b6a1b7964d68eb09bad35c494f0a840dacb6726f923d9fa0d06	2026-08-11 14:06:45.719179+05:30	2026-09-10 14:06:45.719007+05:30	\N	\N	node
550	18	75ffac4d4b03162cc4803c24fb6ee9bdf1446db5be4c3428b608277ea678c6c9	2026-08-11 14:06:50.956095+05:30	2026-09-10 14:06:50.955913+05:30	\N	\N	node
552	18	40d04c46e274969717051ef30db68441ef39ff3daa06cf993f34130d08263065	2026-08-11 14:06:52.006511+05:30	2026-09-10 14:06:52.006332+05:30	\N	\N	node
557	18	9dc1865b8d0b4546f6ac9ad0e821759cb35b47e7768aa050eb08a8165866d663	2026-08-11 14:06:55.028437+05:30	2026-09-10 14:06:55.028262+05:30	\N	\N	node
569	214	44ca7bac2b832373fe4773f70dfd4a57db8adde3865da5ea799eba9954ca7ad2	2026-08-11 14:07:01.682441+05:30	2026-09-10 14:07:01.68211+05:30	\N	\N	node
566	1	15d61b0942cd68a0e4d543988a8869699d3277190b1cb77ff929dbcec68a4101	2026-08-11 14:07:00.067612+05:30	2026-09-10 14:07:00.067473+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
517	18	28297eb81dcee10be3aa663bc783319bc27c1c05b6841666a7e634623a4d9c84	2026-08-11 14:06:30.818335+05:30	2026-09-10 14:06:30.818179+05:30	\N	\N	node
518	208	204073e04d841fe3bb4acd3b53910a773e41493e8541e9d5d02d999f67912a0e	2026-08-11 14:06:31.673685+05:30	2026-09-10 14:06:31.673458+05:30	\N	\N	node
532	17	e7c741cdffa9f15f6e4f7a9f28b1073ce499d760f2904721c520b964cf3c09e3	2026-08-11 14:06:38.522709+05:30	2026-09-10 14:06:38.522486+05:30	\N	\N	node
547	17	3cfee791d0c7178322415477e9c2205fea60c660c6bffffcb2cf6e9fff891739	2026-08-11 14:06:49.118176+05:30	2026-09-10 14:06:49.117774+05:30	\N	\N	node
554	17	48aaca419cac956e5789b62c947c978a1c2ec2a7f4576db8b40604d34a031d19	2026-08-11 14:06:53.794623+05:30	2026-09-10 14:06:53.794425+05:30	\N	\N	node
562	212	966fc11f8183dc598b50f8f89a53734fa451cbcc37946e854ee028f1691ac381	2026-08-11 14:06:58.557656+05:30	2026-09-10 14:06:58.557352+05:30	\N	\N	node
568	18	66cde4708823a37a4fe4a5f4e72b708823831ece598e02195e5a929efb4580ce	2026-08-11 14:07:00.727843+05:30	2026-09-10 14:07:00.727698+05:30	\N	\N	node
519	18	00be29c10a974b6cf168e58a6edece914bcec8f164cbafe574a7ff570b9db754	2026-08-11 14:06:32.053255+05:30	2026-09-10 14:06:32.053077+05:30	\N	\N	node
527	17	d761809335bb039a8e0e599f4c1f65be05c0b84ab170ef96ea5a8590c8ca8e0a	2026-08-11 14:06:35.726973+05:30	2026-09-10 14:06:35.726804+05:30	\N	\N	node
545	17	ce4709365cd917fac1572be192306535f9aaca35073ceb22127ade4daabc82d1	2026-08-11 14:06:47.873603+05:30	2026-09-10 14:06:47.873212+05:30	\N	\N	node
559	18	e510a8895b274bcfd35fd459d2eb6baf54b7bc5a281630ce826548a7df882145	2026-08-11 14:06:56.203132+05:30	2026-09-10 14:06:56.202973+05:30	\N	\N	node
564	17	8f2792aaa15c4cde5ffc441bae5698be615f60ce840155d29f618b853d5b5e9f	2026-08-11 14:06:59.343617+05:30	2026-09-10 14:06:59.343381+05:30	\N	\N	node
570	18	f68fc817c2277e6712219950b56c39d7b8aae997bd166748f6920a761cfc93cd	2026-08-11 14:07:02.02671+05:30	2026-09-10 14:07:02.026491+05:30	\N	\N	node
520	18	e66879658c1a58f16ca156aa58e4c64d90cb0e4701d237b78ed0a80e27434402	2026-08-11 14:06:32.469113+05:30	2026-09-10 14:06:32.468857+05:30	\N	\N	node
521	208	50a1c590f8bf89a768fc2caa1b1bdb2b102e821a27727620c51c090423fe2c74	2026-08-11 14:06:33.075847+05:30	2026-09-10 14:06:33.075662+05:30	\N	\N	node
529	17	2e3d6af3d6e2a8260164dac4773ca1034122d9574a008cf92c26a4e91657e89b	2026-08-11 14:06:37.122429+05:30	2026-09-10 14:06:37.12219+05:30	\N	\N	node
533	17	d40f517e4bccf73e8f5ad70dc70e7268384156168c813e0d7ced336554f5b6b4	2026-08-11 14:06:39.028277+05:30	2026-09-10 14:06:39.028047+05:30	\N	\N	node
542	3	c0a4892e4d3376aa2810b309848bac561cd15ccf057c7fd8f3077a9a03c813a9	2026-08-11 14:06:46.191121+05:30	2026-09-10 14:06:46.19089+05:30	\N	\N	node
556	17	7faa7b6c05e564292c9ca47ea00aed40fe8d83588afd291716337605aa3078e4	2026-08-11 14:06:54.696323+05:30	2026-09-10 14:06:54.696148+05:30	\N	\N	node
522	18	8bec1df1b654400566e18ab2b1ab651953a1bc35f81f43153766637f62564d8e	2026-08-11 14:06:33.408806+05:30	2026-09-10 14:06:33.408647+05:30	\N	\N	node
538	18	2d5a62555bedf2d98bfca6ec6280121f641bd6e34cb73c106f734a33fc89f57c	2026-08-11 14:06:41.886637+05:30	2026-09-10 14:06:41.886398+05:30	\N	\N	node
544	8	226e4d50521649ca591c013ada7f557acece7ba13da9ca240ecef562cdf07da3	2026-08-11 14:06:47.042814+05:30	2026-09-10 14:06:47.042628+05:30	\N	\N	node
555	18	3d3c4449ddbf1955596fa774e79c0bfec0c25c93bc64f29e95b55f5c1aeb7bd9	2026-08-11 14:06:54.352119+05:30	2026-09-10 14:06:54.351787+05:30	\N	\N	node
565	18	931ac6e499b544ef92e6325554c30f48da54c247522ac4f2cc24366bc3387da7	2026-08-11 14:06:59.69055+05:30	2026-09-10 14:06:59.690358+05:30	\N	\N	node
523	208	4d52f527edc92bb9524c3ced335e064544121d32632adae4e2d640d3729612c4	2026-08-11 14:06:33.83595+05:30	2026-09-10 14:06:33.835717+05:30	\N	\N	node
549	17	da7cce60c5dc9f271e0a42b43c10f6ced84c8be5a9d60a90abdb18cdb8290d0c	2026-08-11 14:06:50.627051+05:30	2026-09-10 14:06:50.626833+05:30	\N	\N	node
551	17	f672f0196d76947b11c27d87f10e17d22686d2efac78278685d80c7de54eabad	2026-08-11 14:06:51.656008+05:30	2026-09-10 14:06:51.655831+05:30	\N	\N	node
561	18	1e78725a8915a298042b9665a756f0406153877824711b8ed16d9ac49117adc0	2026-08-11 14:06:57.383817+05:30	2026-09-10 14:06:57.383636+05:30	\N	\N	node
567	17	e22261bf92beba3f9070dcff7598c878926cfb09bc17381a24503eb376947f38	2026-08-11 14:07:00.404894+05:30	2026-09-10 14:07:00.40469+05:30	\N	\N	node
524	18	2e8f4169130c964fd570181db15b93a306e6c9b435c451f619a79ed0ddc9bfd8	2026-08-11 14:06:34.299568+05:30	2026-09-10 14:06:34.299289+05:30	\N	\N	node
528	209	9e297bf2ac9423253f06a61e125f12e2f56016efbc69fcbfebc6354f6fc60768	2026-08-11 14:06:36.789985+05:30	2026-09-10 14:06:36.789826+05:30	\N	\N	node
536	18	f8bf23ac0b7be10b3ac2c5b5f8b4e424b4d5757beccf2ea9624631d1d62f417f	2026-08-11 14:06:41.183579+05:30	2026-09-10 14:06:41.18338+05:30	\N	\N	node
546	210	f29bc01cf9eb0564343afb529ea83bf72200ed5d737a5a25dd3fe07e473e8ba3	2026-08-11 14:06:48.639819+05:30	2026-09-10 14:06:48.639613+05:30	\N	\N	node
553	17	9eca61243073647074baaa299564a4461e3e7035fe999cd5c1411e2661f98032	2026-08-11 14:06:53.484872+05:30	2026-09-10 14:06:53.484711+05:30	\N	\N	node
525	18	06ed7089e51a3d25ff361e86f4f25cb166a97c9f630a7dfee61a6edba75b889f	2026-08-11 14:06:34.889602+05:30	2026-09-10 14:06:34.889381+05:30	\N	\N	node
530	17	02ab21d5f6378320de7e7aa10597e143cb2deb4f4dca36340dac3acfd3296b5b	2026-08-11 14:06:37.663671+05:30	2026-09-10 14:06:37.663379+05:30	\N	\N	node
537	17	1ecf5abe9a784b53c8da69713871f00e7a676c67c70a63e3b145c39aa26459c0	2026-08-11 14:06:41.542899+05:30	2026-09-10 14:06:41.542746+05:30	\N	\N	node
539	17	11906bb2c28f56771e6dec4f435b1226b054855931d3beddf601a2daf37c3741	2026-08-11 14:06:42.797965+05:30	2026-09-10 14:06:42.797179+05:30	\N	\N	node
558	212	79cc4b596dbddad4aabe9e22d1682eb9714c12e5305c6ed165ae47d2782a8742	2026-08-11 14:06:55.835842+05:30	2026-09-10 14:06:55.835674+05:30	\N	\N	node
526	17	af5ee28d5aacc69af35ac0312b0e37f7a93133527d3dc7d4554482bc1a9b2ea9	2026-08-11 14:06:35.313171+05:30	2026-09-10 14:06:35.312546+05:30	\N	\N	node
531	209	a5a50e3b5e855205d4543f427bb1a9496a3ffbcbc3522082bce76094bdb51a33	2026-08-11 14:06:38.178097+05:30	2026-09-10 14:06:38.177937+05:30	\N	\N	node
543	7	b0fdb6b78c6fa8718db8128f8da63da88c1595415adafb5f23b5cc549e099ea9	2026-08-11 14:06:46.51975+05:30	2026-09-10 14:06:46.519587+05:30	\N	\N	node
548	210	63d6aa2ce0e6f35591106a42a3eb04805a4f96497315383ee869cd74d41034f2	2026-08-11 14:06:50.287169+05:30	2026-09-10 14:06:50.286988+05:30	\N	\N	node
560	213	383212942ea543de354b95ce255aa8c41f3b35fb720387cedbfb194c369b1f91	2026-08-11 14:06:57.012191+05:30	2026-09-10 14:06:57.011923+05:30	\N	\N	node
534	17	0edc7030c5e9d4f69f02cd565434a309073dc2ff08f88934399b756a68bcda74	2026-08-11 14:06:39.580991+05:30	2026-09-10 14:06:39.580227+05:30	\N	\N	node
563	18	1cd08085e9ee4127f6813286554f393e7493da98c039e12ab978f28929fa73e6	2026-08-11 14:06:58.904057+05:30	2026-09-10 14:06:58.903886+05:30	\N	\N	node
571	18	d63868064314a003e2d4f9aad810ac3543257b378cd59c85ec96bbc2ba5d39c7	2026-08-11 14:07:02.827136+05:30	2026-09-10 14:07:02.826825+05:30	\N	\N	node
572	214	7cdf0eb3e66472bdf91282b421383a935b714fd4c9adcae726677cd5e84af90f	2026-08-11 14:07:03.422789+05:30	2026-09-10 14:07:03.422568+05:30	\N	\N	node
573	18	106b64cc8034c27775e21ef351d1453090e01d0d7c0c28e50bbbf1c5b3bc1a78	2026-08-11 14:07:03.824409+05:30	2026-09-10 14:07:03.824148+05:30	\N	\N	node
574	214	5f76a87ce3cf6d70a245dcbbe74f42bfd05de7a70f230c8d3b3b3eea4381e48b	2026-08-11 14:07:04.308333+05:30	2026-09-10 14:07:04.308122+05:30	\N	\N	node
575	18	05d4563e0d3f7210cf4705ef21cde72107af18e5671e82e3ba83872505954033	2026-08-11 14:07:04.721526+05:30	2026-09-10 14:07:04.721319+05:30	\N	\N	node
576	18	0ebb412ceb0440284035edbb987690158acd41e4f1a4ff66662c8f130b2940c5	2026-08-11 14:07:05.5206+05:30	2026-09-10 14:07:05.52039+05:30	\N	\N	node
577	17	96ad9cfac1c70ed9aa4391662bbcb2b0d1f676d32e8f5d1b43049476531df656	2026-08-11 14:07:05.953725+05:30	2026-09-10 14:07:05.95352+05:30	\N	\N	node
578	17	e64f0a10ccaebd547e98102065298a99be666a3b6eea23b5b9124ecb53039b45	2026-08-11 14:07:06.316524+05:30	2026-09-10 14:07:06.316233+05:30	\N	\N	node
579	215	e6c0c02acc041ac009093b9e8ba4c75b1a99cd068adf662099011454db587c1e	2026-08-11 14:07:07.695374+05:30	2026-09-10 14:07:07.694998+05:30	\N	\N	node
580	17	5899bf117cdd6b3d29990db69d542cf9926e926918f16e1488c61b9fbb2b219a	2026-08-11 14:07:08.219036+05:30	2026-09-10 14:07:08.218775+05:30	\N	\N	node
581	17	fa2923b46673bccd4cb9414cb8a11475df862a4f6bdf0bb715e45b3494da7578	2026-08-11 14:07:08.675517+05:30	2026-09-10 14:07:08.675306+05:30	\N	\N	node
582	215	90fef08bff4f053974d859f2b56b5f86cf3cdd720bbac60657891916044e9c2d	2026-08-11 14:07:09.174432+05:30	2026-09-10 14:07:09.174188+05:30	\N	\N	node
583	17	50db2d59eb6f4bbdd7e9bf2b8cdea6d33a874310c85add3eae8107c4cfc88e9b	2026-08-11 14:07:09.698656+05:30	2026-09-10 14:07:09.698296+05:30	\N	\N	node
584	17	72fed1693f36d219e6d3fe2a43575b9eabec80aa82b078890d737d5273d480f2	2026-08-11 14:07:10.169277+05:30	2026-09-10 14:07:10.169021+05:30	\N	\N	node
585	17	ff22077d14f2c29413cae5d3c643ce620a89b2af9587257096cf59909df07fdf	2026-08-11 14:07:10.849425+05:30	2026-09-10 14:07:10.849111+05:30	\N	\N	node
586	18	4dd87f346edf0d7e3085f9109b3178b16daa3e125ae85069e1da89f0d8a3302b	2026-08-11 14:07:11.204424+05:30	2026-09-10 14:07:11.204156+05:30	\N	\N	node
587	18	49de7b7ffb814132ea823ff0b499c3fadba3ae4e32ad029f61cc0ea3e0e8ef62	2026-08-11 14:07:12.403277+05:30	2026-09-10 14:07:12.403106+05:30	\N	\N	node
588	17	a3d8bfcba965dcc321fb55f025b596a9a6c7faf2a4ca776c5fd0d97921973a57	2026-08-11 14:07:12.770223+05:30	2026-09-10 14:07:12.76996+05:30	\N	\N	node
589	18	7985f8ef28e436da0f2dcd8343bbafbc468e2425a7bb3509d62f18f416c60268	2026-08-11 14:07:13.159702+05:30	2026-09-10 14:07:13.159514+05:30	\N	\N	node
590	17	de21f6e1bf3723e29d5a76ba50f7a929bfbe9cd3e3a435440b95a97a6214edff	2026-08-11 14:07:14.10052+05:30	2026-09-10 14:07:14.100232+05:30	\N	\N	node
591	1	77c1529190d17f0396ba2573ef325925b801053aab71121e5b8c0a2dc8573c40	2026-08-11 14:08:47.768414+05:30	2026-09-10 14:08:47.768161+05:30	2026-08-11 14:08:48.246269+05:30	2026-08-11 14:08:48.246269+05:30	node
593	1	c9d524e6dc3564c73708a0123d31ea472017a74b587426d0b9b8b479ba39472f	2026-08-11 14:08:48.584726+05:30	2026-09-10 14:08:48.584541+05:30	2026-08-11 14:08:48.919961+05:30	2026-08-11 14:08:48.919961+05:30	node
594	1	e9079584c2b14c771dd8ec430bc820fe01c6614bce5ce1c39dae006d15175b1e	2026-08-11 14:08:48.911708+05:30	2026-09-10 14:08:48.911516+05:30	2026-08-11 14:08:48.931077+05:30	2026-08-11 14:08:48.931077+05:30	node
597	2	930606dd065f9408abcd9bc33cb08961f7cec2702f35aeb4bf117a32db2a806f	2026-08-11 14:08:49.727408+05:30	2026-09-10 14:08:49.727163+05:30	\N	\N	node
31	1	2c6c3b355366a10b47361779f48a400e008cc6e6721e549582dcda4d03d161ff	2026-08-11 13:56:35.786088+05:30	2026-09-10 13:56:35.785861+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
67	1	001c7f3073b199931765211ceabf6a32b4f5a68c4a7bff0b1c4817934a486dd1	2026-08-11 13:58:20.283875+05:30	2026-09-10 13:58:20.283707+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
175	1	6591d7048556a35c7d3059a81c54344f36de4b5c359104730c1eec17c405d2a3	2026-08-11 14:00:37.806156+05:30	2026-09-10 14:00:37.805956+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
176	1	61bf9872349cf6f0d92c68bdf839bb6b7fbb3a64826ad7673a5a2d56b14ae47c	2026-08-11 14:00:54.234448+05:30	2026-09-10 14:00:54.234289+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
180	1	8be8fc608bb071a6b98b8e5185bf1930a060cfbd8f1d4ae59767d8c2d13c9de5	2026-08-11 14:01:33.379546+05:30	2026-09-10 14:01:33.379284+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
269	1	5394d6167984850a27f3af5f4a5faf3e49bb44288816329a494db447c9c8a8bd	2026-08-11 14:03:24.869537+05:30	2026-09-10 14:03:24.869374+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
362	1	091bb97d0fcf457353b3adfcfa262d4012e153d0900b68069bc15e0b06aa8a99	2026-08-11 14:04:50.709486+05:30	2026-09-10 14:04:50.709305+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
515	1	55e3006174724ad2f84f414d347ecabeac7da4637e9c0f902ff99c82c7119125	2026-08-11 14:06:30.103446+05:30	2026-09-10 14:06:30.103154+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
592	1	0d091a22d4d84b117fcff7f31a492f812d78bba56f18dcff4ea3801602653e2d	2026-08-11 14:08:48.256927+05:30	2026-09-10 14:08:48.256772+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
595	1	5ecd66de41d68c8e0f88b192cbd9be7c0c2473ca57ab361592826219b94d53b5	2026-08-11 14:08:48.926603+05:30	2026-09-10 14:08:48.926446+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
596	1	f94fa6c01f9f31121e9f90b34c3112b3fd0cba4c259d88bc2acae3f8049c24e6	2026-08-11 14:08:48.937595+05:30	2026-09-10 14:08:48.937439+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
598	1	a86026be3dd79eefbc46be882e1938e26ec4ffcbb240f870d39cf618ce76a9ec	2026-08-11 14:08:50.408385+05:30	2026-09-10 14:08:50.408126+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
599	1	66f4d27e760caa8c2ba3d09c1395dc30d1311f374290fc3ca12c0ad47896ace0	2026-08-11 14:08:50.768349+05:30	2026-09-10 14:08:50.768132+05:30	\N	2026-08-11 14:08:50.774999+05:30	node
600	1	e1d43528654086de5da8398eab11912d532171284c579f4774a831ea408acbf2	2026-08-11 14:09:09.870539+05:30	2026-09-10 14:09:09.870373+05:30	2026-08-11 14:09:10.312062+05:30	2026-08-11 14:09:10.312062+05:30	node
602	1	2bdb6f205c883cd29ce682923b20ca26847d4a0e50f0f047e70e3f82c2413b8d	2026-08-11 14:09:10.651586+05:30	2026-09-10 14:09:10.651418+05:30	2026-08-11 14:09:11.033843+05:30	2026-08-11 14:09:11.033843+05:30	node
603	1	616065a8eaace66c7907fe0ab936ad72f021698f65f1d3ed6e3f7108e8bd8ce1	2026-08-11 14:09:11.026445+05:30	2026-09-10 14:09:11.026259+05:30	2026-08-11 14:09:11.040518+05:30	2026-08-11 14:09:11.040518+05:30	node
606	2	086a9c7984b7196a08cda875bff248cec34b6a5a0c08e7465e5877abc4853cb3	2026-08-11 14:09:11.614032+05:30	2026-09-10 14:09:11.613898+05:30	\N	\N	node
601	1	063981429494cce49486927991e8079c1e669f45f369d0ca13a0fc02222e42f1	2026-08-11 14:09:10.314193+05:30	2026-09-10 14:09:10.314064+05:30	\N	2026-08-11 14:09:12.551297+05:30	node
604	1	f41b5e7092d9ba642dbacdeb5f6a9748e7ce2abfbc434da231faa6892017813e	2026-08-11 14:09:11.036082+05:30	2026-09-10 14:09:11.03593+05:30	\N	2026-08-11 14:09:12.551297+05:30	node
605	1	c53d7230d4dfdf403643fc82e1432ee4e72c3d85950a40b16b186ab9fe799bc9	2026-08-11 14:09:11.044391+05:30	2026-09-10 14:09:11.044246+05:30	\N	2026-08-11 14:09:12.551297+05:30	node
607	1	3e257e124ee180ccea6c8f498fb4dbaf1b9f113040500d78f11a55bcb3abf65e	2026-08-11 14:09:12.202556+05:30	2026-09-10 14:09:12.202343+05:30	\N	2026-08-11 14:09:12.551297+05:30	node
608	1	67051677af8bfa91a9703614bd137692a7f16a95c3af11cfd140ee0deb35ef62	2026-08-11 14:09:12.545193+05:30	2026-09-10 14:09:12.545036+05:30	\N	2026-08-11 14:09:12.551297+05:30	node
618	1	883b0d170f52c664d7c5ee47c5cc3d5a8dd2a3649493694afdac53f7ea3b0e42	2026-08-11 14:17:32.461457+05:30	2026-09-10 14:17:32.460841+05:30	2026-08-11 14:17:33.424511+05:30	2026-08-11 14:17:33.424511+05:30	node
620	1	2fb9f841b48ffc6560ae1c4e93cb86a29fe2ed9bdd64227f9f06a40dfdf4c35f	2026-08-11 14:17:34.068347+05:30	2026-09-10 14:17:34.068086+05:30	2026-08-11 14:17:34.514761+05:30	2026-08-11 14:17:34.514761+05:30	node
621	1	4779902832747201a1f381bd664dd2735c951442cd26c6bbf4af8a4d6a831f08	2026-08-11 14:17:34.504617+05:30	2026-09-10 14:17:34.504187+05:30	2026-08-11 14:17:34.527257+05:30	2026-08-11 14:17:34.527257+05:30	node
619	1	2ed693919aee2125243e1c4baf4aa56f93d1818240bd165e5bcc76e9fec917d4	2026-08-11 14:17:33.428291+05:30	2026-09-10 14:17:33.428076+05:30	\N	2026-08-11 14:17:37.385895+05:30	node
637	1	ce6466043cc84976ed8e305cec353d276613eb5c72366b3874134191548d0661	2026-08-11 14:19:19.540005+05:30	2026-09-10 14:19:19.539578+05:30	2026-08-11 14:19:20.215895+05:30	2026-08-11 14:19:20.215895+05:30	node
638	1	42ece2cb5fab72adea423d671e1cfe3339b15f520f7db8810d801d60f9daaca8	2026-08-11 14:19:20.223414+05:30	2026-09-10 14:19:20.223116+05:30	\N	2026-08-11 14:19:23.69237+05:30	node
639	1	1765999ace042e9cdad0f32d0746f5afe53df9ac1f1441d127c656b9ef501660	2026-08-11 14:19:20.731917+05:30	2026-09-10 14:19:20.731659+05:30	2026-08-11 14:19:21.16533+05:30	2026-08-11 14:19:21.16533+05:30	node
640	1	2f0b6c5ffcaa1f82b41842a7c4678891bbcb18858fd269b99d658e4f23389057	2026-08-11 14:19:21.155709+05:30	2026-09-10 14:19:21.155394+05:30	2026-08-11 14:19:21.177334+05:30	2026-08-11 14:19:21.177334+05:30	node
643	2	32afe1967729e7eb60fcf8bb794302c2003fdcfb398d7dddf4f6581550f566ed	2026-08-11 14:19:22.069335+05:30	2026-09-10 14:19:22.069069+05:30	\N	\N	node
636	1	4417e9b1668f17fdceda46b7f4d210e546605c2af880361e127f77f49ac4d72c	2026-08-11 14:18:20.902801+05:30	2026-09-10 14:18:20.902495+05:30	\N	2026-08-11 14:19:23.69237+05:30	curl/8.14.1
641	1	32fd268c05543bf98b600b159ae6356853af2395fde4e5f56568086fd3de0090	2026-08-11 14:19:21.168137+05:30	2026-09-10 14:19:21.167935+05:30	\N	2026-08-11 14:19:23.69237+05:30	node
642	1	8dfbc25f2e82c25cda01eafe80438569b3e0055ad35a89b77f45db40cb83197c	2026-08-11 14:19:21.179954+05:30	2026-09-10 14:19:21.179743+05:30	\N	2026-08-11 14:19:23.69237+05:30	node
644	1	bd8c3405a85b0f48682f1a359c19bb24f1553f158ccaa41ad5422fb8dcfa67b1	2026-08-11 14:19:23.179756+05:30	2026-09-10 14:19:23.179485+05:30	\N	2026-08-11 14:19:23.69237+05:30	node
645	1	e41d1f9d8f3a89130bd1875a727929cf2b84cc248a2985fbdf32858a0897aa10	2026-08-11 14:19:23.6844+05:30	2026-09-10 14:19:23.684163+05:30	\N	2026-08-11 14:19:23.69237+05:30	node
646	1	ef716b881f24977897ac0b9f9a4523f750fb997b83a4fbfc01223376ab4ed5c5	2026-08-11 14:19:49.844891+05:30	2026-09-10 14:19:49.844644+05:30	2026-08-11 14:19:50.438532+05:30	2026-08-11 14:19:50.438532+05:30	node
648	1	e3f70fa333a7d96195012b17b78a4c8aeaa4f8108a84ab96a06989c6a16311ce	2026-08-11 14:19:50.991602+05:30	2026-09-10 14:19:50.991289+05:30	2026-08-11 14:19:51.462269+05:30	2026-08-11 14:19:51.462269+05:30	node
649	1	9bd6d01b42443fc2ae8ad739c62895b4916fe7536d94992551519440d6bc3b78	2026-08-11 14:19:51.448191+05:30	2026-09-10 14:19:51.447989+05:30	2026-08-11 14:19:51.471404+05:30	2026-08-11 14:19:51.471404+05:30	node
652	2	9ba7f5cb33d0c8e8c4634461957652b5594e206e6089ac019dd4ae910a9c0c76	2026-08-11 14:19:52.209071+05:30	2026-09-10 14:19:52.20879+05:30	\N	\N	node
647	1	5a453b187846503847078b3e17b1cb4d35b47c6ad8153f93633e0b65de46b9c1	2026-08-11 14:19:50.444427+05:30	2026-09-10 14:19:50.444109+05:30	\N	2026-08-11 14:19:53.848379+05:30	node
650	1	2061792d899c9b550bdda41876b15bba2f50338f0d61244c1dd1905c2967ce50	2026-08-11 14:19:51.46443+05:30	2026-09-10 14:19:51.464247+05:30	\N	2026-08-11 14:19:53.848379+05:30	node
651	1	fcbd2f3aa7a5a95106ea93cbfe1dff4afaa83901e27fbe56cd042e45d7b4c37d	2026-08-11 14:19:51.474605+05:30	2026-09-10 14:19:51.474367+05:30	\N	2026-08-11 14:19:53.848379+05:30	node
653	1	efaedbc73fd5bad22b8ab5f22f78596f1a579718249fedbc4a254ab73d3740c7	2026-08-11 14:19:53.335073+05:30	2026-09-10 14:19:53.334766+05:30	\N	2026-08-11 14:19:53.848379+05:30	node
654	1	70a6ebaa3a520508680ea45c42b9c304824d0824ece0354601ca3859842e29e9	2026-08-11 14:19:53.84155+05:30	2026-09-10 14:19:53.841264+05:30	\N	2026-08-11 14:19:53.848379+05:30	node
655	5	14c044bc430160fc2b26917496626477f6175137762244ab380045c44e0cde63	2026-08-11 14:20:32.879462+05:30	2026-09-10 14:20:32.879209+05:30	\N	\N	node
656	3	d84aa66c58fe26b54c51370f485a93836a46bbdb3369985a42c715001330c29e	2026-08-11 14:20:33.825153+05:30	2026-09-10 14:20:33.824922+05:30	\N	\N	node
657	3	3c1cdba3102a39c5d6c8267d63cc45532a2d6692e4594360811faf1f19800259	2026-08-11 14:20:34.259132+05:30	2026-09-10 14:20:34.258871+05:30	\N	\N	node
658	7	99ef9eb84bbb513e1b62e769b29b3542e40615c314399f7753d78c8387cb8f0a	2026-08-11 14:20:34.874098+05:30	2026-09-10 14:20:34.873756+05:30	\N	\N	node
659	8	ee4c38fb7bef3c542aab57d686c5bbc05078a47698fcc3dde859adbc809c6cce	2026-08-11 14:20:37.528311+05:30	2026-09-10 14:20:37.52805+05:30	\N	\N	node
660	17	4f4d7d051299167d69ead5156d75080ccbcfe48e64b286a785d68661a7ece8cf	2026-08-11 14:20:38.237973+05:30	2026-09-10 14:20:38.237743+05:30	\N	\N	node
661	230	ec1c7039c9965f7794103951f3ccee58a1e722cd4026efcb65321cd0dd4480ec	2026-08-11 14:20:39.309686+05:30	2026-09-10 14:20:39.309451+05:30	\N	\N	node
662	17	4db4a9d94549513ed52963936467110c569a7de5e0c86a2ee00944f930555686	2026-08-11 14:20:39.742305+05:30	2026-09-10 14:20:39.741958+05:30	\N	\N	node
663	230	91f70e043595c66f2edf21a198edceef2ddf56bf2b0cbeaa43109e5752878603	2026-08-11 14:20:41.230971+05:30	2026-09-10 14:20:41.230725+05:30	\N	\N	node
664	17	b87ebbc4b073143648ba5291fcd2c7a8daf801973277ced7d5b39686a3c1a4e3	2026-08-11 14:20:41.948789+05:30	2026-09-10 14:20:41.94853+05:30	\N	\N	node
665	18	90257ea0fcbe833c8bf6889d30ec67b667943b99384418f2176b731ebc64ed55	2026-08-11 14:20:42.372778+05:30	2026-09-10 14:20:42.372574+05:30	\N	\N	node
666	17	6a44110a3ba547db071c8b043eaa43710d6218c8124bc0e3417b7e325f654d2a	2026-08-11 14:20:43.443512+05:30	2026-09-10 14:20:43.443241+05:30	\N	\N	node
667	18	27de6564896778ecafd56213e4bf2dcc37962432ea40fbe967dab18df4f20f96	2026-08-11 14:20:43.897223+05:30	2026-09-10 14:20:43.896932+05:30	\N	\N	node
668	17	ca0c7aafca1db37e71b839cbbe4e01dc8cb8ecddba97fd4745fcc6a9a89a7274	2026-08-11 14:20:45.38071+05:30	2026-09-10 14:20:45.380456+05:30	\N	\N	node
669	17	70b12289a80d92c62f4b0c25464699077becdb0e95d79f2817381cbe80982585	2026-08-11 14:20:45.79826+05:30	2026-09-10 14:20:45.797983+05:30	\N	\N	node
670	18	0782cfcb511118892ab2ee8811ed3657014e3388ef42a8e662abf4ee8f751692	2026-08-11 14:20:46.440186+05:30	2026-09-10 14:20:46.439869+05:30	\N	\N	node
671	17	81223f33c9469a4eb4f32a3529c3ab828f7659cf89870a5d5704a390250ab7a3	2026-08-11 14:20:46.912683+05:30	2026-09-10 14:20:46.91242+05:30	\N	\N	node
672	18	1c71da4385d927fa39f62f1d752e981fafc4bba6dabeacaa00c6515068139419	2026-08-11 14:20:47.386588+05:30	2026-09-10 14:20:47.386376+05:30	\N	\N	node
673	232	c6d34a42312b12d597e9c0bf98677389a653a5d3e3a28f6193acca6d1a91722d	2026-08-11 14:20:48.469202+05:30	2026-09-10 14:20:48.468958+05:30	\N	\N	node
674	18	30c98e4200236da8a820804ffae176bc3303cb49fa7b2221a04cd17b45743a60	2026-08-11 14:20:48.980085+05:30	2026-09-10 14:20:48.979804+05:30	\N	\N	node
675	233	139bb48a856717012e3bd0037bd740323537dfbefb8d84396d3258dbb3714b36	2026-08-11 14:20:50.121028+05:30	2026-09-10 14:20:50.12074+05:30	\N	\N	node
676	18	d15401a6c08347d660bae0e54d7531f0caed17c79ee1a9a30d052b4e79d7de9e	2026-08-11 14:20:50.542283+05:30	2026-09-10 14:20:50.541973+05:30	\N	\N	node
677	232	5dc6ad538563442234d2e8ba976250c97274b49f4bc9c2515a6611ab4bc27a03	2026-08-11 14:20:52.116979+05:30	2026-09-10 14:20:52.116729+05:30	\N	\N	node
678	18	fa29705b045ac8607e2f4f1df8a1755a611a273bfea58e0e14da52ae01f64ad6	2026-08-11 14:20:52.520879+05:30	2026-09-10 14:20:52.520633+05:30	\N	\N	node
679	17	9647236a0862f5aa7d618729b7de48795b5678e1e0dae63653ca3ec8e04f7757	2026-08-11 14:20:53.064512+05:30	2026-09-10 14:20:53.064238+05:30	\N	\N	node
680	18	7b62a51c08d9f04343ee32f70c0ccb6c3cf8a4ca6ce36a038ac8bb8a3dbe17d5	2026-08-11 14:20:53.580867+05:30	2026-09-10 14:20:53.580613+05:30	\N	\N	node
681	1	d203fc0b4552641482039906ac952759f33a4cb97e185bafb3b101b6a138b1dc	2026-08-11 14:20:54.087192+05:30	2026-09-10 14:20:54.086922+05:30	\N	2026-08-11 14:25:54.219556+05:30	node
682	17	70f7d8bb5ff993bb57ce60f8691c589012c274ea6b92569d35f366e532693ad9	2026-08-11 14:20:54.531897+05:30	2026-09-10 14:20:54.530919+05:30	\N	\N	node
683	18	16ea4b111c0f05090584afc2b1aca139f2a60ab5b695aad27816f6bd1399324b	2026-08-11 14:20:54.948023+05:30	2026-09-10 14:20:54.947779+05:30	\N	\N	node
684	234	d4e188bc67480f9b807d48b7295471f02412125f272ebb3cbcd2a761af8339e0	2026-08-11 14:20:56.015783+05:30	2026-09-10 14:20:56.015609+05:30	\N	\N	node
685	18	5b945a904e4809377e932f7d565b28b2cbf9c873415819e3d5bc6f8c96f6064e	2026-08-11 14:20:56.407494+05:30	2026-09-10 14:20:56.407104+05:30	\N	\N	node
687	234	b26daa12a2ab9e299ba6e1c265d6e1377dc8690a47f2c6a686985a646a6c546b	2026-08-11 14:20:57.701905+05:30	2026-09-10 14:20:57.701674+05:30	\N	\N	node
688	18	1483a3f7363e9acc534a641be14864d73785423db53f6d2324a7a53f54b60d75	2026-08-11 14:20:58.141388+05:30	2026-09-10 14:20:58.140974+05:30	\N	\N	node
694	235	cd982e041eca8ccac41e124d3f2b4b2f7dcf179d534f2ebdd6a087875d23e87c	2026-08-11 14:21:02.255661+05:30	2026-09-10 14:21:02.255376+05:30	\N	\N	node
695	17	76373b8e27383c87ac6fea6c488c1979614e399638d50f03ecbcfb0baa6c9034	2026-08-11 14:21:02.730672+05:30	2026-09-10 14:21:02.730404+05:30	\N	\N	node
697	235	3814329321769169d59243be294636dcb49ec748766ade1e3a0d646315701831	2026-08-11 14:21:03.741767+05:30	2026-09-10 14:21:03.741388+05:30	\N	\N	node
698	17	ca1ad6312290d1e51bfb813622768de948c9e37161cbbee97b564a530ee6201a	2026-08-11 14:21:04.265617+05:30	2026-09-10 14:21:04.265362+05:30	\N	\N	node
702	18	4237960ca3ff47f555f4b222a7d118d0d2d4a50bd05014d94fa279550e6cd1e8	2026-08-11 14:21:07.135725+05:30	2026-09-10 14:21:07.135482+05:30	\N	\N	node
686	18	e59d0b8ed6469c25966d30a2c684fb9e074805cd5754e577e362c266ea7ba336	2026-08-11 14:20:57.056297+05:30	2026-09-10 14:20:57.055974+05:30	\N	\N	node
689	234	4e1920336752a482a8af585b2ac0fb85e27b8c456b543907f8c25955922d8f60	2026-08-11 14:20:58.644079+05:30	2026-09-10 14:20:58.643797+05:30	\N	\N	node
690	18	8e2230a439426ac985c018e16001db0f238c91bf644ad6df660d98e79b55a71d	2026-08-11 14:20:59.142224+05:30	2026-09-10 14:20:59.14201+05:30	\N	\N	node
691	18	f449bab5778597b609d4d4863959343c19b46c2ed8b5ad908f910099bedc61a1	2026-08-11 14:20:59.948612+05:30	2026-09-10 14:20:59.948314+05:30	\N	\N	node
692	17	e05df3b916abca8ad082de0b50ad8169985b038c613fb22f117a3e5649b1027b	2026-08-11 14:21:00.479976+05:30	2026-09-10 14:21:00.479738+05:30	\N	\N	node
693	17	279dba494e1bf21f66f35dadc53e098f5e7e8ac1e14bdda35b4a55eea6c53002	2026-08-11 14:21:00.930752+05:30	2026-09-10 14:21:00.930475+05:30	\N	\N	node
701	18	b0c0765e6c4c683a3f092c4322c75353b4bf1c7a739cab203032e3d81b81b548	2026-08-11 14:21:05.839508+05:30	2026-09-10 14:21:05.8393+05:30	\N	\N	node
711	17	d52b16b052246d87b66085a53f861bc3e8e8e95223bb1c25f266750feaaee46c	2026-08-11 14:21:23.821675+05:30	2026-09-10 14:21:23.8215+05:30	\N	\N	node
712	18	0d384c24e95306bfba63eed373efa2d662aacd088b46ad297e23a9f3646cc9a3	2026-08-11 14:21:24.677354+05:30	2026-09-10 14:21:24.677072+05:30	\N	\N	node
706	1	2a03d1d92fc7ece007deefcc953243617ddcf87383f4b102ac57dcaafd8497e2	2026-08-11 14:21:13.206873+05:30	2026-09-10 14:21:13.206467+05:30	\N	2026-08-11 14:25:54.219556+05:30	node
696	17	39f0840e0f8ea0536d7545f635f60898d9178f9e43c9374f4d7beda0a58c1a71	2026-08-11 14:21:03.217299+05:30	2026-09-10 14:21:03.217082+05:30	\N	\N	node
699	17	3e0168656cc35a0c97b8ed0812f83760300bdc90eeddd5af7b6d9a9ef672b6c7	2026-08-11 14:21:04.742017+05:30	2026-09-10 14:21:04.741809+05:30	\N	\N	node
700	17	c882fb1dfc6bdbfd31d136a37946544e45d9a6be795676f7cf55ac0951494010	2026-08-11 14:21:05.410782+05:30	2026-09-10 14:21:05.410513+05:30	\N	\N	node
703	17	24745c73e69e68bc28307e1ccf7e702d6b12c93c7ed4cd0b172f449eee9e2e86	2026-08-11 14:21:07.592842+05:30	2026-09-10 14:21:07.592493+05:30	\N	\N	node
704	18	af8e72d81a54b04c97f737fced1c581e9cce5e9f27498d9193673be7f99e49bc	2026-08-11 14:21:07.994946+05:30	2026-09-10 14:21:07.994703+05:30	\N	\N	node
705	17	2acfe162142359eee104bf166c67c93f70073cb44db61c8fe840ac6b589346fa	2026-08-11 14:21:09.259594+05:30	2026-09-10 14:21:09.259387+05:30	\N	\N	node
707	19	fe615dcae70ba6b027dac2815ed3785c409f9bc0cfa81c47c3350c61a4638905	2026-08-11 14:21:19.565815+05:30	2026-09-10 14:21:19.565589+05:30	\N	\N	node
708	20	325d93c48d18ee201e8b744a4af4a4f60ed8870b89e235d7261591925f742745	2026-08-11 14:21:20.62572+05:30	2026-09-10 14:21:20.625435+05:30	\N	\N	node
709	18	01a14c4b63e3133a132b37e60506562eb2a07f739a71d944771eb27418cbd684	2026-08-11 14:21:21.413934+05:30	2026-09-10 14:21:21.413722+05:30	\N	\N	node
710	18	0d712aeb81ffd16d911cff973f98fe426af291651b08ea46cac139d67bd74d74	2026-08-11 14:21:22.982105+05:30	2026-09-10 14:21:22.981881+05:30	\N	\N	node
713	18	4f0519b5982960854593e119a9a44789eab901991ce2a9a36178ebdeeaec2291	2026-08-11 14:21:25.452711+05:30	2026-09-10 14:21:25.452532+05:30	\N	\N	node
714	18	0d4c7913d6341f95f06436308172db725b6201a5e772565da6bd3f87c13c541f	2026-08-11 14:21:26.269488+05:30	2026-09-10 14:21:26.269273+05:30	\N	\N	node
715	17	58d8650023968e88fb21a58b1b52c17b043d706c42b6d5b2c0994949eb12d520	2026-08-11 14:21:26.884623+05:30	2026-09-10 14:21:26.884394+05:30	\N	\N	node
716	18	8844d6e80a762a7f8c1d06dbade70406f39abf84e0fa5330a3eeac032d7eb2bf	2026-08-11 14:21:27.409666+05:30	2026-09-10 14:21:27.409464+05:30	\N	\N	node
717	18	b4734257814082c20acb0abc965fd17944c805cc4bee89d6bdc48142a045a29b	2026-08-11 14:21:27.931155+05:30	2026-09-10 14:21:27.930868+05:30	\N	\N	node
718	19	c27e15855ebac4255784d917778eb048fb30ac83cd2a4a2c8f85107d4d299e16	2026-08-11 14:21:28.601826+05:30	2026-09-10 14:21:28.601509+05:30	\N	\N	node
719	18	5660402b85795bb20a9f1774a7fb3bc620712b7c4b9f65f81742fa1f7c57c526	2026-08-11 14:21:29.127846+05:30	2026-09-10 14:21:29.127674+05:30	\N	\N	node
720	17	efad71637537686d948a9f3b72b7277a239ea0302d06c27341ec2830cf8a0b0e	2026-08-11 14:21:29.722735+05:30	2026-09-10 14:21:29.722461+05:30	\N	\N	node
721	17	cad44a0ce9962f5bb0e319d7dc4b6f6c2886ca0f045367fe859f0d65d2b6cde2	2026-08-11 14:21:30.171236+05:30	2026-09-10 14:21:30.171+05:30	\N	\N	node
722	18	886284461228ee3662070b3edaf87719101bdd15213b01c121730c2f7ec8f28c	2026-08-11 14:21:34.15509+05:30	2026-09-10 14:21:34.154869+05:30	\N	\N	node
723	19	5ec221d1530eadc1c4f66367a94e00c37ff4015614ad3c4313a621ea8a7e4e0d	2026-08-11 14:21:38.066306+05:30	2026-09-10 14:21:38.066063+05:30	\N	\N	node
724	20	14b04b1b55ab7e5157ddf183cbc0b93dd8c19f74f856da81778e8abbaafc634e	2026-08-11 14:21:39.912113+05:30	2026-09-10 14:21:39.911927+05:30	\N	\N	node
725	17	cf243419ba106c4222d33de19783c59e582d04db56ad7f78033a02ed53c5a8a0	2026-08-11 14:21:41.818367+05:30	2026-09-10 14:21:41.818143+05:30	\N	\N	node
726	19	32c762162597e5df878aac4b892d69aa8a5d88f1894750cd90795e26300eea15	2026-08-11 14:21:42.21089+05:30	2026-09-10 14:21:42.210708+05:30	\N	\N	node
727	20	c613a79a6878dcdfb46e3630552368504833f3e063eb508a41aacccc3b56ad08	2026-08-11 14:21:42.62274+05:30	2026-09-10 14:21:42.622531+05:30	\N	\N	node
728	17	569b9046368e0bc949a88b3ceaafd3dba0f433f1e8808c5cbf61a0843508f7ba	2026-08-11 14:21:43.07946+05:30	2026-09-10 14:21:43.079257+05:30	\N	\N	node
729	18	3346f0852e2010ba1afc473a74bb856756c96a562f1ddaa7cc601ecbd0a031f7	2026-08-11 14:21:43.616341+05:30	2026-09-10 14:21:43.616042+05:30	\N	\N	node
730	19	df6b9100126f956b6708e060af9a47a6d20931983ed9376f4b366eec481b00bb	2026-08-11 14:21:44.446289+05:30	2026-09-10 14:21:44.445863+05:30	\N	\N	node
731	20	1603d7e318f3eeacd2b049c8857da11a6a0178e01ae9afccb6253935725c7a64	2026-08-11 14:21:45.045571+05:30	2026-09-10 14:21:45.045347+05:30	\N	\N	node
732	19	8272ab630592282682df81617102364bb648628793a051c2176af34cc2b518a7	2026-08-11 14:21:45.578559+05:30	2026-09-10 14:21:45.578333+05:30	\N	\N	node
735	1	9f662c97ab13662abaf8e22889a016384a522a0c83aa0106b3193a0c436d7523	2026-08-11 14:25:50.486192+05:30	2026-09-10 14:25:50.486+05:30	2026-08-11 14:25:51.090362+05:30	2026-08-11 14:25:51.090362+05:30	node
737	1	e45827db204a315a7991e226e9c0504247d825fccb2aed2eb24e215371f24b02	2026-08-11 14:25:51.600885+05:30	2026-09-10 14:25:51.600624+05:30	2026-08-11 14:25:51.971826+05:30	2026-08-11 14:25:51.971826+05:30	node
738	1	e3e8f657414f839ba886bd4f3a7fef0e2cc45898b913de8b4b985a582b1efe8a	2026-08-11 14:25:51.963347+05:30	2026-09-10 14:25:51.963097+05:30	2026-08-11 14:25:51.982078+05:30	2026-08-11 14:25:51.982078+05:30	node
741	2	e68a3e02e8950d5921b44b92905efd6f6863cf8b19a194e8039844e3ae5688fb	2026-08-11 14:25:52.636472+05:30	2026-09-10 14:25:52.636245+05:30	\N	\N	node
733	1	da1c7775b9e9df8e8e3200e51f31b4a3f3041bb85b9627ee75f09627dd371460	2026-08-11 14:22:16.393532+05:30	2026-09-10 14:22:16.393288+05:30	\N	2026-08-11 14:25:54.219556+05:30	curl/8.14.1
734	1	d93291fed11d24b3639f508aab91de49e67aaa8032425002932f4e40ffce429c	2026-08-11 14:25:20.712414+05:30	2026-09-10 14:25:20.711923+05:30	\N	2026-08-11 14:25:54.219556+05:30	curl/8.14.1
736	1	81088e88c8130c9ed51050dd8acfa363fff09602662a2d5652a3327663e0b020	2026-08-11 14:25:51.185552+05:30	2026-09-10 14:25:51.185363+05:30	\N	2026-08-11 14:25:54.219556+05:30	node
739	1	2622594983b8a359e4766d1e6444ed00f05561d3e982274d4fc5fc8f819f2ee2	2026-08-11 14:25:51.974051+05:30	2026-09-10 14:25:51.973838+05:30	\N	2026-08-11 14:25:54.219556+05:30	node
740	1	75cb9f85551bdef0541e2e24816465b1c89595ca0c0fac309b9bbdb739cccac9	2026-08-11 14:25:51.984251+05:30	2026-09-10 14:25:51.984094+05:30	\N	2026-08-11 14:25:54.219556+05:30	node
742	1	2f4cb50a87f0ad2ffae7cced4cbe962e53bd63b9e22fcc78db46869482f3c7cd	2026-08-11 14:25:53.697481+05:30	2026-09-10 14:25:53.697141+05:30	\N	2026-08-11 14:25:54.219556+05:30	node
743	1	fc8da878765b84cc30896d92913024cf6acb7edd1fec62603417f7ad28bed667	2026-08-11 14:25:54.212728+05:30	2026-09-10 14:25:54.212424+05:30	\N	2026-08-11 14:25:54.219556+05:30	node
744	5	d50d8cb7a32f776fa0543f2d24a95c79adcfef5927de5cbeb6a9b329ed7b4752	2026-08-11 14:26:28.148121+05:30	2026-09-10 14:26:28.147796+05:30	\N	\N	node
745	3	858d07a4126acd17490cd0450ad9e1a00645d00e88b32acd462dd59878cbf852	2026-08-11 14:26:28.806472+05:30	2026-09-10 14:26:28.806255+05:30	\N	\N	node
746	3	a27225a0ce0341e5af53b4a01c3a8778da46b75e15207bfe50b5e93fcd35c9d6	2026-08-11 14:26:29.331635+05:30	2026-09-10 14:26:29.331418+05:30	\N	\N	node
747	7	39e3190a105ffeef3a679b18c6fef5aad9d743d9c797f4d5b4d7de6fff622581	2026-08-11 14:26:29.994584+05:30	2026-09-10 14:26:29.994234+05:30	\N	\N	node
748	8	ec0d09c6228be0f1295eea9736103da4b252e66ec7578eb0b382d674e5b64ab1	2026-08-11 14:26:32.451908+05:30	2026-09-10 14:26:32.451663+05:30	\N	\N	node
749	17	c5050c5a14355f336e979d4b00257bdb149f8f3ba796a79626b9f4ddcd1b91d6	2026-08-11 14:26:32.962287+05:30	2026-09-10 14:26:32.961692+05:30	\N	\N	node
750	236	9ae71d6bd36c78934584258be7b3686c9e63f7a734bec770544eb02324390af1	2026-08-11 14:26:33.900301+05:30	2026-09-10 14:26:33.900099+05:30	\N	\N	node
751	17	6e0a8817134384d51b9c32b52f6f774c9d9f1a5e039e4350465bfd3348cea7ea	2026-08-11 14:26:34.266145+05:30	2026-09-10 14:26:34.265957+05:30	\N	\N	node
764	239	d232bc741923cd913adabe3dbc74e67640204f60d4de5174e1aea7fcf22f1261	2026-08-11 14:26:44.409172+05:30	2026-09-10 14:26:44.408877+05:30	\N	\N	node
765	18	fc9d2f66454700bd4b453346a990173c095baa0080d410f3902712bf3d19dbb7	2026-08-11 14:26:44.841146+05:30	2026-09-10 14:26:44.840879+05:30	\N	\N	node
773	240	2ad9b900f23c0acbd62311ed900fa80bcc5a522e444f1e1fc5e7b8e5e620781d	2026-08-11 14:26:50.006231+05:30	2026-09-10 14:26:50.005991+05:30	\N	\N	node
774	18	5c76ee0a27a20a017d02e6a06c2f6dce0b1da8ec60d49a280f9310cf1cbd1e65	2026-08-11 14:26:50.367271+05:30	2026-09-10 14:26:50.367022+05:30	\N	\N	node
780	18	36fc2f0f978347718bb3166718abfdc7e6f5895877560fcafc83e214d11f5b27	2026-08-11 14:26:53.387989+05:30	2026-09-10 14:26:53.387811+05:30	\N	\N	node
781	17	90a498acbd6e2d8bca7d0493961e0a23f77357ab752a2fff9e37349210ea241f	2026-08-11 14:26:53.801937+05:30	2026-09-10 14:26:53.801687+05:30	\N	\N	node
782	17	b9b43feb88249111ab8745effd5ae9e4f6192eeb52ac7d2de9395a7ba6ee5aea	2026-08-11 14:26:54.261026+05:30	2026-09-10 14:26:54.260786+05:30	\N	\N	node
783	241	6f793993785df678167f9d67474b31abb33f7cba391b619c1557375c1093f5a2	2026-08-11 14:26:55.408766+05:30	2026-09-10 14:26:55.408546+05:30	\N	\N	node
784	17	f43969561d568991f17a4ff241b461319cb771c299544f9b6e2c574d0d146b1d	2026-08-11 14:26:55.798938+05:30	2026-09-10 14:26:55.798655+05:30	\N	\N	node
788	17	eb856c0d393ac4a8a7113a2610d4fb03c1a7df9a44b608b8e1c3543d07b018b5	2026-08-11 14:26:57.584649+05:30	2026-09-10 14:26:57.58441+05:30	\N	\N	node
789	17	fff46ab964aa95fea8a4029d7192e1533219e7d74f2a44f5063877701ad8ec67	2026-08-11 14:26:58.103355+05:30	2026-09-10 14:26:58.103071+05:30	\N	\N	node
792	17	f40bc028d3e09d4eaa55e6331b938917938c8ab6391df121d6a33d9cb1ee6bba	2026-08-11 14:27:00.221779+05:30	2026-09-10 14:27:00.221513+05:30	\N	\N	node
793	18	cf94eb112d75f989645c2f82c6e894b4272b8ddd2fb7f8547ba18d20a9c70277	2026-08-11 14:27:00.713071+05:30	2026-09-10 14:27:00.712667+05:30	\N	\N	node
794	17	0449b0f531d12e689ef92f374509ac9134426e551e727796b827ed52e37871cb	2026-08-11 14:27:01.536024+05:30	2026-09-10 14:27:01.53577+05:30	\N	\N	node
803	18	0877421dd3c62a5107389513a49b25fdc2c3659ec711adf23941a3577ae97a94	2026-08-11 14:27:26.394093+05:30	2026-09-10 14:27:26.393806+05:30	\N	\N	node
817	17	2efaa06fb67c10fad225af148170776e2298c1920b786b8aec0c34bde9e8a5c1	2026-08-11 14:27:42.776117+05:30	2026-09-10 14:27:42.775834+05:30	\N	\N	node
836	17	a0021f0494b3a0faec338694bceb9a863b0870e6b4e3d103096aa76ca55ee770	2026-08-11 14:28:21.707104+05:30	2026-09-10 14:28:21.706819+05:30	\N	\N	node
770	1	1943c7567112897b1ad5092d0ce56874844623390a12b394397d381291caf752	2026-08-11 14:26:48.105167+05:30	2026-09-10 14:26:48.104894+05:30	\N	2026-08-11 14:31:10.176426+05:30	node
752	236	6c0a67c2216ad064edff0a4e3d3dfe82bc5a65ca930685007d4960b6868643f3	2026-08-11 14:26:35.603603+05:30	2026-09-10 14:26:35.603361+05:30	\N	\N	node
753	17	7e20d56f7c85e805fb35cdd41350b363b498a6b74266bdc6f32403af6e96a306	2026-08-11 14:26:35.991666+05:30	2026-09-10 14:26:35.991403+05:30	\N	\N	node
754	18	0ebe866adc1054b5c1d8e3f7b6b6819eae4c2acf418abb34d5b2bc3771d8dbce	2026-08-11 14:26:36.444861+05:30	2026-09-10 14:26:36.444517+05:30	\N	\N	node
755	17	f67e21dbb98baa963afc6bf0f38e753c7aab40988933bbd3d9cdf6ffd36b3ef3	2026-08-11 14:26:37.374398+05:30	2026-09-10 14:26:37.374148+05:30	\N	\N	node
756	18	02b9969d34ba7e9ee24a7df8547984a9f89e0b1f2e27ce97322d9d3a1a5be732	2026-08-11 14:26:37.757435+05:30	2026-09-10 14:26:37.757163+05:30	\N	\N	node
757	17	5a5d64bd9ca72eeaeefcafa3123145fb8203a6243b4bac48e3aa314838a980a6	2026-08-11 14:26:39.64499+05:30	2026-09-10 14:26:39.644693+05:30	\N	\N	node
758	17	3b0664d12c55239a63205ff4dbc2b902b2e8ce4aecfa81582848f09648911aa6	2026-08-11 14:26:40.103072+05:30	2026-09-10 14:26:40.102697+05:30	\N	\N	node
759	18	49ccdacd8197cac064bb9a10dd5c21e6b4880b7eef52a3deff64f6ad54a29d8c	2026-08-11 14:26:40.799546+05:30	2026-09-10 14:26:40.799253+05:30	\N	\N	node
760	17	32f62033684004e3a0cbfd3346bd0647cdeff960049a89c478fe8346a2658b8b	2026-08-11 14:26:41.226263+05:30	2026-09-10 14:26:41.225953+05:30	\N	\N	node
762	238	777c1abdd5f28de947d9f7955eb21122b2cf39f74a7832a3262bf20489f9bc65	2026-08-11 14:26:42.718389+05:30	2026-09-10 14:26:42.718143+05:30	\N	\N	node
763	18	bbdcf2206f934d7b921970b21351031af673a2722f33edbee24227d61ad9b5ca	2026-08-11 14:26:43.120983+05:30	2026-09-10 14:26:43.120758+05:30	\N	\N	node
766	238	5962832ed12ec10072cc8ed1d9602ee7404c04f36a390796d7a3b5133258f312	2026-08-11 14:26:46.316141+05:30	2026-09-10 14:26:46.315919+05:30	\N	\N	node
767	18	2b9e84ea2042a0aee12d8504252f2704714ca66a0e70ec8239f08e9b7612e256	2026-08-11 14:26:46.698982+05:30	2026-09-10 14:26:46.698719+05:30	\N	\N	node
768	17	4625f4333d695793127b9fb1945200032d6af3b2f0e6081e8b55ae4141ec05e1	2026-08-11 14:26:47.203346+05:30	2026-09-10 14:26:47.203091+05:30	\N	\N	node
769	18	331b5a363ab9f8898f5d59fca21b20552d11f4673bc01789505ed43b13aa00f6	2026-08-11 14:26:47.645816+05:30	2026-09-10 14:26:47.645508+05:30	\N	\N	node
771	17	f4e98357822c649d4bb9826c14def79866290a9a4adcd48675fc39e56b5aa440	2026-08-11 14:26:48.548573+05:30	2026-09-10 14:26:48.547881+05:30	\N	\N	node
772	18	e8ab03e113845042038162874a72ea44ef956889597124670cec90255270da39	2026-08-11 14:26:48.986816+05:30	2026-09-10 14:26:48.986286+05:30	\N	\N	node
775	18	33a749dc5c42a74ed83c9eb9f3631617e67bf0feb32519a6cc73e17ce21bd06d	2026-08-11 14:26:50.982448+05:30	2026-09-10 14:26:50.982192+05:30	\N	\N	node
776	240	17d25d8c45de91fb3a0b6d3c5ec0f6eedcc1164063278ff1f7b650b1d9582684	2026-08-11 14:26:51.509411+05:30	2026-09-10 14:26:51.509176+05:30	\N	\N	node
777	18	67f5a5981aa7696984b96796e2f8d1a8ff2aa5a29ddef91bdc085aa7d8f292ac	2026-08-11 14:26:51.8819+05:30	2026-09-10 14:26:51.881648+05:30	\N	\N	node
778	240	0e884742915f98606e906c463c5dd6598f23782268591beea535d26428072bed	2026-08-11 14:26:52.389099+05:30	2026-09-10 14:26:52.388848+05:30	\N	\N	node
779	18	70b06db7a90232820724b2c79bbcda9f2a1bf5269d7372da66fa22c1f6774595	2026-08-11 14:26:52.762737+05:30	2026-09-10 14:26:52.762367+05:30	\N	\N	node
785	17	37fde32e9bc3a6562fc28a0ae4931b7fa913f55affca384f97dbddb403154602	2026-08-11 14:26:56.205514+05:30	2026-09-10 14:26:56.205242+05:30	\N	\N	node
786	241	de909bf6fe9a1fb699616c05a3137b211db81d428c977069d66b127a6bbedd4b	2026-08-11 14:26:56.67571+05:30	2026-09-10 14:26:56.675453+05:30	\N	\N	node
787	17	dc50362f84c21f20c86b9bb5932eacca12509ddc051bf9694ac876207620efb6	2026-08-11 14:26:57.137201+05:30	2026-09-10 14:26:57.136961+05:30	\N	\N	node
791	18	e419e83421569728ac5363bb7601311129ff4608284d8140b3dcf390dcc21323	2026-08-11 14:26:59.745944+05:30	2026-09-10 14:26:59.745621+05:30	\N	\N	node
797	20	c1530022aad9958bd4f4097bdcc5d27288c4c168ef03e84472ed2982251902db	2026-08-11 14:27:21.104878+05:30	2026-09-10 14:27:21.104668+05:30	\N	\N	node
808	18	a1ac124c57b6e9d458bc2a36f950ad723847d0088aaed6cc51e741b8ff59650e	2026-08-11 14:27:28.916594+05:30	2026-09-10 14:27:28.916362+05:30	\N	\N	node
825	18	2d731aa0a91e86de00a2990bbfd3bffda40c50a64984211a68018560935473b9	2026-08-11 14:28:15.457597+05:30	2026-09-10 14:28:15.457405+05:30	\N	\N	node
837	18	3271d8f13a2a10199e61e22e3e6834336b0ae1a32b8d3e38ddedc154c8a9e2af	2026-08-11 14:28:25.647777+05:30	2026-09-10 14:28:25.64745+05:30	\N	\N	node
761	18	f67089c3b86247c0b81424c19de21b9e805201249e89d29e8204fdaeaee1db3b	2026-08-11 14:26:41.652774+05:30	2026-09-10 14:26:41.652502+05:30	\N	\N	node
790	18	99f28eaf167e94ce519a916f841ddc48dd39f6bc4f44f0a77fa17ab90460a3d0	2026-08-11 14:26:58.516339+05:30	2026-09-10 14:26:58.516117+05:30	\N	\N	node
796	19	cf0043e96f5dc604c2d71b2ea680a79aa9a522c8b5786767e657555664c8f07e	2026-08-11 14:27:12.113383+05:30	2026-09-10 14:27:12.113045+05:30	\N	\N	node
798	18	cf2775da66cb056edb75ffec13404e8ffc543860a8225344cb3aed6daa6a4593	2026-08-11 14:27:21.860032+05:30	2026-09-10 14:27:21.859856+05:30	\N	\N	node
799	18	08f9f0fcae5e08a112d2b95014fb21f7ca86af1a8a3f396ec66ec132af692314	2026-08-11 14:27:23.234592+05:30	2026-09-10 14:27:23.234362+05:30	\N	\N	node
800	17	b0eb6b7ee0ab1df6840448adce8b149f3b8cbaaf70974c8d5bd100858dd623e6	2026-08-11 14:27:23.994355+05:30	2026-09-10 14:27:23.994095+05:30	\N	\N	node
801	18	db323ec800ca6afe0e1b0e06b00181778062c942b7024bc373e1195ab560e557	2026-08-11 14:27:24.820975+05:30	2026-09-10 14:27:24.820765+05:30	\N	\N	node
802	18	78e62d431b6b1ef4a71d19d38a43781c1451ca20804b7c55f5d33c301a3e199d	2026-08-11 14:27:25.524544+05:30	2026-09-10 14:27:25.524303+05:30	\N	\N	node
804	17	492230ea14c7cf72d07fdfb8d56aa189e3426c1c0f3e0d8719d56798aec489cc	2026-08-11 14:27:26.97195+05:30	2026-09-10 14:27:26.971782+05:30	\N	\N	node
805	18	5cc27dea35207b28f272a17a28ee8533347d951167db70fa5798bd67c9439260	2026-08-11 14:27:27.438302+05:30	2026-09-10 14:27:27.438135+05:30	\N	\N	node
806	18	7a4f9da1d0187137b04ee7ecf428b255627db3f3524e12ce416f70cad00aa416	2026-08-11 14:27:27.892449+05:30	2026-09-10 14:27:27.892154+05:30	\N	\N	node
807	19	c62b1797a6f4e01696b54900a0b552b0582049ff02b0756724423e6ab153f5e3	2026-08-11 14:27:28.460733+05:30	2026-09-10 14:27:28.460507+05:30	\N	\N	node
809	17	131c8890af9b39c1890d3d3c716849d8fedbc40ab5fee28d7740edb283eaea93	2026-08-11 14:27:29.449933+05:30	2026-09-10 14:27:29.449692+05:30	\N	\N	node
810	17	6812300e38dcf0c5802160d9a4b0869b2b3dc297b8f73e8effc97ba6854065a4	2026-08-11 14:27:29.890512+05:30	2026-09-10 14:27:29.890328+05:30	\N	\N	node
811	18	093463e470ae99a3d3d9d2afda38eabbd4f120a3942e77ed99e67dbd986017e5	2026-08-11 14:27:33.86084+05:30	2026-09-10 14:27:33.860601+05:30	\N	\N	node
812	19	514459aba2320c7753d79013ede5c42fbb5d4ceb53dda290fc4e0c6993fc9858	2026-08-11 14:27:37.782573+05:30	2026-09-10 14:27:37.78231+05:30	\N	\N	node
813	20	b8469cf45234626024c3771fa391f50374bd26ce909a5f26e54b7c44a49a4729	2026-08-11 14:27:39.631599+05:30	2026-09-10 14:27:39.631234+05:30	\N	\N	node
814	17	58d1e345de207ca5708f4c63287c10e0fd67d225df652362041cdb17f9a87c8d	2026-08-11 14:27:41.482603+05:30	2026-09-10 14:27:41.482218+05:30	\N	\N	node
815	19	e856a301e010841b11d3049d1c4bb2da8156e0254ff1f0598b4db894665ed819	2026-08-11 14:27:41.930005+05:30	2026-09-10 14:27:41.929562+05:30	\N	\N	node
816	20	889d40f3409c6fb8362102048eac389e70d4328636f5313ef9cdf8a23e9f57a5	2026-08-11 14:27:42.337656+05:30	2026-09-10 14:27:42.337438+05:30	\N	\N	node
818	18	2a4a77e7403707a9f781f7774a9c6f832475bbba002b2ecf502d59d4b4005432	2026-08-11 14:27:43.14634+05:30	2026-09-10 14:27:43.145979+05:30	\N	\N	node
819	19	0002b48252efee101e0379705cb9859c7799ea14e475b0f41985896669516bb1	2026-08-11 14:27:43.8787+05:30	2026-09-10 14:27:43.87845+05:30	\N	\N	node
820	20	bf5cc63c1fe6c12cfff7116da2b363beee0ab6a9085b40cef1159e3da3416642	2026-08-11 14:27:44.589517+05:30	2026-09-10 14:27:44.589277+05:30	\N	\N	node
821	19	29027f2a9c2358fc70bccd810b2026a91e384ede01d4f0c51def32871d411044	2026-08-11 14:27:45.053384+05:30	2026-09-10 14:27:45.053179+05:30	\N	\N	node
822	19	f66e263110e025d1e013da7d3672d63265b8c16401af131ff6746651bfb95a17	2026-08-11 14:28:04.414719+05:30	2026-09-10 14:28:04.41425+05:30	\N	\N	node
823	20	7bb17c3227c1b177417a01ba25aef7025d9d94d4a22ecfe4a42bedb9acb53ce8	2026-08-11 14:28:13.286429+05:30	2026-09-10 14:28:13.28618+05:30	\N	\N	node
824	18	1eee844023a4c95eae83e32733c6128e113b6bf2423dea3ac734434c57c9d408	2026-08-11 14:28:13.983127+05:30	2026-09-10 14:28:13.982906+05:30	\N	\N	node
826	17	3b7459112d8949468dd918ce7c54f775aae3cae8a7620e92d8388c826bb26dcd	2026-08-11 14:28:16.160479+05:30	2026-09-10 14:28:16.160314+05:30	\N	\N	node
827	18	2b8ec26566a6831cf0802c37bac7dc803ac230cd0ac3152802f50ad3dc8aeb3d	2026-08-11 14:28:16.96422+05:30	2026-09-10 14:28:16.963752+05:30	\N	\N	node
828	18	00246013075b4a5922af8dd5a66caf7a42350cf717dfe5125b5d9777e20c2903	2026-08-11 14:28:17.683379+05:30	2026-09-10 14:28:17.683172+05:30	\N	\N	node
829	18	df6ddeabe1404d6a4fd7b6cf0e662d9293c8ac0b4697c3e0c072fa0aa12d223e	2026-08-11 14:28:18.417223+05:30	2026-09-10 14:28:18.417027+05:30	\N	\N	node
830	17	2e4c568dfcfdafacb0b132441b51bfbca308898c8ec830766b3dc3bad8507ac2	2026-08-11 14:28:18.948268+05:30	2026-09-10 14:28:18.947946+05:30	\N	\N	node
831	18	b88ab61dafbd3360a8a49340729c3aeff3365e67fe356ee2b5943bf687142b27	2026-08-11 14:28:19.390411+05:30	2026-09-10 14:28:19.390223+05:30	\N	\N	node
832	18	d02a1f6e67c95544e8d2e92c354f4eab8abd2ad808562e7ae617f082738fc70d	2026-08-11 14:28:19.8794+05:30	2026-09-10 14:28:19.879008+05:30	\N	\N	node
833	19	a326eb07ebad18842801f7b0568b63609e4831d655a765a13e7a4e9304283a7f	2026-08-11 14:28:20.389211+05:30	2026-09-10 14:28:20.38891+05:30	\N	\N	node
834	18	68fd55199198c0efc454fbfacae69c3485118de5db518307b3e1a44fb8337d1a	2026-08-11 14:28:20.801506+05:30	2026-09-10 14:28:20.801331+05:30	\N	\N	node
835	17	b4cfcf0cc0e9a04a0b4cd042c82fa41c189ea5b2e4355516b68a8f589ec64be8	2026-08-11 14:28:21.270054+05:30	2026-09-10 14:28:21.269842+05:30	\N	\N	node
838	19	21a99ce3601869c1dd9f9600924974fa53447f6e4f0d0feb5cdf4404f4a69950	2026-08-11 14:28:29.446591+05:30	2026-09-10 14:28:29.446205+05:30	\N	\N	node
839	20	28daae29868275609bbd9409cb3f71b105a81738e295eae4ffba94ad16b115ff	2026-08-11 14:28:31.249111+05:30	2026-09-10 14:28:31.248761+05:30	\N	\N	node
840	17	e57806d083d2897e19d4b8f5bef76b0d0fe56653da2349ba1c4acd67bb3a7309	2026-08-11 14:28:33.019167+05:30	2026-09-10 14:28:33.018996+05:30	\N	\N	node
841	19	4b29b710fce738a9dacc1e6c6bcb739f429311e42450ab7e52e63985f94dfc3b	2026-08-11 14:28:33.357954+05:30	2026-09-10 14:28:33.357621+05:30	\N	\N	node
842	20	367a7b106ec4e163a10b0c70783c04a0c8c3f8db28705e0cbf5b55661bb9b777	2026-08-11 14:28:33.783549+05:30	2026-09-10 14:28:33.783268+05:30	\N	\N	node
843	17	2a22b450c1d7ebcb68ab3e986d2224db19cff7ff3ceed82368a5f0f5428bc27d	2026-08-11 14:28:34.220366+05:30	2026-09-10 14:28:34.220121+05:30	\N	\N	node
844	18	794ace89dd6f7a29152fff47507a5ffa276fac68d1bc178fcb086a6f08e8da0a	2026-08-11 14:28:34.576517+05:30	2026-09-10 14:28:34.576267+05:30	\N	\N	node
845	19	ca95c5d85273fb34adbebee0ca2a36aabc722cc93291d70875cccd3f8be93164	2026-08-11 14:28:35.316043+05:30	2026-09-10 14:28:35.315742+05:30	\N	\N	node
846	20	518697c852dd0360c0181fcc4c656bd772fac394e70585016fb4196adf523c03	2026-08-11 14:28:35.890957+05:30	2026-09-10 14:28:35.890769+05:30	\N	\N	node
847	19	5549f577ce61a9bb48f82ad6aba031f08756671e6619131c3c353350c0af339d	2026-08-11 14:28:36.415173+05:30	2026-09-10 14:28:36.414762+05:30	\N	\N	node
848	19	80ba38e7f7afec0cc43fc64a69e9eaeb8da61bad86b9de2ffca4f16ff45d8c40	2026-08-11 14:28:39.299708+05:30	2026-09-10 14:28:39.299438+05:30	\N	\N	node
849	20	4525c9aa1df6d3b3699463b1e5bfdc92abc630f4ce62ddf5cc24dc1040bad7f5	2026-08-11 14:28:40.134068+05:30	2026-09-10 14:28:40.133796+05:30	\N	\N	node
850	18	73d1047e48cffc9efd690c42ea27baba3872d135a60976786a211a2a7c01f44c	2026-08-11 14:28:40.879237+05:30	2026-09-10 14:28:40.878949+05:30	\N	\N	node
851	18	18794183d72c0c8b79f327f8ff5a934c435de2b890758811aa784e406be02352	2026-08-11 14:28:42.228025+05:30	2026-09-10 14:28:42.227719+05:30	\N	\N	node
852	17	fbdb3c7cc93a196e2ef0ac1fe13f7aef4077e3f6dfe482c86b01ff017bfc331c	2026-08-11 14:28:42.971714+05:30	2026-09-10 14:28:42.971445+05:30	\N	\N	node
853	18	87b85444e2e1807e6222aabd28cb63e06e63610cd7c0124b66889d33b5fe9e0f	2026-08-11 14:28:43.764249+05:30	2026-09-10 14:28:43.76385+05:30	\N	\N	node
854	18	9438587d10c496d0c817c32b2cd05566c625f0c3408db30f977082bfe0839f9d	2026-08-11 14:28:44.532938+05:30	2026-09-10 14:28:44.532616+05:30	\N	\N	node
855	18	e02083a7e27b8c1b538bdd09f948ab247796d326fd74b2e8a441643ddf882663	2026-08-11 14:28:45.208414+05:30	2026-09-10 14:28:45.20823+05:30	\N	\N	node
856	17	6a81d00987e33c3debb52b55b6f1be45f4ac6422a863e7a6551a4fc0f787bafb	2026-08-11 14:28:45.799542+05:30	2026-09-10 14:28:45.799276+05:30	\N	\N	node
857	18	5d70092ffd55c86182af75ceb4b86d864e5fc0049afe0d276471029e5604080c	2026-08-11 14:28:46.256375+05:30	2026-09-10 14:28:46.256197+05:30	\N	\N	node
858	18	0ad333d406cbe0dd9fb2d78b1a6508592bae675ca105fa77720da3f7d686c14f	2026-08-11 14:28:46.731328+05:30	2026-09-10 14:28:46.730899+05:30	\N	\N	node
862	17	52dc370af1216a60c0bc903c2f167b4ead4f0a958ec5e4fc649a31a8eff297c4	2026-08-11 14:28:48.562193+05:30	2026-09-10 14:28:48.561992+05:30	\N	\N	node
867	19	ec8453f913070e6d6bce01bfc90d72a087d16b7adefaf73d1311b519a8029706	2026-08-11 14:29:00.293259+05:30	2026-09-10 14:29:00.293093+05:30	\N	\N	node
912	18	74dba1bc298b73c2ffb30318129611a3ea2fd94ec36a9e7a724961fbfba19ca6	2026-08-11 14:30:00.960667+05:30	2026-09-10 14:30:00.960385+05:30	\N	\N	node
920	20	bf4e4a8f65e6fe37863998d3d11e16173f646c8fd1d629ebdaf89435c9c63a8d	2026-08-11 14:30:14.413041+05:30	2026-09-10 14:30:14.412854+05:30	\N	\N	node
936	18	47b7044b899211cae911d4785bfe622db9f96ce3fcdf0ca305c1a6248ae122d8	2026-08-11 14:30:26.968111+05:30	2026-09-10 14:30:26.967859+05:30	\N	\N	node
950	20	2718167741e55117a978766f271fa2fc83b57a8c95eefc95e4c170c1ad219b8a	2026-08-11 14:30:42.759505+05:30	2026-09-10 14:30:42.759334+05:30	\N	\N	node
955	1	e6d32a61df6f4a8231ab7902aa9b7e800e1390edbf4030d9de49301a1a1fdab2	2026-08-11 14:31:08.043348+05:30	2026-09-10 14:31:08.043185+05:30	2026-08-11 14:31:08.063706+05:30	2026-08-11 14:31:08.063706+05:30	node
959	1	d4c7dbae0b337c9df7ebb29f881bba7f8db93c9cc043eefd21f793afffc80686	2026-08-11 14:31:09.700238+05:30	2026-09-10 14:31:09.700001+05:30	\N	2026-08-11 14:31:10.176426+05:30	node
967	242	f2262707abf6a683cd328f9fa2c52a42df43e4a2c52c96f32b9c9b943ebe9fcc	2026-08-11 14:31:16.30409+05:30	2026-09-10 14:31:16.303894+05:30	\N	\N	node
972	17	027a822e1d781d0b6b9c10b7c5bf020397dcfa90e291a79f9e5bd45938685248	2026-08-11 14:31:19.534684+05:30	2026-09-10 14:31:19.534515+05:30	\N	\N	node
859	19	d5dae4a4c0a9f449ae5d6fba7ac48b75319983d1f7bc82beac31430c28cf3781	2026-08-11 14:28:47.222917+05:30	2026-09-10 14:28:47.222668+05:30	\N	\N	node
865	20	5b534567bff0f001074d6d60d581abcf0010bcee1b21e687d8f89a7af7df26f7	2026-08-11 14:28:58.051921+05:30	2026-09-10 14:28:58.051553+05:30	\N	\N	node
874	19	8dbc3aa8e12e810ba2a93e30e73f798328d22f85e8c5e2fe225a07b633380f6a	2026-08-11 14:29:26.285746+05:30	2026-09-10 14:29:26.285515+05:30	\N	\N	node
884	18	c2fe535a715d11588fb002c72200caed7c550ebc102c0ae350cd067554de8207	2026-08-11 14:29:33.450948+05:30	2026-09-10 14:29:33.450723+05:30	\N	\N	node
898	20	23cd613b213e9412d32a6397d5f557836fc6fb22bc8d2afc497e46e355a0ba7f	2026-08-11 14:29:49.396134+05:30	2026-09-10 14:29:49.395938+05:30	\N	\N	node
906	18	69d1c26a470801cf7d126dd97323ec4cddda5d75efe7fc5ed0cbb4bdf6aeabb8	2026-08-11 14:29:57.773298+05:30	2026-09-10 14:29:57.773081+05:30	\N	\N	node
913	17	1907719ea6687f32435beb4003c92bb111c5a48c2355de81a5774f36ec50a103	2026-08-11 14:30:01.550062+05:30	2026-09-10 14:30:01.549691+05:30	\N	\N	node
917	20	bc7cc5b95c7382d41db2d4545de816a80a561d1e5437477717c0798f95684109	2026-08-11 14:30:11.807419+05:30	2026-09-10 14:30:11.80715+05:30	\N	\N	node
933	18	9044d8f3f1b3834d30929065d82c4dfab12f5adb1126aa7c5825b836c0fdea0d	2026-08-11 14:30:25.500586+05:30	2026-09-10 14:30:25.500244+05:30	\N	\N	node
946	20	a5de2eb787a14aeb1a307d013a171128b6461d1c797781c9419c12dbf570dadc	2026-08-11 14:30:40.771522+05:30	2026-09-10 14:30:40.771184+05:30	\N	\N	node
976	18	7c9c96ae9c3cfbfb65eb8b0f859c115e4a3c6fbe9ca59685a8bfac7b128c4ea5	2026-08-11 14:31:22.244529+05:30	2026-09-10 14:31:22.244344+05:30	\N	\N	node
979	244	a9ce90eba363a9ce4e7ff2bbe5d3e0fd060ee1784a15cb89603217c3c7ff7a98	2026-08-11 14:31:24.066687+05:30	2026-09-10 14:31:24.066241+05:30	\N	\N	node
860	18	e537f54452fda98f563bde74c72ac4659c785acc3a1219854f571882feba7003	2026-08-11 14:28:47.722468+05:30	2026-09-10 14:28:47.722305+05:30	\N	\N	node
872	20	9db7abb96a2bdeead853a060e5cd767b07d6a0ee50e2705ed888042d1d1a6294	2026-08-11 14:29:02.727729+05:30	2026-09-10 14:29:02.727464+05:30	\N	\N	node
878	17	a4d49764c664055228467a699340a8a2cd74a6418db3d0e715938bb6028c598c	2026-08-11 14:29:29.829521+05:30	2026-09-10 14:29:29.829333+05:30	\N	\N	node
882	17	3e5b4b8e95c87708b0a2d48d9763c9c686af4aa67e5a49815a528d098e8798e0	2026-08-11 14:29:32.524769+05:30	2026-09-10 14:29:32.524557+05:30	\N	\N	node
891	20	e626df583d91125ac1395db295e4dacf3ea22fc4eaab9cebd70acae905f298a2	2026-08-11 14:29:44.777166+05:30	2026-09-10 14:29:44.77693+05:30	\N	\N	node
899	19	f83ae8bc9def916fc3ea4f257ae0c986b7764deda7dbb08b6c2ee513ce1308e9	2026-08-11 14:29:49.889983+05:30	2026-09-10 14:29:49.889819+05:30	\N	\N	node
910	18	c437546311343f22fe8e20241496bb0b89c646afd6b62f18c3a8df8c5a303152	2026-08-11 14:30:00.023813+05:30	2026-09-10 14:30:00.023566+05:30	\N	\N	node
911	19	c895e3c1fc37341dcde392a25bccf2a3a58edb26a645a8443f6696421eccfe41	2026-08-11 14:30:00.452648+05:30	2026-09-10 14:30:00.452378+05:30	\N	\N	node
924	20	dba3c77f54db67ce99f178aef758a09c5dd95d2706258c0c61f374fed82af122	2026-08-11 14:30:16.393099+05:30	2026-09-10 14:30:16.39287+05:30	\N	\N	node
930	17	55767b42f5e45007f62a5703096b760b4b1e8e83983f8bd58630cd29e8b9df85	2026-08-11 14:30:23.258351+05:30	2026-09-10 14:30:23.258155+05:30	\N	\N	node
934	17	59c2af1d2f743306086e3001b542b94ac48e80031a733fd00b3e22ba9a5bc307	2026-08-11 14:30:25.953648+05:30	2026-09-10 14:30:25.953403+05:30	\N	\N	node
940	17	7080abe204b3eb5c36b2406133f0757f152d347e96890fda56f96dd71aeba5b5	2026-08-11 14:30:28.757165+05:30	2026-09-10 14:30:28.756985+05:30	\N	\N	node
948	18	194d403350d55b067513eb997a0c0b7b425d60a31d96b88c1b5712c6665d68ea	2026-08-11 14:30:41.46179+05:30	2026-09-10 14:30:41.461574+05:30	\N	\N	node
957	1	7f58766372f39da672e38ff48cd61c7ea892d5679b4760197e46939756bb23e9	2026-08-11 14:31:08.069812+05:30	2026-09-10 14:31:08.069522+05:30	\N	2026-08-11 14:31:10.176426+05:30	node
861	17	73d159e2aec81e81b8b7962a92dcdc4aaadd04719eafae040d23ef6c5906533f	2026-08-11 14:28:48.215536+05:30	2026-09-10 14:28:48.215276+05:30	\N	\N	node
868	20	bd67d319265fee356901c25e517d9589e397ee4a92386c859aa70aeea2ca7557	2026-08-11 14:29:00.639645+05:30	2026-09-10 14:29:00.639469+05:30	\N	\N	node
876	18	de64b782b981b5bb9d17f11eb4c9edc8113888facc034d1eaed4836c83a213eb	2026-08-11 14:29:27.766476+05:30	2026-09-10 14:29:27.766214+05:30	\N	\N	node
879	18	beb8f80d6ec97635918d78a4ca26a3082e348ed83fb05f940bce92a6530be33f	2026-08-11 14:29:30.583777+05:30	2026-09-10 14:29:30.583445+05:30	\N	\N	node
883	18	b3bf136a4c19fee8b6bc31a7d97c4582f8d50b1cb2538a340a68d88afc77f5d4	2026-08-11 14:29:32.971604+05:30	2026-09-10 14:29:32.971422+05:30	\N	\N	node
894	20	32a8a0fbb6e588843024f58ee904932933a4c144f7fd7996062b7aad3107cf73	2026-08-11 14:29:47.380175+05:30	2026-09-10 14:29:47.380005+05:30	\N	\N	node
901	20	65a629b23c00a3f8c9a52469ec669b3e827726e9704fcfab2dbfa4b41c4395ae	2026-08-11 14:29:53.55171+05:30	2026-09-10 14:29:53.551453+05:30	\N	\N	node
919	19	c7a4f709edefa41129423ca94541dd15c6d6ed89ef5df052d6a32f4ee8130007	2026-08-11 14:30:14.072157+05:30	2026-09-10 14:30:14.07192+05:30	\N	\N	node
942	19	e8f4adf50bc424bfe9a1e3d13ebbf7145032b01d086ca33b541f6c4e1ef79969	2026-08-11 14:30:36.632878+05:30	2026-09-10 14:30:36.632404+05:30	\N	\N	node
943	20	d7f44da4a9fa30b72d765a0f06b746e1a87d5de2266a70aabab45e4e01c68f86	2026-08-11 14:30:38.274538+05:30	2026-09-10 14:30:38.274341+05:30	\N	\N	node
956	1	f52603637aa3a966b438517b3c99f2a3e812cd6fa15598714580062faaa0102b	2026-08-11 14:31:08.058132+05:30	2026-09-10 14:31:08.057987+05:30	\N	2026-08-11 14:31:10.176426+05:30	node
964	7	1cccc107290be21b995d264fdd012a6b47483d9e195c86b8381761eb375604fe	2026-08-11 14:31:14.360349+05:30	2026-09-10 14:31:14.360144+05:30	\N	\N	node
965	8	c9cd0f2ca2351b9ebd83986217f8dcf425ba4383fb21fd4ac1d1bbebe57a6fd4	2026-08-11 14:31:14.96733+05:30	2026-09-10 14:31:14.967049+05:30	\N	\N	node
969	242	d59d26e9ea5e451931df9d71308d00cd22abbb93dfd0a93c6d27621bdec13c32	2026-08-11 14:31:17.923582+05:30	2026-09-10 14:31:17.923355+05:30	\N	\N	node
975	17	757fb5aadec870e66d786c1d4129c1605495395369cffff7d5ca045a3114ce0f	2026-08-11 14:31:21.628721+05:30	2026-09-10 14:31:21.628491+05:30	\N	\N	node
863	18	11199b0e17c9affc8ffd290a1a04096510a035b95c7937087f431031fcfbb274	2026-08-11 14:28:52.477788+05:30	2026-09-10 14:28:52.477628+05:30	\N	\N	node
864	19	6ec496b13c0e142ca913c680ded2e500544c50bb854ea48eb63438b5b2d892ce	2026-08-11 14:28:56.262692+05:30	2026-09-10 14:28:56.262457+05:30	\N	\N	node
866	17	c78ee6e3b2cab0a8c0592d20483f9522ebf4a9ca3a4a5d3faa2b16ab3fca5139	2026-08-11 14:28:59.948705+05:30	2026-09-10 14:28:59.948448+05:30	\N	\N	node
869	17	fb6bcc78ad2a758fceab9f7afabfd14794c790d673f0f73f68116c2b552b84d6	2026-08-11 14:29:01.052685+05:30	2026-09-10 14:29:01.052413+05:30	\N	\N	node
877	18	ad61e0ed5cfed285b8dbe1564a41c2b4853027af722005a3d145a8c4cef88db6	2026-08-11 14:29:29.125288+05:30	2026-09-10 14:29:29.125063+05:30	\N	\N	node
881	18	1dcc991f3a7ff05ed451126556e68aaf86f554ab8f5c63408232cb4e761eb689	2026-08-11 14:29:32.002459+05:30	2026-09-10 14:29:32.002212+05:30	\N	\N	node
885	19	f703dfd069dcc600fd9ce8b3539d2ea5c5b91da8c6d8091cde2c1cce72909087	2026-08-11 14:29:33.923321+05:30	2026-09-10 14:29:33.923108+05:30	\N	\N	node
886	18	91dff718e966c15b23470c3a628bc8a75d0e11e4fd5c87ff782dac87a27b2b5a	2026-08-11 14:29:34.424227+05:30	2026-09-10 14:29:34.423995+05:30	\N	\N	node
890	19	f66e7fdfd877bd1c7df715cd13e2b03201149e32de4b6f858ec3b3a8513c8f6e	2026-08-11 14:29:42.969999+05:30	2026-09-10 14:29:42.969755+05:30	\N	\N	node
892	17	944bad396de25d70e6e35b7df49626d1230b20dff6605754400e7863a75f9fcb	2026-08-11 14:29:46.691545+05:30	2026-09-10 14:29:46.691316+05:30	\N	\N	node
893	19	e45c7c8b55051b5d22d5b901b0847e67adb7f03774ab1a59bd82ea26981c118d	2026-08-11 14:29:47.033127+05:30	2026-09-10 14:29:47.032686+05:30	\N	\N	node
895	17	d6d6134ecdc12100b4d1580cb973a469d457aa8f822ccd55931ad3c592d98e0e	2026-08-11 14:29:47.768166+05:30	2026-09-10 14:29:47.767876+05:30	\N	\N	node
908	17	a6824477c5118eb9681f96fd2b4d1b3cfd070cef89eb4ed96d0a3082fd3d6e4f	2026-08-11 14:29:58.955431+05:30	2026-09-10 14:29:58.955193+05:30	\N	\N	node
914	17	3b1389ad244c00ea86380735d28aba25bb31d62eb311dacea5d0df186ca7341a	2026-08-11 14:30:01.896349+05:30	2026-09-10 14:30:01.896179+05:30	\N	\N	node
915	18	06bbf4b1e99eedb7333bcd2616194cbd2eafb79ad8e4684aa2eac706f240e46f	2026-08-11 14:30:05.862286+05:30	2026-09-10 14:30:05.862051+05:30	\N	\N	node
921	17	f893452a9fafb5616a959463b9fdbfea2ad7be2b3bea7d9fd64b12691bcdce8e	2026-08-11 14:30:14.785511+05:30	2026-09-10 14:30:14.785217+05:30	\N	\N	node
922	18	62d42ae1f4987bb3d51a2837dc42548e742f2b37027c7dde1cc7e66eaaa55f3f	2026-08-11 14:30:15.214853+05:30	2026-09-10 14:30:15.214199+05:30	\N	\N	node
929	18	31914b1a3bb1f434faf1cfd1266c261d53f9ed0d8f934bae5827333ae2a53937	2026-08-11 14:30:22.481333+05:30	2026-09-10 14:30:22.48105+05:30	\N	\N	node
939	17	adbc7513f5525674a369e00cf1b0458665f60104d5b53c97f2b1ce1d0b153cae	2026-08-11 14:30:28.433872+05:30	2026-09-10 14:30:28.433624+05:30	\N	\N	node
945	19	c0ce6404a5e121352d99b2a2672621d7058920081d228256209a143a35ded30a	2026-08-11 14:30:40.36097+05:30	2026-09-10 14:30:40.360751+05:30	\N	\N	node
949	19	ab854b1903343a07af28a43b2bd63c7d776a359357bc9e59651d1d647d0141ed	2026-08-11 14:30:42.303783+05:30	2026-09-10 14:30:42.303528+05:30	\N	\N	node
952	1	6d9936818fdbe6b9349fc137de8e0eda45d1a4718333ce4f5937378df43380b8	2026-08-11 14:31:06.772062+05:30	2026-09-10 14:31:06.771836+05:30	2026-08-11 14:31:07.233086+05:30	2026-08-11 14:31:07.233086+05:30	node
954	1	ac40d8e6d2926e0bc9ef33c8000ead19b6834ece5354fd32230e79ac2d04a452	2026-08-11 14:31:07.685731+05:30	2026-09-10 14:31:07.685487+05:30	2026-08-11 14:31:08.05064+05:30	2026-08-11 14:31:08.05064+05:30	node
958	2	b0c05aa8132ea993d3ca44f31ade5ba5cbb757e115dbbd80ba4be095f6b8bd94	2026-08-11 14:31:08.814934+05:30	2026-09-10 14:31:08.814692+05:30	\N	\N	node
795	1	84d6f677cf161f6d62e5f7cc21082e877ea260668f2e388886d2669b3c813218	2026-08-11 14:27:06.383649+05:30	2026-09-10 14:27:06.383417+05:30	\N	2026-08-11 14:31:10.176426+05:30	node
961	5	e70c7d6d25b35eb0d0605eae41bc9d374df09eb48afd8eecf5294315bbd2c88e	2026-08-11 14:31:13.057561+05:30	2026-09-10 14:31:13.057361+05:30	\N	\N	node
963	3	e5f71ee5f47038bc3b294c29ee6197bf8cb339c7a8848f1616632019f353eea0	2026-08-11 14:31:13.95433+05:30	2026-09-10 14:31:13.954122+05:30	\N	\N	node
966	17	9a478bf5b9190db6ce8883a68544641592189b01349c44044467bfd522613baa	2026-08-11 14:31:15.47727+05:30	2026-09-10 14:31:15.47706+05:30	\N	\N	node
974	17	4eeab98313b0794efcf9bc566e79a06bbf1a651f80e8d8cd4bcff49c843e4a80	2026-08-11 14:31:21.229983+05:30	2026-09-10 14:31:21.229813+05:30	\N	\N	node
977	17	b5201ac115558e3679f69aa49eca525825335c389ef845640168919e5df48a5f	2026-08-11 14:31:22.608694+05:30	2026-09-10 14:31:22.608419+05:30	\N	\N	node
978	18	711e3d4ff84601f4d920b09bf3a44a1857e0be478b8ae7899d397527135b4aa6	2026-08-11 14:31:23.02323+05:30	2026-09-10 14:31:23.023001+05:30	\N	\N	node
980	18	222b4da9ec58c148b1e1c92f766cd269d6d45de06c8b42ed4abb82203d6aca67	2026-08-11 14:31:24.44429+05:30	2026-09-10 14:31:24.444034+05:30	\N	\N	node
982	18	65083f1fb65282c01c7245b3cbb7f7f01b4bcdf6f1ef716808cf6ba9eb4b3b5f	2026-08-11 14:31:25.94775+05:30	2026-09-10 14:31:25.947478+05:30	\N	\N	node
870	18	29d2914cf54a984e3e3065f9af643fdcfe84ee8dd45bb02574bc7fce2d923342	2026-08-11 14:29:01.498041+05:30	2026-09-10 14:29:01.497259+05:30	\N	\N	node
888	17	eb70e0059d21eacb379c46ee2b98ce69459752d365f560ae4394495af90309a2	2026-08-11 14:29:35.237011+05:30	2026-09-10 14:29:35.236771+05:30	\N	\N	node
900	19	8e81e688ca7138703958bad59ae8a95685400d1253e0132694579acf241dabba	2026-08-11 14:29:52.501259+05:30	2026-09-10 14:29:52.500732+05:30	\N	\N	node
904	17	d676e9aaf7046194c28446b104c7a2418c891c15113fc4b81d8da3aed7862a87	2026-08-11 14:29:56.220436+05:30	2026-09-10 14:29:56.220227+05:30	\N	\N	node
907	18	c36872faaa79852287c3df275548167ff6e8555e1b288f8e6bfe789d8467e322	2026-08-11 14:29:58.488864+05:30	2026-09-10 14:29:58.488688+05:30	\N	\N	node
927	20	6e5a03dd9e2f9e2957e640796a5424df7ebfb3ac98bfcbe176bc6ddae6a7c947	2026-08-11 14:30:20.543226+05:30	2026-09-10 14:30:20.543061+05:30	\N	\N	node
932	18	8d57cfa27f2f3ff706158b1c2a723dc043183602d69e9dbff24e59f6a65e9e3f	2026-08-11 14:30:24.777817+05:30	2026-09-10 14:30:24.777575+05:30	\N	\N	node
935	18	812991c42e6c7444a236d9a80378dfffd71b2b0c1d747c9d85b30633536e8b45	2026-08-11 14:30:26.45967+05:30	2026-09-10 14:30:26.459438+05:30	\N	\N	node
947	17	60b80015c3f99e88994bca36d09dbe4d321d635d96cb4f65a8b4c28bd43d769d	2026-08-11 14:30:41.117263+05:30	2026-09-10 14:30:41.117027+05:30	\N	\N	node
951	19	abab0e6e6b6ffc10e0df5b2482b7a1d6a9bde35cf8aac37689a57d710593a1e6	2026-08-11 14:30:43.234419+05:30	2026-09-10 14:30:43.234118+05:30	\N	\N	node
953	1	1298ddeab3d25f31ca845322688a959666e9d05370890df3fbf7fb41f9bd41fb	2026-08-11 14:31:07.28791+05:30	2026-09-10 14:31:07.287694+05:30	\N	2026-08-11 14:31:10.176426+05:30	node
971	18	8c72064af51037f6590c3c3a4b53f0c6ed8dead2b4a38012b01898903e1f4f0c	2026-08-11 14:31:18.78735+05:30	2026-09-10 14:31:18.787077+05:30	\N	\N	node
973	18	9b69811ae7da06bf41aba4037f1b281370968a23e3c3029476b1caf409e157d9	2026-08-11 14:31:19.905079+05:30	2026-09-10 14:31:19.90486+05:30	\N	\N	node
981	245	5e8007c54acbc4ca735b5298884420b3fbb297523818633759a44c1dc5bc98d5	2026-08-11 14:31:25.584799+05:30	2026-09-10 14:31:25.58457+05:30	\N	\N	node
871	19	cf6d6ae89ef9c85abb1f7a0b4e6f2bd12e91c4677ede8ed2f396a576e0500cb0	2026-08-11 14:29:02.299856+05:30	2026-09-10 14:29:02.299631+05:30	\N	\N	node
873	19	7054fe2c59ef6ede4d170c95653b6fb05e3a8231d8d11a1ee9bd3ec989ef0cab	2026-08-11 14:29:03.257302+05:30	2026-09-10 14:29:03.257031+05:30	\N	\N	node
880	18	2ccb2888c0f7cdb00c0ac9cda8b0d13df10611bc504d1b62475169cac296aedc	2026-08-11 14:29:31.307995+05:30	2026-09-10 14:29:31.30781+05:30	\N	\N	node
889	18	344538b4f568bb2ec15c079d2f53e76283c908e518f489748af5c7557cad654b	2026-08-11 14:29:39.165862+05:30	2026-09-10 14:29:39.165574+05:30	\N	\N	node
896	18	c41441872feebd02ba8be49a9c66b327f9c9eb1c1b6d8fb9ae33d6eff882e196	2026-08-11 14:29:48.208852+05:30	2026-09-10 14:29:48.208606+05:30	\N	\N	node
902	18	3808d587def6205b05f91e3109c9f8ec4c4cf5c8c80c2af5732e0ca962cd03e0	2026-08-11 14:29:54.150765+05:30	2026-09-10 14:29:54.150505+05:30	\N	\N	node
905	18	bc3403e26408f21aca8dc6b781a50c87a61b8235ae8b999a705b146aee30afed	2026-08-11 14:29:56.999238+05:30	2026-09-10 14:29:56.998951+05:30	\N	\N	node
909	18	53ddc4b62cdcb545184891a27d5bfa3d21746e55451d6d2c4bf5726fe88311c3	2026-08-11 14:29:59.541005+05:30	2026-09-10 14:29:59.540806+05:30	\N	\N	node
916	19	294fdd4b56ca9eff51e8c60acdf482bb542a3b80e9069e399a4894f6a50d3714	2026-08-11 14:30:09.984383+05:30	2026-09-10 14:30:09.9841+05:30	\N	\N	node
918	17	659e3468ee1d70d2109d6ffcc5791d357a7dd8104d5ef41a40ce04400583da7d	2026-08-11 14:30:13.67146+05:30	2026-09-10 14:30:13.671012+05:30	\N	\N	node
926	19	daa53498bddf797e4ade7113b36ba4c97d217881c80f4e75113da5d45a4e9618	2026-08-11 14:30:19.519055+05:30	2026-09-10 14:30:19.518841+05:30	\N	\N	node
931	18	d1507078001ada8a3a43ea28920508060a69082955df4282f206da1d6971f298	2026-08-11 14:30:24.01835+05:30	2026-09-10 14:30:24.018039+05:30	\N	\N	node
937	19	655a4766ba6e1943d29b978b472020729873b607c8b61b90ce420ac9999974ab	2026-08-11 14:30:27.388882+05:30	2026-09-10 14:30:27.388709+05:30	\N	\N	node
938	18	f10dfee374ce9fe8b3e64d4ce8fd027688707518da4bc42db70549149804a344	2026-08-11 14:30:27.838406+05:30	2026-09-10 14:30:27.838115+05:30	\N	\N	node
944	17	cac8d477e121535114f8107b0c031626ed7cc54e7195e5ee8bbdf51092d9dc2d	2026-08-11 14:30:39.973644+05:30	2026-09-10 14:30:39.973458+05:30	\N	\N	node
960	1	9a3cc02df7f17a53d6fdacc45d0a4210d76399689c3ebb965097776484e1bf7b	2026-08-11 14:31:10.16947+05:30	2026-09-10 14:31:10.16923+05:30	\N	2026-08-11 14:31:10.176426+05:30	node
962	3	65335e654bdb28049c2d040aae89ac18c456f9b09a531e22a7a07dfb32e01e15	2026-08-11 14:31:13.492306+05:30	2026-09-10 14:31:13.492065+05:30	\N	\N	node
968	17	b6219f68bf3e664733e0325d726cb57654a469f691cecbd341c65d70120bd1ae	2026-08-11 14:31:16.656379+05:30	2026-09-10 14:31:16.656175+05:30	\N	\N	node
875	20	b0d38cca7a57448cdae2993917a9f7b1828218dd9e58ee32bda1f9dc10ad7089	2026-08-11 14:29:27.055191+05:30	2026-09-10 14:29:27.054942+05:30	\N	\N	node
887	17	764f90b08cac6fdac4816a986d96a7bf0aae3998bf87290b033c82b2b5bed63f	2026-08-11 14:29:34.892902+05:30	2026-09-10 14:29:34.892729+05:30	\N	\N	node
897	19	194c5f5cb0209593ec91b4c90122209bb5d81eb0e1fe3b864b952c564b8930aa	2026-08-11 14:29:48.917194+05:30	2026-09-10 14:29:48.91698+05:30	\N	\N	node
903	18	96e16794eb08c8353df2d9517d61be669477d76ff1e1de8020dba5285f64b05d	2026-08-11 14:29:55.482906+05:30	2026-09-10 14:29:55.482628+05:30	\N	\N	node
923	19	e3008b8da9a95525d82ed5f2909616d749a7070d20e73661a5acac88c569f151	2026-08-11 14:30:15.934191+05:30	2026-09-10 14:30:15.933895+05:30	\N	\N	node
925	19	8deae20199112c7e321c2e76c5cfb215e3bfaa43c77d6cb510bcf3782e797f56	2026-08-11 14:30:16.92909+05:30	2026-09-10 14:30:16.928865+05:30	\N	\N	node
928	18	bd6ef5560a6af276c00e6bf8e1ab93307f0637b3057e39ca769f9dc5726e00b1	2026-08-11 14:30:21.10905+05:30	2026-09-10 14:30:21.108804+05:30	\N	\N	node
941	18	38e173e8a0dfe99e0756cd17488cc22108b92a4a272c00e0466d2b0e195b9922	2026-08-11 14:30:32.8221+05:30	2026-09-10 14:30:32.821851+05:30	\N	\N	node
970	17	e21d8cc12a6a00cc807ee2be656885f54d2097c3bf5d1c4641caf8e3722c12cb	2026-08-11 14:31:18.3206+05:30	2026-09-10 14:31:18.320305+05:30	\N	\N	node
983	244	d49602543651afb4b39f2114921f95be4a633fda3b25537da73e40777e5ce3ff	2026-08-11 14:31:27.398108+05:30	2026-09-10 14:31:27.397949+05:30	\N	\N	node
984	18	243475d94544ad6982d224f3d4528c138382c83265472ca6a402d9a7660e07a3	2026-08-11 14:31:27.784405+05:30	2026-09-10 14:31:27.784046+05:30	\N	\N	node
985	17	fbb047e837e4547a3674d9698a8b43b6fbfe68b9f71c947d903473d45b340324	2026-08-11 14:31:28.324942+05:30	2026-09-10 14:31:28.324678+05:30	\N	\N	node
986	18	3f925e9250af6afcfd1f1ea48abb9fd36fdfcf2cc118c0421369d6546bfba3ef	2026-08-11 14:31:28.720805+05:30	2026-09-10 14:31:28.720643+05:30	\N	\N	node
988	17	8aecc452c2a3f7f78f474cd670f32e075d381d44ac2776d420ee334d1cff0c29	2026-08-11 14:31:29.447585+05:30	2026-09-10 14:31:29.447327+05:30	\N	\N	node
989	18	ce55706b67d2930aff7fcfb73591e2945c27235fb528a0caf7c75f1b89cd98b2	2026-08-11 14:31:30.16803+05:30	2026-09-10 14:31:30.167685+05:30	\N	\N	node
990	246	0fb71505e9b98d13954d023bc35bd28b26da9ba8a8a3bf7b45bbd48d2c18ff99	2026-08-11 14:31:31.075881+05:30	2026-09-10 14:31:31.07567+05:30	\N	\N	node
991	18	90665c1387c9b6493729b7e56debbc0984babb5dc7dfb9afc47db8d8835d1dfb	2026-08-11 14:31:31.529013+05:30	2026-09-10 14:31:31.528791+05:30	\N	\N	node
992	18	c4be260ee965ae149c3cd3f82ca24c5ab3f1c8027a144a013a65be1aa9b1b57d	2026-08-11 14:31:31.986771+05:30	2026-09-10 14:31:31.986579+05:30	\N	\N	node
993	246	4a824401483fb7a21d00239924063d3f7638bd0b96ea72e6bdaea8571ce9b8a9	2026-08-11 14:31:32.517422+05:30	2026-09-10 14:31:32.517149+05:30	\N	\N	node
994	18	47ace0f854c111c8b07c83e9e5def5ec46e12ef3b2d1cbfaf066d6b1e727db8a	2026-08-11 14:31:32.945817+05:30	2026-09-10 14:31:32.945546+05:30	\N	\N	node
995	246	0c151fe29a407d6c3087ec6c5d991469ccb7df9856c5f74677cbcca004b60720	2026-08-11 14:31:33.431328+05:30	2026-09-10 14:31:33.43115+05:30	\N	\N	node
996	18	db45b76c5f071e57c6d8159a5a8ed8fa4fa14813dc4bf673011cd651a47a9062	2026-08-11 14:31:33.826662+05:30	2026-09-10 14:31:33.826371+05:30	\N	\N	node
997	18	93c6b1907b7314b133669dcd48ba5b85ae4351cc2dcd46c914500290d1064e11	2026-08-11 14:31:34.549303+05:30	2026-09-10 14:31:34.548852+05:30	\N	\N	node
998	17	07613999a012c88534e7af2529b9d575e88144e9b55a1f5fcd953b71533a0626	2026-08-11 14:31:35.000512+05:30	2026-09-10 14:31:35.000035+05:30	\N	\N	node
999	17	fd42e454f9fb6e636ef48b5c8a95e0ccc26867270e9a130cb88108f28a358d95	2026-08-11 14:31:35.347293+05:30	2026-09-10 14:31:35.347135+05:30	\N	\N	node
1000	247	edef3ebc919fa889418ec28adc3ec73efc644c5557e833bbaeb31efb4880a68d	2026-08-11 14:31:36.678289+05:30	2026-09-10 14:31:36.678109+05:30	\N	\N	node
1001	17	79c4ec346552dbf7f9aec5d20f7d7424a7be6ea3ca6e5908d7a045fc86f6eeb8	2026-08-11 14:31:37.022753+05:30	2026-09-10 14:31:37.022592+05:30	\N	\N	node
1002	17	3965295e873d3331a729b2cce15f9c5179cd9c55e40307f2a3b6e18332036ba4	2026-08-11 14:31:37.473023+05:30	2026-09-10 14:31:37.472707+05:30	\N	\N	node
1003	247	bb6786e06ec3e6af0e50a204d9a41af6dc71e9d54b1cbabcc1142b4d43689f17	2026-08-11 14:31:38.005907+05:30	2026-09-10 14:31:38.00566+05:30	\N	\N	node
1004	17	3f97c3bbe9bf05812dbadf9641133e650c18fe32a19bf67ec75eadc1f9dfd677	2026-08-11 14:31:38.433511+05:30	2026-09-10 14:31:38.432752+05:30	\N	\N	node
1005	17	8f7d6eb332fbea49d07359a26450b16491db6b6d0a8f13922c4387666318bf4e	2026-08-11 14:31:38.876275+05:30	2026-09-10 14:31:38.876051+05:30	\N	\N	node
1006	17	f624edef722235d1c467926aa47ec19541e0bc6c34f7c913200691ec0c658817	2026-08-11 14:31:39.399854+05:30	2026-09-10 14:31:39.399475+05:30	\N	\N	node
1007	18	26194a771e3fb65ba2ef9703ecc311fd4d568fa29cced636ad2c5bda4dfa7edc	2026-08-11 14:31:39.859468+05:30	2026-09-10 14:31:39.859255+05:30	\N	\N	node
1008	18	c8e1e28af90bc08ee7b84a2393d68a5d3e2833109c3f668ec3cfb4997a2eb18d	2026-08-11 14:31:41.020726+05:30	2026-09-10 14:31:41.020505+05:30	\N	\N	node
1009	17	9e5a11c2d74f4a880fa8f0895ce50bc8a93aa67dd31d224e072ee1c2d0589a44	2026-08-11 14:31:41.448919+05:30	2026-09-10 14:31:41.448745+05:30	\N	\N	node
1010	18	a1a3df7bef4f5ab94fb6730b98ae22bae384ed1aeb1a7136bf33d5f1051a531a	2026-08-11 14:31:41.785311+05:30	2026-09-10 14:31:41.785127+05:30	\N	\N	node
1011	17	dcde5270d35e176e4fd03d4aa6c1832eb2c9cadecc3b9873815eec8692cb0282	2026-08-11 14:31:42.592476+05:30	2026-09-10 14:31:42.592219+05:30	\N	\N	node
1013	19	7e2baf820300003297089a024069001c5d3a70eb6ea8f0b6b6742f5d60de4111	2026-08-11 14:31:50.482906+05:30	2026-09-10 14:31:50.482597+05:30	\N	\N	node
1014	20	bfd8353133f93cbe326b692e4204c8a90518998f74ba149b8a874197a1301fb6	2026-08-11 14:31:51.516091+05:30	2026-09-10 14:31:51.515753+05:30	\N	\N	node
1015	18	f1b7b49d0640586fe4d252d5a4789a083ad7ccc4a6df38f7fbf4a203adedba17	2026-08-11 14:31:52.119833+05:30	2026-09-10 14:31:52.119559+05:30	\N	\N	node
1016	18	4b351c2093df49e574a466cae7e9e60e65b43a07cb22dbb092f159768ada13f1	2026-08-11 14:31:53.531318+05:30	2026-09-10 14:31:53.531147+05:30	\N	\N	node
1017	17	ee268c89654dd25eb64bcda92b11a765cec86f3b6e6f920c541d8c8a9174068c	2026-08-11 14:31:54.263621+05:30	2026-09-10 14:31:54.263383+05:30	\N	\N	node
1018	18	12faf871eea22612861eb916fcf543ea956005e15148b3984d4bea1082acedc8	2026-08-11 14:31:55.011221+05:30	2026-09-10 14:31:55.010986+05:30	\N	\N	node
1019	18	0dca8c34831b774963bf5636563088930e492df6c8de0a1fd89fd4b8380bed9c	2026-08-11 14:31:55.717955+05:30	2026-09-10 14:31:55.71763+05:30	\N	\N	node
1020	18	3970ae8e53bb7cf0e54964d338c804527cf1ec917911fce63575fe18135473f6	2026-08-11 14:31:56.452482+05:30	2026-09-10 14:31:56.452178+05:30	\N	\N	node
1021	17	f752f1e9c83534f06c594ad144abc14265529d0ff18090cd0fd27bc4225339f7	2026-08-11 14:31:56.936208+05:30	2026-09-10 14:31:56.935937+05:30	\N	\N	node
1022	18	bb6566c8f2585bec67b95436a7278b2b47f61a1ef22da69ab4b5a090c826a7b7	2026-08-11 14:31:57.385568+05:30	2026-09-10 14:31:57.385257+05:30	\N	\N	node
1023	18	186457cb074d7b293133daefd0f1aef22145f497a77fb63c0ba82ef4fd0b428a	2026-08-11 14:31:57.941788+05:30	2026-09-10 14:31:57.941527+05:30	\N	\N	node
1024	19	23d84283aa20b2321cdad75b63d25fcc7ae228e6d0e8faea6bfda45f47745f18	2026-08-11 14:31:58.431184+05:30	2026-09-10 14:31:58.430912+05:30	\N	\N	node
1025	18	73fdbc93d649ca0aff078c347ecb3bae46b9c864e26076bc92742b81084a3d51	2026-08-11 14:31:58.885312+05:30	2026-09-10 14:31:58.885074+05:30	\N	\N	node
1026	17	0132ac4f8aac50bfbc9a76f0717a5d636a009aab5b47e16f8d735515698ac06f	2026-08-11 14:31:59.435058+05:30	2026-09-10 14:31:59.434826+05:30	\N	\N	node
1027	17	b7abe1e837a7fe70d7abd41347894c55d88fd1a7c3bbc8a8dadf2f4a237a8bbe	2026-08-11 14:31:59.819767+05:30	2026-09-10 14:31:59.819606+05:30	\N	\N	node
1028	18	a811c079a1cc7a4a41299c87b2b76ea06fdf9187811964ae59c613d273ba2146	2026-08-11 14:32:03.701504+05:30	2026-09-10 14:32:03.701206+05:30	\N	\N	node
1029	19	8d2b2f4189a26e0a0954d250a834ef1e7be1f01450c648bcacdd36ecf48af9ab	2026-08-11 14:32:07.539562+05:30	2026-09-10 14:32:07.539376+05:30	\N	\N	node
1030	20	fb327007c2dea9df1b677043f14528c4ad6c7647c2580c88d2824b7a3b8b5a7e	2026-08-11 14:32:09.259656+05:30	2026-09-10 14:32:09.259385+05:30	\N	\N	node
1031	17	c6e0e76da3f51d6c28ddf9f1696feb2251427d6f719b18223c08746153364b79	2026-08-11 14:32:11.033238+05:30	2026-09-10 14:32:11.032881+05:30	\N	\N	node
1032	19	68e42a7f62afce0437b5bf6107be7685c13edff7490693f69b6d4fb422322d43	2026-08-11 14:32:11.387055+05:30	2026-09-10 14:32:11.386738+05:30	\N	\N	node
1041	1	5bb83916f1617ee9935658b01dfd780f945d1903b9beaa28cd8ceda4cbc55a24	2026-08-11 14:32:16.061159+05:30	2026-09-10 14:32:16.060962+05:30	2026-08-11 14:32:16.47414+05:30	2026-08-11 14:32:16.47414+05:30	node
1050	3	b59d3048a59969ae1c8229ffa483548e09c4759e39886d3e5636675b66458ccd	2026-08-11 14:32:22.101725+05:30	2026-09-10 14:32:22.101464+05:30	\N	\N	node
1053	17	7fa0b60071ac224e84fe1f48a9d6484535610b7c2c7b1cfe7eeb38cd62b2fad1	2026-08-11 14:32:23.715335+05:30	2026-09-10 14:32:23.715115+05:30	\N	\N	node
1056	248	eeb8651c64246f912cf87b6814890411891f64d0119f9894ec51db4d973edff4	2026-08-11 14:32:26.329381+05:30	2026-09-10 14:32:26.329078+05:30	\N	\N	node
1082	252	462d6c6651b0e10d009127a61cd2740bfb16034524f910317013c60ee9122d11	2026-08-11 14:32:41.230088+05:30	2026-09-10 14:32:41.229865+05:30	\N	\N	node
1087	253	e1ebef6484f10f1be77b31080056e7e038e989bcc2f681a9a1ae0cffa98fe022	2026-08-11 14:32:44.296137+05:30	2026-09-10 14:32:44.295936+05:30	\N	\N	node
1090	253	fcc0ddac9c9b8172eeacde7dc0d56bbc5d75c9154d1d6b7857daddca28c49c20	2026-08-11 14:32:45.798274+05:30	2026-09-10 14:32:45.798047+05:30	\N	\N	node
1033	20	8a1859487e23efc106aceaac0282021eda9e9944ac0d7abe7dcf72c076286bb7	2026-08-11 14:32:11.879931+05:30	2026-09-10 14:32:11.879698+05:30	\N	\N	node
1055	17	e09a80ff68d327ed4eeacd30a2e99ac85a0bed0bd9f318ec970c11582fe3d662	2026-08-11 14:32:25.06511+05:30	2026-09-10 14:32:25.064879+05:30	\N	\N	node
1065	18	bceb112e6886eb9634bc1b70827c10c6c4857aaffebfedb1dcb452559a211f25	2026-08-11 14:32:31.585911+05:30	2026-09-10 14:32:31.585637+05:30	\N	\N	node
1086	17	e3bd8cac44b0dea85c1b4a4ba0f579b4739d6f5fae25cb2dea72777632e71ad2	2026-08-11 14:32:43.054572+05:30	2026-09-10 14:32:43.053923+05:30	\N	\N	node
1094	18	7229a9a12fae2c1c9cac3dc96210edb4c265f9523fcf79817146cf27a716b50a	2026-08-11 14:32:47.613977+05:30	2026-09-10 14:32:47.613695+05:30	\N	\N	node
1100	19	e45ce9f1efb1e5e9b30e961d5e4fcfbe85ef4201f1ec4bde639f3695a9109a63	2026-08-11 14:32:58.406007+05:30	2026-09-10 14:32:58.405703+05:30	\N	\N	node
1106	18	dd7dae5abd4ce6aeef3122baae6827057c5a6b79e4aecb47ba077f15dbf36ec3	2026-08-11 14:33:03.624325+05:30	2026-09-10 14:33:03.624076+05:30	\N	\N	node
1110	18	c6fa0d4b603267ace67c493781d55cd9f0acd57e3a90a986b945aa1791379321	2026-08-11 14:33:05.842419+05:30	2026-09-10 14:33:05.842177+05:30	\N	\N	node
1034	17	39d57f007a2cc8906581ddc1f4392d152c1605fba03ebbcab07b67c18093e389	2026-08-11 14:32:12.240052+05:30	2026-09-10 14:32:12.239892+05:30	\N	\N	node
1045	2	0c05bbf69cc4d4f8bb68590a018590668517b6ad01c98364a9af13a07b9dcac8	2026-08-11 14:32:17.153226+05:30	2026-09-10 14:32:17.152912+05:30	\N	\N	node
987	1	59f9bf2d23386252667c6405a6f2adf8ec11fe37cd9cbe7ce071c895ddcd0f40	2026-08-11 14:31:29.07172+05:30	2026-09-10 14:31:29.071542+05:30	\N	2026-08-11 14:32:18.378911+05:30	node
1012	1	06c52246ab32fbc27be461b100bd3ae0b8b14403aa4da8cc2457b9be41b15970	2026-08-11 14:31:45.370879+05:30	2026-09-10 14:31:45.370629+05:30	\N	2026-08-11 14:32:18.378911+05:30	node
1035	18	09fcaf43b3198f4f8b7aa0ff4c48d7a8f693d5d0f53fb8e88a78b02fb7bfdb15	2026-08-11 14:32:12.687741+05:30	2026-09-10 14:32:12.687565+05:30	\N	\N	node
1057	17	a760672ab92ac83b8b564c59a8d554d8c2552711f522d0fd15ebc930f1dbdfd0	2026-08-11 14:32:26.751787+05:30	2026-09-10 14:32:26.751598+05:30	\N	\N	node
1079	18	3c0917a5f70a8e9f1cf2784a196c39cfece0008a65075c7cce87602e705dc3b3	2026-08-11 14:32:39.860756+05:30	2026-09-10 14:32:39.860589+05:30	\N	\N	node
1092	17	ca48d3487938fcdd85097e2f2d11761b85e6a63338b4d4cb46bc8e6768099835	2026-08-11 14:32:46.634503+05:30	2026-09-10 14:32:46.634113+05:30	\N	\N	node
1096	17	7f197929d80c3f49329aa7a92701c881fc423e75292565598ef4e2f4c7586ffd	2026-08-11 14:32:49.148909+05:30	2026-09-10 14:32:49.148664+05:30	\N	\N	node
1102	18	fdadf68943aadfd716bf3fa99c8f0fd7638a16b3cd1caa4d811dcef04fcee738	2026-08-11 14:32:59.968752+05:30	2026-09-10 14:32:59.9684+05:30	\N	\N	node
1105	18	9c4f934fdcee3fe27b970f14553e06a10b0e818416cc2bc644a25276e66a4212	2026-08-11 14:33:02.862716+05:30	2026-09-10 14:33:02.862434+05:30	\N	\N	node
1108	17	984afef7581c9253757f80aa66732a986e9124e4d33468b69ce88855ee71f5e2	2026-08-11 14:33:04.902257+05:30	2026-09-10 14:33:04.902024+05:30	\N	\N	node
1074	1	7d832f7cd1e63e6937ceb05da016961b9743337df0b85f7e513708ff50a1dd6c	2026-08-11 14:32:37.26395+05:30	2026-09-10 14:32:37.263758+05:30	\N	2026-08-11 15:10:02.742418+05:30	node
1036	19	9864d98428ea31fba9df44c0746f76be355487c79603a8318aa7a1a2b41fdd75	2026-08-11 14:32:13.5037+05:30	2026-09-10 14:32:13.503456+05:30	\N	\N	node
1038	19	77c98f8a09b5b9be340793474cf33df377ac04921fe7a15e5008a44ddf464cda	2026-08-11 14:32:14.365554+05:30	2026-09-10 14:32:14.365307+05:30	\N	\N	node
1040	1	91b56db62c8f4fafc8a46ed5f1966051303588dfc288690eea204e890e17423f	2026-08-11 14:32:15.701658+05:30	2026-09-10 14:32:15.701324+05:30	\N	2026-08-11 14:32:18.378911+05:30	node
1061	17	d7cc821c09539ca0c88f35a6c2348330582861f2b3591596dc009dea5b939dac	2026-08-11 14:32:29.723593+05:30	2026-09-10 14:32:29.723324+05:30	\N	\N	node
1066	250	21745402b41f30d1b483a00660c2020440dc2922b0b250e212c553d26a7e3f8b	2026-08-11 14:32:32.486781+05:30	2026-09-10 14:32:32.486615+05:30	\N	\N	node
1073	18	544d428efcf1ffbadd82933654d2e0a2c586e59e7f18e8646a22a7747a94b701	2026-08-11 14:32:36.877884+05:30	2026-09-10 14:32:36.877589+05:30	\N	\N	node
1078	18	7a93fa96043700621dc37dae03cacfed15ebf0ddd86f2644c7bb41391a4ae844	2026-08-11 14:32:39.378764+05:30	2026-09-10 14:32:39.378551+05:30	\N	\N	node
1107	18	3973101a4d29ebd4a991d61dd1bd97a80897096bfec8a5a2820fa1ad326989b3	2026-08-11 14:33:04.417456+05:30	2026-09-10 14:33:04.417035+05:30	\N	\N	node
1037	20	ae39c3ebd0e86e31fb40478d23b037e87d56bfc221e16e1f0d02b797efb0a4cf	2026-08-11 14:32:13.910178+05:30	2026-09-10 14:32:13.909992+05:30	\N	\N	node
1042	1	829f5c5ef8528a54c4a35c7e2baae48d60a6d0ecb8094f42cbb5049a5e32ecc1	2026-08-11 14:32:16.465924+05:30	2026-09-10 14:32:16.465745+05:30	2026-08-11 14:32:16.486728+05:30	2026-08-11 14:32:16.486728+05:30	node
1046	1	81a37879ec0a82eca0a1f3581e1bbd2bec07f463d511468b2f93c6de8aa11563	2026-08-11 14:32:17.810269+05:30	2026-09-10 14:32:17.810088+05:30	\N	2026-08-11 14:32:18.378911+05:30	node
1069	18	d9d689376165f2fedcae1fff1bc13e3e2275496c756351e40d073b6a90661b3f	2026-08-11 14:32:34.225356+05:30	2026-09-10 14:32:34.22501+05:30	\N	\N	node
1077	252	f5a2545b066471828fb8341d18cd605a16848f44a5bd51e3ec7007729d3a307a	2026-08-11 14:32:39.000579+05:30	2026-09-10 14:32:39.000317+05:30	\N	\N	node
1085	17	0925968ec2a8317a4820d5729c81aaa3f7635dc8bad66ecc609fe62b7a763971	2026-08-11 14:32:42.629683+05:30	2026-09-10 14:32:42.629395+05:30	\N	\N	node
1089	17	bdaf9bc0bcdc7ea0e4bf26ae3e958825bd11909d00d26da0d810a9abb3e5e6bc	2026-08-11 14:32:45.335861+05:30	2026-09-10 14:32:45.335613+05:30	\N	\N	node
1093	17	9b37f157f219e986c793d42e71b146e0ef7e2319c61d0b747104e41fd23909ac	2026-08-11 14:32:47.173245+05:30	2026-09-10 14:32:47.172987+05:30	\N	\N	node
1109	18	a8303a6d168fb7f9a8e13aecfe3f26c991477aebe63f06524e61acb25c2e5df2	2026-08-11 14:33:05.351924+05:30	2026-09-10 14:33:05.351588+05:30	\N	\N	node
1039	1	51c528ec4e24d573019c0b4a9aa0190ac65552b25abb35cddc1b60261420d631	2026-08-11 14:32:15.281497+05:30	2026-09-10 14:32:15.28134+05:30	2026-08-11 14:32:15.694255+05:30	2026-08-11 14:32:15.694255+05:30	node
1048	5	c5cfd487b7ba07b98cdcc8bd60e462306339a17b47954964ddb1757352697a53	2026-08-11 14:32:21.101244+05:30	2026-09-10 14:32:21.10093+05:30	\N	\N	node
1075	17	5ec8944f6cb60a220ee109a11a2098856089df74a81d35b5af344398329419bc	2026-08-11 14:32:37.635653+05:30	2026-09-10 14:32:37.635359+05:30	\N	\N	node
1083	18	096cd15c99762627ad85357a251dc0b21483e2eba0db4baaba2c3c290c312286	2026-08-11 14:32:41.63872+05:30	2026-09-10 14:32:41.638443+05:30	\N	\N	node
1084	18	6a2f670aeadb522c13fd14a5f22a5976a6e7bbcd3a19ffde7beeae69927014e3	2026-08-11 14:32:42.212612+05:30	2026-09-10 14:32:42.212409+05:30	\N	\N	node
1103	18	c552b9dbbdbcb8b04ff853d3dbe1b2a57722ea27b7e5db7e809e0148a43ce9d3	2026-08-11 14:33:01.32197+05:30	2026-09-10 14:33:01.321799+05:30	\N	\N	node
1043	1	aa5a935d1afc48eb5821257b7c602cf58aebcc37fc34423d4b29debaf44e696c	2026-08-11 14:32:16.479481+05:30	2026-09-10 14:32:16.479229+05:30	\N	2026-08-11 14:32:18.378911+05:30	node
1051	7	582877aa909cd185c8f0acdad981aca7f0ca3dafa5e7a960857b085b82786f2c	2026-08-11 14:32:22.473327+05:30	2026-09-10 14:32:22.473166+05:30	\N	\N	node
1052	8	d207203e3932f8bdaccf3844fd0b9629e23d1d8f0ae7d40fd597e3d8d8649d40	2026-08-11 14:32:23.269527+05:30	2026-09-10 14:32:23.269261+05:30	\N	\N	node
1062	17	43df6694f0a760bbde4c8511ecd06eb17b67acdb5492141e3f38ad43992b0bf1	2026-08-11 14:32:30.087056+05:30	2026-09-10 14:32:30.08686+05:30	\N	\N	node
1067	18	d3be2f7b9222ffeb5af888a372c88f9765d235b97433d03c216772bd5a8ad9a2	2026-08-11 14:32:32.928122+05:30	2026-09-10 14:32:32.927916+05:30	\N	\N	node
1070	250	64b7c24c07205fa5920df54349638ad39e18f024015153129d99a2aa98110459	2026-08-11 14:32:35.584956+05:30	2026-09-10 14:32:35.584573+05:30	\N	\N	node
1076	18	102429e7df9f3431ca396ee2f60f396b3df5a49255e478e5afa55e967ed892aa	2026-08-11 14:32:38.115762+05:30	2026-09-10 14:32:38.115574+05:30	\N	\N	node
1098	17	118d12122a3f9c96bb41979e16a64213f6b5d0b36412fd690313e406b97d277c	2026-08-11 14:32:50.458358+05:30	2026-09-10 14:32:50.458136+05:30	\N	\N	node
1101	20	12f8d5ed1880d4805beff223b3a285722f9712c1137a3f35fb7c94802ad95ccc	2026-08-11 14:32:59.389794+05:30	2026-09-10 14:32:59.389568+05:30	\N	\N	node
1044	1	084de0fa55d9ae8503e9ab1b608e89aedfd4bdac8bdb5e41410ed97da65d4367	2026-08-11 14:32:16.493243+05:30	2026-09-10 14:32:16.492976+05:30	\N	2026-08-11 14:32:18.378911+05:30	node
1054	248	265c5ac59fca0305aac269f470dc422e8b39441c54964ce56df2425faf2521b1	2026-08-11 14:32:24.640999+05:30	2026-09-10 14:32:24.640759+05:30	\N	\N	node
1059	17	6a9e6e333a699dd3c1ca7548af2abc72fbb6d70f2a352a699052414c09317826	2026-08-11 14:32:28.101203+05:30	2026-09-10 14:32:28.100948+05:30	\N	\N	node
1064	17	9e622e3818f958208345c8e573fc2395638dec3fcb042206857ac3c4f89081f1	2026-08-11 14:32:30.965381+05:30	2026-09-10 14:32:30.965107+05:30	\N	\N	node
1068	251	c08054612e0dbd1f65375ceea3e37e6bcacba6bf8d9c7c982ccc8e8535752268	2026-08-11 14:32:33.840517+05:30	2026-09-10 14:32:33.840251+05:30	\N	\N	node
1071	18	12c8eb6c28dda8c005e216ff17b232d9ed88108e2e49e5470a8aacc29f85c0fe	2026-08-11 14:32:35.933799+05:30	2026-09-10 14:32:35.933503+05:30	\N	\N	node
1080	252	782e2932b8ac9bdd630688bb525ad96d765e69628d9300433a7e226645ce68a8	2026-08-11 14:32:40.334376+05:30	2026-09-10 14:32:40.334128+05:30	\N	\N	node
1091	17	0af8a952ddeef891d750f91f9d3b7064b50615b4f6e1663615227078e510dc5f	2026-08-11 14:32:46.225871+05:30	2026-09-10 14:32:46.225609+05:30	\N	\N	node
1097	18	8dd49a23b1e12b18af327f8758c25cd0f78bf60fa227fac250183b5722726f44	2026-08-11 14:32:49.558079+05:30	2026-09-10 14:32:49.557905+05:30	\N	\N	node
1104	17	86ce943bbbdbf50dee7112dbcd5560a94b15e23a2bdb51c61c1db903df49b928	2026-08-11 14:33:02.045361+05:30	2026-09-10 14:33:02.0451+05:30	\N	\N	node
1099	1	ba20bbd79960c1e32ad829b2dd67d5d8d3c80cc1d9ecaf52fd22496831f4e766	2026-08-11 14:32:53.318551+05:30	2026-09-10 14:32:53.318201+05:30	\N	2026-08-11 15:10:02.742418+05:30	node
1047	1	da045cac145f4bb216642fe6e2c5f51e467fa22bf77e82624084ad925746864d	2026-08-11 14:32:18.369015+05:30	2026-09-10 14:32:18.368783+05:30	\N	2026-08-11 14:32:18.378911+05:30	node
1049	3	72d8fb0bad69358add2f2a8b2aa35e2ac298024b1e3b1da3d9f40ba9d00b4bb2	2026-08-11 14:32:21.755164+05:30	2026-09-10 14:32:21.7549+05:30	\N	\N	node
1058	18	e7f54de38f24822ead7632797d9d997ffcfbaa94c2b6ff0be52beb623404979d	2026-08-11 14:32:27.121548+05:30	2026-09-10 14:32:27.121374+05:30	\N	\N	node
1060	18	494016b308a59b4b7baa4da0d891d1c37821b9de707d4eb330bfcd5881b60817	2026-08-11 14:32:28.45183+05:30	2026-09-10 14:32:28.451565+05:30	\N	\N	node
1063	18	b8fa3e9b0cd1f7f862b62cdeb815def531ca997d07e55bf417d43395cc87c039	2026-08-11 14:32:30.566318+05:30	2026-09-10 14:32:30.566082+05:30	\N	\N	node
1072	17	16404a9a144206bbe551edd21169407d307f5270ca90371ec07e7c352d7a5a48	2026-08-11 14:32:36.511393+05:30	2026-09-10 14:32:36.511109+05:30	\N	\N	node
1081	18	42e545139d76220335bb90d2732e9d687cf1fe3fe91db2470a92587ab7b5769e	2026-08-11 14:32:40.670677+05:30	2026-09-10 14:32:40.670502+05:30	\N	\N	node
1088	17	b252b689f8e589c889919e600f2dd1a573bfb830fb6b87c6fddc3370f79cfaba	2026-08-11 14:32:44.819668+05:30	2026-09-10 14:32:44.819379+05:30	\N	\N	node
1095	18	44126213f29116e36f793ba1cd2da8302c2c77b9b4d954fdcb55659231231354	2026-08-11 14:32:48.701641+05:30	2026-09-10 14:32:48.701309+05:30	\N	\N	node
1111	19	66d4dc5c18a23aea1f20d86f5c38e69359ba76835ffd2ec03052fd62d7e56f7d	2026-08-11 14:33:06.365706+05:30	2026-09-10 14:33:06.365382+05:30	\N	\N	node
1112	18	f6c7855bf4f4d550a3681d5d035e0e55e5503e8c823c0a2d357eb914adcf0463	2026-08-11 14:33:06.896026+05:30	2026-09-10 14:33:06.895772+05:30	\N	\N	node
1113	1	61dfe187b5c761ebf3ee02ddb3ef05b102136a85b9ac99a5a5bc429da4139afb	2026-08-11 15:09:59.586233+05:30	2026-09-10 15:09:59.585977+05:30	2026-08-11 15:10:00.084903+05:30	2026-08-11 15:10:00.084903+05:30	node
1115	1	1fa08e3dc619c0676ec0bb4042c41fb8d251ebf5435d13c9de7175b9f7b0c3e0	2026-08-11 15:10:00.492019+05:30	2026-09-10 15:10:00.491858+05:30	2026-08-11 15:10:00.836491+05:30	2026-08-11 15:10:00.836491+05:30	node
1116	1	35baaa6d1187bb0e3c3c2c6cb7da24840cb584e61c39faf06a56c7c0f7f324a6	2026-08-11 15:10:00.827997+05:30	2026-09-10 15:10:00.827781+05:30	2026-08-11 15:10:00.845767+05:30	2026-08-11 15:10:00.845767+05:30	node
1119	2	034bb95419d096bafb6ddf76539e51f14afd66ace4266e09c80d6c880ccbcaeb	2026-08-11 15:10:01.471018+05:30	2026-09-10 15:10:01.470844+05:30	\N	\N	node
1114	1	0f668405f8ca131104bf40a24d0846136caba158b7e6714f0d7d3f020e133fa5	2026-08-11 15:10:00.140161+05:30	2026-09-10 15:10:00.139996+05:30	\N	2026-08-11 15:10:02.742418+05:30	node
1117	1	bf91ce3629a79e77d6928fd0d7152830e3b9bd5a48f97696ca4ecffe7426fea8	2026-08-11 15:10:00.83898+05:30	2026-09-10 15:10:00.83878+05:30	\N	2026-08-11 15:10:02.742418+05:30	node
1118	1	f834076492f3612122da56d4aea4bbc85628b65244dbad77ee3d943edccb3ab1	2026-08-11 15:10:00.848047+05:30	2026-09-10 15:10:00.847889+05:30	\N	2026-08-11 15:10:02.742418+05:30	node
1120	1	5dce664ce27e96048f1d27cb16862341d21eb6ed111fc59f0cb7b4b22418fc2b	2026-08-11 15:10:02.34695+05:30	2026-09-10 15:10:02.346727+05:30	\N	2026-08-11 15:10:02.742418+05:30	node
1121	1	29cd4e15787b57c14e9fda983b856509173729ed27b25bb9ba2444d34d2feda5	2026-08-11 15:10:02.735481+05:30	2026-09-10 15:10:02.735182+05:30	\N	2026-08-11 15:10:02.742418+05:30	node
1122	5	372d5c27faa39254492d3be312643678fe9d69049052039647e90435799b33d7	2026-08-11 15:10:05.346016+05:30	2026-09-10 15:10:05.345826+05:30	\N	\N	node
1123	3	60361a261b0b619c6baa154a33c16d168e4721ae2e796d32dd094bb5a9de2241	2026-08-11 15:10:05.827995+05:30	2026-09-10 15:10:05.82777+05:30	\N	\N	node
1124	3	7232c3c9e311e64f7d91357b9fe3acab71931c95d6ee13b4288120d44ba26ff8	2026-08-11 15:10:06.14661+05:30	2026-09-10 15:10:06.146407+05:30	\N	\N	node
1125	7	e60cba9b177e38d7d87f9763071425b867662ad83b0a88c84990f9b3ed4a32c2	2026-08-11 15:10:06.635922+05:30	2026-09-10 15:10:06.635673+05:30	\N	\N	node
1126	8	1840099c8016cf9707f3773489cec88da4393cd3f7ec1aeb32b1060c786e0812	2026-08-11 15:10:07.290789+05:30	2026-09-10 15:10:07.290539+05:30	\N	\N	node
1127	17	b1b56b26d454605d46cb3d1492343101e702e6c1a1ee54d92dd622a0861ee15b	2026-08-11 15:10:07.768968+05:30	2026-09-10 15:10:07.768724+05:30	\N	\N	node
1128	254	0a9fed625a19ef8230e4c02911412ec00a9df476d7e1ae33af5e7e196456f03c	2026-08-11 15:10:08.567327+05:30	2026-09-10 15:10:08.566719+05:30	\N	\N	node
1129	17	16d82fabf51d8dd04fea745aee5b0e52c700ef8437e3087ff3e3e9ee93adf651	2026-08-11 15:10:08.9351+05:30	2026-09-10 15:10:08.934872+05:30	\N	\N	node
1130	254	b2d1e3fe5ba1c871f629be0416b158669f31037b094dc23acfda918215e9c163	2026-08-11 15:10:10.367673+05:30	2026-09-10 15:10:10.367282+05:30	\N	\N	node
1131	17	378c19a63ea914f277ad505af225fcf8644dd796b09550264352df8cf4898430	2026-08-11 15:10:10.703209+05:30	2026-09-10 15:10:10.702997+05:30	\N	\N	node
1132	18	cc0c8a43d5ccf8113b366644914d031b65705a258530f681451a026e3d024a57	2026-08-11 15:10:11.099168+05:30	2026-09-10 15:10:11.098985+05:30	\N	\N	node
1133	17	1da31f19ce9ab3a3bd9b9410906d7bc4143f3c61149d5ec29068758dc66e1206	2026-08-11 15:10:11.903793+05:30	2026-09-10 15:10:11.903625+05:30	\N	\N	node
1134	18	ad30ddc512d2ff1cc62e333725bc1e94d5d78bed349aeb1c911b5b00a799ff53	2026-08-11 15:10:12.256219+05:30	2026-09-10 15:10:12.255981+05:30	\N	\N	node
1135	17	0051cc9c7149b194d448fcc98ce2861ed7bf04ac2cc884c634e472b06c1e69d2	2026-08-11 15:10:13.488201+05:30	2026-09-10 15:10:13.488045+05:30	\N	\N	node
1136	17	d7b5b4a8ba34ab18bb68a32c08476c63661043854e4120376e89c0031e6edaaa	2026-08-11 15:10:13.820921+05:30	2026-09-10 15:10:13.820632+05:30	\N	\N	node
1137	18	c3b5d00f9dcd3a02f526a0284b8e76e990ffd9ccd36f074a72eb8405065901ec	2026-08-11 15:10:14.371798+05:30	2026-09-10 15:10:14.37157+05:30	\N	\N	node
1138	17	4503219c765af0e64ee3256235bae1addd9f5d7fc82ce6d6db8b10246b0724d9	2026-08-11 15:10:14.801444+05:30	2026-09-10 15:10:14.801131+05:30	\N	\N	node
1139	18	b283d5f8683bd7112195633fe6323bacc0b4781dca9edfebb8ed0e63325fe775	2026-08-11 15:10:15.148207+05:30	2026-09-10 15:10:15.148004+05:30	\N	\N	node
1140	256	cd3d34d0cfe944e2987e72b79f60333fadd1262f321f74ee81c5d0f96db61b16	2026-08-11 15:10:16.257664+05:30	2026-09-10 15:10:16.25746+05:30	\N	\N	node
1141	18	6d5b8e1e1c4ad15a1c27cf3d60c9d582db40aec7accafc606055f087fdeb7fbe	2026-08-11 15:10:16.602527+05:30	2026-09-10 15:10:16.602293+05:30	\N	\N	node
1142	257	441b193a61c56d3ed9c50fae7ba2d4a05b4824a3a101606f42dafcd7fe284ef5	2026-08-11 15:10:17.536888+05:30	2026-09-10 15:10:17.536629+05:30	\N	\N	node
1143	18	d7ef1d52baa3afb7a35dccd61b3a22d537f47a1d60316d2c30525e4b07f065c5	2026-08-11 15:10:17.986965+05:30	2026-09-10 15:10:17.986773+05:30	\N	\N	node
1144	256	d268b78d3375c5b006961b467fcccbbc3ce09d8b40037a15269af95ecfaeb965	2026-08-11 15:10:19.160435+05:30	2026-09-10 15:10:19.160189+05:30	\N	\N	node
1145	18	73f61e2ecc0f868febc9244f18b0d11cbc3ccc3e0dc5265a23de0ebd8c4451d6	2026-08-11 15:10:19.563625+05:30	2026-09-10 15:10:19.563408+05:30	\N	\N	node
1146	17	8f74ba9f097f48e8bb39eaedbde4d10dd1d94def981df3435d879b8a1fc687a6	2026-08-11 15:10:20.067393+05:30	2026-09-10 15:10:20.066926+05:30	\N	\N	node
1147	18	7dd58fb695595752bdb56ebe3f8f05dd9e07da6a70707f53d8d40f8c1f637ac2	2026-08-11 15:10:20.406319+05:30	2026-09-10 15:10:20.406108+05:30	\N	\N	node
1149	17	52ae1b037a0bf372d91607fcc20cb36f5cbb6106caaef11db6c541b5e893accb	2026-08-11 15:10:21.283979+05:30	2026-09-10 15:10:21.283521+05:30	\N	\N	node
1148	1	6efe7d8d5b163b7c425a8212f6efafba2e5fd7900a64409d851be7a973b119c4	2026-08-11 15:10:20.807525+05:30	2026-09-10 15:10:20.807296+05:30	\N	2026-08-11 15:53:57.819978+05:30	node
1150	18	ab76f8a33cf505041fd83b34be6afd6ce18c6b5ea61599c5f4a5e4d1127dbbc0	2026-08-11 15:10:21.614537+05:30	2026-09-10 15:10:21.614384+05:30	\N	\N	node
1158	18	86203710d859e4734202ea288275d0ab3ecb07018c787f81a6bd25fdf6de79b5	2026-08-11 15:10:25.806625+05:30	2026-09-10 15:10:25.806378+05:30	\N	\N	node
1159	17	f7ef37641b0643b14d3be782c203ce25642e687d637de86421d1122330a045b3	2026-08-11 15:10:26.147312+05:30	2026-09-10 15:10:26.147162+05:30	\N	\N	node
1160	17	14b5cb83491928c4ec6639f1b070d7492bb6ed8844967b5b0296a1b009666bb0	2026-08-11 15:10:26.518947+05:30	2026-09-10 15:10:26.518645+05:30	\N	\N	node
1151	258	b6dd76cb4e2e927b12a127eb63fd2d9a361753772cfcb392d1cedfb7981d3d57	2026-08-11 15:10:22.540826+05:30	2026-09-10 15:10:22.540554+05:30	\N	\N	node
1152	18	eb8490da1032dbdd5a4a6149760d223d72c3b010e6782ba4ab27ab9027dfa188	2026-08-11 15:10:22.896404+05:30	2026-09-10 15:10:22.896247+05:30	\N	\N	node
1153	18	f5ce95217bedd2b9f13083dde44c62c9e1ada4d92fafd0ba699bf9aa79414941	2026-08-11 15:10:23.300357+05:30	2026-09-10 15:10:23.299995+05:30	\N	\N	node
1154	258	ece34ac812b3c8c9e258a8eed97b8e25629f20fec4a59820cf1593723fbb59b3	2026-08-11 15:10:23.83534+05:30	2026-09-10 15:10:23.835073+05:30	\N	\N	node
1155	18	047d355f1d88ae2d0e540b8d40f76390ef4fa41d8d99302262f08ac726d160c0	2026-08-11 15:10:24.33243+05:30	2026-09-10 15:10:24.332178+05:30	\N	\N	node
1156	258	2a0f1ba769bc7bc9a63923f5521610834e9d146742971332391e4ef8cdbc2dcf	2026-08-11 15:10:24.779044+05:30	2026-09-10 15:10:24.778804+05:30	\N	\N	node
1157	18	6f108659929b0f6efc32bff34d9536e37757dae663f61ac33968b9f17b39aca7	2026-08-11 15:10:25.153177+05:30	2026-09-10 15:10:25.152926+05:30	\N	\N	node
1161	259	ecd423e45da5852d48bade0b60eb6410d271a46a18dc0a204c608c384147ed9e	2026-08-11 15:10:27.751759+05:30	2026-09-10 15:10:27.751582+05:30	\N	\N	node
1162	17	3dd1fe9726277956ce5d930c262cd7e472550fff91fce416243b7b35374d3f41	2026-08-11 15:10:28.075587+05:30	2026-09-10 15:10:28.075381+05:30	\N	\N	node
1163	17	046ab1a5124cbaa7ba4a77880399fcf477b0da7a338e9bcc3b213da0262d20fc	2026-08-11 15:10:28.491162+05:30	2026-09-10 15:10:28.490962+05:30	\N	\N	node
1164	259	6d181733e0c6810c127f4f811a8daef2b04e45e6dbc20d71ffa97b0282bb1246	2026-08-11 15:10:28.98863+05:30	2026-09-10 15:10:28.988457+05:30	\N	\N	node
1165	17	a3a3fd43cd5c5b8d42525ce21e508a68eef1bea75f93b3c85bd735a86a6fc631	2026-08-11 15:10:29.333237+05:30	2026-09-10 15:10:29.332844+05:30	\N	\N	node
1166	17	b24aec58fbb415e5885ea49151f4217daef9eb9fb2bc36e21fcf7570520533f4	2026-08-11 15:10:29.748085+05:30	2026-09-10 15:10:29.747917+05:30	\N	\N	node
1167	17	8127963361cd1c5f9edce45134955e4eb9e9175166c1e461b6a62cc972448dfb	2026-08-11 15:10:30.312919+05:30	2026-09-10 15:10:30.312695+05:30	\N	\N	node
1168	18	4f158806da5300707a4018cddb98426615953d2496aca31fbf1606d22bfa08e0	2026-08-11 15:10:30.721231+05:30	2026-09-10 15:10:30.720965+05:30	\N	\N	node
1169	18	88be8b90d93873dfab523a8ae591c3d9f187559d486da0fae630198fd245c311	2026-08-11 15:10:31.731002+05:30	2026-09-10 15:10:31.730823+05:30	\N	\N	node
1170	17	3036b7c5e24a149a2c909dcc9da230891195565a6b8258ce52553512dbee877f	2026-08-11 15:10:32.130535+05:30	2026-09-10 15:10:32.130315+05:30	\N	\N	node
1171	18	e6c547e9ef71b02fce07becf85660f8759b588044ad87515214f2c68b9de1569	2026-08-11 15:10:32.492697+05:30	2026-09-10 15:10:32.492474+05:30	\N	\N	node
1172	17	ced5c02be85470cc60cb22ce4edd047b24d7135904b08974b9c12c659c8e4d68	2026-08-11 15:10:33.295039+05:30	2026-09-10 15:10:33.294794+05:30	\N	\N	node
1174	1	07ea5fa4efc38738f75549bc714110456f19f94516e99d75127f5929cd3767ad	2026-08-11 15:53:54.526101+05:30	2026-09-10 15:53:54.525769+05:30	2026-08-11 15:53:55.265542+05:30	2026-08-11 15:53:55.265542+05:30	node
1176	1	081c05f9b2becf53c1a6a3f8020fca377f2e27ca514c4c2a6c918066322ae6b1	2026-08-11 15:53:55.58484+05:30	2026-09-10 15:53:55.584622+05:30	2026-08-11 15:53:55.958434+05:30	2026-08-11 15:53:55.958434+05:30	node
1177	1	07a4b019fecb957d39fd62130fd51a93f5f99a38ca880e5177b7af3ae9f2b8fa	2026-08-11 15:53:55.951527+05:30	2026-09-10 15:53:55.951367+05:30	2026-08-11 15:53:55.965605+05:30	2026-08-11 15:53:55.965605+05:30	node
1180	2	3f25712e2eb0270bc44627caf6d8a7328b0dbe8114a397d4e9a4d2caa9bfeb0f	2026-08-11 15:53:56.716301+05:30	2026-09-10 15:53:56.716126+05:30	\N	\N	node
1173	1	b2e9ecdab4be0af0efd88b9c068ac9cc46b1baf08f25d6138f34298fe116ee5d	2026-08-11 15:10:35.73455+05:30	2026-09-10 15:10:35.734081+05:30	\N	2026-08-11 15:53:57.819978+05:30	node
1175	1	14de6e6d9170254be00fc9fafa26302eebed2fd7970642e6a54e21d020500a75	2026-08-11 15:53:55.270567+05:30	2026-09-10 15:53:55.270439+05:30	\N	2026-08-11 15:53:57.819978+05:30	node
1178	1	094f6837f98fe9bf4b74c086adbbe7b8ec078eeca669203b324eb07661eaeb5d	2026-08-11 15:53:55.960502+05:30	2026-09-10 15:53:55.960383+05:30	\N	2026-08-11 15:53:57.819978+05:30	node
1179	1	6d85760b8a9ab376ad0193e581be000ff171f773c366dff1a7f4904cb5d8d923	2026-08-11 15:53:55.967396+05:30	2026-09-10 15:53:55.967266+05:30	\N	2026-08-11 15:53:57.819978+05:30	node
1181	1	2ebc2fbc6e774caf1d9814e9385475e58c8bd510372d1cac2ddeabd8f6b443f9	2026-08-11 15:53:57.471946+05:30	2026-09-10 15:53:57.471472+05:30	\N	2026-08-11 15:53:57.819978+05:30	node
1182	1	0f5dc2a1ee6da33615d91c44884722b2f4116f4cfc39d4ccb917ee5b7e569d0a	2026-08-11 15:53:57.813722+05:30	2026-09-10 15:53:57.813544+05:30	\N	2026-08-11 15:53:57.819978+05:30	node
1183	5	6528f166b690ac29e8266b104e597ca362d277b63f0f18ec060118193e6c8032	2026-08-11 15:54:01.048455+05:30	2026-09-10 15:54:01.048258+05:30	\N	\N	node
1184	3	20d7bd9f704d28661e2958c1704dbd7192b34adf79f77a1808df42816477ae53	2026-08-11 15:54:01.62+05:30	2026-09-10 15:54:01.619846+05:30	\N	\N	node
1185	3	687f79a08c0a801c5d30a238c98f3510f30542311482768abfdd32a889bfe822	2026-08-11 15:54:01.990254+05:30	2026-09-10 15:54:01.989945+05:30	\N	\N	node
1186	7	752eef401fe787af72c11fdecc195903c3009a39355538458a17703990225deb	2026-08-11 15:54:02.333243+05:30	2026-09-10 15:54:02.333074+05:30	\N	\N	node
1187	8	4bbb56d046d0e937e3f399b8bba9dce45e722acfb597204c2c031470f8956749	2026-08-11 15:54:03.156178+05:30	2026-09-10 15:54:03.155914+05:30	\N	\N	node
1188	17	d20ad46fc0db8df27e0b6672db8b6b1df86970238d5d23d6a0f2ddf0a015003a	2026-08-11 15:54:03.565502+05:30	2026-09-10 15:54:03.565344+05:30	\N	\N	node
1189	260	91d67815da95cf4273ee99b671fe51550927db93ed7bd166ab33b0f22019c7ea	2026-08-11 15:54:04.397789+05:30	2026-09-10 15:54:04.397552+05:30	\N	\N	node
1190	17	0baae5a21ea38ce69b85efd594c02b1f03688f95818fdae37e06b20cb3713e78	2026-08-11 15:54:04.725575+05:30	2026-09-10 15:54:04.725289+05:30	\N	\N	node
1191	260	60df3e436e076609ae9513aab11fc93dd9ae790d605fa4506279699d67f16e17	2026-08-11 15:54:05.905372+05:30	2026-09-10 15:54:05.905008+05:30	\N	\N	node
1192	17	0a6ac7a52e92424a93ae6bf0a10121f2db1bfa231e0d9b6fbbc6eb426d454940	2026-08-11 15:54:06.232466+05:30	2026-09-10 15:54:06.232292+05:30	\N	\N	node
1193	18	40f9c4f8082501ced7d82ac91b1ba951edb1d9be0306b445c66e8731ec930eb1	2026-08-11 15:54:06.567896+05:30	2026-09-10 15:54:06.567721+05:30	\N	\N	node
1194	17	da91fdfc1fd3ada7d887315a1f2d15e4854fa01983a5dfe4dab26407c40dccf4	2026-08-11 15:54:07.380636+05:30	2026-09-10 15:54:07.38042+05:30	\N	\N	node
1195	18	46f40a8cdfe87cf000c07a8f4c4df475693491f7daa2521227196139167e4ff8	2026-08-11 15:54:07.729533+05:30	2026-09-10 15:54:07.729307+05:30	\N	\N	node
1196	17	f4b7d3a0f787a5ab5ecd5373ecba7542c4f2a3b57595d11f4dfbb3d63487266a	2026-08-11 15:54:08.981235+05:30	2026-09-10 15:54:08.981037+05:30	\N	\N	node
1197	17	f0917eaa9ee39e68dcbc517658ecdeadc035b44c9a231348ee9df2fb8a0a4d74	2026-08-11 15:54:09.362217+05:30	2026-09-10 15:54:09.361966+05:30	\N	\N	node
1198	18	e7804e415c767f6be10b65e1d2dd303722b929a6f24087766607bbb9bf2ccc21	2026-08-11 15:54:09.889403+05:30	2026-09-10 15:54:09.889083+05:30	\N	\N	node
1199	17	911157c4f32318074d537b825b6460c72eba608e036f83391fb2d3caebe23cd7	2026-08-11 15:54:10.295322+05:30	2026-09-10 15:54:10.29513+05:30	\N	\N	node
1200	18	a688122f833f4a35afa7849c255cfa0214889cde90d84d67007c98d7134d0b33	2026-08-11 15:54:10.679463+05:30	2026-09-10 15:54:10.679305+05:30	\N	\N	node
1201	262	d297323bb6c1061c41b6a8dad193170ed2198d37f919d58848a1dd9f74455673	2026-08-11 15:54:11.541415+05:30	2026-09-10 15:54:11.541174+05:30	\N	\N	node
1202	18	56205cd57c0b64201534844047a53026df63b0648cd297cac35efc2bb3621b37	2026-08-11 15:54:11.934818+05:30	2026-09-10 15:54:11.934599+05:30	\N	\N	node
1203	263	05c4d10e8fe528f53b11c8429b328d89a37bf1028a07152921ff322733f03220	2026-08-11 15:54:12.873738+05:30	2026-09-10 15:54:12.873532+05:30	\N	\N	node
1204	18	04b8e672a74093cd6772ed4873c432f1f0a599c9f22ab12cb67ccad6165b261d	2026-08-11 15:54:13.268876+05:30	2026-09-10 15:54:13.26868+05:30	\N	\N	node
1205	262	96c82f1f4efe34c2042e8661aa3b2d61f7f747b12b0825d2d7a56ed7ba59ab01	2026-08-11 15:54:14.467794+05:30	2026-09-10 15:54:14.467549+05:30	\N	\N	node
1206	18	7c92066cde97208ccf9dccdb8b8fec7495ef49a8bf555a82bba09cd832d5c5be	2026-08-11 15:54:14.931039+05:30	2026-09-10 15:54:14.930801+05:30	\N	\N	node
1207	17	d5df1cd7d84284e4895cd1a0db1be3d0abd0ac1aa283d18c471c9b5504d65494	2026-08-11 15:54:15.35576+05:30	2026-09-10 15:54:15.355298+05:30	\N	\N	node
1208	18	e852e3641bb1664d2da435eb559653c6f35a155e0f5f4294dbdd52a90cd93ca2	2026-08-11 15:54:15.723966+05:30	2026-09-10 15:54:15.723631+05:30	\N	\N	node
1210	17	301ceed19f603a5cecd2fc89507a5fa439c445a2f08f6cb1476ba943261aab0d	2026-08-11 15:54:16.489845+05:30	2026-09-10 15:54:16.489535+05:30	\N	\N	node
1211	18	ea9f837400c1387e740ae55ae9a3235a3ec5aa89d0b5cfc6a5b468e4542ff80e	2026-08-11 15:54:16.856469+05:30	2026-09-10 15:54:16.856223+05:30	\N	\N	node
1214	18	53087bdecc1ce7e280dfae9e7bef8e671a4f0cfa1a82d7a94e3e1b528f6143fa	2026-08-11 15:54:18.830705+05:30	2026-09-10 15:54:18.830522+05:30	\N	\N	node
1215	264	7e994fa2cd123515fed8b2ac7d63f53f9b339db51b63851c827006088ef13c08	2026-08-11 15:54:19.36813+05:30	2026-09-10 15:54:19.36794+05:30	\N	\N	node
1216	18	7730da21fe1856311663a24b56964d6e85e423d9cff805cc174ff6b8134bafc3	2026-08-11 15:54:19.722721+05:30	2026-09-10 15:54:19.72232+05:30	\N	\N	node
1217	264	99626bf63aa0b2ba4692acacd845461eed63adce6ee4868194cb94d0b530ef2c	2026-08-11 15:54:20.120855+05:30	2026-09-10 15:54:20.120641+05:30	\N	\N	node
1218	18	3952588663445cd51ed024418eda1ef7be0cd97d3aa00bbaf374fa547ea24997	2026-08-11 15:54:20.522995+05:30	2026-09-10 15:54:20.52269+05:30	\N	\N	node
1224	17	af6f89f5e221442f9b6ac6e28c672419a2c0269610a9581bba7ff77aca1ab66e	2026-08-11 15:54:24.350888+05:30	2026-09-10 15:54:24.350742+05:30	\N	\N	node
1227	17	c0c1a117655bfc87035132808b73385f58bd163ff63b762c34431080cf8ec128	2026-08-11 15:54:25.80835+05:30	2026-09-10 15:54:25.808136+05:30	\N	\N	node
1231	17	520ac4f481feadb00e07ec5fdfac7e0658f7dea7b46b39f40fcd97e29b7eb7ad	2026-08-11 15:54:28.254964+05:30	2026-09-10 15:54:28.25461+05:30	\N	\N	node
1232	18	8337a4bfe1ce034f6e1a28bb402df3c0c2f213a20f16eebe8ec4b34f3de54d9e	2026-08-11 15:54:28.842327+05:30	2026-09-10 15:54:28.842082+05:30	\N	\N	node
1209	1	4dcb38881c9c81382c02b9573d5876838ac347d17c1065828357ce1fa767acd3	2026-08-11 15:54:16.078908+05:30	2026-09-10 15:54:16.078654+05:30	\N	\N	node
1212	264	1a4edf99b167f789c333a7c138fa61687b3c89cf9ee24d8034551dec8d93c234	2026-08-11 15:54:17.699714+05:30	2026-09-10 15:54:17.69949+05:30	\N	\N	node
1213	18	3eff16a3412aeb9077005eb91c390df8791f9ee11603778b91b40f28ecff2cc5	2026-08-11 15:54:18.13941+05:30	2026-09-10 15:54:18.139103+05:30	\N	\N	node
1222	265	2877a34471e805f9240d8a12b2a865ba4810dbbdc1f0e06746168691209a9d6d	2026-08-11 15:54:23.179033+05:30	2026-09-10 15:54:23.178808+05:30	\N	\N	node
1223	17	f1c5aa846c8bbb3f8f07543e19a9a5a96ec335a8fb901e6f4faa43bfe90a5b44	2026-08-11 15:54:23.843021+05:30	2026-09-10 15:54:23.842789+05:30	\N	\N	node
1225	265	009c006080c640f252a69827e45968c533e1dbb3626f81dac73608ba5f760d1f	2026-08-11 15:54:24.8686+05:30	2026-09-10 15:54:24.868443+05:30	\N	\N	node
1226	17	791eb05c954fe56ef3398d2624af17e6f99edb68acd1ced5f5f16c7999967baf	2026-08-11 15:54:25.295208+05:30	2026-09-10 15:54:25.294928+05:30	\N	\N	node
1229	18	21195159965b95a2e12c11affec8cbea1fe4f6a604d5940408d8802ecfbcd0ee	2026-08-11 15:54:26.626213+05:30	2026-09-10 15:54:26.626052+05:30	\N	\N	node
1233	17	87e416bf5709336daafdd59e9d743928f03f1ae3cfea9bcdd034aeb4a3548cf5	2026-08-11 15:54:29.768765+05:30	2026-09-10 15:54:29.768598+05:30	\N	\N	node
1219	18	34da6c2a3a3f399baa45c9f7f75dd444cb1d900253b0484ddb3a7d19b388c333	2026-08-11 15:54:21.300253+05:30	2026-09-10 15:54:21.3001+05:30	\N	\N	node
1220	17	f3c52c40b2ae8292ac5eb5384b5522795ba9bdd1c51a98ab35ca1d70c58c25df	2026-08-11 15:54:21.656304+05:30	2026-09-10 15:54:21.656069+05:30	\N	\N	node
1221	17	c7a97192de39ca50e7da278deed331f411c9fd7dcd98af3be6b658be117e34ae	2026-08-11 15:54:21.982031+05:30	2026-09-10 15:54:21.981839+05:30	\N	\N	node
1228	17	fed7bfb271c2bc535bf5021ade9a0b23ee7b424d5565c76d87bc50a9541a3f55	2026-08-11 15:54:26.277668+05:30	2026-09-10 15:54:26.277516+05:30	\N	\N	node
1230	18	765294cca7ffc94f112b7c220c073157a45031c19d00e4ac25bffd00c5bccb4b	2026-08-11 15:54:27.9106+05:30	2026-09-10 15:54:27.910352+05:30	\N	\N	node
1234	1	c51a7e44e2256cc7c88baccd2fcc39f09381f9432cfe45bad6255eec1022c0ce	2026-08-11 15:54:32.146392+05:30	2026-09-10 15:54:32.146203+05:30	\N	\N	node
1235	18	22bba08de01376e44242168b4a2acf4192af25e39f1bfd8b1663114c4fc9228a	2026-08-12 10:01:47.966669+05:30	2026-09-11 10:01:47.966141+05:30	\N	\N	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36
1236	18	30ce428b7e47c816089774b13d5efae3e43da818d5bc2bebbf12e4e59a0bd8f0	2026-08-12 10:09:55.590228+05:30	2026-09-11 10:09:55.589798+05:30	\N	\N	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/151.0.0.0 Safari/537.36
1237	1	87ed639426d2d76e6d2b98b388ae6ca101d2178ff173173c163c9901026ddb74	2026-08-12 10:10:04.407924+05:30	2026-09-11 10:10:04.407685+05:30	\N	\N	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/151.0.0.0 Safari/537.36
1238	1	909faa4948c31f9a7ffad109c1fdebafe92080107e152ca45dab84ca303763a6	2026-08-12 10:15:07.719609+05:30	2026-09-11 10:15:07.719328+05:30	\N	\N	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36
\.


--
-- TOC entry 5922 (class 0 OID 31345)
-- Dependencies: 283
-- Data for Name: requisition; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.requisition (requisition_id, facility_id, raised_by, requisition_date, status, created_at, updated_at, deleted_at, deleted_by, delete_reason, legacy_id, legacy_source, reviewed_by, reviewed_at, remarks) FROM stdin;
1	1	3	2026-08-09	Partial	2026-08-09 22:35:33.95675+05:30	2026-08-09 22:35:49.234845+05:30	\N	\N	\N	\N	\N	7	2026-08-09 22:35:49.234845+05:30	Approved with one cut; zinc added.
58	1	3	2026-08-10	Partial	2026-08-10 17:31:07.793661+05:30	2026-08-10 17:31:09.09297+05:30	\N	\N	\N	\N	\N	7	2026-08-10 17:31:09.09297+05:30	Cut one line; zinc added.
2	1	3	2026-08-09	Partial	2026-08-09 22:38:21.795425+05:30	2026-08-09 22:38:21.92519+05:30	\N	\N	\N	\N	\N	9	2026-08-09 22:38:21.92519+05:30	Approved with one cut; zinc added.
59	1	3	2026-08-10	Partial	2026-08-10 17:31:41.679566+05:30	2026-08-10 17:31:42.125147+05:30	\N	\N	\N	\N	\N	7	2026-08-10 17:31:42.125147+05:30	Cut one line; zinc added.
4	1	3	2026-08-09	Rejected	2026-08-09 22:38:22.120328+05:30	2026-08-09 22:38:22.150038+05:30	\N	\N	\N	\N	\N	9	2026-08-09 22:38:22.150038+05:30	
3	1	3	2026-08-09	Received	2026-08-09 22:38:22.055541+05:30	2026-08-09 22:38:22.159984+05:30	\N	\N	\N	\N	\N	9	2026-08-09 22:38:22.103477+05:30	
60	1	3	2026-08-10	Partial	2026-08-10 17:35:03.699421+05:30	2026-08-10 17:35:04.748118+05:30	\N	\N	\N	\N	\N	7	2026-08-10 17:35:04.748118+05:30	Cut one line; zinc added.
5	1	3	2026-08-09	Partial	2026-08-09 22:38:22.182167+05:30	2026-08-09 22:38:22.252708+05:30	\N	\N	\N	\N	\N	9	2026-08-09 22:38:22.239182+05:30	
61	1	3	2026-08-10	Partial	2026-08-10 17:39:14.785471+05:30	2026-08-10 17:39:16.157673+05:30	\N	\N	\N	\N	\N	7	2026-08-10 17:39:16.157673+05:30	Cut one line; zinc added.
6	1	3	2026-08-09	Partial	2026-08-09 22:52:49.730128+05:30	2026-08-09 22:52:49.880386+05:30	\N	\N	\N	\N	\N	11	2026-08-09 22:52:49.880386+05:30	Approved with one cut; zinc added.
62	1	3	2026-08-10	Partial	2026-08-10 17:42:42.520011+05:30	2026-08-10 17:42:42.614759+05:30	\N	\N	\N	\N	\N	52	2026-08-10 17:42:42.614759+05:30	Approved with one cut; zinc added.
8	1	3	2026-08-09	Rejected	2026-08-09 22:52:50.049238+05:30	2026-08-09 22:52:50.109312+05:30	\N	\N	\N	\N	\N	11	2026-08-09 22:52:50.109312+05:30	
7	1	3	2026-08-09	Received	2026-08-09 22:52:49.942214+05:30	2026-08-09 22:52:50.128923+05:30	\N	\N	\N	\N	\N	11	2026-08-09 22:52:50.032313+05:30	
9	1	3	2026-08-09	Partial	2026-08-09 22:52:50.144428+05:30	2026-08-09 22:52:50.226498+05:30	\N	\N	\N	\N	\N	11	2026-08-09 22:52:50.181746+05:30	
64	1	3	2026-08-10	Rejected	2026-08-10 17:42:42.770872+05:30	2026-08-10 17:42:42.834665+05:30	\N	\N	\N	\N	\N	52	2026-08-10 17:42:42.834665+05:30	
10	1	3	2026-08-09	Partial	2026-08-09 23:13:43.168373+05:30	2026-08-09 23:13:43.68591+05:30	\N	\N	\N	\N	\N	7	2026-08-09 23:13:43.68591+05:30	Cut one line; zinc added.
63	1	3	2026-08-10	Received	2026-08-10 17:42:42.632037+05:30	2026-08-10 17:42:42.857054+05:30	\N	\N	\N	\N	\N	52	2026-08-10 17:42:42.751124+05:30	
11	1	3	2026-08-09	Partial	2026-08-09 23:16:24.517487+05:30	2026-08-09 23:16:24.92054+05:30	\N	\N	\N	\N	\N	7	2026-08-09 23:16:24.92054+05:30	Cut one line; zinc added.
12	1	3	2026-08-09	Partial	2026-08-09 23:16:55.291321+05:30	2026-08-09 23:16:55.707293+05:30	\N	\N	\N	\N	\N	7	2026-08-09 23:16:55.707293+05:30	Cut one line; zinc added.
13	1	3	2026-08-09	Partial	2026-08-09 23:17:00.797942+05:30	2026-08-09 23:17:00.948408+05:30	\N	\N	\N	\N	\N	13	2026-08-09 23:17:00.948408+05:30	Approved with one cut; zinc added.
15	1	3	2026-08-09	Rejected	2026-08-09 23:17:01.029421+05:30	2026-08-09 23:17:01.075902+05:30	\N	\N	\N	\N	\N	13	2026-08-09 23:17:01.075902+05:30	
14	1	3	2026-08-09	Received	2026-08-09 23:17:00.974233+05:30	2026-08-09 23:17:01.098773+05:30	\N	\N	\N	\N	\N	13	2026-08-09 23:17:01.014581+05:30	
16	1	3	2026-08-09	Partial	2026-08-09 23:17:01.117708+05:30	2026-08-09 23:17:01.180947+05:30	\N	\N	\N	\N	\N	13	2026-08-09 23:17:01.155508+05:30	
17	1	3	2026-08-09	Partial	2026-08-09 23:40:20.281732+05:30	2026-08-09 23:40:20.868794+05:30	\N	\N	\N	\N	\N	7	2026-08-09 23:40:20.868794+05:30	Cut one line; zinc added.
18	1	3	2026-08-09	Partial	2026-08-09 23:40:25.804091+05:30	2026-08-09 23:40:25.943495+05:30	\N	\N	\N	\N	\N	15	2026-08-09 23:40:25.943495+05:30	Approved with one cut; zinc added.
20	1	3	2026-08-09	Rejected	2026-08-09 23:40:26.047244+05:30	2026-08-09 23:40:26.097871+05:30	\N	\N	\N	\N	\N	15	2026-08-09 23:40:26.097871+05:30	
19	1	3	2026-08-09	Received	2026-08-09 23:40:25.988608+05:30	2026-08-09 23:40:26.157182+05:30	\N	\N	\N	\N	\N	15	2026-08-09 23:40:26.02798+05:30	
21	1	3	2026-08-09	Partial	2026-08-09 23:40:26.177417+05:30	2026-08-09 23:40:26.229048+05:30	\N	\N	\N	\N	\N	15	2026-08-09 23:40:26.211281+05:30	
22	1	3	2026-08-09	Partial	2026-08-09 23:54:37.678893+05:30	2026-08-09 23:54:38.201204+05:30	\N	\N	\N	\N	\N	7	2026-08-09 23:54:38.201204+05:30	Cut one line; zinc added.
23	1	3	2026-08-10	Partial	2026-08-10 11:09:21.014895+05:30	2026-08-10 11:09:21.161145+05:30	\N	\N	\N	\N	\N	21	2026-08-10 11:09:21.161145+05:30	Approved with one cut; zinc added.
25	1	3	2026-08-10	Rejected	2026-08-10 11:09:21.260111+05:30	2026-08-10 11:09:21.280567+05:30	\N	\N	\N	\N	\N	21	2026-08-10 11:09:21.280567+05:30	
24	1	3	2026-08-10	Received	2026-08-10 11:09:21.219181+05:30	2026-08-10 11:09:21.291926+05:30	\N	\N	\N	\N	\N	21	2026-08-10 11:09:21.242324+05:30	
26	1	3	2026-08-10	Partial	2026-08-10 11:09:21.300855+05:30	2026-08-10 11:09:21.349256+05:30	\N	\N	\N	\N	\N	21	2026-08-10 11:09:21.3236+05:30	
27	1	3	2026-08-10	Partial	2026-08-10 11:10:01.594539+05:30	2026-08-10 11:10:02.111915+05:30	\N	\N	\N	\N	\N	7	2026-08-10 11:10:02.111915+05:30	Cut one line; zinc added.
28	1	3	2026-08-10	Partial	2026-08-10 11:41:56.436249+05:30	2026-08-10 11:41:56.682981+05:30	\N	\N	\N	\N	\N	23	2026-08-10 11:41:56.682981+05:30	Approved with one cut; zinc added.
30	1	3	2026-08-10	Rejected	2026-08-10 11:41:56.738705+05:30	2026-08-10 11:41:56.759889+05:30	\N	\N	\N	\N	\N	23	2026-08-10 11:41:56.759889+05:30	
29	1	3	2026-08-10	Received	2026-08-10 11:41:56.705642+05:30	2026-08-10 11:41:56.771756+05:30	\N	\N	\N	\N	\N	23	2026-08-10 11:41:56.726533+05:30	
31	1	3	2026-08-10	Partial	2026-08-10 11:41:56.782538+05:30	2026-08-10 11:41:56.820085+05:30	\N	\N	\N	\N	\N	23	2026-08-10 11:41:56.800601+05:30	
32	1	3	2026-08-10	Partial	2026-08-10 11:42:09.491659+05:30	2026-08-10 11:42:09.947512+05:30	\N	\N	\N	\N	\N	7	2026-08-10 11:42:09.947512+05:30	Cut one line; zinc added.
33	1	3	2026-08-10	Partial	2026-08-10 16:34:49.83258+05:30	2026-08-10 16:34:50.504957+05:30	\N	\N	\N	\N	\N	7	2026-08-10 16:34:50.504957+05:30	Cut one line; zinc added.
34	1	3	2026-08-10	Partial	2026-08-10 16:35:01.709903+05:30	2026-08-10 16:35:02.403687+05:30	\N	\N	\N	\N	\N	7	2026-08-10 16:35:02.403687+05:30	Cut one line; zinc added.
35	1	3	2026-08-10	Partial	2026-08-10 16:36:12.723275+05:30	2026-08-10 16:36:12.955993+05:30	\N	\N	\N	\N	\N	29	2026-08-10 16:36:12.955993+05:30	Approved with one cut; zinc added.
37	1	3	2026-08-10	Rejected	2026-08-10 16:36:13.023741+05:30	2026-08-10 16:36:13.047314+05:30	\N	\N	\N	\N	\N	29	2026-08-10 16:36:13.047314+05:30	
36	1	3	2026-08-10	Received	2026-08-10 16:36:12.971325+05:30	2026-08-10 16:36:13.14262+05:30	\N	\N	\N	\N	\N	29	2026-08-10 16:36:13.012093+05:30	
38	1	3	2026-08-10	Partial	2026-08-10 16:36:13.159746+05:30	2026-08-10 16:36:13.259176+05:30	\N	\N	\N	\N	\N	29	2026-08-10 16:36:13.190314+05:30	
39	1	3	2026-08-10	Partial	2026-08-10 16:36:27.892318+05:30	2026-08-10 16:36:28.390843+05:30	\N	\N	\N	\N	\N	7	2026-08-10 16:36:28.390843+05:30	Cut one line; zinc added.
40	1	3	2026-08-10	Partial	2026-08-10 16:38:13.694601+05:30	2026-08-10 16:38:13.784469+05:30	\N	\N	\N	\N	\N	35	2026-08-10 16:38:13.784469+05:30	Approved with one cut; zinc added.
42	1	3	2026-08-10	Rejected	2026-08-10 16:38:13.846521+05:30	2026-08-10 16:38:13.890594+05:30	\N	\N	\N	\N	\N	35	2026-08-10 16:38:13.890594+05:30	
41	1	3	2026-08-10	Received	2026-08-10 16:38:13.809444+05:30	2026-08-10 16:38:13.906144+05:30	\N	\N	\N	\N	\N	35	2026-08-10 16:38:13.831313+05:30	
43	1	3	2026-08-10	Partial	2026-08-10 16:38:13.921483+05:30	2026-08-10 16:38:13.981515+05:30	\N	\N	\N	\N	\N	35	2026-08-10 16:38:13.966841+05:30	
44	1	3	2026-08-10	Partial	2026-08-10 16:38:29.350694+05:30	2026-08-10 16:38:30.148491+05:30	\N	\N	\N	\N	\N	7	2026-08-10 16:38:30.148491+05:30	Cut one line; zinc added.
45	1	3	2026-08-10	Partial	2026-08-10 16:51:28.323678+05:30	2026-08-10 16:51:29.046179+05:30	\N	\N	\N	\N	\N	7	2026-08-10 16:51:29.046179+05:30	Cut one line; zinc added.
46	1	3	2026-08-10	Partial	2026-08-10 16:56:43.690128+05:30	2026-08-10 16:56:44.117293+05:30	\N	\N	\N	\N	\N	7	2026-08-10 16:56:44.117293+05:30	Cut one line; zinc added.
47	1	3	2026-08-10	Partial	2026-08-10 16:57:03.912638+05:30	2026-08-10 16:57:03.990101+05:30	\N	\N	\N	\N	\N	41	2026-08-10 16:57:03.990101+05:30	Approved with one cut; zinc added.
49	1	3	2026-08-10	Rejected	2026-08-10 16:57:04.045211+05:30	2026-08-10 16:57:04.071243+05:30	\N	\N	\N	\N	\N	41	2026-08-10 16:57:04.071243+05:30	
48	1	3	2026-08-10	Received	2026-08-10 16:57:04.009843+05:30	2026-08-10 16:57:04.140475+05:30	\N	\N	\N	\N	\N	41	2026-08-10 16:57:04.03343+05:30	
50	1	3	2026-08-10	Partial	2026-08-10 16:57:04.15092+05:30	2026-08-10 16:57:04.206964+05:30	\N	\N	\N	\N	\N	41	2026-08-10 16:57:04.19541+05:30	
51	1	3	2026-08-10	Partial	2026-08-10 16:57:17.040104+05:30	2026-08-10 16:57:17.499685+05:30	\N	\N	\N	\N	\N	7	2026-08-10 16:57:17.499685+05:30	Cut one line; zinc added.
52	1	3	2026-08-10	Partial	2026-08-10 17:14:06.280401+05:30	2026-08-10 17:14:06.815896+05:30	\N	\N	\N	\N	\N	7	2026-08-10 17:14:06.815896+05:30	Cut one line; zinc added.
53	1	3	2026-08-10	Partial	2026-08-10 17:14:36.7147+05:30	2026-08-10 17:14:36.834167+05:30	\N	\N	\N	\N	\N	45	2026-08-10 17:14:36.834167+05:30	Approved with one cut; zinc added.
55	1	3	2026-08-10	Rejected	2026-08-10 17:14:36.927635+05:30	2026-08-10 17:14:36.975972+05:30	\N	\N	\N	\N	\N	45	2026-08-10 17:14:36.975972+05:30	
54	1	3	2026-08-10	Received	2026-08-10 17:14:36.880215+05:30	2026-08-10 17:14:37.002714+05:30	\N	\N	\N	\N	\N	45	2026-08-10 17:14:36.910614+05:30	
56	1	3	2026-08-10	Partial	2026-08-10 17:14:37.058587+05:30	2026-08-10 17:14:37.096912+05:30	\N	\N	\N	\N	\N	45	2026-08-10 17:14:37.079533+05:30	
57	1	3	2026-08-10	Partial	2026-08-10 17:14:55.110193+05:30	2026-08-10 17:14:55.800752+05:30	\N	\N	\N	\N	\N	7	2026-08-10 17:14:55.800752+05:30	Cut one line; zinc added.
65	1	3	2026-08-10	Partial	2026-08-10 17:42:42.889853+05:30	2026-08-10 17:42:42.95485+05:30	\N	\N	\N	\N	\N	52	2026-08-10 17:42:42.922356+05:30	
66	1	3	2026-08-10	Partial	2026-08-10 17:43:01.540336+05:30	2026-08-10 17:43:02.044755+05:30	\N	\N	\N	\N	\N	7	2026-08-10 17:43:02.044755+05:30	Cut one line; zinc added.
67	1	3	2026-08-10	Partial	2026-08-10 17:52:59.227463+05:30	2026-08-10 17:53:00.544788+05:30	\N	\N	\N	\N	\N	7	2026-08-10 17:53:00.544788+05:30	Cut one line; zinc added.
68	1	3	2026-08-10	Partial	2026-08-10 18:00:18.736023+05:30	2026-08-10 18:00:19.572704+05:30	\N	\N	\N	\N	\N	7	2026-08-10 18:00:19.572704+05:30	Cut one line; zinc added.
69	1	3	2026-08-10	Partial	2026-08-10 18:00:41.119855+05:30	2026-08-10 18:00:41.849188+05:30	\N	\N	\N	\N	\N	7	2026-08-10 18:00:41.849188+05:30	Cut one line; zinc added.
70	1	18	2026-08-10	Requested	2026-08-10 18:06:46.536373+05:30	2026-08-10 18:06:46.536373+05:30	\N	\N	\N	\N	\N	\N	\N	
71	1	3	2026-08-10	Partial	2026-08-10 19:16:17.764001+05:30	2026-08-10 19:16:18.556757+05:30	\N	\N	\N	\N	\N	7	2026-08-10 19:16:18.556757+05:30	Cut one line; zinc added.
72	1	3	2026-08-10	Partial	2026-08-10 19:16:42.489361+05:30	2026-08-10 19:16:43.048067+05:30	\N	\N	\N	\N	\N	7	2026-08-10 19:16:43.048067+05:30	Cut one line; zinc added.
73	1	3	2026-08-10	Partial	2026-08-10 19:35:50.955032+05:30	2026-08-10 19:35:52.029054+05:30	\N	\N	\N	\N	\N	7	2026-08-10 19:35:52.029054+05:30	Cut one line; zinc added.
74	1	3	2026-08-10	Partial	2026-08-10 19:39:44.141524+05:30	2026-08-10 19:39:44.831035+05:30	\N	\N	\N	\N	\N	7	2026-08-10 19:39:44.831035+05:30	Cut one line; zinc added.
75	1	3	2026-08-10	Partial	2026-08-10 19:41:08.758697+05:30	2026-08-10 19:41:11.292018+05:30	\N	\N	\N	\N	\N	7	2026-08-10 19:41:11.292018+05:30	Cut one line; zinc added.
76	1	3	2026-08-10	Partial	2026-08-10 19:41:53.477818+05:30	2026-08-10 19:41:54.071388+05:30	\N	\N	\N	\N	\N	7	2026-08-10 19:41:54.071388+05:30	Cut one line; zinc added.
77	1	3	2026-08-10	Partial	2026-08-10 20:18:58.534834+05:30	2026-08-10 20:18:59.072763+05:30	\N	\N	\N	\N	\N	7	2026-08-10 20:18:59.072763+05:30	Cut one line; zinc added.
78	1	3	2026-08-10	Partial	2026-08-10 20:22:52.46761+05:30	2026-08-10 20:22:52.943887+05:30	\N	\N	\N	\N	\N	7	2026-08-10 20:22:52.943887+05:30	Cut one line; zinc added.
79	1	3	2026-08-10	Partial	2026-08-10 20:34:33.873847+05:30	2026-08-10 20:34:34.394888+05:30	\N	\N	\N	\N	\N	7	2026-08-10 20:34:34.394888+05:30	Cut one line; zinc added.
80	1	3	2026-08-10	Partial	2026-08-10 20:47:40.248497+05:30	2026-08-10 20:47:40.747469+05:30	\N	\N	\N	\N	\N	7	2026-08-10 20:47:40.747469+05:30	Cut one line; zinc added.
81	1	3	2026-08-10	Partial	2026-08-10 21:13:43.749218+05:30	2026-08-10 21:13:44.340046+05:30	\N	\N	\N	\N	\N	7	2026-08-10 21:13:44.340046+05:30	Cut one line; zinc added.
82	1	3	2026-08-10	Partial	2026-08-10 21:20:10.835393+05:30	2026-08-10 21:20:11.35224+05:30	\N	\N	\N	\N	\N	7	2026-08-10 21:20:11.35224+05:30	Cut one line; zinc added.
83	1	3	2026-08-10	Partial	2026-08-10 21:38:15.516633+05:30	2026-08-10 21:38:16.422879+05:30	\N	\N	\N	\N	\N	7	2026-08-10 21:38:16.422879+05:30	Cut one line; zinc added.
84	1	3	2026-08-10	Partial	2026-08-10 21:48:50.966379+05:30	2026-08-10 21:48:51.4549+05:30	\N	\N	\N	\N	\N	7	2026-08-10 21:48:51.4549+05:30	Cut one line; zinc added.
85	1	3	2026-08-11	Partial	2026-08-11 09:30:12.564769+05:30	2026-08-11 09:30:13.267508+05:30	\N	\N	\N	\N	\N	7	2026-08-11 09:30:13.267508+05:30	Cut one line; zinc added.
86	1	3	2026-08-11	Partial	2026-08-11 09:36:14.417437+05:30	2026-08-11 09:36:15.098849+05:30	\N	\N	\N	\N	\N	7	2026-08-11 09:36:15.098849+05:30	Cut one line; zinc added.
87	1	3	2026-08-11	Partial	2026-08-11 09:52:10.72694+05:30	2026-08-11 09:52:11.43045+05:30	\N	\N	\N	\N	\N	7	2026-08-11 09:52:11.43045+05:30	Cut one line; zinc added.
88	1	3	2026-08-11	Partial	2026-08-11 11:14:09.17014+05:30	2026-08-11 11:14:10.159777+05:30	\N	\N	\N	\N	\N	7	2026-08-11 11:14:10.159777+05:30	Cut one line; zinc added.
89	1	3	2026-08-11	Partial	2026-08-11 13:59:28.934586+05:30	2026-08-11 13:59:29.543401+05:30	\N	\N	\N	\N	\N	7	2026-08-11 13:59:29.543401+05:30	Cut one line; zinc added.
90	1	3	2026-08-11	Partial	2026-08-11 14:02:35.546144+05:30	2026-08-11 14:02:36.170363+05:30	\N	\N	\N	\N	\N	7	2026-08-11 14:02:36.170363+05:30	Cut one line; zinc added.
91	1	3	2026-08-11	Partial	2026-08-11 14:03:11.204316+05:30	2026-08-11 14:03:12.027096+05:30	\N	\N	\N	\N	\N	7	2026-08-11 14:03:12.027096+05:30	Cut one line; zinc added.
92	1	3	2026-08-11	Partial	2026-08-11 14:04:17.373831+05:30	2026-08-11 14:04:17.831104+05:30	\N	\N	\N	\N	\N	7	2026-08-11 14:04:17.831104+05:30	Cut one line; zinc added.
93	1	3	2026-08-11	Partial	2026-08-11 14:04:36.402135+05:30	2026-08-11 14:04:37.172834+05:30	\N	\N	\N	\N	\N	7	2026-08-11 14:04:37.172834+05:30	Cut one line; zinc added.
94	1	3	2026-08-11	Partial	2026-08-11 14:05:05.860699+05:30	2026-08-11 14:05:06.393761+05:30	\N	\N	\N	\N	\N	7	2026-08-11 14:05:06.393761+05:30	Cut one line; zinc added.
95	1	3	2026-08-11	Partial	2026-08-11 14:05:47.854385+05:30	2026-08-11 14:05:48.272976+05:30	\N	\N	\N	\N	\N	7	2026-08-11 14:05:48.272976+05:30	Cut one line; zinc added.
96	1	3	2026-08-11	Partial	2026-08-11 14:06:16.893899+05:30	2026-08-11 14:06:17.293406+05:30	\N	\N	\N	\N	\N	7	2026-08-11 14:06:17.293406+05:30	Cut one line; zinc added.
97	1	3	2026-08-11	Partial	2026-08-11 14:06:46.201326+05:30	2026-08-11 14:06:46.583668+05:30	\N	\N	\N	\N	\N	7	2026-08-11 14:06:46.583668+05:30	Cut one line; zinc added.
128	1	3	2026-08-11	Partial	2026-08-11 14:20:34.26918+05:30	2026-08-11 14:20:35.010181+05:30	\N	\N	\N	\N	\N	7	2026-08-11 14:20:35.010181+05:30	Cut one line; zinc added.
129	1	3	2026-08-11	Partial	2026-08-11 14:26:29.342519+05:30	2026-08-11 14:26:30.174058+05:30	\N	\N	\N	\N	\N	7	2026-08-11 14:26:30.174058+05:30	Cut one line; zinc added.
130	1	3	2026-08-11	Partial	2026-08-11 14:31:13.962429+05:30	2026-08-11 14:31:14.436027+05:30	\N	\N	\N	\N	\N	7	2026-08-11 14:31:14.436027+05:30	Cut one line; zinc added.
131	1	3	2026-08-11	Partial	2026-08-11 14:32:22.111893+05:30	2026-08-11 14:32:22.549365+05:30	\N	\N	\N	\N	\N	7	2026-08-11 14:32:22.549365+05:30	Cut one line; zinc added.
132	1	3	2026-08-11	Partial	2026-08-11 15:10:06.157152+05:30	2026-08-11 15:10:06.762327+05:30	\N	\N	\N	\N	\N	7	2026-08-11 15:10:06.762327+05:30	Cut one line; zinc added.
133	1	3	2026-08-11	Partial	2026-08-11 15:54:01.996583+05:30	2026-08-11 15:54:02.455343+05:30	\N	\N	\N	\N	\N	7	2026-08-11 15:54:02.455343+05:30	Cut one line; zinc added.
\.


--
-- TOC entry 5924 (class 0 OID 31370)
-- Dependencies: 285
-- Data for Name: requisition_line; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.requisition_line (requisition_line_id, requisition_id, medicine_id, medicine_name, dosage, requested_qty, dispatched_qty, received_qty, received, status, deleted_at, deleted_by, delete_reason, legacy_id, legacy_source, approved_qty, review_note, added_by_cmo) FROM stdin;
1	1	\N	Paracetamol 500mg	500mg	500	0	0	f	Approved	\N	\N	\N	\N	\N	500		f
2	1	\N	ORS Sachet		300	0	0	f	Partial	\N	\N	\N	\N	\N	150	Low central stock	f
3	1	\N	Iron Folic Acid		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
4	1	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	250	Diarrhoea outbreak in the block	t
5	2	\N	Paracetamol 500mg	500mg	500	0	0	f	Approved	\N	\N	\N	\N	\N	500		f
6	2	\N	ORS Sachet		300	0	0	f	Partial	\N	\N	\N	\N	\N	150	Low central stock	f
7	2	\N	Iron Folic Acid		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
8	2	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	250	Outbreak in the block	t
10	4	\N	Albendazole 400mg		60	0	0	f	Rejected	\N	\N	\N	\N	\N	0	Not indicated	f
9	3	\N	Cetirizine 10mg		100	0	100	t	Approved	\N	\N	\N	\N	\N	100		f
11	5	\N	Cough Syrup		40	0	25	t	Approved	\N	\N	\N	\N	\N	40		f
12	6	\N	Paracetamol 500mg	500mg	500	0	0	f	Approved	\N	\N	\N	\N	\N	500		f
13	6	\N	ORS Sachet		300	0	0	f	Partial	\N	\N	\N	\N	\N	150	Low central stock	f
14	6	\N	Iron Folic Acid		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
15	6	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	250	Outbreak in the block	t
17	8	\N	Albendazole 400mg		60	0	0	f	Rejected	\N	\N	\N	\N	\N	0	Not indicated	f
16	7	\N	Cetirizine 10mg		100	0	100	t	Approved	\N	\N	\N	\N	\N	100		f
38	18	\N	Paracetamol 500mg	500mg	500	0	0	f	Approved	\N	\N	\N	\N	\N	500		f
18	9	\N	Cough Syrup		40	0	25	t	Approved	\N	\N	\N	\N	\N	40		f
19	10	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
20	10	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
21	10	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
22	11	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
23	11	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
24	11	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
25	12	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
26	12	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
27	12	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
28	13	\N	Paracetamol 500mg	500mg	500	0	0	f	Approved	\N	\N	\N	\N	\N	500		f
29	13	\N	ORS Sachet		300	0	0	f	Partial	\N	\N	\N	\N	\N	150	Low central stock	f
30	13	\N	Iron Folic Acid		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
31	13	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	250	Outbreak in the block	t
39	18	\N	ORS Sachet		300	0	0	f	Partial	\N	\N	\N	\N	\N	150	Low central stock	f
33	15	\N	Albendazole 400mg		60	0	0	f	Rejected	\N	\N	\N	\N	\N	0	Not indicated	f
32	14	\N	Cetirizine 10mg		100	0	100	t	Approved	\N	\N	\N	\N	\N	100		f
40	18	\N	Iron Folic Acid		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
34	16	\N	Cough Syrup		40	0	25	t	Approved	\N	\N	\N	\N	\N	40		f
35	17	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
36	17	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
37	17	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
41	18	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	250	Outbreak in the block	t
52	24	\N	Cetirizine 10mg		100	0	100	t	Approved	\N	\N	\N	\N	\N	100		f
43	20	\N	Albendazole 400mg		60	0	0	f	Rejected	\N	\N	\N	\N	\N	0	Not indicated	f
42	19	\N	Cetirizine 10mg		100	0	100	t	Approved	\N	\N	\N	\N	\N	100		f
44	21	\N	Cough Syrup		40	0	25	t	Approved	\N	\N	\N	\N	\N	40		f
45	22	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
46	22	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
47	22	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
48	23	\N	Paracetamol 500mg	500mg	500	0	0	f	Approved	\N	\N	\N	\N	\N	500		f
49	23	\N	ORS Sachet		300	0	0	f	Partial	\N	\N	\N	\N	\N	150	Low central stock	f
50	23	\N	Iron Folic Acid		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
51	23	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	250	Outbreak in the block	t
53	25	\N	Albendazole 400mg		60	0	0	f	Rejected	\N	\N	\N	\N	\N	0	Not indicated	f
54	26	\N	Cough Syrup		40	0	25	t	Approved	\N	\N	\N	\N	\N	40		f
55	27	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
56	27	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
57	27	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
58	28	\N	Paracetamol 500mg	500mg	500	0	0	f	Approved	\N	\N	\N	\N	\N	500		f
59	28	\N	ORS Sachet		300	0	0	f	Partial	\N	\N	\N	\N	\N	150	Low central stock	f
60	28	\N	Iron Folic Acid		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
61	28	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	250	Outbreak in the block	t
63	30	\N	Albendazole 400mg		60	0	0	f	Rejected	\N	\N	\N	\N	\N	0	Not indicated	f
62	29	\N	Cetirizine 10mg		100	0	100	t	Approved	\N	\N	\N	\N	\N	100		f
66	32	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
64	31	\N	Cough Syrup		40	0	25	t	Approved	\N	\N	\N	\N	\N	40		f
65	32	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
67	32	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
68	33	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
69	33	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
70	33	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
71	34	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
72	34	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
73	34	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
74	35	\N	Paracetamol 500mg	500mg	500	0	0	f	Approved	\N	\N	\N	\N	\N	500		f
75	35	\N	ORS Sachet		300	0	0	f	Partial	\N	\N	\N	\N	\N	150	Low central stock	f
76	35	\N	Iron Folic Acid		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
77	35	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	250	Outbreak in the block	t
110	52	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
79	37	\N	Albendazole 400mg		60	0	0	f	Rejected	\N	\N	\N	\N	\N	0	Not indicated	f
78	36	\N	Cetirizine 10mg		100	0	100	t	Approved	\N	\N	\N	\N	\N	100		f
111	52	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
80	38	\N	Cough Syrup		40	0	25	t	Approved	\N	\N	\N	\N	\N	40		f
81	39	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
82	39	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
83	39	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
84	40	\N	Paracetamol 500mg	500mg	500	0	0	f	Approved	\N	\N	\N	\N	\N	500		f
85	40	\N	ORS Sachet		300	0	0	f	Partial	\N	\N	\N	\N	\N	150	Low central stock	f
86	40	\N	Iron Folic Acid		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
87	40	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	250	Outbreak in the block	t
112	52	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
89	42	\N	Albendazole 400mg		60	0	0	f	Rejected	\N	\N	\N	\N	\N	0	Not indicated	f
88	41	\N	Cetirizine 10mg		100	0	100	t	Approved	\N	\N	\N	\N	\N	100		f
90	43	\N	Cough Syrup		40	0	25	t	Approved	\N	\N	\N	\N	\N	40		f
91	44	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
92	44	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
93	44	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
94	45	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
95	45	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
96	45	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
97	46	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
98	46	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
99	46	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
100	47	\N	Paracetamol 500mg	500mg	500	0	0	f	Approved	\N	\N	\N	\N	\N	500		f
101	47	\N	ORS Sachet		300	0	0	f	Partial	\N	\N	\N	\N	\N	150	Low central stock	f
102	47	\N	Iron Folic Acid		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
103	47	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	250	Outbreak in the block	t
105	49	\N	Albendazole 400mg		60	0	0	f	Rejected	\N	\N	\N	\N	\N	0	Not indicated	f
104	48	\N	Cetirizine 10mg		100	0	100	t	Approved	\N	\N	\N	\N	\N	100		f
106	50	\N	Cough Syrup		40	0	25	t	Approved	\N	\N	\N	\N	\N	40		f
107	51	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
108	51	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
109	51	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
113	53	\N	Paracetamol 500mg	500mg	500	0	0	f	Approved	\N	\N	\N	\N	\N	500		f
114	53	\N	ORS Sachet		300	0	0	f	Partial	\N	\N	\N	\N	\N	150	Low central stock	f
115	53	\N	Iron Folic Acid		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
116	53	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	250	Outbreak in the block	t
127	59	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
118	55	\N	Albendazole 400mg		60	0	0	f	Rejected	\N	\N	\N	\N	\N	0	Not indicated	f
117	54	\N	Cetirizine 10mg		100	0	100	t	Approved	\N	\N	\N	\N	\N	100		f
128	59	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
119	56	\N	Cough Syrup		40	0	25	t	Approved	\N	\N	\N	\N	\N	40		f
120	57	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
121	57	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
122	57	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
123	58	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
124	58	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
125	58	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
126	59	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
129	60	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
130	60	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
131	60	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
132	61	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
133	61	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
134	61	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
135	62	\N	Paracetamol 500mg	500mg	500	0	0	f	Approved	\N	\N	\N	\N	\N	500		f
136	62	\N	ORS Sachet		300	0	0	f	Partial	\N	\N	\N	\N	\N	150	Low central stock	f
137	62	\N	Iron Folic Acid		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
138	62	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	250	Outbreak in the block	t
140	64	\N	Albendazole 400mg		60	0	0	f	Rejected	\N	\N	\N	\N	\N	0	Not indicated	f
139	63	\N	Cetirizine 10mg		100	0	100	t	Approved	\N	\N	\N	\N	\N	100		f
141	65	\N	Cough Syrup		40	0	25	t	Approved	\N	\N	\N	\N	\N	40		f
142	66	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
143	66	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
144	66	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
145	67	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
146	67	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
147	67	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
148	68	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
149	68	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
150	68	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
151	69	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
152	69	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
153	69	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
154	70	32	Ambroxol		100	0	0	f	Requested	\N	\N	\N	\N	\N	\N		f
155	70	10	Cap.Pantoprazole		200	0	0	f	Requested	\N	\N	\N	\N	\N	\N		f
156	70	28	Cap.Vitamin D3		300	0	0	f	Requested	\N	\N	\N	\N	\N	\N		f
157	71	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
158	71	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
159	71	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
160	72	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
161	72	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
162	72	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
163	73	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
164	73	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
165	73	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
166	74	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
167	74	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
168	74	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
169	75	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
170	75	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
171	75	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
172	76	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
173	76	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
174	76	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
175	77	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
176	77	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
177	77	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
178	78	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
179	78	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
180	78	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
181	79	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
182	79	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
183	79	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
184	80	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
185	80	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
186	80	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
187	81	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
188	81	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
189	81	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
190	82	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
191	82	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
192	82	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
193	83	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
194	83	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
195	83	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
196	84	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
197	84	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
198	84	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
199	85	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
200	85	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
201	85	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
202	86	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
203	86	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
204	86	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
205	87	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
206	87	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
207	87	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
208	88	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
209	88	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
210	88	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
211	89	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
212	89	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
213	89	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
214	90	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
215	90	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
216	90	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
217	91	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
218	91	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
219	91	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
228	94	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
220	92	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
221	92	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
222	92	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
223	93	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
224	93	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
225	93	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
226	94	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
227	94	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
229	95	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
230	95	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
231	95	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
232	96	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
233	96	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
234	96	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
235	97	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
236	97	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
237	97	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
262	128	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
263	128	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
264	128	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
265	129	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
266	129	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
267	129	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
268	130	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
269	130	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
270	130	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
271	131	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
272	131	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
273	131	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
274	132	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
275	132	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
276	132	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
277	133	\N	Paracetamol 500mg	500mg	400	0	0	f	Partial	\N	\N	\N	\N	\N	200	Low stock	f
278	133	\N	ORS Sachet		200	0	0	f	Approved	\N	\N	\N	\N	\N	200		f
279	133	\N	Zinc Sulphate		0	0	0	f	Approved	\N	\N	\N	\N	\N	100	Outbreak	t
\.


--
-- TOC entry 5880 (class 0 OID 30682)
-- Dependencies: 241
-- Data for Name: roster; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.roster (roster_id, org_id, facility_id, roster_month, file_path, uploaded_by, uploaded_at, deleted_at, deleted_by, delete_reason) FROM stdin;
1	1	\N	2026-08	roster-190.xlsx	18	2026-08-10 17:14:12.548525+05:30	2026-08-10 17:14:12.569826+05:30	18	replaced by a newer upload
2	1	\N	2026-08	roster-190-v2.xlsx	18	2026-08-10 17:14:12.569826+05:30	2026-08-10 17:15:05.795433+05:30	18	replaced by a newer upload
3	1	\N	2026-08	roster-795.xlsx	18	2026-08-10 17:15:05.795433+05:30	2026-08-10 17:15:05.814248+05:30	18	replaced by a newer upload
4	1	\N	2026-08	roster-795-v2.xlsx	18	2026-08-10 17:15:05.814248+05:30	2026-08-10 17:31:17.604997+05:30	18	replaced by a newer upload
5	1	\N	2026-08	roster-861.xlsx	18	2026-08-10 17:31:17.604997+05:30	2026-08-10 17:31:17.627068+05:30	18	replaced by a newer upload
6	1	\N	2026-08	roster-861-v2.xlsx	18	2026-08-10 17:31:17.627068+05:30	2026-08-10 17:31:48.724616+05:30	18	replaced by a newer upload
7	1	\N	2026-08	roster-579.xlsx	18	2026-08-10 17:31:48.724616+05:30	2026-08-10 17:31:48.743258+05:30	18	replaced by a newer upload
8	1	\N	2026-08	roster-579-v2.xlsx	18	2026-08-10 17:31:48.743258+05:30	2026-08-10 17:35:17.697406+05:30	18	replaced by a newer upload
111	1	\N	2026-08	roster-976-v2.xlsx	18	2026-08-11 15:54:08.22094+05:30	\N	\N	\N
9	1	\N	2026-08	roster-507.xlsx	18	2026-08-10 17:35:17.697406+05:30	2026-08-10 17:35:17.722848+05:30	18	replaced by a newer upload
10	1	\N	2026-08	roster-507-v2.xlsx	18	2026-08-10 17:35:17.722848+05:30	2026-08-10 17:39:27.23775+05:30	18	replaced by a newer upload
11	1	\N	2026-08	roster-399.xlsx	18	2026-08-10 17:39:27.23775+05:30	2026-08-10 17:39:27.257753+05:30	18	replaced by a newer upload
12	1	\N	2026-08	roster-399-v2.xlsx	18	2026-08-10 17:39:27.257753+05:30	2026-08-10 17:43:08.228039+05:30	18	replaced by a newer upload
13	1	\N	2026-08	roster-377.xlsx	18	2026-08-10 17:43:08.228039+05:30	2026-08-10 17:43:08.23896+05:30	18	replaced by a newer upload
14	1	\N	2026-08	roster-377-v2.xlsx	18	2026-08-10 17:43:08.23896+05:30	2026-08-10 17:53:08.730486+05:30	18	replaced by a newer upload
15	1	\N	2026-08	roster-357.xlsx	18	2026-08-10 17:53:08.730486+05:30	2026-08-10 17:53:08.784303+05:30	18	replaced by a newer upload
16	1	\N	2026-08	roster-357-v2.xlsx	18	2026-08-10 17:53:08.784303+05:30	2026-08-10 18:00:26.116057+05:30	18	replaced by a newer upload
17	1	\N	2026-08	roster-644.xlsx	18	2026-08-10 18:00:26.116057+05:30	2026-08-10 18:00:26.137682+05:30	18	replaced by a newer upload
18	1	\N	2026-08	roster-644-v2.xlsx	18	2026-08-10 18:00:26.137682+05:30	2026-08-10 18:00:48.85718+05:30	18	replaced by a newer upload
19	1	\N	2026-08	roster-251.xlsx	18	2026-08-10 18:00:48.85718+05:30	2026-08-10 18:00:48.873417+05:30	18	replaced by a newer upload
20	1	\N	2026-08	roster-251-v2.xlsx	18	2026-08-10 18:00:48.873417+05:30	2026-08-10 19:16:26.575009+05:30	18	replaced by a newer upload
21	1	\N	2026-08	roster-177.xlsx	18	2026-08-10 19:16:26.575009+05:30	2026-08-10 19:16:26.596969+05:30	18	replaced by a newer upload
22	1	\N	2026-08	roster-177-v2.xlsx	18	2026-08-10 19:16:26.596969+05:30	2026-08-10 19:16:50.42178+05:30	18	replaced by a newer upload
23	1	\N	2026-08	roster-953.xlsx	18	2026-08-10 19:16:50.42178+05:30	2026-08-10 19:16:50.447744+05:30	18	replaced by a newer upload
24	1	\N	2026-08	roster-953-v2.xlsx	18	2026-08-10 19:16:50.447744+05:30	2026-08-10 19:36:01.314784+05:30	18	replaced by a newer upload
25	1	\N	2026-08	roster-208.xlsx	18	2026-08-10 19:36:01.314784+05:30	2026-08-10 19:36:01.34942+05:30	18	replaced by a newer upload
26	1	\N	2026-08	roster-208-v2.xlsx	18	2026-08-10 19:36:01.34942+05:30	2026-08-10 19:39:53.776418+05:30	18	replaced by a newer upload
27	1	\N	2026-08	roster-254.xlsx	18	2026-08-10 19:39:53.776418+05:30	2026-08-10 19:39:53.813858+05:30	18	replaced by a newer upload
28	1	\N	2026-08	roster-254-v2.xlsx	18	2026-08-10 19:39:53.813858+05:30	2026-08-10 19:41:21.597847+05:30	18	replaced by a newer upload
29	1	\N	2026-08	roster-457.xlsx	18	2026-08-10 19:41:21.597847+05:30	2026-08-10 19:41:21.686703+05:30	18	replaced by a newer upload
30	1	\N	2026-08	roster-457-v2.xlsx	18	2026-08-10 19:41:21.686703+05:30	2026-08-10 19:42:01.377059+05:30	18	replaced by a newer upload
31	1	\N	2026-08	roster-834.xlsx	18	2026-08-10 19:42:01.377059+05:30	2026-08-10 19:42:01.401854+05:30	18	replaced by a newer upload
32	1	\N	2026-08	roster-834-v2.xlsx	18	2026-08-10 19:42:01.401854+05:30	2026-08-10 20:19:05.625242+05:30	18	replaced by a newer upload
33	1	\N	2026-08	roster-269.xlsx	18	2026-08-10 20:19:05.625242+05:30	2026-08-10 20:19:05.647683+05:30	18	replaced by a newer upload
34	1	\N	2026-08	roster-269-v2.xlsx	18	2026-08-10 20:19:05.647683+05:30	2026-08-10 20:23:01.66035+05:30	18	replaced by a newer upload
35	1	\N	2026-08	roster-306.xlsx	18	2026-08-10 20:23:01.66035+05:30	2026-08-10 20:23:01.683008+05:30	18	replaced by a newer upload
36	1	\N	2026-08	roster-306-v2.xlsx	18	2026-08-10 20:23:01.683008+05:30	2026-08-10 20:34:41.675885+05:30	18	replaced by a newer upload
37	1	\N	2026-08	roster-850.xlsx	18	2026-08-10 20:34:41.675885+05:30	2026-08-10 20:34:41.688824+05:30	18	replaced by a newer upload
38	1	\N	2026-08	roster-850-v2.xlsx	18	2026-08-10 20:34:41.688824+05:30	2026-08-10 20:47:47.64629+05:30	18	replaced by a newer upload
39	1	\N	2026-08	roster-630.xlsx	18	2026-08-10 20:47:47.64629+05:30	2026-08-10 20:47:47.664995+05:30	18	replaced by a newer upload
40	1	\N	2026-08	roster-630-v2.xlsx	18	2026-08-10 20:47:47.664995+05:30	2026-08-10 21:13:56.918144+05:30	18	replaced by a newer upload
41	1	\N	2026-08	roster-531.xlsx	18	2026-08-10 21:13:56.918144+05:30	2026-08-10 21:13:56.937275+05:30	18	replaced by a newer upload
42	1	\N	2026-08	roster-531-v2.xlsx	18	2026-08-10 21:13:56.937275+05:30	2026-08-10 21:20:19.539745+05:30	18	replaced by a newer upload
43	1	\N	2026-08	roster-214.xlsx	18	2026-08-10 21:20:19.539745+05:30	2026-08-10 21:20:19.574413+05:30	18	replaced by a newer upload
44	1	\N	2026-08	roster-214-v2.xlsx	18	2026-08-10 21:20:19.574413+05:30	2026-08-10 21:38:29.73642+05:30	18	replaced by a newer upload
45	1	\N	2026-08	roster-292.xlsx	18	2026-08-10 21:38:29.73642+05:30	2026-08-10 21:38:29.763092+05:30	18	replaced by a newer upload
46	1	\N	2026-08	roster-292-v2.xlsx	18	2026-08-10 21:38:29.763092+05:30	2026-08-10 21:49:01.054171+05:30	18	replaced by a newer upload
47	1	\N	2026-08	roster-562.xlsx	18	2026-08-10 21:49:01.054171+05:30	2026-08-10 21:49:01.074508+05:30	18	replaced by a newer upload
48	1	\N	2026-08	roster-562-v2.xlsx	18	2026-08-10 21:49:01.074508+05:30	2026-08-11 09:30:21.765074+05:30	18	replaced by a newer upload
49	1	\N	2026-08	roster-893.xlsx	18	2026-08-11 09:30:21.765074+05:30	2026-08-11 09:30:21.782114+05:30	18	replaced by a newer upload
50	1	\N	2026-08	roster-893-v2.xlsx	18	2026-08-11 09:30:21.782114+05:30	2026-08-11 09:36:21.828593+05:30	18	replaced by a newer upload
51	1	\N	2026-08	roster-982.xlsx	18	2026-08-11 09:36:21.828593+05:30	2026-08-11 09:36:21.843516+05:30	18	replaced by a newer upload
52	1	\N	2026-08	roster-982-v2.xlsx	18	2026-08-11 09:36:21.843516+05:30	2026-08-11 09:52:21.825072+05:30	18	replaced by a newer upload
53	1	\N	2026-08	roster-320.xlsx	18	2026-08-11 09:52:21.825072+05:30	2026-08-11 09:52:21.8365+05:30	18	replaced by a newer upload
54	1	\N	2026-08	roster-320-v2.xlsx	18	2026-08-11 09:52:21.8365+05:30	2026-08-11 11:14:16.713756+05:30	18	replaced by a newer upload
64	1	\N	2026-08	roster-827-v2.xlsx	18	2026-08-11 14:04:42.806194+05:30	2026-08-11 14:05:12.309964+05:30	18	replaced by a newer upload
55	1	\N	2026-08	roster-284.xlsx	18	2026-08-11 11:14:16.713756+05:30	2026-08-11 11:14:16.728994+05:30	18	replaced by a newer upload
65	1	\N	2026-08	roster-457.xlsx	18	2026-08-11 14:05:12.309964+05:30	2026-08-11 14:05:12.322305+05:30	18	replaced by a newer upload
56	1	\N	2026-08	roster-284-v2.xlsx	18	2026-08-11 11:14:16.728994+05:30	2026-08-11 13:59:35.159429+05:30	18	replaced by a newer upload
57	1	\N	2026-08	roster-563.xlsx	18	2026-08-11 13:59:35.159429+05:30	2026-08-11 13:59:35.183067+05:30	18	replaced by a newer upload
66	1	\N	2026-08	roster-457-v2.xlsx	18	2026-08-11 14:05:12.322305+05:30	2026-08-11 14:05:53.589061+05:30	18	replaced by a newer upload
58	1	\N	2026-08	roster-563-v2.xlsx	18	2026-08-11 13:59:35.183067+05:30	2026-08-11 14:03:17.746963+05:30	18	replaced by a newer upload
67	1	\N	2026-08	roster-887.xlsx	18	2026-08-11 14:05:53.589061+05:30	2026-08-11 14:05:53.609252+05:30	18	replaced by a newer upload
59	1	\N	2026-08	roster-781.xlsx	18	2026-08-11 14:03:17.746963+05:30	2026-08-11 14:03:17.75801+05:30	18	replaced by a newer upload
60	1	\N	2026-08	roster-781-v2.xlsx	18	2026-08-11 14:03:17.75801+05:30	2026-08-11 14:04:23.666245+05:30	18	replaced by a newer upload
68	1	\N	2026-08	roster-887-v2.xlsx	18	2026-08-11 14:05:53.609252+05:30	2026-08-11 14:06:22.85409+05:30	18	replaced by a newer upload
61	1	\N	2026-08	roster-271.xlsx	18	2026-08-11 14:04:23.666245+05:30	2026-08-11 14:04:23.675204+05:30	18	replaced by a newer upload
69	1	\N	2026-08	roster-928.xlsx	18	2026-08-11 14:06:22.85409+05:30	2026-08-11 14:06:22.877715+05:30	18	replaced by a newer upload
62	1	\N	2026-08	roster-271-v2.xlsx	18	2026-08-11 14:04:23.675204+05:30	2026-08-11 14:04:42.789742+05:30	18	replaced by a newer upload
63	1	\N	2026-08	roster-827.xlsx	18	2026-08-11 14:04:42.789742+05:30	2026-08-11 14:04:42.806194+05:30	18	replaced by a newer upload
70	1	\N	2026-08	roster-928-v2.xlsx	18	2026-08-11 14:06:22.877715+05:30	2026-08-11 14:06:52.89648+05:30	18	replaced by a newer upload
71	1	\N	2026-08	roster-312.xlsx	18	2026-08-11 14:06:52.89648+05:30	2026-08-11 14:06:52.992272+05:30	18	replaced by a newer upload
72	1	\N	2026-08	roster-312-v2.xlsx	18	2026-08-11 14:06:52.992272+05:30	2026-08-11 14:20:44.612764+05:30	18	replaced by a newer upload
100	1	\N	2026-08	roster-395.xlsx	18	2026-08-11 14:20:44.612764+05:30	2026-08-11 14:20:44.65124+05:30	18	replaced by a newer upload
101	1	\N	2026-08	roster-395-v2.xlsx	18	2026-08-11 14:20:44.65124+05:30	2026-08-11 14:26:38.657408+05:30	18	replaced by a newer upload
102	1	\N	2026-08	roster-456.xlsx	18	2026-08-11 14:26:38.657408+05:30	2026-08-11 14:26:38.696609+05:30	18	replaced by a newer upload
103	1	\N	2026-08	roster-456-v2.xlsx	18	2026-08-11 14:26:38.696609+05:30	2026-08-11 14:31:20.511326+05:30	18	replaced by a newer upload
104	1	\N	2026-08	roster-356.xlsx	18	2026-08-11 14:31:20.511326+05:30	2026-08-11 14:31:20.526024+05:30	18	replaced by a newer upload
105	1	\N	2026-08	roster-356-v2.xlsx	18	2026-08-11 14:31:20.526024+05:30	2026-08-11 14:32:29.001184+05:30	18	replaced by a newer upload
106	1	\N	2026-08	roster-649.xlsx	18	2026-08-11 14:32:29.001184+05:30	2026-08-11 14:32:29.014656+05:30	18	replaced by a newer upload
107	1	\N	2026-08	roster-649-v2.xlsx	18	2026-08-11 14:32:29.014656+05:30	2026-08-11 15:10:12.820044+05:30	18	replaced by a newer upload
108	1	\N	2026-08	roster-662.xlsx	18	2026-08-11 15:10:12.820044+05:30	2026-08-11 15:10:12.841798+05:30	18	replaced by a newer upload
109	1	\N	2026-08	roster-662-v2.xlsx	18	2026-08-11 15:10:12.841798+05:30	2026-08-11 15:54:08.207681+05:30	18	replaced by a newer upload
110	1	\N	2026-08	roster-976.xlsx	18	2026-08-11 15:54:08.207681+05:30	2026-08-11 15:54:08.22094+05:30	18	replaced by a newer upload
\.


--
-- TOC entry 5876 (class 0 OID 30631)
-- Dependencies: 237
-- Data for Name: staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.staff (staff_id, org_id, staff_name, role, phone, facility_id, is_active, created_at, deleted_at, deleted_by, delete_reason, legacy_id, legacy_source) FROM stdin;
236	1	Test Nurse 457	counsellor	9900000457	\N	t	2026-08-11 14:05:11.824636+05:30	\N	\N	\N	\N	\N
240	1	Temp Worker 1263	lab	9840001263	\N	t	2026-08-11 14:05:20.739088+05:30	2026-08-11 14:05:23.899455+05:30	18	left the programme	\N	\N
243	1	Rohit Kumar 3776	doctor	9810003776	\N	t	2026-08-11 14:05:56.935538+05:30	\N	\N	\N	\N	\N
246	1	Test Nurse 928	counsellor	9900000928	\N	t	2026-08-11 14:06:22.297619+05:30	\N	\N	\N	\N	\N
13	1	Priya Sharma (Hasanpur)	lab	9738353577	2	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
250	1	Temp Worker 3914	lab	9840003914	\N	t	2026-08-11 14:06:30.888186+05:30	2026-08-11 14:06:34.307596+05:30	18	left the programme	\N	\N
15	1	Ram Prasad (Hasanpur)	driver	9202566464	2	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
16	1	Sanjeev Mahto (Roorkee)	counsellor	9100758637	3	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
17	1	Dr. Aakanksha Dua (Roorkee)	doctor	9548452043	3	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
18	1	Priya Sharma (Roorkee)	lab	9217469106	3	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
19	1	Kedar Dash (Roorkee)	pharmacist	9512282102	3	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
20	1	Ram Prasad (Roorkee)	driver	9991008896	3	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
21	2	Sanjeev Mahto (Igatpuri)	counsellor	9390674031	4	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
22	2	Dr. Aakanksha Dua (Igatpuri)	doctor	9949043895	4	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
23	2	Priya Sharma (Igatpuri)	lab	9148034108	4	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
24	2	Kedar Dash (Igatpuri)	pharmacist	9427962371	4	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
25	2	Ram Prasad (Igatpuri)	driver	9809959009	4	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
26	2	Sanjeev Mahto (Bardoli)	counsellor	9668753121	5	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
27	2	Dr. Aakanksha Dua (Bardoli)	doctor	9742411092	5	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
28	2	Priya Sharma (Bardoli)	lab	9998331106	5	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
29	2	Kedar Dash (Bardoli)	pharmacist	9730055957	5	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
30	2	Ram Prasad (Bardoli)	driver	9630030527	5	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
31	2	Sanjeev Mahto (Kalavad)	counsellor	9313292209	6	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
32	2	Dr. Aakanksha Dua (Kalavad)	doctor	9410123303	6	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
33	2	Priya Sharma (Kalavad)	lab	9102987516	6	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
34	2	Kedar Dash (Kalavad)	pharmacist	9441271245	6	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
35	2	Ram Prasad (Kalavad)	driver	9360864624	6	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
36	3	Sanjeev Mahto (Nanjangud)	counsellor	9616803525	7	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
37	3	Dr. Aakanksha Dua (Nanjangud)	doctor	9408803114	7	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
38	3	Priya Sharma (Nanjangud)	lab	9604166021	7	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
39	3	Kedar Dash (Nanjangud)	pharmacist	9674274978	7	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
40	3	Ram Prasad (Nanjangud)	driver	9663549876	7	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
41	3	Sanjeev Mahto (Balianta)	counsellor	9104549198	8	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
42	3	Dr. Aakanksha Dua (Balianta)	doctor	9931302682	8	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
43	3	Priya Sharma (Balianta)	lab	9904385430	8	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
44	3	Kedar Dash (Balianta)	pharmacist	9951064515	8	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
45	3	Ram Prasad (Balianta)	driver	9345925726	8	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
46	1	Sanjeev Mahto (Gajraula)	counsellor	9495568668	9	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
47	1	Dr. Aakanksha Dua (Gajraula)	doctor	9388293090	9	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
48	1	Priya Sharma (Gajraula)	lab	9935944661	9	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
49	1	Kedar Dash (Gajraula)	pharmacist	9105055534	9	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
50	1	Sanjeev Mahto (Hasanpur)	counsellor	9904173391	10	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
51	1	Dr. Aakanksha Dua (Hasanpur)	doctor	9467298927	10	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
52	1	Priya Sharma (Hasanpur)	lab	9554896140	10	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
53	1	Kedar Dash (Hasanpur)	pharmacist	9882831314	10	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
54	1	Sanjeev Mahto (Roorkee)	counsellor	9713464312	11	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
55	1	Dr. Aakanksha Dua (Roorkee)	doctor	9408110233	11	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
56	1	Priya Sharma (Roorkee)	lab	9147236076	11	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
57	1	Kedar Dash (Roorkee)	pharmacist	9518514864	11	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
58	2	Sanjeev Mahto (Igatpuri)	counsellor	9237021333	12	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
59	2	Dr. Aakanksha Dua (Igatpuri)	doctor	9713857438	12	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
60	2	Priya Sharma (Igatpuri)	lab	9536004008	12	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
61	2	Kedar Dash (Igatpuri)	pharmacist	9226988082	12	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
62	2	Sanjeev Mahto (Bardoli)	counsellor	9727386408	13	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
63	2	Dr. Aakanksha Dua (Bardoli)	doctor	9558056459	13	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
64	2	Priya Sharma (Bardoli)	lab	9197036124	13	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
65	2	Kedar Dash (Bardoli)	pharmacist	9358059611	13	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
66	3	Sanjeev Mahto (Nanjangud)	counsellor	9820620682	14	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
67	3	Dr. Aakanksha Dua (Nanjangud)	doctor	9507663431	14	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
68	3	Priya Sharma (Nanjangud)	lab	9162856659	14	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
69	3	Kedar Dash (Nanjangud)	pharmacist	9420397244	14	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
253	1	Rohit Kumar 3632	doctor	9810003632	\N	t	2026-08-11 14:06:56.277889+05:30	\N	\N	\N	\N	\N
14	1	Kedar Dash (Hasanpur)	pharmacist	9552193242	\N	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
11	1	Sanjeev Mahto (Hasanpur)	counsellor	9158146729	\N	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
12	1	Dr. Aakanksha Dua (Hasanpur)	doctor	9717341991	\N	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
255	1	Temp Worker 5717	lab	9840005717	\N	t	2026-08-11 14:07:00.79967+05:30	2026-08-11 14:07:04.731494+05:30	18	left the programme	\N	\N
276	1	Rohit Kumar 7839	doctor	9810007839	\N	t	2026-08-11 14:20:49.121618+05:30	\N	\N	\N	\N	\N
277	1	Driver Singh 7839	driver	9820007839	\N	t	2026-08-11 14:20:50.552359+05:30	\N	\N	\N	\N	\N
279	1	Test Nurse 456	counsellor	9900000456	\N	t	2026-08-11 14:26:37.885144+05:30	\N	\N	\N	\N	\N
70	1	Sanjeev Mahto (Roorkee)	counsellor	9446772675	15	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
71	1	Dr. Aakanksha Dua (Roorkee)	doctor	9152252264	15	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
72	1	Priya Sharma (Roorkee)	lab	9481126024	15	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
73	1	Kedar Dash (Roorkee)	pharmacist	9104867155	15	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
74	1	Ram Prasad (Roorkee)	driver	9610403105	15	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
75	2	Sanjeev Mahto (Baramati)	counsellor	9158146729	16	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
76	2	Dr. Aakanksha Dua (Baramati)	doctor	9717341991	16	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
77	2	Priya Sharma (Baramati)	lab	9738353577	16	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
78	2	Kedar Dash (Baramati)	pharmacist	9552193242	16	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
79	2	Ram Prasad (Baramati)	driver	9202566464	16	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
80	2	Sanjeev Mahto (Vagra)	counsellor	9100758637	17	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
81	2	Dr. Aakanksha Dua (Vagra)	doctor	9548452043	17	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
82	2	Priya Sharma (Vagra)	lab	9217469106	17	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
83	2	Kedar Dash (Vagra)	pharmacist	9512282102	17	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
84	2	Ram Prasad (Vagra)	driver	9991008896	17	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
85	2	Sanjeev Mahto (Ahmedabad(BB))	counsellor	9390674031	18	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
86	2	Dr. Aakanksha Dua (Ahmedabad(BB))	doctor	9949043895	18	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
87	2	Priya Sharma (Ahmedabad(BB))	lab	9148034108	18	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
88	2	Kedar Dash (Ahmedabad(BB))	pharmacist	9427962371	18	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
89	2	Ram Prasad (Ahmedabad(BB))	driver	9809959009	18	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
90	3	Sanjeev Mahto (Nanjangud)	counsellor	9668753121	19	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
91	3	Dr. Aakanksha Dua (Nanjangud)	doctor	9742411092	19	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
92	3	Priya Sharma (Nanjangud)	lab	9998331106	19	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
93	3	Kedar Dash (Nanjangud)	pharmacist	9730055957	19	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
94	3	Ram Prasad (Nanjangud)	driver	9630030527	19	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
95	3	Sanjeev Mahto (Bamra)	counsellor	9313292209	20	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
96	3	Dr. Aakanksha Dua (Bamra)	doctor	9410123303	20	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
97	3	Priya Sharma (Bamra)	lab	9102987516	20	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
98	3	Kedar Dash (Bamra)	pharmacist	9441271245	20	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
99	3	Ram Prasad (Bamra)	driver	9360864624	20	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
100	2	Sanjeev Mahto (Baramati)	counsellor	9616803525	21	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
101	2	Dr. Aakanksha Dua (Baramati)	doctor	9408803114	21	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
102	2	Priya Sharma (Baramati)	lab	9604166021	21	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
103	2	Kedar Dash (Baramati)	pharmacist	9674274978	21	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
104	2	Sanjeev Mahto (Bharuch)	counsellor	9663549876	22	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
105	2	Dr. Aakanksha Dua (Bharuch)	doctor	9104549198	22	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
106	2	Priya Sharma (Bharuch)	lab	9931302682	22	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
107	2	Kedar Dash (Bharuch)	pharmacist	9904385430	22	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
108	3	Sanjeev Mahto (Mysore taluk)	counsellor	9951064515	23	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
109	3	Dr. Aakanksha Dua (Mysore taluk)	doctor	9345925726	23	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
110	3	Priya Sharma (Mysore taluk)	lab	9495568668	23	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
111	3	Kedar Dash (Mysore taluk)	pharmacist	9388293090	23	t	2026-08-10 11:28:25.630716+05:30	\N	\N	\N	\N	\N
112	1	Test Nurse 190	counsellor	9900000190	\N	t	2026-08-10 17:14:12.461087+05:30	\N	\N	\N	\N	\N
113	1	Test Nurse 795	counsellor	9900000795	\N	t	2026-08-10 17:15:05.724606+05:30	\N	\N	\N	\N	\N
114	1	Test Nurse 861	counsellor	9900000861	\N	t	2026-08-10 17:31:17.52219+05:30	\N	\N	\N	\N	\N
115	1	Test Nurse 579	counsellor	9900000579	\N	t	2026-08-10 17:31:48.647091+05:30	\N	\N	\N	\N	\N
116	1	Test Nurse 507	counsellor	9900000507	\N	t	2026-08-10 17:35:17.578996+05:30	\N	\N	\N	\N	\N
117	1	Test Nurse 399	counsellor	9900000399	\N	t	2026-08-10 17:39:27.121488+05:30	\N	\N	\N	\N	\N
118	1	Test Nurse 377	counsellor	9900000377	\N	t	2026-08-10 17:43:08.17519+05:30	\N	\N	\N	\N	\N
119	1	Test Nurse 357	counsellor	9900000357	\N	t	2026-08-10 17:53:08.182432+05:30	\N	\N	\N	\N	\N
120	1	Ravi Kumar 1317	counsellor	9800001317	\N	t	2026-08-10 17:53:12.027839+05:30	\N	\N	\N	\N	\N
121	1	Rohit Kumar 1317	doctor	9810001317	\N	t	2026-08-10 17:53:13.770441+05:30	\N	\N	\N	\N	\N
237	1	Ravi Kumar 9933	counsellor	9800009933	\N	t	2026-08-11 14:05:14.872879+05:30	\N	\N	\N	\N	\N
123	1	Test Nurse 644	counsellor	9900000644	\N	t	2026-08-10 18:00:25.580493+05:30	\N	\N	\N	\N	\N
124	1	Ravi Kumar 1835	counsellor	9800001835	\N	t	2026-08-10 18:00:28.832493+05:30	\N	\N	\N	\N	\N
125	1	Rohit Kumar 1835	doctor	9810001835	\N	t	2026-08-10 18:00:30.821275+05:30	\N	\N	\N	\N	\N
126	1	Driver Singh 1835	driver	9820001835	\N	t	2026-08-10 18:00:33.253953+05:30	\N	\N	\N	\N	\N
127	1	Test Nurse 251	counsellor	9900000251	\N	t	2026-08-10 18:00:48.30441+05:30	\N	\N	\N	\N	\N
128	1	Ravi Kumar 8790	counsellor	9800008790	\N	t	2026-08-10 18:00:51.582549+05:30	\N	\N	\N	\N	\N
129	1	Rohit Kumar 8790	doctor	9810008790	\N	t	2026-08-10 18:00:53.039166+05:30	\N	\N	\N	\N	\N
130	1	Driver Singh 8790	driver	9820008790	\N	t	2026-08-10 18:00:54.68671+05:30	\N	\N	\N	\N	\N
131	1	Test Nurse 177	counsellor	9900000177	\N	t	2026-08-10 19:16:26.003903+05:30	\N	\N	\N	\N	\N
132	1	Ravi Kumar 3247	counsellor	9800003247	\N	t	2026-08-10 19:16:30.138735+05:30	\N	\N	\N	\N	\N
133	1	Rohit Kumar 3247	doctor	9810003247	\N	t	2026-08-10 19:16:31.634567+05:30	\N	\N	\N	\N	\N
134	1	Driver Singh 3247	driver	9820003247	\N	t	2026-08-10 19:16:33.216052+05:30	\N	\N	\N	\N	\N
135	1	Test Nurse 953	counsellor	9900000953	\N	t	2026-08-10 19:16:49.84612+05:30	\N	\N	\N	\N	\N
136	1	Ravi Kumar 8755	counsellor	9800008755	\N	t	2026-08-10 19:16:53.402697+05:30	\N	\N	\N	\N	\N
137	1	Rohit Kumar 8755	doctor	9810008755	\N	t	2026-08-10 19:16:54.899639+05:30	\N	\N	\N	\N	\N
138	1	Driver Singh 8755	driver	9820008755	\N	t	2026-08-10 19:16:56.542249+05:30	\N	\N	\N	\N	\N
139	1	Test Nurse 208	counsellor	9900000208	\N	t	2026-08-10 19:36:00.53519+05:30	\N	\N	\N	\N	\N
140	1	Ravi Kumar 6089	counsellor	9800006089	\N	t	2026-08-10 19:36:05.134975+05:30	\N	\N	\N	\N	\N
141	1	Rohit Kumar 6089	doctor	9810006089	\N	t	2026-08-10 19:36:06.932617+05:30	\N	\N	\N	\N	\N
142	1	Driver Singh 6089	driver	9820006089	\N	t	2026-08-10 19:36:08.438798+05:30	\N	\N	\N	\N	\N
244	1	Driver Singh 3776	driver	9820003776	\N	t	2026-08-11 14:05:58.141317+05:30	\N	\N	\N	\N	\N
238	1	Rohit Kumar 9933	doctor	9810009933	\N	t	2026-08-11 14:05:16.071565+05:30	\N	\N	\N	\N	\N
205	1	Ravi Kumar 2014	counsellor	9800002014	\N	t	2026-08-11 09:36:24.994538+05:30	\N	\N	\N	\N	\N
206	1	Rohit Kumar 2014	doctor	9810002014	\N	t	2026-08-11 09:36:26.364665+05:30	\N	\N	\N	\N	\N
143	1	Temp Worker 9424	lab	9840009424	\N	t	2026-08-10 19:36:13.649873+05:30	2026-08-10 19:36:18.434083+05:30	18	left the programme	\N	\N
144	1	Test Nurse 254	counsellor	9900000254	\N	t	2026-08-10 19:39:53.045492+05:30	\N	\N	\N	\N	\N
145	1	Ravi Kumar 8140	counsellor	9800008140	\N	t	2026-08-10 19:39:57.403178+05:30	\N	\N	\N	\N	\N
146	1	Rohit Kumar 8140	doctor	9810008140	\N	t	2026-08-10 19:39:59.109521+05:30	\N	\N	\N	\N	\N
147	1	Driver Singh 8140	driver	9820008140	\N	t	2026-08-10 19:40:00.673374+05:30	\N	\N	\N	\N	\N
198	1	Temp Worker 9650	lab	9840009650	\N	t	2026-08-10 21:49:14.162246+05:30	2026-08-10 21:49:18.804099+05:30	18	left the programme	\N	\N
183	1	Temp Worker 3005	lab	9840003005	\N	t	2026-08-10 21:14:09.383956+05:30	2026-08-10 21:14:17.1112+05:30	18	left the programme	\N	\N
184	1	Test Nurse 214	counsellor	9900000214	\N	t	2026-08-10 21:20:18.90493+05:30	\N	\N	\N	\N	\N
148	1	Temp Worker 9371	lab	9840009371	\N	t	2026-08-10 19:40:05.88101+05:30	2026-08-10 19:40:10.735779+05:30	18	left the programme	\N	\N
149	1	Test Nurse 457	counsellor	9900000457	\N	t	2026-08-10 19:41:21.098181+05:30	\N	\N	\N	\N	\N
150	1	Ravi Kumar 2665	counsellor	9800002665	\N	t	2026-08-10 19:41:24.923756+05:30	\N	\N	\N	\N	\N
152	1	Driver Singh 2665	driver	9820002665	\N	t	2026-08-10 19:41:27.776239+05:30	\N	\N	\N	\N	\N
185	1	Ravi Kumar 4313	counsellor	9800004313	\N	t	2026-08-10 21:20:22.933932+05:30	\N	\N	\N	\N	\N
186	1	Rohit Kumar 4313	doctor	9810004313	\N	t	2026-08-10 21:20:24.523305+05:30	\N	\N	\N	\N	\N
187	1	Driver Singh 4313	driver	9820004313	\N	t	2026-08-10 21:20:26.512322+05:30	\N	\N	\N	\N	\N
153	1	Temp Worker 7733	lab	9840007733	\N	t	2026-08-10 19:41:32.625734+05:30	2026-08-10 19:41:36.581135+05:30	18	left the programme	\N	\N
154	1	Test Nurse 834	counsellor	9900000834	\N	t	2026-08-10 19:42:00.900416+05:30	\N	\N	\N	\N	\N
155	1	Ravi Kumar 6432	counsellor	9800006432	\N	t	2026-08-10 19:42:04.540253+05:30	\N	\N	\N	\N	\N
156	1	Rohit Kumar 6432	doctor	9810006432	\N	t	2026-08-10 19:42:05.961043+05:30	\N	\N	\N	\N	\N
157	1	Driver Singh 6432	driver	9820006432	\N	t	2026-08-10 19:42:07.436162+05:30	\N	\N	\N	\N	\N
199	1	Test Nurse 893	counsellor	9900000893	\N	t	2026-08-11 09:30:21.206621+05:30	\N	\N	\N	\N	\N
200	1	Ravi Kumar 9753	counsellor	9800009753	\N	t	2026-08-11 09:30:25.638681+05:30	\N	\N	\N	\N	\N
158	1	Temp Worker 9609	lab	9840009609	\N	t	2026-08-10 19:42:12.53779+05:30	2026-08-10 19:42:16.591326+05:30	18	left the programme	\N	\N
159	1	Test Nurse 269	counsellor	9900000269	\N	t	2026-08-10 20:19:05.055891+05:30	\N	\N	\N	\N	\N
160	1	Ravi Kumar 2825	counsellor	9800002825	\N	t	2026-08-10 20:19:08.398786+05:30	\N	\N	\N	\N	\N
161	1	Rohit Kumar 2825	doctor	9810002825	\N	t	2026-08-10 20:19:09.671944+05:30	\N	\N	\N	\N	\N
162	1	Driver Singh 2825	driver	9820002825	\N	t	2026-08-10 20:19:10.851037+05:30	\N	\N	\N	\N	\N
201	1	Rohit Kumar 9753	doctor	9810009753	\N	t	2026-08-11 09:30:26.995879+05:30	\N	\N	\N	\N	\N
188	1	Temp Worker 6582	lab	9840006582	\N	t	2026-08-10 21:20:31.801994+05:30	2026-08-10 21:20:36.595539+05:30	18	left the programme	\N	\N
189	1	Test Nurse 292	counsellor	9900000292	\N	t	2026-08-10 21:38:29.02013+05:30	\N	\N	\N	\N	\N
163	1	Temp Worker 2350	lab	9840002350	\N	t	2026-08-10 20:19:14.753196+05:30	2026-08-10 20:19:18.421365+05:30	18	left the programme	\N	\N
164	1	Test Nurse 306	counsellor	9900000306	\N	t	2026-08-10 20:23:00.872109+05:30	\N	\N	\N	\N	\N
165	1	Ravi Kumar 2255	counsellor	9800002255	\N	t	2026-08-10 20:23:04.718696+05:30	\N	\N	\N	\N	\N
166	1	Rohit Kumar 2255	doctor	9810002255	\N	t	2026-08-10 20:23:06.461904+05:30	\N	\N	\N	\N	\N
167	1	Driver Singh 2255	driver	9820002255	\N	t	2026-08-10 20:23:07.903929+05:30	\N	\N	\N	\N	\N
190	1	Ravi Kumar 1547	counsellor	9800001547	\N	t	2026-08-10 21:38:33.311784+05:30	\N	\N	\N	\N	\N
191	1	Rohit Kumar 1547	doctor	9810001547	\N	t	2026-08-10 21:38:35.551814+05:30	\N	\N	\N	\N	\N
192	1	Driver Singh 1547	driver	9820001547	\N	t	2026-08-10 21:38:37.626822+05:30	\N	\N	\N	\N	\N
168	1	Temp Worker 6719	lab	9840006719	\N	t	2026-08-10 20:23:13.360937+05:30	2026-08-10 20:23:18.003235+05:30	18	left the programme	\N	\N
169	1	Test Nurse 850	counsellor	9900000850	\N	t	2026-08-10 20:34:41.209188+05:30	\N	\N	\N	\N	\N
170	1	Ravi Kumar 7610	counsellor	9800007610	\N	t	2026-08-10 20:34:44.331186+05:30	\N	\N	\N	\N	\N
171	1	Rohit Kumar 7610	doctor	9810007610	\N	t	2026-08-10 20:34:45.728485+05:30	\N	\N	\N	\N	\N
172	1	Driver Singh 7610	driver	9820007610	\N	t	2026-08-10 20:34:47.039181+05:30	\N	\N	\N	\N	\N
202	1	Driver Singh 9753	driver	9820009753	\N	t	2026-08-11 09:30:28.747925+05:30	\N	\N	\N	\N	\N
274	1	Test Nurse 395	counsellor	9900000395	\N	t	2026-08-11 14:20:44.030498+05:30	\N	\N	\N	\N	\N
173	1	Temp Worker 2986	lab	9840002986	\N	t	2026-08-10 20:34:51.19058+05:30	2026-08-10 20:34:55.15636+05:30	18	left the programme	\N	\N
174	1	Test Nurse 630	counsellor	9900000630	\N	t	2026-08-10 20:47:47.19328+05:30	\N	\N	\N	\N	\N
175	1	Ravi Kumar 7160	counsellor	9800007160	\N	t	2026-08-10 20:47:50.363608+05:30	\N	\N	\N	\N	\N
176	1	Rohit Kumar 7160	doctor	9810007160	\N	t	2026-08-10 20:47:51.75114+05:30	\N	\N	\N	\N	\N
177	1	Driver Singh 7160	driver	9820007160	\N	t	2026-08-10 20:47:53.058856+05:30	\N	\N	\N	\N	\N
207	1	Driver Singh 2014	driver	9820002014	\N	t	2026-08-11 09:36:27.555658+05:30	\N	\N	\N	\N	\N
193	1	Temp Worker 4454	lab	9840004454	\N	t	2026-08-10 21:38:45.595629+05:30	2026-08-10 21:38:50.892993+05:30	18	left the programme	\N	\N
178	1	Temp Worker 1701	lab	9840001701	\N	t	2026-08-10 20:47:57.26639+05:30	2026-08-10 20:48:01.345815+05:30	18	left the programme	\N	\N
179	1	Test Nurse 531	counsellor	9900000531	\N	t	2026-08-10 21:13:56.286573+05:30	\N	\N	\N	\N	\N
180	1	Ravi Kumar 6559	counsellor	9800006559	\N	t	2026-08-10 21:14:00.956875+05:30	\N	\N	\N	\N	\N
181	1	Rohit Kumar 6559	doctor	9810006559	\N	t	2026-08-10 21:14:02.901957+05:30	\N	\N	\N	\N	\N
182	1	Driver Singh 6559	driver	9820006559	\N	t	2026-08-10 21:14:04.422567+05:30	\N	\N	\N	\N	\N
194	1	Test Nurse 562	counsellor	9900000562	\N	t	2026-08-10 21:48:59.966187+05:30	\N	\N	\N	\N	\N
195	1	Ravi Kumar 6249	counsellor	9800006249	\N	t	2026-08-10 21:49:04.893219+05:30	\N	\N	\N	\N	\N
196	1	Rohit Kumar 6249	doctor	9810006249	\N	t	2026-08-10 21:49:06.954403+05:30	\N	\N	\N	\N	\N
197	1	Driver Singh 6249	driver	9820006249	\N	t	2026-08-10 21:49:08.696005+05:30	\N	\N	\N	\N	\N
208	1	Temp Worker 5593	lab	9840005593	\N	t	2026-08-11 09:36:31.960351+05:30	2026-08-11 09:36:35.760356+05:30	18	left the programme	\N	\N
209	1	Test Nurse 320	counsellor	9900000320	\N	t	2026-08-11 09:52:21.460419+05:30	\N	\N	\N	\N	\N
203	1	Temp Worker 2378	lab	9840002378	\N	t	2026-08-11 09:30:33.342506+05:30	2026-08-11 09:30:38.369449+05:30	18	left the programme	\N	\N
204	1	Test Nurse 982	counsellor	9900000982	\N	t	2026-08-11 09:36:21.280715+05:30	\N	\N	\N	\N	\N
211	1	Rohit Kumar 6870	doctor	9810006870	\N	t	2026-08-11 09:52:25.324722+05:30	\N	\N	\N	\N	\N
210	1	Ravi Kumar 6870	counsellor	9800006870	\N	t	2026-08-11 09:52:23.96172+05:30	\N	\N	\N	\N	\N
212	1	Driver Singh 6870	driver	9820006870	\N	t	2026-08-11 09:52:26.659653+05:30	\N	\N	\N	\N	\N
213	1	Temp Worker 1188	lab	9840001188	\N	t	2026-08-11 09:52:30.487983+05:30	2026-08-11 09:52:34.959608+05:30	18	left the programme	\N	\N
5	1	Ram Prasad	driver	9876543211	\N	t	2026-08-03 15:44:07.114211+05:30	\N	\N	\N	\N	\N
6	1	Sanjeev Mahto (Gajraula)	counsellor	9446772675	\N	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
3	1	Kedar Dash	pharmacist	\N	1	t	2026-08-03 14:50:13.85991+05:30	\N	\N	\N	\N	\N
151	1	Rohit Kumar 2665	doctor	9810002665	\N	t	2026-08-10 19:41:26.394045+05:30	\N	\N	\N	\N	\N
7	1	Dr. Aakanksha Dua (Gajraula)	doctor	9152252264	\N	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
8	1	Priya Sharma (Gajraula)	lab	9481126024	\N	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
9	1	Kedar Dash (Gajraula)	pharmacist	9104867155	\N	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
10	1	Ram Prasad (Gajraula)	driver	9610403105	\N	t	2026-08-10 11:21:51.929567+05:30	\N	\N	\N	\N	\N
239	1	Driver Singh 9933	driver	9820009933	\N	t	2026-08-11 14:05:17.21921+05:30	\N	\N	\N	\N	\N
215	1	Test Nurse 284	counsellor	9900000284	\N	t	2026-08-11 11:14:16.150759+05:30	\N	\N	\N	\N	\N
216	1	Ravi Kumar 5738	counsellor	9800005738	\N	t	2026-08-11 11:14:19.185686+05:30	\N	\N	\N	\N	\N
217	1	Rohit Kumar 5738	doctor	9810005738	\N	t	2026-08-11 11:14:20.346603+05:30	\N	\N	\N	\N	\N
284	1	Test Nurse 356	counsellor	9900000356	\N	t	2026-08-11 14:31:20.01339+05:30	\N	\N	\N	\N	\N
285	1	Ravi Kumar 4850	counsellor	9800004850	\N	t	2026-08-11 14:31:23.159893+05:30	\N	\N	\N	\N	\N
219	1	Temp Worker 1539	lab	9840001539	\N	t	2026-08-11 11:14:24.95331+05:30	2026-08-11 11:14:27.943688+05:30	18	left the programme	\N	\N
241	1	Test Nurse 887	counsellor	9900000887	\N	t	2026-08-11 14:05:53.178037+05:30	\N	\N	\N	\N	\N
242	1	Ravi Kumar 3776	counsellor	9800003776	\N	t	2026-08-11 14:05:55.717608+05:30	\N	\N	\N	\N	\N
278	1	Temp Worker 8389	lab	9840008389	\N	t	2026-08-11 14:20:55.063926+05:30	2026-08-11 14:20:59.186425+05:30	18	left the programme	\N	\N
245	1	Temp Worker 1238	lab	9840001238	\N	t	2026-08-11 14:06:01.708349+05:30	2026-08-11 14:06:05.224039+05:30	18	left the programme	\N	\N
220	1	Test Nurse 563	counsellor	9900000563	\N	t	2026-08-11 13:59:34.715348+05:30	\N	\N	\N	\N	\N
221	1	Ravi Kumar 2820	counsellor	9800002820	\N	t	2026-08-11 13:59:37.999694+05:30	\N	\N	\N	\N	\N
222	1	Rohit Kumar 2820	doctor	9810002820	\N	t	2026-08-11 13:59:39.164657+05:30	\N	\N	\N	\N	\N
223	1	Driver Singh 2820	driver	9820002820	\N	t	2026-08-11 13:59:40.263996+05:30	\N	\N	\N	\N	\N
224	1	Temp Worker 5556	lab	9840005556	\N	t	2026-08-11 13:59:43.624095+05:30	2026-08-11 13:59:46.894986+05:30	18	left the programme	\N	\N
122	1	Driver Singh 1317	driver	9820001317	\N	t	2026-08-10 17:53:15.467192+05:30	\N	\N	\N	\N	\N
218	1	Driver Singh 5738	driver	9820005738	\N	t	2026-08-11 11:14:21.450054+05:30	\N	\N	\N	\N	\N
247	1	Ravi Kumar 1262	counsellor	9800001262	\N	t	2026-08-11 14:06:25.10046+05:30	\N	\N	\N	\N	\N
248	1	Rohit Kumar 1262	doctor	9810001262	\N	t	2026-08-11 14:06:26.262163+05:30	\N	\N	\N	\N	\N
225	1	Test Nurse 781	counsellor	9900000781	\N	t	2026-08-11 14:03:17.384597+05:30	\N	\N	\N	\N	\N
226	1	Ravi Kumar 7199	counsellor	9800007199	\N	t	2026-08-11 14:03:19.888512+05:30	\N	\N	\N	\N	\N
227	1	Rohit Kumar 7199	doctor	9810007199	\N	t	2026-08-11 14:03:21.089048+05:30	\N	\N	\N	\N	\N
228	1	Driver Singh 7199	driver	9820007199	\N	t	2026-08-11 14:03:22.289303+05:30	\N	\N	\N	\N	\N
286	1	Rohit Kumar 4850	doctor	9810004850	\N	t	2026-08-11 14:31:24.568622+05:30	\N	\N	\N	\N	\N
229	1	Temp Worker 1241	lab	9840001241	\N	t	2026-08-11 14:03:25.692362+05:30	2026-08-11 14:03:28.801267+05:30	18	left the programme	\N	\N
251	1	Test Nurse 312	counsellor	9900000312	\N	t	2026-08-11 14:06:52.07378+05:30	\N	\N	\N	\N	\N
252	1	Ravi Kumar 3632	counsellor	9800003632	\N	t	2026-08-11 14:06:55.095073+05:30	\N	\N	\N	\N	\N
254	1	Driver Singh 3632	driver	9820003632	\N	t	2026-08-11 14:06:57.389135+05:30	\N	\N	\N	\N	\N
230	1	Test Nurse 271	counsellor	9900000271	\N	t	2026-08-11 14:04:23.230805+05:30	\N	\N	\N	\N	\N
231	1	Test Nurse 827	counsellor	9900000827	\N	t	2026-08-11 14:04:42.405224+05:30	\N	\N	\N	\N	\N
232	1	Ravi Kumar 4690	counsellor	9800004690	\N	t	2026-08-11 14:04:45.359799+05:30	\N	\N	\N	\N	\N
233	1	Rohit Kumar 4690	doctor	9810004690	\N	t	2026-08-11 14:04:46.547321+05:30	\N	\N	\N	\N	\N
234	1	Driver Singh 4690	driver	9820004690	\N	t	2026-08-11 14:04:47.854993+05:30	\N	\N	\N	\N	\N
235	1	Temp Worker 9249	lab	9840009249	\N	t	2026-08-11 14:04:51.438118+05:30	2026-08-11 14:04:54.751988+05:30	18	left the programme	\N	\N
287	1	Driver Singh 4850	driver	9820004850	\N	t	2026-08-11 14:31:25.955665+05:30	\N	\N	\N	\N	\N
275	1	Ravi Kumar 7839	counsellor	9800007839	\N	t	2026-08-11 14:20:47.518129+05:30	\N	\N	\N	\N	\N
295	1	Ravi Kumar 7509	counsellor	9800007509	\N	t	2026-08-11 15:10:15.258602+05:30	\N	\N	\N	\N	\N
280	1	Ravi Kumar 1300	counsellor	9800001300	\N	t	2026-08-11 14:26:41.791244+05:30	\N	\N	\N	\N	\N
281	1	Rohit Kumar 1300	doctor	9810001300	\N	t	2026-08-11 14:26:43.285779+05:30	\N	\N	\N	\N	\N
282	1	Driver Singh 1300	driver	9820001300	\N	t	2026-08-11 14:26:44.849642+05:30	\N	\N	\N	\N	\N
296	1	Rohit Kumar 7509	doctor	9810007509	\N	t	2026-08-11 15:10:16.708194+05:30	\N	\N	\N	\N	\N
293	1	Temp Worker 5923	lab	9840005923	\N	t	2026-08-11 14:32:38.213456+05:30	2026-08-11 14:32:41.648103+05:30	18	left the programme	\N	\N
288	1	Temp Worker 5481	lab	9840005481	\N	t	2026-08-11 14:31:30.25289+05:30	2026-08-11 14:31:33.837739+05:30	18	left the programme	\N	\N
283	1	Temp Worker 3702	lab	9840003702	\N	t	2026-08-11 14:26:49.107694+05:30	2026-08-11 14:26:52.773628+05:30	18	left the programme	\N	\N
297	1	Driver Singh 7509	driver	9820007509	\N	t	2026-08-11 15:10:17.992494+05:30	\N	\N	\N	\N	\N
289	1	Test Nurse 649	counsellor	9900000649	\N	t	2026-08-11 14:32:28.565966+05:30	\N	\N	\N	\N	\N
290	1	Ravi Kumar 9027	counsellor	9800009027	\N	t	2026-08-11 14:32:31.707113+05:30	\N	\N	\N	\N	\N
291	1	Rohit Kumar 9027	doctor	9810009027	\N	t	2026-08-11 14:32:33.074099+05:30	\N	\N	\N	\N	\N
292	1	Driver Singh 9027	driver	9820009027	\N	t	2026-08-11 14:32:34.230871+05:30	\N	\N	\N	\N	\N
299	1	Test Nurse 976	counsellor	9900000976	\N	t	2026-08-11 15:54:07.814497+05:30	\N	\N	\N	\N	\N
294	1	Test Nurse 662	counsellor	9900000662	\N	t	2026-08-11 15:10:12.345259+05:30	\N	\N	\N	\N	\N
249	1	Driver Singh 1262	driver	9820001262	\N	t	2026-08-11 14:06:27.381617+05:30	\N	\N	\N	\N	\N
298	1	Temp Worker 4935	lab	9840004935	\N	t	2026-08-11 15:10:21.690387+05:30	2026-08-11 15:10:25.160684+05:30	18	left the programme	\N	\N
300	1	Ravi Kumar 9073	counsellor	9800009073	\N	t	2026-08-11 15:54:10.775258+05:30	\N	\N	\N	\N	\N
301	1	Rohit Kumar 9073	doctor	9810009073	\N	t	2026-08-11 15:54:12.049981+05:30	\N	\N	\N	\N	\N
302	1	Driver Singh 9073	driver	9820009073	\N	t	2026-08-11 15:54:13.276253+05:30	\N	\N	\N	\N	\N
303	1	Temp Worker 5516	lab	9840005516	\N	t	2026-08-11 15:54:16.932526+05:30	2026-08-11 15:54:20.532573+05:30	18	left the programme	\N	\N
214	1	Counsellor	counsellor	9097513232	1	t	2026-08-11 10:43:42.049668+05:30	\N	\N	\N	\N	\N
1	1	Sanjeev Mahto	counsellor	\N	1	t	2026-08-03 14:50:13.85991+05:30	\N	\N	\N	\N	\N
2	1	Dr. Aakanksha Dua	doctor	\N	1	t	2026-08-03 14:50:13.85991+05:30	\N	\N	\N	\N	\N
4	1	Anil Yadav	lab	\N	1	t	2026-08-03 14:50:13.85991+05:30	\N	\N	\N	\N	\N
\.


--
-- TOC entry 5878 (class 0 OID 30659)
-- Dependencies: 239
-- Data for Name: staff_assignment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.staff_assignment (assignment_id, staff_id, facility_id, role, from_date, to_date, deleted_at, deleted_by, delete_reason) FROM stdin;
\.


--
-- TOC entry 5864 (class 0 OID 30469)
-- Dependencies: 225
-- Data for Name: state_ref; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.state_ref (state_id, state_code, state_name, is_active) FROM stdin;
1	AS	Assam	t
2	BR	Bihar	t
3	DN	Daman & Diu	t
4	GA	Goa	t
5	GJ	Gujarat	t
6	HR	Haryana	t
7	JH	Jharkhand	t
8	KA	Karnataka	t
9	MP	Madhya Pradesh	t
10	MH	Maharashtra	t
11	OD	Odisha	t
12	PB	Punjab	t
13	RJ	Rajasthan	t
14	TN	Tamil Nadu	t
15	TG	Telangana	t
16	UP	Uttar Pradesh	t
17	UT	Uttarakhand	t
18	WB	West Bengal	t
19	TF	Test State 3776	f
20	WG	Test State 9398	f
21	ZS	Test State 5497	f
22	WX	Test State 3913	f
23	LA	Test State 7797	f
24	JO	Test State 8247	f
25	SR	Test State 9426	f
26	ED	Test State 8160	f
27	BT	Test State 7509	f
28	HF	Test State 6717	f
29	FX	Test State 3153	f
30	CG	Test State 7800	f
31	CM	Test State 5908	f
32	RE	Test State 6988	f
33	XU	Test State 4967	f
34	PX	Test State 2177	f
35	CL	Test State 7731	f
36	KH	Test State 7357	f
37	WY	Test State 8082	f
38	XB	Test State 1669	f
39	AC	Test State 2660	f
40	SE	Test State 1650	f
41	HD	Test State 9071	f
43	JK	Test State 5879	f
44	WF	Test State 1178	f
45	JY	Test State 5826	f
46	JA	Test State 7686	f
47	WV	Test State 9419	f
48	DX	Test State 4068	f
49	TY	Test State 4454	f
80	YA	Test State 2468	f
81	UZ	Test State 4271	f
82	GN	Test State 5493	f
83	WO	Test State 6612	f
84	ID	Test State 2527	f
85	XE	Test State 1381	f
\.


--
-- TOC entry 5860 (class 0 OID 30430)
-- Dependencies: 221
-- Data for Name: subscription_tier; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.subscription_tier (tier_id, label, months, patient_limit, price, is_active) FROM stdin;
free	Free	0	200	0.00	t
3mo	3 months	3	500	999.00	t
6mo	6 months	6	1500	2499.00	t
1yr	1 year	12	3000	3999.00	t
\.


--
-- TOC entry 5886 (class 0 OID 30771)
-- Dependencies: 247
-- Data for Name: symptom_master; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.symptom_master (symptom_id, symptom_name, aliases, is_custom, is_active) FROM stdin;
1	Fever	{}	f	t
2	Cough	{}	f	t
3	Cold	{}	f	t
4	Headache	{}	f	t
5	Body ache	{}	f	t
6	Weakness	{}	f	t
7	Vomiting	{}	f	t
8	Diarrhoea	{}	f	t
9	Abdominal pain	{}	f	t
10	Chest pain	{}	f	t
11	Shortness of breath	{}	f	t
12	Sore throat	{}	f	t
13	Runny nose	{}	f	t
14	Joint Pain	{}	f	t
15	Skin rash	{}	f	t
16	Dizziness	{}	f	t
17	Palpitations	{}	f	t
18	Burning Micturition	{}	f	t
19	Frequent urination	{}	f	t
20	Loss of appetite	{}	f	t
21	Weight loss	{}	f	t
22	Chills	{}	f	t
23	Sweating	{}	f	t
24	Nausea	{}	f	t
25	Wheezing	{}	f	t
26	Back pain	{}	f	t
27	Swelling	{}	f	t
28	Blurred vision	{}	f	t
29	Ear pain	{}	f	t
30	Constipation	{}	f	t
\.


--
-- TOC entry 5941 (class 0 OID 57424)
-- Dependencies: 312
-- Data for Name: sync_action; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sync_action (sync_action_id, user_id, client_action_id, client_batch_id, kind, status, server_id, result, error_code, error_message, applied_at) FROM stdin;
1	1	reg-1786436162	batch-1	patient.register	applied	157	{"patient_id": 161, "unique_code": "GN-0137", "appointment_id": 157}	\N	\N	2026-08-11 13:46:03.760099+05:30
2	1	bad-1786436164	\N	appointment.doctor_submit	rejected	\N	\N	FORBIDDEN	A counsellor cannot perform this action	2026-08-11 13:46:04.113745+05:30
3	2	dx-1786436187	b2	appointment.doctor_submit	applied	157	{"status": "with_counsellor", "appointment_id": 157}	\N	\N	2026-08-11 13:46:27.348337+05:30
4	1	test-8jbdsg4o	test-m4sb8nyu	patient.register	applied	164	{"patient_id": 170, "unique_code": "GN-0146", "appointment_id": 164}	\N	\N	2026-08-11 14:08:49.325926+05:30
5	1	test-bkpfi2gc	\N	patient.register	applied	165	{"patient_id": 171, "unique_code": "GN-0147", "appointment_id": 165}	\N	\N	2026-08-11 14:08:49.369591+05:30
6	1	test-9ojt7106	\N	patient.register	rejected	\N	\N	UNPROCESSABLE	Unknown village 'Nowhere At All'	2026-08-11 14:08:49.377343+05:30
7	1	test-15ztlxwp	\N	not.a.kind	rejected	\N	\N	UNPROCESSABLE	Unknown action 'not.a.kind'	2026-08-11 14:08:49.386027+05:30
8	1	test-t6615uyq	\N	appointment.doctor_submit	rejected	\N	\N	FORBIDDEN	A counsellor cannot perform this action	2026-08-11 14:08:49.394078+05:30
9	2	test-msy4ojxo	\N	appointment.doctor_submit	applied	165	{"status": "with_counsellor", "appointment_id": 165}	\N	\N	2026-08-11 14:08:49.847387+05:30
10	1	test-hfdwxgu9	test-o75u6vfp	patient.register	applied	167	{"patient_id": 172, "unique_code": "GN-0148", "appointment_id": 167}	\N	\N	2026-08-11 14:09:11.158434+05:30
11	1	test-579zc6iq	\N	patient.register	applied	168	{"patient_id": 173, "unique_code": "GN-0149", "appointment_id": 168}	\N	\N	2026-08-11 14:09:11.185167+05:30
12	1	test-v6xcohd2	\N	patient.register	rejected	\N	\N	UNPROCESSABLE	Unknown village 'Nowhere At All'	2026-08-11 14:09:11.18863+05:30
13	1	test-t1g1suk2	\N	not.a.kind	rejected	\N	\N	UNPROCESSABLE	Unknown action 'not.a.kind'	2026-08-11 14:09:11.19011+05:30
14	1	test-vyifiuk3	\N	appointment.doctor_submit	rejected	\N	\N	FORBIDDEN	A counsellor cannot perform this action	2026-08-11 14:09:11.19588+05:30
15	2	test-hnlcxe2c	\N	appointment.doctor_submit	applied	168	{"status": "with_counsellor", "appointment_id": 168}	\N	\N	2026-08-11 14:09:11.680927+05:30
37	1	test-qf1ovg8h	test-vp6f91q5	patient.register	applied	197	{"patient_id": 203, "unique_code": "GN-0150", "appointment_id": 197}	\N	\N	2026-08-11 14:17:35.177614+05:30
38	1	test-jxnt6zxj	\N	patient.register	applied	198	{"patient_id": 204, "unique_code": "GN-0151", "appointment_id": 198}	\N	\N	2026-08-11 14:17:35.211937+05:30
39	1	test-rw44vkcp	\N	patient.register	rejected	\N	\N	UNPROCESSABLE	Unknown village 'Nowhere At All'	2026-08-11 14:17:35.218642+05:30
40	1	test-udlyvjuu	\N	not.a.kind	rejected	\N	\N	UNPROCESSABLE	Unknown action 'not.a.kind'	2026-08-11 14:17:35.223074+05:30
41	1	test-pwlnc8gl	\N	appointment.doctor_submit	rejected	\N	\N	FORBIDDEN	A counsellor cannot perform this action	2026-08-11 14:17:35.233308+05:30
42	2	test-rlkd92b6	\N	appointment.doctor_submit	applied	198	{"status": "with_counsellor", "appointment_id": 198}	\N	\N	2026-08-11 14:17:35.99208+05:30
43	1	test-3u15pflx	test-6ydtynqq	patient.register	applied	200	{"patient_id": 205, "unique_code": "GN-0152", "appointment_id": 200}	\N	\N	2026-08-11 14:18:04.374887+05:30
44	1	test-os1zgnlk	\N	patient.register	applied	201	{"patient_id": 206, "unique_code": "GN-0153", "appointment_id": 201}	\N	\N	2026-08-11 14:18:04.404583+05:30
45	1	test-ca3ym17u	\N	patient.register	rejected	\N	\N	UNPROCESSABLE	Unknown village 'Nowhere At All'	2026-08-11 14:18:04.411101+05:30
46	1	test-a4rvjdbd	\N	not.a.kind	rejected	\N	\N	UNPROCESSABLE	Unknown action 'not.a.kind'	2026-08-11 14:18:04.412982+05:30
47	1	test-58v1plem	\N	appointment.doctor_submit	rejected	\N	\N	FORBIDDEN	A counsellor cannot perform this action	2026-08-11 14:18:04.423502+05:30
48	2	test-aimradlu	\N	appointment.doctor_submit	applied	201	{"status": "with_counsellor", "appointment_id": 201}	\N	\N	2026-08-11 14:18:05.094654+05:30
49	1	test-4hk61ccp	test-7j6z2tqb	patient.register	applied	203	{"patient_id": 207, "unique_code": "GN-0154", "appointment_id": 203}	\N	\N	2026-08-11 14:19:21.561882+05:30
50	1	test-61hmwtfj	\N	patient.register	applied	204	{"patient_id": 208, "unique_code": "GN-0155", "appointment_id": 204}	\N	\N	2026-08-11 14:19:21.627289+05:30
51	1	test-56q9ztg9	\N	patient.register	rejected	\N	\N	UNPROCESSABLE	Unknown village 'Nowhere At All'	2026-08-11 14:19:21.633785+05:30
52	1	test-nlwigkkt	\N	not.a.kind	rejected	\N	\N	UNPROCESSABLE	Unknown action 'not.a.kind'	2026-08-11 14:19:21.63626+05:30
53	1	test-w066myff	\N	appointment.doctor_submit	rejected	\N	\N	FORBIDDEN	A counsellor cannot perform this action	2026-08-11 14:19:21.647229+05:30
54	2	test-007oyrso	\N	appointment.doctor_submit	applied	204	{"status": "with_counsellor", "appointment_id": 204}	\N	\N	2026-08-11 14:19:22.185985+05:30
55	1	test-g4d2stv2	test-mw3y8et0	patient.register	applied	206	{"patient_id": 209, "unique_code": "GN-0156", "appointment_id": 206}	\N	\N	2026-08-11 14:19:51.600227+05:30
56	1	test-9rtndxko	\N	patient.register	applied	207	{"patient_id": 210, "unique_code": "GN-0157", "appointment_id": 207}	\N	\N	2026-08-11 14:19:51.693284+05:30
57	1	test-134erex3	\N	patient.register	rejected	\N	\N	UNPROCESSABLE	Unknown village 'Nowhere At All'	2026-08-11 14:19:51.699252+05:30
58	1	test-kxptwba3	\N	not.a.kind	rejected	\N	\N	UNPROCESSABLE	Unknown action 'not.a.kind'	2026-08-11 14:19:51.701346+05:30
59	1	test-vln0lyxx	\N	appointment.doctor_submit	rejected	\N	\N	FORBIDDEN	A counsellor cannot perform this action	2026-08-11 14:19:51.711577+05:30
60	2	test-6mbimowq	\N	appointment.doctor_submit	applied	207	{"status": "with_counsellor", "appointment_id": 207}	\N	\N	2026-08-11 14:19:52.3684+05:30
61	1	test-n04ptrky	test-nho7xmnf	patient.register	applied	210	{"patient_id": 212, "unique_code": "GN-0159", "appointment_id": 210}	\N	\N	2026-08-11 14:25:52.254156+05:30
62	1	test-z3190fnh	\N	patient.register	applied	211	{"patient_id": 213, "unique_code": "GN-0160", "appointment_id": 211}	\N	\N	2026-08-11 14:25:52.275173+05:30
63	1	test-0ec8u0ks	\N	patient.register	rejected	\N	\N	UNPROCESSABLE	Unknown village 'Nowhere At All'	2026-08-11 14:25:52.280973+05:30
64	1	test-f48m8qnj	\N	not.a.kind	rejected	\N	\N	UNPROCESSABLE	Unknown action 'not.a.kind'	2026-08-11 14:25:52.282744+05:30
65	1	test-hb74cyv1	\N	appointment.doctor_submit	rejected	\N	\N	FORBIDDEN	A counsellor cannot perform this action	2026-08-11 14:25:52.289277+05:30
66	2	test-sb1e4ltg	\N	appointment.doctor_submit	applied	211	{"status": "with_counsellor", "appointment_id": 211}	\N	\N	2026-08-11 14:25:52.848927+05:30
67	1	test-9llee9uw	test-rp8o20xg	patient.register	applied	214	{"patient_id": 215, "unique_code": "GN-0162", "appointment_id": 214}	\N	\N	2026-08-11 14:31:08.299525+05:30
68	1	test-fdf5qjfc	\N	patient.register	applied	215	{"patient_id": 216, "unique_code": "GN-0163", "appointment_id": 215}	\N	\N	2026-08-11 14:31:08.369345+05:30
69	1	test-rj8hstwr	\N	patient.register	rejected	\N	\N	UNPROCESSABLE	Unknown village 'Nowhere At All'	2026-08-11 14:31:08.391577+05:30
70	1	test-6jkf19pg	\N	not.a.kind	rejected	\N	\N	UNPROCESSABLE	Unknown action 'not.a.kind'	2026-08-11 14:31:08.398325+05:30
71	1	test-br9h8tnz	\N	appointment.doctor_submit	rejected	\N	\N	FORBIDDEN	A counsellor cannot perform this action	2026-08-11 14:31:08.40949+05:30
72	2	test-7imtg6ud	\N	appointment.doctor_submit	applied	215	{"status": "with_counsellor", "appointment_id": 215}	\N	\N	2026-08-11 14:31:08.941776+05:30
73	1	test-kt44onq0	test-4noq60en	patient.register	applied	218	{"patient_id": 218, "unique_code": "GN-0165", "appointment_id": 218}	\N	\N	2026-08-11 14:32:16.685579+05:30
74	1	test-dmwuqtli	\N	patient.register	applied	219	{"patient_id": 219, "unique_code": "GN-0166", "appointment_id": 219}	\N	\N	2026-08-11 14:32:16.715998+05:30
75	1	test-dhpadzlv	\N	patient.register	rejected	\N	\N	UNPROCESSABLE	Unknown village 'Nowhere At All'	2026-08-11 14:32:16.73804+05:30
76	1	test-p7nrnucz	\N	not.a.kind	rejected	\N	\N	UNPROCESSABLE	Unknown action 'not.a.kind'	2026-08-11 14:32:16.741002+05:30
77	1	test-0eeygh8p	\N	appointment.doctor_submit	rejected	\N	\N	FORBIDDEN	A counsellor cannot perform this action	2026-08-11 14:32:16.751659+05:30
78	2	test-kv5c7cto	\N	appointment.doctor_submit	applied	219	{"status": "with_counsellor", "appointment_id": 219}	\N	\N	2026-08-11 14:32:17.234429+05:30
79	1	test-zl6hsvcp	test-6cm2ir7a	patient.register	applied	222	{"patient_id": 221, "unique_code": "GN-0168", "appointment_id": 222}	\N	\N	2026-08-11 15:10:01.059541+05:30
80	1	test-dlhlmyk0	\N	patient.register	applied	223	{"patient_id": 222, "unique_code": "GN-0169", "appointment_id": 223}	\N	\N	2026-08-11 15:10:01.079534+05:30
81	1	test-hjzun7p1	\N	patient.register	rejected	\N	\N	UNPROCESSABLE	Unknown village 'Nowhere At All'	2026-08-11 15:10:01.084926+05:30
82	1	test-7gdi4ghv	\N	not.a.kind	rejected	\N	\N	UNPROCESSABLE	Unknown action 'not.a.kind'	2026-08-11 15:10:01.086665+05:30
83	1	test-wxarb9rh	\N	appointment.doctor_submit	rejected	\N	\N	FORBIDDEN	A counsellor cannot perform this action	2026-08-11 15:10:01.093345+05:30
84	2	test-4vl1gdiv	\N	appointment.doctor_submit	applied	223	{"status": "with_counsellor", "appointment_id": 223}	\N	\N	2026-08-11 15:10:01.563267+05:30
85	1	test-v553of30	test-qs0sswo5	patient.register	applied	226	{"patient_id": 224, "unique_code": "GN-0171", "appointment_id": 226}	\N	\N	2026-08-11 15:53:56.222826+05:30
86	1	test-n0rbkk02	\N	patient.register	applied	227	{"patient_id": 225, "unique_code": "GN-0172", "appointment_id": 227}	\N	\N	2026-08-11 15:53:56.246247+05:30
87	1	test-dald0xv7	\N	patient.register	rejected	\N	\N	UNPROCESSABLE	Unknown village 'Nowhere At All'	2026-08-11 15:53:56.250578+05:30
88	1	test-6lj2632v	\N	not.a.kind	rejected	\N	\N	UNPROCESSABLE	Unknown action 'not.a.kind'	2026-08-11 15:53:56.252544+05:30
89	1	test-yqgaxf0a	\N	appointment.doctor_submit	rejected	\N	\N	FORBIDDEN	A counsellor cannot perform this action	2026-08-11 15:53:56.261306+05:30
90	2	test-ogh7pkwc	\N	appointment.doctor_submit	applied	227	{"status": "with_counsellor", "appointment_id": 227}	\N	\N	2026-08-11 15:53:56.823863+05:30
\.


--
-- TOC entry 5935 (class 0 OID 32817)
-- Dependencies: 297
-- Data for Name: user_zone; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_zone (user_zone_id, user_id, state_id, district_id, created_at, deleted_at, deleted_by, delete_reason) FROM stdin;
1	8	16	48	2026-08-09 22:37:00.490829+05:30	\N	\N	\N
2	20	16	\N	2026-08-10 00:16:14.489338+05:30	\N	\N	\N
\.


--
-- TOC entry 5870 (class 0 OID 30526)
-- Dependencies: 231
-- Data for Name: village_ref; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.village_ref (village_id, block_id, village_name, is_active) FROM stdin;
1	1	Amara Pathar	t
2	1	Barua Bari Gaon	t
3	1	Batakuchi Nc	t
4	1	Bijini Ghat	t
5	1	Damora Pathar	t
6	1	Dhangiri Gaon	t
7	1	Digaru	t
8	1	Gomoria Gaon	t
9	1	Kapalkata	t
10	1	Mitanu Pathar	t
11	1	Patirkuchi	t
12	1	Samota	t
13	1	Sonapur Ghat	t
14	1	Sultanpur	t
15	1	Tegharia	t
16	1	Teteliguri Pathar	t
17	2	9th Mile	t
18	2	Bashistha Lakhara	t
19	2	Beltola	t
20	2	Bharalumukh Slum Pocket	t
21	2	Boragaon Garbage Belt Settlements	t
22	2	Fatasil Ambari Basti	t
23	2	Goriaguli	t
24	2	Hahara	t
25	2	Hatigaon Slum Cluster	t
26	2	Hatimura	t
27	2	Jalukbari	t
28	2	Kamarkuchi	t
29	2	Khanapara Lotakata	t
30	2	Khetri	t
31	2	Lalungoan Garchuk	t
32	2	Lokhra Char Area	t
33	2	Maligaon Railway Colony Adjacent Slums	t
34	2	Medikuchi	t
35	2	Pamohi Maligaon	t
36	2	Pandu	t
37	2	Pandu Riverside Settlements	t
38	2	Patharkuchi	t
39	2	Sonapur	t
40	2	Sundernagar	t
41	2	Survey Char	t
42	2	West Jalukbari Basti	t
43	3	Ashiana Nagar	t
44	4	Atiawad	t
45	4	Bhimpore	t
46	4	Dabhel	t
47	4	Daman	t
48	4	Dunetha	t
49	4	Ghelwad	t
50	4	Somnath	t
51	4	Varkund	t
52	5	Ameshiwada Amona	t
53	5	Amona	t
54	5	Bandarwada Amona	t
55	5	Barniwada Navelim	t
56	5	Betalwada	t
57	5	Betki- Khandola	t
58	5	Dakulmaina Navelim	t
59	5	Dhabdhba	t
60	5	Durikwada Navelim	t
61	5	Fanaswadi Navelim	t
62	5	Gaonkarwada	t
63	5	Ghoogremaina	t
64	5	Khumbharwada	t
65	5	Lamgao	t
66	5	Mastiwada Navelim	t
67	5	Navelim	t
68	5	Pilgao	t
69	5	Pimplewada Amona	t
70	5	Sarmanas	t
71	5	Sirigao	t
72	5	Tariwada Amona	t
73	5	Tikhajan	t
74	5	Upper Durikwada	t
75	5	Virdi	t
76	6	Motera	t
77	7	Chandkheda	t
78	8	Amritpura	t
79	8	Ankleshwar	t
80	8	Boidra	t
81	8	Kasiya	t
82	8	Kharchi	t
83	8	Mandva	t
84	8	Motali	t
85	8	Mulad	t
86	8	Nana Sanja	t
87	8	Naugama	t
88	8	Samor	t
89	8	Uchali	t
90	9	Cholad	t
91	9	Dayadara	t
92	9	Derol	t
93	9	Kalla	t
94	9	Kelod	t
95	9	Kothi	t
96	9	Other	t
97	9	Sarnar	t
98	9	Talsa	t
99	9	Vachhnad	t
100	9	Vahalu	t
101	9	Vasi	t
102	10	Other	t
103	11	Aankot	t
104	11	Argama	t
105	11	Bhersam	t
106	11	Juned	t
107	11	Kelod	t
108	11	Kothi	t
109	11	Other	t
110	11	Rahad	t
111	11	Saladara	t
112	11	Talsa	t
113	11	Vacchnad	t
114	11	Vilayat	t
115	11	Vorasamni	t
116	12	Other	t
117	13	Amirpura	t
118	13	Chorpura	t
119	13	Gagandiya	t
120	13	Gothada 1	t
121	13	Gothada 2	t
122	13	Gothda 3	t
123	13	Javla	t
124	13	Juna Samlaya	t
125	13	Karchia	t
126	13	Khanderavpura	t
127	13	Lasundra	t
128	13	Manoharpura	t
129	13	Manorpura	t
130	13	Nani Bhadol	t
131	13	Other	t
132	13	Pasva	t
133	13	Pratap Nagar	t
134	13	Radhanpura	t
135	13	Radhanpura 2	t
136	13	Samantpura	t
137	13	Sherpura	t
138	13	Subhelav	t
139	13	Test Unnao	t
140	13	Vankaner	t
141	13	Vemar	t
142	14	Adampur	t
143	14	Gopalpur	t
144	14	Kho	t
145	14	Kidoli	t
146	14	Pathreri	t
147	14	Pehladpur	t
148	14	Skh Plant Kharkhoda	t
149	14	Skh Plant M1	t
150	14	Skh Plant M2	t
151	14	Skh Plant M3	t
152	14	Skh Plant Mm	t
153	14	Skh Technology	t
154	15	Jhabua	t
155	15	Khijuri	t
156	15	Patuhera	t
157	16	Bhaganki	t
158	16	Khor	t
159	16	Lokra	t
160	16	Lokri	t
161	16	Mau	t
162	17	Bhatsana	t
163	17	Maheshwari	t
164	17	Tatarpur Khalsa	t
165	18	Bhaganki	t
166	18	Kalwari	t
167	19	Hassanpur	t
168	19	Jourasi	t
169	20	Jharsa	t
170	20	Kadarpur	t
171	20	Khandsa	t
172	21	Fatehpur	t
173	21	Munimpur	t
174	21	Nimana	t
175	21	Other	t
176	21	Sondhi	t
177	21	Yakubpur	t
178	22	Bid Dadri	t
179	22	Canteen Labour 7	t
180	22	Dadri Toye	t
181	22	Jahidpur	t
182	22	Jhangirpur	t
183	22	Kaloi	t
184	22	Kheri Jatt	t
185	22	Kutani	t
186	22	Naurangpur	t
187	22	Navodayâ School	t
188	22	Other	t
189	22	Ramgarh Dhani	t
190	22	Surha	t
191	22	Untlodha	t
192	23	Other	t
193	24	Chandol	t
194	24	Dhakla	t
195	24	Other	t
196	24	Subana	t
197	25	Aliyar	t
198	25	Bilaspur Kailan	t
199	25	Bilaspur Khurd	t
200	25	Dhana	t
201	25	Jhundsarai	t
202	25	Kharkhoda	t
203	25	Kho	t
204	25	Manesar	t
205	25	Pathreri	t
206	25	Skh M3	t
207	25	Skh Plant	t
208	26	Bid Dadri	t
209	26	Chandol	t
210	26	Dadri Toye	t
211	26	Dhakla	t
212	26	Fatehpur	t
213	26	Jahidpur	t
214	26	Kaloi	t
215	26	Kukdola	t
216	26	Kutani	t
217	26	Munimpur	t
218	26	Nangla	t
219	26	Naurangpur	t
220	26	Nimana	t
221	26	Other	t
222	26	Ramgarh Dhani	t
223	26	Sondhi	t
224	26	Subana	t
225	26	Untlodha	t
226	26	Yakubpur	t
227	27	Bhupania	t
228	27	Ghubana	t
229	27	Goela Kalan	t
230	27	Harinagar	t
231	27	Khera Khurrampur	t
232	27	Kheri Jatt	t
233	27	Khungai	t
234	27	Khurrampur	t
235	27	Majri	t
236	27	Nayanganpur	t
237	27	Nihon Mmu	t
238	27	Silana	t
239	27	Silani	t
240	27	Sucha (Naudunga)	t
241	27	Uthloda	t
242	27	Zhaidpur	t
243	28	Reliance Clinic	t
244	29	Bamnola	t
245	29	Bgbc Labor Camp	t
246	29	Bgcc (Sec 5&7)	t
247	29	Daryapur	t
248	29	Dewerkhana	t
249	29	Fatehpur	t
250	29	Ic 3 Labor Camp	t
251	29	Ismilepur	t
252	29	Kukdola	t
253	29	Ladpur	t
254	29	Lagarpur	t
255	29	Lohat	t
256	29	M.P Mazra	t
257	29	Mundakhera	t
258	29	Munimpur	t
259	29	Nimana	t
260	29	Other	t
261	29	Other Labour Camp	t
262	29	Pahasaur	t
263	29	Pelpa	t
264	29	Reliance Retail	t
265	29	Sec 3 Cgl	t
266	29	Sec 4	t
267	29	Sondhi	t
268	29	Ugt (Sec 5)	t
269	29	Yakubpur	t
270	30	Aurangpur	t
271	30	Dadri Toye	t
272	30	Harinagar Duma	t
273	30	Jahangirpur	t
274	30	Kaloi	t
275	30	Kutani	t
276	30	Mubarikpur	t
277	30	Nangla	t
278	30	Ramgarh Dhani	t
279	30	Sector 7	t
280	30	Sector 8	t
281	30	Surah	t
282	30	Untlodha	t
283	30	Wtp	t
284	31	Bero (Fringe Villages)	t
285	31	Bukru	t
286	31	Hesal	t
287	31	Jaratoli	t
288	31	Kanke (Rural)	t
289	31	Lapung	t
290	31	Nagri	t
291	31	Namkum (Rural Pockets)	t
292	31	Patratoli	t
293	31	Pithoria	t
294	31	Silli Border Villages	t
295	32	Basavanagudi	t
296	32	Basaveshwaranagar	t
297	32	Cunningham Road	t
298	32	Hebbal	t
299	32	Indiranagar	t
300	32	Jayanagar	t
301	32	Koramangala	t
302	32	Mahalakshmi Layout	t
303	32	Malleshpalya	t
304	32	Malleswaram West	t
305	32	Rajajinagar	t
306	32	Rajiv Gandhi Nagar	t
307	32	Richmond Town	t
308	32	Sadashivanagar	t
309	32	Sampige Road	t
310	32	Seshadripuram	t
311	32	Shivajinagar	t
312	32	Vidyaranayaapura	t
313	32	Yeshwanthpur	t
314	33	Abachikkanahalli	t
315	33	Agalakote	t
316	33	Akkalenahalli Mallena - Halli	t
317	33	Alurdoddanahalli	t
318	33	Anighatta	t
319	33	Anneswara	t
320	33	Aradeshahalli	t
321	33	Arasanahalli Peddanahalli	t
322	33	Arasinakunte	t
323	33	Aruvanahalli	t
324	33	Attibele	t
325	33	Avathi	t
326	33	Bachahalli	t
327	33	Baladimmanahalli	t
328	33	Balepura	t
329	33	Bammanahalli	t
330	33	Bandaramanahalli	t
331	33	Bannimangala	t
332	33	Bediganahalli	t
333	33	Beerasandra	t
334	33	Bettakote	t
335	33	Bettakote Amanikere	t
336	33	Bettenahalli	t
337	33	Bhatramarenahalli	t
338	33	Bidalapura	t
339	33	Bidalapura Amanikere	t
340	33	Bidalur	t
341	33	Bijjawara	t
342	33	Binnamangala	t
343	33	Bommawara	t
344	33	Boodihal	t
345	33	Boovanahalli	t
346	33	Budigere	t
347	33	Bullahalli	t
348	33	Byadarahalli	t
349	33	Bychapura	t
350	33	Byradenahalli	t
351	33	Byrappanahalli	t
352	33	Byrapura	t
353	33	Chandenahalli	t
354	33	Channahalli	t
355	33	Channarayapatna	t
356	33	Chapparadahalli	t
357	33	Cheemachanahalli	t
358	33	Chikka Thattamangala	t
359	33	Chikkachimanahalli	t
360	33	Chikkagollahalli	t
361	33	Chikkanahalli	t
362	33	Chikkannanahosahalli	t
363	33	Chikkasanne	t
364	33	Chikkenahalli	t
365	33	Chikkobanahalli	t
366	33	Chinnakempanahalli	t
367	33	Chinnappanayakana Hosur	t
368	33	Chowdenahalli	t
369	33	Dandiganahalli	t
370	33	Dasarahalli	t
371	33	Devaganahalli	t
372	33	Devanayakanahalli	t
373	33	Devenahalli	t
374	33	Dharmapura	t
375	33	Dodda Thattamangala	t
376	33	Doddacheemanahalli	t
377	33	Doddagollahalli	t
378	33	Doddakurubarahalli	t
379	33	Doddamuddenahalli	t
380	33	Doddappanahalli	t
381	33	Doddasagarahalli	t
382	33	Doddasanne	t
383	33	Dyavarahalli	t
384	33	Gaddadanagenahalli	t
385	33	Gangamuthanahalli	t
386	33	Gangavara Chowdappana Halli	t
387	33	Gejjaguppe	t
388	33	Gobbarakunte	t
389	33	Gokare	t
390	33	Gollahalli	t
391	33	Gonur	t
392	33	Gopasandra	t
393	33	Gudla Muddenahalli	t
394	33	Guduvanahalli	t
395	33	Handrahalli	t
396	33	Haralur	t
397	33	Haralur Nagenahalli	t
398	33	Harohalli	t
399	33	Hegganahalli	t
400	33	Hiriganahalli	t
401	33	Holerahalli	t
402	33	Hosahalli	t
403	33	Hosahudya	t
404	33	Hyadala	t
405	33	Ibasapura	t
406	33	Ilathore	t
407	33	Indrasanahalli	t
408	33	Irigenahalli	t
409	33	Jalige	t
410	33	Jogahalli	t
411	33	Jonnahalli	t
412	33	Juttanahalli	t
413	33	Kaggalahalli	t
414	33	Kamenahalli	t
415	33	Kannamangala	t
416	33	Karahalli	t
417	33	Kempalingapura	t
418	33	Kempathimmanahalli	t
419	33	Kodagurki	t
420	33	Koira	t
421	33	Kommasandra	t
422	33	Konaginabele	t
423	33	Kondenahalli	t
424	33	Koramangala	t
425	33	Kottigethimmanahalli	t
426	33	Kundana	t
427	33	Kurubarakunte	t
428	33	Lakshmipura	t
429	33	Lalagondanahalli	t
430	33	Lingadeeragollahalli	t
431	33	Maligenahalli	t
432	33	Mallenahalli	t
433	33	Mallepura	t
434	33	Mandibele	t
435	33	Mangondanahalli	t
436	33	Maragondanahalli	t
437	33	Mattabaralu	t
438	33	Mayasandra	t
439	33	Meesaganahalli	t
440	33	Moodiganahalli	t
441	34	Adinarayana Hosahalli	t
442	34	Alappanahalli	t
443	34	Aloor	t
444	34	Amani Palanakere	t
445	34	Ankonahalli	t
446	34	Aralumallige	t
447	34	Arehalliguddadahalli	t
448	34	Bairapura	t
449	34	Baiyappanahalli	t
450	34	Bankenahalli	t
451	34	Bannamangala	t
452	34	Beera Sandra	t
453	34	Bhaktarahalli	t
454	34	Binuvanahalli	t
455	34	Bisuvinahalli	t
456	34	Bommanahalli	t
457	34	Bommasandra	t
458	34	Byradena Halli	t
459	34	Chikka Tumakuru	t
460	34	Chinkampanna Halli	t
461	34	Darga Jogahalli	t
462	34	Dargajogihalli	t
463	34	Dargapura	t
464	34	Duddnahalli	t
465	34	Ellupura	t
466	34	Galipoje	t
467	34	Ganga Chandra	t
468	34	Guddadahalli	t
469	34	Gummanahalli	t
470	34	Gundungere	t
471	34	Hanabe	t
472	34	Hasanaghatta	t
473	34	Honnaghata	t
474	34	Hoonagatta	t
475	34	Hosahudya	t
476	34	Jakkasandra	t
477	34	Jaligere	t
478	34	Jinkebachchahalli	t
479	34	Juttanahalli	t
480	34	Jyotipura	t
481	34	K G Govindapura	t
482	34	K G Kuntanahalli	t
483	34	Kadalappanahalli	t
484	34	Karenahalli	t
485	34	Kasavanahalli	t
486	34	Kasuvinahally	t
487	34	Keshtur	t
488	34	Kesturu	t
489	34	Khasbag	t
490	34	Kodigehalli	t
491	34	Kogina Halli	t
492	34	Kolipura	t
493	34	Koluru	t
494	34	Koluru Planteshan	t
495	34	Kurubarahalli	t
496	34	Laxmi Devipura	t
497	34	Madagondanahalli	t
498	34	Majara Hosahalli	t
499	34	Makali	t
500	34	Mandibyadarahalli	t
501	34	Mandibydrana Halli	t
502	34	Maralenahalli	t
503	34	Menasi	t
504	34	Moprahalli	t
505	34	Muttur	t
506	34	Mutturu	t
507	34	Nagadenahalli	t
508	34	Nagasandra	t
509	34	Nagdenahalli	t
510	34	Nagsandra	t
511	34	Neralaghatta	t
512	34	Obadenahalli	t
513	34	Obbadenahalli	t
514	34	Palana Jogahalli	t
515	34	Raghunathapura	t
516	34	Raghunathpura	t
517	34	Sasalu	t
518	34	Shivapura-Amanikere	t
519	34	Shreenivasapura	t
520	34	Siddenaykanahalli	t
521	34	Sonappanahalli	t
522	34	Sonnenahalli	t
523	34	Sunagatta	t
524	34	Suttahalli	t
525	34	Talagavara	t
526	34	Tammaganahalli	t
527	34	Tammashettahalli	t
528	34	Thalaga Vara	t
529	34	Tigalebagayti	t
530	34	Tippapura	t
531	34	Vaddarahalli	t
532	34	Varadanahalli	t
533	34	Vardanahalli	t
534	34	Veerabadhranapalya	t
535	34	Veerapura	t
536	34	Yellupura	t
537	35	Ajagondanahalli	t
538	35	Alagondanahalli	t
539	35	Amanidoddakere	t
540	35	Ambaleepura	t
541	35	Anugondanahalli	t
542	35	Appajipura	t
543	35	Appasandra	t
544	35	Aralemakanahalli Be	t
545	35	Arehalli	t
546	35	Baguru	t
547	35	Bairahalli	t
548	35	Banahalli Be	t
549	35	Banarahalli	t
550	35	Basabattanahalli	t
551	35	Belamangala	t
552	35	Bellikere	t
553	35	Bhaktagondanahalli Be	t
554	35	Bhaktarahalli	t
555	35	Bhodanahosahalli	t
556	35	Bisanahalli	t
557	35	Bommanabande	t
558	35	Byalahalli	t
559	35	Chandrapura Be	t
560	35	Channapura	t
561	35	Cheemandahalli	t
562	35	Chikkagattiganabbe	t
563	35	Chikkahulluru	t
564	35	Chikkanallala	t
565	35	Chikkanallurahalli	t
566	35	Chikkataggali	t
567	35	Chokkahalli	t
568	35	Cholappanahalli	t
569	35	D Hosahalli	t
570	35	Dabbagunte	t
571	35	Dasaratimmanahalli	t
572	35	Devalapura	t
573	35	Devanagondi	t
574	35	Devaragollahalli	t
575	35	Devashettihalli	t
576	35	Doddadasarahalli	t
577	35	Doddadenahalli	t
578	35	Doddadunnasandra	t
579	35	Doddahulluru	t
580	35	Doddanallala Be	t
581	35	Doddataggali	t
582	35	Ganagalu	t
583	35	Ganagaluru	t
584	35	Gonakanahalli	t
585	35	Govindapura	t
586	35	Guguttahalli	t
587	35	Gullakayipura	t
588	35	Gunduru	t
589	35	Halavasinakayipura	t
590	35	Handenahalli	t
591	35	Haraluru	t
592	35	Harohalli	t
593	35	Hemmandahalli	t
594	35	Honachanahalli	t
595	35	Hosakote	t
596	35	Hulluru Amanikerela	t
597	35	Hunasehalli	t
598	35	Injanahalli	t
599	35	Jadigenahalli	t
600	35	Jinnagara	t
601	35	Kacharakanahalli	t
602	35	Kalkunteagrahara	t
603	35	Kallahalli	t
604	35	Kamarasanahalli	t
605	35	Kaneekallu	t
606	35	Kannurahalli	t
607	35	Karibeeranahosahalli	t
608	35	Kattigenahalli	t
609	35	Khajihosahalli	t
610	35	Kodihalli	t
611	35	Koraluru	t
612	35	Koturu	t
613	35	Kumbalahalli	t
614	35	Kurubaragollahalli	t
615	35	Lakkondahalli	t
616	35	Lingadheeramallasandra	t
617	35	Makanahalli	t
618	35	Mallasandra	t
619	35	Mallimakanapura	t
620	35	Maragondanahalli	t
621	35	Marangere	t
622	35	Medahalli	t
623	35	Medimallasandra	t
624	35	Mugabala	t
625	35	Mugabala Hosahalli	t
626	35	Mutkuru	t
627	35	Mutsandra	t
628	35	Muttukadahalli	t
629	35	Naduvatti	t
630	35	Naganaykanakote	t
631	35	Narayanakere	t
632	35	Nidaghatta	t
633	35	Obalapura	t
634	35	Orohalli	t
635	35	Paramanahalli	t
636	35	Pettanahalli	t
637	35	Pillagumpe	t
638	35	Pujenagrahara	t
639	35	Sametanahalli	t
640	35	Sarkara Guttaganahalli	t
641	35	Shankaneepura	t
642	35	Shivanapura	t
643	35	Siddanapura	t
644	35	Somlapura	t
645	35	Sompura	t
646	35	Sonnadenahalli	t
647	35	Taggalihosahalli	t
648	35	Tarabahalli	t
649	35	Tattanuru	t
650	35	Timmandahalli	t
651	35	Timmapura	t
652	35	Tindlu	t
653	35	Tiratahalli	t
654	35	Tirumalashettihalli	t
655	35	Tiruvaranga	t
656	35	Ummalu	t
657	35	Upparahalli	t
658	35	Vabasandra	t
659	35	Vadigehalli	t
660	35	Vagata	t
661	35	Vijayapura Be	t
662	35	Yadagondanahalli	t
663	35	Yalachamanahalli	t
664	35	Yalachanaykanapura	t
665	36	Alagatta	t
666	36	B.N. Halli	t
667	36	Bommanahalli	t
668	36	Chikkenahalli	t
669	36	Haliyuru	t
670	36	Hirekandwadi	t
671	36	Kadaleguddu	t
672	36	Kagalagere	t
673	36	Konanuru	t
674	36	Malappanahatti	t
675	36	Manangi	t
676	36	Medikeripura	t
677	36	Megalahalli	t
678	36	Muttugaduru	t
679	36	Siddapura	t
680	36	Sirigere Siddapura	t
681	36	Thanigehalli	t
682	36	V.Palya	t
683	37	Annayappana Shed	t
684	37	Annur	t
685	37	Annuruhadi	t
686	37	Basavanagiri 'A'	t
687	37	Basavanagiri 'B'	t
688	37	Belaganahalli	t
689	37	Belthuru A Colony	t
690	37	Belthuru B Colony	t
691	37	Bharathipura	t
692	37	Bheemanahalli	t
693	37	Bheemanahalli Hadi	t
694	37	Bochikatte	t
695	37	Bomblapura	t
696	37	Bomblapura Hadi	t
697	37	Br Kattehadi	t
698	37	Budanur Hadi	t
699	37	Budanuru	t
700	37	Bukthalemala	t
701	37	Chaikkakalegowdana Pura Hadi	t
702	37	Chakahalli	t
703	37	Chakkodanahalli	t
704	37	Chikkakalegowdanapura	t
705	37	Chikkerehadi	t
706	37	Devalapura Colony	t
707	37	Devarajanagar	t
708	37	G.G. Colony	t
709	37	G.M. Halli Hadi	t
710	37	Ganeshpura	t
711	37	Ganished	t
712	37	Goolikatte	t
713	37	Gowndrushed	t
714	37	Hakkipikki Shed	t
715	37	Honnemaradahalla	t
716	37	Hosahallihadi	t
717	37	Hosatoravalli	t
718	37	Indiranagar	t
719	37	Itna Colony	t
720	37	K Yadathorehadi	t
721	37	K. Edatorepalya	t
722	37	K. Yadatore	t
723	37	K.G. Hundi	t
724	37	Kadahampapura	t
725	37	Kailasapura	t
726	37	Kunteri Hadi	t
727	37	Lakshmipura	t
728	37	Mahadeshwara Colony	t
729	37	Mahadevapura	t
730	37	Majjanakuppehadi	t
731	37	Mastigudihadi	t
732	37	Metikuppe Hadi	t
733	37	Muruganahalli	t
734	37	Muskere	t
735	37	Muskerehadi	t
736	37	N.N. Halli	t
737	37	Nanajayana Colony	t
738	37	Nn Halli Palya	t
739	37	Padukoti	t
740	37	Rajegowdanahundi	t
741	37	Rajegowdanahundihadi	t
742	37	Savvemala	t
743	37	Shanthipura	t
744	37	Shareef Colony	t
745	37	Sollapura C Hadi	t
746	37	Sonahalli	t
747	37	Sonahalli Hadi	t
748	37	Sunnakallu Manti	t
749	37	Tiger Block	t
750	37	Udbur Colony	t
751	37	Vaddaragudi	t
752	37	Vishwakarma Colony	t
753	37	Yalehundi	t
754	38	Ankanahalli	t
755	38	Annarayapura	t
756	38	Bannikuppe	t
757	38	Benkipura	t
758	38	Bilikere	t
759	38	Bolanahalli	t
760	38	Chikkabeedanahalli	t
761	38	Chikkadanahalli	t
762	38	Chilkunda	t
763	38	Cholanahalli	t
764	38	Dallalu Koppalu	t
765	38	Dasthikola	t
766	38	Devarahalli	t
767	38	Doddabeeachanahalli	t
768	38	Eradasi Koppalu	t
769	38	G Nagara	t
770	38	Gohalli	t
771	38	Hagaranahalli	t
772	38	Handanahalli	t
773	38	Hareenahalli	t
774	38	Hosuru	t
775	38	Jeenahalli	t
776	38	Kalegowdanakoppalu	t
777	38	Kebbekoppalu	t
778	38	Kolagatta (Gnagara)	t
779	38	Kuppe	t
780	38	Madugirikoppalu	t
781	38	Mallinathapura	t
782	38	Manuganahalli	t
783	38	Maradur	t
784	38	Maralayanakoppalu	t
785	38	Mudalakoppalu	t
786	38	Nanjappanakoppalu	t
787	38	Rampura / Haradanahalli	t
788	38	Rayanahalli	t
789	38	Sabbanahalli	t
790	38	Shankalli	t
791	38	Tenkalakoppalu	t
792	38	Tulasikopplu	t
793	38	Yalachawadi	t
794	39	Adaguru	t
795	39	Araker	t
796	39	Arjunahalli	t
797	39	Badakanakoppalu	t
798	39	Balur Koppalu	t
799	39	Baluru Koppalu	t
800	39	Bandahalli	t
801	39	Basavanapura	t
802	39	Basavapatna	t
803	39	Basavarajapura	t
804	39	Batiganahalli	t
805	39	Bherya	t
806	39	Bommenahalli	t
807	39	Chandagaalu	t
808	39	Chikkabherya	t
809	39	Chowkahalli	t
810	39	D.V. Gudi	t
811	39	Doddakoppalu	t
812	39	Doddekoppalu	t
813	39	Doranahalli	t
814	39	Galigekere	t
815	39	Halagegowdanakoppalu	t
816	39	Hampapura	t
817	39	Hanasoge	t
818	39	Hangarabayanahalli	t
819	39	Haramballi	t
820	39	Haramballi Koppalu	t
821	39	Hosaagrahara	t
822	39	Hosahalli	t
823	39	K Badavane	t
824	39	Kakanahalli	t
825	39	Kalyanapura	t
826	39	Kanchinakere	t
827	39	Katnalu	t
828	39	Kaval Hosuru	t
829	39	Koluru	t
830	39	Kumbarakoppalu	t
831	39	Lalanahalli	t
832	39	M.G.Halli	t
833	39	Manchanahally	t
834	39	Mulepetlu	t
835	39	Nadappanahalli	t
836	39	Sugganahalli	t
837	39	Vaddarahalli	t
838	39	Yaremanuganahalli	t
839	40	Anaghanahalli	t
840	40	B.G.Hundi	t
841	40	Badagalahundi	t
842	40	Ballahalli	t
843	40	Baradanapura	t
844	40	Beerihundi	t
845	40	Bogadi	t
846	40	Byathanahalli	t
847	40	D.H.Hundi	t
848	40	D.M.G.Halli	t
849	40	D.Salundi	t
850	40	Daripura	t
851	40	Dasanakoppalu	t
852	40	Devagalli	t
853	40	Dhanagalli	t
854	40	Doddahundi	t
855	40	Doora	t
856	40	Galagarahundi	t
857	40	Ganagarahundi	t
858	40	Gohalli	t
859	40	Goorur	t
860	40	Gopalapura	t
861	40	Halekesare	t
862	40	Hanchya	t
863	40	Jattihundi	t
864	40	Jayapura	t
865	40	K Salundi	t
866	40	K.Hemmanahalli	t
867	40	K.M.Hundi	t
868	40	K.N.Hundi	t
869	40	K.R.Mill	t
870	40	Kadakola	t
871	40	Kalisiddanahundi	t
872	40	Kallalavadi	t
873	40	Kamanakere	t
874	40	Kattehundi	t
875	40	Kellahalli	t
876	40	Kenchalagudu	t
877	40	Kerehundi	t
878	40	Kergalli	t
879	40	Koppaluru	t
880	40	Kottehundi	t
881	40	Kumarabeedu	t
882	40	Lingabudipaly	t
883	40	Madagahalli	t
884	40	Madahalli	t
885	40	Mahadevapura	t
886	40	Manikyapura	t
887	40	Maraiahnahundi	t
888	40	Maratikyathanahalli	t
889	40	Marballi	t
890	40	Marballikoppalu	t
891	40	Mavinahalli	t
892	40	Muganahundi	t
893	40	Mulluru	t
894	40	Muniswaminagara	t
895	40	Murudagalli	t
896	40	Nagarthnahalli	t
897	40	Nanjarajanahundi	t
898	40	Nuggehalli	t
899	40	Parasayanahundi	t
900	40	Ramanahundi	t
901	40	Rammanahalli	t
902	40	S.N.Halli	t
903	40	Sahukarahundi	t
904	40	Sathagalli	t
905	40	Shrirampura	t
906	40	T.Katuru	t
907	40	Tibbaiahnahundi	t
908	40	Yadehalli	t
909	41	Aallaiahnapura	t
910	41	Adharsha School	t
911	41	Akala	t
912	41	Ankusharayanapura	t
913	41	Avathalapura	t
914	41	B.R.Pura	t
915	41	Badanavalu	t
916	41	Basapura	t
917	41	Basavattige	t
918	41	Belagunda	t
919	41	Biligere	t
920	41	Bilugali	t
921	41	Byalaru	t
922	41	Chamlapuradahundi	t
923	41	Chiikahomma Mole	t
924	41	Chikkahimma	t
925	41	Chikkakavalande	t
926	41	Chunchanahalli	t
927	41	Dasanuru	t
928	41	Debur	t
929	41	Devanuru	t
930	41	Doddahomma	t
931	41	Gattavadi	t
932	41	Geekahalli Hundy	t
933	41	Geekhahalli	t
934	41	Hampapura	t
935	41	Handuvinahalli	t
936	41	Hanumanapura	t
937	41	Hariharapura	t
938	41	Haropura	t
939	41	Ibjala	t
940	41	Igli	t
941	41	Jeemarahalli	t
942	41	Kadaburu	t
943	41	Kakkarehatti	t
944	41	Kallahalli	t
945	41	Kalmalli	t
946	41	Kanakanagara	t
947	41	Kanenuru	t
948	41	Kappasoge	t
949	41	Karemole	t
950	41	Kathwadipura	t
951	41	Kathwadypura	t
952	41	Katuru	t
953	41	Konanapura	t
954	41	Konanuru	t
955	41	Korehundy	t
956	41	Kupparavalli	t
957	41	Marallipura	t
958	41	Motha	t
959	41	Nallithalapura	t
960	41	Nanjanahalli	t
961	41	Nerale	t
962	41	Other	t
963	41	P.Maralli	t
964	41	Palya	t
965	41	Sujathapuram	t
966	41	Thoravalli	t
967	41	Thoravallo Mole	t
968	41	Varahalli	t
969	42	Other	t
970	43	Anivalu	t
971	43	Attigodu	t
972	43	B G Koppalu	t
973	43	Balekatte	t
974	43	Barse	t
975	43	Barse Koppalu	t
976	43	Basavanagara	t
977	43	Besanakuppe	t
978	43	Bettadathunga	t
979	43	Bhuvanahalli	t
980	43	Btm Koppalu	t
981	43	Chikkahonuru	t
982	43	Chikkahossur	t
983	43	Chikkamalai	t
984	43	Chikkegowdanakoppalu	t
985	43	D G Koppalu	t
986	43	Depoora	t
987	43	Doddahonnur	t
988	43	Doddahossur	t
989	43	Gg Koppalu	t
990	43	Giruguru	t
991	43	Guddenahalli	t
992	43	Harinahally	t
993	43	Heremalali	t
994	43	Joganahalli	t
995	43	K Hosahalli	t
996	43	Kaggalikoppalu	t
997	43	Kallikoppalu	t
998	43	Kg Koppalu	t
999	43	Kogiluru	t
1000	43	Konasuru	t
1001	43	Koppa	t
1002	43	Kowlanahally	t
1003	43	Kudukuru	t
1004	43	Kudukuru Koppalu	t
1005	43	M Akoppalu	t
1006	43	M Hosahalli	t
1007	43	M M Koppalu	t
1008	43	M Mari Gowdanakoppalu	t
1009	43	M Mata	t
1010	43	M Matada Koppalu	t
1011	43	Maradiyuru	t
1012	43	Mardoor	t
1013	43	Mardoor Gate	t
1014	43	Maruru	t
1015	43	Meluru	t
1016	43	Naganhalli	t
1017	43	Naganhalli Palya	t
1018	43	Navilkodi	t
1019	43	P Basavanahalli	t
1020	43	Salukoppalu	t
1021	43	Sangashettihally	t
1022	43	T G Koppalu	t
1023	44	Abburu	t
1024	44	Ankanahalli	t
1025	44	Balluru	t
1026	44	Bandahalli	t
1027	44	Basavanapura	t
1028	44	Basavaraja Pura	t
1029	44	Battiganahalli	t
1030	44	Bettahalli	t
1031	44	Bylapura	t
1032	44	Chikkabheriya	t
1033	44	Chikkahanasoge	t
1034	44	Chikkanayakanahalli	t
1035	44	Dadadahalli	t
1036	44	Dammanahalli	t
1037	44	Doddakoppalu	t
1038	44	Elladahalli	t
1039	44	Gayanahally	t
1040	44	Gummanahally	t
1041	44	Hadya	t
1042	44	Hanasoge	t
1043	44	Haradanahally	t
1044	44	Harambahalli	t
1045	44	Harambahalli Koppalu	t
1046	44	Hebsuru	t
1047	44	Honnenahally	t
1048	44	Hosagrahara	t
1049	44	Kaggala	t
1050	44	Kalammanakoppalu	t
1051	44	Kallimuddanahalli	t
1052	44	Karathalu	t
1053	44	Karpurahalli	t
1054	44	Katnalu	t
1055	44	Kedaga	t
1056	44	Koluru	t
1057	44	Kulume Hosuru	t
1058	44	Kurubahalli	t
1059	44	Lakkikuppe	t
1060	44	Madapura	t
1061	44	Maluganahalli	t
1062	44	Mandiganahalli	t
1063	44	Mavanuru	t
1064	44	Mudalabeedu	t
1065	44	Munduru	t
1066	44	Nadappanahalli	t
1067	44	Pashupathi	t
1068	44	Rampura	t
1069	44	Saligrama A	t
1070	44	Saligrama B	t
1071	44	Salukoppalu	t
1072	44	Saraguru	t
1073	44	Senabina Kuppe	t
1074	44	Shambravalli	t
1075	44	Sheegavalu	t
1076	44	Somanahalli	t
1077	44	Subbegowdana Kopplau	t
1078	44	Thandre	t
1079	44	Thandre Ankanahalli	t
1080	44	Y.M.Halli	t
1081	45	Agatturu	t
1082	45	Anagatti	t
1083	45	Anagattihadi	t
1084	45	Ankanathapura	t
1085	45	Ankanathapurahadi	t
1086	45	Bidarahalli	t
1087	45	Bidarahallihundi	t
1088	45	Chamegowdanahundi	t
1089	45	Chennipura	t
1090	45	Dammunakatte	t
1091	45	Dammunakattehadi	t
1092	45	Gaddehalla	t
1093	45	Gonathakalundi	t
1094	45	Hegganuru	t
1095	45	Hoovinakola	t
1096	45	Hosakeresunda	t
1097	45	Hosamalahadi	t
1098	45	Hunaganahalli	t
1099	45	Hunasehalli	t
1100	45	Hunasekuppe	t
1101	45	Hunasekuppehadi	t
1102	45	Itna	t
1103	45	Jiyara	t
1104	45	Kalegowdanhundi	t
1105	45	Kandegala	t
1106	45	Karapurahadi	t
1107	45	Kerehadi	t
1108	45	Kottegala	t
1109	45	Kunnapatana	t
1110	45	Lakshmipurahadi	t
1111	45	Lanke	t
1112	45	Machanayakanahalli	t
1113	45	Machhare	t
1114	45	Maladahadi	t
1115	45	Manchahalli	t
1116	45	Manchegowdanahallihadi	t
1117	45	Manuganahalli	t
1118	45	Marnahadi	t
1119	45	Mosaralla	t
1120	45	Nadhinathapura	t
1121	45	Niluvagilu	t
1122	45	Pakshinota	t
1123	45	Penjalli	t
1124	45	Penjallihadi	t
1125	45	Pura	t
1126	45	Puradakatte	t
1127	45	Ramenahalli	t
1128	45	Ramenahallihadi	t
1129	45	Sagare A	t
1130	45	Sagare B	t
1131	45	Saraswathipuram	t
1132	45	Sargur A-Ward-4	t
1133	45	Sargur B Ward 5,6,7,8	t
1134	45	Sargur C Ward 2,3	t
1135	45	Sargur D Ward 2,4	t
1136	45	Sattigehundi	t
1137	45	Seeguruhadi	t
1138	45	Shanthipura	t
1139	45	Sheeranahundi	t
1140	45	Taraka	t
1141	45	Teranimunti	t
1142	45	Thelugumasalli	t
1143	45	Thumbasoge	t
1144	45	Udburuhadi	t
1145	45	Uyyamballi	t
1146	46	Ambedkar Mohala	t
1147	46	Ankanahalli	t
1148	46	Aravattege Koppalu	t
1149	46	Atthahalli	t
1150	46	B.Bettahalli	t
1151	46	Basavanahalli	t
1152	46	Bevinahalli	t
1153	46	Bhugathagahalli	t
1154	46	Bidanahalli	t
1155	46	Bismila Nagara	t
1156	46	Bolegowdanahundi	t
1157	46	Bommanahalli	t
1158	46	Budhahalli	t
1159	46	Chamalapura	t
1160	46	Chamanahali	t
1161	46	Chamanahali Koppalu	t
1162	46	Chidaravalli	t
1163	46	Chikkakalkuni	t
1164	46	Chimili	t
1165	46	D.M.Gudu	t
1166	46	Dasegowdanahalli	t
1167	46	Dayiramohala	t
1168	46	Doddangadibeedi	t
1169	46	Gadijogihundi	t
1170	46	Ganiganahalli	t
1171	46	Ganigeri	t
1172	46	Gudadakoppalu	t
1173	46	Hanumanalu	t
1174	46	Hegguru	t
1175	46	Horakeri	t
1176	46	Hosa Thirumakudalu	t
1177	46	Hosahalli	t
1178	46	Hosakoppalu	t
1179	46	K.G.Koppalu	t
1180	46	K.K.Halli	t
1181	46	K.K.S.F	t
1182	46	Kallipura	t
1183	46	Kanchanahalli	t
1184	46	Kannanayakanahalli	t
1185	46	Karihurallikoppalu	t
1186	46	Katte Koppalu	t
1187	46	Kempanapura	t
1188	46	Kodagahalli	t
1189	46	Kolatthuru	t
1190	46	Kutthanahalli	t
1191	46	M.K.Halli	t
1192	46	M.M.Road	t
1193	46	Madigahalli	t
1194	46	Makanahalli	t
1195	46	Maliyuru	t
1196	46	Maregowdanahalli	t
1197	46	Megala Koppalu	t
1198	46	Mudukapura	t
1199	46	Muslim Street	t
1200	46	Nagalagere	t
1201	46	Nanjapura	t
1202	46	Neregyathanahalli	t
1203	46	Nugahalli Koppalu	t
1204	46	Parivarada Beedi	t
1205	46	Ramegowdanapura	t
1206	46	S.Doddapura	t
1207	46	Santhemela	t
1208	46	Seehalli	t
1209	46	Senapathahalli	t
1210	46	Sigodipura	t
1211	46	Subhas Nagara	t
1212	46	Therina Beedi	t
1213	46	Thyagaraja Mohala	t
1214	46	Tolgate	t
1215	47	Adaguru	t
1216	47	Adahalli	t
1217	47	Adarsha School	t
1218	47	Adharsha School Debur	t
1219	47	Adibettahalli	t
1220	47	Ahalya	t
1221	47	Akki Kuppe	t
1222	47	Akkuru	t
1223	47	Akkurudoddhi	t
1224	47	Alaganchy	t
1225	47	Alaganchypura	t
1226	47	Alanahalli	t
1227	47	Algodu	t
1228	47	Anagalli	t
1229	47	Ankanahali Koppalu	t
1230	47	Ankanahalli	t
1231	47	Arakerekoppalu	t
1232	47	Arasinakere	t
1233	47	Arjunahalli	t
1234	47	Athiguppe	t
1235	47	Ayyanavarahundi	t
1236	47	Bachahalli	t
1237	47	Badagalahundy	t
1238	47	Badakanakoppalu	t
1239	47	Badhanvalu	t
1240	47	Ballur	t
1241	47	Balur Koppalu	t
1242	47	Bannallihundi	t
1243	47	Banni Kuppe	t
1244	47	Banooru	t
1245	47	Baradanapura	t
1246	47	Basalapura	t
1247	47	Basavanapura	t
1248	47	Basavarajapura	t
1249	47	Basavattige	t
1250	47	Beeranahally	t
1251	47	Belagundha	t
1252	47	Belale	t
1253	47	Belathur	t
1254	47	Benakanahalli	t
1255	47	Betta Halli	t
1256	47	Bhogayyanahundi	t
1257	47	Bhuthanahalli	t
1258	47	Bidagalu	t
1259	47	Bidaragudu	t
1260	47	Biligere	t
1261	47	Bilikere	t
1262	47	Booditittu	t
1263	47	Bopanahalli	t
1264	47	Byadarahally	t
1265	47	Byalaru	t
1266	47	Byalaruhundy	t
1267	47	Cg Hundi	t
1268	47	Chakkuru	t
1269	47	Chamahalli	t
1270	47	Chamalapura	t
1271	47	Chamanahallihundy	t
1272	47	Chandagaalu	t
1273	47	Chandahalli	t
1274	47	Chandravady	t
1275	47	Chattanahalli	t
1276	47	Chattanahalli Palya	t
1277	47	Cheeranhally	t
1278	47	Chennabasavayyanahundi	t
1279	47	Chennipura	t
1280	47	Chikakanya	t
1281	47	Chikka Bherya	t
1282	47	Chikkabeachanahalli	t
1283	47	Chikkagowdana Hundy	t
1284	47	Chikkakereyuru	t
1285	47	Chikkamagali	t
1286	47	Chikkanandi	t
1287	47	Chikkanayakanahalli	t
1288	47	Chikkankanahalli	t
1289	47	Chikkavalandhe	t
1290	47	Chikknandi	t
1291	47	Chinnadagudihundi	t
1292	47	Chinnamballi	t
1293	47	Chottanahalli	t
1294	47	Chowdalli	t
1295	47	Chowhalli	t
1296	47	Chowkahalli	t
1297	47	Chowth	t
1298	47	Chowtha	t
1299	47	Chunchanahalli	t
1300	47	Dadadahalli	t
1301	47	Dakalehundy	t
1302	47	Dandikere	t
1303	47	Daripura	t
1304	47	Dasanooru	t
1305	47	Debur	t
1306	47	Depegowdanapura	t
1307	47	Devalapura	t
1308	47	Deviramanahallihundy	t
1309	47	Deviramanhalli	t
1310	47	Dharma\\Yyanahundi	t
1311	47	Dhevarasanahalli	t
1312	47	Dhoddahomma	t
1313	47	Doddabeachanahalli	t
1314	47	Doddabylalu	t
1315	47	Doddakanya	t
1316	47	Doddakaturu	t
1317	47	Doddakavalande	t
1318	47	Doddakoppalu	t
1319	47	Doddamaragowdanahalli	t
1320	47	Doddanahundi	t
1321	47	Doddapura	t
1322	47	Doddegowdana Koppalu	t
1323	47	Doora	t
1324	47	Dornahalli	t
1325	47	Duggali	t
1326	47	Echgundla	t
1327	47	G Basavanahalli	t
1328	47	G.Basanahalli	t
1329	47	Gagenahalli	t
1330	47	Galigekere	t
1331	47	Gattavadipura	t
1332	47	Gatvady	t
1333	47	Geekahalli	t
1334	47	Geekahallihundy	t
1335	47	Gejjagalli	t
1336	47	Gejjaganahalli	t
1337	47	Goddanapura	t
1338	47	Goluru	t
1339	47	Gonahalli	t
1340	47	Gonthaganahundi	t
1341	47	Gopalapura	t
1342	47	Gowdrahundy	t
1343	47	Gujjappanahundi	t
1344	47	Gujjegowdanapura	t
1345	47	Gujjigowdanapura	t
1346	47	Gumchanahalli	t
1347	47	Gummanahalli	t
1348	47	H Kongalli	t
1349	47	H Megadahalli	t
1350	47	H.Kongali	t
1351	47	Habatoor Koppalu	t
1352	47	Habbanakuppe	t
1353	47	Hadaganahally	t
1354	47	Hadjana	t
1355	47	Hadya	t
1356	47	Hadya H	t
1357	47	Hagaranahalli	t
1358	47	Halambooru	t
1359	47	Halamburumanty	t
1360	47	Halasuru	t
1361	47	Halathur	t
1362	47	Halebidu	t
1363	47	Halebokalli	t
1364	47	Halepura	t
1365	47	Halladhakere	t
1366	47	Hallidhiddi	t
1367	47	Hallikerehundi	t
1368	47	Hampapura	t
1369	47	Hanchipura	t
1370	47	Handanahalli	t
1371	47	Handuvinahalli	t
1372	47	Haniyamballi	t
1373	47	Hanni Kuppe	t
1374	47	Hanumanapura	t
1375	47	Haradana Halli	t
1376	47	Harathale	t
1377	47	Harilapura	t
1378	47	Hariyur	t
1379	47	Harohalli	t
1380	47	Haropura	t
1381	47	Hathwalu	t
1382	47	Hd Madapura	t
1383	47	Hd Nerale	t
1384	47	Hebbalu	t
1385	47	Hebbaya	t
1386	47	Heggadahalli	t
1387	47	Hegganur	t
1388	47	Hejjige	t
1389	47	Hemmige	t
1390	47	Hirenandi	t
1391	47	Hiriyuru	t
1392	47	Holehundi	t
1393	47	Honnenahally	t
1394	47	Horalavadi Hosuru	t
1395	47	Horalvady	t
1396	47	Hosabokalli	t
1397	47	Hosahalli	t
1398	47	Hosaheggudilu	t
1399	47	Hosahemmigi	t
1400	47	Hosahundy	t
1401	47	Hosapura	t
1402	47	Hosayyanavarhundi	t
1403	47	Hosuru	t
1404	47	Hosurundi	t
1405	47	Hs Halepura	t
1406	47	Hulikura	t
1407	47	Hulimavu	t
1408	47	Hullahalli	t
1409	47	Hullenahalli	t
1410	47	Hunasekuppe	t
1411	47	Hunsnalli	t
1412	47	Hunsuru	t
1413	47	Huralikyathanahalli	t
1414	47	Huskuru	t
1415	47	Hyakanuru	t
1416	47	Hyrige	t
1417	47	Immavu	t
1418	47	Jadagana Koppalu	t
1419	47	Jakkahalli	t
1420	47	Jalahalli	t
1421	47	Javanikuppe	t
1422	47	Jinnahalli	t
1423	47	Kaadanahalli	t
1424	47	Kadaburu	t
1425	47	Kadajatti	t
1426	47	Kaggere	t
1427	47	Kagundi	t
1428	47	Kahalli	t
1429	47	Kalale	t
1430	47	Kale Gowdana Koppalu	t
1431	47	Kalegowdanahundi	t
1432	47	Kaliyuru	t
1433	47	Kalkere	t
1434	47	Kallahalli	t
1435	47	Kalmalli	t
1436	47	Kamahalli	t
1437	47	Kamanahalli	t
1438	47	Kamaravalli	t
1439	47	Kanakanagara	t
1440	47	Kanchinakere	t
1441	47	Kanchmalli	t
1442	47	Kandegala	t
1443	47	Kanenooru	t
1444	47	Kannahalli	t
1445	47	Kannahalli Mole	t
1446	47	Kapsoge	t
1447	47	Karalapura	t
1448	47	Karehundy	t
1449	47	Karepura	t
1450	47	Karigala	t
1451	47	Karuhatti	t
1452	47	Karya	t
1453	47	Kasvinahalli	t
1454	47	Katnalu	t
1455	47	Kattepura	t
1456	47	Kebbe Koppalu	t
1457	47	Kedaga	t
1458	47	Kellahalli	t
1459	47	Kembalu	t
1460	47	Kempegowdana Hundy	t
1461	47	Kendanakoppalu	t
1462	47	Kerehundy	t
1463	47	Ketalli	t
1464	47	Kiragasuru	t
1465	47	Kiragundha	t
1466	47	Kiralu	t
1467	47	Kiranalli	t
1468	47	Kochanahalli	t
1469	47	Kodinarasipura	t
1470	47	Kogilavadi	t
1471	47	Kohala	t
1472	47	Kolagala	t
1473	47	Kollegowdanahalli	t
1474	47	Konanuru	t
1475	47	Konthayyanahundi	t
1476	47	Koodanahalli	t
1477	47	Korehundy	t
1478	47	Kothegala	t
1479	47	Kotthegala	t
1480	47	Kr Puram	t
1481	47	Krishnapura	t
1482	47	Kudlapura	t
1483	47	Kudluru	t
1484	47	Kugaluru	t
1485	47	Kullakkanahundi	t
1486	47	Kulya	t
1487	47	Kumbarahalli	t
1488	47	Kumbrahallimata	t
1489	47	Kunigal	t
1490	47	Kuntanbelattur	t
1491	47	Kupparavali	t
1492	47	Kurahatty	t
1493	47	Kuruba Hally	t
1494	47	Kuruburu	t
1495	47	Lakki Kuppe	t
1496	47	Lakki Kuppe Koppalu	t
1497	47	Lakshmanapura	t
1498	47	Lakshmanpura	t
1499	47	Lalanahalli	t
1500	47	Lanke	t
1501	47	Laxmipura	t
1502	47	M Basavanapura	t
1503	47	M Kannenahalli	t
1504	47	M Kongaalli	t
1505	47	M. Mulluru	t
1506	47	M.Megadahalli	t
1507	47	Maadhanahalli	t
1508	47	Maavinahalli	t
1509	47	Machabayanahalli	t
1510	47	Madahalli	t
1511	47	Madapura	t
1512	47	Madarahalli	t
1513	47	Madhapura	t
1514	47	Magali	t
1515	47	Magudilu	t
1516	47	Mahadevi Colony	t
1517	47	Makanahalli	t
1518	47	Makanahundy	t
1519	47	Makanapura	t
1520	47	Malangi	t
1521	47	Malara Colony	t
1522	47	Malaradahundy	t
1523	47	Malkundy	t
1524	47	Mallahalli	t
1525	47	Malugana Halli	t
1526	47	Manchanahally	t
1527	47	Mandakalli	t
1528	47	Mangipacchanahundi	t
1529	47	Mannehundy	t
1530	47	Manti Koppalu	t
1531	47	Manuganahalli	t
1532	47	Maradipura	t
1533	47	Maraduru	t
1534	47	Maragowdanahalli	t
1535	47	Maraluru	t
1536	47	Maranapura	t
1537	47	Marase	t
1538	47	Marasettihalli	t
1539	47	Marballi	t
1540	47	Marballihundy	t
1541	47	Marigowdanahundy	t
1542	47	Marulaianna Koppalu	t
1543	47	Masge	t
1544	47	Matakere	t
1545	47	Mavinahalli	t
1546	47	Mellahalli	t
1547	47	Melur	t
1548	47	Melure	t
1549	47	Moodala Koppalu	t
1550	47	Moodalabeedu	t
1551	47	Motha	t
1552	47	Mudala Koppalu	t
1553	47	Muddanahalli	t
1554	47	Mudhahalli	t
1555	47	Mudiguppe	t
1556	47	Mulluru	t
1557	47	Munudur	t
1558	47	Muthur	t
1559	47	Mysore Rec	t
1560	47	Nagarathahalli	t
1561	47	Nanjangud Town	t
1562	47	Naviluru	t
1563	47	Nayakanahundi	t
1564	47	Nellithapura	t
1565	47	Neralakuppe	t
1566	47	Nerele	t
1567	47	Nerelehundi	t
1568	47	Nilasoge	t
1569	47	Niluvagilu	t
1570	47	P Maralli	t
1571	47	Pailwan Colony	t
1572	47	Palya	t
1573	47	Pillahalli	t
1574	47	Poonadahalli	t
1575	47	Pura	t
1576	47	Puttegowdana Hundi	t
1577	47	Ramenahalli	t
1578	47	Rampura	t
1579	47	Rayana Hally	t
1580	47	Rayanahundy	t
1581	47	Sajjehundy	t
1582	47	Saligrama	t
1583	47	Salu Koppalu	t
1584	47	Salundi	t
1585	47	Saraguru	t
1586	47	Sathyagala	t
1587	47	Savve	t
1588	47	Sd/Vtc Nanjangud	t
1589	47	Seegahalli	t
1590	47	Seehalli	t
1591	47	Shambudevanapura	t
1592	47	Shanu Bhoganahalli	t
1593	47	Shettalli	t
1594	47	Shiramahalli	t
1595	47	Shiramalli	t
1596	47	Shravanana Hally	t
1597	47	Siddhainahundy	t
1598	47	Sindhuvalli	t
1599	47	Sindhuvallipura	t
1600	47	Someshwarapura	t
1601	47	Sonahalli	t
1602	47	Sujjaluru	t
1603	47	Sundavalu	t
1604	47	Sunkalmanti	t
1605	47	Surahalli	t
1606	47	T Katuru	t
1607	47	T N Hunsuru	t
1608	47	Tandrekoppalu	t
1609	47	Tatanahalli	t
1610	47	Tenkalakoppalu	t
1611	47	Thandre	t
1612	47	Thardhale	t
1613	47	Thelaginakuppe	t
1614	47	Thimakapura	t
1615	47	Thippuru	t
1616	47	Thoravalli	t
1617	47	Thoremaavu	t
1618	47	Thukadimadaina Hundy	t
1619	47	Thumbasoge	t
1620	47	Thumnerale	t
1621	47	Uppinahalli	t
1622	47	Uyi Gowdanahalli	t
1623	47	Valagere	t
1624	47	Varahalli	t
1625	47	Varakodu	t
1626	47	Vatalu	t
1627	47	Veeradevanapura	t
1628	47	Veeregowdanahundi	t
1629	47	Venkategowdanakopplu	t
1630	47	Yaladahally	t
1631	47	Yalamatturu	t
1632	47	Yaraganahalli	t
1633	47	Yechagalli	t
1634	47	Yelachagere	t
1635	47	Yelamathur	t
1636	47	Yeragalli	t
1637	48	Arebannimangala	t
1638	48	Attur	t
1639	48	B.K Palya	t
1640	48	Bandikodegehalli	t
1641	48	Batrumarenahalli	t
1642	48	Baylanahalli	t
1643	48	Chowdeshwari Ward	t
1644	48	Golahalli	t
1645	48	Gopalapura	t
1646	48	Hunachuru	t
1647	48	Huvinayakanahalli	t
1648	48	Jakkur	t
1649	48	Kaderapanahalli	t
1650	48	Kondenahalli	t
1651	48	Mahadevakodigehalli	t
1652	48	Manchappanahalli	t
1653	48	Maralakunte	t
1654	48	Misganhalli	t
1655	48	Mylanahalli	t
1656	48	Singhalli	t
1657	48	Thanisandra	t
1658	48	Vidyaranyapura	t
1659	48	Yediyur	t
1660	48	Yelanka New Town	t
1661	49	Ambamolya	t
1662	49	Ankya	t
1663	49	Jamli	t
1664	49	Panchderiya	t
1665	49	Tillore	t
1666	50	Bangarda Chhota	t
1667	50	Bank	t
1668	50	Palda	t
1669	50	Piplya Kumar	t
1670	50	Rau	t
1671	51	Isambe	t
1672	52	Asare	t
1673	52	Dharni	t
1674	52	Dharni Wadi	t
1675	52	Wadi	t
1676	53	Ambiwali	t
1677	53	Asroti	t
1678	53	Asuedi	t
1679	53	Dandwadi	t
1680	53	Isambe	t
1681	53	Isambe Wadi	t
1682	53	Kasatarwadi	t
1683	53	Kokari	t
1684	53	Kopri	t
1685	53	Lohop	t
1686	53	Lohop Wadi	t
1687	53	Lop	t
1688	53	Madap	t
1689	53	Majgaonvadi	t
1690	53	Mazgaon	t
1691	53	Nadode	t
1692	53	Nadodevadi	t
1693	53	Ningdoli	t
1694	53	Pali Khurd	t
1695	53	Paud	t
1696	53	Paud Wadi	t
1697	53	Sarang	t
1698	53	Saud And Baudhawadi	t
1699	53	Talawali	t
1700	53	Tupgaon	t
1701	53	Vadgaon	t
1702	53	Varad	t
1703	53	Vasai	t
1704	53	Wadgaon Vadi	t
1705	53	Wanawali	t
1706	53	Waras	t
1707	54	Antop Hill	t
1708	54	Chembur Mahul Gav	t
1709	54	Chita Camp	t
1710	54	Dadar East	t
1711	54	Dadar West	t
1712	54	Dharavi 90 Ft Road	t
1713	54	Govandi	t
1714	54	Kalamboli	t
1715	54	Maharashtra Nagar	t
1716	54	Mahim	t
1717	54	Mahim Fort	t
1718	54	Matunga Labour Camp	t
1719	54	Pant Nagar	t
1720	54	Rajiv Gandhi Nagar	t
1721	54	Shanti Nagar	t
1722	54	Sidharth Nagar	t
1723	54	Sion East	t
1724	54	Sion Koliwada	t
1725	54	Sion West	t
1726	54	Worli Koliwada	t
1727	55	Bharkas	t
1728	55	Bhimnagar	t
1729	55	Bothali	t
1730	55	Butibori	t
1731	55	Deoli	t
1732	55	Deoli Grampanchaytâ Chowk	t
1733	55	Gandhi Khapari	t
1734	55	Gondwana	t
1735	55	Gondwana Shivaji Chowk	t
1736	55	Gondwana Ward No. 1	t
1737	55	Gondwana Ward No. 2	t
1738	55	Gosawi Nagar	t
1739	55	Kinhi	t
1740	55	Kirmiti	t
1741	55	Kolar	t
1742	55	Mandawa	t
1743	55	Mohgaon	t
1744	55	Parsodi	t
1745	55	Pipri	t
1746	55	Pohi	t
1747	55	Satgaon	t
1748	55	Shirur New	t
1749	55	Shirur Old	t
1750	55	Takalghat	t
1751	55	Tembhari	t
1752	55	Waranga	t
1753	55	Wateghat Shankar Nagar	t
1754	56	Ashram School	t
1755	56	Dombale Wasti	t
1756	56	Farm Society	t
1757	56	Gadadarwadi	t
1758	56	Ghumat Wasti	t
1759	56	Jagtapvasti & Patharvasti	t
1760	56	Khandobachiwadi	t
1761	56	Kuranvasti	t
1762	56	Laxminagar	t
1763	56	Mirewadi	t
1764	56	Navlevasti	t
1765	56	Nevasevasti	t
1766	56	Nimbut	t
1767	56	Other	t
1768	56	Padegaon	t
1769	56	Padegaon Farm Society	t
1770	56	Peer Society	t
1771	56	Pharandenagar	t
1772	56	Pharndenagar	t
1773	56	Raikar Wasti	t
1774	56	Tarathi	t
1775	56	Tarti Mala	t
1776	56	Vavare Wasti	t
1777	57	Bharate Wadi	t
1778	57	Bhote Wadi	t
1779	57	Chandus	t
1780	57	Chimte Wadi	t
1781	57	Deshmukh	t
1782	57	Dhamane	t
1783	57	Dhamangaon	t
1784	57	Dhuvoli Wanjale	t
1785	57	Ganeshwadi	t
1786	57	Gargotewadi	t
1787	57	Kadlak Wadi	t
1788	57	Karvande Wadi	t
1789	57	Kiwale	t
1790	57	Kohinde	t
1791	57	Kudekar Vasti	t
1792	57	Nayfad	t
1793	57	Saburdi	t
1794	57	Sakurdi	t
1795	57	Shendurli	t
1796	57	Shirgaon Mandoshi	t
1797	57	Talavade	t
1798	57	Tardewadi	t
1799	57	Vadachiwadi	t
1800	57	Vajvane	t
1801	57	Vashire	t
1802	58	Other	t
1803	59	Nira	t
1804	59	Other	t
1805	59	Ward No. 06/ Nira	t
1806	60	Anjani Nagar	t
1807	60	Arebannimangala	t
1808	60	Attur	t
1809	60	Bhilarewadi	t
1810	60	Byatarayanapura	t
1811	60	Chowdeshwari	t
1812	60	Dattanagar	t
1813	60	Doddabommasandra	t
1814	60	Gokulnagar	t
1815	60	Hanumannagar	t
1816	60	Horamavu	t
1817	60	Jakkur	t
1818	60	Jambhulwadi	t
1819	60	Kampegowda Ward	t
1820	60	Khopadenagar	t
1821	60	Kondhpur Patha	t
1822	60	Mahadevakodigehalli	t
1823	60	Mylanahalli	t
1824	60	Pune Panasonic	t
1825	60	Rm Nagar	t
1826	60	Santosh Nagar	t
1827	60	Shantinagar	t
1828	60	Singnahalli	t
1829	60	Thanisandra	t
1830	60	Velu Gaon	t
1831	60	Vetal Bhuva Chouk	t
1832	60	Vidyaranyapura	t
1833	60	Yelahanka Satellite Town	t
1834	61	Panvel Ward 1	t
1835	62	Bhekrai Nagar	t
1836	62	Handewadi	t
1837	62	Mahammad Wadi	t
1838	62	Mancharwadi Phata	t
1839	62	Nande	t
1840	62	Phursungi	t
1841	62	Sarode Nagar	t
1842	62	Sasane Nagar	t
1843	62	Sayyad Nagar	t
1844	62	Undri	t
1845	62	Uruli Devachi	t
1846	62	Vadaki	t
1847	62	Vasant Nagar	t
1848	63	Hadapsar	t
1849	64	Dhokasangvi	t
1850	64	Malthan	t
1851	64	Nimgao Bhogi	t
1852	64	Paritwadi	t
1853	64	Pimpri Dumala	t
1854	64	Ranjangaon	t
1855	64	Ranjangaon Village	t
1856	64	Skh Smc	t
1857	64	Sone Sangavi	t
1858	64	Sonesangvi	t
1859	64	Takalkarwadi	t
1860	64	Warude	t
1861	65	Ajangaon	t
1862	65	Bibi	t
1863	65	Chowki	t
1864	65	Dhokurda	t
1865	65	Ghoreghatak	t
1866	65	Kanholibara Cluster	t
1867	65	Saoli	t
1868	66	Akoli	t
1869	66	Amgaon	t
1870	66	Arvi Lahan	t
1871	66	Bhansuli	t
1872	66	Bhimnagar	t
1873	66	Bramhni	t
1874	66	Chimnazari	t
1875	66	Degma	t
1876	66	Dhanoli	t
1877	66	Gandhi Khapri	t
1878	66	Ghodadeo	t
1879	66	Gondapur	t
1880	66	Heti	t
1881	66	Jaipur	t
1882	66	Jamni	t
1883	66	Juwadi	t
1884	66	Kanhapur	t
1885	66	Khadka	t
1886	66	Khadki	t
1887	66	Khairi	t
1888	66	Kinhi	t
1889	66	Kukdi	t
1890	66	Lakhmapur	t
1891	66	Mahsala	t
1892	66	Mathni	t
1893	66	Matkazari	t
1894	66	Menkhat	t
1895	66	Morchapur	t
1896	66	Nanbardi	t
1897	66	Pardhi Beda1	t
1898	66	Pardhi Beda2	t
1899	66	Pipaldhara	t
1900	66	Ramna	t
1901	66	Sawali	t
1902	66	Sukli Bai	t
1903	66	Sukli Station	t
1904	66	Tamaswada	t
1905	66	Wadad	t
1906	66	Wadgaon Kala	t
1907	66	Wadgaon Khurd	t
1908	67	Babuniktimal	t
1909	67	Govindpuri	t
1910	67	Kestopur	t
1911	67	Khanpur	t
1912	67	Rampur	t
1913	68	Charmal	t
1914	68	Dhankauda	t
1915	68	Ghungapali	t
1916	68	Hatibari	t
1917	68	Jamankira	t
1918	68	Jujumura	t
1919	68	Kisinda	t
1920	68	Kukudapali	t
1921	68	Laida	t
1922	68	Maneswar	t
1923	68	Rengali	t
1924	69	Adho Majra	t
1925	69	Ahema	t
1926	69	Akout	t
1927	69	Amipur	t
1928	69	Anandpur	t
1929	69	Asarpur	t
1930	69	Babaheri	t
1931	69	Bahal	t
1932	69	Baknaur	t
1933	69	Balana	t
1934	69	Bara	t
1935	69	Barouli	t
1936	69	Batrohan	t
1937	69	Bedsan	t
1938	69	Bego Majra	t
1939	69	Bhanpur Nakatpur	t
1940	69	Bhanri	t
1941	69	Bhunni	t
1942	69	Bhurangpur	t
1943	69	Bosarkalan	t
1944	69	Budhapur	t
1945	69	Chapad	t
1946	69	Chaura	t
1947	69	Dakala	t
1948	69	Dhudhad	t
1949	69	Fatehpur	t
1950	69	Jahlan	t
1951	69	Jhandi	t
1952	69	Jogipur	t
1953	69	Kartarpur	t
1954	69	Kheri Gujran	t
1955	69	Lalina	t
1956	69	Main	t
1957	69	Naina Kaut	t
1958	69	Noorkhedia	t
1959	69	Rajgarh	t
1960	69	Sher Majra	t
1961	69	Sular	t
1962	69	Wazirpur	t
1963	70	Adarsh Colony	t
1964	70	Atawa	t
1965	70	Balongi	t
1966	70	Bar Majra	t
1967	70	Bhanri	t
1968	70	Jfl Phase 1 Industrial Area	t
1969	70	Khokha Market/Mohali Village	t
1970	70	Palsora	t
1971	70	Shahi Majra	t
1972	71	Balongi	t
1973	71	Barmajra And Colonies	t
1974	71	Chajju Majra	t
1975	71	Daun	t
1976	71	Desu Majra	t
1977	71	Dhanas	t
1978	71	Jujhar Nagar	t
1979	71	Khokha Market	t
1980	71	Madanpur	t
1981	71	Maloya	t
1982	71	Naya Gaon	t
1983	71	Palsora	t
1984	71	Peeda	t
1985	71	Raipur	t
1986	71	Ramgarh	t
1987	71	Shahi Majra	t
1988	71	Shahpur	t
1989	71	Taga	t
1990	72	Bagga Kheda	t
1991	72	Banakiya Kala	t
1992	72	Banakiya Khurd	t
1993	72	Bhawarkiya	t
1994	72	Chapari	t
1995	72	Chatarpura	t
1996	72	Chittorgarh	t
1997	72	Dolji Ka Kheda	t
1998	72	Gopal Pura	t
1999	72	Jhopadiya	t
2000	72	Jitiya	t
2001	72	Kakariya	t
2002	72	Kalyanpura	t
2003	72	Kathodiya	t
2004	72	Kodiya Khedi	t
2005	72	Langach	t
2006	72	Laxmipura	t
2007	72	Mata Ji Ka Kheda	t
2008	72	Moda Kheda	t
2009	72	Narela	t
2010	72	Nariya	t
2011	72	Pandoli Station	t
2012	72	Plnt	t
2013	72	Ramakheda	t
2014	72	Ren Ka Kheda	t
2015	72	Saropa	t
2016	72	Singhpur	t
2017	72	Sirodi	t
2018	72	Sisodio Ka Sawata	t
2019	72	Surajpura	t
2020	72	Test Dighwara	t
2021	73	Alathur	t
2022	73	Athigamanallur	t
2023	73	Echoor	t
2024	73	Ecr	t
2025	73	Edayarkuppam	t
2026	73	Illalur	t
2027	73	Kuzihipathandalam	t
2028	73	Madayathur	t
2029	73	Manamathy	t
2030	73	Paiyanur	t
2031	73	Pandithamedu	t
2032	73	Porunthavakkam	t
2033	73	Puliyure	t
2034	73	Sembakkam	t
2035	73	Sreedhavahur	t
2036	73	Thandalam	t
2037	73	Thiruporur	t
2038	74	Besant Nagar	t
2039	74	Guindy	t
2040	74	Kottivakkam	t
2041	74	Neelankarai	t
2042	74	Palavakkam	t
2043	74	Perungudi	t
2044	74	Saidapet	t
2045	74	Taramani	t
2046	74	Thiruvanmiyur	t
2047	74	Velachery	t
2048	75	Anthammagudem	t
2049	75	Bheemanpalle	t
2050	75	Chinnakondur	t
2051	75	Dharmojigudem	t
2052	75	Dothigudem	t
2053	75	Dothigudem (Unit Village)	t
2054	75	Guvambhavi	t
2055	75	Jiblakpalle	t
2056	75	Kanumukula	t
2057	75	Lakkaram	t
2058	75	Masid Gudem	t
2059	75	Other	t
2060	75	Pedda Kondur	t
2061	75	Pochampally	t
2062	75	Pochampally (Municipal Council)	t
2063	75	Sirrila	t
2064	75	Yellagiri	t
2065	75	Yellambhavi	t
2066	76	Allapur	t
2067	76	Gayathrinagar	t
2068	76	Hanuman Nagar	t
2069	76	Motinagar	t
2070	76	Parvath Nagar	t
2071	76	Pragathi Nagar	t
2072	76	Radha Krishna Nagar	t
2073	76	Raj Nagar	t
2074	76	Rama Krishna Nagar	t
2075	76	Ramarao Nagar	t
2076	76	Saradhinagar	t
2077	77	Bharath Nagar	t
2078	77	Housing Board Kailashgiri Area	t
2079	77	Iala Office	t
2080	77	Mallapur Area Ashok Nagar Basti	t
2081	77	Mallapur Area Ntr Nagar	t
2082	77	Nacharam Area Baba	t
2083	77	Rtc Colony	t
2084	77	Shirdi Sai Baba Temple Premises	t
2085	78	Isambe	t
2086	79	Ambedkar Nagar	t
2087	79	Bjr Nagar	t
2088	79	Dammiguda	t
2089	79	Gandhi Nagar	t
2090	79	Hb Colony	t
2091	79	Malikarjuna Nagar	t
2092	79	Moula Ali Floor Hotel	t
2093	79	Moula Ali Gandhi Nagar	t
2094	79	Nadamuri Nagar	t
2095	79	Old Kapra	t
2096	79	Sai Nagar	t
2097	79	Sai Ram Colony	t
2098	79	Uppuguda Govdam	t
2099	79	Uppuguda Village	t
2100	79	Vijay School Kapra	t
2101	80	Moulali	t
2102	80	Nscb Nagar	t
2103	81	Ameerpet	t
2104	81	Banjara Hills	t
2105	81	Film Nagar	t
2106	81	Gachibowli	t
2107	81	Hitech City	t
2108	81	Kondapur	t
2109	81	Madhapur	t
2110	81	Manikonda	t
2111	81	Mehdipatnam	t
2112	81	Panjagutta	t
2113	81	Tolichowki	t
2114	82	Ankireddipalli	t
2115	82	Anthammagudem	t
2116	82	Bommalaramaram	t
2117	82	Cheekati Mamidi	t
2118	82	Dharmojigudem	t
2119	82	Dothigudem	t
2120	82	Guvambhavi	t
2121	82	Hazipur	t
2122	82	Jalalpur	t
2123	82	Kanumukula	t
2124	82	Malyala	t
2125	82	Mandakini Palle	t
2126	82	Naginenipalle	t
2127	82	Peda Parvathapuram	t
2128	82	Pedda Kondur	t
2129	82	Pyararam	t
2130	82	Ramalingampally	t
2131	82	Rangapuram	t
2132	82	Sirilla	t
2133	82	Solipet	t
2134	82	Thumkunta	t
2135	82	Yavavpuram	t
2136	82	Yellagiri	t
2137	83	Aehrola Tejwan	t
2138	83	Aehrolla	t
2139	83	Afzalpur Lut	t
2140	83	Agapur Kalan	t
2141	83	Agapur Khurd	t
2142	83	Agrola Kalan	t
2143	83	Alampur	t
2144	83	Allipur	t
2145	83	Asp Ltd	t
2146	83	Atalee	t
2147	83	Atarpura	t
2148	83	Azadpur Mafi	t
2149	83	Baansle	t
2150	83	Bagadpur Mafi	t
2151	83	Bahadurpur Ghulam Mohiuddinpur	t
2152	83	Bahaleelpur	t
2153	83	Baldana Asgarali Khan	t
2154	83	Baldana Heerasingh	t
2155	83	Barampur	t
2156	83	Barsabad	t
2157	83	Basaili	t
2158	83	Basantpur Ahatmali	t
2159	83	Basantpur Must.	t
2160	83	Baseli	t
2161	83	Basera	t
2162	83	Bastaura	t
2163	83	Bastaura Mafi	t
2164	83	Basti	t
2165	83	Batupura	t
2166	83	Bawanpura Mafi	t
2167	83	Bhagwanpur Bhur	t
2168	83	Bhagwanpur Khadar	t
2169	83	Bhandi	t
2170	83	Bhanpur	t
2171	83	Bharapur Mafi	t
2172	83	Bhekanpur Somali	t
2173	83	Bhikanpur	t
2174	83	Bijora	t
2175	83	Bilra Atmali	t
2176	83	Chak Dhanauri	t
2177	83	Chak Kudaina	t
2178	83	Chak Shawajpur	t
2179	83	Chaki Kheda	t
2180	83	Chandanpur Kheri	t
2181	83	Chaubara	t
2182	83	Chauhadpur Mafi	t
2183	83	Chauparwa	t
2184	83	Chhoya	t
2185	83	Chobara	t
2186	83	Choharpur	t
2187	83	Dariyapur	t
2188	83	Dhakka	t
2189	83	Dhoriya	t
2190	83	Fatehpur	t
2191	83	Fattepur	t
2192	83	Firozpur	t
2193	83	Foundapure	t
2194	83	Gajraula	t
2195	83	Hayatpur	t
2196	83	Hussanpur Gujjar	t
2197	83	Insilco	t
2198	83	Inslnoko	t
2199	83	Jalapur	t
2200	83	Jubilant	t
2201	83	Kakadar	t
2202	83	Kamrala Bahadurpur	t
2203	83	Kankather	t
2204	83	Kankathera	t
2205	83	Karanpur Mafi	t
2206	83	Katai	t
2207	83	Khanpur	t
2208	83	Khumabali	t
2209	83	Khungavli	t
2210	83	Khyalipur	t
2211	83	Kudaina	t
2212	83	Kudaini	t
2213	83	Kumraila	t
2214	83	Leesdhi	t
2215	83	Lisri	t
2216	83	Maheshra	t
2217	83	Mahmedpur	t
2218	83	Manota	t
2219	83	Matena	t
2220	83	Meerpur	t
2221	83	Mohammadabad	t
2222	83	Mohammadpur	t
2223	83	Moharka	t
2224	83	Moharka Patti	t
2225	83	Mohmadabad	t
2226	83	Moradabad	t
2227	83	Nagalmafi	t
2228	83	Naglishekh	t
2229	83	Naipura	t
2230	83	Navada	t
2231	83	Navda	t
2232	83	Other	t
2233	83	Other Villages	t
2234	83	Paal Salempur	t
2235	83	Pal	t
2236	83	Papsara	t
2237	83	Rajbapur	t
2238	83	Rakheda	t
2239	83	Rakhera	t
2240	83	Raunaq	t
2241	83	Rehdra	t
2242	83	Rehmapur Mafi	t
2243	83	Sabjwpur Dor	t
2244	83	Sadallapur	t
2245	83	Sadullapur	t
2246	83	Saidnagli	t
2247	83	Salempur	t
2248	83	Shabajpur	t
2249	83	Shahpur	t
2250	83	Shawajpurdor	t
2251	83	Sihali Gosai	t
2252	83	Sihali Jagir	t
2253	83	Sitajagatdevpur	t
2254	83	Sultanpur Ther	t
2255	83	Sultanther	t
2256	83	Takhatpur	t
2257	83	Tanda	t
2258	83	Tanta	t
2259	83	Teva	t
2260	83	Tigaria Bhood	t
2261	83	Tigariya	t
2262	83	Tigiriya Bhood	t
2263	83	Tigiriya Khaddar	t
2264	83	Tigri	t
2265	83	Tt Ltd	t
2266	83	Us Foods	t
2267	83	Yakbagdi	t
2268	84	Burablee	t
2269	84	Patai Khadar	t
2270	84	Rukhalu	t
2271	84	Sohrkaa	t
2272	84	Sutablee	t
2273	85	Other	t
2274	86	Aadamapur	t
2275	86	Aadamapur Maajara	t
2276	86	Aasakapur	t
2277	86	Adampur Bada Majra	t
2278	86	Aogarpur	t
2279	86	Bagadpurchodya	t
2280	86	Bagarpur	t
2281	86	Bahaadurapur Mishr	t
2282	86	Bahadurpur Mishra	t
2283	86	Bartaura	t
2284	86	Bartora	t
2285	86	Baska Kalan	t
2286	86	Baska Khurd	t
2287	86	Beejhalapur	t
2288	86	Bhabli	t
2289	86	Bhagpura	t
2290	86	Bhamoripatti	t
2291	86	Bhanda	t
2292	86	Bhandi	t
2293	86	Bhansari	t
2294	86	Bheema Thikri	t
2295	86	Bhogpura	t
2296	86	Bhoobara	t
2297	86	Bhuvra	t
2298	86	Bijnora	t
2299	86	Birampur	t
2300	86	Bukhaareepur	t
2301	86	Bukharipur	t
2302	86	Cachunagal	t
2303	86	Calamundi	t
2304	86	Chachora	t
2305	86	Chahchara	t
2306	86	Chakoonee	t
2307	86	Chaktari	t
2308	86	Chakuni	t
2309	86	Chamarapateee	t
2310	86	Chamarpatayi	t
2311	86	Chandankota	t
2312	86	Chandanpur	t
2313	86	Chapana	t
2314	86	Cheela	t
2315	86	Dadyal	t
2316	86	Dahari Khadan	t
2317	86	Damagada	t
2318	86	Dariyal	t
2319	86	Dariyapur Tugan	t
2320	86	Darrara	t
2321	86	Daulatpur Kalan	t
2322	86	Daurara	t
2323	86	Dayawali	t
2324	86	Dehri Gurjar	t
2325	86	Dehri Khadar	t
2326	86	Dhabaarasee	t
2327	86	Dhakiya Khadar	t
2328	86	Dhakola	t
2329	86	Doolhepuraheer	t
2330	86	Dorara	t
2331	86	Dulhepur Ahir	t
2332	86	Enta	t
2333	86	Fatehpur	t
2334	86	Fatehpur Adhek	t
2335	86	Firojpur	t
2336	86	Fulpur	t
2337	86	Gangat Kola	t
2338	86	Gangeshwari	t
2339	86	Gangwar	t
2340	86	Garavpur	t
2341	86	Gulampur	t
2342	86	Gurantha	t
2343	86	Haidalapur	t
2344	86	Hajipur	t
2345	86	Hakampur	t
2346	86	Hayaatapur	t
2347	86	Hayatpur	t
2348	86	Heesakheda	t
2349	86	Hernota	t
2350	86	Hirnota	t
2351	86	Imratpur	t
2352	86	Isaratapur	t
2353	86	Jaliopur	t
2354	86	Jebda Mustkam	t
2355	86	Jeevpur	t
2356	86	Jivpur	t
2357	86	Kai Dwitiya	t
2358	86	Kailmundi	t
2359	86	Karanpur	t
2360	86	Karanpur Khadar	t
2361	86	Kasaipura	t
2362	86	Kasampur	t
2363	86	Khadagaraasee	t
2364	86	Khadagrani	t
2365	86	Khajepur	t
2366	86	Khaliya Khalsa	t
2367	86	Khaliya Khalsha	t
2368	86	Khaliya Patti	t
2369	86	Khanaura	t
2370	86	Khandasoli	t
2371	86	Khanora	t
2372	86	Khanupura	t
2373	86	Kharkhaunda	t
2374	86	Kharpadi	t
2375	86	Kheliya Khalsa	t
2376	86	Khurtia	t
2377	86	Khurtiya	t
2378	86	Kokapur	t
2379	86	Ladybug	t
2380	86	Lakhanapur	t
2381	86	Lakhanpur	t
2382	86	Lalapur	t
2383	86	Lathman Ki Maddya	t
2384	86	Lathmar Ki Mandiya	t
2385	86	Latthmar Ki Madahaiya	t
2386	86	Lesda	t
2387	86	Lisra	t
2388	86	Machariya	t
2389	86	Madaripur	t
2390	86	Maharpur	t
2391	86	Makarandpur	t
2392	86	Makrandpur	t
2393	86	Malakpur	t
2394	86	Mangrola	t
2395	86	Marora	t
2396	86	Masakpur	t
2397	86	Matipura	t
2398	86	Meerpur Dabka	t
2399	86	Meharpur	t
2400	86	Mirzapur	t
2401	86	Mirzapurdungar	t
2402	86	Mubarijpur	t
2403	86	Mujahidpur	t
2404	86	Mungta	t
2405	86	Nagla Khadar	t
2406	86	Nanai	t
2407	86	Narabpura	t
2408	86	Navavpura	t
2409	86	Niryawalikhadar	t
2410	86	Ogarpur	t
2411	86	Ogpura	t
2412	86	Other	t
2413	86	Pashupura	t
2414	86	Pathra	t
2415	86	Patikhadar	t
2416	86	Paurara	t
2417	86	Pharnota	t
2418	86	Phatapur	t
2419	86	Phatehapuraghek	t
2420	86	Phoolpur	t
2421	86	Piploti Kala	t
2422	86	Piploti Khurd	t
2423	86	Porara	t
2424	86	Porara Jatavoowali	t
2425	86	Porara Sainiwali	t
2426	86	Preetamapur	t
2427	86	Pritampur	t
2428	86	Pursal	t
2429	86	Putsaal	t
2430	86	Rahra	t
2431	86	Rehra	t
2432	86	Rehrai	t
2433	86	Roharu	t
2434	86	Roopaanaagal	t
2435	86	Rukhalu	t
2436	86	Rupanagal	t
2437	86	Rustampur	t
2438	86	Rustampur Khadar	t
2439	86	Saandhalapur	t
2440	86	Sakatpur	t
2441	86	Salara	t
2442	86	Santhalpur	t
2443	86	Sehdramilk	t
2444	86	Shahadarmilk	t
2445	86	Shahbazpurdhola	t
2446	86	Shakarpur	t
2447	86	Shergarh	t
2448	86	Shitala Sarai	t
2449	86	Simthala	t
2450	86	Sirsakalan	t
2451	86	Sirsakalan 1	t
2452	86	Sirsanal	t
2453	86	Sirsha Kalan	t
2454	86	Sisona	t
2455	86	Sodhan Millak	t
2456	86	Sohat	t
2457	86	Soobara	t
2458	86	Subra	t
2459	86	Sultaanapurabheema	t
2460	86	Sultanpur Bheema	t
2461	86	Sutabli	t
2462	86	Sutaoli	t
2463	86	Sutarikhurd	t
2464	86	Tajpur Dungar	t
2465	86	Talaabadha	t
2466	86	Talabada	t
2467	86	Taranpur	t
2468	86	Taroli	t
2469	86	Tatarpur Sandal	t
2470	86	Tigariya Nadirshah	t
2471	86	Tigrianadirshah	t
2472	86	Ukabali	t
2473	86	Vbijhalpur	t
2474	87	Agora	t
2475	87	Ahmadgarh	t
2476	87	Ajnara	t
2477	87	Asroli	t
2478	87	Aterna	t
2479	87	Aurangabad	t
2480	87	Baad	t
2481	87	Bad	t
2482	87	Badagaon	t
2483	87	Badshahpur Paehgai	t
2484	87	Baghrai	t
2485	87	Bahanpur	t
2486	87	Baina	t
2487	87	Balrampur	t
2488	87	Banail	t
2489	87	Barasu	t
2490	87	Baroli(Shikarpur)	t
2491	87	Barula(Baruli)	t
2492	87	Basaich	t
2493	87	Bhadwa	t
2494	87	Bhagrai	t
2495	87	Bhaipur(Seekra)	t
2496	87	Bheekampur	t
2497	87	Bhojgarhi	t
2498	87	Bijili Pur	t
2499	87	Bulandshahr New	t
2500	87	Chapana	t
2501	87	Chauganpur	t
2502	87	Chingrawali	t
2503	87	Chitson	t
2504	87	Choroli	t
2505	87	Daheli	t
2506	87	Dalelgarhi	t
2507	87	Dalpatpur	t
2508	87	Dashari	t
2509	87	Daupur	t
2510	87	Deeghi	t
2511	87	Devrala	t
2512	87	Fatehabad	t
2513	87	Fatehgarh	t
2514	87	Gangagarh	t
2515	87	Gangaoli	t
2516	87	Gawaroli	t
2517	87	Ghatal	t
2518	87	Ghusrana Hari Singh	t
2519	87	Ghusranagail	t
2520	87	Gwaroli	t
2521	87	Hameer Pur	t
2522	87	Hameerpur	t
2523	87	Hesara	t
2524	87	Hinsoti	t
2525	87	Ibrahimpur (Got)	t
2526	87	Jagdishpur	t
2527	87	Jalalpur(Md.Ginori)	t
2528	87	Java	t
2529	87	Jeerajpur	t
2530	87	Jinamai	t
2531	87	Kailawan	t
2532	87	Kala-Khuri	t
2533	87	Kalena	t
2534	87	Kandher	t
2535	87	Karira	t
2536	87	Kariyawali	t
2537	87	Kasoomi	t
2538	87	Khailia-Kalyanpur	t
2539	87	Khakhoonda	t
2540	87	Khandar	t
2541	87	Kheda	t
2542	87	Khurdkheda	t
2543	87	Khutana	t
2544	87	Kiyoli Khurd	t
2545	87	Lalner	t
2546	87	Lalpur	t
2547	87	Mahagura(Satha)	t
2548	87	Maharajpur-Karkora	t
2549	87	Mahav	t
2550	87	Mahmoodpur (Shik.)	t
2551	87	Malgosa	t
2552	87	Malyosa	t
2553	87	Mamau	t
2554	87	Md.Pur Ginori	t
2555	87	Mouroni	t
2556	87	Mukehra	t
2557	87	N. Bhensroli	t
2558	87	N.Rai Singh	t
2559	87	Nagaliya	t
2560	87	Nagla Harisingh	t
2561	87	Nagla Rai Singh	t
2562	87	Naglajagat	t
2563	87	Naglia Takkar	t
2564	87	Naglia Udaibhan	t
2565	87	Nar Mohamad	t
2566	87	Nawada	t
2567	87	Neemka	t
2568	87	Nemtabad	t
2569	87	Oranga	t
2570	87	Other	t
2571	87	Pala	t
2572	87	Palra	t
2573	87	Parauli	t
2574	87	Peetampur	t
2575	87	Rahmapur	t
2576	87	Raipur Daheli	t
2577	87	Ramnagar	t
2578	87	Rampur Manpur	t
2579	87	Ramwas	t
2580	87	Ranaich	t
2581	87	Rasoolpur	t
2582	87	Rohinda	t
2583	87	Sabitgarh	t
2584	87	Sahar	t
2585	87	Salabad	t
2586	87	Salaimpur	t
2587	87	Salaimpur(P.Garhi)	t
2588	87	Salampur	t
2589	87	Salimpur (B)	t
2590	87	Samastpur	t
2591	87	Seekra	t
2592	87	Sendra Faridpur	t
2593	87	Shahpur	t
2594	87	Shehwajpurdaulat	t
2595	87	Shukla	t
2596	87	Shyalri	t
2597	87	Shyampur	t
2598	87	Siddhaâ Garhi	t
2599	87	Sohi	t
2600	87	Sooratpur Khurd	t
2601	87	Sujapur Putha	t
2602	87	Surajpur Putha	t
2603	87	Suratpur	t
2604	87	Surja Vali (Salempur)	t
2605	87	Turkipurawas	t
2606	87	Udaypur	t
2607	88	Asratpur	t
2608	88	Beehra	t
2609	88	Bhandoria	t
2610	88	Bondra	t
2611	88	Jamalpur	t
2612	88	Jitaka	t
2613	88	Khanoda	t
2614	88	Khawajpur	t
2615	88	Kheri	t
2616	88	Kisholi	t
2617	88	Lakhaoti	t
2618	88	Maheshpur	t
2619	88	Moodibakapur	t
2620	88	Muktesra	t
2621	88	Nimchana	t
2622	88	Other	t
2623	88	Pasoli	t
2624	88	Pipala	t
2625	88	Rajgarhi	t
2626	88	Tomri	t
2627	89	Accher	t
2628	89	Aicchar Sector 36	t
2629	89	Begumpur	t
2630	89	Bironda	t
2631	89	Dadupur	t
2632	89	Greater Noida	t
2633	89	Imliyaka	t
2634	89	Janta Flat	t
2635	89	Kashiram Colony	t
2636	89	Kasna	t
2637	89	Khakrala Village Phase 2	t
2638	89	Malakpur	t
2639	89	Manakpur	t
2640	89	Rampur	t
2641	89	Silver City	t
2642	89	Surajpur	t
2643	89	Swarn Nagri Greater Noida	t
2644	90	Other	t
2645	91	Aichhar	t
2646	91	Balla Ki Mandhiya	t
2647	91	Barsaat	t
2648	91	Begumpur	t
2649	91	Bimtech School	t
2650	91	Bironda	t
2651	91	Dabra	t
2652	91	Dadha	t
2653	91	Dadupur	t
2654	91	Ghangola	t
2655	91	Godi Bachheda	t
2656	91	Gujarpur	t
2657	91	Gulistanpur	t
2658	91	Imliyaka	t
2659	91	Jfl Kasna	t
2660	91	Jls G. Noida	t
2661	91	Jls G.Noida	t
2662	91	Kasna	t
2663	91	Kayampur	t
2664	91	Khanpur	t
2665	91	Luksar	t
2666	91	Natto Ki Mandiya	t
2667	91	Other	t
2668	91	Pubhari	t
2669	91	Raipur Banger	t
2670	91	Rampur Fatehpur	t
2671	91	Sirsa	t
2672	91	Surajpur	t
2673	91	Tugalpur	t
2674	92	Dadupur	t
2675	92	Devla	t
2676	92	Fazayalpur	t
2677	92	Ghangola	t
2678	92	Imliyaka	t
2679	92	Jaitpur	t
2680	92	Kasna	t
2681	92	Khanpur	t
2682	92	Ladpura	t
2683	92	Luksar	t
2684	92	Maycha	t
2685	92	Mkoda	t
2686	92	Natto Ki Mandiya	t
2687	92	Nyana	t
2688	92	Rampur-Fatehpur	t
2689	92	Salempur Gujjar	t
2690	92	Shapur	t
2691	92	Sirsa	t
2692	92	Surajpur	t
2693	92	Til Begumpur	t
2694	93	Abdulcheck	t
2695	93	Adrauna	t
2696	93	Adrauna Kairtiya Taula	t
2697	93	Ahirauli	t
2698	93	Amdariya	t
2699	93	Babhanavli	t
2700	93	Badahara A	t
2701	93	Badahara B	t
2702	93	Badahara C	t
2703	93	Badhara	t
2704	93	Bag Padhna	t
2705	93	Bahadurganj	t
2706	93	Bakha Mahadeva	t
2707	93	Bakhanti	t
2708	93	Bandhawa	t
2709	93	Bariyatola	t
2710	93	Barwa Bazar Khurd	t
2711	93	Barwa Mahadeva	t
2712	93	Barwa Sthan	t
2713	93	Barwakhurd	t
2714	93	Basantpur	t
2715	93	Basdila	t
2716	93	Bhatwaliya	t
2717	93	Bhuaisohara	t
2718	93	Bihuli Sumali	t
2719	93	Bisanpura	t
2720	93	Bishunpur Ab	t
2721	93	Chandarpur	t
2722	93	Chandarpur Ahirtola	t
2723	93	Chandarpur Barwa	t
2724	93	Chandarpur Bauliya	t
2725	93	Chandarpur Gobarhi	t
2726	93	Chandarpur Khash	t
2727	93	Chandarpur Lachhiya	t
2728	93	Chandarpur Malgahan	t
2729	93	Dandopur	t
2730	93	Dandopur Pratham	t
2731	93	Dhautikar	t
2732	93	Dhodharahi	t
2733	93	Dhuwatika	t
2734	93	Dir Chapra	t
2735	93	Hanumanganj	t
2736	93	Jadahan	t
2737	93	Jagal Chauriya	t
2738	93	Jagal Jagdeeshpur	t
2739	93	Jamunbakha	t
2740	93	Jayi Chhapra	t
2741	93	Kalwari Patti	t
2742	93	Kathinhiya	t
2743	93	Kathiniya	t
2744	93	Khairatiya	t
2745	93	Khairatwa	t
2746	93	Kotwa	t
2747	93	Kuia	t
2748	93	Kusmi	t
2749	93	Laukariya	t
2750	93	Machharahan	t
2751	93	Madhav Gauji	t
2752	93	Madhopur	t
2753	93	Maghimathia A	t
2754	93	Mandarey	t
2755	93	Mansha Chapra	t
2756	93	Mathiadheer	t
2757	93	Mathiya Dheer	t
2758	93	Mishrauli	t
2759	93	Mishrauli Khan Taula	t
2760	93	Mishroli	t
2761	93	Morvan A	t
2762	93	Morvan B	t
2763	93	Morwan	t
2764	93	Moti Chhapra	t
2765	93	Motipur	t
2766	93	Narsar	t
2767	93	Navgawa	t
2768	93	Other	t
2769	93	Padari	t
2770	93	Pakdi Bantir Somali	t
2771	93	Pakdi Bantir Sonha	t
2772	93	Papaur B	t
2773	93	Papur	t
2774	93	Pardi	t
2775	93	Parsoni	t
2776	93	Patehra	t
2777	93	Pathar Deva	t
2778	93	Pathardeva	t
2779	93	Pharna	t
2780	93	Pidari	t
2781	93	Piparbujurg	t
2782	93	Pipra Khurd	t
2783	93	Pipra Khurd A	t
2784	93	Porarah	t
2785	93	Rampur Khas	t
2786	93	Rowari	t
2787	93	Sahuadeeh	t
2788	93	Saithayi Misr	t
2789	93	Sanera Malchapra	t
2790	93	Saneramal Chapra	t
2791	93	Sapaha Khas	t
2792	93	Sapaha Mahto	t
2793	93	Saunha	t
2794	93	Sekhue Misra	t
2795	93	Shauraha Khurd	t
2796	93	Sidhawat Chhavni	t
2797	93	Sidhawat Khas	t
2798	93	Sirsiya Kala	t
2799	93	Sirsiya Khurd	t
2800	93	Siswa Mathiya	t
2801	93	Sohrauna	t
2802	93	Surya Nagar	t
2803	93	Sushwaliya	t
2804	93	Taydi	t
2805	93	Urdahan-2	t
2806	93	Urdha 3	t
2807	93	Urdha A	t
2808	93	Vijayi Chapra	t
2809	93	Vishunpura Upadhyay Tola	t
2810	94	Ahmamau	t
2811	94	Ahmatnagar Musahabganj	t
2812	94	Alam Nagar	t
2813	94	Arjunganj	t
2814	94	Bani	t
2815	94	Banthra	t
2816	94	Bharatpuri	t
2817	94	Bhudeswar	t
2818	94	Dubagga	t
2819	94	Gadi Kanura	t
2820	94	Gomti Nagar	t
2821	94	Guda Kaloni	t
2822	94	Juggaur	t
2823	94	Khasiram Aawash Yojana	t
2824	94	Mauriya	t
2825	94	Natwan Dera	t
2826	94	Sarojini Nagar	t
2827	94	Sohramau	t
2828	94	Tal Katora	t
2829	94	Tejikheda	t
2830	94	Vikas Nagar	t
2831	95	Aalamgeerpur	t
2832	95	Abdllapur Leda	t
2833	95	Adalpur	t
2834	95	Alhepur	t
2835	95	Aliabad	t
2836	95	Amantabad	t
2837	95	Ashalempur	t
2838	95	Badhapur	t
2839	95	Bahadur Nagar	t
2840	95	Baidhnathpur	t
2841	95	Bairampur	t
2842	95	Balapur	t
2843	95	Bamaniya Patti	t
2844	95	Bankawala	t
2845	95	Begampur	t
2846	95	Bhagiyawala	t
2847	95	Bhaipur	t
2848	95	Bhood	t
2849	95	Bobad Wala	t
2850	95	Budh Nagar	t
2851	95	Cane Office	t
2852	95	Chandanpur	t
2853	95	Chandupur	t
2854	95	Darapur	t
2855	95	Dhakwala Majhra	t
2856	95	Dulhapur	t
2857	95	Eshapur	t
2858	95	Fatanpur	t
2859	95	Hospura	t
2860	95	Jofrabad	t
2861	95	Juladhakiya	t
2862	95	Kalewala	t
2863	95	Kanakpur	t
2864	95	Karanpur	t
2865	95	Khai Kheda	t
2866	95	Khaikhera	t
2867	95	Khwajpur	t
2868	95	Kotha Mahamood	t
2869	95	Kundesra	t
2870	95	Lalawala	t
2871	95	Lalpur Goshai	t
2872	95	Lodhipur Patti	t
2873	95	Madaiya Vijay Rampur	t
2874	95	Madarpur	t
2875	95	Madhowala	t
2876	95	Mahespur	t
2877	95	Mallupura	t
2878	95	Mill Gat Yard	t
2879	95	Mill Gate	t
2880	95	Mishripur	t
2881	95	Modhiharatpur	t
2882	95	Modihajratpur	t
2883	95	Mohaddeenpur	t
2884	95	Mohiadinpur	t
2885	95	Mulawaan	t
2886	95	Mustafabad	t
2887	95	Naharwala	t
2888	95	Naherwala	t
2889	95	Nangla Tahar	t
2890	95	Nirmalpur	t
2891	95	Other	t
2892	95	Paindapur	t
2893	95	Pashiyapura Padarath	t
2894	95	Pattimodha	t
2895	95	Pipli Ahir	t
2896	95	Raghuwala	t
2897	95	Rajpur Milak	t
2898	95	Rajupur Kala	t
2899	95	Rani Nagal	t
2900	95	Raninagal	t
2901	95	Ratupura	t
2902	95	Rehta Maafi	t
2903	95	Rooppur Tandola	t
2904	95	Sabalpur	t
2905	95	Salarpur	t
2906	95	Salempur	t
2907	95	Sarkada Param	t
2908	95	Sarkara Vishnoi	t
2909	95	Sarkoda Param	t
2910	95	Shareef Nagar	t
2911	95	Sherpur Behlin	t
2912	95	Sherpur Patti	t
2913	95	Sugar Mill	t
2914	95	Sultanpur Khaadar	t
2915	95	Sultanpur Khaddar	t
2916	95	Sultanpur Munda	t
2917	95	Tigri	t
2918	95	Triveni Raninagal	t
2919	95	Udairwala	t
2920	95	Veerwala	t
2921	96	A.Mouchri	t
2922	96	Ahmadgarh	t
2923	96	Ahroda	t
2924	96	Akbarpur Sadat	t
2925	96	Akhepur	t
2926	96	Ambarpur	t
2927	96	Amroli	t
2928	96	Anti	t
2929	96	Antwara	t
2930	96	Badsu	t
2931	96	Bahpur	t
2932	96	Basayach	t
2933	96	Bhainsi East	t
2934	96	Bhainsi West	t
2935	96	Bhaleri	t
2936	96	Bhalwa	t
2937	96	Bhamori	t
2938	96	Bhangi- Bhangela	t
2939	96	Bhanwada	t
2940	96	Bhoop Khedi	t
2941	96	Buada Kalan	t
2942	96	Buada Khurd	t
2943	96	Chacherpur	t
2944	96	Chandsamand	t
2945	96	Chandsinha	t
2946	96	Chinduada	t
2947	96	Chinduadi	t
2948	96	Chitora	t
2949	96	Chittoda	t
2950	96	Dabathua	t
2951	96	Dahaud	t
2952	96	Dandu Pur	t
2953	96	Daulatpur	t
2954	96	Dayal Puri	t
2955	96	Dedupur	t
2956	96	Dudhali	t
2957	96	Dukhchara	t
2958	96	Dungar(Maliyana)	t
2959	96	Fahimpur	t
2960	96	Faridpur	t
2961	96	Gadanpura	t
2962	96	Gagsona	t
2963	96	Galibpur	t
2964	96	Gangdhari	t
2965	96	Gaya Nagla	t
2966	96	Ghanshyam Pur	t
2967	96	Ghatayan North	t
2968	96	Ghatayan South	t
2969	96	Goyala	t
2970	96	Hazipur	t
2971	96	Inchoda	t
2972	96	Incholi	t
2973	96	Jamal Pur	t
2974	96	Jandhedi Jatan	t
2975	96	Jangethi	t
2976	96	Jansath	t
2977	96	Jasaula	t
2978	96	Jatpura	t
2979	96	Javan	t
2980	96	Jeet Pur	t
2981	96	Jhinjharpur	t
2982	96	Kadli	t
2983	96	Kaihalawada	t
2984	96	Kailash Nagar	t
2985	96	Kakrala	t
2986	96	Kakroli	t
2987	96	Kalyanpur	t
2988	96	Katka	t
2989	96	Kawal	t
2990	96	Khalidpur	t
2991	96	Khanjapur	t
2992	96	Khanpur	t
2993	96	Khata	t
2994	96	Khataula	t
2995	96	Khatauli	t
2996	96	Khaukhani	t
2997	96	Kheda Chongava	t
2998	96	Khedi Quresh	t
2999	96	Khedi Tagan	t
3000	96	Khera	t
3001	96	Kheri	t
3002	96	Kitash	t
3003	96	Kusawali	t
3004	96	Ladpur	t
3005	96	Lahaudda	t
3006	96	Lisauda	t
3007	96	Madkarimpur	t
3008	96	Maheshpur	t
3009	96	Maksuda Bad	t
3010	96	Mandawali Bangar	t
3011	96	Mandawali Khadar	t
3012	96	Mandwadi	t
3013	96	Manphoda	t
3014	96	Mantaudi	t
3015	96	Mathedi	t
3016	96	Mimla Khedi	t
3017	96	Mira Pur Khurd	t
3018	96	Mirapur Dalpat	t
3019	96	Mohammadpur	t
3020	96	Mohiuddinpur	t
3021	96	Moman	t
3022	96	Mubarikpur	t
3023	96	Mujahid Pur	t
3024	96	Mustafabad	t
3025	96	Naepura	t
3026	96	Nagla Sayani	t
3027	96	Nagli Ajhad	t
3028	96	Nagli Mahasingh	t
3029	96	Nagli Sadharan	t
3030	96	Nagoari	t
3031	96	Naidu	t
3032	96	Nanglarout	t
3033	96	Nayagav	t
3034	96	Nithari	t
3035	96	Nuni Kheda	t
3036	96	Other	t
3037	96	Paharpur Bangar	t
3038	96	Pal	t
3039	96	Palda	t
3040	96	Paldi	t
3041	96	Pamnawali	t
3042	96	Phalauda	t
3043	96	Phulat	t
3044	96	Pilona	t
3045	96	Pimoda	t
3046	96	Pipal Hera	t
3047	96	Poothkhas	t
3048	96	Puttha	t
3049	96	Rahavati	t
3050	96	Raipur Nangli	t
3051	96	Rampur	t
3052	96	Rampur Ghoriya	t
3053	96	Rardhana	t
3054	96	Rasulpur Kilaura	t
3055	96	Ratore	t
3056	96	Riyawali Nagla	t
3057	96	Ruhasa	t
3058	96	Rukanpur	t
3059	96	Sadpur	t
3060	96	Saidipur	t
3061	96	Sakauti	t
3062	96	Salava	t
3063	96	Samoli	t
3064	96	Sanota	t
3065	96	Sarai Rasulpur	t
3066	96	Sardhan	t
3067	96	Sathedi	t
3068	96	Shahpur	t
3069	96	Shekhpura	t
3070	96	Sikanderpur Kala	t
3071	96	Sikanderpur Khurd	t
3072	96	Sikeda(Gate)	t
3073	96	Siyajudi	t
3074	96	Sohjni	t
3075	96	Tabita	t
3076	96	Tajpur	t
3077	96	Tanda	t
3078	96	Tigri	t
3079	96	Tilora	t
3080	96	Tingai	t
3081	96	Tisung	t
3082	96	Titoda	t
3083	96	Tulsipur	t
3084	96	Vazidpur Kavvali	t
3085	96	Wajidpur Khurd	t
3086	96	Yahiyapur	t
3087	97	Akbarabad	t
3088	97	Ali Ganj	t
3089	97	Alianagar	t
3090	97	Allehpur	t
3091	97	Bathuwa Khera	t
3092	97	Bhubra Mustekam	t
3093	97	Bodhi Daryal	t
3094	97	Boobra	t
3095	97	Chack Khardiya	t
3096	97	Chakdulli	t
3097	97	Chandupura	t
3098	97	Chandupuri	t
3099	97	Darhiyal	t
3100	97	Fattawala	t
3101	97	Ghosipura	t
3102	97	Jamna Jamni	t
3103	97	Jatpura	t
3104	97	Khanpur	t
3105	97	Kishanpur	t
3106	97	Kundesra	t
3107	97	Kundesri	t
3108	97	Laddpur Bibi	t
3109	97	Lodhipur Nayak	t
3110	97	Lohara Inayat	t
3111	97	Mahua Khera	t
3112	97	Majhra Mubana	t
3113	97	Mirapur Mirganj	t
3114	97	Mohmadpur	t
3115	97	Mubana	t
3116	97	Nankar Rani	t
3117	97	Narayanpur	t
3118	97	Narpat Nagar	t
3119	97	Other	t
3120	97	Piplinayak	t
3121	97	Pursupura	t
3122	97	Puswara	t
3123	97	Rahmant Ganj	t
3124	97	Roopapur	t
3125	97	Sarakthal	t
3126	97	Shivnagar	t
3127	97	Sikampur	t
3128	97	Sirka	t
3129	97	Sithla	t
3130	98	Abdullah Pur	t
3131	98	Akbargarh	t
3132	98	Alamgir Pur (Doodhli	t
3133	98	Alawalpur	t
3134	98	Ali Pur	t
3135	98	Amarpur Gadhi	t
3136	98	Amarpur Nain	t
3137	98	Ambehta Sheikh	t
3138	98	Ambeta Shekha	t
3139	98	Amboli	t
3140	98	Arnayach	t
3141	98	Babupur	t
3142	98	Bachiti	t
3143	98	Baddedi	t
3144	98	Badedi Kala	t
3145	98	Badhai Kalan (Deh)	t
3146	98	Badhedi	t
3147	98	Badhedi Khurd	t
3148	98	Baduli	t
3149	98	Baduli_N	t
3150	98	Bago Wali (Rohana)	t
3151	98	Bahadar Pur	t
3152	98	Bahera	t
3153	98	Bajeed Pur	t
3154	98	Bajhedi	t
3155	98	Balu Majra	t
3156	98	Balu Majra_N	t
3157	98	Balwa Kheri	t
3158	98	Bandar Juda	t
3159	98	Bargaon	t
3160	98	Bargaon N	t
3161	98	Bastam	t
3162	98	Beerpur	t
3163	98	Begam Pur	t
3164	98	Belda Bujurg	t
3165	98	Bhaila Kalan	t
3166	98	Bhaila Khurd	t
3167	98	Bhanera Khass	t
3168	98	Bharapur	t
3169	98	Bhataul	t
3170	98	Bhatpura	t
3171	98	Bhawanpur	t
3172	98	Bhayla Khurd	t
3173	98	Bhaylakala	t
3174	98	Bibipur	t
3175	98	Bijo Pura	t
3176	98	Biralsi	t
3177	98	Bishan Pur(Gunarsi)	t
3178	98	Budha Khera	t
3179	98	Chandena Koli	t
3180	98	Chandpur	t
3181	98	Chandpur Majbata	t
3182	98	Chaukra	t
3183	98	Chaundahedi	t
3184	98	Chhimau	t
3185	98	Chiraon	t
3186	98	Dakowali	t
3187	98	Daleep Pura	t
3188	98	Dangheda	t
3189	98	Datiayana	t
3190	98	Dehchand	t
3191	98	Dehra	t
3192	98	Deoband First	t
3193	98	Deoband Iind	t
3194	98	Dharam Pur Gurjar	t
3195	98	Dhoom Garh	t
3196	98	Diwal Hedi	t
3197	98	Doodhli (Rohana)	t
3198	98	Dudhli	t
3199	98	Dugchada	t
3200	98	Dugchari	t
3201	98	Dulichandpur	t
3202	98	Falauda	t
3203	98	Farid Pur	t
3204	98	Fatehpur	t
3205	98	Fatehullah Pur	t
3206	98	Gangdaspur	t
3207	98	Ganjheri	t
3208	98	Ghalauli	t
3209	98	Ghiana	t
3210	98	Ghisar Padi	t
3211	98	Ghissu Khera	t
3212	98	Gopali	t
3213	98	Gunarsa	t
3214	98	Gunarsi	t
3215	98	Gurgaj Pur	t
3216	98	Hasimpur	t
3217	98	Hulas Garh	t
3218	98	Ibdullapur	t
3219	98	Imalia	t
3220	98	Ismail Pur	t
3221	98	Jagdei	t
3222	98	Jahirpur	t
3223	98	Jakhwala	t
3224	98	Jalal Pur Mazri	t
3225	98	Jaroda Jatt	t
3226	98	Jatola Damodar Pur	t
3227	98	Jatoul	t
3228	98	Jhaniran	t
3229	98	Kallan Hedi	t
3230	98	Kanjali	t
3231	98	Kapoori	t
3232	98	Kasim Pur	t
3233	98	Kasim Pur Niwada	t
3234	98	Kasoli	t
3235	98	Kayampur	t
3236	98	Kendki	t
3237	98	Khajuri	t
3238	98	Khandja Ahmedpur	t
3239	98	Khedi Junka	t
3240	98	Kheri Assa	t
3241	98	Khoja Nagla	t
3242	98	Khudda	t
3243	98	Kishan Pura	t
3244	98	Kishanpura	t
3245	98	Korwa	t
3246	98	Kota	t
3247	98	Kulseth	t
3248	98	Kuralki	t
3249	98	Kurdi	t
3250	98	Kutesra Ghangarh Pat	t
3251	98	Kutesra Ibrahim P.	t
3252	98	Kutesra Lakkad Patti	t
3253	98	Kutesra Shankarpatti	t
3254	98	Kutesra Suleman P.	t
3255	98	Labkari	t
3256	98	Lacchipur	t
3257	98	Lakhnaur	t
3258	98	Lakhnouti	t
3259	98	Laltala	t
3260	98	Luhari	t
3261	98	Lukadari	t
3262	98	Maheshpur	t
3263	98	Majari	t
3264	98	Majhol	t
3265	98	Makbara	t
3266	98	Makhiyali	t
3267	98	Manki	t
3268	98	Manohar Pur	t
3269	98	Mathura	t
3270	98	Maya Pur	t
3271	98	Mayaheri	t
3272	98	Megh Raj Pur	t
3273	98	Miragpur Dola Paripe	t
3274	98	Miragpur Dola Patti	t
3275	98	Miragpur Kakan Matri	t
3276	98	Miragpur Ruhaiya	t
3277	98	Mirzapur	t
3278	98	Mohdin Pur	t
3279	98	Mushkipur	t
3280	98	Nagli Noor	t
3281	98	Nanehra Kalan	t
3282	98	Nanheda Teeptan	t
3283	98	Nanhera Asha	t
3284	98	Nanhera Khurd	t
3285	98	Nasrullapur	t
3286	98	Naya Gaon	t
3287	98	Nihal Khedi	t
3288	98	Niyamatpur	t
3289	98	Niyamu	t
3290	98	Noorpur	t
3291	98	Nunawari	t
3292	98	Other	t
3293	98	Pachim Charthawal	t
3294	98	Pahupur	t
3295	98	Palauli	t
3296	98	Paniyali	t
3297	98	Phulas-A-Pur	t
3298	98	Phulasi	t
3299	98	Pipal Shaha	t
3300	98	Purvi Charthawal	t
3301	98	Rahmat Pur	t
3302	98	Rajju Pur	t
3303	98	Rammu Pur	t
3304	98	Rankhandi	t
3305	98	Rankhandi (Rohana)	t
3306	98	Ranmal Pur	t
3307	98	Ransura	t
3308	98	Rasoolpur Tank	t
3309	98	Rastam	t
3310	98	Ratan Hedi	t
3311	98	Reda	t
3312	98	Saadpur	t
3313	98	Sadharan Pur	t
3314	98	Sahji	t
3315	98	Sainpur	t
3316	98	Sakhan Kala	t
3317	98	Sakhan Khurd	t
3318	98	Salauni	t
3319	98	Salem Pur	t
3320	98	Salha Pur	t
3321	98	Sampla Bakkal	t
3322	98	Sampla Khatri	t
3323	98	Seedki	t
3324	98	Seedpura	t
3325	98	Shabbir Pur	t
3326	98	Shahpur	t
3327	98	Shakarpur Tigri	t
3328	98	Shekhupur	t
3329	98	Shekhupur Tak	t
3330	98	Shimlana	t
3331	98	Shiv Pur	t
3332	98	Shivdass Pur	t
3333	98	Sikanderpur	t
3334	98	Sirsali Kalan	t
3335	98	Sirsali Khurd	t
3336	98	Sisauni	t
3337	98	Sisona Jamalpur	t
3338	98	Subre	t
3339	98	Sultanpur	t
3340	98	Sunehti	t
3341	98	Taiyab Pur	t
3342	98	Talheri Buzurg	t
3343	98	Telheri Khurd	t
3344	98	Thithki	t
3345	98	Thokar Pur	t
3346	98	Tigri	t
3347	98	Tigri(Morna)	t
3348	98	Uncha Gaon	t
3349	99	Rampur Vill	t
3350	99	Rampur Vill Two	t
3351	100	Sarsawa Vill 1	t
3352	100	Sarsawa Vill 2	t
3353	101	Bhagwanpur	t
3354	101	Chauli 1	t
3355	101	Chauli 2	t
3356	101	Chhangamajri	t
3357	101	Chhapur	t
3358	101	Dadda Pati	t
3359	101	Daudbassi	t
3360	101	Gee	t
3361	101	Hassanpur Madanpur	t
3362	101	Kawad	t
3363	101	Khanpur	t
3364	101	Khelpur	t
3365	101	Khubbanpur	t
3366	101	Lavva	t
3367	101	Makkhanpur	t
3368	101	Mandawar	t
3369	101	Other	t
3370	101	Raipur	t
3371	101	Ruhalki	t
3372	101	Sikanderpur	t
3373	101	Sirchandi	t
3374	101	Sisona	t
3375	102	Bahadurpur	t
3376	102	Chelod	t
3377	102	Churulia	t
3378	102	Domohani Basti	t
3379	102	Kalyanpur	t
3380	102	Lachhipur	t
3381	102	Narayanpur	t
3382	102	Panipathar	t
3383	102	Rangamatia	t
3384	102	Salapara	t
3385	103	Bolpur Â€“ Shantiniketan	t
3386	103	Goalpara	t
3387	103	Kankalitola	t
3388	103	Kustikapara	t
3389	103	Pearson Pally	t
3390	103	Prantik	t
3391	103	Raipur	t
3392	103	Shyambati	t
3393	103	Surul	t
3394	104	Ashighar Slum Cluster	t
3395	104	Bagdogra Bypass Urban Pockets	t
3396	104	Champasari More Settlements	t
3397	104	Matigara Basti	t
3398	104	Pradhan Nagar Slum Pocket	t
3399	104	Railway Colony Adjacent Slums	t
3400	104	Shivmandir Fringe Area	t
3401	104	Subhashpally Informal Cluster	t
3402	104	Ward 46 Â€“ College Para	t
3403	105	Baniyara	t
3404	105	Bhagabatipur	t
3405	105	Biki Hakola	t
3406	105	Bikihakola	t
3407	105	Bikihakola (Skpara)	t
3408	105	Biprannapara	t
3409	105	Dhamisa	t
3410	105	Dhulagori	t
3411	105	Hatisal	t
3412	105	Jele Para	t
3413	105	Kandua	t
3414	105	Kandua (Royel Club)	t
3415	105	Kandua (Yubak Sangha)	t
3416	105	Khan Para	t
3417	105	Kulai	t
3418	105	Monsatala	t
3419	105	Nabghora (Netaji Club)	t
3420	105	Nabghora (Ruidaspara)	t
3421	105	New Road	t
3422	105	Ranihati	t
3423	105	Ruidas Para	t
3424	105	Sandhipur	t
3425	105	Sulati (Samaj Kalyan Samiti)	t
3426	105	Sulati (Skpara)	t
3427	106	Kandua	t
3428	106	Nanghara	t
3429	106	Sulati	t
3430	107	Bikihakola	t
3431	108	Chaknorsingha	t
3432	109	Bamnani	t
3433	109	Bamunari Shiv Tola	t
3434	109	Bangihati Dakshin Para	t
3435	109	Bangihati Majher Para	t
3436	109	Bangihati Uttor Para	t
3437	109	Bibir Ber	t
3438	109	Bibir Beri	t
3439	109	Dhamisa	t
3440	109	Ghash Para	t
3441	109	Gumodanga-1	t
3442	109	Gumodanga-2	t
3443	109	Jaladhulagori	t
3444	109	Kandua	t
3445	109	Madhpur	t
3446	109	Madhpur-1	t
3447	109	Madhpur-2	t
3448	109	Mirpur	t
3449	109	Mollar Beri	t
3450	109	Mollerber Madrasa Math	t
3451	109	Monsatala	t
3452	109	Panchla	t
3453	109	Paniyara	t
3454	109	Sankrail	t
3455	109	Satghara	t
3456	109	Satghora	t
3457	109	Simla Kali Tola	t
3458	109	Simla Kalitola	t
3459	109	Sulati	t
3460	109	Vaduya	t
3461	110	Beck Bazaar	t
3462	110	Beniapukur	t
3463	110	Circus Avenue	t
3464	110	Circus Avenue Pavement Dwellers	t
3465	110	Deb Lane Slum Pocket	t
3466	110	Free School Street Cluster	t
3467	110	Mullick Bazar	t
3468	110	Nonapukur Slum Pocket	t
3469	110	Nonnapukur Slum	t
3470	110	Park Circus	t
3471	110	Park Circus Seven Point Area	t
3472	110	Raja Bazaar	t
3473	110	Ripon Street Informal Cluster	t
3474	110	Sealdah Peripheral	t
3475	110	Tijila Road Basti	t
3476	110	Tiljala Road Basti	t
3477	110	Topsia Canal East	t
3478	110	Ward 56 Â€“ Mullick Bazar	t
3479	111	Canning I Â€“ Chhoto Mollakhali	t
3480	111	Canning I Â€“ Durgapur	t
3481	111	Canning I Â€“ Gopalpur	t
3482	111	Canning I Â€“ Taldi	t
3483	111	Canning Ii Â€“ Atharabanki	t
3484	111	Canning Ii Â€“ Bamankhali	t
3485	111	Canning Ii Â€“ Deuli	t
3486	111	Canning Ii Â€“ Jatar Deul	t
3487	111	Canning Ii Â€“ Kalikatala	t
3488	111	Canning Ii Â€“ Narayanpur	t
3489	112	Test Village 3776	f
3496	119	Test Village 8160	f
3490	113	Test Village 9398	f
3493	116	Test Village 7797	f
3491	114	Test Village 5497	f
3492	115	Test Village 3913	f
3495	118	Test Village 9426	f
3494	117	Test Village 8247	f
3497	120	Test Village 7509	f
3498	121	Test Village 6717	f
3499	122	Test Village 3153	f
3500	123	Test Village 7800	f
3501	124	Test Village 5908	f
3502	125	Test Village 6988	f
3503	126	Test Village 4967	f
3504	127	Test Village 2177	f
3505	128	Test Village 7731	f
3506	129	Test Village 7357	f
3507	130	Test Village 8082	f
3508	131	Test Village 1669	f
3509	132	Test Village 2660	f
3510	133	Test Village 1650	f
3511	134	Test Village 9071	f
3512	135	Test Village 5879	f
3513	136	Test Village 1178	f
3514	137	Test Village 5826	f
3515	138	Test Village 7686	f
3516	139	Test Village 9419	f
3517	140	Test Village 4068	f
3518	141	Test Village 4454	f
3549	172	Test Village 2468	f
3550	173	Test Village 4271	f
3551	174	Test Village 5493	f
3552	175	Test Village 6612	f
3553	176	Test Village 2527	f
3554	177	Test Village 1381	f
\.


--
-- TOC entry 5956 (class 0 OID 0)
-- Dependencies: 244
-- Name: app_user_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.app_user_user_id_seq', 265, true);


--
-- TOC entry 5957 (class 0 OID 0)
-- Dependencies: 264
-- Name: appointment_appointment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.appointment_appointment_id_seq', 229, true);


--
-- TOC entry 5958 (class 0 OID 0)
-- Dependencies: 272
-- Name: appointment_attachment_attachment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.appointment_attachment_attachment_id_seq', 1, false);


--
-- TOC entry 5959 (class 0 OID 0)
-- Dependencies: 268
-- Name: appointment_lab_test_appointment_lab_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.appointment_lab_test_appointment_lab_id_seq', 142, true);


--
-- TOC entry 5960 (class 0 OID 0)
-- Dependencies: 278
-- Name: attendance_attendance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.attendance_attendance_id_seq', 36, true);


--
-- TOC entry 5961 (class 0 OID 0)
-- Dependencies: 228
-- Name: block_ref_block_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.block_ref_block_id_seq', 177, true);


--
-- TOC entry 5962 (class 0 OID 0)
-- Dependencies: 308
-- Name: camp_anchor_camp_anchor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.camp_anchor_camp_anchor_id_seq', 3, true);


--
-- TOC entry 5963 (class 0 OID 0)
-- Dependencies: 276
-- Name: camp_camp_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.camp_camp_id_seq', 37, true);


--
-- TOC entry 5964 (class 0 OID 0)
-- Dependencies: 260
-- Name: category_master_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.category_master_category_id_seq', 5, true);


--
-- TOC entry 5965 (class 0 OID 0)
-- Dependencies: 256
-- Name: counselling_topic_master_topic_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.counselling_topic_master_topic_id_seq', 6, true);


--
-- TOC entry 5966 (class 0 OID 0)
-- Dependencies: 254
-- Name: device_master_device_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.device_master_device_id_seq', 4, true);


--
-- TOC entry 5967 (class 0 OID 0)
-- Dependencies: 280
-- Name: device_status_history_device_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.device_status_history_device_status_id_seq', 71, true);


--
-- TOC entry 5968 (class 0 OID 0)
-- Dependencies: 248
-- Name: disease_master_disease_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.disease_master_disease_id_seq', 111, true);


--
-- TOC entry 5969 (class 0 OID 0)
-- Dependencies: 226
-- Name: district_ref_district_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.district_ref_district_id_seq', 167, true);


--
-- TOC entry 5970 (class 0 OID 0)
-- Dependencies: 232
-- Name: facility_facility_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.facility_facility_id_seq', 163, true);


--
-- TOC entry 5971 (class 0 OID 0)
-- Dependencies: 252
-- Name: lab_test_master_lab_test_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.lab_test_master_lab_test_id_seq', 19, true);


--
-- TOC entry 5972 (class 0 OID 0)
-- Dependencies: 242
-- Name: leave_record_leave_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.leave_record_leave_id_seq', 69, true);


--
-- TOC entry 5973 (class 0 OID 0)
-- Dependencies: 250
-- Name: medicine_master_medicine_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.medicine_master_medicine_id_seq', 32, true);


--
-- TOC entry 5974 (class 0 OID 0)
-- Dependencies: 291
-- Name: migration_quarantine_quarantine_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.migration_quarantine_quarantine_id_seq', 1, false);


--
-- TOC entry 5975 (class 0 OID 0)
-- Dependencies: 293
-- Name: migration_run_run_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.migration_run_run_id_seq', 1, false);


--
-- TOC entry 5976 (class 0 OID 0)
-- Dependencies: 286
-- Name: mmu_location_track_track_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.mmu_location_track_track_id_seq', 1, false);


--
-- TOC entry 5977 (class 0 OID 0)
-- Dependencies: 234
-- Name: mmu_route_stop_route_stop_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.mmu_route_stop_route_stop_id_seq', 1, false);


--
-- TOC entry 5978 (class 0 OID 0)
-- Dependencies: 222
-- Name: offer_offer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.offer_offer_id_seq', 1, true);


--
-- TOC entry 5979 (class 0 OID 0)
-- Dependencies: 219
-- Name: organization_org_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.organization_org_id_seq', 111, true);


--
-- TOC entry 5980 (class 0 OID 0)
-- Dependencies: 289
-- Name: patient_monthly_aggregate_aggregate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.patient_monthly_aggregate_aggregate_id_seq', 1, false);


--
-- TOC entry 5981 (class 0 OID 0)
-- Dependencies: 262
-- Name: patient_patient_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.patient_patient_id_seq', 226, true);


--
-- TOC entry 5982 (class 0 OID 0)
-- Dependencies: 270
-- Name: prescription_item_prescription_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.prescription_item_prescription_item_id_seq', 119, true);


--
-- TOC entry 5983 (class 0 OID 0)
-- Dependencies: 274
-- Name: previous_prescription_previous_rx_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.previous_prescription_previous_rx_id_seq', 1, false);


--
-- TOC entry 5984 (class 0 OID 0)
-- Dependencies: 258
-- Name: referral_destination_master_destination_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.referral_destination_master_destination_id_seq', 5, true);


--
-- TOC entry 5985 (class 0 OID 0)
-- Dependencies: 306
-- Name: refresh_session_session_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.refresh_session_session_id_seq', 1238, true);


--
-- TOC entry 5986 (class 0 OID 0)
-- Dependencies: 284
-- Name: requisition_line_requisition_line_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.requisition_line_requisition_line_id_seq', 279, true);


--
-- TOC entry 5987 (class 0 OID 0)
-- Dependencies: 282
-- Name: requisition_requisition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.requisition_requisition_id_seq', 133, true);


--
-- TOC entry 5988 (class 0 OID 0)
-- Dependencies: 240
-- Name: roster_roster_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roster_roster_id_seq', 111, true);


--
-- TOC entry 5989 (class 0 OID 0)
-- Dependencies: 238
-- Name: staff_assignment_assignment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.staff_assignment_assignment_id_seq', 1, false);


--
-- TOC entry 5990 (class 0 OID 0)
-- Dependencies: 236
-- Name: staff_staff_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.staff_staff_id_seq', 303, true);


--
-- TOC entry 5991 (class 0 OID 0)
-- Dependencies: 224
-- Name: state_ref_state_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.state_ref_state_id_seq', 85, true);


--
-- TOC entry 5992 (class 0 OID 0)
-- Dependencies: 246
-- Name: symptom_master_symptom_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.symptom_master_symptom_id_seq', 30, true);


--
-- TOC entry 5993 (class 0 OID 0)
-- Dependencies: 311
-- Name: sync_action_sync_action_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sync_action_sync_action_id_seq', 90, true);


--
-- TOC entry 5994 (class 0 OID 0)
-- Dependencies: 296
-- Name: user_zone_user_zone_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_zone_user_zone_id_seq', 2, true);


--
-- TOC entry 5995 (class 0 OID 0)
-- Dependencies: 230
-- Name: village_ref_village_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.village_ref_village_id_seq', 3554, true);


--
-- TOC entry 5442 (class 2606 OID 30751)
-- Name: app_user app_user_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_pkey PRIMARY KEY (user_id);


--
-- TOC entry 5523 (class 2606 OID 31207)
-- Name: appointment_attachment appointment_attachment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_attachment
    ADD CONSTRAINT appointment_attachment_pkey PRIMARY KEY (attachment_id);


--
-- TOC entry 5506 (class 2606 OID 31113)
-- Name: appointment_diagnosis appointment_diagnosis_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_diagnosis
    ADD CONSTRAINT appointment_diagnosis_pkey PRIMARY KEY (appointment_id, diagnosis_text);


--
-- TOC entry 5512 (class 2606 OID 31139)
-- Name: appointment_lab_test appointment_lab_test_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_lab_test
    ADD CONSTRAINT appointment_lab_test_pkey PRIMARY KEY (appointment_lab_id);


--
-- TOC entry 5492 (class 2606 OID 31028)
-- Name: appointment appointment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_pkey PRIMARY KEY (appointment_id);


--
-- TOC entry 5503 (class 2606 OID 31092)
-- Name: appointment_symptom appointment_symptom_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_symptom
    ADD CONSTRAINT appointment_symptom_pkey PRIMARY KEY (appointment_id, symptom_id);


--
-- TOC entry 5540 (class 2606 OID 31297)
-- Name: attendance attendance_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_pkey PRIMARY KEY (attendance_id);


--
-- TOC entry 5400 (class 2606 OID 30519)
-- Name: block_ref block_ref_district_id_block_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.block_ref
    ADD CONSTRAINT block_ref_district_id_block_name_key UNIQUE (district_id, block_name);


--
-- TOC entry 5402 (class 2606 OID 30517)
-- Name: block_ref block_ref_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.block_ref
    ADD CONSTRAINT block_ref_pkey PRIMARY KEY (block_id);


--
-- TOC entry 5585 (class 2606 OID 57407)
-- Name: camp_anchor camp_anchor_facility_id_anchor_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camp_anchor
    ADD CONSTRAINT camp_anchor_facility_id_anchor_name_key UNIQUE (facility_id, anchor_name);


--
-- TOC entry 5587 (class 2606 OID 57405)
-- Name: camp_anchor camp_anchor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camp_anchor
    ADD CONSTRAINT camp_anchor_pkey PRIMARY KEY (camp_anchor_id);


--
-- TOC entry 5534 (class 2606 OID 31257)
-- Name: camp camp_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camp
    ADD CONSTRAINT camp_pkey PRIMARY KEY (camp_id);


--
-- TOC entry 5476 (class 2606 OID 30893)
-- Name: category_master category_master_category_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.category_master
    ADD CONSTRAINT category_master_category_name_key UNIQUE (category_name);


--
-- TOC entry 5478 (class 2606 OID 30891)
-- Name: category_master category_master_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.category_master
    ADD CONSTRAINT category_master_pkey PRIMARY KEY (category_id);


--
-- TOC entry 5468 (class 2606 OID 30863)
-- Name: counselling_topic_master counselling_topic_master_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.counselling_topic_master
    ADD CONSTRAINT counselling_topic_master_pkey PRIMARY KEY (topic_id);


--
-- TOC entry 5470 (class 2606 OID 30865)
-- Name: counselling_topic_master counselling_topic_master_topic_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.counselling_topic_master
    ADD CONSTRAINT counselling_topic_master_topic_name_key UNIQUE (topic_name);


--
-- TOC entry 5464 (class 2606 OID 30851)
-- Name: device_master device_master_device_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_master
    ADD CONSTRAINT device_master_device_name_key UNIQUE (device_name);


--
-- TOC entry 5466 (class 2606 OID 30849)
-- Name: device_master device_master_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_master
    ADD CONSTRAINT device_master_pkey PRIMARY KEY (device_id);


--
-- TOC entry 5545 (class 2606 OID 31327)
-- Name: device_status_history device_status_history_device_id_facility_id_status_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_status_history
    ADD CONSTRAINT device_status_history_device_id_facility_id_status_date_key UNIQUE (device_id, facility_id, status_date);


--
-- TOC entry 5547 (class 2606 OID 31325)
-- Name: device_status_history device_status_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_status_history
    ADD CONSTRAINT device_status_history_pkey PRIMARY KEY (device_status_id);


--
-- TOC entry 5451 (class 2606 OID 30803)
-- Name: disease_master disease_master_disease_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disease_master
    ADD CONSTRAINT disease_master_disease_name_key UNIQUE (disease_name);


--
-- TOC entry 5453 (class 2606 OID 30801)
-- Name: disease_master disease_master_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disease_master
    ADD CONSTRAINT disease_master_pkey PRIMARY KEY (disease_id);


--
-- TOC entry 5394 (class 2606 OID 30497)
-- Name: district_ref district_ref_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.district_ref
    ADD CONSTRAINT district_ref_pkey PRIMARY KEY (district_id);


--
-- TOC entry 5396 (class 2606 OID 30499)
-- Name: district_ref district_ref_state_id_district_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.district_ref
    ADD CONSTRAINT district_ref_state_id_district_name_key UNIQUE (state_id, district_name);


--
-- TOC entry 5414 (class 2606 OID 30573)
-- Name: facility facility_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facility
    ADD CONSTRAINT facility_pkey PRIMARY KEY (facility_id);


--
-- TOC entry 5460 (class 2606 OID 30835)
-- Name: lab_test_master lab_test_master_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lab_test_master
    ADD CONSTRAINT lab_test_master_pkey PRIMARY KEY (lab_test_id);


--
-- TOC entry 5462 (class 2606 OID 30837)
-- Name: lab_test_master lab_test_master_test_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lab_test_master
    ADD CONSTRAINT lab_test_master_test_name_key UNIQUE (test_name);


--
-- TOC entry 5437 (class 2606 OID 30722)
-- Name: leave_record leave_record_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.leave_record
    ADD CONSTRAINT leave_record_pkey PRIMARY KEY (leave_id);


--
-- TOC entry 5456 (class 2606 OID 30821)
-- Name: medicine_master medicine_master_medicine_name_strength_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medicine_master
    ADD CONSTRAINT medicine_master_medicine_name_strength_key UNIQUE (medicine_name, strength);


--
-- TOC entry 5458 (class 2606 OID 30819)
-- Name: medicine_master medicine_master_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medicine_master
    ADD CONSTRAINT medicine_master_pkey PRIMARY KEY (medicine_id);


--
-- TOC entry 5570 (class 2606 OID 31694)
-- Name: migration_quarantine migration_quarantine_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.migration_quarantine
    ADD CONSTRAINT migration_quarantine_pkey PRIMARY KEY (quarantine_id);


--
-- TOC entry 5574 (class 2606 OID 31716)
-- Name: migration_run migration_run_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.migration_run
    ADD CONSTRAINT migration_run_pkey PRIMARY KEY (run_id);


--
-- TOC entry 5563 (class 2606 OID 31441)
-- Name: mmu_current_position mmu_current_position_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mmu_current_position
    ADD CONSTRAINT mmu_current_position_pkey PRIMARY KEY (facility_id);


--
-- TOC entry 5560 (class 2606 OID 31419)
-- Name: mmu_location_track mmu_location_track_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mmu_location_track
    ADD CONSTRAINT mmu_location_track_pkey PRIMARY KEY (track_id);


--
-- TOC entry 5418 (class 2606 OID 30623)
-- Name: mmu_route_stop mmu_route_stop_facility_id_stop_seq_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mmu_route_stop
    ADD CONSTRAINT mmu_route_stop_facility_id_stop_seq_key UNIQUE (facility_id, stop_seq);


--
-- TOC entry 5420 (class 2606 OID 30621)
-- Name: mmu_route_stop mmu_route_stop_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mmu_route_stop
    ADD CONSTRAINT mmu_route_stop_pkey PRIMARY KEY (route_stop_id);


--
-- TOC entry 5384 (class 2606 OID 30467)
-- Name: offer offer_offer_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_offer_code_key UNIQUE (offer_code);


--
-- TOC entry 5386 (class 2606 OID 30465)
-- Name: offer offer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_pkey PRIMARY KEY (offer_id);


--
-- TOC entry 5375 (class 2606 OID 30427)
-- Name: organization organization_org_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization
    ADD CONSTRAINT organization_org_code_key UNIQUE (org_code);


--
-- TOC entry 5377 (class 2606 OID 30429)
-- Name: organization organization_org_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization
    ADD CONSTRAINT organization_org_name_key UNIQUE (org_name);


--
-- TOC entry 5379 (class 2606 OID 30425)
-- Name: organization organization_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (org_id);


--
-- TOC entry 5566 (class 2606 OID 31480)
-- Name: patient_monthly_aggregate patient_monthly_aggregate_org_id_source_month_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient_monthly_aggregate
    ADD CONSTRAINT patient_monthly_aggregate_org_id_source_month_key UNIQUE (org_id, source, month);


--
-- TOC entry 5568 (class 2606 OID 31478)
-- Name: patient_monthly_aggregate patient_monthly_aggregate_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient_monthly_aggregate
    ADD CONSTRAINT patient_monthly_aggregate_pkey PRIMARY KEY (aggregate_id);


--
-- TOC entry 5487 (class 2606 OID 30920)
-- Name: patient patient_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient
    ADD CONSTRAINT patient_pkey PRIMARY KEY (patient_id);


--
-- TOC entry 5517 (class 2606 OID 31178)
-- Name: prescription_item prescription_item_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescription_item
    ADD CONSTRAINT prescription_item_pkey PRIMARY KEY (prescription_item_id);


--
-- TOC entry 5529 (class 2606 OID 31232)
-- Name: previous_prescription previous_prescription_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.previous_prescription
    ADD CONSTRAINT previous_prescription_pkey PRIMARY KEY (previous_rx_id);


--
-- TOC entry 5472 (class 2606 OID 30879)
-- Name: referral_destination_master referral_destination_master_destination_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.referral_destination_master
    ADD CONSTRAINT referral_destination_master_destination_name_key UNIQUE (destination_name);


--
-- TOC entry 5474 (class 2606 OID 30877)
-- Name: referral_destination_master referral_destination_master_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.referral_destination_master
    ADD CONSTRAINT referral_destination_master_pkey PRIMARY KEY (destination_id);


--
-- TOC entry 5581 (class 2606 OID 57376)
-- Name: refresh_session refresh_session_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.refresh_session
    ADD CONSTRAINT refresh_session_pkey PRIMARY KEY (session_id);


--
-- TOC entry 5583 (class 2606 OID 57378)
-- Name: refresh_session refresh_session_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.refresh_session
    ADD CONSTRAINT refresh_session_token_hash_key UNIQUE (token_hash);


--
-- TOC entry 5558 (class 2606 OID 31392)
-- Name: requisition_line requisition_line_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition_line
    ADD CONSTRAINT requisition_line_pkey PRIMARY KEY (requisition_line_id);


--
-- TOC entry 5553 (class 2606 OID 31358)
-- Name: requisition requisition_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition
    ADD CONSTRAINT requisition_pkey PRIMARY KEY (requisition_id);


--
-- TOC entry 5434 (class 2606 OID 30694)
-- Name: roster roster_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roster
    ADD CONSTRAINT roster_pkey PRIMARY KEY (roster_id);


--
-- TOC entry 5431 (class 2606 OID 30669)
-- Name: staff_assignment staff_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff_assignment
    ADD CONSTRAINT staff_assignment_pkey PRIMARY KEY (assignment_id);


--
-- TOC entry 5427 (class 2606 OID 30645)
-- Name: staff staff_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (staff_id);


--
-- TOC entry 5388 (class 2606 OID 30480)
-- Name: state_ref state_ref_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.state_ref
    ADD CONSTRAINT state_ref_pkey PRIMARY KEY (state_id);


--
-- TOC entry 5390 (class 2606 OID 30482)
-- Name: state_ref state_ref_state_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.state_ref
    ADD CONSTRAINT state_ref_state_code_key UNIQUE (state_code);


--
-- TOC entry 5392 (class 2606 OID 30484)
-- Name: state_ref state_ref_state_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.state_ref
    ADD CONSTRAINT state_ref_state_name_key UNIQUE (state_name);


--
-- TOC entry 5381 (class 2606 OID 30446)
-- Name: subscription_tier subscription_tier_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subscription_tier
    ADD CONSTRAINT subscription_tier_pkey PRIMARY KEY (tier_id);


--
-- TOC entry 5446 (class 2606 OID 30785)
-- Name: symptom_master symptom_master_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.symptom_master
    ADD CONSTRAINT symptom_master_pkey PRIMARY KEY (symptom_id);


--
-- TOC entry 5448 (class 2606 OID 30787)
-- Name: symptom_master symptom_master_symptom_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.symptom_master
    ADD CONSTRAINT symptom_master_symptom_name_key UNIQUE (symptom_name);


--
-- TOC entry 5590 (class 2606 OID 57438)
-- Name: sync_action sync_action_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sync_action
    ADD CONSTRAINT sync_action_pkey PRIMARY KEY (sync_action_id);


--
-- TOC entry 5592 (class 2606 OID 57440)
-- Name: sync_action sync_action_user_id_client_action_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sync_action
    ADD CONSTRAINT sync_action_user_id_client_action_id_key UNIQUE (user_id, client_action_id);


--
-- TOC entry 5576 (class 2606 OID 32828)
-- Name: user_zone user_zone_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_zone
    ADD CONSTRAINT user_zone_pkey PRIMARY KEY (user_zone_id);


--
-- TOC entry 5405 (class 2606 OID 30539)
-- Name: village_ref village_ref_block_id_village_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.village_ref
    ADD CONSTRAINT village_ref_block_id_village_name_key UNIQUE (block_id, village_name);


--
-- TOC entry 5407 (class 2606 OID 30537)
-- Name: village_ref village_ref_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.village_ref
    ADD CONSTRAINT village_ref_pkey PRIMARY KEY (village_id);


--
-- TOC entry 5564 (class 1259 OID 31486)
-- Name: agg_month_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX agg_month_idx ON public.patient_monthly_aggregate USING btree (month);


--
-- TOC entry 5508 (class 1259 OID 32789)
-- Name: alt_unpaid_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX alt_unpaid_idx ON public.appointment_lab_test USING btree (appointment_id) WHERE ((paid = false) AND (deleted_at IS NULL));


--
-- TOC entry 5439 (class 1259 OID 31551)
-- Name: app_user_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX app_user_active_idx ON public.app_user USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5440 (class 1259 OID 31667)
-- Name: app_user_legacy_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX app_user_legacy_uniq ON public.app_user USING btree (legacy_source, legacy_id) WHERE (legacy_id IS NOT NULL);


--
-- TOC entry 5443 (class 1259 OID 31658)
-- Name: app_user_username_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX app_user_username_uniq ON public.app_user USING btree (username) WHERE (deleted_at IS NULL);


--
-- TOC entry 5489 (class 1259 OID 31565)
-- Name: appointment_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appointment_active_idx ON public.appointment USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5520 (class 1259 OID 31602)
-- Name: appointment_attachment_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appointment_attachment_active_idx ON public.appointment_attachment USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5521 (class 1259 OID 31672)
-- Name: appointment_attachment_legacy_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX appointment_attachment_legacy_uniq ON public.appointment_attachment USING btree (legacy_source, legacy_id) WHERE (legacy_id IS NOT NULL);


--
-- TOC entry 5504 (class 1259 OID 31581)
-- Name: appointment_diagnosis_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appointment_diagnosis_active_idx ON public.appointment_diagnosis USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5509 (class 1259 OID 31588)
-- Name: appointment_lab_test_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appointment_lab_test_active_idx ON public.appointment_lab_test USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5510 (class 1259 OID 31670)
-- Name: appointment_lab_test_legacy_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX appointment_lab_test_legacy_uniq ON public.appointment_lab_test USING btree (legacy_source, legacy_id) WHERE (legacy_id IS NOT NULL);


--
-- TOC entry 5490 (class 1259 OID 31669)
-- Name: appointment_legacy_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX appointment_legacy_uniq ON public.appointment USING btree (legacy_source, legacy_id) WHERE (legacy_id IS NOT NULL);


--
-- TOC entry 5501 (class 1259 OID 31574)
-- Name: appointment_symptom_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appointment_symptom_active_idx ON public.appointment_symptom USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5493 (class 1259 OID 31084)
-- Name: appt_doctor_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appt_doctor_idx ON public.appointment USING btree (attended_by);


--
-- TOC entry 5507 (class 1259 OID 31124)
-- Name: appt_dx_disease_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appt_dx_disease_idx ON public.appointment_diagnosis USING btree (disease_id);


--
-- TOC entry 5494 (class 1259 OID 31080)
-- Name: appt_facility_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appt_facility_idx ON public.appointment USING btree (facility_id, appointment_date DESC);


--
-- TOC entry 5495 (class 1259 OID 31082)
-- Name: appt_month_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appt_month_idx ON public.appointment USING btree (month);


--
-- TOC entry 5496 (class 1259 OID 31661)
-- Name: appt_one_open_per_day; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX appt_one_open_per_day ON public.appointment USING btree (patient_id, appointment_date) WHERE ((status = ANY (ARRAY['registered'::public.appointment_status_t, 'with_doctor'::public.appointment_status_t, 'with_lab'::public.appointment_status_t, 'with_pharma'::public.appointment_status_t])) AND (deleted_at IS NULL));


--
-- TOC entry 5497 (class 1259 OID 31083)
-- Name: appt_org_source_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appt_org_source_idx ON public.appointment USING btree (org_id, source, month);


--
-- TOC entry 5498 (class 1259 OID 31079)
-- Name: appt_patient_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appt_patient_idx ON public.appointment USING btree (patient_id);


--
-- TOC entry 5499 (class 1259 OID 31081)
-- Name: appt_status_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX appt_status_date_idx ON public.appointment USING btree (status, appointment_date DESC);


--
-- TOC entry 5428 (class 1259 OID 30680)
-- Name: assignment_staff_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX assignment_staff_idx ON public.staff_assignment USING btree (staff_id, from_date DESC);


--
-- TOC entry 5535 (class 1259 OID 31310)
-- Name: att_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX att_date_idx ON public.attendance USING btree (attendance_date DESC);


--
-- TOC entry 5536 (class 1259 OID 31311)
-- Name: att_user_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX att_user_idx ON public.attendance USING btree (user_id, attendance_date DESC);


--
-- TOC entry 5524 (class 1259 OID 31213)
-- Name: attachment_appointment_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX attachment_appointment_idx ON public.appointment_attachment USING btree (appointment_id);


--
-- TOC entry 5537 (class 1259 OID 31623)
-- Name: attendance_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX attendance_active_idx ON public.attendance USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5538 (class 1259 OID 31675)
-- Name: attendance_legacy_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX attendance_legacy_uniq ON public.attendance USING btree (legacy_source, legacy_id) WHERE (legacy_id IS NOT NULL);


--
-- TOC entry 5541 (class 1259 OID 31660)
-- Name: attendance_user_date_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX attendance_user_date_uniq ON public.attendance USING btree (user_id, attendance_date) WHERE (deleted_at IS NULL);


--
-- TOC entry 5398 (class 1259 OID 30546)
-- Name: block_district_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX block_district_idx ON public.block_ref USING btree (district_id);


--
-- TOC entry 5530 (class 1259 OID 31616)
-- Name: camp_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX camp_active_idx ON public.camp USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5531 (class 1259 OID 31273)
-- Name: camp_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX camp_date_idx ON public.camp USING btree (camp_date DESC);


--
-- TOC entry 5532 (class 1259 OID 31674)
-- Name: camp_legacy_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX camp_legacy_uniq ON public.camp USING btree (legacy_source, legacy_id) WHERE (legacy_id IS NOT NULL);


--
-- TOC entry 5542 (class 1259 OID 31343)
-- Name: device_status_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX device_status_date_idx ON public.device_status_history USING btree (status_date DESC);


--
-- TOC entry 5543 (class 1259 OID 31632)
-- Name: device_status_history_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX device_status_history_active_idx ON public.device_status_history USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5449 (class 1259 OID 30804)
-- Name: disease_icd_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX disease_icd_idx ON public.disease_master USING btree (icd11_code);


--
-- TOC entry 5454 (class 1259 OID 30805)
-- Name: disease_synonyms_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX disease_synonyms_idx ON public.disease_master USING gin (synonyms);


--
-- TOC entry 5397 (class 1259 OID 30545)
-- Name: district_state_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX district_state_idx ON public.district_ref USING btree (state_id);


--
-- TOC entry 5408 (class 1259 OID 31507)
-- Name: facility_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX facility_active_idx ON public.facility USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5409 (class 1259 OID 31659)
-- Name: facility_code_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX facility_code_uniq ON public.facility USING btree (facility_code) WHERE (deleted_at IS NULL);


--
-- TOC entry 5410 (class 1259 OID 30603)
-- Name: facility_geo_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX facility_geo_idx ON public.facility USING btree (state_id, district_id);


--
-- TOC entry 5411 (class 1259 OID 31665)
-- Name: facility_legacy_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX facility_legacy_uniq ON public.facility USING btree (legacy_source, legacy_id) WHERE (legacy_id IS NOT NULL);


--
-- TOC entry 5412 (class 1259 OID 30601)
-- Name: facility_org_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX facility_org_idx ON public.facility USING btree (org_id);


--
-- TOC entry 5415 (class 1259 OID 30602)
-- Name: facility_type_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX facility_type_idx ON public.facility USING btree (facility_type);


--
-- TOC entry 5500 (class 1259 OID 57451)
-- Name: ix_appointment_parent; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_appointment_parent ON public.appointment USING btree (parent_appointment_id) WHERE (parent_appointment_id IS NOT NULL);


--
-- TOC entry 5588 (class 1259 OID 57418)
-- Name: ix_camp_anchor_facility; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_camp_anchor_facility ON public.camp_anchor USING btree (facility_id) WHERE (deleted_at IS NULL);


--
-- TOC entry 5579 (class 1259 OID 57384)
-- Name: ix_refresh_session_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_refresh_session_user ON public.refresh_session USING btree (user_id) WHERE (revoked_at IS NULL);


--
-- TOC entry 5513 (class 1259 OID 31150)
-- Name: lab_appointment_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX lab_appointment_idx ON public.appointment_lab_test USING btree (appointment_id);


--
-- TOC entry 5435 (class 1259 OID 31544)
-- Name: leave_record_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX leave_record_active_idx ON public.leave_record USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5438 (class 1259 OID 30733)
-- Name: leave_staff_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX leave_staff_idx ON public.leave_record USING btree (staff_id, from_date DESC);


--
-- TOC entry 5416 (class 1259 OID 31514)
-- Name: mmu_route_stop_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX mmu_route_stop_active_idx ON public.mmu_route_stop USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5382 (class 1259 OID 31655)
-- Name: offer_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX offer_active_idx ON public.offer USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5372 (class 1259 OID 31500)
-- Name: organization_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX organization_active_idx ON public.organization USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5373 (class 1259 OID 31664)
-- Name: organization_legacy_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX organization_legacy_uniq ON public.organization USING btree (legacy_source, legacy_id) WHERE (legacy_id IS NOT NULL);


--
-- TOC entry 5479 (class 1259 OID 31656)
-- Name: patient_aadhar_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX patient_aadhar_uniq ON public.patient USING btree (aadhar_number) WHERE ((aadhar_number IS NOT NULL) AND (deleted_at IS NULL));


--
-- TOC entry 5480 (class 1259 OID 31558)
-- Name: patient_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX patient_active_idx ON public.patient USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5481 (class 1259 OID 30964)
-- Name: patient_contact_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX patient_contact_idx ON public.patient USING btree (contact_number);


--
-- TOC entry 5482 (class 1259 OID 30966)
-- Name: patient_geo_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX patient_geo_idx ON public.patient USING btree (state_id, district_id, block_id, village_id);


--
-- TOC entry 5483 (class 1259 OID 31668)
-- Name: patient_legacy_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX patient_legacy_uniq ON public.patient USING btree (legacy_source, legacy_id) WHERE (legacy_id IS NOT NULL);


--
-- TOC entry 5484 (class 1259 OID 30965)
-- Name: patient_name_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX patient_name_idx ON public.patient USING btree (lower(patient_name));


--
-- TOC entry 5485 (class 1259 OID 30967)
-- Name: patient_org_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX patient_org_idx ON public.patient USING btree (org_id);


--
-- TOC entry 5488 (class 1259 OID 31657)
-- Name: patient_unique_code_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX patient_unique_code_uniq ON public.patient USING btree (unique_code) WHERE ((unique_code IS NOT NULL) AND (deleted_at IS NULL));


--
-- TOC entry 5514 (class 1259 OID 31595)
-- Name: prescription_item_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX prescription_item_active_idx ON public.prescription_item USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5515 (class 1259 OID 31671)
-- Name: prescription_item_legacy_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX prescription_item_legacy_uniq ON public.prescription_item USING btree (legacy_source, legacy_id) WHERE (legacy_id IS NOT NULL);


--
-- TOC entry 5525 (class 1259 OID 31243)
-- Name: prev_rx_patient_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX prev_rx_patient_idx ON public.previous_prescription USING btree (patient_id);


--
-- TOC entry 5526 (class 1259 OID 31609)
-- Name: previous_prescription_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX previous_prescription_active_idx ON public.previous_prescription USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5527 (class 1259 OID 31673)
-- Name: previous_prescription_legacy_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX previous_prescription_legacy_uniq ON public.previous_prescription USING btree (legacy_source, legacy_id) WHERE (legacy_id IS NOT NULL);


--
-- TOC entry 5571 (class 1259 OID 31696)
-- Name: quarantine_payload_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX quarantine_payload_idx ON public.migration_quarantine USING gin (payload);


--
-- TOC entry 5572 (class 1259 OID 31695)
-- Name: quarantine_target_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX quarantine_target_idx ON public.migration_quarantine USING btree (target_table, resolved);


--
-- TOC entry 5548 (class 1259 OID 31404)
-- Name: req_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX req_date_idx ON public.requisition USING btree (requisition_date DESC);


--
-- TOC entry 5554 (class 1259 OID 31403)
-- Name: req_line_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX req_line_idx ON public.requisition_line USING btree (requisition_id);


--
-- TOC entry 5549 (class 1259 OID 31641)
-- Name: requisition_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX requisition_active_idx ON public.requisition USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5550 (class 1259 OID 31676)
-- Name: requisition_legacy_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX requisition_legacy_uniq ON public.requisition USING btree (legacy_source, legacy_id) WHERE (legacy_id IS NOT NULL);


--
-- TOC entry 5555 (class 1259 OID 31648)
-- Name: requisition_line_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX requisition_line_active_idx ON public.requisition_line USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5556 (class 1259 OID 31677)
-- Name: requisition_line_legacy_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX requisition_line_legacy_uniq ON public.requisition_line USING btree (legacy_source, legacy_id) WHERE (legacy_id IS NOT NULL);


--
-- TOC entry 5551 (class 1259 OID 32815)
-- Name: requisition_pending_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX requisition_pending_idx ON public.requisition USING btree (facility_id, requisition_date DESC) WHERE ((status = 'Requested'::public.requisition_status_t) AND (deleted_at IS NULL));


--
-- TOC entry 5432 (class 1259 OID 31537)
-- Name: roster_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX roster_active_idx ON public.roster USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5421 (class 1259 OID 30629)
-- Name: route_stop_facility_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX route_stop_facility_idx ON public.mmu_route_stop USING btree (facility_id, visit_date);


--
-- TOC entry 5518 (class 1259 OID 31189)
-- Name: rx_appointment_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX rx_appointment_idx ON public.prescription_item USING btree (appointment_id);


--
-- TOC entry 5519 (class 1259 OID 31190)
-- Name: rx_medicine_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX rx_medicine_idx ON public.prescription_item USING btree (medicine_id);


--
-- TOC entry 5422 (class 1259 OID 31521)
-- Name: staff_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX staff_active_idx ON public.staff USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5429 (class 1259 OID 31530)
-- Name: staff_assignment_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX staff_assignment_active_idx ON public.staff_assignment USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5423 (class 1259 OID 30657)
-- Name: staff_facility_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX staff_facility_idx ON public.staff USING btree (facility_id);


--
-- TOC entry 5424 (class 1259 OID 31666)
-- Name: staff_legacy_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX staff_legacy_uniq ON public.staff USING btree (legacy_source, legacy_id) WHERE (legacy_id IS NOT NULL);


--
-- TOC entry 5425 (class 1259 OID 30656)
-- Name: staff_org_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX staff_org_idx ON public.staff USING btree (org_id);


--
-- TOC entry 5561 (class 1259 OID 31430)
-- Name: track_facility_time_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX track_facility_time_idx ON public.mmu_location_track USING btree (facility_id, recorded_at DESC);


--
-- TOC entry 5444 (class 1259 OID 30769)
-- Name: user_org_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_org_idx ON public.app_user USING btree (org_id) WHERE is_active;


--
-- TOC entry 5577 (class 1259 OID 32849)
-- Name: user_zone_uniq; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX user_zone_uniq ON public.user_zone USING btree (user_id, state_id, COALESCE(district_id, ('-1'::integer)::bigint)) WHERE (deleted_at IS NULL);


--
-- TOC entry 5578 (class 1259 OID 32850)
-- Name: user_zone_user_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_zone_user_idx ON public.user_zone USING btree (user_id) WHERE (deleted_at IS NULL);


--
-- TOC entry 5403 (class 1259 OID 30547)
-- Name: village_block_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX village_block_idx ON public.village_ref USING btree (block_id);


--
-- TOC entry 5697 (class 2620 OID 31491)
-- Name: appointment appointment_upd; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER appointment_upd BEFORE UPDATE ON public.appointment FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 5698 (class 2620 OID 31492)
-- Name: attendance attendance_upd; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER attendance_upd BEFORE UPDATE ON public.attendance FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 5695 (class 2620 OID 31489)
-- Name: facility facility_upd; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER facility_upd BEFORE UPDATE ON public.facility FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 5694 (class 2620 OID 31488)
-- Name: organization organization_upd; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER organization_upd BEFORE UPDATE ON public.organization FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 5696 (class 2620 OID 31490)
-- Name: patient patient_upd; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER patient_upd BEFORE UPDATE ON public.patient FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 5699 (class 2620 OID 31493)
-- Name: requisition requisition_upd; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER requisition_upd BEFORE UPDATE ON public.requisition FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- TOC entry 5618 (class 2606 OID 31545)
-- Name: app_user app_user_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5619 (class 2606 OID 30759)
-- Name: app_user app_user_facility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(facility_id);


--
-- TOC entry 5620 (class 2606 OID 30754)
-- Name: app_user app_user_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organization(org_id);


--
-- TOC entry 5621 (class 2606 OID 30764)
-- Name: app_user app_user_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(staff_id);


--
-- TOC entry 5631 (class 2606 OID 31064)
-- Name: appointment appointment_assigned_doctor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_assigned_doctor_id_fkey FOREIGN KEY (assigned_doctor_id) REFERENCES public.staff(staff_id);


--
-- TOC entry 5658 (class 2606 OID 31208)
-- Name: appointment_attachment appointment_attachment_appointment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_attachment
    ADD CONSTRAINT appointment_attachment_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES public.appointment(appointment_id) ON DELETE RESTRICT;


--
-- TOC entry 5659 (class 2606 OID 31596)
-- Name: appointment_attachment appointment_attachment_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_attachment
    ADD CONSTRAINT appointment_attachment_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5632 (class 2606 OID 31049)
-- Name: appointment appointment_attended_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_attended_by_fkey FOREIGN KEY (attended_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5633 (class 2606 OID 31074)
-- Name: appointment appointment_counselling_topic_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_counselling_topic_id_fkey FOREIGN KEY (counselling_topic_id) REFERENCES public.counselling_topic_master(topic_id);


--
-- TOC entry 5634 (class 2606 OID 31559)
-- Name: appointment appointment_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5648 (class 2606 OID 31114)
-- Name: appointment_diagnosis appointment_diagnosis_appointment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_diagnosis
    ADD CONSTRAINT appointment_diagnosis_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES public.appointment(appointment_id) ON DELETE RESTRICT;


--
-- TOC entry 5649 (class 2606 OID 31575)
-- Name: appointment_diagnosis appointment_diagnosis_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_diagnosis
    ADD CONSTRAINT appointment_diagnosis_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5650 (class 2606 OID 31119)
-- Name: appointment_diagnosis appointment_diagnosis_disease_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_diagnosis
    ADD CONSTRAINT appointment_diagnosis_disease_id_fkey FOREIGN KEY (disease_id) REFERENCES public.disease_master(disease_id);


--
-- TOC entry 5635 (class 2606 OID 31059)
-- Name: appointment appointment_dispensed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_dispensed_by_fkey FOREIGN KEY (dispensed_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5636 (class 2606 OID 31034)
-- Name: appointment appointment_facility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(facility_id);


--
-- TOC entry 5637 (class 2606 OID 32792)
-- Name: appointment appointment_fee_collected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_fee_collected_by_fkey FOREIGN KEY (fee_collected_by) REFERENCES public.app_user(user_id) ON DELETE RESTRICT;


--
-- TOC entry 5638 (class 2606 OID 31054)
-- Name: appointment appointment_lab_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_lab_by_fkey FOREIGN KEY (lab_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5651 (class 2606 OID 31140)
-- Name: appointment_lab_test appointment_lab_test_appointment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_lab_test
    ADD CONSTRAINT appointment_lab_test_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES public.appointment(appointment_id) ON DELETE RESTRICT;


--
-- TOC entry 5652 (class 2606 OID 31582)
-- Name: appointment_lab_test appointment_lab_test_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_lab_test
    ADD CONSTRAINT appointment_lab_test_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5653 (class 2606 OID 31145)
-- Name: appointment_lab_test appointment_lab_test_lab_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_lab_test
    ADD CONSTRAINT appointment_lab_test_lab_test_id_fkey FOREIGN KEY (lab_test_id) REFERENCES public.lab_test_master(lab_test_id);


--
-- TOC entry 5654 (class 2606 OID 32783)
-- Name: appointment_lab_test appointment_lab_test_paid_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_lab_test
    ADD CONSTRAINT appointment_lab_test_paid_by_fkey FOREIGN KEY (paid_by) REFERENCES public.app_user(user_id) ON DELETE RESTRICT;


--
-- TOC entry 5639 (class 2606 OID 31039)
-- Name: appointment appointment_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organization(org_id);


--
-- TOC entry 5640 (class 2606 OID 57446)
-- Name: appointment appointment_parent_appointment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_parent_appointment_id_fkey FOREIGN KEY (parent_appointment_id) REFERENCES public.appointment(appointment_id);


--
-- TOC entry 5641 (class 2606 OID 31029)
-- Name: appointment appointment_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patient(patient_id) ON DELETE RESTRICT;


--
-- TOC entry 5642 (class 2606 OID 31069)
-- Name: appointment appointment_referral_destination_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_referral_destination_id_fkey FOREIGN KEY (referral_destination_id) REFERENCES public.referral_destination_master(destination_id);


--
-- TOC entry 5643 (class 2606 OID 31044)
-- Name: appointment appointment_registered_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_registered_by_fkey FOREIGN KEY (registered_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5645 (class 2606 OID 31093)
-- Name: appointment_symptom appointment_symptom_appointment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_symptom
    ADD CONSTRAINT appointment_symptom_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES public.appointment(appointment_id) ON DELETE RESTRICT;


--
-- TOC entry 5646 (class 2606 OID 31566)
-- Name: appointment_symptom appointment_symptom_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_symptom
    ADD CONSTRAINT appointment_symptom_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5647 (class 2606 OID 31098)
-- Name: appointment_symptom appointment_symptom_symptom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment_symptom
    ADD CONSTRAINT appointment_symptom_symptom_id_fkey FOREIGN KEY (symptom_id) REFERENCES public.symptom_master(symptom_id);


--
-- TOC entry 5644 (class 2606 OID 32797)
-- Name: appointment appointment_test_paid_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_test_paid_by_fkey FOREIGN KEY (test_paid_by) REFERENCES public.app_user(user_id) ON DELETE RESTRICT;


--
-- TOC entry 5667 (class 2606 OID 57452)
-- Name: attendance attendance_camp_anchor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_camp_anchor_id_fkey FOREIGN KEY (camp_anchor_id) REFERENCES public.camp_anchor(camp_anchor_id);


--
-- TOC entry 5668 (class 2606 OID 31617)
-- Name: attendance attendance_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5669 (class 2606 OID 31305)
-- Name: attendance attendance_facility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(facility_id);


--
-- TOC entry 5670 (class 2606 OID 31300)
-- Name: attendance attendance_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(user_id);


--
-- TOC entry 5596 (class 2606 OID 30520)
-- Name: block_ref block_ref_district_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.block_ref
    ADD CONSTRAINT block_ref_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.district_ref(district_id);


--
-- TOC entry 5691 (class 2606 OID 57413)
-- Name: camp_anchor camp_anchor_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camp_anchor
    ADD CONSTRAINT camp_anchor_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5692 (class 2606 OID 57408)
-- Name: camp_anchor camp_anchor_facility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camp_anchor
    ADD CONSTRAINT camp_anchor_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(facility_id);


--
-- TOC entry 5663 (class 2606 OID 31268)
-- Name: camp camp_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camp
    ADD CONSTRAINT camp_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5664 (class 2606 OID 31610)
-- Name: camp camp_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camp
    ADD CONSTRAINT camp_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5665 (class 2606 OID 31258)
-- Name: camp camp_facility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camp
    ADD CONSTRAINT camp_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(facility_id);


--
-- TOC entry 5666 (class 2606 OID 31263)
-- Name: camp camp_village_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.camp
    ADD CONSTRAINT camp_village_id_fkey FOREIGN KEY (village_id) REFERENCES public.village_ref(village_id);


--
-- TOC entry 5671 (class 2606 OID 31624)
-- Name: device_status_history device_status_history_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_status_history
    ADD CONSTRAINT device_status_history_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5672 (class 2606 OID 31328)
-- Name: device_status_history device_status_history_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_status_history
    ADD CONSTRAINT device_status_history_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.device_master(device_id);


--
-- TOC entry 5673 (class 2606 OID 31333)
-- Name: device_status_history device_status_history_facility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_status_history
    ADD CONSTRAINT device_status_history_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(facility_id);


--
-- TOC entry 5674 (class 2606 OID 31338)
-- Name: device_status_history device_status_history_reported_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_status_history
    ADD CONSTRAINT device_status_history_reported_by_fkey FOREIGN KEY (reported_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5595 (class 2606 OID 30500)
-- Name: district_ref district_ref_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.district_ref
    ADD CONSTRAINT district_ref_state_id_fkey FOREIGN KEY (state_id) REFERENCES public.state_ref(state_id);


--
-- TOC entry 5598 (class 2606 OID 30591)
-- Name: facility facility_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facility
    ADD CONSTRAINT facility_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.block_ref(block_id);


--
-- TOC entry 5599 (class 2606 OID 31501)
-- Name: facility facility_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facility
    ADD CONSTRAINT facility_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5600 (class 2606 OID 30586)
-- Name: facility facility_district_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facility
    ADD CONSTRAINT facility_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.district_ref(district_id);


--
-- TOC entry 5601 (class 2606 OID 30576)
-- Name: facility facility_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facility
    ADD CONSTRAINT facility_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organization(org_id);


--
-- TOC entry 5602 (class 2606 OID 30581)
-- Name: facility facility_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facility
    ADD CONSTRAINT facility_state_id_fkey FOREIGN KEY (state_id) REFERENCES public.state_ref(state_id);


--
-- TOC entry 5603 (class 2606 OID 30596)
-- Name: facility facility_tier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facility
    ADD CONSTRAINT facility_tier_id_fkey FOREIGN KEY (tier_id) REFERENCES public.subscription_tier(tier_id);


--
-- TOC entry 5615 (class 2606 OID 31538)
-- Name: leave_record leave_record_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.leave_record
    ADD CONSTRAINT leave_record_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5616 (class 2606 OID 30728)
-- Name: leave_record leave_record_replacement_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.leave_record
    ADD CONSTRAINT leave_record_replacement_staff_id_fkey FOREIGN KEY (replacement_staff_id) REFERENCES public.staff(staff_id);


--
-- TOC entry 5617 (class 2606 OID 30723)
-- Name: leave_record leave_record_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.leave_record
    ADD CONSTRAINT leave_record_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(staff_id);


--
-- TOC entry 5684 (class 2606 OID 31442)
-- Name: mmu_current_position mmu_current_position_facility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mmu_current_position
    ADD CONSTRAINT mmu_current_position_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(facility_id) ON DELETE RESTRICT;


--
-- TOC entry 5682 (class 2606 OID 31420)
-- Name: mmu_location_track mmu_location_track_facility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mmu_location_track
    ADD CONSTRAINT mmu_location_track_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(facility_id);


--
-- TOC entry 5683 (class 2606 OID 31425)
-- Name: mmu_location_track mmu_location_track_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mmu_location_track
    ADD CONSTRAINT mmu_location_track_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(user_id);


--
-- TOC entry 5604 (class 2606 OID 31508)
-- Name: mmu_route_stop mmu_route_stop_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mmu_route_stop
    ADD CONSTRAINT mmu_route_stop_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5605 (class 2606 OID 30624)
-- Name: mmu_route_stop mmu_route_stop_facility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mmu_route_stop
    ADD CONSTRAINT mmu_route_stop_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(facility_id) ON DELETE RESTRICT;


--
-- TOC entry 5594 (class 2606 OID 31649)
-- Name: offer offer_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5593 (class 2606 OID 31494)
-- Name: organization organization_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organization
    ADD CONSTRAINT organization_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5622 (class 2606 OID 30953)
-- Name: patient patient_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient
    ADD CONSTRAINT patient_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.block_ref(block_id);


--
-- TOC entry 5623 (class 2606 OID 30938)
-- Name: patient patient_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient
    ADD CONSTRAINT patient_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.category_master(category_id);


--
-- TOC entry 5624 (class 2606 OID 31552)
-- Name: patient patient_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient
    ADD CONSTRAINT patient_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5625 (class 2606 OID 30948)
-- Name: patient patient_district_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient
    ADD CONSTRAINT patient_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.district_ref(district_id);


--
-- TOC entry 5626 (class 2606 OID 30928)
-- Name: patient patient_facility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient
    ADD CONSTRAINT patient_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(facility_id);


--
-- TOC entry 5685 (class 2606 OID 31481)
-- Name: patient_monthly_aggregate patient_monthly_aggregate_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient_monthly_aggregate
    ADD CONSTRAINT patient_monthly_aggregate_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organization(org_id);


--
-- TOC entry 5627 (class 2606 OID 30923)
-- Name: patient patient_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient
    ADD CONSTRAINT patient_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organization(org_id);


--
-- TOC entry 5628 (class 2606 OID 30933)
-- Name: patient patient_registered_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient
    ADD CONSTRAINT patient_registered_by_fkey FOREIGN KEY (registered_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5629 (class 2606 OID 30943)
-- Name: patient patient_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient
    ADD CONSTRAINT patient_state_id_fkey FOREIGN KEY (state_id) REFERENCES public.state_ref(state_id);


--
-- TOC entry 5630 (class 2606 OID 30958)
-- Name: patient patient_village_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient
    ADD CONSTRAINT patient_village_id_fkey FOREIGN KEY (village_id) REFERENCES public.village_ref(village_id);


--
-- TOC entry 5655 (class 2606 OID 31179)
-- Name: prescription_item prescription_item_appointment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescription_item
    ADD CONSTRAINT prescription_item_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES public.appointment(appointment_id) ON DELETE RESTRICT;


--
-- TOC entry 5656 (class 2606 OID 31589)
-- Name: prescription_item prescription_item_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescription_item
    ADD CONSTRAINT prescription_item_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5657 (class 2606 OID 31184)
-- Name: prescription_item prescription_item_medicine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescription_item
    ADD CONSTRAINT prescription_item_medicine_id_fkey FOREIGN KEY (medicine_id) REFERENCES public.medicine_master(medicine_id);


--
-- TOC entry 5660 (class 2606 OID 31238)
-- Name: previous_prescription previous_prescription_appointment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.previous_prescription
    ADD CONSTRAINT previous_prescription_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES public.appointment(appointment_id) ON DELETE RESTRICT;


--
-- TOC entry 5661 (class 2606 OID 31603)
-- Name: previous_prescription previous_prescription_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.previous_prescription
    ADD CONSTRAINT previous_prescription_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5662 (class 2606 OID 31233)
-- Name: previous_prescription previous_prescription_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.previous_prescription
    ADD CONSTRAINT previous_prescription_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patient(patient_id) ON DELETE RESTRICT;


--
-- TOC entry 5690 (class 2606 OID 57379)
-- Name: refresh_session refresh_session_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.refresh_session
    ADD CONSTRAINT refresh_session_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(user_id);


--
-- TOC entry 5675 (class 2606 OID 31633)
-- Name: requisition requisition_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition
    ADD CONSTRAINT requisition_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5676 (class 2606 OID 31359)
-- Name: requisition requisition_facility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition
    ADD CONSTRAINT requisition_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(facility_id);


--
-- TOC entry 5679 (class 2606 OID 31642)
-- Name: requisition_line requisition_line_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition_line
    ADD CONSTRAINT requisition_line_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5680 (class 2606 OID 31398)
-- Name: requisition_line requisition_line_medicine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition_line
    ADD CONSTRAINT requisition_line_medicine_id_fkey FOREIGN KEY (medicine_id) REFERENCES public.medicine_master(medicine_id);


--
-- TOC entry 5681 (class 2606 OID 31393)
-- Name: requisition_line requisition_line_requisition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition_line
    ADD CONSTRAINT requisition_line_requisition_id_fkey FOREIGN KEY (requisition_id) REFERENCES public.requisition(requisition_id) ON DELETE RESTRICT;


--
-- TOC entry 5677 (class 2606 OID 31364)
-- Name: requisition requisition_raised_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition
    ADD CONSTRAINT requisition_raised_by_fkey FOREIGN KEY (raised_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5678 (class 2606 OID 32804)
-- Name: requisition requisition_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition
    ADD CONSTRAINT requisition_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.app_user(user_id) ON DELETE RESTRICT;


--
-- TOC entry 5612 (class 2606 OID 31531)
-- Name: roster roster_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roster
    ADD CONSTRAINT roster_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5613 (class 2606 OID 30700)
-- Name: roster roster_facility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roster
    ADD CONSTRAINT roster_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(facility_id);


--
-- TOC entry 5614 (class 2606 OID 30695)
-- Name: roster roster_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roster
    ADD CONSTRAINT roster_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organization(org_id);


--
-- TOC entry 5609 (class 2606 OID 31522)
-- Name: staff_assignment staff_assignment_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff_assignment
    ADD CONSTRAINT staff_assignment_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5610 (class 2606 OID 30675)
-- Name: staff_assignment staff_assignment_facility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff_assignment
    ADD CONSTRAINT staff_assignment_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(facility_id);


--
-- TOC entry 5611 (class 2606 OID 30670)
-- Name: staff_assignment staff_assignment_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff_assignment
    ADD CONSTRAINT staff_assignment_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(staff_id) ON DELETE RESTRICT;


--
-- TOC entry 5606 (class 2606 OID 31515)
-- Name: staff staff_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id);


--
-- TOC entry 5607 (class 2606 OID 30651)
-- Name: staff staff_facility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(facility_id);


--
-- TOC entry 5608 (class 2606 OID 30646)
-- Name: staff staff_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organization(org_id);


--
-- TOC entry 5693 (class 2606 OID 57441)
-- Name: sync_action sync_action_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sync_action
    ADD CONSTRAINT sync_action_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(user_id);


--
-- TOC entry 5686 (class 2606 OID 32844)
-- Name: user_zone user_zone_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_zone
    ADD CONSTRAINT user_zone_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.app_user(user_id) ON DELETE RESTRICT;


--
-- TOC entry 5687 (class 2606 OID 32839)
-- Name: user_zone user_zone_district_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_zone
    ADD CONSTRAINT user_zone_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.district_ref(district_id) ON DELETE RESTRICT;


--
-- TOC entry 5688 (class 2606 OID 32834)
-- Name: user_zone user_zone_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_zone
    ADD CONSTRAINT user_zone_state_id_fkey FOREIGN KEY (state_id) REFERENCES public.state_ref(state_id) ON DELETE RESTRICT;


--
-- TOC entry 5689 (class 2606 OID 32829)
-- Name: user_zone user_zone_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_zone
    ADD CONSTRAINT user_zone_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(user_id) ON DELETE RESTRICT;


--
-- TOC entry 5597 (class 2606 OID 30540)
-- Name: village_ref village_ref_block_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.village_ref
    ADD CONSTRAINT village_ref_block_id_fkey FOREIGN KEY (block_id) REFERENCES public.block_ref(block_id);


--
-- TOC entry 5948 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


-- Completed on 2026-08-12 12:00:01

--
-- PostgreSQL database dump complete
--

\unrestrict rCiHejZ99aMwKgPtTFEu6TNJ7KcvrK4GhKndXbXiJEULG2gTXqXrInY1F3iUh5W

