-- LICENCE CREATIVE COMMONS - CC - BY - SA
-- =======================================
-- Cette oeuvre est mise à disposition sous licence Paternité – Partage dans les mêmes conditions
-- Pour voir une copie de cette licence, visitez http://creativecommons.org/licenses/by-sa/3.0/
-- ou écrivez à Creative Commons, 444 Castro Street, Suite 900, Mountain View, California, 94041, USA.
--
-- PostgreSQL database dump
--

-- Dumped from database version 9.0.4
-- Dumped by pg_dump version 9.0.4
-- Started on 2011-10-23 15:19:36 CEST

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- TOC entry 7 (class 2615 OID 17670)
-- Name: drh; Type: SCHEMA; Schema: -; Owner: formation_admin
--

CREATE SCHEMA drh;


ALTER SCHEMA drh OWNER TO formation_admin;

SET search_path = drh, pg_catalog;

--
-- TOC entry 334 (class 1247 OID 17957)
-- Dependencies: 335 7
-- Name: CODE10; Type: DOMAIN; Schema: drh; Owner: formation_admin
--

CREATE DOMAIN "CODE10" AS character varying(10)
	CONSTRAINT "CODE10_check_length" CHECK ((character_length((VALUE)::text) = 10));


ALTER DOMAIN drh."CODE10" OWNER TO formation_admin;

--
-- TOC entry 33 (class 1255 OID 17979)
-- Dependencies: 7 365
-- Name: handle_employe_code(); Type: FUNCTION; Schema: drh; Owner: formation_admin
--

CREATE FUNCTION handle_employe_code() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
    service_code  character varying;
  BEGIN
    RAISE NOTICE E'\n    Operation: %\n    Schema: %\n    Table: %',
        TG_OP,
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME;
    -- this function can be called from services in UPDATE (only if id or ser_id altered)
    -- or INSERT mode
    -- or from an updated ser_code on services
    -- deleted service will be handled by CASCADE SET ser_id=1 launching an employes update
    -- updated service id will be handled by CASCADE UPDATE launching an employes update
    IF (TG_OP = 'UPDATE') THEN
      IF (TG_TABLE_NAME = 'employes') THEN
          SELECT ser_code INTO service_code FROM drh.services WHERE ser_id=NEW.ser_id;
          NEW.emp_code := service_code || '-' || trim(to_char(NEW.per_id,'0000'));
          RETURN NEW;
      ELSIF (TG_TABLE_NAME = 'services') THEN
          service_code = NEW.ser_code;
          UPDATE drh.employes
            SET emp_code=service_code || '-' || trim(to_char(per_id,'0000'))
            WHERE ser_id=NEW.ser_id;
          RETURN NEW;
      END IF;
    ELSIF (TG_OP = 'INSERT') THEN
      IF (TG_TABLE_NAME = 'employes') THEN
          SELECT ser_code INTO service_code FROM drh.services WHERE ser_id=NEW.ser_id;
          NEW.emp_code := service_code || '-' || trim(to_char(NEW.per_id,'0000'));
          RETURN NEW;
      END IF;
    END IF;
    RETURN NULL;
  END;
$$;


ALTER FUNCTION drh.handle_employe_code() OWNER TO formation_admin;

SET search_path = public, pg_catalog;

--
-- TOC entry 20 (class 1255 OID 17816)
-- Dependencies: 8 365
-- Name: update_datemodif_column(); Type: FUNCTION; Schema: public; Owner: formation_admin
--

CREATE FUNCTION update_datemodif_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    NEW.date_modification = NOW();
    RETURN NEW;
  END;
$$;


ALTER FUNCTION public.update_datemodif_column() OWNER TO formation_admin;

SET search_path = drh, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 1571 (class 1259 OID 18006)
-- Dependencies: 1915 1916 7
-- Name: agences; Type: TABLE; Schema: drh; Owner: formation_admin; Tablespace:
--

CREATE TABLE agences (
    age_id integer NOT NULL,
    age_nom character varying(100),
    age_code character varying(3) DEFAULT 'COD'::character varying NOT NULL,
    age_points integer DEFAULT 0
)
WITH (fillfactor=100);


ALTER TABLE drh.agences OWNER TO formation_admin;

--
-- TOC entry 1967 (class 0 OID 0)
-- Dependencies: 1571
-- Name: TABLE agences; Type: COMMENT; Schema: drh; Owner: formation_admin
--

COMMENT ON TABLE agences IS 'Agences d''intérim';


--
-- TOC entry 1564 (class 1259 OID 17719)
-- Dependencies: 1875 1876 1877 1878 1879 1880 7
-- Name: personnel; Type: TABLE; Schema: drh; Owner: formation_admin; Tablespace:
--

CREATE TABLE personnel (
    per_id integer NOT NULL,
    per_nom character varying(100) DEFAULT 'inconnu'::character varying NOT NULL,
    per_prenom character varying(50) DEFAULT 'john'::character varying NOT NULL,
    date_creation timestamp without time zone DEFAULT now(),
    date_modification timestamp without time zone DEFAULT now(),
    per_actif boolean DEFAULT true NOT NULL,
    per_points integer DEFAULT 0
)
WITH (fillfactor=80);


ALTER TABLE drh.personnel OWNER TO formation_admin;

--
-- TOC entry 1566 (class 1259 OID 17743)
-- Dependencies: 1882 1883 1884 1885 1886 7
-- Name: services; Type: TABLE; Schema: drh; Owner: formation_admin; Tablespace:
--

CREATE TABLE services (
    ser_id integer NOT NULL,
    ser_nom character varying(100) DEFAULT 'inconnu'::character varying NOT NULL,
    ser_code character varying(5) NOT NULL,
    ser_parent integer DEFAULT 1 NOT NULL,
    date_creation timestamp with time zone DEFAULT now(),
    date_modification timestamp with time zone DEFAULT now(),
    ser_points integer DEFAULT 0
)
WITH (fillfactor=75);


ALTER TABLE drh.services OWNER TO formation_admin;

--
-- TOC entry 1563 (class 1259 OID 17717)
-- Dependencies: 1564 7
-- Name: employes_emp_id_seq; Type: SEQUENCE; Schema: drh; Owner: formation_admin
--

CREATE SEQUENCE employes_emp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE drh.employes_emp_id_seq OWNER TO formation_admin;

--
-- TOC entry 1971 (class 0 OID 0)
-- Dependencies: 1563
-- Name: employes_emp_id_seq; Type: SEQUENCE OWNED BY; Schema: drh; Owner: formation_admin
--

ALTER SEQUENCE employes_emp_id_seq OWNED BY personnel.per_id;


--
-- TOC entry 1972 (class 0 OID 0)
-- Dependencies: 1563
-- Name: employes_emp_id_seq; Type: SEQUENCE SET; Schema: drh; Owner: formation_admin
--

SELECT pg_catalog.setval('employes_emp_id_seq', 49, true);


--
-- TOC entry 1569 (class 1259 OID 17937)
-- Dependencies: 1898 1899 1900 1901 1902 1903 1904 1905 1906 1907 1908 1909 1910 1911 1912 1913 1564 7
-- Name: employes; Type: TABLE; Schema: drh; Owner: formation_admin; Tablespace:
--

CREATE TABLE employes (
    emp_code character varying(10),
    emp_naissance date,
    ser_id integer DEFAULT 1 NOT NULL,
    emp_date_entree date DEFAULT now() NOT NULL,
    emp_code_pays character varying(2) DEFAULT 'FR'::character varying,
    emp_salaire_annuel numeric(12,4) DEFAULT 0.0,
    CONSTRAINT employe_embauche_avant_naissance_impossible CHECK ((COALESCE((emp_date_entree)::timestamp with time zone, now()) >= COALESCE((emp_naissance)::timestamp with time zone, (emp_date_entree)::timestamp with time zone, now()))),
    CONSTRAINT employe_entree_avant_creation_societe_impossible CHECK (((emp_date_entree IS NULL) OR (emp_date_entree >= '2001-04-12'::date))),
    CONSTRAINT employe_entree_future_impossible CHECK (((emp_date_entree IS NULL) OR (emp_date_entree < now()))),
    CONSTRAINT employe_salaire_positif CHECK (((emp_salaire_annuel >= (0)::numeric) OR (emp_salaire_annuel IS NULL))),
    CONSTRAINT employes_date_naissance_future_impossible CHECK (((emp_naissance < now()) OR (emp_naissance IS NULL)))
)
INHERITS (personnel);


ALTER TABLE drh.employes OWNER TO formation_admin;

--
-- TOC entry 1567 (class 1259 OID 17915)
-- Dependencies: 1887 1888 1889 1890 1891 1892 1893 1895 1896 1897 1564 7
-- Name: interimaires; Type: TABLE; Schema: drh; Owner: formation_admin; Tablespace:
--

CREATE TABLE interimaires (
    age_id integer DEFAULT 1,
    int_nb_jours_annee integer DEFAULT 0 NOT NULL,
    int_id integer NOT NULL,
    int_nb_jours_total integer DEFAULT 0,
    int_salaire_quotidien numeric(12,4)
)
INHERITS (personnel);


ALTER TABLE drh.interimaires OWNER TO formation_admin;

--
-- TOC entry 1584 (class 1259 OID 18401)
-- Dependencies: 1681 7
-- Name: vue_tableau_personnel; Type: VIEW; Schema: drh; Owner: formation_admin
--

CREATE VIEW vue_tableau_personnel AS
    SELECT p.relname AS per_type, pers.per_actif, pers.per_id, pers.per_nom, pers.per_prenom, COALESCE(emp.emp_code, (((age.age_code)::text || btrim(to_char(inter.int_id, '0000'::text))))::character varying, 'X'::character varying) AS per_code, COALESCE(emp.emp_salaire_annuel, (inter.int_salaire_quotidien * (inter.int_nb_jours_annee)::numeric), 0.00) AS per_salaire_annuel_real, COALESCE(emp.emp_salaire_annuel, (inter.int_salaire_quotidien * (360)::numeric), 0.00) AS per_salaire_annuel, date_part('year'::text, age((emp.emp_naissance)::timestamp with time zone)) AS pers_age, COALESCE(age((emp.emp_date_entree)::timestamp with time zone), justify_days((((inter.int_nb_jours_total)::text || ' days'::text))::interval)) AS pers_anciennete, emp.ser_id, inter.age_id FROM ((((personnel pers JOIN pg_class p ON ((p.oid = pers.tableoid))) LEFT JOIN employes emp ON ((emp.per_id = pers.per_id))) LEFT JOIN interimaires inter ON ((inter.per_id = pers.per_id))) LEFT JOIN agences age ON ((inter.age_id = age.age_id))) ORDER BY pers.per_actif, pers.per_nom, pers.per_prenom;


ALTER TABLE drh.vue_tableau_personnel OWNER TO formation_admin;

--
-- TOC entry 1570 (class 1259 OID 18004)
-- Dependencies: 7 1571
-- Name: agences_age_id_seq; Type: SEQUENCE; Schema: drh; Owner: formation_admin
--

CREATE SEQUENCE agences_age_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE drh.agences_age_id_seq OWNER TO formation_admin;

--
-- TOC entry 1977 (class 0 OID 0)
-- Dependencies: 1570
-- Name: agences_age_id_seq; Type: SEQUENCE OWNED BY; Schema: drh; Owner: formation_admin
--

ALTER SEQUENCE agences_age_id_seq OWNED BY agences.age_id;


--
-- TOC entry 1978 (class 0 OID 0)
-- Dependencies: 1570
-- Name: agences_age_id_seq; Type: SEQUENCE SET; Schema: drh; Owner: formation_admin
--

SELECT pg_catalog.setval('agences_age_id_seq', 4, true);


--
-- TOC entry 1583 (class 1259 OID 18367)
-- Dependencies: 7
-- Name: employes_projet; Type: TABLE; Schema: drh; Owner: formation_admin; Tablespace:
--

CREATE TABLE employes_projet (
    pro_id integer NOT NULL,
    emp_id integer NOT NULL
)
WITH (fillfactor=50);


ALTER TABLE drh.employes_projet OWNER TO formation_admin;

--
-- TOC entry 1568 (class 1259 OID 17927)
-- Dependencies: 1567 7
-- Name: interimaires_int_id_seq; Type: SEQUENCE; Schema: drh; Owner: formation_admin
--

CREATE SEQUENCE interimaires_int_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE drh.interimaires_int_id_seq OWNER TO formation_admin;

--
-- TOC entry 1981 (class 0 OID 0)
-- Dependencies: 1568
-- Name: interimaires_int_id_seq; Type: SEQUENCE OWNED BY; Schema: drh; Owner: formation_admin
--

ALTER SEQUENCE interimaires_int_id_seq OWNED BY interimaires.int_id;


--
-- TOC entry 1982 (class 0 OID 0)
-- Dependencies: 1568
-- Name: interimaires_int_id_seq; Type: SEQUENCE SET; Schema: drh; Owner: formation_admin
--

SELECT pg_catalog.setval('interimaires_int_id_seq', 8, true);


--
-- TOC entry 1582 (class 1259 OID 18361)
-- Dependencies: 7
-- Name: projet; Type: TABLE; Schema: drh; Owner: formation_admin; Tablespace:
--

CREATE TABLE projet (
    pro_id integer NOT NULL,
    pro_nom character varying(50)
)
WITH (fillfactor=100);


ALTER TABLE drh.projet OWNER TO formation_admin;

--
-- TOC entry 1581 (class 1259 OID 18359)
-- Dependencies: 1582 7
-- Name: projet_pro_id_seq; Type: SEQUENCE; Schema: drh; Owner: formation_admin
--

CREATE SEQUENCE projet_pro_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE drh.projet_pro_id_seq OWNER TO formation_admin;

--
-- TOC entry 1984 (class 0 OID 0)
-- Dependencies: 1581
-- Name: projet_pro_id_seq; Type: SEQUENCE OWNED BY; Schema: drh; Owner: formation_admin
--

ALTER SEQUENCE projet_pro_id_seq OWNED BY projet.pro_id;


--
-- TOC entry 1985 (class 0 OID 0)
-- Dependencies: 1581
-- Name: projet_pro_id_seq; Type: SEQUENCE SET; Schema: drh; Owner: formation_admin
--

SELECT pg_catalog.setval('projet_pro_id_seq', 5, true);


--
-- TOC entry 1565 (class 1259 OID 17741)
-- Dependencies: 1566 7
-- Name: services_ser_id_seq; Type: SEQUENCE; Schema: drh; Owner: formation_admin
--

CREATE SEQUENCE services_ser_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE drh.services_ser_id_seq OWNER TO formation_admin;

--
-- TOC entry 1987 (class 0 OID 0)
-- Dependencies: 1565
-- Name: services_ser_id_seq; Type: SEQUENCE OWNED BY; Schema: drh; Owner: formation_admin
--

ALTER SEQUENCE services_ser_id_seq OWNED BY services.ser_id;


--
-- TOC entry 1988 (class 0 OID 0)
-- Dependencies: 1565
-- Name: services_ser_id_seq; Type: SEQUENCE SET; Schema: drh; Owner: formation_admin
--

SELECT pg_catalog.setval('services_ser_id_seq', 13, true);


--
-- TOC entry 1914 (class 2604 OID 18009)
-- Dependencies: 1570 1571 1571
-- Name: age_id; Type: DEFAULT; Schema: drh; Owner: formation_admin
--

ALTER TABLE agences ALTER COLUMN age_id SET DEFAULT nextval('agences_age_id_seq'::regclass);


--
-- TOC entry 1894 (class 2604 OID 17929)
-- Dependencies: 1568 1567
-- Name: int_id; Type: DEFAULT; Schema: drh; Owner: formation_admin
--

ALTER TABLE interimaires ALTER COLUMN int_id SET DEFAULT nextval('interimaires_int_id_seq'::regclass);


--
-- TOC entry 1874 (class 2604 OID 17722)
-- Dependencies: 1563 1564 1564
-- Name: per_id; Type: DEFAULT; Schema: drh; Owner: formation_admin
--

ALTER TABLE personnel ALTER COLUMN per_id SET DEFAULT nextval('employes_emp_id_seq'::regclass);


--
-- TOC entry 1917 (class 2604 OID 18364)
-- Dependencies: 1582 1581 1582
-- Name: pro_id; Type: DEFAULT; Schema: drh; Owner: formation_admin
--

ALTER TABLE projet ALTER COLUMN pro_id SET DEFAULT nextval('projet_pro_id_seq'::regclass);


--
-- TOC entry 1881 (class 2604 OID 17746)
-- Dependencies: 1566 1565 1566
-- Name: ser_id; Type: DEFAULT; Schema: drh; Owner: formation_admin
--

ALTER TABLE services ALTER COLUMN ser_id SET DEFAULT nextval('services_ser_id_seq'::regclass);


--
-- TOC entry 1957 (class 0 OID 18006)
-- Dependencies: 1571
-- Data for Name: agences; Type: TABLE DATA; Schema: drh; Owner: formation_admin
--

INSERT INTO agences (age_id, age_nom, age_code, age_points) VALUES (4, 'AGENCE NATIONALE D''INTERIM', 'ANI', 0);
INSERT INTO agences (age_id, age_nom, age_code, age_points) VALUES (2, 'TRAVAILLER PLUS', 'TR+', 1080);
INSERT INTO agences (age_id, age_nom, age_code, age_points) VALUES (3, 'GAGNER PLUS', 'GA+', 1390);
INSERT INTO agences (age_id, age_nom, age_code, age_points) VALUES (1, 'INTERIM & CO', 'INT', 830);


--
-- TOC entry 1956 (class 0 OID 17937)
-- Dependencies: 1569
-- Data for Name: employes; Type: TABLE DATA; Schema: drh; Owner: formation_admin
--

INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (35, 'Boszormenyi', 'Zoltan', '2011-10-22 12:18:43.075143', '2011-10-22 13:55:46.369912', '00PA3-0035', '1961-02-01', 10, true, '2005-06-12', 0, 'AU', 45258.7400);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (36, 'Cave-Ayland ', 'Marc', '2011-10-22 12:18:59.354926', '2011-10-22 13:55:54.96985', 'P0001-0036', '1963-05-05', 3, true, '2008-11-23', 0, 'UK', 31256.2500);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (38, 'Davis', 'Jeff', '2011-10-22 12:19:22.975192', '2011-10-22 13:56:07.146002', '0DR02-0038', '1973-05-29', 5, true, '2003-05-05', 0, 'US', 26584.1200);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (39, 'Deckelmann', 'Selena', '2011-10-22 12:19:43.460912', '2011-10-22 13:56:14.457902', 'D0001-0039', '1980-01-01', 4, true, '2003-05-05', 0, 'US', 25986.5200);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (40, 'Drake', 'Josua', '2011-10-22 12:19:57.949743', '2011-10-22 13:56:19.089978', '0QA03-0040', '1982-09-06', 12, true, '2003-05-05', 0, 'US', 29458.5200);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (41, 'Dunstan', 'Andrew', '2011-10-22 12:20:15.405007', '2011-10-22 13:56:23.71378', '0QA03-0041', '1968-05-12', 12, true, '2006-09-12', 0, 'US', 41256.8500);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (42, 'Fetter', 'David', '2011-10-22 12:20:27.526743', '2011-10-22 13:56:28.681739', 'F0001-0042', '1969-06-25', 2, true, '2010-05-14', 0, 'US', 42561.0000);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (45, '斉藤', '博', '2011-10-22 12:21:50.621399', '2011-10-22 13:56:47.665793', '0CO03-0045', '1981-06-25', 8, true, '2011-01-28', 0, 'JP', 29563.2500);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (14, 'Doe', 'Williams', '2011-10-19 19:25:37.518536', '2011-10-22 12:22:53.566103', 'F0001-0014', '1973-03-15', 2, true, '2008-06-06', 8705, 'FR', 54256.1200);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (15, 'Dupont', 'Martine', '2011-10-19 19:26:11.614375', '2011-10-22 12:22:58.851547', 'P0001-0015', '1979-12-12', 3, true, '2002-03-29', 6080, 'FR', 25658.2500);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (28, 'Berkush', 'Josh', '2011-10-22 12:10:16.784546', '2011-10-22 12:23:07.823272', 'P0001-0028', '1982-08-12', 3, true, '2007-09-21', 0, 'US', 22568.2500);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (29, 'Eseintraut', 'Peter', '2011-10-22 12:10:57.859909', '2011-10-22 12:23:11.637215', 'P0001-0029', '1972-05-25', 3, true, '2008-03-02', 0, 'FI', 23526.2500);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (30, 'Hagender', 'Magnus', '2011-10-22 12:12:27.686948', '2011-10-22 12:23:15.667189', 'D0001-0030', '1979-06-29', 4, true, '2009-12-13', 0, 'SW', 25658.8500);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (43, 'Fontaine', 'Dimitri', '2011-10-22 12:20:46.733237', '2011-10-22 13:57:06.386254', 'C0001-0043', '1983-12-12', 13, true, '2010-05-15', 0, 'FR', 22568.1200);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (44, 'Gündüz', 'Devrim', '2011-10-22 12:21:09.625923', '2011-10-22 13:57:38.369899', 'C0001-0044', '1987-08-12', 13, true, '2010-05-18', 0, 'TU', 22568.1200);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (31, 'Lane', 'Tom', '2011-10-22 12:13:12.200697', '2011-10-22 12:24:38.281611', '0DR02-0031', '1978-03-01', 5, true, '2006-09-11', 0, 'US', 31589.2500);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (32, 'Momjian', 'Bruce', '2011-10-22 12:13:32.05452', '2011-10-22 12:24:48.620373', '0CP03-0032', '1989-09-25', 6, true, '2007-04-26', 0, 'US', 35652.2500);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (33, 'Page', 'Dave', '2011-10-22 12:13:47.319101', '2011-10-22 12:24:55.760698', '0DR02-0033', '1981-11-12', 5, true, '2005-03-29', 0, 'UK', 38596.2500);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (37, 'Cramer', 'Dave', '2011-10-22 12:19:10.461494', '2011-10-22 13:57:57.657923', '0CP03-0037', '1961-02-01', 6, true, '2002-09-26', 0, 'CA', 27586.5400);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (49, 'Doe', 'John', '2011-10-22 14:59:38.628635', '2011-10-22 17:22:40.371787', '00PA3-0049', NULL, 10, true, '2011-10-22', 0, NULL, 29854.2500);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (34, 'Bartunov', 'Oleg', '2011-10-22 12:17:18.189704', '2011-10-22 13:55:41.705901', 'P0001-0034', '1968-10-15', 3, true, '2004-03-03', 0, 'RU', 39542.2500);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (27, 'Cash', 'Johny', '2011-10-22 12:08:12.057929', '2011-10-23 11:29:10.213246', 'P0001-0027', '1985-10-26', 3, false, '2011-01-12', 0, 'FR', 24568.2500);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (48, 'Ostrovitch', 'Vladimir', '2011-10-22 13:53:54.320972', '2011-10-23 15:12:42.143815', '0TR02-0048', NULL, 7, true, '2010-10-22', 0, 'RU', NULL);
INSERT INTO employes (per_id, per_nom, per_prenom, date_creation, date_modification, emp_code, emp_naissance, ser_id, per_actif, emp_date_entree, per_points, emp_code_pays, emp_salaire_annuel) VALUES (13, 'Doe', 'John', '2011-10-19 19:24:41.734691', '2011-10-23 15:18:57.287738', 'D0001-0013', '1971-10-12', 4, true, '2001-04-12', 9825, 'FR', 58958.2500);


--
-- TOC entry 1959 (class 0 OID 18367)
-- Dependencies: 1583
-- Data for Name: employes_projet; Type: TABLE DATA; Schema: drh; Owner: formation_admin
--

INSERT INTO employes_projet (pro_id, emp_id) VALUES (1, 13);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (1, 15);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (1, 34);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (1, 37);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (1, 38);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (1, 39);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (1, 40);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 28);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 29);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 30);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 31);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 32);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 33);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 34);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 35);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 36);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 37);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 38);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 39);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 40);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 42);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 43);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 44);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 45);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (2, 48);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (3, 15);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (3, 30);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (3, 36);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (3, 41);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (3, 37);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (3, 31);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (4, 15);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (4, 30);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (4, 36);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (4, 41);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (4, 42);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (4, 43);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (4, 44);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (4, 48);
INSERT INTO employes_projet (pro_id, emp_id) VALUES (3, 48);


--
-- TOC entry 1955 (class 0 OID 17915)
-- Dependencies: 1567
-- Data for Name: interimaires; Type: TABLE DATA; Schema: drh; Owner: formation_admin
--

INSERT INTO interimaires (per_id, per_nom, per_prenom, date_creation, date_modification, age_id, int_nb_jours_annee, int_id, per_actif, int_nb_jours_total, per_points, int_salaire_quotidien) VALUES (16, 'Monk', 'Thelonius', '2011-10-19 19:28:06.36684', '2011-10-19 19:28:06.36684', 1, 15, 1, true, 15, 5505, 35.0000);
INSERT INTO interimaires (per_id, per_nom, per_prenom, date_creation, date_modification, age_id, int_nb_jours_annee, int_id, per_actif, int_nb_jours_total, per_points, int_salaire_quotidien) VALUES (17, 'Parker', 'Charlie', '2011-10-20 09:57:23.259576', '2011-10-20 09:57:23.259576', 2, 5, 2, true, 5, 7840, 29.0000);
INSERT INTO interimaires (per_id, per_nom, per_prenom, date_creation, date_modification, age_id, int_nb_jours_annee, int_id, per_actif, int_nb_jours_total, per_points, int_salaire_quotidien) VALUES (22, 'Reinhardt', 'Django', '2011-10-20 09:59:52.365789', '2011-10-20 09:59:52.365789', 3, 85, 4, true, 458, 6465, 35.4500);
INSERT INTO interimaires (per_id, per_nom, per_prenom, date_creation, date_modification, age_id, int_nb_jours_annee, int_id, per_actif, int_nb_jours_total, per_points, int_salaire_quotidien) VALUES (24, 'Jackson', 'Mahalia', '2011-10-20 10:08:51.963194', '2011-10-20 10:08:51.963194', 1, 15, 6, true, 15, 9675, 45.3200);
INSERT INTO interimaires (per_id, per_nom, per_prenom, date_creation, date_modification, age_id, int_nb_jours_annee, int_id, per_actif, int_nb_jours_total, per_points, int_salaire_quotidien) VALUES (25, 'Armstrong', 'Louis', '2011-10-20 10:09:24.387202', '2011-10-20 10:09:24.387202', 2, 26, 7, true, 426, 2260, 39.9900);
INSERT INTO interimaires (per_id, per_nom, per_prenom, date_creation, date_modification, age_id, int_nb_jours_annee, int_id, per_actif, int_nb_jours_total, per_points, int_salaire_quotidien) VALUES (26, 'Petrucianni', 'Michel', '2011-10-20 10:10:15.611359', '2011-10-20 10:10:15.611359', 3, 152, 8, true, 325, 10150, 27.2500);
INSERT INTO interimaires (per_id, per_nom, per_prenom, date_creation, date_modification, age_id, int_nb_jours_annee, int_id, per_actif, int_nb_jours_total, per_points, int_salaire_quotidien) VALUES (21, 'Davis', 'Miles', '2011-10-20 09:58:46.762352', '2011-10-20 09:58:46.762352', 3, 59, 3, false, 123, 6460, 29.2900);
INSERT INTO interimaires (per_id, per_nom, per_prenom, date_creation, date_modification, age_id, int_nb_jours_annee, int_id, per_actif, int_nb_jours_total, per_points, int_salaire_quotidien) VALUES (23, 'Gillespsie', 'Dizzie', '2011-10-20 10:08:24.467249', '2011-10-20 10:08:24.467249', 2, 2, 5, false, 259, 7340, 29.0000);


--
-- TOC entry 1953 (class 0 OID 17719)
-- Dependencies: 1564
-- Data for Name: personnel; Type: TABLE DATA; Schema: drh; Owner: formation_admin
--

INSERT INTO personnel (per_id, per_nom, per_prenom, date_creation, date_modification, per_actif, per_points) VALUES (46, 'Stosick', 'Tristan', '2011-10-22 13:51:47.048493', '2011-10-22 13:51:47.048493', true, 0);
INSERT INTO personnel (per_id, per_nom, per_prenom, date_creation, date_modification, per_actif, per_points) VALUES (47, 'Leroy', 'Régis', '2011-10-22 13:52:16.049325', '2011-10-22 13:52:16.049325', true, 0);


--
-- TOC entry 1958 (class 0 OID 18361)
-- Dependencies: 1582
-- Data for Name: projet; Type: TABLE DATA; Schema: drh; Owner: formation_admin
--

INSERT INTO projet (pro_id, pro_nom) VALUES (2, 'Base de données');
INSERT INTO projet (pro_id, pro_nom) VALUES (4, 'Séminaire 2010');
INSERT INTO projet (pro_id, pro_nom) VALUES (1, 'Trombonnes 2004');
INSERT INTO projet (pro_id, pro_nom) VALUES (3, 'Séminaire 2009');
INSERT INTO projet (pro_id, pro_nom) VALUES (5, 'Séminaire 2011');


--
-- TOC entry 1954 (class 0 OID 17743)
-- Dependencies: 1566
-- Data for Name: services; Type: TABLE DATA; Schema: drh; Owner: formation_admin
--

INSERT INTO services (ser_id, ser_nom, ser_code, ser_parent, date_creation, date_modification, ser_points) VALUES (5, 'RH', '0DR02', 4, '2011-10-19 16:23:06.478274+02', '2011-10-19 16:23:30.726727+02', 0);
INSERT INTO services (ser_id, ser_nom, ser_code, ser_parent, date_creation, date_modification, ser_points) VALUES (8, 'Comité', '0CO03', 4, '2011-10-19 16:23:06.478274+02', '2011-10-19 16:23:30.726727+02', 0);
INSERT INTO services (ser_id, ser_nom, ser_code, ser_parent, date_creation, date_modification, ser_points) VALUES (9, 'Achats', '00AC2', 6, '2011-10-19 16:23:06.478274+02', '2011-10-19 16:23:30.726727+02', 0);
INSERT INTO services (ser_id, ser_nom, ser_code, ser_parent, date_creation, date_modification, ser_points) VALUES (10, 'Paye', '00PA3', 6, '2011-10-19 16:23:06.478274+02', '2011-10-19 16:23:30.726727+02', 0);
INSERT INTO services (ser_id, ser_nom, ser_code, ser_parent, date_creation, date_modification, ser_points) VALUES (11, 'Maintenance', '0MA02', 3, '2011-10-19 16:23:06.478274+02', '2011-10-19 16:23:30.726727+02', 0);
INSERT INTO services (ser_id, ser_nom, ser_code, ser_parent, date_creation, date_modification, ser_points) VALUES (12, 'Qualité', '0QA03', 3, '2011-10-19 16:23:06.478274+02', '2011-10-19 16:23:30.726727+02', 0);
INSERT INTO services (ser_id, ser_nom, ser_code, ser_parent, date_creation, date_modification, ser_points) VALUES (13, 'Commercial', 'C0001', 1, '2011-10-19 16:23:06.478274+02', '2011-10-19 17:55:43.037958+02', 0);
INSERT INTO services (ser_id, ser_nom, ser_code, ser_parent, date_creation, date_modification, ser_points) VALUES (1, 'Inconnu', 'X0000', 1, '2011-10-19 16:23:06.478274+02', '2011-10-19 17:55:43.037958+02', 0);
INSERT INTO services (ser_id, ser_nom, ser_code, ser_parent, date_creation, date_modification, ser_points) VALUES (6, 'Comptabilité', '0CP03', 2, '2011-10-19 16:23:06.478274+02', '2011-10-19 18:01:57.614285+02', 0);
INSERT INTO services (ser_id, ser_nom, ser_code, ser_parent, date_creation, date_modification, ser_points) VALUES (7, 'Trading', '0TR02', 2, '2011-10-19 16:23:06.478274+02', '2011-10-19 18:02:00.424357+02', 0);
INSERT INTO services (ser_id, ser_nom, ser_code, ser_parent, date_creation, date_modification, ser_points) VALUES (4, 'Direction', 'D0001', 1, '2011-10-19 16:23:06.478274+02', '2011-10-21 16:20:50.225659+02', 480);
INSERT INTO services (ser_id, ser_nom, ser_code, ser_parent, date_creation, date_modification, ser_points) VALUES (3, 'Production', 'P0001', 1, '2011-10-19 16:23:06.478274+02', '2011-10-21 16:20:50.716864+02', 430);
INSERT INTO services (ser_id, ser_nom, ser_code, ser_parent, date_creation, date_modification, ser_points) VALUES (2, 'Finances', 'F0001', 1, '2011-10-19 17:56:42.598624+02', '2011-10-21 16:20:51.961172+02', 490);


--
-- TOC entry 1932 (class 2606 OID 18027)
-- Dependencies: 1571 1571
-- Name: agence_code_UNIQUE; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace:
--

ALTER TABLE ONLY agences
    ADD CONSTRAINT "agence_code_UNIQUE" UNIQUE (age_code);


--
-- TOC entry 1934 (class 2606 OID 18014)
-- Dependencies: 1571 1571
-- Name: agences_PRIMARY_KEY; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace:
--

ALTER TABLE ONLY agences
    ADD CONSTRAINT "agences_PRIMARY_KEY" PRIMARY KEY (age_id);


--
-- TOC entry 1919 (class 2606 OID 17724)
-- Dependencies: 1564 1564
-- Name: employes_PRIMARY_KEY; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace:
--

ALTER TABLE ONLY personnel
    ADD CONSTRAINT "employes_PRIMARY_KEY" PRIMARY KEY (per_id);


--
-- TOC entry 1940 (class 2606 OID 18400)
-- Dependencies: 1583 1583 1583
-- Name: employes_projet_PRIMARY_KEY; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace:
--

ALTER TABLE ONLY employes_projet
    ADD CONSTRAINT "employes_projet_PRIMARY_KEY" PRIMARY KEY (pro_id, emp_id);


--
-- TOC entry 1929 (class 2606 OID 17948)
-- Dependencies: 1569 1569
-- Name: emplyes_personnel_PRIMARY_KEY; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace:
--

ALTER TABLE ONLY employes
    ADD CONSTRAINT "emplyes_personnel_PRIMARY_KEY" PRIMARY KEY (per_id);


--
-- TOC entry 1925 (class 2606 OID 17934)
-- Dependencies: 1567 1567
-- Name: interim_employes_PRIMARY_KEY; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace:
--

ALTER TABLE ONLY interimaires
    ADD CONSTRAINT "interim_employes_PRIMARY_KEY" PRIMARY KEY (per_id);


--
-- TOC entry 1927 (class 2606 OID 17936)
-- Dependencies: 1567 1567
-- Name: interim_unique_int_id; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace:
--

ALTER TABLE ONLY interimaires
    ADD CONSTRAINT interim_unique_int_id UNIQUE (int_id);


--
-- TOC entry 1936 (class 2606 OID 18366)
-- Dependencies: 1582 1582
-- Name: projet_PRIMARY_KEY; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace:
--

ALTER TABLE ONLY projet
    ADD CONSTRAINT "projet_PRIMARY_KEY" PRIMARY KEY (pro_id);


--
-- TOC entry 1938 (class 2606 OID 18411)
-- Dependencies: 1582 1582
-- Name: projet_nom_UNIQUE; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace:
--

ALTER TABLE ONLY projet
    ADD CONSTRAINT "projet_nom_UNIQUE" UNIQUE (pro_nom) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 1922 (class 2606 OID 17748)
-- Dependencies: 1566 1566
-- Name: service_PRIMARY_KEY; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace:
--

ALTER TABLE ONLY services
    ADD CONSTRAINT "service_PRIMARY_KEY" PRIMARY KEY (ser_id);


--
-- TOC entry 1930 (class 1259 OID 17970)
-- Dependencies: 1569
-- Name: fki_EMPLOYE_POUR_UN_SERVICE_FK; Type: INDEX; Schema: drh; Owner: formation_admin; Tablespace:
--

CREATE INDEX "fki_EMPLOYE_POUR_UN_SERVICE_FK" ON employes USING btree (ser_id);


--
-- TOC entry 1941 (class 1259 OID 18392)
-- Dependencies: 1583
-- Name: fki_employes_projet_EMPLOYES_FK; Type: INDEX; Schema: drh; Owner: formation_admin; Tablespace:
--

CREATE INDEX "fki_employes_projet_EMPLOYES_FK" ON employes_projet USING btree (emp_id);


--
-- TOC entry 1942 (class 1259 OID 18398)
-- Dependencies: 1583
-- Name: fki_employes_projet_PROJET_FK; Type: INDEX; Schema: drh; Owner: formation_admin; Tablespace:
--

CREATE INDEX "fki_employes_projet_PROJET_FK" ON employes_projet USING btree (pro_id);


--
-- TOC entry 1923 (class 1259 OID 18020)
-- Dependencies: 1567
-- Name: fki_interimaires_agence_interim_FK; Type: INDEX; Schema: drh; Owner: formation_admin; Tablespace:
--

CREATE INDEX "fki_interimaires_agence_interim_FK" ON interimaires USING btree (age_id);


--
-- TOC entry 1920 (class 1259 OID 18047)
-- Dependencies: 1564 1564 1564
-- Name: personnel_Actif_nom_prenom_IDX; Type: INDEX; Schema: drh; Owner: formation_admin; Tablespace:
--

CREATE INDEX "personnel_Actif_nom_prenom_IDX" ON personnel USING btree (per_actif, per_nom, per_prenom);


--
-- TOC entry 1951 (class 2620 OID 17983)
-- Dependencies: 1569 33
-- Name: emp_insert_code; Type: TRIGGER; Schema: drh; Owner: formation_admin
--

CREATE TRIGGER emp_insert_code BEFORE INSERT ON employes FOR EACH ROW EXECUTE PROCEDURE handle_employe_code();


--
-- TOC entry 1952 (class 2620 OID 17984)
-- Dependencies: 1569 1569 1569 33
-- Name: emp_update_code; Type: TRIGGER; Schema: drh; Owner: formation_admin
--

CREATE TRIGGER emp_update_code BEFORE UPDATE ON employes FOR EACH ROW WHEN (((new.per_id <> old.per_id) OR (new.ser_id <> old.ser_id))) EXECUTE PROCEDURE handle_employe_code();


--
-- TOC entry 1950 (class 2620 OID 17974)
-- Dependencies: 1569 20
-- Name: emp_update_date_modification; Type: TRIGGER; Schema: drh; Owner: formation_admin
--

CREATE TRIGGER emp_update_date_modification BEFORE UPDATE ON employes FOR EACH ROW EXECUTE PROCEDURE public.update_datemodif_column();


--
-- TOC entry 1949 (class 2620 OID 17985)
-- Dependencies: 1566 33 1566
-- Name: ser_update_alter_emp_code; Type: TRIGGER; Schema: drh; Owner: formation_admin
--

CREATE TRIGGER ser_update_alter_emp_code BEFORE UPDATE ON services FOR EACH ROW WHEN (((new.ser_code)::text <> (old.ser_code)::text)) EXECUTE PROCEDURE handle_employe_code();


--
-- TOC entry 1948 (class 2620 OID 17911)
-- Dependencies: 20 1566
-- Name: ser_update_date_modification; Type: TRIGGER; Schema: drh; Owner: formation_admin
--

CREATE TRIGGER ser_update_date_modification BEFORE UPDATE ON services FOR EACH ROW EXECUTE PROCEDURE public.update_datemodif_column();


--
-- TOC entry 1945 (class 2606 OID 17965)
-- Dependencies: 1569 1921 1566
-- Name: EMPLOYE_POUR_UN_SERVICE_FK; Type: FK CONSTRAINT; Schema: drh; Owner: formation_admin
--

ALTER TABLE ONLY employes
    ADD CONSTRAINT "EMPLOYE_POUR_UN_SERVICE_FK" FOREIGN KEY (ser_id) REFERENCES services(ser_id) ON UPDATE CASCADE ON DELETE SET DEFAULT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 1943 (class 2606 OID 17770)
-- Dependencies: 1566 1566 1921
-- Name: SERVICE_RELATION_PARENT; Type: FK CONSTRAINT; Schema: drh; Owner: formation_admin
--

ALTER TABLE ONLY services
    ADD CONSTRAINT "SERVICE_RELATION_PARENT" FOREIGN KEY (ser_parent) REFERENCES services(ser_id) ON UPDATE CASCADE ON DELETE SET DEFAULT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 1946 (class 2606 OID 18387)
-- Dependencies: 1583 1928 1569
-- Name: employes_projet_EMPLOYES_FK; Type: FK CONSTRAINT; Schema: drh; Owner: formation_admin
--

ALTER TABLE ONLY employes_projet
    ADD CONSTRAINT "employes_projet_EMPLOYES_FK" FOREIGN KEY (emp_id) REFERENCES employes(per_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 1947 (class 2606 OID 18393)
-- Dependencies: 1582 1935 1583
-- Name: employes_projet_PROJET_FK; Type: FK CONSTRAINT; Schema: drh; Owner: formation_admin
--

ALTER TABLE ONLY employes_projet
    ADD CONSTRAINT "employes_projet_PROJET_FK" FOREIGN KEY (pro_id) REFERENCES projet(pro_id);


--
-- TOC entry 1944 (class 2606 OID 18015)
-- Dependencies: 1933 1571 1567
-- Name: interimaires_agence_interim_FK; Type: FK CONSTRAINT; Schema: drh; Owner: formation_admin
--

ALTER TABLE ONLY interimaires
    ADD CONSTRAINT "interimaires_agence_interim_FK" FOREIGN KEY (age_id) REFERENCES agences(age_id) ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 1962 (class 0 OID 0)
-- Dependencies: 7
-- Name: drh; Type: ACL; Schema: -; Owner: formation_admin
--

REVOKE ALL ON SCHEMA drh FROM PUBLIC;
REVOKE ALL ON SCHEMA drh FROM formation_admin;
GRANT ALL ON SCHEMA drh TO formation_admin;
GRANT USAGE ON SCHEMA drh TO formation_drh;


--
-- TOC entry 1964 (class 0 OID 0)
-- Dependencies: 8
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- TOC entry 1965 (class 0 OID 0)
-- Dependencies: 33
-- Name: handle_employe_code(); Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON FUNCTION handle_employe_code() FROM PUBLIC;
GRANT ALL ON FUNCTION handle_employe_code() TO PUBLIC;
GRANT ALL ON FUNCTION handle_employe_code() TO formation_ecriture;
GRANT ALL ON FUNCTION handle_employe_code() TO formation_lecture;
GRANT ALL ON FUNCTION handle_employe_code() TO postgres;


SET search_path = public, pg_catalog;

--
-- TOC entry 1966 (class 0 OID 0)
-- Dependencies: 20
-- Name: update_datemodif_column(); Type: ACL; Schema: public; Owner: formation_admin
--

REVOKE ALL ON FUNCTION update_datemodif_column() FROM PUBLIC;
REVOKE ALL ON FUNCTION update_datemodif_column() FROM postgres;
GRANT ALL ON FUNCTION update_datemodif_column() TO postgres;
GRANT ALL ON FUNCTION update_datemodif_column() TO PUBLIC;
GRANT ALL ON FUNCTION update_datemodif_column() TO formation_ecriture;
GRANT ALL ON FUNCTION update_datemodif_column() TO formation_lecture;
GRANT ALL ON FUNCTION update_datemodif_column() TO formation_admin WITH GRANT OPTION;


SET search_path = drh, pg_catalog;

--
-- TOC entry 1968 (class 0 OID 0)
-- Dependencies: 1571
-- Name: agences; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE agences FROM PUBLIC;
GRANT ALL ON TABLE agences TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE agences TO formation_ecriture;
GRANT SELECT ON TABLE agences TO formation_lecture;


--
-- TOC entry 1969 (class 0 OID 0)
-- Dependencies: 1564
-- Name: personnel; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE personnel FROM PUBLIC;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE personnel TO formation_ecriture;
GRANT SELECT ON TABLE personnel TO formation_lecture;


--
-- TOC entry 1970 (class 0 OID 0)
-- Dependencies: 1566
-- Name: services; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE services FROM PUBLIC;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE services TO formation_ecriture;
GRANT SELECT ON TABLE services TO formation_lecture;


--
-- TOC entry 1973 (class 0 OID 0)
-- Dependencies: 1563
-- Name: employes_emp_id_seq; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON SEQUENCE employes_emp_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE employes_emp_id_seq FROM formation_admin;
GRANT ALL ON SEQUENCE employes_emp_id_seq TO formation_admin;
GRANT ALL ON SEQUENCE employes_emp_id_seq TO formation_ecriture;
GRANT SELECT,USAGE ON SEQUENCE employes_emp_id_seq TO formation_lecture;
GRANT ALL ON SEQUENCE employes_emp_id_seq TO formation_admin WITH GRANT OPTION;


--
-- TOC entry 1974 (class 0 OID 0)
-- Dependencies: 1569
-- Name: employes; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE employes FROM PUBLIC;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE employes TO formation_ecriture;
GRANT SELECT ON TABLE employes TO formation_lecture;


--
-- TOC entry 1975 (class 0 OID 0)
-- Dependencies: 1567
-- Name: interimaires; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE interimaires FROM PUBLIC;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE interimaires TO formation_ecriture;
GRANT SELECT ON TABLE interimaires TO formation_lecture;


--
-- TOC entry 1976 (class 0 OID 0)
-- Dependencies: 1584
-- Name: vue_tableau_personnel; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE vue_tableau_personnel FROM PUBLIC;
REVOKE ALL ON TABLE vue_tableau_personnel FROM ultrogothe;
GRANT ALL ON TABLE vue_tableau_personnel TO ultrogothe;
GRANT ALL ON TABLE vue_tableau_personnel TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE vue_tableau_personnel TO formation_ecriture;
GRANT SELECT ON TABLE vue_tableau_personnel TO formation_lecture;
GRANT ALL ON TABLE vue_tableau_personnel TO formation_admin WITH GRANT OPTION;


--
-- TOC entry 1979 (class 0 OID 0)
-- Dependencies: 1570
-- Name: agences_age_id_seq; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON SEQUENCE agences_age_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE agences_age_id_seq FROM formation_admin;
GRANT ALL ON SEQUENCE agences_age_id_seq TO formation_admin;
GRANT ALL ON SEQUENCE agences_age_id_seq TO postgres;
GRANT ALL ON SEQUENCE agences_age_id_seq TO formation_ecriture;
GRANT SELECT,USAGE ON SEQUENCE agences_age_id_seq TO formation_lecture;
GRANT ALL ON SEQUENCE agences_age_id_seq TO formation_admin WITH GRANT OPTION;


--
-- TOC entry 1980 (class 0 OID 0)
-- Dependencies: 1583
-- Name: employes_projet; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE employes_projet FROM PUBLIC;
GRANT ALL ON TABLE employes_projet TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE employes_projet TO formation_ecriture;
GRANT SELECT ON TABLE employes_projet TO formation_lecture;


--
-- TOC entry 1983 (class 0 OID 0)
-- Dependencies: 1582
-- Name: projet; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE projet FROM PUBLIC;
GRANT ALL ON TABLE projet TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE projet TO formation_ecriture;
GRANT SELECT ON TABLE projet TO formation_lecture;


--
-- TOC entry 1986 (class 0 OID 0)
-- Dependencies: 1581
-- Name: projet_pro_id_seq; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON SEQUENCE projet_pro_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE projet_pro_id_seq FROM formation_admin;
GRANT ALL ON SEQUENCE projet_pro_id_seq TO formation_admin;
GRANT ALL ON SEQUENCE projet_pro_id_seq TO postgres;
GRANT ALL ON SEQUENCE projet_pro_id_seq TO formation_ecriture;
GRANT SELECT,USAGE ON SEQUENCE projet_pro_id_seq TO formation_lecture;
GRANT ALL ON SEQUENCE projet_pro_id_seq TO formation_admin WITH GRANT OPTION;


--
-- TOC entry 1989 (class 0 OID 0)
-- Dependencies: 1565
-- Name: services_ser_id_seq; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON SEQUENCE services_ser_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE services_ser_id_seq FROM formation_admin;
GRANT ALL ON SEQUENCE services_ser_id_seq TO formation_admin;
GRANT ALL ON SEQUENCE services_ser_id_seq TO formation_ecriture;
GRANT SELECT,USAGE ON SEQUENCE services_ser_id_seq TO formation_lecture;
GRANT ALL ON SEQUENCE services_ser_id_seq TO formation_admin WITH GRANT OPTION;


-- Completed on 2011-10-23 15:19:36 CEST

--
-- PostgreSQL database dump complete
--

