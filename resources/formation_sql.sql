-- LICENCE CREATIVE COMMONS - CC - BY - SA
-- =======================================
-- Cette oeuvre est mise à disposition sous licence Paternité – Partage dans les mêmes conditions 
-- Pour voir une copie de cette licence, visitez http://creativecommons.org/licenses/by-sa/3.0/ 
-- ou écrivez à Creative Commons, 444 Castro Street, Suite 900, Mountain View, California, 94041, USA.

-- PostgreSQL database dump
--

-- Dumped from database version 9.0.4
-- Dumped by pg_dump version 9.0.4
-- Started on 2011-10-29 21:17:03 CEST

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- TOC entry 6 (class 2615 OID 21549)
-- Name: app; Type: SCHEMA; Schema: -; Owner: formation_admin
--

CREATE SCHEMA app;


ALTER SCHEMA app OWNER TO formation_admin;

--
-- TOC entry 7 (class 2615 OID 20385)
-- Name: drh; Type: SCHEMA; Schema: -; Owner: formation_admin
--

CREATE SCHEMA drh;


ALTER SCHEMA drh OWNER TO formation_admin;

--
-- TOC entry 364 (class 2612 OID 11574)
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: postgres
--

CREATE OR REPLACE PROCEDURAL LANGUAGE plpgsql;


ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO postgres;

SET search_path = app, pg_catalog;

--
-- TOC entry 343 (class 1247 OID 21551)
-- Dependencies: 6
-- Name: statut_commande; Type: TYPE; Schema: app; Owner: formation_admin
--

CREATE TYPE statut_commande AS ENUM (
    'en attente',
    'en préparation',
    'prête à l''envoi',
    'expédiée'
);


ALTER TYPE app.statut_commande OWNER TO formation_admin;

--
-- TOC entry 345 (class 1247 OID 21557)
-- Dependencies: 6
-- Name: statut_facturation_commande; Type: TYPE; Schema: app; Owner: formation_admin
--

CREATE TYPE statut_facturation_commande AS ENUM (
    'non facturée',
    'facturée',
    'payée',
    'retard de paiement',
    'litige',
    'abandonnée',
    'annulée'
);


ALTER TYPE app.statut_facturation_commande OWNER TO formation_admin;

SET search_path = drh, pg_catalog;

--
-- TOC entry 320 (class 1247 OID 20445)
-- Dependencies: 321 7
-- Name: CODE10; Type: DOMAIN; Schema: drh; Owner: formation_admin
--

CREATE DOMAIN "CODE10" AS character varying(10)
	CONSTRAINT "CODE10_check_length" CHECK ((character_length((VALUE)::text) = 10));


ALTER DOMAIN drh."CODE10" OWNER TO formation_admin;

SET search_path = app, pg_catalog;

--
-- TOC entry 22 (class 1255 OID 21565)
-- Dependencies: 364 6
-- Name: commande_points(); Type: FUNCTION; Schema: app; Owner: formation_admin
--

CREATE FUNCTION commande_points() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE NOTICE E'\napp.commande_points()\n    Operation: %\n    Schema: %\n    Table: %',
        TG_OP,
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME;
    NEW.com_points = app.points_from_amount(NEW.com_total_ht);
    RAISE NOTICE E'\n     Calling Point For Amount % :: Get: %',NEW.com_total_ht,NEW.com_points;
    RETURN NEW;
  END;
$$;


ALTER FUNCTION app.commande_points() OWNER TO formation_admin;

--
-- TOC entry 24 (class 1255 OID 21566)
-- Dependencies: 364 6
-- Name: ligne_commande_total(); Type: FUNCTION; Schema: app; Owner: formation_admin
--

CREATE FUNCTION ligne_commande_total() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE NOTICE E'\nligne_commande_total()\n    Operation: %\n    Schema: %\n    Table: %',
        TG_OP,
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME;
    NEW.lic_total = NEW.lic_quantite * NEW.lic_prix_unitaire;
    RETURN NEW;
  END;
$$;


ALTER FUNCTION app.ligne_commande_total() OWNER TO formation_admin;

--
-- TOC entry 23 (class 1255 OID 21567)
-- Dependencies: 364 6
-- Name: perform_new_points_add(integer, integer); Type: FUNCTION; Schema: app; Owner: formation_admin
--

CREATE FUNCTION perform_new_points_add(points integer, personel_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
  DECLARE 
    user_record   app.vue_drh_tableau_personnel%rowtype;
  BEGIN
    RAISE NOTICE E'\n** perform_new_points_add:: % points , % **',points,personel_id;
    PERFORM app.update_points_vue_drh_tableau_personnel(points,personel_id,'personnels');
    -- maintenant on passe aux points pour les services/agences
    -- en relation avec ce personnel
    -- le score à ce niveau ne fait que des +-10
    SELECT * INTO user_record FROM app.vue_drh_tableau_personnel WHERE per_id=personel_id;
    IF (user_record.per_type = 'interimaires') THEN
      PERFORM app.update_points_vue_drh_tableau_personnel(10,user_record.age_id,'agences');
    ELSIF (user_record.per_type = 'employes') THEN
      PERFORM app.update_points_vue_drh_tableau_personnel(10,user_record.ser_id,'services');
    END IF;
  END;
$$;


ALTER FUNCTION app.perform_new_points_add(points integer, personel_id integer) OWNER TO formation_admin;

--
-- TOC entry 25 (class 1255 OID 21568)
-- Dependencies: 364 6
-- Name: perform_old_points_removal(integer, integer); Type: FUNCTION; Schema: app; Owner: formation_admin
--

CREATE FUNCTION perform_old_points_removal(points integer, personel_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
  DECLARE 
    user_record   app.vue_drh_tableau_personnel%rowtype;
  BEGIN
    RAISE NOTICE E'\n**perform_old_points_removal: % points , % **',points,personel_id;
    PERFORM app.update_points_vue_drh_tableau_personnel(-points,personel_id,'personnels');
    -- maintenant on passe aux points pour les services/agences
    -- en relation avec ce personnel
    -- le score à ce niveau ne fait que des +-10
    SELECT * INTO user_record FROM app.vue_drh_tableau_personnel WHERE per_id=personel_id;
    IF (user_record.per_type = 'interimaires') THEN
      PERFORM app.update_points_vue_drh_tableau_personnel(-10,user_record.age_id,'agences');
    ELSIF (user_record.per_type = 'employes') THEN
      PERFORM app.update_points_vue_drh_tableau_personnel(-10,user_record.ser_id,'services');
    END IF;
  END;
$$;


ALTER FUNCTION app.perform_old_points_removal(points integer, personel_id integer) OWNER TO formation_admin;

--
-- TOC entry 26 (class 1255 OID 21569)
-- Dependencies: 6
-- Name: points_from_amount(numeric); Type: FUNCTION; Schema: app; Owner: formation_admin
--

CREATE FUNCTION points_from_amount(numeric) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT CASE 
      WHEN ($1 IS NULL OR $1=0) THEN 0
      WHEN ($1<50) THEN 5 
      WHEN ($1>=50 AND $1<100) THEN 15
      WHEN ($1>=100 AND $1<200) THEN 50
      WHEN ($1>=200 AND $1<500) THEN 100
      ELSE 1000 END;
$_$;


ALTER FUNCTION app.points_from_amount(numeric) OWNER TO formation_admin;

--
-- TOC entry 27 (class 1255 OID 21570)
-- Dependencies: 364 6
-- Name: repercute_points_to_personnel_and_service(); Type: FUNCTION; Schema: app; Owner: formation_admin
--

CREATE FUNCTION repercute_points_to_personnel_and_service() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE NOTICE E'\nrepercute_points_to_personnel_and_service\n    Operation: %\n    Schema: %\n    Table: %',
        TG_OP,
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME;
    IF (TG_OP = 'UPDATE') THEN
        -- remove OLD points
        IF (OLD.com_points<>0) THEN
          PERFORM app.perform_old_points_removal(OLD.com_points,OLD.per_id);
        END IF;
        -- add NEW points
        IF (NEW.com_points<>0) THEN
          PERFORM app.perform_new_points_add(NEW.com_points,NEW.per_id);
        END IF;
    ELSIF (TG_OP = 'INSERT') THEN
        -- add NEW points
        IF (NEW.com_points<>0) THEN
          PERFORM app.perform_new_points_add(NEW.com_points,NEW.per_id);
        END IF;
    ELSIF (TG_OP = 'DELETE') THEN
        -- remove OLD points
        IF (OLD.com_points<>0) THEN
          PERFORM app.perform_old_points_removal(OLD.com_points,OLD.per_id);
        END IF;
    END IF;
    RETURN NEW;
  END;
$$;


ALTER FUNCTION app.repercute_points_to_personnel_and_service() OWNER TO formation_admin;

--
-- TOC entry 29 (class 1255 OID 21571)
-- Dependencies: 6
-- Name: sum_commande(integer); Type: FUNCTION; Schema: app; Owner: formation_admin
--

CREATE FUNCTION sum_commande(integer) RETURNS numeric
    LANGUAGE sql
    AS $_$
    SELECT SUM(lic_total) AS total FROM app.lignes_commande WHERE com_id=$1;
$_$;


ALTER FUNCTION app.sum_commande(integer) OWNER TO formation_admin;

--
-- TOC entry 32 (class 1255 OID 21572)
-- Dependencies: 364 6
-- Name: total_commande_triggers(); Type: FUNCTION; Schema: app; Owner: formation_admin
--

CREATE FUNCTION total_commande_triggers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
    identifiant_commande  integer;
    total_ht              numeric(12,4);
  BEGIN
    RAISE NOTICE E'\ntotal_commande_triggers()\n    Operation: %\n    Schema: %\n    Table: %',
        TG_OP,
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME;
    IF ((TG_OP = 'UPDATE') OR (TG_OP = 'INSERT')) THEN
      identifiant_commande = NEW.com_id;
      total_ht = app.sum_commande(identifiant_commande);
      RAISE NOTICE E'\ncalling app.update_commande_amounts( % , % )',total_ht,identifiant_commande;
      PERFORM app.update_commande_amounts(total_ht,identifiant_commande);
      RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
      identifiant_commande = OLD.com_id;
      total_ht = app.sum_commande(identifiant_commande);
      RAISE NOTICE E'\ncalling app.update_commande_amounts( % , % )',total_ht,identifiant_commande;
      PERFORM app.update_commande_amounts(total_ht,identifiant_commande);
      RETURN NEW;
    END IF;
    RETURN NULL;
  END;
$$;


ALTER FUNCTION app.total_commande_triggers() OWNER TO formation_admin;

--
-- TOC entry 31 (class 1255 OID 21573)
-- Dependencies: 6
-- Name: update_commande_amounts(numeric, integer); Type: FUNCTION; Schema: app; Owner: formation_admin
--

CREATE FUNCTION update_commande_amounts(numeric, integer) RETURNS void
    LANGUAGE sql
    AS $_$
  UPDATE app.commandes SET
    com_total_ht = $1,
    com_total_tva = $1 * com_taux_tva,
    com_total_ttc = $1 * (1+com_taux_tva)
  WHERE com_id=$2;
$_$;


ALTER FUNCTION app.update_commande_amounts(numeric, integer) OWNER TO formation_admin;

--
-- TOC entry 30 (class 1255 OID 21574)
-- Dependencies: 364 6
-- Name: update_points_vue_drh_tableau_personnel(integer, integer, text); Type: FUNCTION; Schema: app; Owner: formation_admin
--

CREATE FUNCTION update_points_vue_drh_tableau_personnel(score integer, target_code integer, target_entity text) RETURNS void
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE NOTICE E'update_points_vue_drh_tableau_personnel()\n    Addition: % points for % #%',score,target_entity,target_code;
    UPDATE app.vue_drh_points SET points=points+score WHERE id=target_code AND entity=target_entity;
  END;
$$;


ALTER FUNCTION app.update_points_vue_drh_tableau_personnel(score integer, target_code integer, target_entity text) OWNER TO formation_admin;

--
-- TOC entry 28 (class 1255 OID 21575)
-- Dependencies: 364 6
-- Name: verif_modifications_autorisees_sur_ligne_commande(); Type: FUNCTION; Schema: app; Owner: formation_admin
--

CREATE FUNCTION verif_modifications_autorisees_sur_ligne_commande() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE NOTICE E'\nverif_modifications_autorisees_sur_ligne_commande()\n    Operation: %\n    Schema: %\n    Table: %',
        TG_OP,
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME;
    IF (NEW.com_id<>OLD.com_id) THEN
      RAISE EXCEPTION 'Il est interdit de modifier la commande référente d''une ligne de commande.';
    END IF;
    RETURN NEW;
 END;
$$;


ALTER FUNCTION app.verif_modifications_autorisees_sur_ligne_commande() OWNER TO formation_admin;

SET search_path = drh, pg_catalog;

--
-- TOC entry 20 (class 1255 OID 20447)
-- Dependencies: 364 7
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
-- TOC entry 21 (class 1255 OID 20448)
-- Dependencies: 364 8
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

SET search_path = app, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 1575 (class 1259 OID 21576)
-- Dependencies: 1917 1918 1919 1920 1921 6 345 343
-- Name: commandes; Type: TABLE; Schema: app; Owner: formation_admin; Tablespace: 
--

CREATE TABLE commandes (
    com_id integer NOT NULL,
    com_date timestamp without time zone DEFAULT now(),
    com_date_expedition timestamp without time zone,
    com_date_facturation timestamp without time zone,
    com_statut_facturation statut_facturation_commande DEFAULT 'non facturée'::statut_facturation_commande NOT NULL,
    com_statut statut_commande DEFAULT 'en attente'::statut_commande NOT NULL,
    per_id integer,
    com_points integer DEFAULT 0,
    com_taux_tva numeric(6,4) DEFAULT 0.196,
    com_total_ht numeric(12,4),
    com_total_tva numeric(12,4),
    com_total_ttc numeric(12,4)
)
WITH (fillfactor=80);


ALTER TABLE app.commandes OWNER TO formation_admin;

--
-- TOC entry 2020 (class 0 OID 0)
-- Dependencies: 1575
-- Name: COLUMN commandes.com_date_expedition; Type: COMMENT; Schema: app; Owner: formation_admin
--

COMMENT ON COLUMN commandes.com_date_expedition IS 'Date à laquelle la commande a été expédiée';


--
-- TOC entry 2021 (class 0 OID 0)
-- Dependencies: 1575
-- Name: COLUMN commandes.com_date_facturation; Type: COMMENT; Schema: app; Owner: formation_admin
--

COMMENT ON COLUMN commandes.com_date_facturation IS 'date à laquelle la facturation de la commande est effectuée';


--
-- TOC entry 1576 (class 1259 OID 21584)
-- Dependencies: 1575 6
-- Name: commandes_com_id_seq; Type: SEQUENCE; Schema: app; Owner: formation_admin
--

CREATE SEQUENCE commandes_com_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE app.commandes_com_id_seq OWNER TO formation_admin;

--
-- TOC entry 2023 (class 0 OID 0)
-- Dependencies: 1576
-- Name: commandes_com_id_seq; Type: SEQUENCE OWNED BY; Schema: app; Owner: formation_admin
--

ALTER SEQUENCE commandes_com_id_seq OWNED BY commandes.com_id;


--
-- TOC entry 2024 (class 0 OID 0)
-- Dependencies: 1576
-- Name: commandes_com_id_seq; Type: SEQUENCE SET; Schema: app; Owner: formation_admin
--

SELECT pg_catalog.setval('commandes_com_id_seq', 3578, true);


--
-- TOC entry 1577 (class 1259 OID 21586)
-- Dependencies: 1923 1924 1925 1926 1928 1929 1930 1931 6
-- Name: lignes_commande; Type: TABLE; Schema: app; Owner: formation_admin; Tablespace: 
--

CREATE TABLE lignes_commande (
    lic_id integer NOT NULL,
    lic_quantite integer DEFAULT 0,
    pro_id integer NOT NULL,
    com_id integer NOT NULL,
    lic_est_reduction boolean DEFAULT false,
    lic_prix_unitaire numeric(12,4) DEFAULT 0.0 NOT NULL,
    lic_total numeric(12,4) DEFAULT 0.0 NOT NULL,
    CONSTRAINT "CHECK_MAX_UNE_REDUCTION" CHECK (((NOT lic_est_reduction) OR (lic_quantite = 1))),
    CONSTRAINT "CHECK_PRIX_UNITAIRE_POSITIF" CHECK ((lic_est_reduction OR (lic_prix_unitaire > 0.0::numeric(14,2)))),
    CONSTRAINT "CHECK_QUANTITE_POSTIVE" CHECK ((lic_quantite > 0)),
    CONSTRAINT "CHECK_TOTAL_EST_POSITIF" CHECK ((lic_est_reduction OR (lic_total > 0.0::numeric(14,2))))
)
WITH (fillfactor=90);


ALTER TABLE app.lignes_commande OWNER TO formation_admin;

--
-- TOC entry 1578 (class 1259 OID 21597)
-- Dependencies: 1577 6
-- Name: lignes_commande_lic_id_seq; Type: SEQUENCE; Schema: app; Owner: formation_admin
--

CREATE SEQUENCE lignes_commande_lic_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE app.lignes_commande_lic_id_seq OWNER TO formation_admin;

--
-- TOC entry 2027 (class 0 OID 0)
-- Dependencies: 1578
-- Name: lignes_commande_lic_id_seq; Type: SEQUENCE OWNED BY; Schema: app; Owner: formation_admin
--

ALTER SEQUENCE lignes_commande_lic_id_seq OWNED BY lignes_commande.lic_id;


--
-- TOC entry 2028 (class 0 OID 0)
-- Dependencies: 1578
-- Name: lignes_commande_lic_id_seq; Type: SEQUENCE SET; Schema: app; Owner: formation_admin
--

SELECT pg_catalog.setval('lignes_commande_lic_id_seq', 10109, true);


--
-- TOC entry 1579 (class 1259 OID 21599)
-- Dependencies: 1932 1933 1934 6
-- Name: produit; Type: TABLE; Schema: app; Owner: formation_admin; Tablespace: 
--

CREATE TABLE produit (
    pro_id integer NOT NULL,
    pro_nom character varying(100) NOT NULL,
    pro_code character varying(5) NOT NULL,
    pro_actif boolean DEFAULT true,
    pro_est_reduction boolean DEFAULT false,
    pro_prix_unitaire numeric(12,4) DEFAULT 0.0 NOT NULL
)
WITH (fillfactor=90);


ALTER TABLE app.produit OWNER TO formation_admin;

--
-- TOC entry 1580 (class 1259 OID 21605)
-- Dependencies: 1579 6
-- Name: produit_pro_id_seq; Type: SEQUENCE; Schema: app; Owner: formation_admin
--

CREATE SEQUENCE produit_pro_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE app.produit_pro_id_seq OWNER TO formation_admin;

--
-- TOC entry 2031 (class 0 OID 0)
-- Dependencies: 1580
-- Name: produit_pro_id_seq; Type: SEQUENCE OWNED BY; Schema: app; Owner: formation_admin
--

ALTER SEQUENCE produit_pro_id_seq OWNED BY produit.pro_id;


--
-- TOC entry 2032 (class 0 OID 0)
-- Dependencies: 1580
-- Name: produit_pro_id_seq; Type: SEQUENCE SET; Schema: app; Owner: formation_admin
--

SELECT pg_catalog.setval('produit_pro_id_seq', 14, true);


SET search_path = drh, pg_catalog;

--
-- TOC entry 1562 (class 1259 OID 20449)
-- Dependencies: 1873 1874 7
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
-- TOC entry 2034 (class 0 OID 0)
-- Dependencies: 1562
-- Name: TABLE agences; Type: COMMENT; Schema: drh; Owner: formation_admin
--

COMMENT ON TABLE agences IS 'Agences d''intérim';


SET search_path = app, pg_catalog;

--
-- TOC entry 1581 (class 1259 OID 21607)
-- Dependencies: 1672 6
-- Name: vue_drh_agences; Type: VIEW; Schema: app; Owner: formation_admin
--

CREATE VIEW vue_drh_agences AS
    SELECT agences.age_id, agences.age_nom FROM drh.agences ORDER BY agences.age_nom;


ALTER TABLE app.vue_drh_agences OWNER TO formation_admin;

SET search_path = drh, pg_catalog;

--
-- TOC entry 1563 (class 1259 OID 20454)
-- Dependencies: 1876 1877 1878 1879 1880 1881 7
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
-- TOC entry 1564 (class 1259 OID 20463)
-- Dependencies: 1883 1884 1885 1886 1887 7
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

SET search_path = app, pg_catalog;

--
-- TOC entry 1582 (class 1259 OID 21611)
-- Dependencies: 1673 6
-- Name: vue_drh_points; Type: VIEW; Schema: app; Owner: formation_admin
--

CREATE VIEW vue_drh_points AS
    (SELECT 'personnels' AS entity, (((personnel.per_prenom)::text || ' '::text) || (personnel.per_nom)::text) AS nom, personnel.per_id AS id, personnel.per_points AS points FROM drh.personnel UNION SELECT 'agences' AS entity, agences.age_nom AS nom, agences.age_id AS id, agences.age_points AS points FROM drh.agences) UNION SELECT 'services' AS entity, services.ser_nom AS nom, services.ser_id AS id, services.ser_points AS points FROM drh.services ORDER BY 4 DESC;


ALTER TABLE app.vue_drh_points OWNER TO formation_admin;

--
-- TOC entry 2039 (class 0 OID 0)
-- Dependencies: 1582
-- Name: VIEW vue_drh_points; Type: COMMENT; Schema: app; Owner: formation_admin
--

COMMENT ON VIEW vue_drh_points IS 'Résumé global des points.
Vue éditable sur la colonne des points';


--
-- TOC entry 1583 (class 1259 OID 21615)
-- Dependencies: 1674 6
-- Name: vue_drh_services; Type: VIEW; Schema: app; Owner: formation_admin
--

CREATE VIEW vue_drh_services AS
    SELECT services.ser_id, services.ser_nom, services.ser_parent FROM drh.services ORDER BY services.ser_nom;


ALTER TABLE app.vue_drh_services OWNER TO formation_admin;

SET search_path = drh, pg_catalog;

--
-- TOC entry 1565 (class 1259 OID 20471)
-- Dependencies: 1563 7
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
-- TOC entry 2042 (class 0 OID 0)
-- Dependencies: 1565
-- Name: employes_emp_id_seq; Type: SEQUENCE OWNED BY; Schema: drh; Owner: formation_admin
--

ALTER SEQUENCE employes_emp_id_seq OWNED BY personnel.per_id;


--
-- TOC entry 2043 (class 0 OID 0)
-- Dependencies: 1565
-- Name: employes_emp_id_seq; Type: SEQUENCE SET; Schema: drh; Owner: formation_admin
--

SELECT pg_catalog.setval('employes_emp_id_seq', 49, true);


--
-- TOC entry 1566 (class 1259 OID 20473)
-- Dependencies: 1889 1890 1891 1892 1893 1894 1895 1896 1897 1898 1899 1900 1901 1902 1903 1904 1563 7
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
-- TOC entry 1567 (class 1259 OID 20491)
-- Dependencies: 1905 1906 1907 1908 1909 1910 1911 1912 1913 1915 1563 7
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
-- TOC entry 1568 (class 1259 OID 20503)
-- Dependencies: 1671 7
-- Name: vue_tableau_personnel; Type: VIEW; Schema: drh; Owner: formation_admin
--

CREATE VIEW vue_tableau_personnel AS
    SELECT p.relname AS per_type, pers.per_actif, pers.per_id, pers.per_nom, pers.per_prenom, COALESCE(emp.emp_code, (((age.age_code)::text || btrim(to_char(inter.int_id, '0000'::text))))::character varying, 'X'::character varying) AS per_code, COALESCE(emp.emp_salaire_annuel, (inter.int_salaire_quotidien * (inter.int_nb_jours_annee)::numeric), 0.00) AS per_salaire_annuel_real, COALESCE(emp.emp_salaire_annuel, (inter.int_salaire_quotidien * (360)::numeric), 0.00) AS per_salaire_annuel, date_part('year'::text, age((emp.emp_naissance)::timestamp with time zone)) AS pers_age, COALESCE(age((emp.emp_date_entree)::timestamp with time zone), justify_days((((inter.int_nb_jours_total)::text || ' days'::text))::interval)) AS pers_anciennete, emp.ser_id, inter.age_id FROM ((((personnel pers JOIN pg_class p ON ((p.oid = pers.tableoid))) LEFT JOIN employes emp ON ((emp.per_id = pers.per_id))) LEFT JOIN interimaires inter ON ((inter.per_id = pers.per_id))) LEFT JOIN agences age ON ((inter.age_id = age.age_id))) ORDER BY pers.per_actif, pers.per_nom, pers.per_prenom;


ALTER TABLE drh.vue_tableau_personnel OWNER TO formation_admin;

SET search_path = app, pg_catalog;

--
-- TOC entry 1584 (class 1259 OID 21619)
-- Dependencies: 1675 6
-- Name: vue_drh_tableau_personnel; Type: VIEW; Schema: app; Owner: formation_admin
--

CREATE VIEW vue_drh_tableau_personnel AS
    SELECT vue_tableau_personnel.per_type, vue_tableau_personnel.per_actif, vue_tableau_personnel.per_nom, vue_tableau_personnel.per_prenom, vue_tableau_personnel.per_code, vue_tableau_personnel.pers_age AS per_age, vue_tableau_personnel.pers_anciennete AS per_anciennete, vue_tableau_personnel.ser_id, vue_tableau_personnel.age_id, vue_tableau_personnel.per_id FROM drh.vue_tableau_personnel ORDER BY vue_tableau_personnel.per_actif, vue_tableau_personnel.per_nom, vue_tableau_personnel.per_prenom;


ALTER TABLE app.vue_drh_tableau_personnel OWNER TO formation_admin;

SET search_path = drh, pg_catalog;

--
-- TOC entry 1569 (class 1259 OID 20508)
-- Dependencies: 1562 7
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
-- TOC entry 2049 (class 0 OID 0)
-- Dependencies: 1569
-- Name: agences_age_id_seq; Type: SEQUENCE OWNED BY; Schema: drh; Owner: formation_admin
--

ALTER SEQUENCE agences_age_id_seq OWNED BY agences.age_id;


--
-- TOC entry 2050 (class 0 OID 0)
-- Dependencies: 1569
-- Name: agences_age_id_seq; Type: SEQUENCE SET; Schema: drh; Owner: formation_admin
--

SELECT pg_catalog.setval('agences_age_id_seq', 4, true);


--
-- TOC entry 1570 (class 1259 OID 20510)
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
-- TOC entry 1571 (class 1259 OID 20513)
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
-- TOC entry 2053 (class 0 OID 0)
-- Dependencies: 1571
-- Name: interimaires_int_id_seq; Type: SEQUENCE OWNED BY; Schema: drh; Owner: formation_admin
--

ALTER SEQUENCE interimaires_int_id_seq OWNED BY interimaires.int_id;


--
-- TOC entry 2054 (class 0 OID 0)
-- Dependencies: 1571
-- Name: interimaires_int_id_seq; Type: SEQUENCE SET; Schema: drh; Owner: formation_admin
--

SELECT pg_catalog.setval('interimaires_int_id_seq', 8, true);


--
-- TOC entry 1572 (class 1259 OID 20515)
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
-- TOC entry 1573 (class 1259 OID 20518)
-- Dependencies: 1572 7
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
-- TOC entry 2057 (class 0 OID 0)
-- Dependencies: 1573
-- Name: projet_pro_id_seq; Type: SEQUENCE OWNED BY; Schema: drh; Owner: formation_admin
--

ALTER SEQUENCE projet_pro_id_seq OWNED BY projet.pro_id;


--
-- TOC entry 2058 (class 0 OID 0)
-- Dependencies: 1573
-- Name: projet_pro_id_seq; Type: SEQUENCE SET; Schema: drh; Owner: formation_admin
--

SELECT pg_catalog.setval('projet_pro_id_seq', 5, true);


--
-- TOC entry 1574 (class 1259 OID 20520)
-- Dependencies: 1564 7
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
-- TOC entry 2060 (class 0 OID 0)
-- Dependencies: 1574
-- Name: services_ser_id_seq; Type: SEQUENCE OWNED BY; Schema: drh; Owner: formation_admin
--

ALTER SEQUENCE services_ser_id_seq OWNED BY services.ser_id;


--
-- TOC entry 2061 (class 0 OID 0)
-- Dependencies: 1574
-- Name: services_ser_id_seq; Type: SEQUENCE SET; Schema: drh; Owner: formation_admin
--

SELECT pg_catalog.setval('services_ser_id_seq', 13, true);


SET search_path = app, pg_catalog;

--
-- TOC entry 1922 (class 2604 OID 21623)
-- Dependencies: 1576 1575
-- Name: com_id; Type: DEFAULT; Schema: app; Owner: formation_admin
--

ALTER TABLE commandes ALTER COLUMN com_id SET DEFAULT nextval('commandes_com_id_seq'::regclass);


--
-- TOC entry 1927 (class 2604 OID 21624)
-- Dependencies: 1578 1577
-- Name: lic_id; Type: DEFAULT; Schema: app; Owner: formation_admin
--

ALTER TABLE lignes_commande ALTER COLUMN lic_id SET DEFAULT nextval('lignes_commande_lic_id_seq'::regclass);


--
-- TOC entry 1935 (class 2604 OID 21625)
-- Dependencies: 1580 1579
-- Name: pro_id; Type: DEFAULT; Schema: app; Owner: formation_admin
--

ALTER TABLE produit ALTER COLUMN pro_id SET DEFAULT nextval('produit_pro_id_seq'::regclass);


SET search_path = drh, pg_catalog;

--
-- TOC entry 1875 (class 2604 OID 20522)
-- Dependencies: 1569 1562
-- Name: age_id; Type: DEFAULT; Schema: drh; Owner: formation_admin
--

ALTER TABLE agences ALTER COLUMN age_id SET DEFAULT nextval('agences_age_id_seq'::regclass);


--
-- TOC entry 1914 (class 2604 OID 20523)
-- Dependencies: 1571 1567
-- Name: int_id; Type: DEFAULT; Schema: drh; Owner: formation_admin
--

ALTER TABLE interimaires ALTER COLUMN int_id SET DEFAULT nextval('interimaires_int_id_seq'::regclass);


--
-- TOC entry 1882 (class 2604 OID 20524)
-- Dependencies: 1565 1563
-- Name: per_id; Type: DEFAULT; Schema: drh; Owner: formation_admin
--

ALTER TABLE personnel ALTER COLUMN per_id SET DEFAULT nextval('employes_emp_id_seq'::regclass);


--
-- TOC entry 1916 (class 2604 OID 20527)
-- Dependencies: 1573 1572
-- Name: pro_id; Type: DEFAULT; Schema: drh; Owner: formation_admin
--

ALTER TABLE projet ALTER COLUMN pro_id SET DEFAULT nextval('projet_pro_id_seq'::regclass);


--
-- TOC entry 1888 (class 2604 OID 20528)
-- Dependencies: 1574 1564
-- Name: ser_id; Type: DEFAULT; Schema: drh; Owner: formation_admin
--

ALTER TABLE services ALTER COLUMN ser_id SET DEFAULT nextval('services_ser_id_seq'::regclass);


SET search_path = app, pg_catalog;

--
-- TOC entry 1997 (class 0 OID 21576)
-- Dependencies: 1575
-- Data for Name: commandes; Type: TABLE DATA; Schema: app; Owner: formation_admin
--

INSERT INTO commandes VALUES (3096, '2011-09-12 13:13:56.125396', NULL, NULL, 'non facturée', 'en préparation', 24, 50, 0.1960, 181.4600, 35.5662, 217.0262);
INSERT INTO commandes VALUES (3086, '2011-09-17 10:09:54.811445', NULL, NULL, 'non facturée', 'en attente', 21, 100, 0.1960, 481.8600, 94.4446, 576.3046);
INSERT INTO commandes VALUES (3097, '2010-12-13 07:13:56.226405', NULL, '2010-12-14 16:18:56.226405', 'payée', 'en préparation', 15, 0, 0.1960, -10.0000, -1.9600, -11.9600);
INSERT INTO commandes VALUES (3091, '2011-08-13 09:10:55.452372', '2011-08-19 14:20:55.452372', NULL, 'non facturée', 'expédiée', 14, 1000, 0.1960, 513.8900, 100.7224, 614.6124);
INSERT INTO commandes VALUES (3121, '2011-05-19 06:18:58.95804', '2011-05-28 13:22:58.95804', NULL, 'non facturée', 'expédiée', 13, 100, 0.1960, 317.7600, 62.2810, 380.0410);
INSERT INTO commandes VALUES (3106, '2011-03-12 14:13:57.14591', NULL, NULL, 'non facturée', 'prête à l''envoi', 23, 15, 0.1960, 52.5000, 10.2900, 62.7900);
INSERT INTO commandes VALUES (3115, '2011-03-14 11:11:58.108307', '2011-03-24 20:15:58.108307', NULL, 'non facturée', 'expédiée', 15, 100, 0.1960, 277.2700, 54.3449, 331.6149);
INSERT INTO commandes VALUES (3102, '2011-04-11 11:13:56.602789', '2011-04-21 19:15:56.602789', NULL, 'non facturée', 'expédiée', 16, 100, 0.1960, 311.5800, 61.0697, 372.6497);
INSERT INTO commandes VALUES (3092, '2011-09-20 09:14:55.626853', NULL, '2011-09-22 19:24:55.626853', 'payée', 'prête à l''envoi', 13, 15, 0.1960, 89.0700, 17.4577, 106.5277);
INSERT INTO commandes VALUES (3080, '2011-03-13 14:13:54.320021', NULL, '2011-03-22 21:16:54.320021', 'payée', 'en préparation', 21, 100, 0.1960, 200.6800, 39.3333, 240.0133);
INSERT INTO commandes VALUES (3087, '2011-04-11 12:14:54.950126', NULL, NULL, 'non facturée', 'prête à l''envoi', 21, 100, 0.1960, 488.0100, 95.6500, 583.6600);
INSERT INTO commandes VALUES (3081, '2011-07-13 11:18:54.418195', '2011-07-18 19:20:54.418195', '2011-07-23 20:21:54.418195', 'payée', 'expédiée', 13, 5, 0.1960, -15.0000, -2.9400, -17.9400);
INSERT INTO commandes VALUES (3088, '2011-02-13 14:18:55.11761', '2011-02-18 22:20:55.11761', NULL, 'non facturée', 'expédiée', 17, 0, 0.1960, -10.0000, -1.9600, -11.9600);
INSERT INTO commandes VALUES (3082, '2011-02-14 10:15:54.453015', '2011-02-15 11:17:54.453015', NULL, 'non facturée', 'expédiée', 25, 100, 0.1960, 294.8900, 57.7984, 352.6884);
INSERT INTO commandes VALUES (3110, '2011-07-13 14:16:57.577352', NULL, '2011-07-14 15:25:57.577352', 'facturée', 'en préparation', 24, 15, 0.1960, 88.4300, 17.3323, 105.7623);
INSERT INTO commandes VALUES (3125, '2011-07-20 07:15:59.466719', '2011-07-22 15:19:59.466719', NULL, 'non facturée', 'expédiée', 13, 100, 0.1960, 499.9400, 97.9882, 597.9282);
INSERT INTO commandes VALUES (3098, '2011-09-14 10:15:56.243095', NULL, NULL, 'non facturée', 'en attente', 15, 100, 0.1960, 305.4200, 59.8623, 365.2823);
INSERT INTO commandes VALUES (3123, '2011-04-17 13:14:59.226897', NULL, '2011-04-27 14:17:59.226897', 'payée', 'en attente', 25, 15, 0.1960, 85.3900, 16.7364, 102.1264);
INSERT INTO commandes VALUES (3118, '2011-08-20 08:14:58.491351', '2011-08-21 17:22:58.491351', '2011-08-30 14:20:58.491351', 'facturée', 'expédiée', 24, 1000, 0.1960, 557.2500, 109.2210, 666.4710);
INSERT INTO commandes VALUES (3083, '2011-05-13 07:14:54.494644', NULL, '2011-05-18 17:23:54.494644', 'payée', 'en attente', 14, 100, 0.1960, 304.9300, 59.7663, 364.6963);
INSERT INTO commandes VALUES (3093, '2011-05-12 07:13:55.726898', NULL, '2011-05-14 12:15:55.726898', 'facturée', 'en préparation', 21, 100, 0.1960, 406.6300, 79.6995, 486.3295);
INSERT INTO commandes VALUES (3089, '2010-12-19 14:17:55.135642', '2010-12-20 20:25:55.135642', NULL, 'non facturée', 'expédiée', 22, 100, 0.1960, 453.7900, 88.9428, 542.7328);
INSERT INTO commandes VALUES (3084, '2011-08-17 11:12:54.661177', '2011-08-20 14:20:54.661177', '2011-08-22 12:19:54.661177', 'payée', 'expédiée', 22, 15, 0.1960, 83.6900, 16.4032, 100.0932);
INSERT INTO commandes VALUES (3111, '2011-01-20 07:17:57.64268', NULL, '2011-01-28 10:20:57.64268', 'facturée', 'en attente', 25, 100, 0.1960, 334.1100, 65.4856, 399.5956);
INSERT INTO commandes VALUES (3103, '2011-04-13 09:15:56.769318', '2011-04-16 11:22:56.769318', NULL, 'non facturée', 'expédiée', 26, 1000, 0.1960, 521.9300, 102.2983, 624.2283);
INSERT INTO commandes VALUES (3099, '2011-07-13 08:10:56.403702', '2011-07-22 12:14:56.403702', NULL, 'non facturée', 'expédiée', 17, 100, 0.1960, 364.9700, 71.5341, 436.5041);
INSERT INTO commandes VALUES (3094, '2011-04-15 11:11:55.893654', NULL, '2011-04-24 18:15:55.893654', 'facturée', 'en attente', 23, 50, 0.1960, 135.6800, 26.5933, 162.2733);
INSERT INTO commandes VALUES (3085, '2011-02-11 14:17:54.719481', NULL, NULL, 'non facturée', 'prête à l''envoi', 16, 100, 0.1960, 372.9900, 73.1060, 446.0960);
INSERT INTO commandes VALUES (3100, '2011-05-15 15:11:56.486514', '2011-05-24 20:15:56.486514', '2011-05-22 20:13:56.486514', 'facturée', 'expédiée', 23, 5, 0.1960, 2.9900, 0.5860, 3.5760);
INSERT INTO commandes VALUES (3090, '2010-12-19 12:16:55.293937', '2010-12-23 21:23:55.293937', '2010-12-26 20:25:55.293937', 'facturée', 'expédiée', 13, 1000, 0.1960, 532.0600, 104.2838, 636.3438);
INSERT INTO commandes VALUES (3107, '2011-05-20 06:17:57.209223', '2011-05-28 10:23:57.209223', '2011-05-30 14:26:57.209223', 'facturée', 'expédiée', 24, 100, 0.1960, 422.8100, 82.8708, 505.6808);
INSERT INTO commandes VALUES (3113, '2011-04-15 10:09:57.909862', '2011-04-16 19:14:57.909862', NULL, 'non facturée', 'expédiée', 13, 1000, 0.1960, 511.9400, 100.3402, 612.2802);
INSERT INTO commandes VALUES (3124, '2011-04-19 09:13:59.317639', '2011-04-22 19:14:59.317639', '2011-04-21 11:23:59.317639', 'payée', 'expédiée', 14, 1000, 0.1960, 541.4100, 106.1164, 647.5264);
INSERT INTO commandes VALUES (3095, '2011-05-17 14:16:55.993875', NULL, NULL, 'non facturée', 'prête à l''envoi', 13, 100, 0.1960, 441.4300, 86.5203, 527.9503);
INSERT INTO commandes VALUES (3101, '2011-02-20 09:14:56.517936', '2011-02-26 18:16:56.517936', '2011-03-02 19:18:56.517936', 'facturée', 'expédiée', 24, 100, 0.1960, 214.7700, 42.0949, 256.8649);
INSERT INTO commandes VALUES (3120, '2011-01-12 13:17:58.767549', '2011-01-14 18:23:58.767549', '2011-01-18 20:24:58.767549', 'payée', 'expédiée', 24, 100, 0.1960, 494.7700, 96.9749, 591.7449);
INSERT INTO commandes VALUES (3104, '2011-09-13 15:12:56.950895', NULL, '2011-09-15 17:16:56.950895', 'facturée', 'prête à l''envoi', 26, 100, 0.1960, 343.9600, 67.4162, 411.3762);
INSERT INTO commandes VALUES (3114, '2011-09-15 07:09:58.041888', '2011-09-25 16:19:58.041888', NULL, 'non facturée', 'expédiée', 14, 100, 0.1960, 323.9200, 63.4883, 387.4083);
INSERT INTO commandes VALUES (3108, '2010-12-15 11:09:57.360317', NULL, '2010-12-22 15:18:57.360317', 'facturée', 'prête à l''envoi', 25, 100, 0.1960, 284.1900, 55.7012, 339.8912);
INSERT INTO commandes VALUES (3116, '2011-07-11 15:10:58.316352', '2011-07-17 21:19:58.316352', '2011-07-15 00:18:58.316352', 'payée', 'expédiée', 21, 100, 0.1960, 387.1700, 75.8853, 463.0553);
INSERT INTO commandes VALUES (3105, '2011-01-11 09:09:57.017597', '2011-01-12 19:19:57.017597', '2011-01-21 17:10:57.017597', 'payée', 'expédiée', 26, 15, 0.1960, 93.1900, 18.2652, 111.4552);
INSERT INTO commandes VALUES (3129, '2011-03-15 08:18:59.908041', '2011-03-18 13:19:59.908041', '2011-03-21 11:27:59.908041', 'payée', 'expédiée', 17, 1000, 0.1960, 528.7400, 103.6330, 632.3730);
INSERT INTO commandes VALUES (3109, '2011-02-19 07:14:57.508504', '2011-02-25 14:24:57.508504', '2011-03-01 15:17:57.508504', 'facturée', 'expédiée', 23, 100, 0.1960, 272.8900, 53.4864, 326.3764);
INSERT INTO commandes VALUES (3117, '2011-03-12 08:10:58.457757', NULL, '2011-03-16 11:14:58.457757', 'payée', 'en attente', 26, 5, 0.1960, -15.0000, -2.9400, -17.9400);
INSERT INTO commandes VALUES (3112, '2011-09-11 10:18:57.758639', '2011-09-13 13:21:57.758639', NULL, 'non facturée', 'expédiée', 13, 100, 0.1960, 362.3900, 71.0284, 433.4184);
INSERT INTO commandes VALUES (3119, '2011-06-11 08:17:58.67453', NULL, NULL, 'non facturée', 'prête à l''envoi', 14, 100, 0.1960, 292.1500, 57.2614, 349.4114);
INSERT INTO commandes VALUES (3131, '2011-04-16 12:19:00.215744', '2011-04-22 18:20:00.215744', NULL, 'non facturée', 'expédiée', 13, 1000, 0.1960, 522.9500, 102.4982, 625.4482);
INSERT INTO commandes VALUES (3130, '2011-05-16 15:19:00.173468', NULL, '2011-05-21 16:22:00.173468', 'payée', 'en préparation', 21, 15, 0.1960, 86.9000, 17.0324, 103.9324);
INSERT INTO commandes VALUES (3122, '2011-01-17 09:17:59.083588', NULL, NULL, 'non facturée', 'en préparation', 25, 100, 0.1960, 420.3200, 82.3827, 502.7027);
INSERT INTO commandes VALUES (3126, '2011-05-16 13:13:59.640002', NULL, NULL, 'non facturée', 'en préparation', 15, 50, 0.1960, 130.8300, 25.6427, 156.4727);
INSERT INTO commandes VALUES (3128, '2011-04-19 09:13:59.783033', '2011-04-24 19:22:59.783033', NULL, 'non facturée', 'expédiée', 24, 100, 0.1960, 207.5400, 40.6778, 248.2178);
INSERT INTO commandes VALUES (3127, '2011-02-12 09:12:59.748463', '2011-02-14 17:18:59.748463', NULL, 'non facturée', 'expédiée', 17, 5, 0.1960, -15.0000, -2.9400, -17.9400);
INSERT INTO commandes VALUES (3132, '2011-01-11 14:15:00.372821', '2011-01-21 22:17:00.372821', NULL, 'non facturée', 'expédiée', 26, 15, 0.1960, 64.5900, 12.6596, 77.2496);
INSERT INTO commandes VALUES (3156, '2011-07-16 12:15:02.7221', NULL, NULL, 'non facturée', 'en attente', 13, 1000, 0.1960, 645.2400, 126.4670, 771.7070);
INSERT INTO commandes VALUES (3162, '2011-08-12 11:15:03.348985', '2011-08-15 15:22:03.348985', '2011-08-19 17:21:03.348985', 'payée', 'expédiée', 26, 15, 0.1960, 58.7400, 11.5130, 70.2530);
INSERT INTO commandes VALUES (3148, '2011-05-20 11:19:01.706483', '2011-05-29 18:23:01.706483', NULL, 'non facturée', 'expédiée', 25, 100, 0.1960, 326.8900, 64.0704, 390.9604);
INSERT INTO commandes VALUES (3140, '2010-12-13 06:19:01.081883', '2010-12-14 13:25:01.081883', NULL, 'non facturée', 'expédiée', 25, 50, 0.1960, 119.0200, 23.3279, 142.3479);
INSERT INTO commandes VALUES (3157, '2011-08-17 12:17:02.886917', '2011-08-18 16:27:02.886917', '2011-08-23 21:25:02.886917', 'facturée', 'expédiée', 26, 5, 0.1960, 36.9900, 7.2500, 44.2400);
INSERT INTO commandes VALUES (3133, '2010-12-15 07:12:00.424301', '2010-12-22 16:16:00.424301', '2010-12-23 15:18:00.424301', 'payée', 'expédiée', 25, 100, 0.1960, 391.6400, 76.7614, 468.4014);
INSERT INTO commandes VALUES (3152, '2011-04-19 12:12:02.280748', NULL, NULL, 'non facturée', 'prête à l''envoi', 15, 100, 0.1960, 443.6800, 86.9613, 530.6413);
INSERT INTO commandes VALUES (3153, '2011-04-13 10:14:02.405961', '2011-04-17 19:21:02.405961', NULL, 'non facturée', 'expédiée', 14, 0, 0.1960, 5.7900, 1.1348, 6.9248);
INSERT INTO commandes VALUES (3141, '2011-01-11 14:19:01.213566', NULL, NULL, 'non facturée', 'en attente', 16, 100, 0.1960, 336.6000, 65.9736, 402.5736);
INSERT INTO commandes VALUES (3079, '2010-12-14 10:14:54.102568', NULL, NULL, 'non facturée', 'en attente', 26, 1000, 0.1960, 525.1000, 102.9196, 628.0196);
INSERT INTO commandes VALUES (3134, '2011-08-13 10:10:00.59045', '2011-08-18 11:12:00.59045', '2011-08-19 20:16:00.59045', 'payée', 'expédiée', 17, 100, 0.1960, 387.6200, 75.9735, 463.5935);
INSERT INTO commandes VALUES (3142, '2011-05-11 09:12:01.298164', NULL, NULL, 'non facturée', 'en attente', 17, 5, 0.1960, 7.0400, 1.3798, 8.4198);
INSERT INTO commandes VALUES (3158, '2011-05-11 09:19:02.945262', NULL, '2011-05-17 18:26:02.945262', 'payée', 'en préparation', 16, 15, 0.1960, 53.9000, 10.5644, 64.4644);
INSERT INTO commandes VALUES (3143, '2011-05-19 12:13:01.332101', '2011-05-27 22:17:01.332101', NULL, 'non facturée', 'expédiée', 13, 5, 0.1960, 26.7100, 5.2352, 31.9452);
INSERT INTO commandes VALUES (3144, '2011-08-18 15:18:01.373531', '2011-08-24 21:22:01.373531', NULL, 'non facturée', 'expédiée', 17, 0, 0.1960, 5.9400, 1.1642, 7.1042);
INSERT INTO commandes VALUES (3149, '2011-04-14 09:18:01.823773', NULL, '2011-04-15 11:26:01.823773', 'facturée', 'prête à l''envoi', 22, 100, 0.1960, 261.6900, 51.2912, 312.9812);
INSERT INTO commandes VALUES (3135, '2011-03-13 12:12:00.657481', '2011-03-23 22:20:00.657481', '2011-03-19 15:15:00.657481', 'payée', 'expédiée', 26, 100, 0.1960, 471.1200, 92.3395, 563.4595);
INSERT INTO commandes VALUES (3136, '2010-12-18 15:11:00.790607', NULL, '2010-12-20 21:15:00.790607', 'payée', 'prête à l''envoi', 23, 5, 0.1960, 34.8000, 6.8208, 41.6208);
INSERT INTO commandes VALUES (3154, '2011-04-11 10:15:02.431977', '2011-04-18 17:17:02.431977', NULL, 'non facturée', 'expédiée', 15, 50, 0.1960, 107.0400, 20.9798, 128.0198);
INSERT INTO commandes VALUES (3145, '2011-02-12 14:17:01.390097', NULL, '2011-02-21 15:24:01.390097', 'facturée', 'en préparation', 14, 100, 0.1960, 352.6300, 69.1155, 421.7455);
INSERT INTO commandes VALUES (3150, '2011-07-12 10:16:01.947685', '2011-07-22 14:23:01.947685', '2011-07-20 19:21:01.947685', 'payée', 'expédiée', 23, 100, 0.1960, 284.7100, 55.8032, 340.5132);
INSERT INTO commandes VALUES (3137, '2011-09-18 11:17:00.848602', NULL, NULL, 'non facturée', 'prête à l''envoi', 13, 100, 0.1960, 376.3900, 73.7724, 450.1624);
INSERT INTO commandes VALUES (3163, '2011-03-19 14:16:03.471168', NULL, '2011-03-21 15:24:03.471168', 'facturée', 'en préparation', 26, 100, 0.1960, 289.3000, 56.7028, 346.0028);
INSERT INTO commandes VALUES (3138, '2011-01-19 07:11:01.015201', NULL, NULL, 'non facturée', 'en attente', 22, 5, 0.1960, -2.0300, -0.3979, -2.4279);
INSERT INTO commandes VALUES (3159, '2011-08-20 11:13:02.988456', '2011-08-30 13:17:02.988456', '2011-08-28 13:22:02.988456', 'payée', 'expédiée', 24, 100, 0.1960, 349.7400, 68.5490, 418.2890);
INSERT INTO commandes VALUES (3139, '2011-06-20 13:18:01.048521', '2011-06-28 17:19:01.048521', NULL, 'non facturée', 'expédiée', 26, 5, 0.1960, 34.9000, 6.8404, 41.7404);
INSERT INTO commandes VALUES (3155, '2011-07-14 08:10:02.554187', NULL, NULL, 'non facturée', 'prête à l''envoi', 23, 100, 0.1960, 341.2600, 66.8870, 408.1470);
INSERT INTO commandes VALUES (3160, '2011-09-14 09:12:03.14658', NULL, NULL, 'non facturée', 'en préparation', 13, 5, 0.1960, 18.9500, 3.7142, 22.6642);
INSERT INTO commandes VALUES (3146, '2011-03-19 10:15:01.531372', '2011-03-21 13:19:01.531372', NULL, 'non facturée', 'expédiée', 23, 1000, 0.1960, 504.1300, 98.8095, 602.9395);
INSERT INTO commandes VALUES (3147, '2011-09-11 14:11:01.699196', NULL, NULL, 'non facturée', 'en préparation', 14, 0, 0.1960, NULL, NULL, NULL);
INSERT INTO commandes VALUES (3151, '2011-06-19 07:13:02.116928', NULL, '2011-06-22 12:19:02.116928', 'facturée', 'prête à l''envoi', 15, 100, 0.1960, 408.7300, 80.1111, 488.8411);
INSERT INTO commandes VALUES (3161, '2011-09-20 11:15:03.179862', NULL, NULL, 'non facturée', 'en préparation', 14, 15, 0.1960, 64.3000, 12.6028, 76.9028);
INSERT INTO commandes VALUES (3164, '2011-02-17 12:11:03.638787', '2011-02-22 14:18:03.638787', NULL, 'non facturée', 'expédiée', 22, 100, 0.1960, 244.6100, 47.9436, 292.5536);
INSERT INTO commandes VALUES (3165, '2011-09-11 07:14:03.771623', '2011-09-20 16:15:03.771623', NULL, 'non facturée', 'expédiée', 23, 50, 0.1960, 102.4000, 20.0704, 122.4704);
INSERT INTO commandes VALUES (3220, '2011-01-17 13:18:09.889644', '2011-01-19 14:21:09.889644', '2011-01-24 21:22:09.889644', 'payée', 'expédiée', 26, 100, 0.1960, 209.1200, 40.9875, 250.1075);
INSERT INTO commandes VALUES (3214, '2011-09-16 10:19:09.231801', NULL, '2011-09-21 16:20:09.231801', 'payée', 'en attente', 15, 50, 0.1960, 119.7800, 23.4769, 143.2569);
INSERT INTO commandes VALUES (3188, '2011-02-13 07:11:06.586555', NULL, '2011-02-22 15:14:06.586555', 'facturée', 'prête à l''envoi', 24, 100, 0.1960, 365.4900, 71.6360, 437.1260);
INSERT INTO commandes VALUES (3180, '2011-03-17 06:15:05.376373', '2011-03-18 09:17:05.376373', NULL, 'non facturée', 'expédiée', 24, 100, 0.1960, 293.2600, 57.4790, 350.7390);
INSERT INTO commandes VALUES (3184, '2011-01-15 12:17:06.025384', NULL, '2011-01-22 14:24:06.025384', 'facturée', 'en attente', 15, 100, 0.1960, 357.7400, 70.1170, 427.8570);
INSERT INTO commandes VALUES (3166, '2011-05-14 15:17:03.836136', NULL, '2011-05-24 23:25:03.836136', 'facturée', 'en attente', 25, 100, 0.1960, 387.6200, 75.9735, 463.5935);
INSERT INTO commandes VALUES (3174, '2011-05-14 08:17:04.811343', NULL, NULL, 'non facturée', 'en attente', 26, 100, 0.1960, 334.2200, 65.5071, 399.7271);
INSERT INTO commandes VALUES (3167, '2011-09-17 08:13:04.162317', NULL, NULL, 'non facturée', 'en préparation', 22, 5, 0.1960, -15.0000, -2.9400, -17.9400);
INSERT INTO commandes VALUES (3168, '2011-07-19 10:10:04.193809', '2011-07-25 16:11:04.193809', NULL, 'non facturée', 'expédiée', 26, 50, 0.1960, 169.9400, 33.3082, 203.2482);
INSERT INTO commandes VALUES (3206, '2011-04-19 08:11:08.582602', NULL, NULL, 'non facturée', 'en attente', 22, 100, 0.1960, 474.8600, 93.0726, 567.9326);
INSERT INTO commandes VALUES (3175, '2011-02-16 06:12:04.952767', '2011-02-25 14:21:04.952767', '2011-02-17 14:22:04.952767', 'payée', 'expédiée', 16, 15, 0.1960, 88.6200, 17.3695, 105.9895);
INSERT INTO commandes VALUES (3210, '2011-01-12 10:19:08.899799', '2011-01-17 13:23:08.899799', NULL, 'non facturée', 'expédiée', 24, 100, 0.1960, 249.6800, 48.9373, 298.6173);
INSERT INTO commandes VALUES (3189, '2011-01-11 14:19:06.74981', NULL, NULL, 'non facturée', 'prête à l''envoi', 21, 100, 0.1960, 373.6300, 73.2315, 446.8615);
INSERT INTO commandes VALUES (3181, '2011-09-14 15:11:05.527403', '2011-09-23 22:13:05.527403', '2011-09-22 19:14:05.527403', 'payée', 'expédiée', 22, 50, 0.1960, 117.8700, 23.1025, 140.9725);
INSERT INTO commandes VALUES (3195, '2011-05-18 09:15:07.166007', '2011-05-21 17:17:07.166007', NULL, 'non facturée', 'expédiée', 23, 100, 0.1960, 421.2400, 82.5630, 503.8030);
INSERT INTO commandes VALUES (3169, '2011-03-19 13:17:04.229497', '2011-03-27 20:24:04.229497', NULL, 'non facturée', 'expédiée', 14, 100, 0.1960, 494.6100, 96.9436, 591.5536);
INSERT INTO commandes VALUES (3190, '2011-05-19 13:15:06.824822', '2011-05-29 14:25:06.824822', '2011-05-25 22:24:06.824822', 'payée', 'expédiée', 21, 5, 0.1960, 24.4300, 4.7883, 29.2183);
INSERT INTO commandes VALUES (3185, '2011-05-11 14:18:06.133639', '2011-05-12 23:28:06.133639', '2011-05-19 16:19:06.133639', 'payée', 'expédiée', 16, 100, 0.1960, 498.1700, 97.6413, 595.8113);
INSERT INTO commandes VALUES (3176, '2011-01-18 12:13:05.01177', '2011-01-19 17:17:05.01177', NULL, 'non facturée', 'expédiée', 25, 100, 0.1960, 367.0700, 71.9457, 439.0157);
INSERT INTO commandes VALUES (3217, '2011-02-15 13:12:09.515019', NULL, '2011-02-25 23:19:09.515019', 'facturée', 'prête à l''envoi', 26, 100, 0.1960, 468.2400, 91.7750, 560.0150);
INSERT INTO commandes VALUES (3202, '2011-01-17 08:14:07.998507', '2011-01-25 15:18:07.998507', '2011-01-20 17:20:07.998507', 'facturée', 'expédiée', 24, 1000, 0.1960, 518.7700, 101.6789, 620.4489);
INSERT INTO commandes VALUES (3170, '2011-05-13 06:16:04.427458', '2011-05-14 13:25:04.427458', NULL, 'non facturée', 'expédiée', 26, 1000, 0.1960, 562.9600, 110.3402, 673.3002);
INSERT INTO commandes VALUES (3199, '2011-06-14 14:12:07.683853', '2011-06-23 15:22:07.683853', NULL, 'non facturée', 'expédiée', 22, 1000, 0.1960, 533.5100, 104.5680, 638.0780);
INSERT INTO commandes VALUES (3171, '2011-02-19 14:16:04.552047', NULL, NULL, 'non facturée', 'prête à l''envoi', 23, 15, 0.1960, 98.0400, 19.2158, 117.2558);
INSERT INTO commandes VALUES (3172, '2011-01-13 08:10:04.58711', '2011-01-21 15:20:04.58711', NULL, 'non facturée', 'expédiée', 14, 5, 0.1960, 30.9200, 6.0603, 36.9803);
INSERT INTO commandes VALUES (3182, '2010-12-11 07:12:05.687557', '2010-12-15 09:17:05.687557', NULL, 'non facturée', 'expédiée', 22, 100, 0.1960, 437.0400, 85.6598, 522.6998);
INSERT INTO commandes VALUES (3177, '2011-04-17 12:13:05.169474', NULL, NULL, 'non facturée', 'prête à l''envoi', 25, 50, 0.1960, 130.3500, 25.5486, 155.8986);
INSERT INTO commandes VALUES (3204, '2011-02-17 13:16:08.382656', '2011-02-23 21:26:08.382656', NULL, 'non facturée', 'expédiée', 24, 100, 0.1960, 204.8700, 40.1545, 245.0245);
INSERT INTO commandes VALUES (3196, '2011-04-13 06:11:07.340694', NULL, NULL, 'non facturée', 'en attente', 21, 50, 0.1960, 119.0700, 23.3377, 142.4077);
INSERT INTO commandes VALUES (3186, '2010-12-20 07:12:06.267592', '2010-12-30 13:22:06.267592', NULL, 'non facturée', 'expédiée', 16, 100, 0.1960, 262.6200, 51.4735, 314.0935);
INSERT INTO commandes VALUES (3178, '2011-01-20 11:18:05.285952', '2011-01-26 14:19:05.285952', '2011-01-21 13:27:05.285952', 'facturée', 'expédiée', 13, 100, 0.1960, 301.4500, 59.0842, 360.5342);
INSERT INTO commandes VALUES (3179, '2011-09-11 06:18:05.343105', NULL, '2011-09-14 13:26:05.343105', 'facturée', 'en attente', 14, 15, 0.1960, 50.8100, 9.9588, 60.7688);
INSERT INTO commandes VALUES (3191, '2011-07-16 12:11:06.882854', NULL, NULL, 'non facturée', 'en préparation', 13, 15, 0.1960, 72.4500, 14.2002, 86.6502);
INSERT INTO commandes VALUES (3173, '2011-05-13 12:18:04.626847', '2011-05-20 13:23:04.626847', NULL, 'non facturée', 'expédiée', 16, 1000, 0.1960, 528.9300, 103.6703, 632.6003);
INSERT INTO commandes VALUES (3215, '2010-12-19 07:16:09.313711', NULL, NULL, 'non facturée', 'en attente', 24, 5, 0.1960, 10.9600, 2.1482, 13.1082);
INSERT INTO commandes VALUES (3187, '2011-08-16 08:19:06.491517', '2011-08-17 12:25:06.491517', NULL, 'non facturée', 'expédiée', 17, 15, 0.1960, 86.0400, 16.8638, 102.9038);
INSERT INTO commandes VALUES (3192, '2010-12-11 14:15:07.007661', '2010-12-16 16:25:07.007661', '2010-12-19 20:21:07.007661', 'payée', 'expédiée', 15, 50, 0.1960, 144.9200, 28.4043, 173.3243);
INSERT INTO commandes VALUES (3183, '2011-05-12 10:11:05.863508', NULL, '2011-05-17 15:16:05.863508', 'facturée', 'en préparation', 25, 100, 0.1960, 433.4600, 84.9582, 518.4182);
INSERT INTO commandes VALUES (3200, '2011-04-20 08:13:07.84885', NULL, NULL, 'non facturée', 'en préparation', 17, 50, 0.1960, 117.3000, 22.9908, 140.2908);
INSERT INTO commandes VALUES (3205, '2011-07-12 08:16:08.533888', NULL, '2011-07-16 13:26:08.533888', 'payée', 'prête à l''envoi', 21, 5, 0.1960, 19.9300, 3.9063, 23.8363);
INSERT INTO commandes VALUES (3193, '2011-03-11 13:15:07.067407', '2011-03-17 21:25:07.067407', NULL, 'non facturée', 'expédiée', 22, 15, 0.1960, 63.9000, 12.5244, 76.4244);
INSERT INTO commandes VALUES (3194, '2011-04-20 15:12:07.157441', NULL, '2011-04-28 00:18:07.157441', 'payée', 'en attente', 17, 0, 0.1960, NULL, NULL, NULL);
INSERT INTO commandes VALUES (3212, '2011-05-15 09:12:09.057255', NULL, '2011-05-16 18:20:09.057255', 'facturée', 'en préparation', 26, 100, 0.1960, 342.6300, 67.1555, 409.7855);
INSERT INTO commandes VALUES (3201, '2010-12-20 13:18:07.931791', '2010-12-22 21:22:07.931791', '2010-12-30 21:24:07.931791', 'facturée', 'expédiée', 24, 50, 0.1960, 154.2800, 30.2389, 184.5189);
INSERT INTO commandes VALUES (3197, '2011-03-18 14:16:07.452105', NULL, '2011-03-27 21:21:07.452105', 'payée', 'en attente', 24, 100, 0.1960, 305.7800, 59.9329, 365.7129);
INSERT INTO commandes VALUES (3213, '2011-06-17 08:15:09.215346', '2011-06-19 13:22:09.215346', '2011-06-18 13:19:09.215346', 'facturée', 'expédiée', 17, 0, 0.1960, -5.0000, -0.9800, -5.9800);
INSERT INTO commandes VALUES (3198, '2011-07-15 08:18:07.641784', '2011-07-18 10:23:07.641784', '2011-07-19 11:28:07.641784', 'payée', 'expédiée', 14, 5, 0.1960, 16.4300, 3.2203, 19.6503);
INSERT INTO commandes VALUES (3211, '2010-12-11 06:12:08.949599', NULL, NULL, 'non facturée', 'prête à l''envoi', 14, 100, 0.1960, 258.5800, 50.6817, 309.2617);
INSERT INTO commandes VALUES (3207, '2010-12-15 09:13:08.70735', NULL, NULL, 'non facturée', 'en préparation', 17, 100, 0.1960, 476.8800, 93.4685, 570.3485);
INSERT INTO commandes VALUES (3203, '2011-04-14 15:11:08.141369', NULL, NULL, 'non facturée', 'en préparation', 21, 100, 0.1960, 415.5800, 81.4537, 497.0337);
INSERT INTO commandes VALUES (3208, '2010-12-17 08:19:08.84887', '2010-12-18 17:28:08.84887', NULL, 'non facturée', 'expédiée', 22, 0, 0.1960, NULL, NULL, NULL);
INSERT INTO commandes VALUES (3219, '2011-07-16 08:18:09.847929', NULL, '2011-07-19 16:26:09.847929', 'payée', 'en préparation', 14, 100, 0.1960, 295.8800, 57.9925, 353.8725);
INSERT INTO commandes VALUES (3209, '2011-09-19 07:16:08.85812', '2011-09-26 10:22:08.85812', '2011-09-26 10:21:08.85812', 'facturée', 'expédiée', 14, 5, 0.1960, 13.0600, 2.5598, 15.6198);
INSERT INTO commandes VALUES (3216, '2011-09-16 14:14:09.356828', '2011-09-22 16:21:09.356828', '2011-09-26 18:21:09.356828', 'facturée', 'expédiée', 26, 100, 0.1960, 447.7100, 87.7512, 535.4612);
INSERT INTO commandes VALUES (3221, '2011-05-18 13:18:09.963206', '2011-05-28 19:21:09.963206', '2011-05-22 14:22:09.963206', 'payée', 'expédiée', 23, 100, 0.1960, 370.0700, 72.5337, 442.6037);
INSERT INTO commandes VALUES (3218, '2011-01-20 11:12:09.681536', NULL, '2011-01-30 19:22:09.681536', 'payée', 'en préparation', 14, 100, 0.1960, 253.2800, 49.6429, 302.9229);
INSERT INTO commandes VALUES (3223, '2011-07-15 12:12:10.196346', '2011-07-16 14:17:10.196346', NULL, 'non facturée', 'expédiée', 17, 5, 0.1960, -13.0200, -2.5519, -15.5719);
INSERT INTO commandes VALUES (3222, '2010-12-14 15:17:10.131092', NULL, NULL, 'non facturée', 'prête à l''envoi', 21, 15, 0.1960, 73.0400, 14.3158, 87.3558);
INSERT INTO commandes VALUES (3250, '2011-01-20 15:14:13.662504', '2011-01-29 16:19:13.662504', NULL, 'non facturée', 'expédiée', 24, 100, 0.1960, 353.7400, 69.3330, 423.0730);
INSERT INTO commandes VALUES (3240, '2011-09-19 13:14:12.502245', '2011-09-23 21:16:12.502245', NULL, 'non facturée', 'expédiée', 15, 100, 0.1960, 356.7400, 69.9210, 426.6610);
INSERT INTO commandes VALUES (3266, '2011-01-16 13:17:15.452453', '2011-01-18 20:18:15.452453', '2011-01-18 17:21:15.452453', 'facturée', 'expédiée', 26, 100, 0.1960, 305.6800, 59.9133, 365.5933);
INSERT INTO commandes VALUES (3245, '2010-12-19 07:17:13.045881', '2010-12-24 14:26:13.045881', NULL, 'non facturée', 'expédiée', 26, 1000, 0.1960, 527.2000, 103.3312, 630.5312);
INSERT INTO commandes VALUES (3236, '2011-04-16 13:17:11.920285', NULL, '2011-04-21 21:18:11.920285', 'payée', 'prête à l''envoi', 25, 100, 0.1960, 349.9300, 68.5863, 418.5163);
INSERT INTO commandes VALUES (3260, '2011-08-18 15:13:14.745334', NULL, '2011-08-20 23:21:14.745334', 'facturée', 'prête à l''envoi', 14, 100, 0.1960, 206.1000, 40.3956, 246.4956);
INSERT INTO commandes VALUES (3224, '2011-05-11 12:10:10.237887', '2011-05-19 19:18:10.237887', '2011-05-18 20:20:10.237887', 'payée', 'expédiée', 26, 1000, 0.1960, 530.4500, 103.9682, 634.4182);
INSERT INTO commandes VALUES (3231, '2011-06-18 11:18:11.013673', '2011-06-19 17:19:11.013673', NULL, 'non facturée', 'expédiée', 17, 1000, 0.1960, 581.5400, 113.9818, 695.5218);
INSERT INTO commandes VALUES (3225, '2011-07-17 12:10:10.414246', NULL, '2011-07-19 19:20:10.414246', 'payée', 'en préparation', 24, 100, 0.1960, 292.3900, 57.3084, 349.6984);
INSERT INTO commandes VALUES (3256, '2010-12-19 12:13:14.381202', NULL, '2010-12-28 22:23:14.381202', 'payée', 'en attente', 13, 100, 0.1960, 475.4900, 93.1960, 568.6860);
INSERT INTO commandes VALUES (3241, '2011-06-18 11:10:12.597048', NULL, NULL, 'non facturée', 'en préparation', 17, 100, 0.1960, 247.9300, 48.5943, 296.5243);
INSERT INTO commandes VALUES (3263, '2011-07-19 10:11:15.002786', NULL, '2011-07-22 15:16:15.002786', 'payée', 'prête à l''envoi', 23, 50, 0.1960, 136.3600, 26.7266, 163.0866);
INSERT INTO commandes VALUES (3226, '2011-02-18 09:10:10.472499', '2011-02-27 16:17:10.472499', NULL, 'non facturée', 'expédiée', 21, 100, 0.1960, 287.6900, 56.3872, 344.0772);
INSERT INTO commandes VALUES (3261, '2011-01-15 10:10:14.828986', '2011-01-18 13:12:14.828986', '2011-01-25 15:12:14.828986', 'payée', 'expédiée', 26, 50, 0.1960, 116.7400, 22.8810, 139.6210);
INSERT INTO commandes VALUES (3246, '2011-07-11 15:10:13.22497', NULL, '2011-07-21 00:12:13.22497', 'facturée', 'en attente', 25, 100, 0.1960, 320.5400, 62.8258, 383.3658);
INSERT INTO commandes VALUES (3237, '2011-04-16 08:10:12.062496', '2011-04-18 17:17:12.062496', '2011-04-23 14:16:12.062496', 'facturée', 'expédiée', 17, 100, 0.1960, 299.2500, 58.6530, 357.9030);
INSERT INTO commandes VALUES (3227, '2011-08-16 13:12:10.571216', NULL, '2011-08-26 20:18:10.571216', 'facturée', 'prête à l''envoi', 15, 5, 0.1960, 49.9000, 9.7804, 59.6804);
INSERT INTO commandes VALUES (3232, '2011-07-20 11:12:11.463308', NULL, '2011-07-23 12:20:11.463308', 'payée', 'prête à l''envoi', 14, 100, 0.1960, 381.1500, 74.7054, 455.8554);
INSERT INTO commandes VALUES (3254, '2011-03-16 15:14:14.077278', NULL, NULL, 'non facturée', 'prête à l''envoi', 14, 100, 0.1960, 317.5800, 62.2457, 379.8257);
INSERT INTO commandes VALUES (3257, '2011-01-17 11:12:14.520393', '2011-01-20 16:15:14.520393', NULL, 'non facturée', 'expédiée', 13, 5, 0.1960, 32.3800, 6.3465, 38.7265);
INSERT INTO commandes VALUES (3228, '2011-06-18 11:16:10.638788', NULL, '2011-06-28 18:24:10.638788', 'payée', 'en attente', 15, 50, 0.1960, 132.5600, 25.9818, 158.5418);
INSERT INTO commandes VALUES (3251, '2011-07-20 09:12:13.729277', NULL, '2011-07-21 10:20:13.729277', 'payée', 'en attente', 15, 100, 0.1960, 418.6200, 82.0495, 500.6695);
INSERT INTO commandes VALUES (3242, '2011-09-18 07:19:12.713446', '2011-09-20 13:20:12.713446', NULL, 'non facturée', 'expédiée', 17, 1000, 0.1960, 512.2600, 100.4030, 612.6630);
INSERT INTO commandes VALUES (3233, '2011-02-13 10:19:11.637785', NULL, NULL, 'non facturée', 'en attente', 26, 100, 0.1960, 207.3800, 40.6465, 248.0265);
INSERT INTO commandes VALUES (3243, '2011-09-20 06:14:12.886953', '2011-09-22 12:15:12.886953', NULL, 'non facturée', 'expédiée', 21, 5, 0.1960, -0.5100, -0.1000, -0.6100);
INSERT INTO commandes VALUES (3229, '2011-02-15 10:13:10.764059', NULL, '2011-02-17 18:17:10.764059', 'facturée', 'prête à l''envoi', 24, 15, 0.1960, 84.4300, 16.5483, 100.9783);
INSERT INTO commandes VALUES (3238, '2010-12-18 08:12:12.230032', NULL, NULL, 'non facturée', 'prête à l''envoi', 26, 100, 0.1960, 229.9700, 45.0741, 275.0441);
INSERT INTO commandes VALUES (3252, '2011-06-16 09:15:13.87905', NULL, '2011-06-25 17:25:13.87905', 'facturée', 'prête à l''envoi', 23, 5, 0.1960, 40.8400, 8.0046, 48.8446);
INSERT INTO commandes VALUES (3234, '2011-05-17 08:12:11.738148', '2011-05-22 11:15:11.738148', '2011-05-25 09:17:11.738148', 'payée', 'expédiée', 26, 100, 0.1960, 346.1400, 67.8434, 413.9834);
INSERT INTO commandes VALUES (3274, '2011-01-18 12:17:16.285225', NULL, NULL, 'non facturée', 'en attente', 17, 0, 0.1960, -5.0000, -0.9800, -5.9800);
INSERT INTO commandes VALUES (3239, '2010-12-13 08:15:12.370139', '2010-12-21 16:18:12.370139', '2010-12-19 10:21:12.370139', 'payée', 'expédiée', 15, 100, 0.1960, 241.5500, 47.3438, 288.8938);
INSERT INTO commandes VALUES (3230, '2011-04-11 11:13:10.855463', NULL, NULL, 'non facturée', 'prête à l''envoi', 14, 1000, 0.1960, 565.9500, 110.9262, 676.8762);
INSERT INTO commandes VALUES (3247, '2010-12-18 09:12:13.396026', NULL, NULL, 'non facturée', 'en préparation', 23, 100, 0.1960, 310.9100, 60.9384, 371.8484);
INSERT INTO commandes VALUES (3235, '2011-06-15 15:19:11.837594', '2011-06-22 21:27:11.837594', NULL, 'non facturée', 'expédiée', 26, 50, 0.1960, 159.7200, 31.3051, 191.0251);
INSERT INTO commandes VALUES (3244, '2011-04-17 09:19:12.920218', '2011-04-23 19:28:12.920218', NULL, 'non facturée', 'expédiée', 24, 100, 0.1960, 235.0200, 46.0639, 281.0839);
INSERT INTO commandes VALUES (3265, '2011-05-20 12:18:15.277933', NULL, NULL, 'non facturée', 'prête à l''envoi', 24, 100, 0.1960, 427.3600, 83.7626, 511.1226);
INSERT INTO commandes VALUES (3248, '2011-06-11 11:17:13.562838', NULL, '2011-06-12 14:20:13.562838', 'facturée', 'en attente', 26, 15, 0.1960, 88.0400, 17.2558, 105.2958);
INSERT INTO commandes VALUES (3270, '2011-09-20 06:15:15.91038', NULL, '2011-09-28 11:24:15.91038', 'facturée', 'en attente', 13, 100, 0.1960, 340.2900, 66.6968, 406.9868);
INSERT INTO commandes VALUES (3249, '2011-01-16 06:11:13.62774', NULL, '2011-01-23 14:21:13.62774', 'payée', 'en attente', 13, 5, 0.1960, -1.0400, -0.2038, -1.2438);
INSERT INTO commandes VALUES (3255, '2011-07-15 12:13:14.237617', '2011-07-20 20:21:14.237617', NULL, 'non facturée', 'expédiée', 26, 100, 0.1960, 335.4500, 65.7482, 401.1982);
INSERT INTO commandes VALUES (3253, '2011-07-13 15:18:13.937273', '2011-07-18 16:28:13.937273', '2011-07-23 16:27:13.937273', 'payée', 'expédiée', 13, 100, 0.1960, 259.4200, 50.8463, 310.2663);
INSERT INTO commandes VALUES (3262, '2011-03-18 09:10:14.895094', NULL, NULL, 'non facturée', 'en préparation', 22, 100, 0.1960, 357.5400, 70.0778, 427.6178);
INSERT INTO commandes VALUES (3258, '2011-01-13 07:14:14.578438', '2011-01-16 10:20:14.578438', NULL, 'non facturée', 'expédiée', 24, 100, 0.1960, 358.5300, 70.2719, 428.8019);
INSERT INTO commandes VALUES (3259, '2011-09-20 11:12:14.737485', '2011-09-24 19:19:14.737485', '2011-09-27 18:16:14.737485', 'facturée', 'expédiée', 16, 0, 0.1960, NULL, NULL, NULL);
INSERT INTO commandes VALUES (3278, '2011-04-17 13:12:16.626831', '2011-04-22 15:13:16.626831', NULL, 'non facturée', 'expédiée', 26, 100, 0.1960, 463.1100, 90.7696, 553.8796);
INSERT INTO commandes VALUES (3267, '2011-06-15 15:14:15.593889', NULL, '2011-06-19 22:21:15.593889', 'payée', 'en attente', 23, 50, 0.1960, 116.9700, 22.9261, 139.8961);
INSERT INTO commandes VALUES (3264, '2011-04-14 11:13:15.128227', NULL, '2011-04-18 21:17:15.128227', 'facturée', 'en préparation', 24, 100, 0.1960, 495.8000, 97.1768, 592.9768);
INSERT INTO commandes VALUES (3269, '2011-07-12 15:16:15.743747', '2011-07-23 00:26:15.743747', NULL, 'non facturée', 'expédiée', 23, 100, 0.1960, 313.5200, 61.4499, 374.9699);
INSERT INTO commandes VALUES (3268, '2011-08-20 15:15:15.702176', NULL, NULL, 'non facturée', 'en attente', 22, 5, 0.1960, 29.8000, 5.8408, 35.6408);
INSERT INTO commandes VALUES (3276, '2011-03-19 06:12:16.375153', '2011-03-26 11:15:16.375153', '2011-03-24 12:19:16.375153', 'payée', 'expédiée', 26, 100, 0.1960, 483.5300, 94.7719, 578.3019);
INSERT INTO commandes VALUES (3275, '2011-06-20 07:13:16.301631', '2011-06-24 14:15:16.301631', '2011-06-22 13:18:16.301631', 'facturée', 'expédiée', 21, 15, 0.1960, 52.8900, 10.3664, 63.2564);
INSERT INTO commandes VALUES (3272, '2011-04-13 07:14:16.126746', NULL, '2011-04-19 10:19:16.126746', 'payée', 'en attente', 13, 100, 0.1960, 389.3900, 76.3204, 465.7104);
INSERT INTO commandes VALUES (3271, '2011-09-12 13:11:16.018659', '2011-09-15 14:21:16.018659', NULL, 'non facturée', 'expédiée', 22, 100, 0.1960, 359.7800, 70.5169, 430.2969);
INSERT INTO commandes VALUES (3273, '2011-06-15 13:15:16.252043', NULL, NULL, 'non facturée', 'en préparation', 21, 5, 0.1960, -15.0000, -2.9400, -17.9400);
INSERT INTO commandes VALUES (3281, '2011-08-14 07:10:17.051065', NULL, '2011-08-18 11:17:17.051065', 'payée', 'en préparation', 26, 100, 0.1960, 358.6500, 70.2954, 428.9454);
INSERT INTO commandes VALUES (3280, '2011-03-14 13:17:16.874886', '2011-03-23 16:23:16.874886', NULL, 'non facturée', 'expédiée', 21, 100, 0.1960, 446.2000, 87.4552, 533.6552);
INSERT INTO commandes VALUES (3277, '2011-07-13 09:13:16.568098', NULL, NULL, 'non facturée', 'en attente', 21, 50, 0.1960, 117.1700, 22.9653, 140.1353);
INSERT INTO commandes VALUES (3279, '2011-03-19 15:15:16.816459', NULL, '2011-03-29 19:16:16.816459', 'payée', 'en attente', 21, 50, 0.1960, 136.9300, 26.8383, 163.7683);
INSERT INTO commandes VALUES (3282, '2011-07-14 07:14:17.150773', '2011-07-24 13:24:17.150773', '2011-07-19 13:16:17.150773', 'payée', 'expédiée', 16, 5, 0.1960, 49.9400, 9.7882, 59.7282);
INSERT INTO commandes VALUES (3296, '2011-07-13 07:12:18.698132', NULL, NULL, 'non facturée', 'en attente', 17, 0, 0.1960, -10.0000, -1.9600, -11.9600);
INSERT INTO commandes VALUES (3283, '2011-09-16 15:14:17.184282', '2011-09-26 17:17:17.184282', NULL, 'non facturée', 'expédiée', 14, 15, 0.1960, 64.2800, 12.5989, 76.8789);
INSERT INTO commandes VALUES (3297, '2011-04-16 09:14:18.714664', '2011-04-23 19:18:18.714664', NULL, 'non facturée', 'expédiée', 15, 100, 0.1960, 277.0100, 54.2940, 331.3040);
INSERT INTO commandes VALUES (3284, '2011-02-19 10:18:17.260897', NULL, '2011-02-21 20:25:17.260897', 'payée', 'prête à l''envoi', 23, 50, 0.1960, 199.9300, 39.1863, 239.1163);
INSERT INTO commandes VALUES (3285, '2011-08-18 06:17:17.300714', NULL, NULL, 'non facturée', 'en attente', 16, 0, 0.1960, 10.7800, 2.1129, 12.8929);
INSERT INTO commandes VALUES (3301, '2011-06-12 14:16:19.16549', NULL, '2011-06-21 00:24:19.16549', 'payée', 'en préparation', 16, 100, 0.1960, 291.3800, 57.1105, 348.4905);
INSERT INTO commandes VALUES (3291, '2011-04-11 14:12:17.965533', '2011-04-13 22:21:17.965533', '2011-04-17 22:13:17.965533', 'facturée', 'expédiée', 15, 100, 0.1960, 368.2500, 72.1770, 440.4270);
INSERT INTO commandes VALUES (3286, '2011-09-14 09:13:17.318523', NULL, '2011-09-23 14:15:17.318523', 'facturée', 'prête à l''envoi', 25, 100, 0.1960, 308.8800, 60.5405, 369.4205);
INSERT INTO commandes VALUES (3302, '2010-12-20 07:13:19.28229', NULL, NULL, 'non facturée', 'en préparation', 17, 50, 0.1960, 175.7100, 34.4392, 210.1492);
INSERT INTO commandes VALUES (3287, '2011-05-20 11:16:17.452626', NULL, '2011-05-26 14:20:17.452626', 'payée', 'en préparation', 23, 100, 0.1960, 354.2200, 69.4271, 423.6471);
INSERT INTO commandes VALUES (3298, '2011-02-11 12:13:18.748129', '2011-02-15 20:21:18.748129', NULL, 'non facturée', 'expédiée', 22, 100, 0.1960, 381.0500, 74.6858, 455.7358);
INSERT INTO commandes VALUES (3292, '2011-06-19 10:11:18.100021', '2011-06-29 16:13:18.100021', NULL, 'non facturée', 'expédiée', 22, 50, 0.1960, 169.5800, 33.2377, 202.8177);
INSERT INTO commandes VALUES (3288, '2011-06-14 08:10:17.542186', '2011-06-23 09:16:17.542186', NULL, 'non facturée', 'expédiée', 23, 100, 0.1960, 210.6900, 41.2952, 251.9852);
INSERT INTO commandes VALUES (3303, '2011-08-17 10:13:19.374002', NULL, '2011-08-23 16:22:19.374002', 'facturée', 'en préparation', 16, 100, 0.1960, 218.2100, 42.7692, 260.9792);
INSERT INTO commandes VALUES (3299, '2011-02-19 07:17:18.924076', '2011-02-21 12:24:18.924076', '2011-02-22 17:23:18.924076', 'payée', 'expédiée', 17, 100, 0.1960, 418.6700, 82.0593, 500.7293);
INSERT INTO commandes VALUES (3289, '2011-08-13 10:12:17.700398', '2011-08-18 15:17:17.700398', NULL, 'non facturée', 'expédiée', 23, 100, 0.1960, 379.5000, 74.3820, 453.8820);
INSERT INTO commandes VALUES (3293, '2010-12-18 06:12:18.26651', NULL, '2010-12-23 12:14:18.26651', 'payée', 'en préparation', 22, 50, 0.1960, 176.9900, 34.6900, 211.6800);
INSERT INTO commandes VALUES (3294, '2011-05-11 13:10:18.471678', '2011-05-17 18:11:18.471678', NULL, 'non facturée', 'expédiée', 23, 100, 0.1960, 222.6200, 43.6335, 266.2535);
INSERT INTO commandes VALUES (3290, '2011-08-16 14:13:17.80741', '2011-08-25 15:17:17.80741', '2011-08-19 17:20:17.80741', 'payée', 'expédiée', 24, 1000, 0.1960, 541.5800, 106.1497, 647.7297);
INSERT INTO commandes VALUES (3300, '2011-01-20 07:19:19.041402', NULL, NULL, 'non facturée', 'en préparation', 25, 100, 0.1960, 401.4600, 78.6862, 480.1462);
INSERT INTO commandes VALUES (3295, '2011-07-14 08:14:18.648031', '2011-07-24 18:15:18.648031', NULL, 'non facturée', 'expédiée', 17, 5, 0.1960, -6.2400, -1.2230, -7.4630);
INSERT INTO commandes VALUES (3304, '2011-04-19 14:19:19.531506', NULL, NULL, 'non facturée', 'prête à l''envoi', 21, 1000, 0.1960, 502.3700, 98.4645, 600.8345);
INSERT INTO commandes VALUES (3305, '2011-07-14 09:18:19.732445', NULL, NULL, 'non facturée', 'en préparation', 24, 5, 0.1960, 20.9200, 4.1003, 25.0203);
INSERT INTO commandes VALUES (3306, '2011-02-19 15:16:19.773204', NULL, '2011-02-22 01:26:19.773204', 'payée', 'en attente', 13, 5, 0.1960, 1.6100, 0.3156, 1.9256);
INSERT INTO commandes VALUES (3314, '2011-04-15 08:15:20.404606', NULL, '2011-04-17 14:19:20.404606', 'payée', 'prête à l''envoi', 17, 100, 0.1960, 320.6800, 62.8533, 383.5333);
INSERT INTO commandes VALUES (3333, '2011-01-13 08:14:22.662166', NULL, NULL, 'non facturée', 'en attente', 24, 50, 0.1960, 111.4800, 21.8501, 133.3301);
INSERT INTO commandes VALUES (3337, '2011-04-15 06:10:22.97727', '2011-04-16 11:17:22.97727', '2011-04-23 12:14:22.97727', 'facturée', 'expédiée', 15, 100, 0.1960, 384.8700, 75.4345, 460.3045);
INSERT INTO commandes VALUES (3324, '2011-06-15 08:13:21.663131', NULL, NULL, 'non facturée', 'en attente', 16, 100, 0.1960, 308.8500, 60.5346, 369.3846);
INSERT INTO commandes VALUES (3334, '2011-01-14 10:12:22.744097', '2011-01-20 11:14:22.744097', NULL, 'non facturée', 'expédiée', 24, 5, 0.1960, 34.4300, 6.7483, 41.1783);
INSERT INTO commandes VALUES (3307, '2011-03-14 08:11:19.806641', '2011-03-21 16:12:19.806641', NULL, 'non facturée', 'expédiée', 13, 100, 0.1960, 420.6500, 82.4474, 503.0974);
INSERT INTO commandes VALUES (3325, '2011-04-16 14:10:21.813623', '2011-04-25 23:12:21.813623', NULL, 'non facturée', 'expédiée', 26, 15, 0.1960, 70.3700, 13.7925, 84.1625);
INSERT INTO commandes VALUES (3320, '2011-09-12 08:11:21.155209', '2011-09-18 11:16:21.155209', NULL, 'non facturée', 'expédiée', 22, 100, 0.1960, 211.7500, 41.5030, 253.2530);
INSERT INTO commandes VALUES (3315, '2011-06-13 07:14:20.56434', '2011-06-17 10:15:20.56434', '2011-06-14 12:17:20.56434', 'payée', 'expédiée', 21, 1000, 0.1960, 541.2000, 106.0752, 647.2752);
INSERT INTO commandes VALUES (3308, '2011-08-18 15:11:19.95674', '2011-08-22 01:14:19.95674', '2011-08-27 21:21:19.95674', 'facturée', 'expédiée', 25, 15, 0.1960, 60.3800, 11.8345, 72.2145);
INSERT INTO commandes VALUES (3309, '2011-07-16 06:19:20.022942', '2011-07-17 15:29:20.022942', NULL, 'non facturée', 'expédiée', 25, 50, 0.1960, 100.1500, 19.6294, 119.7794);
INSERT INTO commandes VALUES (3326, '2011-03-13 10:14:21.847137', '2011-03-23 18:18:21.847137', NULL, 'non facturée', 'expédiée', 26, 15, 0.1960, 63.0500, 12.3578, 75.4078);
INSERT INTO commandes VALUES (3341, '2011-04-14 11:19:23.428582', NULL, '2011-04-15 12:22:23.428582', 'payée', 'en attente', 15, 50, 0.1960, 183.7600, 36.0170, 219.7770);
INSERT INTO commandes VALUES (3330, '2011-09-11 06:15:22.236749', NULL, NULL, 'non facturée', 'en attente', 22, 100, 0.1960, 334.2700, 65.5169, 399.7869);
INSERT INTO commandes VALUES (3327, '2011-02-20 09:18:21.920117', NULL, NULL, 'non facturée', 'prête à l''envoi', 24, 100, 0.1960, 201.4200, 39.4783, 240.8983);
INSERT INTO commandes VALUES (3316, '2011-02-15 08:11:20.699372', '2011-02-25 09:21:20.699372', '2011-02-17 09:12:20.699372', 'facturée', 'expédiée', 15, 1000, 0.1960, 593.5900, 116.3436, 709.9336);
INSERT INTO commandes VALUES (3310, '2010-12-11 08:17:20.08967', NULL, NULL, 'non facturée', 'en préparation', 21, 1000, 0.1960, 532.2500, 104.3210, 636.5710);
INSERT INTO commandes VALUES (3311, '2011-04-12 10:15:20.213095', '2011-04-13 19:17:20.213095', '2011-04-20 20:18:20.213095', 'payée', 'expédiée', 14, 5, 0.1960, -15.0000, -2.9400, -17.9400);
INSERT INTO commandes VALUES (3321, '2011-06-15 08:12:21.320509', '2011-06-18 09:14:21.320509', NULL, 'non facturée', 'expédiée', 25, 100, 0.1960, 252.6400, 49.5174, 302.1574);
INSERT INTO commandes VALUES (3312, '2011-09-12 07:12:20.247927', '2011-09-18 17:15:20.247927', NULL, 'non facturée', 'expédiée', 22, 50, 0.1960, 123.7400, 24.2530, 147.9930);
INSERT INTO commandes VALUES (3317, '2011-05-14 06:14:20.85565', '2011-05-22 07:19:20.85565', NULL, 'non facturée', 'expédiée', 13, 15, 0.1960, 97.6000, 19.1296, 116.7296);
INSERT INTO commandes VALUES (3346, '2011-09-11 10:16:23.993534', '2011-09-17 14:25:23.993534', '2011-09-19 11:18:23.993534', 'payée', 'expédiée', 15, 100, 0.1960, 336.0400, 65.8638, 401.9038);
INSERT INTO commandes VALUES (3335, '2011-02-13 15:11:22.779139', '2011-02-24 01:18:22.779139', '2011-02-21 01:16:22.779139', 'facturée', 'expédiée', 21, 100, 0.1960, 456.9000, 89.5524, 546.4524);
INSERT INTO commandes VALUES (3313, '2011-04-14 10:14:20.308361', '2011-04-23 20:24:20.308361', '2011-04-23 20:23:20.308361', 'facturée', 'expédiée', 23, 15, 0.1960, 70.9200, 13.9003, 84.8203);
INSERT INTO commandes VALUES (3344, '2011-02-19 06:10:23.702899', '2011-02-27 09:16:23.702899', NULL, 'non facturée', 'expédiée', 16, 100, 0.1960, 284.2200, 55.7071, 339.9271);
INSERT INTO commandes VALUES (3328, '2010-12-11 15:18:21.976417', NULL, NULL, 'non facturée', 'en attente', 25, 100, 0.1960, 423.6600, 83.0374, 506.6974);
INSERT INTO commandes VALUES (3322, '2011-08-19 11:14:21.471951', '2011-08-26 16:19:21.471951', '2011-08-28 13:20:21.471951', 'payée', 'expédiée', 15, 100, 0.1960, 352.6000, 69.1096, 421.7096);
INSERT INTO commandes VALUES (3331, '2011-09-17 15:13:22.39443', NULL, NULL, 'non facturée', 'en attente', 14, 100, 0.1960, 384.7200, 75.4051, 460.1251);
INSERT INTO commandes VALUES (3318, '2011-05-15 14:14:20.916398', NULL, NULL, 'non facturée', 'en attente', 15, 100, 0.1960, 358.3500, 70.2366, 428.5866);
INSERT INTO commandes VALUES (3323, '2011-05-17 06:11:21.605982', NULL, NULL, 'non facturée', 'prête à l''envoi', 24, 5, 0.1960, 29.1200, 5.7075, 34.8275);
INSERT INTO commandes VALUES (3338, '2011-05-11 10:11:23.102308', '2011-05-17 13:16:23.102308', '2011-05-20 16:16:23.102308', 'facturée', 'expédiée', 21, 1000, 0.1960, 528.3500, 103.5566, 631.9066);
INSERT INTO commandes VALUES (3319, '2011-06-11 12:19:21.097014', NULL, NULL, 'non facturée', 'en préparation', 15, 5, 0.1960, 16.6000, 3.2536, 19.8536);
INSERT INTO commandes VALUES (3336, '2011-04-19 13:15:22.863148', NULL, '2011-04-23 19:21:22.863148', 'payée', 'en préparation', 14, 100, 0.1960, 234.4900, 45.9600, 280.4500);
INSERT INTO commandes VALUES (3339, '2011-05-20 08:16:23.318506', '2011-05-26 10:23:23.318506', NULL, 'non facturée', 'expédiée', 14, 5, 0.1960, 18.1600, 3.5594, 21.7194);
INSERT INTO commandes VALUES (3329, '2011-06-20 15:15:22.087832', '2011-06-27 19:21:22.087832', '2011-06-23 18:16:22.087832', 'facturée', 'expédiée', 25, 100, 0.1960, 291.9400, 57.2202, 349.1602);
INSERT INTO commandes VALUES (3342, '2011-09-19 12:12:23.535321', NULL, NULL, 'non facturée', 'en attente', 23, 100, 0.1960, 248.8100, 48.7668, 297.5768);
INSERT INTO commandes VALUES (3340, '2011-04-17 14:17:23.353355', NULL, '2011-04-20 22:25:23.353355', 'facturée', 'en préparation', 15, 50, 0.1960, 126.4700, 24.7881, 151.2581);
INSERT INTO commandes VALUES (3332, '2011-07-18 15:16:22.504213', NULL, '2011-07-26 20:20:22.504213', 'payée', 'prête à l''envoi', 13, 100, 0.1960, 350.8600, 68.7686, 419.6286);
INSERT INTO commandes VALUES (3348, '2010-12-17 09:14:24.294101', '2010-12-25 19:21:24.294101', '2010-12-27 11:18:24.294101', 'payée', 'expédiée', 21, 100, 0.1960, 294.9700, 57.8141, 352.7841);
INSERT INTO commandes VALUES (3343, '2011-09-18 10:18:23.661303', '2011-09-24 12:19:23.661303', NULL, 'non facturée', 'expédiée', 14, 5, 0.1960, 20.4300, 4.0043, 24.4343);
INSERT INTO commandes VALUES (3345, '2011-09-13 11:14:23.877722', NULL, NULL, 'non facturée', 'prête à l''envoi', 14, 100, 0.1960, 334.4500, 65.5522, 400.0022);
INSERT INTO commandes VALUES (3347, '2011-03-19 15:16:24.11914', '2011-03-21 18:18:24.11914', NULL, 'non facturée', 'expédiée', 22, 100, 0.1960, 345.9600, 67.8082, 413.7682);
INSERT INTO commandes VALUES (3349, '2011-05-12 08:15:24.452118', '2011-05-22 10:23:24.452118', '2011-05-17 10:19:24.452118', 'facturée', 'expédiée', 23, 50, 0.1960, 124.9400, 24.4882, 149.4282);
INSERT INTO commandes VALUES (3383, '2011-09-12 15:11:28.649524', '2011-09-18 17:14:28.649524', '2011-09-17 16:13:28.649524', 'payée', 'expédiée', 16, 100, 0.1960, 310.1900, 60.7972, 370.9872);
INSERT INTO commandes VALUES (3361, '2011-09-12 08:15:25.941218', NULL, '2011-09-17 16:23:25.941218', 'facturée', 'en attente', 14, 50, 0.1960, 101.8500, 19.9626, 121.8126);
INSERT INTO commandes VALUES (3366, '2011-02-20 10:15:26.808055', '2011-02-26 19:23:26.808055', NULL, 'non facturée', 'expédiée', 24, 1000, 0.1960, 507.7300, 99.5151, 607.2451);
INSERT INTO commandes VALUES (3356, '2011-09-11 11:17:25.201881', NULL, '2011-09-20 15:18:25.201881', 'facturée', 'en attente', 16, 100, 0.1960, 381.9000, 74.8524, 456.7524);
INSERT INTO commandes VALUES (3350, '2011-02-13 14:18:24.502117', '2011-02-22 19:22:24.502117', '2011-02-18 18:23:24.502117', 'facturée', 'expédiée', 14, 50, 0.1960, 176.8200, 34.6567, 211.4767);
INSERT INTO commandes VALUES (3372, '2011-04-16 13:14:27.391116', NULL, NULL, 'non facturée', 'prête à l''envoi', 21, 100, 0.1960, 347.0700, 68.0257, 415.0957);
INSERT INTO commandes VALUES (3362, '2011-08-16 09:19:25.999609', NULL, '2011-08-23 13:27:25.999609', 'facturée', 'prête à l''envoi', 23, 5, 0.1960, 22.8900, 4.4864, 27.3764);
INSERT INTO commandes VALUES (3373, '2011-07-18 12:14:27.541571', '2011-07-19 20:21:27.541571', NULL, 'non facturée', 'expédiée', 24, 0, 0.1960, NULL, NULL, NULL);
INSERT INTO commandes VALUES (3374, '2011-01-19 09:18:27.550169', NULL, NULL, 'non facturée', 'prête à l''envoi', 26, 0, 0.1960, 31.9600, 6.2642, 38.2242);
INSERT INTO commandes VALUES (3363, '2011-09-13 09:12:26.050833', '2011-09-14 13:16:26.050833', '2011-09-14 12:17:26.050833', 'payée', 'expédiée', 17, 15, 0.1960, 94.6300, 18.5475, 113.1775);
INSERT INTO commandes VALUES (3357, '2011-02-18 14:14:25.368027', '2011-02-24 16:20:25.368027', NULL, 'non facturée', 'expédiée', 22, 100, 0.1960, 229.0200, 44.8879, 273.9079);
INSERT INTO commandes VALUES (3351, '2011-03-13 09:18:24.602081', NULL, '2011-03-21 12:26:24.602081', 'facturée', 'en attente', 16, 100, 0.1960, 468.6800, 91.8613, 560.5413);
INSERT INTO commandes VALUES (3352, '2011-04-19 12:17:24.760286', NULL, '2011-04-28 21:24:24.760286', 'payée', 'en préparation', 21, 50, 0.1960, 144.7400, 28.3690, 173.1090);
INSERT INTO commandes VALUES (3381, '2011-02-12 11:14:28.333526', NULL, '2011-02-17 20:17:28.333526', 'facturée', 'en attente', 25, 50, 0.1960, 167.7800, 32.8849, 200.6649);
INSERT INTO commandes VALUES (3367, '2011-09-14 07:14:26.983008', '2011-09-19 12:24:26.983008', '2011-09-19 12:22:26.983008', 'payée', 'expédiée', 23, 100, 0.1960, 369.5300, 72.4279, 441.9579);
INSERT INTO commandes VALUES (3353, '2011-09-14 15:17:24.810524', NULL, NULL, 'non facturée', 'en préparation', 16, 15, 0.1960, 91.4100, 17.9164, 109.3264);
INSERT INTO commandes VALUES (3358, '2011-07-14 07:12:25.509624', NULL, NULL, 'non facturée', 'en attente', 15, 100, 0.1960, 298.4000, 58.4864, 356.8864);
INSERT INTO commandes VALUES (3375, '2011-05-13 11:15:27.566105', '2011-05-20 19:16:27.566105', NULL, 'non facturée', 'expédiée', 24, 50, 0.1960, 113.5600, 22.2578, 135.8178);
INSERT INTO commandes VALUES (3364, '2010-12-17 10:16:26.116187', NULL, NULL, 'non facturée', 'en préparation', 22, 1000, 0.1960, 541.8400, 106.2006, 648.0406);
INSERT INTO commandes VALUES (3354, '2011-09-15 06:17:24.918522', '2011-09-19 11:27:24.918522', '2011-09-22 12:25:24.918522', 'payée', 'expédiée', 14, 100, 0.1960, 460.8200, 90.3207, 551.1407);
INSERT INTO commandes VALUES (3368, '2011-09-13 07:15:27.116473', '2011-09-21 11:25:27.116473', '2011-09-18 13:25:27.116473', 'facturée', 'expédiée', 24, 100, 0.1960, 221.7500, 43.4630, 265.2130);
INSERT INTO commandes VALUES (3369, '2011-09-19 13:16:27.214958', NULL, NULL, 'non facturée', 'en attente', 22, 0, 0.1960, NULL, NULL, NULL);
INSERT INTO commandes VALUES (3378, '2011-05-15 11:18:27.949071', '2011-05-21 16:27:27.949071', '2011-05-19 13:24:27.949071', 'facturée', 'expédiée', 14, 100, 0.1960, 381.7600, 74.8250, 456.5850);
INSERT INTO commandes VALUES (3359, '2011-03-18 15:10:25.625966', NULL, NULL, 'non facturée', 'prête à l''envoi', 15, 1000, 0.1960, 578.2000, 113.3272, 691.5272);
INSERT INTO commandes VALUES (3370, '2011-09-15 13:13:27.225052', '2011-09-19 22:18:27.225052', '2011-09-20 19:14:27.225052', 'facturée', 'expédiée', 14, 5, 0.1960, 18.1200, 3.5515, 21.6715);
INSERT INTO commandes VALUES (3355, '2011-09-20 11:12:25.043539', '2011-09-27 14:19:25.043539', NULL, 'non facturée', 'expédiée', 25, 100, 0.1960, 477.8800, 93.6645, 571.5445);
INSERT INTO commandes VALUES (3379, '2011-09-14 06:16:28.116825', NULL, '2011-09-17 11:25:28.116825', 'facturée', 'en préparation', 26, 0, 0.1960, 6.1600, 1.2074, 7.3674);
INSERT INTO commandes VALUES (3365, '2011-06-11 09:15:26.623449', '2011-06-16 14:22:26.623449', NULL, 'non facturée', 'expédiée', 23, 100, 0.1960, 356.3400, 69.8426, 426.1826);
INSERT INTO commandes VALUES (3371, '2011-09-15 06:10:27.258124', NULL, '2011-09-16 16:14:27.258124', 'payée', 'prête à l''envoi', 16, 100, 0.1960, 339.5700, 66.5557, 406.1257);
INSERT INTO commandes VALUES (3376, '2011-05-19 06:18:27.672752', '2011-05-22 15:23:27.672752', '2011-05-21 10:27:27.672752', 'payée', 'expédiée', 16, 100, 0.1960, 473.0100, 92.7100, 565.7200);
INSERT INTO commandes VALUES (3360, '2011-01-15 15:10:25.767477', '2011-01-21 20:20:25.767477', '2011-01-20 20:12:25.767477', 'facturée', 'expédiée', 23, 100, 0.1960, 382.2900, 74.9288, 457.2188);
INSERT INTO commandes VALUES (3384, '2011-05-19 13:10:28.757826', '2011-05-21 17:19:28.757826', NULL, 'non facturée', 'expédiée', 13, 100, 0.1960, 371.2900, 72.7728, 444.0628);
INSERT INTO commandes VALUES (3382, '2011-09-20 13:14:28.483072', '2011-09-30 18:19:28.483072', '2011-09-28 20:16:28.483072', 'payée', 'expédiée', 21, 100, 0.1960, 456.1000, 89.3956, 545.4956);
INSERT INTO commandes VALUES (3380, '2011-04-11 09:18:28.142382', '2011-04-19 18:24:28.142382', '2011-04-17 16:19:28.142382', 'facturée', 'expédiée', 26, 100, 0.1960, 403.0000, 78.9880, 481.9880);
INSERT INTO commandes VALUES (3377, '2010-12-16 07:19:27.84875', '2010-12-24 14:20:27.84875', '2010-12-26 14:27:27.84875', 'facturée', 'expédiée', 26, 100, 0.1960, 394.8900, 77.3984, 472.2884);
INSERT INTO commandes VALUES (3385, '2011-03-18 09:14:28.931251', NULL, NULL, 'non facturée', 'en attente', 24, 1000, 0.1960, 501.2600, 98.2470, 599.5070);
INSERT INTO commandes VALUES (3402, '2011-04-11 09:10:30.588136', NULL, '2011-04-16 13:11:30.588136', 'payée', 'prête à l''envoi', 13, 1000, 0.1960, 513.1000, 100.5676, 613.6676);
INSERT INTO commandes VALUES (3394, '2011-04-18 09:16:29.888904', '2011-04-24 11:23:29.888904', '2011-04-20 10:22:29.888904', 'payée', 'expédiée', 17, 50, 0.1960, 156.8900, 30.7504, 187.6404);
INSERT INTO commandes VALUES (3386, '2011-06-12 07:18:29.18117', '2011-06-14 10:28:29.18117', NULL, 'non facturée', 'expédiée', 14, 5, 0.1960, 28.3100, 5.5488, 33.8588);
INSERT INTO commandes VALUES (3387, '2011-01-20 08:10:29.234725', NULL, '2011-01-29 15:13:29.234725', 'facturée', 'en préparation', 15, 0, 0.1960, 17.9600, 3.5202, 21.4802);
INSERT INTO commandes VALUES (3395, '2010-12-20 10:18:29.973838', '2010-12-22 11:20:29.973838', '2010-12-28 15:27:29.973838', 'payée', 'expédiée', 24, 0, 0.1960, 17.3700, 3.4045, 20.7745);
INSERT INTO commandes VALUES (3388, '2011-03-17 08:17:29.256204', NULL, '2011-03-21 09:27:29.256204', 'payée', 'en préparation', 16, 5, 0.1960, 18.8400, 3.6926, 22.5326);
INSERT INTO commandes VALUES (3389, '2011-02-15 11:19:29.305855', '2011-02-22 15:23:29.305855', '2011-02-16 15:20:29.305855', 'facturée', 'expédiée', 17, 5, 0.1960, -15.0000, -2.9400, -17.9400);
INSERT INTO commandes VALUES (3406, '2011-09-15 10:14:31.172297', NULL, '2011-09-20 11:16:31.172297', 'facturée', 'en préparation', 17, 100, 0.1960, 406.6300, 79.6995, 486.3295);
INSERT INTO commandes VALUES (3396, '2011-01-19 10:10:30.020082', NULL, NULL, 'non facturée', 'prête à l''envoi', 21, 15, 0.1960, 74.2900, 14.5608, 88.8508);
INSERT INTO commandes VALUES (3412, '2011-07-15 07:12:31.80485', NULL, '2011-07-20 15:14:31.80485', 'facturée', 'en préparation', 16, 100, 0.1960, 214.8600, 42.1126, 256.9726);
INSERT INTO commandes VALUES (3418, '2011-09-15 15:10:32.46121', '2011-09-20 18:15:32.46121', '2011-09-21 01:11:32.46121', 'facturée', 'expédiée', 13, 100, 0.1960, 477.1600, 93.5234, 570.6834);
INSERT INTO commandes VALUES (3390, '2010-12-18 09:18:29.339519', '2010-12-23 12:19:29.339519', NULL, 'non facturée', 'expédiée', 17, 50, 0.1960, 149.1600, 29.2354, 178.3954);
INSERT INTO commandes VALUES (3397, '2011-06-16 14:13:30.08158', NULL, '2011-06-17 23:19:30.08158', 'payée', 'en attente', 22, 50, 0.1960, 175.7500, 34.4470, 210.1970);
INSERT INTO commandes VALUES (3416, '2011-02-17 09:10:32.162728', '2011-02-25 11:13:32.162728', NULL, 'non facturée', 'expédiée', 13, 100, 0.1960, 200.2400, 39.2470, 239.4870);
INSERT INTO commandes VALUES (3403, '2010-12-13 09:14:30.704822', '2010-12-18 10:24:30.704822', '2010-12-19 10:16:30.704822', 'payée', 'expédiée', 22, 100, 0.1960, 364.3200, 71.4067, 435.7267);
INSERT INTO commandes VALUES (3398, '2011-01-11 06:11:30.17175', '2011-01-20 11:17:30.17175', NULL, 'non facturée', 'expédiée', 13, 5, 0.1960, 46.4400, 9.1022, 55.5422);
INSERT INTO commandes VALUES (3413, '2011-02-11 13:17:31.863022', '2011-02-19 18:26:31.863022', NULL, 'non facturée', 'expédiée', 13, 1000, 0.1960, 534.8700, 104.8345, 639.7045);
INSERT INTO commandes VALUES (3399, '2010-12-11 06:14:30.354812', '2010-12-18 08:20:30.354812', NULL, 'non facturée', 'expédiée', 22, 5, 0.1960, -15.0000, -2.9400, -17.9400);
INSERT INTO commandes VALUES (3391, '2010-12-15 12:11:29.447449', NULL, '2010-12-22 15:21:29.447449', 'payée', 'prête à l''envoi', 15, 100, 0.1960, 462.3500, 90.6206, 552.9706);
INSERT INTO commandes VALUES (3407, '2011-07-13 09:12:31.321852', '2011-07-22 18:14:31.321852', '2011-07-22 14:16:31.321852', 'facturée', 'expédiée', 22, 1000, 0.1960, 554.4100, 108.6644, 663.0744);
INSERT INTO commandes VALUES (3421, '2011-04-14 07:17:32.994347', '2011-04-16 13:22:32.994347', '2011-04-22 17:25:32.994347', 'facturée', 'expédiée', 23, 1000, 0.1960, 571.2200, 111.9591, 683.1791);
INSERT INTO commandes VALUES (3414, '2011-08-15 08:14:31.953707', NULL, NULL, 'non facturée', 'en attente', 23, 100, 0.1960, 426.3100, 83.5568, 509.8668);
INSERT INTO commandes VALUES (3400, '2011-03-20 10:18:30.388237', '2011-03-27 18:25:30.388237', '2011-03-21 17:25:30.388237', 'facturée', 'expédiée', 17, 1000, 0.1960, 526.2800, 103.1509, 629.4309);
INSERT INTO commandes VALUES (3392, '2010-12-20 14:14:29.60569', NULL, NULL, 'non facturée', 'en attente', 26, 100, 0.1960, 499.0400, 97.8118, 596.8518);
INSERT INTO commandes VALUES (3404, '2011-09-15 15:14:30.864201', NULL, NULL, 'non facturée', 'prête à l''envoi', 14, 1000, 0.1960, 521.9400, 102.3002, 624.2402);
INSERT INTO commandes VALUES (3401, '2011-07-20 06:19:30.538421', NULL, '2011-07-25 08:29:30.538421', 'payée', 'prête à l''envoi', 14, 5, 0.1960, 18.7000, 3.6652, 22.3652);
INSERT INTO commandes VALUES (3393, '2011-08-11 10:19:29.790243', NULL, '2011-08-16 14:26:29.790243', 'facturée', 'en attente', 13, 100, 0.1960, 400.0400, 78.4078, 478.4478);
INSERT INTO commandes VALUES (3419, '2010-12-17 08:16:32.686212', NULL, NULL, 'non facturée', 'en préparation', 17, 1000, 0.1960, 506.5900, 99.2916, 605.8816);
INSERT INTO commandes VALUES (3408, '2011-04-15 14:15:31.580081', '2011-04-25 19:20:31.580081', NULL, 'non facturée', 'expédiée', 24, 100, 0.1960, 426.3400, 83.5626, 509.9026);
INSERT INTO commandes VALUES (3409, '2011-05-18 06:18:31.713272', NULL, '2011-05-27 11:25:31.713272', 'facturée', 'en attente', 26, 5, 0.1960, 6.9600, 1.3642, 8.3242);
INSERT INTO commandes VALUES (3410, '2011-05-20 09:16:31.746561', '2011-05-26 12:21:31.746561', NULL, 'non facturée', 'expédiée', 24, 0, 0.1960, -5.0000, -0.9800, -5.9800);
INSERT INTO commandes VALUES (3417, '2011-08-19 15:12:32.321157', NULL, '2011-08-30 01:15:32.321157', 'payée', 'en préparation', 21, 100, 0.1960, 355.7500, 69.7270, 425.4770);
INSERT INTO commandes VALUES (3405, '2011-03-19 07:13:31.039011', NULL, NULL, 'non facturée', 'en attente', 17, 100, 0.1960, 392.3700, 76.9045, 469.2745);
INSERT INTO commandes VALUES (3411, '2011-01-18 14:12:31.764223', NULL, NULL, 'non facturée', 'en attente', 26, 5, 0.1960, 43.4100, 8.5084, 51.9184);
INSERT INTO commandes VALUES (3415, '2011-06-17 15:10:32.062978', '2011-06-20 16:14:32.062978', NULL, 'non facturée', 'expédiée', 26, 100, 0.1960, 242.5400, 47.5378, 290.0778);
INSERT INTO commandes VALUES (3422, '2010-12-19 14:12:33.144558', NULL, '2010-12-21 20:22:33.144558', 'facturée', 'prête à l''envoi', 16, 100, 0.1960, 217.7200, 42.6731, 260.3931);
INSERT INTO commandes VALUES (3420, '2011-06-19 10:18:32.875604', NULL, NULL, 'non facturée', 'en attente', 14, 1000, 0.1960, 528.6500, 103.6154, 632.2654);
INSERT INTO commandes VALUES (3423, '2011-04-19 13:12:33.286807', '2011-04-26 16:16:33.286807', NULL, 'non facturée', 'expédiée', 25, 5, 0.1960, -15.0000, -2.9400, -17.9400);
INSERT INTO commandes VALUES (3430, '2011-04-18 06:18:34.061332', '2011-04-28 12:27:34.061332', NULL, 'non facturée', 'expédiée', 14, 1000, 0.1960, 524.4600, 102.7942, 627.2542);
INSERT INTO commandes VALUES (3445, '2011-05-15 07:16:35.866214', '2011-05-25 09:24:35.866214', '2011-05-19 17:23:35.866214', 'payée', 'expédiée', 14, 5, 0.1960, -15.0000, -2.9400, -17.9400);
INSERT INTO commandes VALUES (3439, '2011-09-19 10:17:35.266756', '2011-09-28 20:25:35.266756', NULL, 'non facturée', 'expédiée', 22, 100, 0.1960, 262.9800, 51.5441, 314.5241);
INSERT INTO commandes VALUES (3446, '2011-03-11 09:13:35.900802', NULL, '2011-03-21 17:17:35.900802', 'payée', 'en attente', 23, 15, 0.1960, 54.4200, 10.6663, 65.0863);
INSERT INTO commandes VALUES (3424, '2011-01-18 13:10:33.318717', NULL, '2011-01-27 15:13:33.318717', 'payée', 'prête à l''envoi', 23, 1000, 0.1960, 593.0200, 116.2319, 709.2519);
INSERT INTO commandes VALUES (3431, '2010-12-15 12:19:34.234352', NULL, '2010-12-18 18:21:34.234352', 'payée', 'en attente', 17, 100, 0.1960, 448.2200, 87.8511, 536.0711);
INSERT INTO commandes VALUES (3432, '2010-12-14 12:13:34.361053', NULL, '2010-12-20 22:22:34.361053', 'payée', 'en préparation', 16, 0, 0.1960, NULL, NULL, NULL);
INSERT INTO commandes VALUES (3425, '2011-05-16 08:16:33.486588', NULL, '2011-05-21 18:25:33.486588', 'facturée', 'prête à l''envoi', 16, 100, 0.1960, 423.8500, 83.0746, 506.9246);
INSERT INTO commandes VALUES (3440, '2010-12-13 08:10:35.383282', NULL, '2010-12-15 10:13:35.383282', 'payée', 'prête à l''envoi', 14, 100, 0.1960, 437.0100, 85.6540, 522.6640);
INSERT INTO commandes VALUES (3433, '2011-06-17 07:17:34.369584', NULL, '2011-06-26 08:23:34.369584', 'payée', 'en attente', 17, 100, 0.1960, 435.8400, 85.4246, 521.2646);
INSERT INTO commandes VALUES (3426, '2011-09-17 08:14:33.643337', NULL, NULL, 'non facturée', 'en préparation', 16, 15, 0.1960, 83.8200, 16.4287, 100.2487);
INSERT INTO commandes VALUES (3427, '2011-01-17 11:15:33.820516', NULL, NULL, 'non facturée', 'en attente', 23, 5, 0.1960, -15.0000, -2.9400, -17.9400);
INSERT INTO commandes VALUES (3447, '2011-02-15 06:18:36.075916', NULL, NULL, 'non facturée', 'en attente', 13, 100, 0.1960, 307.8400, 60.3366, 368.1766);
INSERT INTO commandes VALUES (3428, '2011-06-19 09:14:33.859809', '2011-06-27 11:18:33.859809', '2011-06-28 10:22:33.859809', 'facturée', 'expédiée', 14, 5, 0.1960, 9.8700, 1.9345, 11.8045);
INSERT INTO commandes VALUES (3434, '2011-09-14 08:10:34.510649', NULL, NULL, 'non facturée', 'prête à l''envoi', 25, 50, 0.1960, 196.2800, 38.4709, 234.7509);
INSERT INTO commandes VALUES (3435, '2011-04-16 11:19:34.710445', NULL, '2011-04-20 19:28:34.710445', 'payée', 'en préparation', 13, 0, 0.1960, NULL, NULL, NULL);
INSERT INTO commandes VALUES (3441, '2011-02-16 12:10:35.534272', NULL, '2011-02-20 15:11:35.534272', 'payée', 'en préparation', 13, 100, 0.1960, 258.5500, 50.6758, 309.2258);
INSERT INTO commandes VALUES (3448, '2011-02-19 15:15:36.40836', NULL, '2011-02-26 16:25:36.40836', 'payée', 'prête à l''envoi', 26, 5, 0.1960, -15.0000, -2.9400, -17.9400);
INSERT INTO commandes VALUES (3436, '2010-12-12 07:12:34.744391', NULL, NULL, 'non facturée', 'en attente', 16, 50, 0.1960, 120.1700, 23.5533, 143.7233);
INSERT INTO commandes VALUES (3429, '2011-04-19 06:16:33.90279', NULL, NULL, 'non facturée', 'en préparation', 26, 100, 0.1960, 479.3600, 93.9546, 573.3146);
INSERT INTO commandes VALUES (3442, '2011-02-16 13:16:35.624556', '2011-02-21 19:23:35.624556', NULL, 'non facturée', 'expédiée', 24, 5, 0.1960, 38.4900, 7.5440, 46.0340);
INSERT INTO commandes VALUES (3437, '2011-05-16 12:17:35.068312', '2011-05-17 20:24:35.068312', NULL, 'non facturée', 'expédiée', 26, 50, 0.1960, 174.2900, 34.1608, 208.4508);
INSERT INTO commandes VALUES (3443, '2011-08-15 13:13:35.675809', NULL, NULL, 'non facturée', 'en préparation', 13, 15, 0.1960, 50.4800, 9.8941, 60.3741);
INSERT INTO commandes VALUES (3438, '2011-07-17 10:10:35.18497', NULL, '2011-07-19 17:15:35.18497', 'facturée', 'prête à l''envoi', 26, 15, 0.1960, 71.5700, 14.0277, 85.5977);
INSERT INTO commandes VALUES (3449, '2011-06-18 13:15:36.441856', '2011-06-21 21:22:36.441856', NULL, 'non facturée', 'expédiée', 13, 100, 0.1960, 413.7600, 81.0970, 494.8570);
INSERT INTO commandes VALUES (3444, '2011-07-11 09:15:35.717451', NULL, NULL, 'non facturée', 'prête à l''envoi', 22, 1000, 0.1960, 510.0200, 99.9639, 609.9839);
INSERT INTO commandes VALUES (3450, '2011-04-14 09:11:36.558165', NULL, NULL, 'non facturée', 'en préparation', 23, 50, 0.1960, 177.9600, 34.8802, 212.8402);
INSERT INTO commandes VALUES (3451, '2011-09-16 11:17:36.666356', NULL, NULL, 'non facturée', 'en attente', 21, 0, 0.1960, -10.0000, -1.9600, -11.9600);
INSERT INTO commandes VALUES (3470, '2011-08-20 11:14:38.771345', NULL, NULL, 'non facturée', 'en préparation', 14, 100, 0.1960, 483.2700, 94.7209, 577.9909);
INSERT INTO commandes VALUES (3465, '2010-12-16 14:11:38.098571', NULL, '2010-12-18 22:12:38.098571', 'facturée', 'prête à l''envoi', 13, 100, 0.1960, 393.8700, 77.1985, 471.0685);
INSERT INTO commandes VALUES (3471, '2011-08-14 14:10:38.948952', '2011-08-21 21:19:38.948952', '2011-08-16 23:18:38.948952', 'payée', 'expédiée', 17, 0, 0.1960, -10.0000, -1.9600, -11.9600);
INSERT INTO commandes VALUES (3452, '2011-09-13 06:15:36.682988', NULL, '2011-09-16 15:16:36.682988', 'facturée', 'en attente', 24, 100, 0.1960, 203.5500, 39.8958, 243.4458);
INSERT INTO commandes VALUES (3460, '2011-01-13 14:10:37.49918', NULL, '2011-01-15 17:20:37.49918', 'payée', 'en préparation', 16, 1000, 0.1960, 612.1300, 119.9775, 732.1075);
INSERT INTO commandes VALUES (3466, '2011-03-15 13:17:38.214321', NULL, NULL, 'non facturée', 'en attente', 23, 100, 0.1960, 422.5100, 82.8120, 505.3220);
INSERT INTO commandes VALUES (3453, '2010-12-13 14:12:36.783399', '2010-12-17 18:19:36.783399', '2010-12-17 15:20:36.783399', 'payée', 'expédiée', 13, 1000, 0.1960, 523.7700, 102.6589, 626.4289);
INSERT INTO commandes VALUES (3472, '2011-09-15 06:19:38.962657', '2011-09-18 14:22:38.962657', NULL, 'non facturée', 'expédiée', 15, 50, 0.1960, 192.3100, 37.6928, 230.0028);
INSERT INTO commandes VALUES (3467, '2011-09-11 06:16:38.463539', NULL, '2011-09-18 14:18:38.463539', 'payée', 'en préparation', 17, 15, 0.1960, 84.3200, 16.5267, 100.8467);
INSERT INTO commandes VALUES (3473, '2011-02-11 11:13:39.087535', '2011-02-19 16:20:39.087535', '2011-02-18 12:17:39.087535', 'facturée', 'expédiée', 26, 50, 0.1960, 149.7000, 29.3412, 179.0412);
INSERT INTO commandes VALUES (3454, '2011-03-18 06:19:36.956619', NULL, NULL, 'non facturée', 'en attente', 16, 100, 0.1960, 343.8900, 67.4024, 411.2924);
INSERT INTO commandes VALUES (3461, '2010-12-20 08:13:37.665834', NULL, '2010-12-26 11:18:37.665834', 'payée', 'prête à l''envoi', 21, 100, 0.1960, 458.0300, 89.7739, 547.8039);
INSERT INTO commandes VALUES (3455, '2011-07-12 14:14:37.081708', '2011-07-22 23:24:37.081708', '2011-07-14 17:22:37.081708', 'payée', 'expédiée', 26, 15, 0.1960, 51.8300, 10.1587, 61.9887);
INSERT INTO commandes VALUES (3456, '2011-01-15 11:19:37.214454', '2011-01-23 14:29:37.214454', '2011-01-21 12:27:37.214454', 'facturée', 'expédiée', 16, 50, 0.1960, 141.4000, 27.7144, 169.1144);
INSERT INTO commandes VALUES (3462, '2011-05-15 13:19:37.840278', NULL, '2011-05-25 17:27:37.840278', 'payée', 'en attente', 25, 5, 0.1960, 41.0900, 8.0536, 49.1436);
INSERT INTO commandes VALUES (3468, '2011-08-15 07:13:38.531616', '2011-08-18 13:17:38.531616', '2011-08-19 09:19:38.531616', 'payée', 'expédiée', 26, 100, 0.1960, 379.3800, 74.3585, 453.7385);
INSERT INTO commandes VALUES (3457, '2011-03-12 06:11:37.273228', '2011-03-20 11:20:37.273228', '2011-03-18 14:16:37.273228', 'payée', 'expédiée', 25, 50, 0.1960, 107.8000, 21.1288, 128.9288);
INSERT INTO commandes VALUES (3474, '2011-04-14 08:10:39.155795', '2011-04-18 12:11:39.155795', NULL, 'non facturée', 'expédiée', 26, 100, 0.1960, 366.4300, 71.8203, 438.2503);
INSERT INTO commandes VALUES (3463, '2011-02-15 06:15:37.898897', NULL, '2011-02-23 08:24:37.898897', 'facturée', 'en attente', 16, 100, 0.1960, 370.4200, 72.6023, 443.0223);
INSERT INTO commandes VALUES (3469, '2011-08-13 08:14:38.679706', NULL, NULL, 'non facturée', 'prête à l''envoi', 14, 50, 0.1960, 122.0000, 23.9120, 145.9120);
INSERT INTO commandes VALUES (3458, '2011-04-11 15:19:37.33958', NULL, NULL, 'non facturée', 'en attente', 21, 100, 0.1960, 435.9000, 85.4364, 521.3364);
INSERT INTO commandes VALUES (3459, '2010-12-12 12:16:37.481031', '2010-12-15 13:22:37.481031', NULL, 'non facturée', 'expédiée', 14, 0, 0.1960, 79.9200, 15.6643, 95.5843);
INSERT INTO commandes VALUES (3464, '2011-04-18 10:15:38.055579', NULL, '2011-04-28 17:20:38.055579', 'facturée', 'prête à l''envoi', 17, 5, 0.1960, -5.9700, -1.1701, -7.1401);
INSERT INTO commandes VALUES (3475, '2011-08-11 06:14:39.256284', '2011-08-21 13:17:39.256284', '2011-08-21 10:21:39.256284', 'payée', 'expédiée', 15, 5, 0.1960, 17.9300, 3.5143, 21.4443);
INSERT INTO commandes VALUES (3476, '2011-02-15 08:13:39.313925', '2011-02-24 13:15:39.313925', '2011-02-19 11:17:39.313925', 'facturée', 'expédiée', 15, 100, 0.1960, 457.6600, 89.7014, 547.3614);
INSERT INTO commandes VALUES (3477, '2011-09-20 07:15:39.505365', NULL, '2011-09-30 13:17:39.505365', 'payée', 'en attente', 26, 5, 0.1960, 39.9100, 7.8224, 47.7324);
INSERT INTO commandes VALUES (3486, '2011-06-18 13:19:40.286302', '2011-06-21 20:23:40.286302', NULL, 'non facturée', 'expédiée', 15, 50, 0.1960, 108.5800, 21.2817, 129.8617);
INSERT INTO commandes VALUES (3478, '2010-12-20 10:11:39.538723', NULL, '2010-12-22 20:15:39.538723', 'payée', 'prête à l''envoi', 24, 50, 0.1960, 141.9200, 27.8163, 169.7363);
INSERT INTO commandes VALUES (3487, '2010-12-13 15:10:40.353472', '2010-12-18 19:12:40.353472', '2010-12-19 19:12:40.353472', 'facturée', 'expédiée', 21, 100, 0.1960, 428.9000, 84.0644, 512.9644);
INSERT INTO commandes VALUES (3479, '2011-08-15 14:12:39.589796', NULL, NULL, 'non facturée', 'prête à l''envoi', 15, 1000, 0.1960, 522.3200, 102.3747, 624.6947);
INSERT INTO commandes VALUES (3480, '2011-08-12 07:15:39.789405', '2011-08-21 14:23:39.789405', '2011-08-17 16:19:39.789405', 'facturée', 'expédiée', 23, 5, 0.1960, 4.9400, 0.9682, 5.9082);
INSERT INTO commandes VALUES (3481, '2011-07-12 09:12:39.846628', NULL, '2011-07-22 15:16:39.846628', 'facturée', 'prête à l''envoi', 14, 5, 0.1960, 1.7900, 0.3508, 2.1408);
INSERT INTO commandes VALUES (3488, '2011-08-18 10:15:40.521164', '2011-08-23 11:24:40.521164', NULL, 'non facturée', 'expédiée', 22, 100, 0.1960, 295.8600, 57.9886, 353.8486);
INSERT INTO commandes VALUES (3482, '2011-07-11 09:17:39.896577', '2011-07-17 19:24:39.896577', '2011-07-17 10:20:39.896577', 'payée', 'expédiée', 21, 50, 0.1960, 165.8300, 32.5027, 198.3327);
INSERT INTO commandes VALUES (3489, '2011-05-15 13:19:40.778855', NULL, NULL, 'non facturée', 'en attente', 22, 0, 0.1960, -5.0000, -0.9800, -5.9800);
INSERT INTO commandes VALUES (3483, '2011-03-12 09:18:40.020015', NULL, '2011-03-20 13:25:40.020015', 'facturée', 'en attente', 14, 100, 0.1960, 326.8300, 64.0587, 390.8887);
INSERT INTO commandes VALUES (3484, '2011-01-20 14:12:40.105239', '2011-01-21 23:14:40.105239', NULL, 'non facturée', 'expédiée', 13, 100, 0.1960, 265.9200, 52.1203, 318.0403);
INSERT INTO commandes VALUES (3490, '2011-02-20 13:12:40.795622', '2011-02-21 17:15:40.795622', NULL, 'non facturée', 'expédiée', 26, 100, 0.1960, 367.0000, 71.9320, 438.9320);
INSERT INTO commandes VALUES (3485, '2011-07-15 10:10:40.179489', '2011-07-21 14:11:40.179489', '2011-07-23 20:14:40.179489', 'payée', 'expédiée', 16, 50, 0.1960, 172.1600, 33.7434, 205.9034);
INSERT INTO commandes VALUES (3491, '2011-05-20 13:11:40.944601', '2011-05-24 21:17:40.944601', '2011-05-22 18:15:40.944601', 'facturée', 'expédiée', 25, 0, 0.1960, 99.9000, 19.5804, 119.4804);
INSERT INTO commandes VALUES (3492, '2011-02-12 12:15:40.96243', NULL, NULL, 'non facturée', 'en attente', 21, 15, 0.1960, 73.8000, 14.4648, 88.2648);
INSERT INTO commandes VALUES (3510, '2011-04-15 15:14:43.492688', '2011-04-18 18:16:43.492688', '2011-04-16 21:17:43.492688', 'payée', 'expédiée', 26, 1000, 0.1960, 558.5600, 109.4778, 668.0378);
INSERT INTO commandes VALUES (3500, '2010-12-17 06:14:42.301815', NULL, NULL, 'non facturée', 'en attente', 13, 15, 0.1960, 73.3600, 14.3786, 87.7386);
INSERT INTO commandes VALUES (3530, '2011-04-11 11:16:46.042131', NULL, '2011-04-12 20:24:46.042131', 'payée', 'en préparation', 21, 50, 0.1960, 181.1400, 35.5034, 216.6434);
INSERT INTO commandes VALUES (3505, '2011-01-11 09:13:42.817454', '2011-01-20 10:15:42.817454', '2011-01-21 15:16:42.817454', 'facturée', 'expédiée', 24, 1000, 0.1960, 546.2900, 107.0728, 653.3628);
INSERT INTO commandes VALUES (3493, '2011-04-15 10:16:41.044428', '2011-04-19 16:24:41.044428', NULL, 'non facturée', 'expédiée', 21, 100, 0.1960, 258.1700, 50.6013, 308.7713);
INSERT INTO commandes VALUES (3516, '2011-09-11 06:15:44.283714', NULL, NULL, 'non facturée', 'prête à l''envoi', 16, 100, 0.1960, 205.4600, 40.2702, 245.7302);
INSERT INTO commandes VALUES (3511, '2011-06-13 08:14:43.642956', NULL, '2011-06-15 17:17:43.642956', 'payée', 'en préparation', 14, 50, 0.1960, 126.3200, 24.7587, 151.0787);
INSERT INTO commandes VALUES (3506, '2011-03-18 08:13:43.074957', NULL, NULL, 'non facturée', 'prête à l''envoi', 26, 5, 0.1960, 43.8900, 8.6024, 52.4924);
INSERT INTO commandes VALUES (3494, '2011-03-20 12:17:41.540173', NULL, NULL, 'non facturée', 'prête à l''envoi', 22, 15, 0.1960, 52.2000, 10.2312, 62.4312);
INSERT INTO commandes VALUES (3501, '2011-09-15 09:12:42.336298', '2011-09-19 16:22:42.336298', '2011-09-25 17:21:42.336298', 'payée', 'expédiée', 17, 100, 0.1960, 434.3000, 85.1228, 519.4228);
INSERT INTO commandes VALUES (3528, '2011-09-11 13:18:45.782114', '2011-09-12 22:20:45.782114', '2011-09-16 18:19:45.782114', 'facturée', 'expédiée', 21, 50, 0.1960, 125.6900, 24.6352, 150.3252);
INSERT INTO commandes VALUES (3525, '2011-06-20 12:13:45.148287', '2011-06-24 16:21:45.148287', NULL, 'non facturée', 'expédiée', 15, 100, 0.1960, 498.5800, 97.7217, 596.3017);
INSERT INTO commandes VALUES (3546, '2011-09-20 13:13:48.213057', NULL, NULL, 'non facturée', 'en préparation', 16, 1000, 0.1960, 552.6700, 108.3233, 660.9933);
INSERT INTO commandes VALUES (3512, '2011-01-20 09:13:43.73452', NULL, '2011-01-24 19:17:43.73452', 'payée', 'prête à l''envoi', 26, 100, 0.1960, 419.7900, 82.2788, 502.0688);
INSERT INTO commandes VALUES (3495, '2011-04-20 10:10:41.636121', '2011-04-23 14:15:41.636121', '2011-04-24 13:17:41.636121', 'payée', 'expédiée', 14, 100, 0.1960, 259.0700, 50.7777, 309.8477);
INSERT INTO commandes VALUES (3507, '2011-03-16 13:15:43.109768', NULL, NULL, 'non facturée', 'en attente', 15, 100, 0.1960, 229.9500, 45.0702, 275.0202);
INSERT INTO commandes VALUES (3520, '2011-01-12 08:16:44.833255', NULL, '2011-01-15 15:19:44.833255', 'payée', 'en préparation', 25, 100, 0.1960, 236.8500, 46.4226, 283.2726);
INSERT INTO commandes VALUES (3502, '2011-06-12 06:16:42.485302', '2011-06-19 14:19:42.485302', '2011-06-20 11:25:42.485302', 'facturée', 'expédiée', 22, 100, 0.1960, 366.6700, 71.8673, 438.5373);
INSERT INTO commandes VALUES (3508, '2011-07-15 14:18:43.309827', NULL, NULL, 'non facturée', 'en préparation', 21, 15, 0.1960, 64.9000, 12.7204, 77.6204);
INSERT INTO commandes VALUES (3496, '2011-05-19 11:11:41.877537', NULL, NULL, 'non facturée', 'en préparation', 23, 100, 0.1960, 242.9200, 47.6123, 290.5323);
INSERT INTO commandes VALUES (3503, '2011-01-14 06:14:42.619141', '2011-01-23 14:24:42.619141', NULL, 'non facturée', 'expédiée', 16, 5, 0.1960, 15.4900, 3.0360, 18.5260);
INSERT INTO commandes VALUES (3540, '2011-07-19 10:14:47.331984', '2011-07-24 14:15:47.331984', '2011-07-20 19:23:47.331984', 'payée', 'expédiée', 23, 1000, 0.1960, 554.7600, 108.7330, 663.4930);
INSERT INTO commandes VALUES (3534, '2011-09-16 13:12:46.632764', '2011-09-24 16:22:46.632764', '2011-09-23 20:22:46.632764', 'facturée', 'expédiée', 16, 100, 0.1960, 266.1700, 52.1693, 318.3393);
INSERT INTO commandes VALUES (3521, '2011-04-15 07:19:44.958451', '2011-04-24 09:26:44.958451', NULL, 'non facturée', 'expédiée', 26, 5, 0.1960, 7.9700, 1.5621, 9.5321);
INSERT INTO commandes VALUES (3517, '2011-09-18 11:11:44.383394', '2011-09-22 20:12:44.383394', NULL, 'non facturée', 'expédiée', 23, 100, 0.1960, 349.0000, 68.4040, 417.4040);
INSERT INTO commandes VALUES (3497, '2011-08-16 14:19:42.027581', '2011-08-26 23:23:42.027581', NULL, 'non facturée', 'expédiée', 13, 15, 0.1960, 52.8900, 10.3664, 63.2564);
INSERT INTO commandes VALUES (3498, '2011-04-20 09:13:42.144136', '2011-04-27 17:15:42.144136', NULL, 'non facturée', 'expédiée', 17, 0, 0.1960, -5.0000, -0.9800, -5.9800);
INSERT INTO commandes VALUES (3545, '2011-01-20 15:15:48.089863', NULL, '2011-01-28 01:17:48.089863', 'payée', 'en préparation', 22, 100, 0.1960, 482.2500, 94.5210, 576.7710);
INSERT INTO commandes VALUES (3513, '2011-07-14 14:13:43.867345', '2011-07-20 20:15:43.867345', NULL, 'non facturée', 'expédiée', 26, 1000, 0.1960, 576.8500, 113.0626, 689.9126);
INSERT INTO commandes VALUES (3504, '2011-05-19 14:18:42.669599', '2011-05-23 18:19:42.669599', NULL, 'non facturée', 'expédiée', 15, 100, 0.1960, 345.7300, 67.7631, 413.4931);
INSERT INTO commandes VALUES (3509, '2011-05-19 15:19:43.351163', NULL, '2011-05-29 23:21:43.351163', 'facturée', 'prête à l''envoi', 26, 100, 0.1960, 435.8800, 85.4325, 521.3125);
INSERT INTO commandes VALUES (3526, '2011-05-12 14:10:45.514128', '2011-05-18 18:12:45.514128', '2011-05-14 19:19:45.514128', 'facturée', 'expédiée', 22, 100, 0.1960, 365.5400, 71.6458, 437.1858);
INSERT INTO commandes VALUES (3499, '2011-05-11 12:14:42.169096', '2011-05-14 22:22:42.169096', NULL, 'non facturée', 'expédiée', 25, 100, 0.1960, 205.2000, 40.2192, 245.4192);
INSERT INTO commandes VALUES (3531, '2011-04-17 14:14:46.131804', '2011-04-20 00:17:46.131804', NULL, 'non facturée', 'expédiée', 21, 100, 0.1960, 351.6000, 68.9136, 420.5136);
INSERT INTO commandes VALUES (3522, '2011-01-16 08:11:45.008049', NULL, '2011-01-21 11:19:45.008049', 'facturée', 'en attente', 26, 50, 0.1960, 162.2600, 31.8030, 194.0630);
INSERT INTO commandes VALUES (3514, '2011-07-19 11:12:44.117469', NULL, '2011-07-28 16:22:44.117469', 'facturée', 'en préparation', 15, 100, 0.1960, 293.1700, 57.4613, 350.6313);
INSERT INTO commandes VALUES (3518, '2011-09-16 14:11:44.608478', '2011-09-21 17:12:44.608478', NULL, 'non facturée', 'expédiée', 15, 50, 0.1960, 125.0600, 24.5118, 149.5718);
INSERT INTO commandes VALUES (3541, '2011-01-20 14:10:47.515211', NULL, NULL, 'non facturée', 'prête à l''envoi', 13, 100, 0.1960, 257.8000, 50.5288, 308.3288);
INSERT INTO commandes VALUES (3523, '2011-07-18 12:13:45.099397', '2011-07-24 13:19:45.099397', NULL, 'non facturée', 'expédiée', 17, 15, 0.1960, 96.4100, 18.8964, 115.3064);
INSERT INTO commandes VALUES (3524, '2011-04-11 06:13:45.140352', '2011-04-16 16:20:45.140352', NULL, 'non facturée', 'expédiée', 17, 0, 0.1960, NULL, NULL, NULL);
INSERT INTO commandes VALUES (3515, '2011-08-18 09:16:44.199051', NULL, '2011-08-24 18:17:44.199051', 'facturée', 'en attente', 15, 50, 0.1960, 152.0000, 29.7920, 181.7920);
INSERT INTO commandes VALUES (3533, '2011-02-18 11:16:46.499454', '2011-02-26 17:22:46.499454', '2011-02-25 15:17:46.499454', 'payée', 'expédiée', 17, 100, 0.1960, 466.5300, 91.4399, 557.9699);
INSERT INTO commandes VALUES (3529, '2011-06-19 08:12:45.883589', '2011-06-26 17:17:45.883589', '2011-06-28 09:21:45.883589', 'payée', 'expédiée', 15, 100, 0.1960, 466.8300, 91.4987, 558.3287);
INSERT INTO commandes VALUES (3535, '2011-08-17 11:11:46.799018', NULL, '2011-08-26 16:14:46.799018', 'payée', 'en attente', 16, 15, 0.1960, 68.4400, 13.4142, 81.8542);
INSERT INTO commandes VALUES (3519, '2011-08-13 11:11:44.724844', '2011-08-19 14:13:44.724844', NULL, 'non facturée', 'expédiée', 25, 15, 0.1960, 56.8300, 11.1387, 67.9687);
INSERT INTO commandes VALUES (3527, '2011-02-19 15:10:45.634425', NULL, '2011-02-20 17:16:45.634425', 'payée', 'prête à l''envoi', 22, 50, 0.1960, 101.0300, 19.8019, 120.8319);
INSERT INTO commandes VALUES (3532, '2011-03-20 11:15:46.258289', NULL, NULL, 'non facturée', 'en attente', 24, 50, 0.1960, 182.1400, 35.6994, 217.8394);
INSERT INTO commandes VALUES (3538, '2011-05-18 11:14:47.099146', '2011-05-23 18:21:47.099146', NULL, 'non facturée', 'expédiée', 14, 100, 0.1960, 319.9200, 62.7043, 382.6243);
INSERT INTO commandes VALUES (3537, '2011-02-11 15:14:46.931004', '2011-02-17 16:16:46.931004', '2011-02-14 16:20:46.931004', 'facturée', 'expédiée', 15, 100, 0.1960, 490.1500, 96.0694, 586.2194);
INSERT INTO commandes VALUES (3536, '2011-03-14 10:14:46.857363', '2011-03-16 19:21:46.857363', NULL, 'non facturée', 'expédiée', 13, 50, 0.1960, 140.4800, 27.5341, 168.0141);
INSERT INTO commandes VALUES (3542, '2011-07-13 14:17:47.781696', NULL, NULL, 'non facturée', 'en attente', 13, 100, 0.1960, 457.3500, 89.6406, 546.9906);
INSERT INTO commandes VALUES (3544, '2011-01-13 07:19:48.006358', '2011-01-23 13:28:48.006358', NULL, 'non facturée', 'expédiée', 17, 50, 0.1960, 170.2100, 33.3612, 203.5712);
INSERT INTO commandes VALUES (3539, '2011-06-16 14:15:47.248716', NULL, NULL, 'non facturée', 'en préparation', 13, 50, 0.1960, 119.3100, 23.3848, 142.6948);
INSERT INTO commandes VALUES (3543, '2011-09-16 14:14:47.931271', NULL, NULL, 'non facturée', 'en préparation', 16, 50, 0.1960, 156.3200, 30.6387, 186.9587);
INSERT INTO commandes VALUES (3547, '2011-07-13 14:15:48.422596', '2011-07-21 15:23:48.422596', '2011-07-21 23:18:48.422596', 'payée', 'expédiée', 17, 1000, 0.1960, 509.4600, 99.8542, 609.3142);
INSERT INTO commandes VALUES (3548, '2011-03-15 07:12:48.596335', '2011-03-18 14:18:48.596335', NULL, 'non facturée', 'expédiée', 24, 1000, 0.1960, 513.3800, 100.6225, 614.0025);
INSERT INTO commandes VALUES (3549, '2011-04-16 06:17:48.837565', '2011-04-17 11:23:48.837565', NULL, 'non facturée', 'expédiée', 17, 100, 0.1960, 298.1100, 58.4296, 356.5396);
INSERT INTO commandes VALUES (3551, '2011-08-16 15:11:49.072099', NULL, NULL, 'non facturée', 'prête à l''envoi', 13, 100, 0.1960, 333.6400, 65.3934, 399.0334);
INSERT INTO commandes VALUES (3550, '2011-03-13 09:10:48.996981', '2011-03-20 19:18:48.996981', NULL, 'non facturée', 'expédiée', 16, 15, 0.1960, 56.6800, 11.1093, 67.7893);
INSERT INTO commandes VALUES (3565, '2011-07-16 14:19:50.703599', '2011-07-25 18:22:50.703599', NULL, 'non facturée', 'expédiée', 15, 100, 0.1960, 393.2500, 77.0770, 470.3270);
INSERT INTO commandes VALUES (3552, '2011-08-18 06:10:49.230102', NULL, '2011-08-26 14:15:49.230102', 'payée', 'prête à l''envoi', 23, 1000, 0.1960, 518.4100, 101.6084, 620.0184);
INSERT INTO commandes VALUES (3560, '2011-06-19 10:16:50.144396', NULL, '2011-06-23 18:17:50.144396', 'payée', 'en attente', 13, 100, 0.1960, 253.7900, 49.7428, 303.5328);
INSERT INTO commandes VALUES (3553, '2011-05-16 10:12:49.362056', '2011-05-18 14:17:49.362056', NULL, 'non facturée', 'expédiée', 15, 15, 0.1960, 81.9200, 16.0563, 97.9763);
INSERT INTO commandes VALUES (3554, '2010-12-15 07:14:49.429811', '2010-12-25 08:24:49.429811', '2010-12-25 08:19:49.429811', 'payée', 'expédiée', 24, 0, 0.1960, NULL, NULL, NULL);
INSERT INTO commandes VALUES (3561, '2011-03-14 10:19:50.287282', NULL, NULL, 'non facturée', 'prête à l''envoi', 24, 15, 0.1960, 97.2800, 19.0669, 116.3469);
INSERT INTO commandes VALUES (3555, '2011-06-12 15:14:49.438852', '2011-06-13 21:16:49.438852', NULL, 'non facturée', 'expédiée', 21, 100, 0.1960, 311.4200, 61.0383, 372.4583);
INSERT INTO commandes VALUES (3576, '2011-02-11 07:19:52.005295', '2011-02-21 09:21:52.005295', '2011-02-16 09:20:52.005295', 'facturée', 'expédiée', 24, 100, 0.1960, 393.7500, 77.1750, 470.9250);
INSERT INTO commandes VALUES (3572, '2010-12-18 15:19:51.433834', NULL, '2010-12-19 22:26:51.433834', 'payée', 'en attente', 17, 100, 0.1960, 451.9000, 88.5724, 540.4724);
INSERT INTO commandes VALUES (3566, '2011-06-20 14:10:50.829944', NULL, '2011-06-24 21:15:50.829944', 'payée', 'prête à l''envoi', 16, 100, 0.1960, 446.2400, 87.4630, 533.7030);
INSERT INTO commandes VALUES (3562, '2010-12-19 08:16:50.335885', NULL, NULL, 'non facturée', 'en attente', 15, 100, 0.1960, 487.3400, 95.5186, 582.8586);
INSERT INTO commandes VALUES (3556, '2011-01-13 15:15:49.555244', '2011-01-23 01:17:49.555244', NULL, 'non facturée', 'expédiée', 24, 100, 0.1960, 383.0600, 75.0798, 458.1398);
INSERT INTO commandes VALUES (3567, '2011-05-16 08:11:51.018854', NULL, NULL, 'non facturée', 'en préparation', 24, 5, 0.1960, 13.1900, 2.5852, 15.7752);
INSERT INTO commandes VALUES (3568, '2011-02-18 13:12:51.060647', NULL, '2011-02-24 20:21:51.060647', 'facturée', 'en préparation', 26, 15, 0.1960, 65.3600, 12.8106, 78.1706);
INSERT INTO commandes VALUES (3569, '2011-02-16 10:11:51.177056', NULL, '2011-02-22 16:18:51.177056', 'payée', 'prête à l''envoi', 26, 5, 0.1960, -15.0000, -2.9400, -17.9400);
INSERT INTO commandes VALUES (3573, '2011-01-13 10:10:51.58194', '2011-01-18 12:12:51.58194', '2011-01-18 16:15:51.58194', 'facturée', 'expédiée', 22, 100, 0.1960, 421.3700, 82.5885, 503.9585);
INSERT INTO commandes VALUES (3563, '2011-08-20 15:15:50.487516', NULL, '2011-08-25 23:17:50.487516', 'facturée', 'en préparation', 14, 100, 0.1960, 318.1100, 62.3496, 380.4596);
INSERT INTO commandes VALUES (3557, '2011-08-13 12:15:49.696473', '2011-08-17 20:16:49.696473', NULL, 'non facturée', 'expédiée', 13, 100, 0.1960, 400.2400, 78.4470, 478.6870);
INSERT INTO commandes VALUES (3558, '2011-07-20 10:14:49.987688', NULL, NULL, 'non facturée', 'en préparation', 26, 50, 0.1960, 185.2400, 36.3070, 221.5470);
INSERT INTO commandes VALUES (3564, '2011-07-15 07:13:50.653716', '2011-07-19 08:23:50.653716', NULL, 'non facturée', 'expédiée', 26, 15, 0.1960, 82.3600, 16.1426, 98.5026);
INSERT INTO commandes VALUES (3577, '2011-02-11 08:10:52.113525', NULL, '2011-02-12 11:16:52.113525', 'facturée', 'en attente', 24, 100, 0.1960, 287.2500, 56.3010, 343.5510);
INSERT INTO commandes VALUES (3559, '2011-09-16 12:14:50.05306', NULL, NULL, 'non facturée', 'en attente', 14, 100, 0.1960, 456.3800, 89.4505, 545.8305);
INSERT INTO commandes VALUES (3578, '2011-05-20 06:14:52.413155', '2011-05-24 11:22:52.413155', NULL, 'non facturée', 'expédiée', 13, 0, 0.1960, 6.1600, 1.2074, 7.3674);
INSERT INTO commandes VALUES (3570, '2011-07-18 11:18:51.226805', '2011-07-21 12:26:51.226805', '2011-07-23 19:20:51.226805', 'facturée', 'expédiée', 22, 100, 0.1960, 422.2700, 82.7649, 505.0349);
INSERT INTO commandes VALUES (3574, '2011-05-15 09:10:51.774162', '2011-05-16 11:14:51.774162', '2011-05-16 17:19:51.774162', 'facturée', 'expédiée', 22, 100, 0.1960, 200.2600, 39.2510, 239.5110);
INSERT INTO commandes VALUES (3571, '2011-01-13 06:17:51.366264', '2011-01-19 08:21:51.366264', '2011-01-16 07:22:51.366264', 'payée', 'expédiée', 25, 5, 0.1960, 20.7700, 4.0709, 24.8409);
INSERT INTO commandes VALUES (3575, '2011-09-20 13:18:51.938656', NULL, NULL, 'non facturée', 'en préparation', 14, 100, 0.1960, 345.8100, 67.7788, 413.5888);


--
-- TOC entry 1998 (class 0 OID 21586)
-- Dependencies: 1577
-- Data for Name: lignes_commande; Type: TABLE DATA; Schema: app; Owner: formation_admin
--

INSERT INTO lignes_commande VALUES (6084, 5, 10, 3079, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (6085, 10, 6, 3079, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (6086, 4, 2, 3079, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (6087, 4, 14, 3079, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (6088, 8, 13, 3079, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (6089, 6, 12, 3079, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (6090, 10, 4, 3079, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (6091, 10, 3, 3079, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (6092, 2, 5, 3079, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (6093, 4, 1, 3079, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (6094, 2, 7, 3079, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (6095, 1, 9, 3079, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6096, 1, 8, 3079, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6097, 5, 13, 3080, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (6098, 8, 11, 3080, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (6099, 6, 7, 3080, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (6100, 10, 4, 3080, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (6101, 3, 3, 3080, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (6102, 1, 9, 3080, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6103, 1, 9, 3081, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6104, 1, 8, 3081, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6105, 1, 12, 3082, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (6106, 10, 3, 3082, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (6107, 1, 9, 3082, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6108, 2, 11, 3083, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (6109, 7, 2, 3083, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (6110, 9, 7, 3083, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (6111, 1, 1, 3083, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (6112, 10, 6, 3083, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (6113, 8, 12, 3083, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (6114, 5, 13, 3083, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (6115, 10, 14, 3083, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (6116, 1, 4, 3083, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (6117, 9, 10, 3083, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (6118, 1, 8, 3083, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6119, 1, 9, 3083, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6120, 8, 1, 3084, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (6121, 8, 14, 3084, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (6122, 5, 6, 3084, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (6123, 1, 8, 3084, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6124, 1, 9, 3084, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6125, 1, 13, 3085, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (6126, 9, 3, 3085, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (6127, 1, 14, 3085, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (6128, 4, 4, 3085, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (6129, 6, 6, 3085, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (6130, 2, 10, 3085, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (6131, 7, 7, 3085, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (6132, 3, 5, 3085, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (6133, 3, 1, 3085, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (6134, 8, 14, 3086, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (6135, 3, 13, 3086, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (6136, 9, 3, 3086, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (6137, 7, 2, 3086, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (6138, 1, 7, 3086, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (6139, 5, 11, 3086, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (6140, 5, 1, 3086, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (6141, 1, 12, 3086, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (6142, 7, 6, 3086, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (6143, 3, 10, 3086, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (6144, 8, 4, 3086, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (6145, 2, 5, 3086, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (6146, 3, 7, 3087, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (6147, 8, 11, 3087, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (6148, 9, 12, 3087, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (6149, 7, 3, 3087, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (6150, 4, 2, 3087, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (6151, 10, 10, 3087, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (6152, 3, 1, 3087, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (6153, 6, 6, 3087, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (6154, 3, 13, 3087, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (6155, 6, 5, 3087, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (6156, 8, 4, 3087, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (6157, 7, 14, 3087, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (6158, 1, 9, 3087, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6159, 1, 8, 3087, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6160, 1, 9, 3088, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6161, 4, 11, 3089, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (6162, 1, 10, 3089, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (6163, 5, 3, 3089, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (6164, 6, 1, 3089, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (6165, 9, 14, 3089, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (6166, 6, 6, 3089, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (6167, 7, 2, 3089, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (6168, 1, 7, 3089, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (6169, 8, 13, 3089, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (6170, 6, 12, 3089, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (6171, 8, 5, 3089, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (6172, 10, 4, 3089, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (6173, 1, 9, 3089, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6174, 9, 13, 3090, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (6175, 3, 7, 3090, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (6176, 10, 3, 3090, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (6177, 5, 14, 3090, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (6178, 10, 10, 3090, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (6179, 6, 4, 3090, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (6180, 3, 11, 3090, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (6181, 6, 1, 3090, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (6182, 9, 12, 3090, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (6183, 3, 6, 3090, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (6184, 1, 8, 3090, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6185, 1, 9, 3090, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6186, 3, 4, 3091, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (6187, 4, 12, 3091, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (6188, 2, 1, 3091, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (6189, 9, 7, 3091, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (6190, 2, 13, 3091, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (6191, 7, 14, 3091, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (6192, 6, 11, 3091, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (6193, 2, 2, 3091, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (6194, 5, 10, 3091, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (6195, 1, 5, 3091, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (6196, 10, 3, 3091, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (6197, 1, 9, 3091, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6083, 5, 11, 3079, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (6198, 9, 5, 3092, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (6199, 4, 1, 3092, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (6200, 3, 14, 3092, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (6201, 3, 6, 3092, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (6202, 4, 10, 3092, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (6203, 1, 8, 3092, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6204, 1, 9, 3092, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6205, 6, 7, 3093, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (6206, 10, 4, 3093, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (6207, 5, 5, 3093, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (6208, 8, 10, 3093, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (6209, 4, 1, 3093, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (6210, 7, 13, 3093, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (6211, 7, 2, 3093, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (6212, 6, 11, 3093, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (6213, 4, 3, 3093, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (6214, 2, 6, 3093, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (6215, 8, 14, 3093, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (6216, 1, 8, 3093, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6217, 1, 9, 3093, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6218, 1, 11, 3094, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (6219, 8, 6, 3094, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (6220, 7, 14, 3094, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (6221, 10, 7, 3094, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (6222, 1, 1, 3094, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (6223, 1, 8, 3094, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6224, 1, 9, 3094, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6225, 3, 1, 3095, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (6226, 4, 14, 3095, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (6227, 4, 11, 3095, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (6228, 10, 13, 3095, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (6229, 9, 5, 3095, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (6230, 3, 12, 3095, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (6231, 5, 10, 3095, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (6232, 7, 3, 3095, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (6233, 7, 6, 3095, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (6234, 9, 12, 3096, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (6235, 1, 13, 3096, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (6236, 7, 1, 3096, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (6237, 6, 7, 3096, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (6238, 3, 6, 3096, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (6239, 3, 3, 3096, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (6240, 1, 8, 3096, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6241, 1, 9, 3096, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6242, 1, 9, 3097, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6243, 7, 12, 3098, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (6244, 6, 11, 3098, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (6245, 4, 4, 3098, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (6246, 7, 5, 3098, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (6247, 5, 1, 3098, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (6248, 7, 14, 3098, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (6249, 1, 7, 3098, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (6250, 2, 3, 3098, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (6251, 3, 2, 3098, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (6252, 2, 6, 3098, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (6253, 5, 13, 3098, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (6254, 4, 10, 3098, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (6255, 1, 9, 3098, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6256, 5, 3, 3099, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (6257, 8, 7, 3099, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (6258, 8, 4, 3099, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (6259, 7, 5, 3099, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (6260, 8, 14, 3099, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (6261, 1, 11, 3099, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (6262, 7, 1, 3099, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (6263, 4, 12, 3099, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (6264, 1, 13, 3100, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (6265, 1, 8, 3100, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6266, 1, 11, 3101, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (6267, 6, 2, 3101, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (6268, 5, 3, 3101, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (6269, 3, 12, 3101, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (6270, 8, 10, 3101, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (6271, 1, 8, 3101, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6272, 5, 14, 3102, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (6273, 4, 4, 3102, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (6274, 6, 13, 3102, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (6275, 9, 5, 3102, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (6276, 2, 7, 3102, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (6277, 3, 10, 3102, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (6278, 6, 6, 3102, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (6279, 9, 2, 3102, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (6280, 3, 1, 3102, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (6281, 2, 3, 3102, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (6282, 2, 11, 3102, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (6283, 6, 12, 3102, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (6284, 1, 9, 3102, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6285, 1, 8, 3102, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6286, 1, 10, 3103, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (6287, 9, 6, 3103, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (6288, 6, 7, 3103, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (6289, 7, 11, 3103, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (6290, 8, 12, 3103, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (6291, 10, 5, 3103, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (6292, 8, 3, 3103, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (6293, 4, 14, 3103, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (6294, 4, 4, 3103, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (6295, 10, 1, 3103, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (6296, 1, 13, 3103, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (6297, 9, 2, 3103, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (6298, 1, 8, 3103, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6299, 9, 7, 3104, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (6300, 8, 3, 3104, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (6301, 7, 2, 3104, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (6302, 4, 12, 3104, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (6303, 6, 1, 3104, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (6304, 1, 8, 3104, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6305, 1, 9, 3104, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6306, 8, 7, 3105, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (6307, 7, 6, 3105, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (6308, 3, 14, 3105, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (6309, 8, 1, 3105, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (6310, 5, 4, 3105, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (6311, 1, 8, 3105, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6312, 1, 9, 3105, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6313, 6, 12, 3106, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (6314, 2, 13, 3106, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (6315, 2, 5, 3106, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (6316, 1, 8, 3106, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6317, 8, 1, 3107, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (6318, 4, 4, 3107, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (6319, 3, 11, 3107, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (6320, 6, 3, 3107, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (6321, 2, 5, 3107, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (6322, 9, 12, 3107, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (6323, 10, 6, 3107, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (6324, 7, 7, 3107, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (6325, 8, 2, 3107, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (6326, 5, 10, 3107, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (6327, 4, 14, 3107, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (6328, 3, 13, 3107, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (6329, 1, 9, 3107, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6330, 1, 8, 3107, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6331, 8, 4, 3108, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (6332, 3, 13, 3108, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (6333, 7, 14, 3108, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (6334, 6, 3, 3108, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (6335, 5, 6, 3108, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (6336, 2, 10, 3108, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (6337, 1, 9, 3108, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6338, 7, 3, 3109, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (6339, 5, 12, 3109, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (6340, 1, 2, 3109, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (6341, 1, 10, 3109, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (6342, 7, 5, 3109, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (6343, 1, 9, 3109, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6344, 1, 11, 3110, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (6345, 2, 6, 3110, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (6346, 6, 12, 3110, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (6347, 8, 7, 3110, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (6348, 4, 6, 3111, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (6349, 5, 14, 3111, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (6350, 1, 7, 3111, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (6351, 9, 10, 3111, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (6352, 7, 1, 3111, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (6353, 7, 12, 3111, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (6354, 5, 11, 3111, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (6355, 6, 3, 3111, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (6356, 10, 14, 3112, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (6357, 3, 4, 3112, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (6358, 5, 5, 3112, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (6359, 6, 1, 3112, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (6360, 4, 7, 3112, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (6361, 10, 12, 3112, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (6362, 2, 2, 3112, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (6363, 2, 10, 3112, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (6364, 3, 3, 3112, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (6365, 3, 11, 3112, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (6366, 4, 13, 3112, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (6367, 9, 6, 3112, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (6368, 1, 8, 3112, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6369, 1, 9, 3112, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6370, 8, 3, 3113, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (6371, 2, 10, 3113, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (6372, 3, 2, 3113, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (6373, 2, 4, 3113, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (6374, 6, 1, 3113, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (6375, 4, 6, 3113, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (6376, 10, 14, 3113, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (6377, 3, 7, 3113, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (6378, 1, 11, 3113, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (6379, 5, 5, 3113, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (6380, 8, 13, 3113, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (6381, 4, 12, 3113, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (6382, 2, 1, 3114, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (6383, 7, 13, 3114, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (6384, 9, 3, 3114, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (6385, 1, 8, 3114, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6386, 9, 5, 3115, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (6387, 3, 7, 3115, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (6388, 1, 4, 3115, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (6389, 7, 13, 3115, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (6390, 3, 11, 3115, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (6391, 7, 2, 3115, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (6392, 10, 6, 3115, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (6393, 10, 12, 3115, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (6394, 4, 14, 3115, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (6395, 1, 10, 3115, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (6396, 3, 1, 3115, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (6397, 1, 8, 3115, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6398, 7, 14, 3116, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (6399, 9, 2, 3116, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (6400, 7, 12, 3116, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (6401, 1, 5, 3116, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (6402, 2, 13, 3116, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (6403, 7, 10, 3116, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (6404, 2, 1, 3116, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (6405, 5, 3, 3116, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (6406, 8, 6, 3116, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (6407, 8, 4, 3116, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (6408, 3, 11, 3116, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (6409, 4, 7, 3116, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (6410, 1, 9, 3116, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6411, 1, 8, 3117, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6412, 1, 9, 3117, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6413, 1, 12, 3118, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (6414, 9, 13, 3118, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (6415, 10, 3, 3118, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (6416, 6, 14, 3118, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (6417, 6, 11, 3118, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (6418, 6, 2, 3118, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (6419, 10, 4, 3118, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (6420, 5, 5, 3118, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (6421, 3, 6, 3118, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (6422, 9, 10, 3118, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (6423, 5, 3, 3119, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (6424, 6, 5, 3119, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (6425, 2, 4, 3119, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (6426, 7, 14, 3119, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (6427, 9, 6, 3119, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (6428, 6, 7, 3119, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (6429, 1, 9, 3119, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6430, 1, 8, 3119, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6431, 7, 10, 3120, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (6432, 2, 12, 3120, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (6433, 6, 14, 3120, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (6434, 6, 3, 3120, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (6435, 9, 7, 3120, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (6436, 7, 1, 3120, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (6437, 5, 2, 3120, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (6438, 8, 13, 3120, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (6439, 2, 6, 3120, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (6440, 10, 5, 3120, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (6441, 4, 11, 3120, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (6442, 2, 4, 3120, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (6443, 1, 9, 3120, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6444, 9, 10, 3121, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (6445, 1, 4, 3121, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (6446, 4, 11, 3121, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (6447, 3, 1, 3121, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (6448, 6, 14, 3121, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (6449, 9, 7, 3121, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (6450, 5, 3, 3121, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (6451, 2, 13, 3121, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (6452, 1, 9, 3121, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6453, 1, 8, 3121, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6454, 6, 3, 3122, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (6455, 5, 6, 3122, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (6456, 5, 13, 3122, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (6457, 7, 4, 3122, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (6458, 1, 10, 3122, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (6459, 1, 12, 3122, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (6460, 5, 14, 3122, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (6461, 7, 2, 3122, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (6462, 5, 7, 3122, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (6463, 3, 11, 3122, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (6464, 9, 5, 3122, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (6465, 4, 1, 3122, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (6466, 1, 8, 3122, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6467, 1, 14, 3123, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (6468, 2, 10, 3123, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (6469, 7, 12, 3123, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (6470, 4, 4, 3123, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (6471, 7, 5, 3123, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (6472, 1, 9, 3123, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6473, 10, 3, 3124, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (6474, 8, 10, 3124, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (6475, 8, 5, 3124, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (6476, 6, 2, 3124, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (6477, 3, 4, 3124, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (6478, 2, 1, 3124, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (6479, 3, 12, 3124, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (6480, 3, 13, 3124, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (6481, 2, 14, 3124, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (6482, 7, 6, 3124, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (6483, 10, 11, 3124, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (6484, 7, 7, 3124, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (6485, 1, 9, 3124, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6486, 1, 8, 3124, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6487, 9, 11, 3125, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (6488, 9, 14, 3125, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (6489, 9, 13, 3125, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (6490, 10, 2, 3125, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (6491, 2, 7, 3125, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (6492, 9, 1, 3125, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (6493, 2, 6, 3125, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (6494, 8, 3, 3125, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (6495, 3, 4, 3125, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (6496, 1, 8, 3125, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6497, 1, 9, 3125, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6498, 1, 14, 3126, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (6499, 7, 12, 3126, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (6500, 3, 11, 3126, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (6501, 8, 6, 3126, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (6502, 2, 2, 3126, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (6503, 6, 5, 3126, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (6504, 10, 10, 3126, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (6505, 1, 9, 3126, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6506, 1, 8, 3127, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6507, 1, 9, 3127, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6508, 9, 7, 3128, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (6509, 6, 12, 3128, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (6510, 5, 10, 3128, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (6511, 7, 6, 3128, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (6512, 4, 5, 3128, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (6513, 4, 1, 3128, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (6514, 8, 13, 3128, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (6515, 3, 11, 3128, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (6516, 1, 9, 3128, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6517, 8, 11, 3129, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (6518, 10, 10, 3129, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (6519, 4, 1, 3129, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (6520, 8, 14, 3129, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (6521, 6, 4, 3129, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (6522, 7, 13, 3129, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (6523, 6, 7, 3129, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (6524, 8, 2, 3129, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (6525, 2, 12, 3129, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (6526, 6, 3, 3129, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (6527, 1, 6, 3129, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (6528, 10, 5, 3129, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (6529, 1, 8, 3129, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6530, 3, 3, 3130, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (6531, 7, 4, 3130, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (6532, 1, 9, 3130, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6533, 7, 5, 3131, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (6534, 4, 11, 3131, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (6535, 5, 2, 3131, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (6536, 3, 14, 3131, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (6537, 10, 12, 3131, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (6538, 9, 3, 3131, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (6539, 2, 13, 3131, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (6540, 7, 1, 3131, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (6541, 8, 10, 3131, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (6542, 6, 4, 3131, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (6543, 5, 7, 3131, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (6544, 4, 6, 3131, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (6545, 5, 14, 3132, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (6546, 2, 1, 3132, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (6547, 2, 6, 3132, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (6548, 2, 2, 3132, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (6549, 9, 13, 3133, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (6550, 10, 6, 3133, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (6551, 6, 11, 3133, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (6552, 8, 7, 3133, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (6553, 1, 3, 3133, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (6554, 6, 14, 3133, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (6555, 5, 1, 3133, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (6556, 5, 2, 3133, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (6557, 10, 10, 3133, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (6558, 8, 12, 3133, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (6559, 4, 4, 3133, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (6560, 9, 5, 3133, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (6561, 1, 8, 3133, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6562, 1, 9, 3133, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6563, 10, 13, 3134, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (6564, 6, 3, 3134, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (6565, 4, 7, 3134, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (6566, 1, 11, 3134, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (6567, 9, 14, 3134, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (6568, 8, 4, 3134, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (6569, 5, 5, 3135, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (6570, 8, 14, 3135, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (6571, 8, 2, 3135, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (6572, 3, 6, 3135, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (6573, 7, 11, 3135, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (6574, 3, 13, 3135, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (6575, 1, 10, 3135, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (6576, 8, 1, 3135, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (6577, 9, 12, 3135, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (6578, 5, 3, 3135, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (6579, 2, 4, 3135, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (6580, 9, 7, 3135, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (6581, 4, 7, 3136, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (6582, 9, 1, 3136, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (6583, 2, 12, 3136, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (6584, 1, 8, 3136, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6585, 1, 9, 3136, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6586, 5, 11, 3137, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (6587, 7, 12, 3137, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (6588, 9, 13, 3137, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (6589, 9, 2, 3137, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (6590, 5, 6, 3137, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (6591, 4, 7, 3137, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (6592, 6, 1, 3137, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (6593, 3, 14, 3137, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (6594, 7, 10, 3137, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (6595, 3, 3, 3137, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (6596, 6, 5, 3137, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (6597, 7, 4, 3137, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (6598, 1, 8, 3137, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6599, 1, 9, 3137, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6600, 3, 4, 3138, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (6601, 1, 8, 3138, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6602, 10, 2, 3139, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (6603, 1, 9, 3139, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6604, 2, 1, 3140, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (6605, 4, 6, 3140, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (6606, 2, 7, 3140, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (6607, 2, 13, 3140, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (6608, 9, 10, 3140, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (6609, 8, 12, 3140, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (6610, 1, 3, 3140, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (6611, 1, 8, 3140, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6612, 1, 9, 3140, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6613, 1, 11, 3141, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (6614, 5, 3, 3141, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (6615, 10, 13, 3141, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (6616, 8, 12, 3141, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (6617, 5, 5, 3141, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (6618, 3, 4, 3141, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (6619, 8, 2, 3141, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (6620, 1, 8, 3141, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6621, 2, 1, 3142, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (6622, 4, 4, 3142, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (6623, 2, 12, 3143, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (6624, 5, 1, 3143, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (6625, 7, 6, 3143, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (6626, 6, 4, 3144, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (6627, 9, 10, 3145, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (6628, 9, 2, 3145, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (6629, 7, 4, 3145, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (6630, 4, 13, 3145, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (6631, 1, 14, 3145, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (6632, 5, 12, 3145, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (6633, 10, 11, 3145, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (6634, 5, 6, 3145, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (6635, 5, 5, 3145, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (6636, 3, 3, 3145, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (6637, 7, 7, 3145, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (6638, 7, 1, 3145, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (6639, 1, 9, 3145, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6640, 10, 7, 3146, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (6641, 7, 11, 3146, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (6642, 4, 2, 3146, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (6643, 7, 3, 3146, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (6644, 10, 1, 3146, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (6645, 10, 13, 3146, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (6646, 1, 10, 3146, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (6647, 1, 6, 3146, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (6648, 5, 5, 3146, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (6649, 2, 12, 3146, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (6650, 5, 4, 3146, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (6651, 5, 14, 3146, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (6652, 1, 9, 3146, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6653, 6, 13, 3148, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (6654, 7, 4, 3148, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (6655, 1, 6, 3148, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (6656, 8, 5, 3148, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (6657, 3, 1, 3148, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (6658, 7, 14, 3148, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (6659, 4, 3, 3148, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (6660, 10, 10, 3148, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (6661, 7, 11, 3149, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (6662, 5, 12, 3149, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (6663, 7, 1, 3149, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (6664, 8, 2, 3149, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (6665, 10, 7, 3149, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (6666, 9, 13, 3149, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (6667, 2, 4, 3149, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (6668, 4, 5, 3149, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (6669, 4, 6, 3149, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (6670, 1, 8, 3149, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6671, 4, 6, 3150, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (6672, 6, 4, 3150, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (6673, 4, 2, 3150, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (6674, 10, 11, 3150, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (6675, 2, 10, 3150, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (6676, 5, 13, 3150, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (6677, 8, 12, 3150, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (6678, 5, 14, 3150, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (6679, 1, 3, 3150, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (6680, 1, 1, 3150, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (6681, 5, 5, 3150, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (6682, 3, 7, 3150, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (6683, 5, 1, 3151, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (6684, 6, 2, 3151, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (6685, 5, 3, 3151, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (6686, 4, 14, 3151, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (6687, 4, 6, 3151, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (6688, 6, 7, 3151, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (6689, 8, 13, 3151, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (6690, 8, 5, 3151, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (6691, 10, 4, 3151, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (6692, 6, 12, 3151, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (6693, 1, 9, 3151, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6694, 8, 14, 3152, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (6695, 7, 3, 3152, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (6696, 2, 10, 3152, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (6697, 2, 7, 3152, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (6698, 4, 12, 3152, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (6699, 7, 1, 3152, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (6700, 3, 11, 3152, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (6701, 5, 13, 3152, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (6702, 1, 2, 3152, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (6703, 5, 6, 3152, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (6704, 8, 5, 3152, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (6705, 5, 4, 3152, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (6706, 1, 9, 3152, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6707, 1, 5, 3153, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (6708, 1, 14, 3154, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (6709, 3, 7, 3154, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (6710, 2, 6, 3154, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (6711, 1, 2, 3154, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (6712, 8, 5, 3154, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (6713, 6, 1, 3154, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (6714, 5, 10, 3154, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (6715, 7, 1, 3155, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (6716, 1, 6, 3155, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (6717, 4, 7, 3155, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (6718, 3, 2, 3155, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (6719, 4, 12, 3155, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (6720, 8, 10, 3155, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (6721, 4, 14, 3155, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (6722, 8, 4, 3155, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (6723, 6, 13, 3155, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (6724, 9, 5, 3155, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (6725, 3, 3, 3155, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (6726, 2, 11, 3155, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (6727, 8, 2, 3156, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (6728, 8, 14, 3156, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (6729, 10, 11, 3156, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (6730, 1, 4, 3156, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (6731, 10, 13, 3156, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (6732, 1, 6, 3156, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (6733, 8, 12, 3156, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (6734, 5, 7, 3156, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (6735, 6, 5, 3156, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (6736, 10, 10, 3156, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (6737, 9, 3, 3156, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (6738, 10, 1, 3156, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (6739, 1, 9, 3156, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6740, 1, 8, 3156, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6741, 9, 2, 3157, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (6742, 2, 5, 3157, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (6743, 1, 9, 3157, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6744, 1, 8, 3157, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6745, 7, 12, 3158, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (6746, 3, 13, 3158, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (6747, 1, 8, 3158, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6748, 4, 2, 3159, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (6749, 4, 4, 3159, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (6750, 7, 7, 3159, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (6751, 3, 12, 3159, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (6752, 5, 11, 3159, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (6753, 5, 10, 3159, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (6754, 8, 14, 3159, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (6755, 10, 6, 3159, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (6756, 4, 3, 3159, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (6757, 6, 5, 3159, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (6758, 1, 8, 3159, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6759, 1, 9, 3159, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6760, 5, 5, 3160, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (6761, 1, 9, 3160, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6762, 9, 4, 3161, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (6763, 7, 7, 3161, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (6764, 4, 12, 3161, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (6765, 1, 9, 3161, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6766, 3, 1, 3162, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (6767, 1, 5, 3162, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (6768, 9, 4, 3162, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (6769, 7, 10, 3162, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (6770, 7, 6, 3162, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (6771, 1, 7, 3162, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (6772, 1, 13, 3162, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (6773, 2, 12, 3162, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (6774, 1, 8, 3162, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6775, 1, 9, 3162, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6776, 8, 2, 3163, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (6777, 5, 6, 3163, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (6778, 8, 11, 3163, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (6779, 3, 3, 3163, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (6780, 9, 12, 3163, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (6781, 1, 14, 3163, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (6782, 7, 1, 3163, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (6783, 5, 10, 3163, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (6784, 3, 4, 3163, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (6785, 5, 13, 3163, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (6786, 1, 7, 3163, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (6787, 1, 8, 3163, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6788, 3, 3, 3164, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (6789, 6, 1, 3164, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (6790, 8, 12, 3164, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (6791, 3, 14, 3164, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (6792, 4, 5, 3164, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (6793, 5, 7, 3164, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (6794, 10, 10, 3164, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (6795, 1, 9, 3164, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6796, 6, 10, 3165, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (6797, 6, 5, 3165, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (6798, 7, 1, 3165, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (6799, 6, 7, 3165, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (6800, 1, 12, 3166, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (6801, 4, 13, 3166, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (6802, 4, 4, 3166, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (6803, 3, 11, 3166, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (6804, 8, 1, 3166, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (6805, 4, 5, 3166, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (6806, 9, 6, 3166, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (6807, 7, 7, 3166, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (6808, 5, 2, 3166, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (6809, 3, 3, 3166, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (6810, 10, 14, 3166, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (6811, 10, 10, 3166, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (6812, 1, 8, 3167, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6813, 1, 9, 3167, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6814, 6, 3, 3168, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (6815, 1, 9, 3168, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6816, 3, 11, 3169, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (6817, 10, 13, 3169, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (6818, 9, 1, 3169, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (6819, 9, 10, 3169, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (6820, 9, 14, 3169, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (6821, 10, 7, 3169, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (6822, 3, 12, 3169, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (6823, 2, 2, 3169, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (6824, 2, 6, 3169, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (6825, 1, 5, 3169, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (6826, 6, 3, 3169, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (6827, 10, 4, 3169, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (6828, 1, 9, 3169, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6829, 1, 8, 3169, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6830, 9, 13, 3170, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (6831, 3, 12, 3170, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (6832, 8, 3, 3170, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (6833, 2, 1, 3170, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (6834, 8, 11, 3170, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (6835, 8, 4, 3170, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (6836, 10, 5, 3170, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (6837, 7, 7, 3170, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (6838, 9, 14, 3170, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (6839, 4, 6, 3171, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (6840, 10, 13, 3171, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (6841, 2, 7, 3171, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (6842, 2, 4, 3172, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (6843, 2, 2, 3172, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (6844, 4, 12, 3172, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (6845, 6, 10, 3173, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (6846, 7, 2, 3173, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (6847, 4, 14, 3173, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (6848, 5, 5, 3173, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (6849, 9, 3, 3173, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (6850, 1, 1, 3173, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (6851, 7, 7, 3173, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (6852, 7, 6, 3173, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (6853, 9, 4, 3173, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (6854, 6, 12, 3173, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (6855, 3, 13, 3173, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (6856, 8, 11, 3173, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (6857, 1, 9, 3173, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6858, 6, 5, 3174, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (6859, 4, 4, 3174, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (6860, 9, 13, 3174, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (6861, 9, 7, 3174, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (6862, 2, 3, 3174, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (6863, 9, 11, 3174, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (6864, 1, 10, 3174, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (6865, 3, 2, 3174, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (6866, 10, 6, 3174, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (6867, 5, 14, 3174, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (6868, 1, 9, 3174, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6869, 5, 12, 3175, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (6870, 6, 6, 3175, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (6871, 7, 13, 3175, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (6872, 5, 11, 3176, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (6873, 9, 7, 3176, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (6874, 2, 10, 3176, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (6875, 2, 12, 3176, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (6876, 4, 14, 3176, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (6877, 7, 6, 3176, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (6878, 4, 3, 3176, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (6879, 7, 2, 3176, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (6880, 4, 4, 3176, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (6881, 10, 5, 3176, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (6882, 1, 1, 3176, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (6883, 3, 13, 3176, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (6884, 1, 9, 3176, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6885, 1, 8, 3176, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6886, 1, 14, 3177, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (6887, 4, 13, 3177, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (6888, 9, 6, 3177, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (6889, 8, 10, 3177, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (6890, 2, 2, 3177, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (6891, 1, 11, 3177, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (6892, 10, 12, 3177, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (6893, 1, 9, 3177, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6894, 9, 3, 3178, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (6895, 9, 6, 3178, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (6896, 7, 12, 3178, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (6897, 1, 9, 3178, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6898, 1, 8, 3178, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6899, 8, 5, 3179, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (6900, 1, 2, 3179, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (6901, 10, 10, 3180, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (6902, 3, 3, 3180, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (6903, 9, 7, 3180, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (6904, 5, 12, 3180, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (6905, 4, 1, 3180, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (6906, 2, 4, 3180, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (6907, 3, 13, 3180, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (6908, 1, 14, 3180, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (6909, 3, 5, 3180, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (6910, 4, 6, 3180, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (6911, 1, 2, 3180, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (6912, 9, 11, 3180, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (6913, 1, 9, 3180, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6914, 1, 8, 3180, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6915, 6, 2, 3181, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (6916, 8, 6, 3181, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (6917, 2, 4, 3181, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (6918, 6, 5, 3181, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (6919, 6, 11, 3181, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (6920, 2, 14, 3181, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (6921, 3, 12, 3181, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (6922, 1, 8, 3181, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6923, 1, 9, 3181, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6924, 7, 3, 3182, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (6925, 5, 13, 3182, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (6926, 8, 14, 3182, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (6927, 7, 1, 3182, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (6928, 8, 6, 3182, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (6929, 7, 7, 3182, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (6930, 1, 11, 3182, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (6931, 2, 12, 3182, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (6932, 8, 4, 3182, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (6933, 4, 10, 3182, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (6934, 3, 5, 3182, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (6935, 1, 2, 3182, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (6936, 1, 8, 3182, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6937, 1, 9, 3182, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6938, 8, 3, 3183, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (6939, 4, 2, 3183, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (6940, 2, 13, 3183, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (6941, 5, 4, 3183, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (6942, 5, 10, 3183, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (6943, 8, 7, 3183, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (6944, 1, 14, 3183, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (6945, 7, 12, 3183, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (6946, 1, 1, 3183, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (6947, 8, 5, 3183, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (6948, 1, 8, 3183, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6949, 10, 12, 3184, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (6950, 6, 3, 3184, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (6951, 1, 4, 3184, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (6952, 10, 2, 3184, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (6953, 7, 10, 3184, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (6954, 9, 5, 3184, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (6955, 3, 13, 3184, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (6956, 1, 8, 3184, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6957, 1, 9, 3184, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6958, 6, 7, 3185, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (6959, 10, 13, 3185, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (6960, 4, 10, 3185, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (6961, 3, 1, 3185, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (6962, 4, 11, 3185, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (6963, 6, 3, 3185, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (6964, 8, 4, 3185, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (6965, 9, 5, 3185, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (6966, 4, 14, 3185, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (6967, 8, 12, 3185, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (6968, 6, 2, 3185, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (6969, 3, 6, 3186, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (6970, 5, 10, 3186, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (6971, 4, 5, 3186, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (6972, 7, 11, 3186, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (6973, 4, 4, 3186, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (6974, 9, 13, 3186, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (6975, 8, 14, 3186, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (6976, 3, 7, 3186, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (6977, 5, 2, 3186, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (6978, 1, 8, 3186, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (6979, 5, 12, 3187, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (6980, 5, 11, 3187, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (6981, 1, 6, 3187, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (6982, 10, 4, 3187, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (6983, 5, 13, 3187, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (6984, 1, 9, 3187, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (6985, 3, 4, 3188, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (6986, 7, 12, 3188, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (6987, 2, 13, 3188, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (6988, 7, 3, 3188, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (6989, 2, 11, 3188, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (6990, 4, 7, 3188, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (6991, 2, 10, 3188, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (6992, 5, 1, 3188, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (6993, 8, 5, 3188, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (6994, 6, 6, 3188, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (6995, 9, 1, 3189, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (6996, 4, 14, 3189, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (6997, 9, 13, 3189, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (6998, 2, 11, 3189, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (6999, 8, 3, 3189, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (7000, 3, 2, 3190, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (7001, 4, 7, 3190, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (7002, 1, 8, 3190, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7003, 1, 9, 3190, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7004, 9, 1, 3191, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (7005, 9, 6, 3191, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (7006, 1, 12, 3191, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (7007, 1, 14, 3191, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (7008, 2, 5, 3191, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (7009, 3, 4, 3191, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (7010, 5, 7, 3191, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (7011, 1, 8, 3191, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7012, 1, 9, 3191, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7013, 4, 14, 3192, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (7014, 4, 3, 3192, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (7015, 1, 8, 3192, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7016, 1, 9, 3192, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7017, 5, 14, 3193, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (7018, 5, 5, 3193, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (7019, 1, 8, 3193, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7020, 1, 9, 3193, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7021, 2, 4, 3195, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (7022, 1, 11, 3195, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (7023, 6, 10, 3195, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (7024, 3, 14, 3195, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (7025, 2, 1, 3195, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (7026, 8, 3, 3195, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (7027, 5, 2, 3195, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (7028, 7, 7, 3195, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (7029, 7, 5, 3195, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (7030, 3, 12, 3195, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (7031, 2, 13, 3195, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (7032, 1, 8, 3195, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7033, 1, 9, 3195, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7034, 3, 6, 3196, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (7035, 3, 4, 3196, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (7036, 7, 10, 3196, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (7037, 7, 7, 3196, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (7038, 8, 2, 3196, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (7039, 5, 12, 3196, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (7040, 1, 8, 3196, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7041, 1, 9, 3196, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7042, 10, 5, 3197, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (7043, 7, 4, 3197, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (7044, 3, 6, 3197, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (7045, 2, 11, 3197, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (7046, 8, 7, 3197, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (7047, 8, 1, 3197, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (7048, 4, 3, 3197, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (7049, 10, 12, 3197, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (7050, 1, 8, 3197, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7051, 7, 2, 3198, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (7052, 1, 9, 3198, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7053, 1, 8, 3198, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7054, 10, 4, 3199, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (7055, 4, 12, 3199, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (7056, 2, 10, 3199, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (7057, 6, 5, 3199, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (7058, 1, 2, 3199, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (7059, 10, 3, 3199, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (7060, 1, 7, 3199, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (7061, 9, 6, 3199, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (7062, 4, 13, 3199, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (7063, 6, 11, 3199, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (7064, 3, 1, 3199, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (7065, 8, 14, 3199, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (7066, 2, 4, 3200, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (7067, 2, 3, 3200, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (7068, 7, 10, 3200, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (7069, 2, 7, 3200, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (7070, 7, 2, 3200, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (7071, 1, 9, 3200, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7072, 8, 2, 3201, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (7073, 2, 13, 3201, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (7074, 5, 7, 3201, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (7075, 7, 14, 3201, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (7076, 7, 3, 3202, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (7077, 9, 13, 3202, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (7078, 8, 6, 3202, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (7079, 1, 10, 3202, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (7080, 4, 5, 3202, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (7081, 10, 14, 3202, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (7082, 8, 1, 3202, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (7083, 6, 4, 3202, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (7084, 3, 7, 3202, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (7085, 2, 12, 3202, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (7086, 9, 11, 3202, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (7087, 6, 2, 3202, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (7088, 1, 9, 3202, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7089, 7, 1, 3203, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (7090, 2, 2, 3203, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (7091, 6, 5, 3203, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (7092, 3, 13, 3203, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (7093, 5, 10, 3203, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (7094, 3, 7, 3203, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (7095, 5, 14, 3203, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (7096, 10, 6, 3203, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (7097, 9, 12, 3203, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (7098, 7, 3, 3203, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (7099, 1, 9, 3203, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7100, 1, 8, 3203, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7101, 3, 13, 3204, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (7102, 2, 3, 3204, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (7103, 4, 10, 3204, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (7104, 3, 4, 3204, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (7105, 6, 14, 3204, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (7106, 4, 7, 3204, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (7107, 1, 11, 3204, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (7108, 1, 2, 3204, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (7109, 6, 1, 3204, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (7110, 3, 5, 3204, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (7111, 1, 8, 3204, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7112, 1, 9, 3204, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7113, 7, 12, 3205, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (7114, 1, 8, 3205, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7115, 1, 9, 3205, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7116, 5, 1, 3206, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (7117, 8, 3, 3206, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (7118, 6, 5, 3206, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (7119, 3, 6, 3206, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (7120, 4, 11, 3206, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (7121, 4, 12, 3206, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (7122, 9, 14, 3206, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (7123, 8, 7, 3206, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (7124, 10, 4, 3206, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (7125, 2, 13, 3206, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (7126, 1, 8, 3206, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7127, 1, 9, 3206, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7128, 6, 4, 3207, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (7129, 7, 14, 3207, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (7130, 4, 12, 3207, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (7131, 8, 3, 3207, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (7132, 6, 1, 3207, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (7133, 5, 10, 3207, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (7134, 4, 13, 3207, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (7135, 6, 6, 3207, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (7136, 8, 5, 3207, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (7137, 5, 7, 3207, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (7138, 3, 2, 3207, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (7139, 1, 9, 3207, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7140, 1, 8, 3207, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7141, 2, 1, 3209, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (7142, 2, 12, 3209, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (7143, 9, 7, 3210, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (7144, 5, 3, 3210, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (7145, 8, 5, 3210, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (7146, 1, 8, 3210, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7147, 10, 14, 3211, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (7148, 6, 13, 3211, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (7149, 10, 1, 3211, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (7150, 4, 2, 3211, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (7151, 2, 6, 3211, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (7152, 8, 7, 3211, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (7153, 8, 4, 3211, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (7154, 4, 12, 3211, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (7155, 1, 8, 3211, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7156, 4, 4, 3212, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (7157, 6, 5, 3212, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (7158, 9, 1, 3212, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (7159, 6, 12, 3212, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (7160, 8, 7, 3212, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (7161, 9, 11, 3212, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (7162, 5, 2, 3212, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (7163, 10, 10, 3212, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (7164, 1, 14, 3212, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (7165, 4, 3, 3212, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (7166, 1, 9, 3212, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7167, 1, 8, 3213, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7168, 4, 5, 3214, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (7169, 10, 7, 3214, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (7170, 1, 4, 3214, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (7171, 7, 1, 3214, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (7172, 5, 12, 3214, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (7173, 1, 8, 3214, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7174, 4, 7, 3215, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (7175, 1, 8, 3215, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7176, 1, 9, 3215, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7177, 4, 4, 3216, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (7178, 5, 6, 3216, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (7179, 8, 7, 3216, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (7180, 8, 12, 3216, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (7181, 9, 2, 3216, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (7182, 6, 10, 3216, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (7183, 5, 3, 3216, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (7184, 5, 14, 3216, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (7185, 6, 5, 3216, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (7186, 1, 1, 3216, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (7187, 7, 13, 3216, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (7188, 1, 8, 3216, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7189, 10, 5, 3217, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (7190, 3, 13, 3217, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (7191, 3, 12, 3217, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (7192, 5, 7, 3217, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (7193, 7, 1, 3217, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (7194, 3, 4, 3217, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (7195, 7, 11, 3217, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (7196, 8, 14, 3217, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (7197, 7, 10, 3217, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (7198, 5, 2, 3217, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (7199, 7, 6, 3217, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (7200, 6, 3, 3217, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (7201, 1, 8, 3217, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7202, 1, 9, 3217, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7203, 3, 4, 3218, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (7204, 7, 12, 3218, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (7205, 1, 6, 3218, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (7206, 7, 13, 3218, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (7207, 3, 3, 3218, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (7208, 2, 14, 3218, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (7209, 4, 2, 3218, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (7210, 8, 1, 3218, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (7211, 5, 11, 3218, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (7212, 2, 7, 3218, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (7213, 1, 9, 3218, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7214, 1, 8, 3218, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7215, 2, 10, 3219, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (7216, 10, 3, 3219, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (7217, 1, 9, 3219, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7218, 3, 7, 3220, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (7219, 6, 3, 3220, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (7220, 3, 11, 3220, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (7221, 6, 6, 3220, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (7222, 1, 9, 3220, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7223, 4, 13, 3221, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (7224, 4, 7, 3221, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (7225, 5, 4, 3221, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (7226, 6, 10, 3221, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (7227, 6, 2, 3221, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (7228, 8, 14, 3221, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (7229, 4, 3, 3221, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (7230, 10, 11, 3221, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (7231, 10, 6, 3221, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (7232, 1, 12, 3221, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (7233, 1, 5, 3221, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (7234, 9, 1, 3221, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (7235, 1, 9, 3221, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7236, 1, 8, 3221, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7237, 5, 1, 3222, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (7238, 7, 12, 3222, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (7239, 9, 2, 3222, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (7240, 1, 9, 3222, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7241, 2, 4, 3223, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (7242, 1, 8, 3223, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7243, 1, 9, 3223, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7244, 6, 6, 3224, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (7245, 8, 14, 3224, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (7246, 2, 11, 3224, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (7247, 10, 4, 3224, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (7248, 4, 7, 3224, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (7249, 7, 12, 3224, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (7250, 8, 2, 3224, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (7251, 7, 13, 3224, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (7252, 7, 10, 3224, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (7253, 7, 3, 3224, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (7254, 7, 5, 3224, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (7255, 7, 1, 3224, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (7256, 1, 9, 3224, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7257, 10, 10, 3225, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (7258, 9, 3, 3225, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (7259, 2, 6, 3225, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (7260, 1, 9, 3225, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7261, 9, 7, 3226, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (7262, 1, 14, 3226, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (7263, 2, 2, 3226, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (7264, 6, 12, 3226, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (7265, 5, 3, 3226, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (7266, 10, 6, 3226, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (7267, 1, 1, 3226, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (7268, 2, 13, 3226, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (7269, 5, 14, 3227, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (7270, 5, 10, 3227, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (7271, 1, 8, 3227, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7272, 1, 9, 3227, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7273, 5, 11, 3228, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (7274, 3, 12, 3228, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (7275, 5, 10, 3228, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (7276, 3, 14, 3228, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (7277, 4, 4, 3228, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (7278, 9, 1, 3228, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (7279, 10, 2, 3228, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (7280, 1, 9, 3228, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7281, 1, 6, 3229, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (7282, 5, 10, 3229, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (7283, 5, 11, 3229, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (7284, 3, 2, 3229, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (7285, 7, 5, 3229, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (7286, 6, 1, 3229, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (7287, 1, 9, 3229, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7288, 1, 8, 3229, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7289, 8, 12, 3230, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (7290, 9, 1, 3230, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (7291, 10, 3, 3230, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (7292, 7, 6, 3230, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (7293, 1, 10, 3230, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (7294, 1, 13, 3230, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (7295, 2, 2, 3230, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (7296, 5, 4, 3230, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (7297, 4, 11, 3230, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (7298, 7, 5, 3230, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (7299, 8, 14, 3230, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (7300, 8, 7, 3230, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (7301, 1, 9, 3230, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7302, 6, 11, 3231, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (7303, 1, 1, 3231, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (7304, 5, 2, 3231, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (7305, 10, 12, 3231, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (7306, 2, 7, 3231, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (7307, 10, 3, 3231, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (7308, 4, 5, 3231, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (7309, 5, 10, 3231, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (7310, 6, 4, 3231, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (7311, 9, 14, 3231, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (7312, 3, 13, 3231, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (7313, 10, 6, 3231, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (7314, 6, 4, 3232, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (7315, 2, 10, 3232, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (7316, 9, 11, 3232, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (7317, 8, 12, 3232, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (7318, 6, 2, 3232, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (7319, 3, 3, 3232, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (7320, 4, 14, 3232, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (7321, 3, 5, 3232, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (7322, 10, 6, 3232, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (7323, 10, 1, 3232, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (7324, 10, 13, 3232, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (7325, 4, 7, 3232, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (7326, 1, 9, 3232, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7327, 1, 8, 3232, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7328, 6, 13, 3233, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (7329, 3, 10, 3233, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (7330, 8, 6, 3233, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (7331, 10, 5, 3233, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (7332, 8, 1, 3233, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (7333, 7, 14, 3233, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (7334, 8, 3, 3234, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (7335, 6, 6, 3234, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (7336, 5, 1, 3234, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (7337, 3, 2, 3234, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (7338, 7, 7, 3234, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (7339, 3, 10, 3234, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (7340, 1, 11, 3234, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (7341, 3, 13, 3234, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (7342, 5, 4, 3234, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (7343, 1, 9, 3234, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7344, 5, 7, 3235, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (7345, 8, 10, 3235, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (7346, 3, 2, 3235, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (7347, 10, 13, 3235, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (7348, 2, 14, 3235, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (7349, 1, 9, 3235, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7350, 6, 13, 3236, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (7351, 8, 1, 3236, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (7352, 10, 14, 3236, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (7353, 4, 10, 3236, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (7354, 7, 12, 3236, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (7355, 4, 6, 3236, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (7356, 10, 5, 3236, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (7357, 4, 4, 3236, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (7358, 10, 7, 3236, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (7359, 4, 11, 3236, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (7360, 1, 8, 3236, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7361, 2, 5, 3237, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (7362, 1, 4, 3237, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (7363, 4, 2, 3237, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (7364, 6, 1, 3237, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (7365, 5, 7, 3237, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (7366, 8, 10, 3237, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (7367, 4, 14, 3237, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (7368, 7, 13, 3237, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (7369, 8, 6, 3237, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (7370, 5, 12, 3237, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (7371, 3, 11, 3237, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (7372, 2, 3, 3237, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (7373, 1, 2, 3238, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (7374, 8, 1, 3238, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (7375, 10, 5, 3238, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (7376, 8, 13, 3238, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (7377, 2, 3, 3238, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (7378, 9, 4, 3238, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (7379, 1, 12, 3238, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (7380, 1, 10, 3238, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (7381, 3, 7, 3238, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (7382, 1, 8, 3238, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7383, 1, 2, 3239, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (7384, 4, 3, 3239, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (7385, 8, 6, 3239, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (7386, 7, 12, 3239, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (7387, 9, 10, 3239, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (7388, 6, 14, 3239, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (7389, 1, 9, 3239, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7390, 1, 8, 3239, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7391, 8, 3, 3240, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (7392, 5, 13, 3240, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (7393, 7, 4, 3240, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (7394, 8, 6, 3240, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (7395, 8, 10, 3240, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (7396, 6, 5, 3240, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (7397, 4, 11, 3240, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (7398, 1, 9, 3240, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7399, 1, 8, 3240, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7400, 2, 5, 3241, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (7401, 6, 10, 3241, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (7402, 6, 13, 3241, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (7403, 5, 3, 3241, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (7404, 2, 6, 3241, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (7405, 2, 11, 3241, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (7406, 4, 12, 3241, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (7407, 1, 9, 3241, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7408, 4, 2, 3242, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (7409, 1, 1, 3242, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (7410, 7, 12, 3242, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (7411, 9, 10, 3242, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (7412, 1, 6, 3242, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (7413, 3, 4, 3242, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (7414, 2, 11, 3242, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (7415, 6, 13, 3242, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (7416, 10, 5, 3242, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (7417, 6, 14, 3242, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (7418, 2, 7, 3242, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (7419, 8, 3, 3242, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (7420, 1, 2, 3243, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (7421, 1, 8, 3243, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7422, 2, 4, 3244, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (7423, 1, 3, 3244, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (7424, 10, 14, 3244, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (7425, 4, 12, 3244, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (7426, 2, 7, 3244, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (7427, 3, 10, 3244, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (7428, 8, 1, 3244, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (7429, 8, 13, 3244, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (7430, 1, 9, 3244, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7431, 1, 8, 3244, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7432, 3, 10, 3245, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (7433, 10, 5, 3245, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (7434, 8, 1, 3245, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (7435, 6, 2, 3245, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (7436, 1, 7, 3245, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (7437, 3, 6, 3245, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (7438, 5, 14, 3245, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (7439, 7, 13, 3245, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (7440, 5, 11, 3245, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (7441, 3, 12, 3245, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (7442, 9, 3, 3245, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (7443, 6, 2, 3246, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (7444, 3, 3, 3246, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (7445, 8, 13, 3246, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (7446, 7, 11, 3246, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (7447, 3, 4, 3246, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (7448, 1, 1, 3246, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (7449, 8, 10, 3246, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (7450, 6, 12, 3246, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (7451, 9, 7, 3246, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (7452, 1, 8, 3246, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7453, 8, 2, 3247, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (7454, 6, 1, 3247, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (7455, 7, 11, 3247, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (7456, 3, 14, 3247, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (7457, 6, 5, 3247, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (7458, 10, 10, 3247, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (7459, 7, 4, 3247, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (7460, 2, 3, 3247, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (7461, 4, 13, 3247, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (7462, 10, 6, 3247, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (7463, 1, 7, 3247, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (7464, 5, 12, 3247, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (7465, 4, 5, 3248, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (7466, 4, 2, 3248, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (7467, 8, 7, 3248, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (7468, 1, 8, 3248, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7469, 4, 4, 3249, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (7470, 1, 8, 3249, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7471, 3, 12, 3250, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (7472, 9, 3, 3250, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (7473, 6, 13, 3250, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (7474, 8, 2, 3250, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (7475, 1, 9, 3250, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7476, 1, 8, 3250, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7477, 6, 10, 3251, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (7478, 5, 3, 3251, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (7479, 1, 5, 3251, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (7480, 2, 12, 3251, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (7481, 5, 4, 3251, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (7482, 7, 13, 3251, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (7483, 4, 6, 3251, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (7484, 8, 7, 3251, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (7485, 10, 14, 3251, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (7486, 2, 11, 3251, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (7487, 4, 1, 3251, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (7488, 4, 2, 3251, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (7489, 1, 8, 3251, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7490, 1, 9, 3251, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7491, 6, 4, 3252, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (7492, 10, 2, 3252, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (7493, 1, 9, 3252, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7494, 6, 4, 3253, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (7495, 3, 10, 3253, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (7496, 6, 7, 3253, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (7497, 7, 5, 3253, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (7498, 4, 12, 3253, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (7499, 5, 11, 3253, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (7500, 3, 3, 3253, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (7501, 8, 2, 3253, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (7502, 6, 1, 3253, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (7503, 1, 9, 3253, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7504, 2, 7, 3254, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (7505, 1, 11, 3254, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (7506, 3, 10, 3254, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (7507, 5, 3, 3254, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (7508, 8, 2, 3254, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (7509, 7, 12, 3254, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (7510, 1, 1, 3254, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (7511, 7, 6, 3254, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (7512, 4, 4, 3254, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (7513, 3, 5, 3254, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (7514, 3, 13, 3254, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (7515, 3, 14, 3254, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (7516, 1, 8, 3254, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7517, 1, 9, 3254, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7518, 6, 2, 3255, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (7519, 7, 13, 3255, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (7520, 10, 14, 3255, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (7521, 1, 7, 3255, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (7522, 3, 3, 3255, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (7523, 3, 12, 3255, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (7524, 6, 1, 3255, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (7525, 6, 11, 3255, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (7526, 1, 4, 3255, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (7527, 1, 5, 3255, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (7528, 1, 6, 3255, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (7529, 4, 1, 3256, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (7530, 9, 4, 3256, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (7531, 7, 3, 3256, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (7532, 10, 2, 3256, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (7533, 9, 6, 3256, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (7534, 3, 7, 3256, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (7535, 3, 11, 3256, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (7536, 1, 13, 3256, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (7537, 5, 10, 3256, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (7538, 6, 5, 3256, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (7539, 9, 14, 3256, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (7540, 5, 12, 3256, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (7541, 1, 9, 3256, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7542, 5, 7, 3257, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (7543, 2, 12, 3257, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (7544, 5, 4, 3257, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (7545, 1, 8, 3257, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7546, 1, 9, 3257, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7547, 8, 11, 3258, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (7548, 1, 13, 3258, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (7549, 10, 6, 3258, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (7550, 10, 10, 3258, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (7551, 10, 14, 3258, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (7552, 1, 2, 3258, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (7553, 3, 3, 3258, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (7554, 8, 5, 3258, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (7555, 5, 1, 3258, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (7556, 1, 12, 3258, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (7557, 5, 7, 3258, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (7558, 1, 9, 3258, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7559, 8, 14, 3260, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (7560, 10, 2, 3260, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (7561, 8, 4, 3260, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (7562, 9, 7, 3260, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (7563, 5, 11, 3260, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (7564, 1, 8, 3260, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7565, 6, 14, 3261, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (7566, 2, 7, 3261, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (7567, 3, 6, 3261, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (7568, 5, 13, 3261, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (7569, 7, 2, 3262, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (7570, 10, 10, 3262, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (7571, 5, 5, 3262, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (7572, 5, 3, 3262, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (7573, 7, 4, 3262, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (7574, 6, 13, 3262, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (7575, 7, 6, 3262, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (7576, 9, 7, 3262, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (7577, 1, 8, 3262, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7578, 5, 5, 3263, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (7579, 1, 7, 3263, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (7580, 1, 3, 3263, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (7581, 10, 6, 3263, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (7582, 7, 10, 3263, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (7583, 6, 1, 3263, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (7584, 2, 11, 3263, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (7585, 10, 4, 3263, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (7586, 2, 12, 3263, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (7587, 1, 6, 3264, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (7588, 2, 4, 3264, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (7589, 6, 3, 3264, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (7590, 1, 10, 3264, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (7591, 7, 2, 3264, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (7592, 10, 11, 3264, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (7593, 7, 14, 3264, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (7594, 2, 12, 3264, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (7595, 7, 1, 3264, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (7596, 6, 5, 3264, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (7597, 6, 13, 3264, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (7598, 10, 7, 3264, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (7599, 2, 6, 3265, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (7600, 8, 1, 3265, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (7601, 7, 13, 3265, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (7602, 9, 10, 3265, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (7603, 4, 3, 3265, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (7604, 9, 12, 3265, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (7605, 8, 14, 3265, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (7606, 5, 2, 3265, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (7607, 2, 11, 3265, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (7608, 9, 7, 3265, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (7609, 1, 4, 3265, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (7610, 1, 8, 3265, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7611, 5, 14, 3266, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (7612, 8, 11, 3266, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (7613, 4, 2, 3266, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (7614, 4, 4, 3266, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (7615, 5, 3, 3266, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (7616, 6, 10, 3266, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (7617, 1, 12, 3266, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (7618, 10, 6, 3266, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (7619, 2, 5, 3266, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (7620, 1, 1, 3266, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (7621, 1, 13, 3266, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (7622, 1, 8, 3266, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7623, 8, 5, 3267, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (7624, 2, 10, 3267, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (7625, 8, 4, 3267, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (7626, 6, 1, 3267, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (7627, 9, 6, 3267, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (7628, 3, 7, 3267, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (7629, 7, 2, 3267, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (7630, 1, 9, 3267, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7631, 1, 8, 3267, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7632, 10, 10, 3268, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (7633, 10, 4, 3268, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (7634, 1, 9, 3268, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7635, 2, 13, 3269, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (7636, 10, 10, 3269, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (7637, 10, 2, 3269, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (7638, 1, 1, 3269, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (7639, 1, 5, 3269, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (7640, 10, 4, 3269, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (7641, 2, 7, 3269, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (7642, 5, 12, 3269, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (7643, 2, 3, 3269, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (7644, 9, 14, 3269, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (7645, 6, 6, 3269, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (7646, 5, 11, 3269, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (7647, 1, 9, 3269, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7648, 4, 1, 3270, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (7649, 5, 14, 3270, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (7650, 3, 7, 3270, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (7651, 7, 3, 3270, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (7652, 8, 4, 3270, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (7653, 6, 12, 3270, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (7654, 8, 11, 3270, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (7655, 1, 8, 3270, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7656, 1, 9, 3270, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7657, 9, 2, 3271, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (7658, 3, 13, 3271, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (7659, 6, 4, 3271, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (7660, 9, 14, 3271, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (7661, 3, 1, 3271, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (7662, 7, 3, 3271, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (7663, 1, 8, 3271, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7664, 1, 9, 3271, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7665, 9, 5, 3272, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (7666, 8, 2, 3272, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (7667, 1, 4, 3272, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (7668, 1, 10, 3272, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (7669, 5, 3, 3272, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (7670, 3, 1, 3272, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (7671, 9, 11, 3272, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (7672, 9, 13, 3272, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (7673, 7, 6, 3272, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (7674, 4, 7, 3272, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (7675, 1, 8, 3273, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7676, 1, 9, 3273, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7677, 1, 8, 3274, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7678, 8, 2, 3275, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (7679, 1, 13, 3275, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (7680, 1, 14, 3275, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (7681, 1, 11, 3275, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (7682, 1, 8, 3275, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7683, 10, 12, 3276, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (7684, 7, 4, 3276, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (7685, 10, 14, 3276, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (7686, 9, 1, 3276, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (7687, 6, 3, 3276, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (7688, 6, 7, 3276, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (7689, 3, 5, 3276, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (7690, 7, 13, 3276, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (7691, 8, 6, 3276, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (7692, 3, 11, 3276, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (7693, 3, 2, 3276, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (7694, 1, 9, 3276, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7695, 1, 8, 3276, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7696, 5, 12, 3277, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (7697, 8, 1, 3277, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (7698, 10, 13, 3277, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (7699, 8, 6, 3278, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (7700, 3, 10, 3278, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (7701, 1, 5, 3278, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (7702, 2, 14, 3278, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (7703, 1, 1, 3278, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (7704, 10, 11, 3278, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (7705, 5, 2, 3278, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (7706, 8, 12, 3278, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (7707, 9, 4, 3278, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (7708, 1, 7, 3278, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (7709, 8, 3, 3278, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (7710, 8, 13, 3278, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (7711, 1, 8, 3278, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7712, 5, 2, 3279, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (7713, 9, 5, 3279, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (7714, 4, 4, 3279, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (7715, 9, 7, 3279, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (7716, 5, 6, 3280, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (7717, 5, 7, 3280, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (7718, 6, 2, 3280, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (7719, 7, 1, 3280, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (7720, 5, 13, 3280, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (7721, 3, 4, 3280, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (7722, 10, 5, 3280, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (7723, 5, 12, 3280, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (7724, 5, 3, 3280, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (7725, 1, 10, 3280, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (7726, 4, 11, 3280, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (7727, 9, 14, 3280, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (7728, 1, 8, 3280, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7729, 1, 9, 3280, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7730, 8, 12, 3281, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (7731, 10, 11, 3281, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (7732, 7, 3, 3281, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (7733, 9, 2, 3281, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (7734, 3, 7, 3281, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (7735, 1, 14, 3281, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (7736, 7, 6, 3281, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (7737, 1, 9, 3281, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7738, 6, 14, 3282, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (7739, 1, 9, 3282, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7740, 10, 6, 3283, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (7741, 4, 12, 3283, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (7742, 3, 13, 3283, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (7743, 5, 2, 3283, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (7744, 1, 9, 3283, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7745, 1, 8, 3283, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7746, 7, 3, 3284, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (7747, 1, 9, 3284, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7748, 7, 1, 3285, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (7749, 6, 6, 3286, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (7750, 10, 14, 3286, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (7751, 7, 11, 3286, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (7752, 2, 5, 3286, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (7753, 6, 13, 3286, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (7754, 2, 7, 3286, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (7755, 3, 3, 3286, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (7756, 9, 1, 3286, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (7757, 2, 4, 3286, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (7758, 1, 8, 3286, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7759, 2, 14, 3287, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (7760, 4, 10, 3287, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (7761, 5, 5, 3287, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (7762, 8, 3, 3287, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (7763, 9, 7, 3287, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (7764, 1, 8, 3287, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7765, 6, 10, 3288, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (7766, 3, 2, 3288, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (7767, 10, 12, 3288, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (7768, 3, 4, 3288, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (7769, 1, 14, 3288, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (7770, 9, 5, 3288, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (7771, 9, 6, 3288, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (7772, 7, 1, 3288, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (7773, 8, 7, 3288, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (7774, 1, 9, 3288, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7775, 10, 11, 3289, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (7776, 2, 7, 3289, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (7777, 8, 3, 3289, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (7778, 7, 1, 3289, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (7779, 2, 14, 3289, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (7780, 3, 10, 3289, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (7781, 1, 2, 3289, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (7782, 6, 6, 3289, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (7783, 6, 5, 3289, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (7784, 5, 7, 3290, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (7785, 9, 14, 3290, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (7786, 10, 3, 3290, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (7787, 1, 1, 3290, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (7788, 5, 5, 3290, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (7789, 2, 6, 3290, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (7790, 1, 11, 3290, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (7791, 7, 12, 3290, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (7792, 3, 2, 3290, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (7793, 9, 4, 3290, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (7794, 5, 13, 3290, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (7795, 1, 8, 3290, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7796, 1, 9, 3290, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7797, 6, 11, 3291, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (7798, 6, 3, 3291, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (7799, 2, 7, 3291, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (7800, 3, 4, 3291, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (7801, 2, 1, 3291, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (7802, 4, 13, 3291, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (7803, 5, 10, 3291, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (7804, 3, 2, 3291, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (7805, 9, 12, 3291, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (7806, 1, 14, 3291, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (7807, 6, 5, 3291, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (7808, 8, 6, 3291, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (7809, 1, 8, 3291, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7810, 1, 9, 3291, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7811, 5, 10, 3292, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (7812, 4, 1, 3292, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (7813, 6, 13, 3292, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (7814, 9, 4, 3292, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (7815, 6, 6, 3292, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (7816, 6, 7, 3292, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (7817, 6, 14, 3292, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (7818, 1, 9, 3292, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7819, 1, 8, 3292, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7820, 3, 7, 3293, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (7821, 1, 3, 3293, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (7822, 5, 11, 3293, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (7823, 9, 2, 3293, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (7824, 2, 1, 3293, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (7825, 7, 10, 3293, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (7826, 1, 13, 3293, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (7827, 5, 6, 3293, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (7828, 1, 5, 3293, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (7829, 3, 4, 3293, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (7830, 3, 14, 3293, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (7831, 1, 12, 3293, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (7832, 1, 8, 3293, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7833, 1, 9, 3293, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7834, 5, 11, 3294, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (7835, 6, 10, 3294, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (7836, 9, 14, 3294, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (7837, 9, 12, 3294, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (7838, 1, 13, 3294, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (7839, 8, 7, 3294, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (7840, 1, 9, 3294, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7841, 1, 5, 3295, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (7842, 3, 4, 3295, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (7843, 1, 9, 3295, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7844, 1, 8, 3295, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7845, 1, 9, 3296, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7846, 9, 5, 3297, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (7847, 7, 3, 3297, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (7848, 3, 12, 3297, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (7849, 10, 1, 3298, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (7850, 5, 6, 3298, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (7851, 4, 2, 3298, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (7852, 4, 5, 3298, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (7853, 10, 11, 3298, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (7854, 3, 7, 3298, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (7855, 2, 12, 3298, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (7856, 1, 4, 3298, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (7857, 10, 13, 3298, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (7858, 6, 10, 3298, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (7859, 7, 14, 3298, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (7860, 3, 3, 3298, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (7861, 1, 9, 3298, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7862, 7, 3, 3299, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (7863, 5, 13, 3299, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (7864, 8, 2, 3299, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (7865, 3, 11, 3299, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (7866, 3, 7, 3299, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (7867, 10, 5, 3299, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (7868, 5, 1, 3299, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (7869, 1, 14, 3299, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (7870, 6, 10, 3299, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (7871, 8, 4, 3299, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (7872, 2, 12, 3299, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (7873, 1, 9, 3299, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7874, 5, 3, 3300, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (7875, 8, 4, 3300, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (7876, 6, 2, 3300, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (7877, 7, 14, 3300, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (7878, 9, 13, 3300, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (7879, 6, 11, 3300, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (7880, 6, 7, 3300, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (7881, 4, 10, 3300, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (7882, 3, 12, 3300, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (7883, 1, 8, 3300, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7884, 1, 9, 3300, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7885, 1, 10, 3301, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (7886, 9, 13, 3301, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (7887, 4, 11, 3301, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (7888, 4, 3, 3301, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (7889, 2, 14, 3301, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (7890, 3, 5, 3301, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (7891, 8, 12, 3301, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (7892, 3, 4, 3301, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (7893, 8, 6, 3301, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (7894, 1, 9, 3301, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7895, 7, 5, 3302, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (7896, 3, 14, 3302, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (7897, 9, 12, 3302, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (7898, 4, 2, 3302, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (7899, 8, 4, 3302, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (7900, 5, 10, 3302, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (7901, 3, 7, 3302, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (7902, 5, 6, 3303, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (7903, 3, 1, 3303, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (7904, 2, 2, 3303, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (7905, 10, 10, 3303, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (7906, 4, 11, 3303, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (7907, 1, 3, 3303, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (7908, 4, 13, 3303, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (7909, 7, 7, 3303, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (7910, 2, 14, 3303, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (7911, 6, 12, 3303, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (7912, 1, 8, 3303, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7913, 7, 12, 3304, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (7914, 6, 7, 3304, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (7915, 2, 6, 3304, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (7916, 3, 11, 3304, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (7917, 8, 5, 3304, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (7918, 1, 4, 3304, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (7919, 6, 3, 3304, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (7920, 6, 13, 3304, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (7921, 6, 2, 3304, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (7922, 9, 14, 3304, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (7923, 9, 10, 3304, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (7924, 1, 8, 3304, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7925, 8, 2, 3305, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (7926, 1, 9, 3305, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7927, 1, 8, 3305, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7928, 9, 6, 3306, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (7929, 1, 9, 3306, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7930, 10, 4, 3307, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (7931, 2, 14, 3307, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (7932, 6, 12, 3307, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (7933, 6, 11, 3307, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (7934, 8, 13, 3307, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (7935, 7, 10, 3307, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (7936, 9, 2, 3307, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (7937, 5, 3, 3307, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (7938, 8, 6, 3307, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (7939, 5, 7, 3307, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (7940, 1, 1, 3307, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (7941, 3, 5, 3307, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (7942, 5, 5, 3308, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (7943, 8, 2, 3308, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (7944, 1, 1, 3308, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (7945, 3, 10, 3308, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (7946, 1, 8, 3308, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7947, 1, 9, 3308, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7948, 10, 13, 3309, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (7949, 3, 7, 3309, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (7950, 7, 1, 3309, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (7951, 1, 9, 3309, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7952, 10, 3, 3310, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (7953, 2, 4, 3310, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (7954, 4, 12, 3310, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (7955, 6, 14, 3310, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (7956, 10, 11, 3310, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (7957, 9, 2, 3310, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (7958, 4, 10, 3310, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (7959, 4, 1, 3310, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (7960, 9, 6, 3310, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (7961, 7, 7, 3310, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (7962, 1, 8, 3310, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7963, 1, 8, 3311, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7964, 1, 9, 3311, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7965, 10, 2, 3312, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (7966, 9, 4, 3312, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (7967, 7, 14, 3312, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (7968, 5, 7, 3313, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (7969, 2, 1, 3313, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (7970, 9, 11, 3313, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (7971, 1, 2, 3313, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (7972, 1, 14, 3313, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (7973, 1, 9, 3313, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7974, 1, 8, 3313, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7975, 3, 2, 3314, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (7976, 2, 3, 3314, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (7977, 7, 4, 3314, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (7978, 9, 14, 3314, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (7979, 9, 7, 3314, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (7980, 2, 13, 3314, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (7981, 1, 11, 3314, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (7982, 9, 1, 3314, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (7983, 1, 6, 3314, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (7984, 1, 12, 3314, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (7985, 10, 5, 3314, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (7986, 3, 10, 3314, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (7987, 1, 8, 3314, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (7988, 1, 9, 3314, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (7989, 9, 4, 3315, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (7990, 10, 3, 3315, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (7991, 10, 7, 3315, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (7992, 3, 6, 3315, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (7993, 1, 10, 3315, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (7994, 9, 1, 3315, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (7995, 4, 12, 3315, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (7996, 2, 13, 3315, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (7997, 9, 14, 3315, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (7998, 8, 2, 3315, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (7999, 1, 9, 3315, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8000, 1, 8, 3315, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8001, 1, 13, 3316, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (8002, 5, 10, 3316, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (8003, 8, 3, 3316, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (8004, 10, 11, 3316, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (8005, 6, 12, 3316, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (8006, 9, 2, 3316, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (8007, 9, 6, 3316, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (8008, 6, 1, 3316, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (8009, 10, 5, 3316, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (8010, 8, 7, 3316, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (8011, 9, 14, 3316, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (8012, 10, 4, 3316, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (8013, 1, 9, 3316, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8014, 7, 12, 3317, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (8015, 10, 10, 3317, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (8016, 3, 5, 3317, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (8017, 10, 1, 3317, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (8018, 1, 5, 3318, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (8019, 1, 7, 3318, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (8020, 6, 4, 3318, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (8021, 10, 1, 3318, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (8022, 10, 11, 3318, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (8023, 6, 10, 3318, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (8024, 1, 12, 3318, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8025, 4, 13, 3318, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (8026, 4, 3, 3318, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (8027, 10, 14, 3318, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (8028, 9, 6, 3318, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (8029, 3, 2, 3318, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (8030, 1, 9, 3318, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8031, 1, 8, 3318, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8032, 1, 2, 3319, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (8033, 2, 5, 3319, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (8034, 1, 11, 3319, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (8035, 1, 1, 3319, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (8036, 1, 8, 3319, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8037, 8, 11, 3320, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (8038, 2, 6, 3320, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (8039, 8, 10, 3320, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (8040, 1, 4, 3320, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (8041, 5, 7, 3320, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (8042, 7, 2, 3320, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (8043, 1, 14, 3320, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (8044, 5, 5, 3320, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (8045, 3, 1, 3320, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (8046, 10, 12, 3320, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (8047, 1, 8, 3320, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8048, 2, 3, 3321, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (8049, 10, 6, 3321, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (8050, 6, 10, 3321, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (8051, 4, 2, 3321, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (8052, 8, 1, 3321, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (8053, 1, 12, 3321, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8054, 6, 11, 3321, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (8055, 4, 4, 3321, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (8056, 3, 14, 3321, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (8057, 6, 7, 3321, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (8058, 6, 5, 3321, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (8059, 1, 8, 3321, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8060, 7, 13, 3322, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (8061, 10, 7, 3322, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (8062, 10, 1, 3322, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (8063, 4, 10, 3322, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (8064, 10, 2, 3322, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8065, 4, 3, 3322, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (8066, 1, 14, 3322, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (8067, 1, 4, 3322, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (8068, 9, 6, 3322, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (8069, 3, 11, 3322, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (8070, 1, 12, 3322, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8071, 1, 12, 3323, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8072, 5, 1, 3323, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (8073, 7, 2, 3323, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (8074, 1, 8, 3323, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8075, 1, 9, 3323, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8076, 7, 11, 3324, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (8077, 6, 6, 3324, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (8078, 2, 10, 3324, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (8079, 4, 14, 3324, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (8080, 6, 1, 3324, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (8081, 4, 3, 3324, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (8082, 1, 5, 3324, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (8083, 2, 13, 3324, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (8084, 4, 12, 3324, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (8085, 10, 4, 3324, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (8086, 6, 2, 3324, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (8087, 3, 7, 3324, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (8088, 9, 7, 3325, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (8089, 4, 10, 3325, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (8090, 3, 10, 3326, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (8091, 4, 6, 3326, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (8092, 8, 13, 3326, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (8093, 1, 8, 3326, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8094, 1, 9, 3326, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8095, 1, 7, 3327, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (8096, 7, 3, 3327, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (8097, 1, 9, 3327, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8098, 1, 8, 3327, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8099, 2, 7, 3328, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (8100, 6, 11, 3328, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (8101, 9, 3, 3328, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (8102, 2, 1, 3328, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (8103, 1, 6, 3328, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (8104, 2, 5, 3328, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (8105, 5, 14, 3328, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (8106, 7, 13, 3328, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (8107, 1, 8, 3328, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8108, 6, 5, 3329, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (8109, 1, 3, 3329, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (8110, 2, 7, 3329, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (8111, 8, 1, 3329, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (8112, 4, 4, 3329, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (8113, 9, 13, 3329, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (8114, 6, 6, 3329, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (8115, 5, 10, 3329, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (8116, 1, 2, 3329, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (8117, 6, 14, 3329, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (8118, 7, 12, 3329, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (8119, 1, 11, 3329, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (8120, 9, 1, 3330, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (8121, 4, 13, 3330, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (8122, 3, 7, 3330, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (8123, 7, 14, 3330, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (8124, 6, 4, 3330, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (8125, 4, 12, 3330, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (8126, 9, 6, 3330, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (8127, 10, 10, 3330, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (8128, 1, 5, 3330, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (8129, 3, 3, 3330, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (8130, 6, 2, 3330, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (8131, 6, 11, 3330, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (8132, 1, 8, 3330, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8133, 1, 9, 3330, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8134, 9, 1, 3331, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (8135, 5, 3, 3331, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (8136, 4, 14, 3331, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (8137, 5, 5, 3331, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (8138, 9, 13, 3331, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (8139, 5, 7, 3331, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (8140, 10, 2, 3331, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8141, 6, 6, 3331, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (8142, 1, 8, 3331, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8143, 7, 14, 3332, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (8144, 9, 10, 3332, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (8145, 1, 5, 3332, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (8146, 3, 1, 3332, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (8147, 4, 3, 3332, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (8148, 4, 7, 3332, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (8149, 2, 2, 3332, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (8150, 3, 6, 3332, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (8151, 4, 12, 3332, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (8152, 4, 11, 3332, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (8153, 8, 13, 3332, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (8154, 1, 9, 3332, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8155, 1, 8, 3332, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8156, 8, 10, 3333, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (8157, 10, 11, 3333, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (8158, 8, 2, 3333, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (8159, 2, 5, 3333, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (8160, 4, 6, 3333, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (8161, 1, 8, 3333, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8162, 2, 4, 3334, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (8163, 5, 7, 3334, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (8164, 8, 6, 3335, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (8165, 9, 3, 3335, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (8166, 9, 11, 3335, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (8167, 1, 4, 3335, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (8168, 3, 10, 3335, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (8169, 10, 2, 3335, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8170, 4, 7, 3335, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (8171, 6, 14, 3335, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (8172, 10, 12, 3336, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (8173, 10, 5, 3336, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (8174, 6, 4, 3336, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (8175, 7, 10, 3336, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (8176, 1, 11, 3336, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (8177, 9, 1, 3336, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (8178, 4, 2, 3336, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (8179, 7, 6, 3336, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (8180, 2, 3, 3336, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (8181, 1, 8, 3336, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8182, 6, 14, 3337, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (8183, 5, 6, 3337, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (8184, 3, 7, 3337, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (8185, 4, 1, 3337, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (8186, 4, 11, 3337, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (8187, 1, 4, 3337, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (8188, 4, 13, 3337, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (8189, 6, 10, 3337, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (8190, 1, 2, 3337, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (8191, 7, 3, 3337, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (8192, 2, 5, 3337, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (8193, 4, 5, 3338, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (8194, 9, 4, 3338, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (8195, 10, 6, 3338, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (8196, 9, 7, 3338, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (8197, 6, 13, 3338, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (8198, 1, 11, 3338, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (8199, 8, 14, 3338, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (8200, 9, 1, 3338, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (8201, 7, 3, 3338, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (8202, 9, 2, 3338, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (8203, 3, 10, 3338, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (8204, 5, 12, 3338, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (8205, 1, 8, 3338, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8206, 4, 5, 3339, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (8207, 1, 8, 3339, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8208, 5, 12, 3340, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (8209, 4, 5, 3340, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (8210, 5, 11, 3340, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (8211, 9, 7, 3340, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (8212, 1, 1, 3341, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (8213, 4, 11, 3341, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (8214, 2, 13, 3341, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (8215, 1, 3, 3341, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (8216, 1, 14, 3341, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (8217, 10, 5, 3341, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (8218, 7, 6, 3341, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (8219, 10, 10, 3341, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (8220, 3, 2, 3341, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (8221, 5, 10, 3342, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (8222, 8, 13, 3342, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (8223, 1, 11, 3342, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (8224, 3, 3, 3342, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (8225, 3, 1, 3342, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (8226, 8, 12, 3342, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (8227, 6, 2, 3342, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (8228, 8, 4, 3342, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (8229, 2, 5, 3342, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (8230, 1, 9, 3342, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8231, 1, 8, 3342, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8232, 3, 2, 3343, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (8233, 4, 10, 3343, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (8234, 1, 8, 3343, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8235, 9, 2, 3344, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (8236, 4, 4, 3344, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (8237, 1, 13, 3344, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (8238, 9, 1, 3344, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (8239, 1, 7, 3344, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (8240, 10, 6, 3344, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (8241, 1, 14, 3344, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (8242, 3, 12, 3344, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (8243, 5, 3, 3344, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (8244, 3, 10, 3344, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (8245, 6, 11, 3344, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (8246, 1, 5, 3344, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (8247, 1, 9, 3344, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8248, 1, 8, 3344, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8249, 9, 5, 3345, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (8250, 5, 13, 3345, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (8251, 2, 2, 3345, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (8252, 10, 6, 3345, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (8253, 4, 11, 3345, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (8254, 7, 3, 3345, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (8255, 3, 1, 3345, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (8256, 1, 9, 3345, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8257, 10, 14, 3346, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (8258, 2, 11, 3346, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (8259, 6, 4, 3346, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (8260, 4, 3, 3346, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (8261, 2, 6, 3346, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (8262, 5, 2, 3346, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (8263, 4, 10, 3346, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (8264, 2, 1, 3346, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (8265, 5, 7, 3346, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (8266, 6, 5, 3346, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (8267, 1, 8, 3346, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8268, 5, 7, 3347, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (8269, 4, 4, 3347, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (8270, 8, 6, 3347, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (8271, 4, 10, 3347, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (8272, 9, 1, 3347, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (8273, 6, 2, 3347, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (8274, 8, 11, 3347, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (8275, 10, 14, 3347, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (8276, 6, 5, 3347, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (8277, 2, 3, 3347, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (8278, 7, 12, 3347, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (8279, 1, 8, 3347, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8280, 1, 9, 3347, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8281, 3, 13, 3348, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (8282, 4, 14, 3348, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (8283, 10, 7, 3348, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (8284, 8, 1, 3348, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (8285, 7, 6, 3348, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (8286, 2, 5, 3348, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (8287, 2, 3, 3348, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (8288, 1, 12, 3348, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8289, 3, 11, 3348, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (8290, 7, 10, 3348, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (8291, 7, 2, 3348, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (8292, 9, 4, 3348, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (8293, 1, 8, 3348, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8294, 4, 3, 3349, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (8295, 2, 14, 3349, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (8296, 1, 8, 3349, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8297, 1, 9, 3349, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8298, 2, 3, 3350, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (8299, 6, 12, 3350, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (8300, 4, 10, 3350, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (8301, 9, 4, 3350, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (8302, 2, 1, 3350, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (8303, 8, 13, 3350, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (8304, 7, 6, 3350, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (8305, 1, 9, 3350, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8306, 4, 2, 3351, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (8307, 9, 11, 3351, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (8308, 1, 6, 3351, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (8309, 1, 12, 3351, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8310, 6, 1, 3351, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (8311, 10, 14, 3351, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (8312, 5, 10, 3351, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (8313, 3, 7, 3351, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (8314, 6, 3, 3351, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (8315, 3, 4, 3351, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (8316, 5, 13, 3351, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (8317, 9, 5, 3351, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (8318, 1, 9, 3351, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8319, 6, 5, 3352, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (8320, 10, 13, 3352, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (8321, 6, 11, 3352, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (8322, 4, 1, 3352, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (8323, 7, 13, 3353, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (8324, 6, 4, 3353, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (8325, 2, 11, 3353, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (8326, 5, 12, 3353, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (8327, 9, 6, 3353, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (8328, 1, 8, 3353, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8329, 1, 9, 3353, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8330, 3, 6, 3354, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (8331, 8, 1, 3354, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (8332, 10, 2, 3354, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8333, 6, 10, 3354, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (8334, 2, 4, 3354, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (8335, 9, 14, 3354, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (8336, 10, 3, 3354, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (8337, 1, 9, 3354, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8338, 9, 6, 3355, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (8339, 9, 4, 3355, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (8340, 9, 7, 3355, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (8341, 5, 13, 3355, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (8342, 3, 10, 3355, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (8343, 10, 14, 3355, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (8344, 8, 5, 3355, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (8345, 3, 3, 3355, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (8346, 4, 11, 3355, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (8347, 2, 1, 3355, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (8348, 10, 12, 3355, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (8349, 10, 2, 3355, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8350, 8, 10, 3356, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (8351, 4, 5, 3356, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (8352, 9, 11, 3356, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (8353, 5, 12, 3356, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (8354, 4, 1, 3356, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (8355, 4, 2, 3356, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (8356, 7, 3, 3356, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (8357, 2, 14, 3356, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (8358, 4, 13, 3356, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (8359, 3, 4, 3356, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (8360, 1, 8, 3356, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8361, 1, 9, 3356, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8362, 6, 11, 3357, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (8363, 1, 3, 3357, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (8364, 1, 4, 3357, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (8365, 8, 5, 3357, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (8366, 1, 12, 3357, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8367, 9, 13, 3357, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (8368, 1, 10, 3357, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (8369, 5, 6, 3357, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (8370, 10, 2, 3357, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8371, 1, 1, 3357, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (8372, 1, 8, 3357, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8373, 4, 4, 3358, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (8374, 8, 10, 3358, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (8375, 3, 3, 3358, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (8376, 8, 12, 3358, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (8377, 7, 13, 3358, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (8378, 8, 14, 3358, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (8379, 1, 5, 3358, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (8380, 1, 11, 3358, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (8381, 1, 8, 3358, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8382, 10, 4, 3359, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (8383, 9, 3, 3359, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (8384, 7, 14, 3359, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (8385, 6, 10, 3359, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (8386, 10, 13, 3359, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (8387, 8, 2, 3359, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (8388, 3, 1, 3359, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (8389, 1, 5, 3359, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (8390, 6, 11, 3359, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (8391, 4, 12, 3359, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (8392, 5, 6, 3359, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (8393, 6, 7, 3359, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (8394, 1, 8, 3359, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8395, 4, 7, 3360, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (8396, 2, 6, 3360, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (8397, 8, 12, 3360, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (8398, 6, 1, 3360, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (8399, 10, 5, 3360, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (8400, 4, 11, 3360, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (8401, 3, 3, 3360, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (8402, 1, 10, 3360, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (8403, 4, 14, 3360, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (8404, 8, 13, 3360, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (8405, 3, 4, 3360, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (8406, 8, 2, 3360, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (8407, 1, 8, 3360, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8408, 3, 12, 3361, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (8409, 6, 2, 3361, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (8410, 6, 14, 3361, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (8411, 6, 10, 3362, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (8412, 5, 11, 3362, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (8413, 1, 8, 3362, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8414, 1, 9, 3362, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8415, 3, 11, 3363, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (8416, 1, 12, 3363, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8417, 7, 14, 3363, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (8418, 6, 6, 3363, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (8419, 7, 7, 3364, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (8420, 6, 6, 3364, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (8421, 5, 12, 3364, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (8422, 10, 2, 3364, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8423, 5, 13, 3364, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (8424, 8, 1, 3364, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (8425, 3, 10, 3364, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (8426, 10, 3, 3364, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (8427, 3, 11, 3364, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (8428, 6, 5, 3364, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (8429, 1, 4, 3364, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (8430, 2, 14, 3364, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (8431, 1, 9, 3364, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8432, 1, 12, 3365, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8433, 3, 1, 3365, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (8434, 5, 4, 3365, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (8435, 9, 6, 3365, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (8436, 5, 7, 3365, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (8437, 8, 13, 3365, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (8438, 2, 5, 3365, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (8439, 6, 10, 3365, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (8440, 4, 14, 3365, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (8441, 7, 2, 3365, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (8442, 7, 11, 3365, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (8443, 4, 3, 3365, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (8444, 1, 8, 3365, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8445, 1, 9, 3365, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8446, 6, 4, 3366, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (8447, 7, 10, 3366, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (8448, 7, 14, 3366, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (8449, 10, 12, 3366, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (8450, 4, 7, 3366, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (8451, 10, 1, 3366, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (8452, 10, 11, 3366, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (8453, 7, 3, 3366, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (8454, 6, 2, 3366, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (8455, 10, 5, 3366, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (8456, 1, 8, 3366, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8457, 1, 9, 3366, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8458, 8, 7, 3367, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (8459, 3, 3, 3367, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (8460, 4, 14, 3367, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (8461, 6, 12, 3367, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (8462, 8, 10, 3367, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (8463, 1, 5, 3367, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (8464, 7, 13, 3367, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (8465, 3, 2, 3367, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (8466, 5, 4, 3367, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (8467, 4, 1, 3367, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (8468, 9, 11, 3367, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (8469, 9, 6, 3367, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (8470, 6, 7, 3368, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (8471, 7, 14, 3368, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (8472, 5, 11, 3368, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (8473, 10, 2, 3368, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8474, 7, 4, 3368, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (8475, 4, 5, 3368, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (8476, 6, 10, 3368, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (8477, 4, 10, 3370, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (8478, 4, 1, 3370, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (8479, 6, 4, 3371, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (8480, 7, 1, 3371, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (8481, 4, 10, 3371, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (8482, 5, 7, 3371, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (8483, 7, 5, 3371, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (8484, 8, 3, 3371, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (8485, 1, 13, 3371, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (8486, 1, 9, 3371, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8487, 7, 6, 3372, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (8488, 1, 7, 3372, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (8489, 10, 13, 3372, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (8490, 10, 5, 3372, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (8491, 2, 3, 3372, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (8492, 10, 11, 3372, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (8493, 3, 10, 3372, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (8494, 10, 14, 3372, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (8495, 1, 9, 3372, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8496, 1, 8, 3372, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8497, 4, 13, 3374, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (8498, 2, 10, 3375, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (8499, 8, 2, 3375, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (8500, 3, 13, 3375, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (8501, 3, 6, 3375, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (8502, 1, 7, 3375, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (8503, 4, 12, 3375, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (8504, 3, 5, 3375, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (8505, 8, 4, 3376, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (8506, 3, 12, 3376, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (8507, 8, 1, 3376, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (8508, 10, 6, 3376, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (8509, 3, 5, 3376, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (8510, 5, 10, 3376, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (8511, 8, 14, 3376, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (8512, 5, 11, 3376, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (8513, 5, 3, 3376, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (8514, 10, 13, 3376, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (8515, 9, 2, 3376, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (8516, 5, 7, 3376, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (8517, 1, 9, 3376, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8518, 9, 4, 3377, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (8519, 3, 10, 3377, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (8520, 7, 3, 3377, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (8521, 7, 13, 3377, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (8522, 5, 5, 3377, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (8523, 9, 2, 3377, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (8524, 7, 11, 3377, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (8525, 9, 1, 3377, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (8526, 7, 13, 3378, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (8527, 8, 1, 3378, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (8528, 2, 3, 3378, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (8529, 5, 10, 3378, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (8530, 8, 6, 3378, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (8531, 5, 7, 3378, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (8532, 9, 5, 3378, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (8533, 6, 2, 3378, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (8534, 9, 14, 3378, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (8535, 3, 12, 3378, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (8536, 5, 11, 3378, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (8537, 7, 4, 3378, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (8538, 1, 8, 3378, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8539, 1, 9, 3378, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8540, 4, 1, 3379, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (8541, 7, 2, 3380, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (8542, 5, 13, 3380, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (8543, 8, 12, 3380, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (8544, 5, 4, 3380, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (8545, 3, 14, 3380, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (8546, 8, 1, 3380, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (8547, 4, 5, 3380, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (8548, 10, 7, 3380, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (8549, 5, 6, 3380, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (8550, 5, 3, 3380, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (8551, 5, 1, 3381, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (8552, 2, 4, 3381, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (8553, 4, 10, 3381, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (8554, 2, 12, 3381, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (8555, 2, 11, 3381, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (8556, 10, 2, 3381, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8557, 7, 5, 3381, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (8558, 1, 3, 3381, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (8559, 1, 6, 3381, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (8560, 1, 7, 3381, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (8561, 2, 14, 3381, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (8562, 1, 9, 3381, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8563, 1, 8, 3381, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8564, 3, 5, 3382, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (8565, 3, 14, 3382, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (8566, 2, 13, 3382, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (8567, 5, 10, 3382, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (8568, 10, 2, 3382, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8569, 5, 7, 3382, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (8570, 5, 12, 3382, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (8571, 5, 1, 3382, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (8572, 9, 3, 3382, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (8573, 8, 4, 3382, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (8574, 1, 9, 3382, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8575, 4, 10, 3383, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (8576, 4, 11, 3383, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (8577, 8, 14, 3383, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (8578, 5, 3, 3383, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (8579, 6, 13, 3383, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (8580, 8, 4, 3383, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (8581, 1, 1, 3383, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (8582, 1, 8, 3383, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8583, 6, 1, 3384, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (8584, 1, 12, 3384, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8585, 7, 11, 3384, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (8586, 1, 13, 3384, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (8587, 8, 6, 3384, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (8588, 9, 2, 3384, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (8589, 3, 7, 3384, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (8590, 9, 5, 3384, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (8591, 4, 3, 3384, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (8592, 2, 10, 3384, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (8593, 3, 4, 3384, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (8594, 8, 14, 3384, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (8595, 1, 9, 3384, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8596, 4, 2, 3385, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (8597, 5, 11, 3385, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (8598, 5, 14, 3385, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (8599, 7, 10, 3385, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (8600, 9, 3, 3385, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (8601, 3, 1, 3385, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (8602, 1, 4, 3385, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (8603, 5, 13, 3385, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (8604, 10, 12, 3385, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (8605, 2, 5, 3385, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (8606, 1, 7, 3385, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (8607, 7, 6, 3385, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (8608, 6, 4, 3386, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (8609, 3, 11, 3386, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (8610, 10, 1, 3386, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (8611, 1, 8, 3386, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8612, 4, 2, 3387, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (8613, 9, 10, 3388, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (8614, 7, 4, 3388, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (8615, 1, 9, 3388, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8616, 1, 8, 3388, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8617, 1, 8, 3389, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8618, 1, 9, 3389, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8619, 2, 6, 3390, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (8620, 1, 5, 3390, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (8621, 8, 4, 3390, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (8622, 4, 1, 3390, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (8623, 6, 7, 3390, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (8624, 10, 2, 3390, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8625, 4, 10, 3390, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (8626, 9, 11, 3390, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (8627, 1, 8, 3390, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8628, 2, 13, 3391, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (8629, 6, 1, 3391, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (8630, 8, 4, 3391, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (8631, 5, 7, 3391, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (8632, 9, 10, 3391, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (8633, 9, 2, 3391, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (8634, 3, 11, 3391, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (8635, 6, 5, 3391, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (8636, 7, 3, 3391, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (8637, 10, 6, 3391, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (8638, 5, 12, 3391, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (8639, 5, 14, 3391, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (8640, 1, 8, 3391, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8641, 1, 9, 3391, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8642, 6, 11, 3392, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (8643, 2, 5, 3392, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (8644, 6, 7, 3392, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (8645, 10, 6, 3392, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (8646, 8, 3, 3392, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (8647, 5, 2, 3392, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (8648, 3, 1, 3392, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (8649, 7, 10, 3392, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (8650, 9, 4, 3392, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (8651, 5, 13, 3392, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (8652, 2, 12, 3392, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (8653, 8, 14, 3392, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (8654, 1, 9, 3392, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8655, 1, 8, 3392, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8656, 2, 11, 3393, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (8657, 7, 13, 3393, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (8658, 8, 12, 3393, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (8659, 8, 5, 3393, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (8660, 4, 14, 3393, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (8661, 7, 3, 3393, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (8662, 8, 2, 3394, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (8663, 4, 1, 3394, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (8664, 9, 14, 3394, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (8665, 10, 11, 3394, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (8666, 1, 9, 3394, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8667, 1, 8, 3394, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8668, 3, 5, 3395, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (8669, 6, 7, 3396, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (8670, 10, 1, 3396, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (8671, 5, 12, 3396, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (8672, 1, 8, 3396, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8673, 5, 11, 3397, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (8674, 8, 2, 3397, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (8675, 5, 4, 3397, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (8676, 3, 3, 3397, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (8677, 4, 14, 3397, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (8678, 1, 9, 3397, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8679, 1, 8, 3397, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8680, 5, 13, 3398, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (8681, 1, 1, 3398, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (8682, 2, 6, 3398, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (8683, 3, 5, 3398, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (8684, 1, 8, 3398, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8685, 1, 9, 3398, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8686, 1, 8, 3399, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8687, 1, 9, 3399, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8688, 1, 12, 3400, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8689, 6, 7, 3400, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (8690, 5, 10, 3400, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (8691, 5, 3, 3400, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (8692, 10, 5, 3400, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (8693, 1, 6, 3400, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (8694, 6, 4, 3400, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (8695, 10, 13, 3400, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (8696, 5, 1, 3400, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (8697, 10, 11, 3400, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (8698, 8, 14, 3400, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (8699, 10, 2, 3400, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8700, 2, 5, 3401, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (8701, 4, 10, 3401, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (8702, 4, 6, 3401, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (8703, 1, 9, 3401, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8704, 6, 7, 3402, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (8705, 7, 2, 3402, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (8706, 4, 6, 3402, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (8707, 5, 4, 3402, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (8708, 8, 14, 3402, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (8709, 9, 3, 3402, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (8710, 10, 11, 3402, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (8711, 2, 13, 3402, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (8712, 9, 10, 3402, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (8713, 6, 2, 3403, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (8714, 4, 5, 3403, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (8715, 9, 4, 3403, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (8716, 6, 12, 3403, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (8717, 3, 10, 3403, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (8718, 6, 13, 3403, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (8719, 9, 6, 3403, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (8720, 5, 3, 3403, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (8721, 8, 7, 3403, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (8722, 2, 14, 3403, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (8723, 1, 8, 3403, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8724, 1, 9, 3403, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8725, 4, 12, 3404, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (8726, 4, 7, 3404, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (8727, 4, 6, 3404, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (8728, 1, 10, 3404, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (8729, 7, 3, 3404, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (8730, 9, 14, 3404, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (8731, 9, 5, 3404, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (8732, 6, 1, 3404, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (8733, 9, 11, 3404, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (8734, 10, 2, 3404, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8735, 4, 13, 3404, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (8736, 9, 4, 3404, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (8737, 1, 9, 3404, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8738, 1, 8, 3404, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8739, 7, 11, 3405, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (8740, 2, 7, 3405, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (8741, 3, 6, 3405, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (8742, 9, 12, 3405, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (8743, 8, 3, 3405, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (8744, 1, 5, 3405, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (8745, 4, 4, 3405, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (8746, 5, 13, 3405, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (8747, 2, 14, 3405, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (8748, 2, 1, 3405, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (8749, 1, 9, 3405, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8750, 10, 2, 3406, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8751, 9, 12, 3406, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (8752, 10, 3, 3406, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (8753, 8, 11, 3406, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (8754, 1, 8, 3406, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8755, 1, 9, 3406, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8756, 5, 5, 3407, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (8757, 4, 7, 3407, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (8758, 1, 11, 3407, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (8759, 8, 2, 3407, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (8760, 7, 12, 3407, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (8761, 8, 14, 3407, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (8762, 4, 13, 3407, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (8763, 8, 6, 3407, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (8764, 10, 3, 3407, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (8765, 3, 1, 3407, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (8766, 5, 4, 3407, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (8767, 1, 10, 3407, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (8768, 1, 9, 3407, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8769, 6, 5, 3408, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (8770, 7, 14, 3408, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (8771, 7, 6, 3408, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (8772, 2, 2, 3408, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (8773, 5, 4, 3408, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (8774, 10, 13, 3408, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (8775, 1, 11, 3408, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (8776, 4, 3, 3408, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (8777, 9, 7, 3408, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (8778, 9, 12, 3408, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (8779, 1, 1, 3408, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (8780, 1, 9, 3408, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8781, 4, 10, 3409, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (8782, 1, 8, 3409, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8783, 1, 8, 3410, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8784, 9, 7, 3411, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (8785, 1, 9, 3411, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8786, 1, 8, 3411, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8787, 7, 14, 3412, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (8788, 5, 3, 3412, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (8789, 2, 12, 3412, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (8790, 1, 8, 3412, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8791, 1, 9, 3412, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8792, 9, 3, 3413, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (8793, 5, 13, 3413, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (8794, 10, 10, 3413, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (8795, 6, 2, 3413, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (8796, 8, 5, 3413, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (8797, 8, 7, 3413, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (8798, 7, 14, 3413, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (8799, 9, 5, 3414, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (8800, 3, 14, 3414, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (8801, 7, 2, 3414, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (8802, 10, 3, 3414, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (8803, 4, 4, 3414, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (8804, 6, 11, 3414, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (8805, 1, 9, 3414, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8806, 1, 8, 3414, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8807, 6, 5, 3415, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (8808, 4, 3, 3415, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (8809, 1, 2, 3415, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (8810, 1, 7, 3415, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (8811, 6, 14, 3415, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (8812, 8, 11, 3415, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (8813, 1, 8, 3415, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8814, 1, 9, 3415, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8815, 2, 1, 3416, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (8816, 2, 10, 3416, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (8817, 3, 14, 3416, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (8818, 9, 5, 3416, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (8819, 10, 4, 3416, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (8820, 9, 2, 3416, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (8821, 1, 3, 3416, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (8822, 4, 11, 3416, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (8823, 3, 13, 3416, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (8824, 3, 6, 3416, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (8825, 1, 8, 3416, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8826, 1, 9, 3416, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8827, 10, 14, 3417, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (8828, 10, 13, 3417, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (8829, 5, 12, 3417, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (8830, 1, 10, 3417, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (8831, 4, 7, 3417, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (8832, 1, 11, 3417, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (8833, 5, 5, 3417, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (8834, 5, 4, 3417, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (8835, 1, 3, 3417, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (8836, 10, 2, 3417, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8837, 3, 6, 3417, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (8838, 10, 1, 3417, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (8839, 1, 9, 3417, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8840, 9, 7, 3418, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (8841, 6, 2, 3418, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (8842, 7, 10, 3418, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (8843, 7, 3, 3418, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (8844, 6, 4, 3418, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (8845, 1, 11, 3418, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (8846, 10, 13, 3418, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (8847, 9, 1, 3418, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (8848, 9, 5, 3418, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (8849, 1, 12, 3418, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8850, 4, 6, 3418, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (8851, 1, 8, 3418, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8852, 7, 6, 3419, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (8853, 5, 10, 3419, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (8854, 4, 12, 3419, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (8855, 8, 11, 3419, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (8856, 9, 7, 3419, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (8857, 8, 14, 3419, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (8858, 9, 2, 3419, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (8859, 9, 1, 3419, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (8860, 10, 4, 3419, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (8861, 8, 5, 3419, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (8862, 4, 13, 3419, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (8863, 5, 3, 3419, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (8864, 9, 3, 3420, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (8865, 8, 14, 3420, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (8866, 3, 4, 3420, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (8867, 10, 6, 3420, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (8868, 7, 7, 3420, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (8869, 1, 1, 3420, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (8870, 9, 5, 3420, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (8871, 8, 10, 3420, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (8872, 5, 13, 3420, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (8873, 3, 6, 3421, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (8874, 10, 5, 3421, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (8875, 2, 11, 3421, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (8876, 1, 1, 3421, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (8877, 9, 3, 3421, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (8878, 10, 2, 3421, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (8879, 9, 13, 3421, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (8880, 7, 10, 3421, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (8881, 10, 4, 3421, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (8882, 6, 14, 3421, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (8883, 1, 12, 3421, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8884, 5, 7, 3421, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (8885, 1, 8, 3421, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8886, 1, 9, 3421, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8887, 7, 4, 3422, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (8888, 1, 12, 3422, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8889, 5, 5, 3422, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (8890, 4, 13, 3422, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (8891, 1, 11, 3422, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (8892, 3, 3, 3422, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (8893, 2, 10, 3422, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (8894, 5, 14, 3422, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (8895, 1, 8, 3422, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8896, 1, 9, 3423, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8897, 1, 8, 3423, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8898, 10, 7, 3424, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (8899, 3, 2, 3424, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (8900, 6, 13, 3424, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (8901, 9, 1, 3424, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (8902, 8, 3, 3424, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (8903, 7, 12, 3424, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (8904, 3, 11, 3424, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (8905, 7, 5, 3424, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (8906, 9, 10, 3424, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (8907, 9, 14, 3424, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (8908, 6, 6, 3424, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (8909, 6, 4, 3424, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (8910, 1, 8, 3424, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8911, 2, 10, 3425, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (8912, 8, 12, 3425, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (8913, 2, 6, 3425, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (8914, 6, 1, 3425, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (8915, 8, 11, 3425, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (8916, 3, 14, 3425, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (8917, 7, 3, 3425, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (8918, 6, 4, 3425, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (8919, 7, 7, 3425, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (8920, 6, 13, 3425, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (8921, 1, 8, 3425, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8922, 10, 1, 3426, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (8923, 3, 11, 3426, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (8924, 2, 6, 3426, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (8925, 7, 10, 3426, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (8926, 6, 13, 3426, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (8927, 1, 9, 3426, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8928, 1, 8, 3426, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8929, 1, 8, 3427, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8930, 1, 9, 3427, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8931, 4, 11, 3428, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (8932, 9, 4, 3428, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (8933, 1, 9, 3428, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8934, 1, 8, 3428, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8935, 1, 14, 3429, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (8936, 3, 10, 3429, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (8937, 5, 11, 3429, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (8938, 7, 13, 3429, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (8939, 8, 12, 3429, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (8940, 6, 6, 3429, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (8941, 1, 2, 3429, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (8942, 2, 4, 3429, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (8943, 10, 3, 3429, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (8944, 1, 1, 3429, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (8945, 5, 5, 3429, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (8946, 2, 1, 3430, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (8947, 6, 12, 3430, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (8948, 2, 2, 3430, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (8949, 2, 10, 3430, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (8950, 4, 14, 3430, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (8951, 8, 6, 3430, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (8952, 9, 3, 3430, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (8953, 1, 11, 3430, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (8954, 10, 7, 3430, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (8955, 2, 5, 3430, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (8956, 9, 4, 3430, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (8957, 9, 13, 3430, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (8958, 1, 8, 3430, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8959, 8, 2, 3431, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (8960, 10, 14, 3431, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (8961, 5, 1, 3431, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (8962, 4, 7, 3431, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (8963, 1, 11, 3431, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (8964, 7, 3, 3431, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (8965, 3, 5, 3431, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (8966, 1, 12, 3431, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8967, 2, 6, 3431, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (8968, 4, 13, 3431, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (8969, 8, 4, 3431, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (8970, 10, 13, 3433, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (8971, 9, 12, 3433, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (8972, 6, 2, 3433, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (8973, 4, 3, 3433, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (8974, 4, 11, 3433, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (8975, 9, 1, 3433, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (8976, 7, 10, 3433, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (8977, 2, 14, 3433, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (8978, 7, 6, 3433, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (8979, 7, 5, 3433, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (8980, 6, 7, 3433, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (8981, 10, 4, 3433, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (8982, 1, 8, 3433, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8983, 5, 4, 3434, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (8984, 5, 11, 3434, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (8985, 5, 3, 3434, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (8986, 7, 2, 3434, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (8987, 1, 9, 3434, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (8988, 10, 14, 3436, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (8989, 8, 6, 3436, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (8990, 5, 10, 3436, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (8991, 1, 8, 3436, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (8992, 3, 3, 3437, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (8993, 8, 6, 3437, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (8994, 1, 12, 3437, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (8995, 2, 4, 3437, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (8996, 5, 2, 3437, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (8997, 3, 1, 3437, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (8998, 4, 14, 3437, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (8999, 1, 12, 3438, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (9000, 1, 14, 3438, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (9001, 4, 5, 3438, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (9002, 5, 2, 3438, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (9003, 2, 13, 3438, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (9004, 1, 8, 3438, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9005, 10, 1, 3439, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (9006, 6, 11, 3439, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (9007, 5, 12, 3439, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (9008, 8, 13, 3439, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (9009, 1, 2, 3439, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (9010, 8, 6, 3439, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (9011, 4, 3, 3439, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (9012, 5, 7, 3440, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (9013, 5, 3, 3440, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (9014, 2, 12, 3440, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (9015, 7, 13, 3440, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (9016, 10, 5, 3440, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (9017, 9, 1, 3440, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (9018, 4, 14, 3440, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (9019, 9, 10, 3440, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (9020, 3, 2, 3440, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (9021, 4, 4, 3440, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (9022, 10, 11, 3440, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (9023, 6, 6, 3440, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (9024, 1, 9, 3440, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9025, 1, 8, 3440, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9026, 6, 14, 3441, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (9027, 10, 12, 3441, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (9028, 9, 4, 3441, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (9029, 4, 2, 3441, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (9030, 1, 3, 3441, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (9031, 7, 11, 3441, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (9032, 8, 13, 3441, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (9033, 2, 10, 3442, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (9034, 2, 6, 3442, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (9035, 7, 12, 3442, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (9036, 1, 8, 3442, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9037, 7, 5, 3443, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (9038, 5, 10, 3443, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (9039, 1, 8, 3443, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9040, 5, 3, 3444, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (9041, 10, 10, 3444, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (9042, 6, 1, 3444, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (9043, 10, 12, 3444, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (9044, 4, 2, 3444, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (9045, 2, 4, 3444, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (9046, 10, 13, 3444, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (9047, 3, 14, 3444, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (9048, 5, 6, 3444, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (9049, 10, 7, 3444, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (9050, 10, 5, 3444, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (9051, 3, 11, 3444, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (9052, 1, 8, 3445, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9053, 1, 9, 3445, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9054, 2, 6, 3446, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (9055, 2, 4, 3446, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (9056, 8, 11, 3446, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (9057, 6, 10, 3446, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (9058, 4, 5, 3447, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (9059, 7, 11, 3447, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (9060, 6, 13, 3447, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (9061, 8, 12, 3447, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (9062, 8, 1, 3447, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (9063, 5, 3, 3447, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (9064, 1, 10, 3447, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (9065, 3, 2, 3447, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (9066, 4, 6, 3447, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (9067, 1, 9, 3447, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9068, 1, 8, 3447, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9069, 1, 8, 3448, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9070, 1, 9, 3448, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9071, 9, 14, 3449, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (9072, 7, 10, 3449, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (9073, 9, 12, 3449, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (9074, 1, 2, 3449, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (9075, 9, 1, 3449, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (9076, 6, 7, 3449, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (9077, 7, 3, 3449, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (9078, 1, 5, 3449, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (9079, 1, 9, 3449, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9080, 1, 8, 3449, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9081, 9, 12, 3450, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (9082, 9, 5, 3450, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (9083, 3, 2, 3450, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (9084, 7, 11, 3450, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (9085, 4, 14, 3450, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (9086, 3, 4, 3450, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (9087, 9, 6, 3450, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (9088, 1, 8, 3450, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9089, 1, 9, 3450, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9090, 1, 9, 3451, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9091, 2, 12, 3452, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (9092, 3, 6, 3452, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (9093, 3, 10, 3452, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (9094, 3, 5, 3452, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (9095, 1, 1, 3452, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (9096, 9, 14, 3452, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (9097, 9, 13, 3452, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (9098, 4, 6, 3453, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (9099, 2, 10, 3453, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (9100, 8, 5, 3453, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (9101, 7, 1, 3453, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (9102, 8, 11, 3453, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (9103, 1, 13, 3453, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (9104, 10, 3, 3453, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (9105, 7, 2, 3453, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (9106, 8, 4, 3453, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (9107, 2, 14, 3453, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (9108, 10, 12, 3453, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (9109, 1, 7, 3453, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (9110, 10, 2, 3454, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (9111, 6, 12, 3454, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (9112, 9, 13, 3454, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (9113, 2, 7, 3454, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (9114, 9, 14, 3454, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (9115, 1, 3, 3454, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (9116, 3, 4, 3454, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (9117, 7, 11, 3454, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (9118, 9, 10, 3454, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (9119, 5, 6, 3454, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (9120, 9, 10, 3455, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (9121, 8, 12, 3455, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (9122, 1, 9, 3455, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9123, 1, 8, 3455, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9124, 6, 10, 3456, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (9125, 10, 13, 3456, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (9126, 3, 1, 3456, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (9127, 6, 7, 3456, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (9128, 10, 1, 3457, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (9129, 9, 11, 3457, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (9130, 2, 10, 3457, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (9131, 2, 12, 3457, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (9132, 7, 5, 3457, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (9133, 5, 13, 3458, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (9134, 10, 14, 3458, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (9135, 6, 7, 3458, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (9136, 5, 3, 3458, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (9137, 1, 12, 3458, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (9138, 4, 6, 3458, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (9139, 3, 11, 3458, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (9140, 10, 4, 3458, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (9141, 10, 5, 3458, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (9142, 1, 10, 3458, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (9143, 7, 1, 3458, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (9144, 3, 2, 3458, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (9145, 1, 9, 3458, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9146, 8, 14, 3459, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (9147, 7, 14, 3460, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (9148, 2, 2, 3460, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (9149, 5, 10, 3460, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (9150, 10, 5, 3460, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (9151, 6, 12, 3460, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (9152, 8, 7, 3460, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (9153, 1, 11, 3460, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (9154, 4, 6, 3460, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (9155, 3, 1, 3460, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (9156, 10, 3, 3460, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (9157, 9, 4, 3460, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (9158, 7, 13, 3460, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (9159, 7, 12, 3461, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (9160, 5, 6, 3461, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (9161, 5, 11, 3461, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (9162, 3, 3, 3461, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (9163, 10, 2, 3461, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (9164, 6, 10, 3461, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (9165, 10, 7, 3461, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (9166, 1, 4, 3461, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (9167, 7, 14, 3461, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (9168, 10, 5, 3461, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (9169, 6, 1, 3461, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (9170, 7, 13, 3461, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (9171, 1, 8, 3461, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9172, 1, 9, 3461, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9173, 10, 6, 3462, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (9174, 3, 10, 3462, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (9175, 6, 1, 3462, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (9176, 2, 12, 3462, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (9177, 3, 10, 3463, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (9178, 9, 4, 3463, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (9179, 7, 13, 3463, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (9180, 10, 1, 3463, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (9181, 3, 12, 3463, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (9182, 1, 7, 3463, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (9183, 2, 11, 3463, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (9184, 2, 14, 3463, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (9185, 7, 3, 3463, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (9186, 1, 2, 3463, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (9187, 3, 5, 3463, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (9188, 7, 6, 3464, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (9189, 1, 8, 3464, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9190, 1, 9, 3464, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9191, 1, 5, 3465, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (9192, 8, 2, 3465, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (9193, 10, 3, 3465, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (9194, 10, 1, 3465, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (9195, 1, 14, 3465, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (9196, 6, 4, 3465, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (9197, 7, 10, 3465, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (9198, 4, 10, 3466, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (9199, 4, 7, 3466, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (9200, 8, 14, 3466, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (9201, 10, 5, 3466, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (9202, 5, 6, 3466, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (9203, 1, 12, 3466, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (9204, 3, 2, 3466, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (9205, 5, 3, 3466, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (9206, 9, 13, 3466, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (9207, 6, 5, 3467, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (9208, 2, 11, 3467, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (9209, 9, 6, 3467, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (9210, 1, 3, 3467, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (9211, 5, 1, 3468, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (9212, 9, 13, 3468, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (9213, 10, 10, 3468, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (9214, 9, 4, 3468, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (9215, 2, 14, 3468, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (9216, 3, 6, 3468, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (9217, 5, 2, 3468, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (9218, 6, 3, 3468, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (9219, 6, 5, 3468, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (9220, 2, 12, 3468, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (9221, 1, 9, 3468, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9222, 1, 3, 3469, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (9223, 8, 2, 3469, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (9224, 9, 10, 3469, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (9225, 1, 13, 3469, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (9226, 5, 6, 3469, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (9227, 1, 12, 3469, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (9228, 4, 4, 3469, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (9229, 1, 5, 3469, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (9230, 10, 5, 3470, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (9231, 7, 3, 3470, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (9232, 4, 7, 3470, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (9233, 5, 12, 3470, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (9234, 6, 10, 3470, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (9235, 4, 14, 3470, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (9236, 3, 11, 3470, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (9237, 8, 4, 3470, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (9238, 6, 2, 3470, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (9239, 7, 13, 3470, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (9240, 3, 6, 3470, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (9241, 1, 9, 3471, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9242, 6, 7, 3472, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (9243, 2, 10, 3472, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (9244, 9, 13, 3472, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (9245, 7, 5, 3472, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (9246, 5, 14, 3472, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (9247, 1, 8, 3472, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9248, 1, 9, 3472, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9249, 4, 10, 3473, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (9250, 9, 12, 3473, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (9251, 10, 7, 3473, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (9252, 7, 11, 3473, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (9253, 3, 2, 3474, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (9254, 6, 3, 3474, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (9255, 3, 6, 3474, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (9256, 5, 14, 3474, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (9257, 7, 13, 3474, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (9258, 1, 4, 3474, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (9259, 3, 5, 3474, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (9260, 9, 12, 3474, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (9261, 2, 11, 3475, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (9262, 5, 12, 3475, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (9263, 1, 9, 3475, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9264, 1, 8, 3475, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9265, 6, 3, 3476, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (9266, 7, 5, 3476, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (9267, 10, 10, 3476, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (9268, 9, 4, 3476, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (9269, 5, 13, 3476, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (9270, 9, 7, 3476, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (9271, 6, 14, 3476, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (9272, 8, 12, 3476, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (9273, 4, 6, 3476, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (9274, 1, 8, 3476, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9275, 9, 12, 3477, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (9276, 1, 8, 3477, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9277, 10, 14, 3478, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (9278, 3, 1, 3478, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (9279, 5, 10, 3478, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (9280, 5, 2, 3478, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (9281, 9, 12, 3479, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (9282, 7, 11, 3479, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (9283, 9, 4, 3479, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (9284, 8, 7, 3479, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (9285, 1, 5, 3479, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (9286, 8, 2, 3479, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (9287, 3, 1, 3479, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (9288, 8, 3, 3479, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (9289, 2, 6, 3479, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (9290, 9, 10, 3479, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (9291, 1, 13, 3479, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (9292, 8, 14, 3479, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (9293, 1, 9, 3479, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9294, 1, 8, 3479, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9295, 2, 11, 3480, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (9296, 4, 10, 3480, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (9297, 1, 9, 3480, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9298, 1, 8, 3480, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9299, 3, 6, 3481, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (9300, 8, 4, 3481, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (9301, 1, 9, 3481, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9302, 4, 10, 3482, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (9303, 2, 11, 3482, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (9304, 3, 12, 3482, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (9305, 5, 1, 3482, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (9306, 9, 2, 3482, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (9307, 6, 4, 3482, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (9308, 3, 13, 3482, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (9309, 10, 5, 3482, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (9310, 1, 8, 3482, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9311, 10, 14, 3483, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (9312, 10, 7, 3483, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (9313, 6, 1, 3483, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (9314, 4, 3, 3483, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (9315, 8, 10, 3483, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (9316, 9, 4, 3483, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (9317, 9, 7, 3484, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (9318, 2, 6, 3484, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (9319, 7, 3, 3484, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (9320, 1, 8, 3484, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9321, 2, 4, 3485, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (9322, 4, 2, 3485, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (9323, 8, 7, 3485, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (9324, 10, 1, 3485, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (9325, 10, 14, 3485, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (9326, 1, 9, 3485, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9327, 1, 8, 3485, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9328, 6, 12, 3486, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (9329, 5, 2, 3486, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (9330, 1, 6, 3486, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (9331, 10, 7, 3486, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (9332, 1, 9, 3486, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9333, 4, 3, 3487, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (9334, 9, 2, 3487, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (9335, 4, 5, 3487, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (9336, 8, 14, 3487, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (9337, 1, 13, 3487, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (9338, 3, 7, 3487, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (9339, 9, 10, 3487, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (9340, 8, 1, 3487, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (9341, 9, 4, 3487, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (9342, 9, 12, 3487, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (9343, 7, 6, 3487, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (9344, 9, 11, 3487, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (9345, 8, 5, 3488, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (9346, 2, 3, 3488, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (9347, 10, 4, 3488, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (9348, 7, 13, 3488, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (9349, 4, 2, 3488, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (9350, 3, 7, 3488, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (9351, 3, 14, 3488, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (9352, 9, 11, 3488, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (9353, 3, 1, 3488, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (9354, 3, 12, 3488, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (9355, 4, 10, 3488, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (9356, 3, 6, 3488, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (9357, 1, 9, 3488, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9358, 1, 8, 3488, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9359, 1, 8, 3489, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9360, 8, 4, 3490, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (9361, 9, 2, 3490, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (9362, 5, 1, 3490, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (9363, 7, 12, 3490, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (9364, 6, 14, 3490, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (9365, 4, 11, 3490, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (9366, 8, 7, 3490, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (9367, 4, 3, 3490, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (9368, 6, 10, 3490, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (9369, 8, 6, 3490, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (9370, 10, 14, 3491, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (9371, 5, 11, 3492, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (9372, 1, 13, 3492, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (9373, 6, 12, 3492, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (9374, 5, 6, 3492, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (9375, 3, 7, 3492, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (9376, 1, 9, 3492, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9377, 5, 12, 3493, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (9378, 9, 6, 3493, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (9379, 6, 4, 3493, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (9380, 9, 2, 3493, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (9381, 5, 5, 3493, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (9382, 1, 10, 3493, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (9383, 3, 7, 3493, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (9384, 3, 11, 3493, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (9385, 4, 13, 3493, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (9386, 8, 14, 3493, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (9387, 7, 6, 3494, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (9388, 7, 1, 3494, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (9389, 4, 11, 3494, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (9390, 7, 2, 3494, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (9391, 1, 8, 3494, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9392, 1, 9, 3494, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9393, 5, 13, 3495, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (9394, 8, 5, 3495, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (9395, 10, 11, 3495, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (9396, 1, 3, 3495, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (9397, 6, 4, 3495, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (9398, 1, 6, 3495, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (9399, 8, 10, 3495, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (9400, 1, 7, 3495, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (9401, 10, 2, 3495, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (9402, 3, 12, 3495, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (9403, 10, 1, 3495, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (9404, 1, 9, 3495, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9405, 9, 6, 3496, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (9406, 7, 12, 3496, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (9407, 1, 7, 3496, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (9408, 4, 2, 3496, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (9409, 4, 10, 3496, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (9410, 4, 5, 3496, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (9411, 10, 13, 3496, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (9412, 1, 3, 3496, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (9413, 8, 11, 3496, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (9414, 1, 8, 3496, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9415, 2, 5, 3497, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (9416, 2, 2, 3497, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (9417, 1, 1, 3497, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (9418, 10, 6, 3497, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (9419, 2, 7, 3497, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (9420, 1, 11, 3497, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (9421, 6, 4, 3497, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (9422, 2, 12, 3497, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (9423, 1, 8, 3497, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9424, 1, 9, 3497, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9425, 1, 8, 3498, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9426, 2, 11, 3499, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (9427, 9, 6, 3499, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (9428, 5, 5, 3499, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (9429, 9, 10, 3499, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (9430, 10, 7, 3499, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (9431, 8, 2, 3499, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (9432, 3, 13, 3499, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (9433, 4, 12, 3499, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (9434, 1, 8, 3499, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9435, 1, 9, 3499, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9436, 5, 10, 3500, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (9437, 9, 7, 3500, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (9438, 10, 6, 3501, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (9439, 8, 11, 3501, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (9440, 10, 13, 3501, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (9441, 8, 12, 3501, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (9442, 3, 14, 3501, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (9443, 1, 5, 3501, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (9444, 8, 10, 3501, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (9445, 7, 3, 3501, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (9446, 6, 4, 3501, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (9447, 1, 2, 3501, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (9448, 3, 1, 3501, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (9449, 1, 8, 3501, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9450, 1, 9, 3501, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9451, 5, 3, 3502, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (9452, 8, 6, 3502, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (9453, 3, 4, 3502, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (9454, 2, 5, 3502, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (9455, 1, 2, 3502, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (9456, 4, 1, 3502, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (9457, 5, 7, 3502, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (9458, 2, 10, 3502, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (9459, 9, 11, 3502, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (9460, 4, 13, 3502, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (9461, 5, 12, 3502, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (9462, 5, 14, 3502, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (9463, 5, 5, 3503, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (9464, 1, 1, 3503, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (9465, 1, 8, 3503, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9466, 1, 9, 3503, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9467, 5, 5, 3504, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (9468, 7, 2, 3504, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (9469, 7, 3, 3504, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (9470, 7, 6, 3504, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (9471, 4, 11, 3504, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (9472, 5, 12, 3504, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (9473, 3, 1, 3504, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (9474, 10, 4, 3504, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (9475, 4, 7, 3504, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (9476, 1, 9, 3504, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9477, 1, 8, 3504, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9478, 10, 7, 3505, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (9479, 4, 10, 3505, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (9480, 9, 1, 3505, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (9481, 8, 2, 3505, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (9482, 7, 13, 3505, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (9483, 3, 4, 3505, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (9484, 2, 14, 3505, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (9485, 9, 11, 3505, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (9486, 10, 3, 3505, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (9487, 4, 12, 3505, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (9488, 1, 8, 3505, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9489, 1, 9, 3505, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9490, 6, 11, 3506, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (9491, 5, 12, 3506, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (9492, 1, 8, 3506, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9493, 6, 12, 3507, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (9494, 5, 11, 3507, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (9495, 5, 10, 3507, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (9496, 9, 6, 3507, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (9497, 2, 1, 3507, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (9498, 2, 2, 3507, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (9499, 5, 3, 3507, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (9500, 1, 7, 3507, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (9501, 1, 9, 3507, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9502, 1, 8, 3507, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9503, 10, 13, 3508, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (9504, 1, 8, 3508, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9505, 1, 9, 3508, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9506, 4, 2, 3509, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (9507, 1, 10, 3509, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (9508, 6, 3, 3509, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (9509, 5, 4, 3509, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (9510, 6, 14, 3509, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (9511, 10, 5, 3509, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (9512, 1, 1, 3509, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (9513, 8, 12, 3509, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (9514, 10, 7, 3509, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (9515, 3, 11, 3509, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (9516, 3, 6, 3509, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (9517, 1, 9, 3509, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9518, 10, 11, 3510, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (9519, 8, 7, 3510, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (9520, 10, 3, 3510, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (9521, 8, 6, 3510, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (9522, 2, 1, 3510, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (9523, 4, 14, 3510, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (9524, 5, 13, 3510, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (9525, 3, 12, 3510, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (9526, 4, 5, 3510, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (9527, 4, 10, 3510, false, 2.9900, 11.9600);
INSERT INTO lignes_commande VALUES (9528, 5, 2, 3510, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (9529, 1, 4, 3510, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (9530, 1, 7, 3511, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (9531, 7, 4, 3511, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (9532, 3, 13, 3511, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (9533, 2, 3, 3511, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (9534, 5, 5, 3511, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (9535, 1, 4, 3512, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (9536, 2, 5, 3512, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (9537, 5, 6, 3512, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (9538, 9, 14, 3512, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (9539, 2, 12, 3512, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (9540, 2, 10, 3512, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (9541, 10, 3, 3512, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (9542, 1, 8, 3512, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9543, 10, 5, 3513, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (9544, 8, 12, 3513, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (9545, 10, 2, 3513, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (9546, 3, 13, 3513, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (9547, 9, 11, 3513, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (9548, 8, 7, 3513, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (9549, 9, 14, 3513, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (9550, 10, 6, 3513, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (9551, 2, 4, 3513, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (9552, 10, 10, 3513, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (9553, 6, 3, 3513, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (9554, 5, 1, 3513, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (9555, 8, 4, 3514, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (9556, 3, 13, 3514, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (9557, 5, 6, 3514, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (9558, 10, 2, 3514, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (9559, 7, 3, 3514, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (9560, 5, 13, 3515, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (9561, 6, 5, 3515, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (9562, 4, 12, 3515, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (9563, 3, 14, 3515, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (9564, 5, 6, 3515, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (9565, 7, 10, 3515, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (9566, 4, 3, 3516, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (9567, 6, 4, 3516, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (9568, 8, 7, 3516, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (9569, 5, 1, 3516, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (9570, 6, 12, 3516, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (9571, 1, 9, 3516, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9572, 7, 1, 3517, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (9573, 5, 5, 3517, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (9574, 3, 7, 3517, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (9575, 7, 14, 3517, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (9576, 1, 6, 3517, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (9577, 6, 10, 3517, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (9578, 8, 11, 3517, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (9579, 9, 4, 3517, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (9580, 8, 2, 3517, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (9581, 5, 12, 3517, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (9582, 3, 13, 3517, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (9583, 3, 3, 3517, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (9584, 1, 9, 3517, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9585, 1, 8, 3517, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9586, 3, 10, 3518, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (9587, 5, 1, 3518, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (9588, 7, 7, 3518, false, 6.4900, 45.4300);
INSERT INTO lignes_commande VALUES (9589, 7, 5, 3518, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (9590, 5, 2, 3518, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (9591, 1, 12, 3518, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (9592, 1, 14, 3518, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (9593, 1, 8, 3518, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9594, 1, 9, 3518, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9595, 3, 4, 3519, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (9596, 5, 10, 3519, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (9597, 7, 2, 3519, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (9598, 1, 6, 3519, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (9599, 1, 12, 3519, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (9600, 2, 5, 3519, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (9601, 3, 1, 3519, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (9602, 1, 8, 3519, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9603, 1, 9, 3519, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9604, 10, 11, 3520, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (9605, 4, 5, 3520, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (9606, 9, 6, 3520, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (9607, 10, 1, 3520, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (9608, 1, 10, 3520, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (9609, 4, 7, 3520, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (9610, 5, 12, 3520, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (9611, 3, 4, 3520, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (9612, 9, 14, 3520, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (9613, 1, 10, 3521, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (9614, 2, 14, 3521, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (9615, 1, 8, 3521, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9616, 1, 9, 3521, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9617, 3, 12, 3522, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (9618, 10, 13, 3522, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (9619, 5, 2, 3522, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (9620, 6, 14, 3522, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (9621, 1, 8, 3522, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9622, 1, 9, 3522, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9623, 7, 5, 3523, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (9624, 10, 11, 3523, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (9625, 2, 13, 3523, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (9626, 7, 1, 3525, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (9627, 3, 4, 3525, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (9628, 2, 2, 3525, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (9629, 9, 7, 3525, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (9630, 4, 5, 3525, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (9631, 4, 11, 3525, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (9632, 9, 6, 3525, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (9633, 8, 3, 3525, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (9634, 10, 12, 3525, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (9635, 1, 13, 3525, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (9636, 7, 14, 3525, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (9637, 3, 10, 3525, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (9638, 1, 9, 3525, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9639, 3, 5, 3526, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (9640, 4, 14, 3526, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (9641, 7, 12, 3526, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (9642, 10, 1, 3526, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (9643, 3, 4, 3526, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (9644, 9, 3, 3526, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (9645, 1, 8, 3526, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9646, 1, 9, 3526, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9647, 3, 5, 3527, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (9648, 3, 7, 3527, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (9649, 2, 11, 3527, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (9650, 6, 2, 3527, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (9651, 5, 6, 3527, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (9652, 1, 12, 3527, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (9653, 9, 4, 3527, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (9654, 8, 10, 3527, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (9655, 1, 8, 3527, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9656, 1, 9, 3527, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9657, 10, 10, 3528, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (9658, 3, 4, 3528, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (9659, 10, 6, 3528, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (9660, 6, 12, 3528, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (9661, 2, 3, 3528, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (9662, 1, 9, 3528, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9663, 9, 6, 3529, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (9664, 9, 7, 3529, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (9665, 7, 3, 3529, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (9666, 10, 12, 3529, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (9667, 8, 10, 3529, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (9668, 6, 5, 3529, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (9669, 2, 4, 3529, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (9670, 3, 2, 3529, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (9671, 9, 11, 3529, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (9672, 4, 13, 3529, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (9673, 1, 8, 3529, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9674, 4, 3, 3530, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (9675, 8, 1, 3530, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (9676, 2, 10, 3530, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (9677, 2, 11, 3530, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (9678, 2, 4, 3530, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (9679, 1, 12, 3530, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (9680, 5, 5, 3530, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (9681, 2, 2, 3530, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (9682, 1, 9, 3530, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9683, 2, 7, 3531, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (9684, 5, 6, 3531, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (9685, 1, 10, 3531, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (9686, 10, 3, 3531, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (9687, 4, 13, 3531, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (9688, 8, 1, 3531, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (9689, 1, 8, 3531, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9690, 1, 9, 3531, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9691, 1, 7, 3532, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (9692, 5, 13, 3532, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (9693, 9, 5, 3532, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (9694, 5, 2, 3532, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (9695, 2, 3, 3532, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (9696, 4, 1, 3532, false, 1.5400, 6.1600);
INSERT INTO lignes_commande VALUES (9697, 1, 8, 3532, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9698, 9, 5, 3533, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (9699, 6, 3, 3533, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (9700, 10, 7, 3533, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (9701, 3, 1, 3533, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (9702, 7, 11, 3533, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (9703, 7, 12, 3533, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (9704, 9, 14, 3533, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (9705, 1, 4, 3533, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (9706, 1, 13, 3533, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (9707, 1, 2, 3533, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (9708, 6, 6, 3533, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (9709, 2, 10, 3533, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (9710, 1, 9, 3533, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9711, 1, 8, 3533, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9712, 2, 4, 3534, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (9713, 10, 11, 3534, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (9714, 4, 12, 3534, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (9715, 2, 3, 3534, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (9716, 4, 13, 3534, false, 7.9900, 31.9600);
INSERT INTO lignes_commande VALUES (9717, 3, 7, 3534, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (9718, 6, 2, 3534, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (9719, 5, 1, 3534, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (9720, 6, 5, 3534, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (9721, 2, 10, 3534, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (9722, 2, 14, 3534, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (9723, 2, 6, 3534, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (9724, 1, 8, 3534, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9725, 7, 12, 3535, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (9726, 7, 5, 3535, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (9727, 2, 11, 3535, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (9728, 1, 8, 3535, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9729, 1, 9, 3535, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9730, 9, 10, 3536, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (9731, 2, 3, 3536, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (9732, 3, 5, 3536, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (9733, 7, 12, 3536, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (9734, 1, 6, 3536, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (9735, 3, 10, 3537, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (9736, 8, 4, 3537, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (9737, 6, 1, 3537, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (9738, 8, 5, 3537, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (9739, 4, 6, 3537, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (9740, 8, 11, 3537, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (9741, 10, 2, 3537, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (9742, 5, 3, 3537, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (9743, 4, 12, 3537, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (9744, 10, 14, 3537, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (9745, 5, 13, 3537, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (9746, 4, 7, 3537, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (9747, 9, 11, 3538, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (9748, 9, 7, 3538, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (9749, 4, 12, 3538, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (9750, 10, 6, 3538, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (9751, 3, 10, 3538, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (9752, 3, 3, 3538, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (9753, 2, 4, 3538, false, 0.9900, 1.9800);
INSERT INTO lignes_commande VALUES (9754, 5, 2, 3538, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (9755, 9, 1, 3538, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (9756, 2, 14, 3538, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (9757, 7, 5, 3538, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (9758, 1, 8, 3538, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9759, 10, 13, 3539, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (9760, 1, 1, 3539, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (9761, 10, 12, 3539, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (9762, 3, 4, 3539, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (9763, 1, 9, 3539, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9764, 1, 8, 3539, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9765, 3, 6, 3540, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (9766, 6, 11, 3540, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (9767, 10, 14, 3540, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (9768, 10, 13, 3540, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (9769, 6, 1, 3540, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (9770, 7, 3, 3540, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (9771, 8, 12, 3540, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (9772, 5, 4, 3540, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (9773, 1, 5, 3540, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (9774, 8, 7, 3540, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (9775, 7, 2, 3540, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (9776, 3, 10, 3540, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (9777, 1, 9, 3540, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9778, 1, 8, 3540, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9779, 7, 4, 3541, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (9780, 10, 6, 3541, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (9781, 10, 12, 3541, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (9782, 3, 2, 3541, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (9783, 3, 1, 3541, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (9784, 9, 5, 3541, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (9785, 4, 14, 3541, false, 9.9900, 39.9600);
INSERT INTO lignes_commande VALUES (9786, 3, 10, 3541, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (9787, 2, 11, 3541, false, 3.9900, 7.9800);
INSERT INTO lignes_commande VALUES (9788, 2, 13, 3541, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (9789, 2, 3, 3541, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (9790, 1, 9, 3541, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9791, 1, 8, 3541, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9792, 10, 1, 3542, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (9793, 1, 12, 3542, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (9794, 5, 10, 3542, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (9795, 6, 3, 3542, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (9796, 8, 5, 3542, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (9797, 9, 2, 3542, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (9798, 6, 4, 3542, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (9799, 6, 7, 3542, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (9800, 5, 14, 3542, false, 9.9900, 49.9500);
INSERT INTO lignes_commande VALUES (9801, 9, 6, 3542, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (9802, 4, 11, 3542, false, 3.9900, 15.9600);
INSERT INTO lignes_commande VALUES (9803, 6, 13, 3542, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (9804, 1, 8, 3542, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9805, 1, 9, 3542, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9806, 2, 14, 3543, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (9807, 9, 7, 3543, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (9808, 6, 13, 3543, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (9809, 1, 3, 3543, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (9810, 10, 6, 3544, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (9811, 2, 3, 3544, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (9812, 7, 14, 3544, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (9813, 1, 13, 3544, false, 7.9900, 7.9900);
INSERT INTO lignes_commande VALUES (9814, 3, 2, 3544, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (9815, 6, 4, 3544, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (9816, 3, 1, 3545, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (9817, 7, 3, 3545, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (9818, 3, 7, 3545, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (9819, 1, 2, 3545, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (9820, 10, 14, 3545, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (9821, 8, 6, 3545, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (9822, 10, 12, 3545, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (9823, 3, 10, 3545, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (9824, 1, 4, 3545, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (9825, 5, 11, 3545, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (9826, 6, 5, 3545, false, 5.7900, 34.7400);
INSERT INTO lignes_commande VALUES (9827, 3, 13, 3545, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (9828, 1, 8, 3545, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9829, 6, 6, 3546, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (9830, 10, 7, 3546, false, 6.4900, 64.9000);
INSERT INTO lignes_commande VALUES (9831, 10, 13, 3546, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (9832, 8, 3, 3546, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (9833, 6, 14, 3546, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (9834, 10, 11, 3546, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (9835, 1, 4, 3546, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (9836, 1, 5, 3546, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (9837, 10, 10, 3546, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (9838, 4, 12, 3546, false, 4.9900, 19.9600);
INSERT INTO lignes_commande VALUES (9839, 1, 2, 3546, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (9840, 6, 1, 3546, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (9841, 1, 9, 3546, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9842, 8, 12, 3547, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (9843, 1, 4, 3547, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (9844, 8, 11, 3547, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (9845, 7, 2, 3547, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (9846, 3, 5, 3547, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (9847, 9, 3, 3547, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (9848, 2, 14, 3547, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (9849, 9, 1, 3547, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (9850, 1, 7, 3547, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (9851, 6, 6, 3547, false, 1.2900, 7.7400);
INSERT INTO lignes_commande VALUES (9852, 10, 10, 3547, false, 2.9900, 29.9000);
INSERT INTO lignes_commande VALUES (9853, 5, 13, 3547, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (9854, 8, 14, 3548, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (9855, 8, 2, 3548, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (9856, 6, 3, 3548, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (9857, 8, 13, 3548, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (9858, 9, 5, 3548, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (9859, 7, 1, 3548, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (9860, 7, 11, 3548, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (9861, 2, 7, 3548, false, 6.4900, 12.9800);
INSERT INTO lignes_commande VALUES (9862, 7, 4, 3548, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (9863, 3, 10, 3548, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (9864, 7, 6, 3548, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (9865, 5, 12, 3548, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (9866, 8, 6, 3549, false, 1.2900, 10.3200);
INSERT INTO lignes_commande VALUES (9867, 2, 3, 3549, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (9868, 5, 13, 3549, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (9869, 10, 4, 3549, false, 0.9900, 9.9000);
INSERT INTO lignes_commande VALUES (9870, 1, 2, 3549, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (9871, 7, 10, 3549, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (9872, 9, 5, 3549, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (9873, 2, 14, 3549, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (9874, 3, 12, 3549, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (9875, 8, 11, 3549, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (9876, 6, 7, 3549, false, 6.4900, 38.9400);
INSERT INTO lignes_commande VALUES (9877, 3, 1, 3549, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (9878, 1, 9, 3549, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9879, 4, 7, 3550, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (9880, 9, 10, 3550, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (9881, 1, 6, 3550, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (9882, 2, 5, 3550, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (9883, 6, 4, 3550, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (9884, 1, 9, 3550, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9885, 1, 8, 3550, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9886, 7, 1, 3551, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (9887, 10, 2, 3551, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (9888, 7, 6, 3551, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (9889, 1, 5, 3551, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (9890, 8, 14, 3551, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (9891, 4, 4, 3551, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (9892, 3, 12, 3551, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (9893, 3, 7, 3551, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (9894, 3, 10, 3551, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (9895, 3, 3, 3551, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (9896, 10, 11, 3551, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (9897, 2, 13, 3551, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (9898, 1, 9, 3551, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9899, 5, 1, 3552, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (9900, 7, 12, 3552, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (9901, 9, 5, 3552, false, 5.7900, 52.1100);
INSERT INTO lignes_commande VALUES (9902, 8, 13, 3552, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (9903, 5, 10, 3552, false, 2.9900, 14.9500);
INSERT INTO lignes_commande VALUES (9904, 10, 2, 3552, false, 4.4900, 44.9000);
INSERT INTO lignes_commande VALUES (9905, 10, 3, 3552, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (9906, 7, 6, 3553, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (9907, 2, 10, 3553, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (9908, 9, 13, 3553, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (9909, 1, 8, 3553, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9910, 7, 10, 3555, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (9911, 5, 2, 3555, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (9912, 8, 5, 3555, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (9913, 8, 4, 3555, false, 0.9900, 7.9200);
INSERT INTO lignes_commande VALUES (9914, 3, 6, 3555, false, 1.2900, 3.8700);
INSERT INTO lignes_commande VALUES (9915, 7, 3, 3555, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (9916, 6, 2, 3556, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (9917, 10, 14, 3556, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (9918, 4, 5, 3556, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (9919, 6, 11, 3556, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (9920, 9, 12, 3556, false, 4.9900, 44.9100);
INSERT INTO lignes_commande VALUES (9921, 4, 7, 3556, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (9922, 2, 13, 3556, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (9923, 1, 4, 3556, false, 0.9900, 0.9900);
INSERT INTO lignes_commande VALUES (9924, 6, 1, 3556, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (9925, 9, 10, 3556, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (9926, 3, 3, 3556, false, 29.9900, 89.9700);
INSERT INTO lignes_commande VALUES (9927, 4, 6, 3556, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (9928, 1, 9, 3556, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9929, 1, 11, 3557, false, 3.9900, 3.9900);
INSERT INTO lignes_commande VALUES (9930, 4, 4, 3557, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (9931, 7, 13, 3557, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (9932, 4, 6, 3557, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (9933, 8, 10, 3557, false, 2.9900, 23.9200);
INSERT INTO lignes_commande VALUES (9934, 3, 1, 3557, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (9935, 9, 14, 3557, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (9936, 6, 3, 3557, false, 29.9900, 179.9400);
INSERT INTO lignes_commande VALUES (9937, 1, 7, 3557, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (9938, 2, 2, 3557, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (9939, 3, 5, 3557, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (9940, 3, 12, 3557, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (9941, 1, 9, 3557, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9942, 1, 8, 3557, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9943, 5, 6, 3558, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (9944, 10, 13, 3558, false, 7.9900, 79.9000);
INSERT INTO lignes_commande VALUES (9945, 2, 2, 3558, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (9946, 9, 14, 3558, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (9947, 8, 14, 3559, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (9948, 6, 12, 3559, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (9949, 4, 2, 3559, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (9950, 10, 3, 3559, false, 29.9900, 299.9000);
INSERT INTO lignes_commande VALUES (9951, 5, 1, 3559, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (9952, 4, 7, 3559, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (9953, 1, 8, 3559, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9954, 7, 6, 3560, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (9955, 5, 1, 3560, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (9956, 7, 14, 3560, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (9957, 10, 5, 3560, false, 5.7900, 57.9000);
INSERT INTO lignes_commande VALUES (9958, 8, 11, 3560, false, 3.9900, 31.9200);
INSERT INTO lignes_commande VALUES (9959, 6, 12, 3560, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (9960, 3, 13, 3560, false, 7.9900, 23.9700);
INSERT INTO lignes_commande VALUES (9961, 9, 10, 3560, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (9962, 1, 7, 3560, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (9963, 1, 9, 3560, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9964, 3, 5, 3561, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (9965, 9, 14, 3561, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (9966, 1, 9, 3561, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9967, 7, 5, 3562, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (9968, 3, 11, 3562, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (9969, 3, 1, 3562, false, 1.5400, 4.6200);
INSERT INTO lignes_commande VALUES (9970, 1, 14, 3562, false, 9.9900, 9.9900);
INSERT INTO lignes_commande VALUES (9971, 7, 2, 3562, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (9972, 4, 7, 3562, false, 6.4900, 25.9600);
INSERT INTO lignes_commande VALUES (9973, 8, 3, 3562, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (9974, 8, 13, 3562, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (9975, 8, 12, 3562, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (9976, 4, 6, 3562, false, 1.2900, 5.1600);
INSERT INTO lignes_commande VALUES (9977, 5, 4, 3562, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (9978, 3, 10, 3562, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (9979, 7, 11, 3563, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (9980, 3, 7, 3563, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (9981, 2, 3, 3563, false, 29.9900, 59.9800);
INSERT INTO lignes_commande VALUES (9982, 8, 5, 3563, false, 5.7900, 46.3200);
INSERT INTO lignes_commande VALUES (9983, 9, 1, 3563, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (9984, 4, 4, 3563, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (9985, 10, 6, 3563, false, 1.2900, 12.9000);
INSERT INTO lignes_commande VALUES (9986, 8, 2, 3563, false, 4.4900, 35.9200);
INSERT INTO lignes_commande VALUES (9987, 9, 10, 3563, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (9988, 2, 13, 3563, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (9989, 10, 12, 3563, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (9990, 2, 14, 3563, false, 9.9900, 19.9800);
INSERT INTO lignes_commande VALUES (9991, 1, 9, 3563, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9992, 1, 8, 3563, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (9993, 7, 13, 3564, false, 7.9900, 55.9300);
INSERT INTO lignes_commande VALUES (9994, 1, 7, 3564, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (9995, 6, 12, 3564, false, 4.9900, 29.9400);
INSERT INTO lignes_commande VALUES (9996, 1, 9, 3564, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (9997, 3, 2, 3565, false, 4.4900, 13.4700);
INSERT INTO lignes_commande VALUES (9998, 7, 3, 3565, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (9999, 8, 12, 3565, false, 4.9900, 39.9200);
INSERT INTO lignes_commande VALUES (10000, 6, 10, 3565, false, 2.9900, 17.9400);
INSERT INTO lignes_commande VALUES (10001, 6, 1, 3565, false, 1.5400, 9.2400);
INSERT INTO lignes_commande VALUES (10002, 5, 5, 3565, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (10003, 3, 14, 3565, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (10004, 5, 6, 3565, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (10005, 1, 7, 3565, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (10006, 5, 13, 3565, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (10007, 6, 4, 3565, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (10008, 1, 9, 3565, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (10009, 1, 8, 3565, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (10010, 9, 1, 3566, false, 1.5400, 13.8600);
INSERT INTO lignes_commande VALUES (10011, 1, 7, 3566, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (10012, 9, 13, 3566, false, 7.9900, 71.9100);
INSERT INTO lignes_commande VALUES (10013, 9, 2, 3566, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (10014, 7, 3, 3566, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (10015, 3, 11, 3566, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (10016, 1, 5, 3566, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (10017, 3, 12, 3566, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (10018, 4, 4, 3566, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (10019, 7, 14, 3566, false, 9.9900, 69.9300);
INSERT INTO lignes_commande VALUES (10020, 7, 6, 3566, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (10021, 1, 10, 3566, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (10022, 1, 9, 3566, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (10023, 1, 8, 3566, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (10024, 9, 6, 3567, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (10025, 2, 5, 3567, false, 5.7900, 11.5800);
INSERT INTO lignes_commande VALUES (10026, 1, 9, 3567, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (10027, 5, 12, 3568, false, 4.9900, 24.9500);
INSERT INTO lignes_commande VALUES (10028, 9, 2, 3568, false, 4.4900, 40.4100);
INSERT INTO lignes_commande VALUES (10029, 1, 9, 3569, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (10030, 1, 8, 3569, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (10031, 10, 14, 3570, false, 9.9900, 99.9000);
INSERT INTO lignes_commande VALUES (10032, 3, 7, 3570, false, 6.4900, 19.4700);
INSERT INTO lignes_commande VALUES (10033, 5, 3, 3570, false, 29.9900, 149.9500);
INSERT INTO lignes_commande VALUES (10034, 7, 11, 3570, false, 3.9900, 27.9300);
INSERT INTO lignes_commande VALUES (10035, 4, 2, 3570, false, 4.4900, 17.9600);
INSERT INTO lignes_commande VALUES (10036, 5, 13, 3570, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (10037, 10, 1, 3570, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (10038, 7, 5, 3570, false, 5.7900, 40.5300);
INSERT INTO lignes_commande VALUES (10039, 1, 6, 3570, false, 1.2900, 1.2900);
INSERT INTO lignes_commande VALUES (10040, 2, 12, 3570, false, 4.9900, 9.9800);
INSERT INTO lignes_commande VALUES (10041, 6, 4, 3570, false, 0.9900, 5.9400);
INSERT INTO lignes_commande VALUES (10042, 3, 10, 3570, false, 2.9900, 8.9700);
INSERT INTO lignes_commande VALUES (10043, 1, 8, 3570, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (10044, 1, 9, 3570, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (10045, 1, 5, 3571, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (10046, 9, 4, 3571, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (10047, 2, 1, 3571, false, 1.5400, 3.0800);
INSERT INTO lignes_commande VALUES (10048, 1, 10, 3571, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (10049, 9, 10, 3572, false, 2.9900, 26.9100);
INSERT INTO lignes_commande VALUES (10050, 9, 6, 3572, false, 1.2900, 11.6100);
INSERT INTO lignes_commande VALUES (10051, 7, 2, 3572, false, 4.4900, 31.4300);
INSERT INTO lignes_commande VALUES (10052, 8, 14, 3572, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (10053, 8, 7, 3572, false, 6.4900, 51.9200);
INSERT INTO lignes_commande VALUES (10054, 10, 12, 3572, false, 4.9900, 49.9000);
INSERT INTO lignes_commande VALUES (10055, 3, 5, 3572, false, 5.7900, 17.3700);
INSERT INTO lignes_commande VALUES (10056, 4, 3, 3572, false, 29.9900, 119.9600);
INSERT INTO lignes_commande VALUES (10057, 4, 4, 3572, false, 0.9900, 3.9600);
INSERT INTO lignes_commande VALUES (10058, 8, 13, 3572, false, 7.9900, 63.9200);
INSERT INTO lignes_commande VALUES (10059, 1, 8, 3572, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (10060, 1, 10, 3573, false, 2.9900, 2.9900);
INSERT INTO lignes_commande VALUES (10061, 3, 12, 3573, false, 4.9900, 14.9700);
INSERT INTO lignes_commande VALUES (10062, 3, 11, 3573, false, 3.9900, 11.9700);
INSERT INTO lignes_commande VALUES (10063, 9, 7, 3573, false, 6.4900, 58.4100);
INSERT INTO lignes_commande VALUES (10064, 8, 3, 3573, false, 29.9900, 239.9200);
INSERT INTO lignes_commande VALUES (10065, 6, 14, 3573, false, 9.9900, 59.9400);
INSERT INTO lignes_commande VALUES (10066, 9, 4, 3573, false, 0.9900, 8.9100);
INSERT INTO lignes_commande VALUES (10067, 6, 2, 3573, false, 4.4900, 26.9400);
INSERT INTO lignes_commande VALUES (10068, 8, 1, 3573, false, 1.5400, 12.3200);
INSERT INTO lignes_commande VALUES (10069, 1, 9, 3573, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (10070, 1, 8, 3573, true, -5.0000, -5.0000);
INSERT INTO lignes_commande VALUES (10071, 1, 5, 3574, false, 5.7900, 5.7900);
INSERT INTO lignes_commande VALUES (10072, 5, 1, 3574, false, 1.5400, 7.7000);
INSERT INTO lignes_commande VALUES (10073, 5, 13, 3574, false, 7.9900, 39.9500);
INSERT INTO lignes_commande VALUES (10074, 9, 14, 3574, false, 9.9900, 89.9100);
INSERT INTO lignes_commande VALUES (10075, 2, 6, 3574, false, 1.2900, 2.5800);
INSERT INTO lignes_commande VALUES (10076, 3, 4, 3574, false, 0.9900, 2.9700);
INSERT INTO lignes_commande VALUES (10077, 7, 10, 3574, false, 2.9900, 20.9300);
INSERT INTO lignes_commande VALUES (10078, 1, 7, 3574, false, 6.4900, 6.4900);
INSERT INTO lignes_commande VALUES (10079, 6, 11, 3574, false, 3.9900, 23.9400);
INSERT INTO lignes_commande VALUES (10080, 1, 2, 3575, false, 4.4900, 4.4900);
INSERT INTO lignes_commande VALUES (10081, 10, 11, 3575, false, 3.9900, 39.9000);
INSERT INTO lignes_commande VALUES (10082, 9, 3, 3575, false, 29.9900, 269.9100);
INSERT INTO lignes_commande VALUES (10083, 1, 1, 3575, false, 1.5400, 1.5400);
INSERT INTO lignes_commande VALUES (10084, 3, 14, 3575, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (10085, 6, 13, 3576, false, 7.9900, 47.9400);
INSERT INTO lignes_commande VALUES (10086, 5, 4, 3576, false, 0.9900, 4.9500);
INSERT INTO lignes_commande VALUES (10087, 7, 3, 3576, false, 29.9900, 209.9300);
INSERT INTO lignes_commande VALUES (10088, 1, 12, 3576, false, 4.9900, 4.9900);
INSERT INTO lignes_commande VALUES (10089, 4, 5, 3576, false, 5.7900, 23.1600);
INSERT INTO lignes_commande VALUES (10090, 5, 2, 3576, false, 4.4900, 22.4500);
INSERT INTO lignes_commande VALUES (10091, 7, 6, 3576, false, 1.2900, 9.0300);
INSERT INTO lignes_commande VALUES (10092, 5, 11, 3576, false, 3.9900, 19.9500);
INSERT INTO lignes_commande VALUES (10093, 10, 1, 3576, false, 1.5400, 15.4000);
INSERT INTO lignes_commande VALUES (10094, 2, 10, 3576, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (10095, 3, 14, 3576, false, 9.9900, 29.9700);
INSERT INTO lignes_commande VALUES (10096, 5, 7, 3577, false, 6.4900, 32.4500);
INSERT INTO lignes_commande VALUES (10097, 2, 13, 3577, false, 7.9900, 15.9800);
INSERT INTO lignes_commande VALUES (10098, 5, 5, 3577, false, 5.7900, 28.9500);
INSERT INTO lignes_commande VALUES (10099, 8, 14, 3577, false, 9.9900, 79.9200);
INSERT INTO lignes_commande VALUES (10100, 2, 10, 3577, false, 2.9900, 5.9800);
INSERT INTO lignes_commande VALUES (10101, 5, 6, 3577, false, 1.2900, 6.4500);
INSERT INTO lignes_commande VALUES (10102, 7, 1, 3577, false, 1.5400, 10.7800);
INSERT INTO lignes_commande VALUES (10103, 2, 2, 3577, false, 4.4900, 8.9800);
INSERT INTO lignes_commande VALUES (10104, 7, 12, 3577, false, 4.9900, 34.9300);
INSERT INTO lignes_commande VALUES (10105, 9, 11, 3577, false, 3.9900, 35.9100);
INSERT INTO lignes_commande VALUES (10106, 1, 3, 3577, false, 29.9900, 29.9900);
INSERT INTO lignes_commande VALUES (10107, 7, 4, 3577, false, 0.9900, 6.9300);
INSERT INTO lignes_commande VALUES (10108, 1, 9, 3577, true, -10.0000, -10.0000);
INSERT INTO lignes_commande VALUES (10109, 4, 1, 3578, false, 1.5400, 6.1600);


--
-- TOC entry 1999 (class 0 OID 21599)
-- Dependencies: 1579
-- Data for Name: produit; Type: TABLE DATA; Schema: app; Owner: formation_admin
--

INSERT INTO produit VALUES (8, 'Promotion Anniversaire', 'PRO01', true, true, -5.0000);
INSERT INTO produit VALUES (9, 'Promotion Spéciale', 'PRO02', NULL, true, -10.0000);
INSERT INTO produit VALUES (7, 'Agraphes par 500 T2', 'A2500', true, false, 6.4900);
INSERT INTO produit VALUES (6, 'Agraphes par 50 T2', 'A2050', true, false, 1.2900);
INSERT INTO produit VALUES (4, 'Agraphes par 50 T1', 'AG050', true, false, 0.9900);
INSERT INTO produit VALUES (3, 'Trombonnes par 5000', 'TR05K', true, false, 29.9900);
INSERT INTO produit VALUES (2, 'Trombonnes par 500', 'TR500', true, false, 4.4900);
INSERT INTO produit VALUES (1, 'Trombonnes par 100', 'TR100', true, false, 1.5400);
INSERT INTO produit VALUES (5, 'Agraphes par 500 T1', 'AG500', true, NULL, 5.7900);
INSERT INTO produit VALUES (10, 'Punaises Plates par 50', 'PU050', true, false, 2.9900);
INSERT INTO produit VALUES (11, 'Punaises Plates par 100', 'PU100', true, false, 3.9900);
INSERT INTO produit VALUES (14, 'Punaises Cartes par 100', 'PC100', true, false, 9.9900);
INSERT INTO produit VALUES (12, 'Punaises Cartes par 25', 'PC025', true, NULL, 4.9900);
INSERT INTO produit VALUES (13, 'Punaises Cartes par 50', 'PC050', true, NULL, 7.9900);


SET search_path = drh, pg_catalog;

--
-- TOC entry 1990 (class 0 OID 20449)
-- Dependencies: 1562
-- Data for Name: agences; Type: TABLE DATA; Schema: drh; Owner: formation_admin
--

INSERT INTO agences VALUES (4, 'AGENCE NATIONALE D''INTERIM', 'ANI', 0);
INSERT INTO agences VALUES (2, 'TRAVAILLER PLUS', 'TR+', 1080);
INSERT INTO agences VALUES (1, 'INTERIM & CO', 'INT', 830);
INSERT INTO agences VALUES (3, 'GAGNER PLUS', 'GA+', 1390);


--
-- TOC entry 1993 (class 0 OID 20473)
-- Dependencies: 1566
-- Data for Name: employes; Type: TABLE DATA; Schema: drh; Owner: formation_admin
--

INSERT INTO employes VALUES (35, 'Boszormenyi', 'Zoltan', '2011-10-22 12:18:43.075143', '2011-10-22 13:55:46.369912', true, 0, '00PA3-0035', '1961-02-01', 10, '2005-06-12', 'AU', 45258.7400);
INSERT INTO employes VALUES (36, 'Cave-Ayland ', 'Marc', '2011-10-22 12:18:59.354926', '2011-10-22 13:55:54.96985', true, 0, 'P0001-0036', '1963-05-05', 3, '2008-11-23', 'UK', 31256.2500);
INSERT INTO employes VALUES (38, 'Davis', 'Jeff', '2011-10-22 12:19:22.975192', '2011-10-22 13:56:07.146002', true, 0, '0DR02-0038', '1973-05-29', 5, '2003-05-05', 'US', 26584.1200);
INSERT INTO employes VALUES (39, 'Deckelmann', 'Selena', '2011-10-22 12:19:43.460912', '2011-10-22 13:56:14.457902', true, 0, 'D0001-0039', '1980-01-01', 4, '2003-05-05', 'US', 25986.5200);
INSERT INTO employes VALUES (40, 'Drake', 'Josua', '2011-10-22 12:19:57.949743', '2011-10-22 13:56:19.089978', true, 0, '0QA03-0040', '1982-09-06', 12, '2003-05-05', 'US', 29458.5200);
INSERT INTO employes VALUES (41, 'Dunstan', 'Andrew', '2011-10-22 12:20:15.405007', '2011-10-22 13:56:23.71378', true, 0, '0QA03-0041', '1968-05-12', 12, '2006-09-12', 'US', 41256.8500);
INSERT INTO employes VALUES (42, 'Fetter', 'David', '2011-10-22 12:20:27.526743', '2011-10-22 13:56:28.681739', true, 0, 'F0001-0042', '1969-06-25', 2, '2010-05-14', 'US', 42561.0000);
INSERT INTO employes VALUES (45, '斉藤', '博', '2011-10-22 12:21:50.621399', '2011-10-22 13:56:47.665793', true, 0, '0CO03-0045', '1981-06-25', 8, '2011-01-28', 'JP', 29563.2500);
INSERT INTO employes VALUES (14, 'Doe', 'Williams', '2011-10-19 19:25:37.518536', '2011-10-22 12:22:53.566103', true, 8705, 'F0001-0014', '1973-03-15', 2, '2008-06-06', 'FR', 54256.1200);
INSERT INTO employes VALUES (15, 'Dupont', 'Martine', '2011-10-19 19:26:11.614375', '2011-10-22 12:22:58.851547', true, 6080, 'P0001-0015', '1979-12-12', 3, '2002-03-29', 'FR', 25658.2500);
INSERT INTO employes VALUES (28, 'Berkush', 'Josh', '2011-10-22 12:10:16.784546', '2011-10-22 12:23:07.823272', true, 0, 'P0001-0028', '1982-08-12', 3, '2007-09-21', 'US', 22568.2500);
INSERT INTO employes VALUES (29, 'Eseintraut', 'Peter', '2011-10-22 12:10:57.859909', '2011-10-22 12:23:11.637215', true, 0, 'P0001-0029', '1972-05-25', 3, '2008-03-02', 'FI', 23526.2500);
INSERT INTO employes VALUES (30, 'Hagender', 'Magnus', '2011-10-22 12:12:27.686948', '2011-10-22 12:23:15.667189', true, 0, 'D0001-0030', '1979-06-29', 4, '2009-12-13', 'SW', 25658.8500);
INSERT INTO employes VALUES (43, 'Fontaine', 'Dimitri', '2011-10-22 12:20:46.733237', '2011-10-22 13:57:06.386254', true, 0, 'C0001-0043', '1983-12-12', 13, '2010-05-15', 'FR', 22568.1200);
INSERT INTO employes VALUES (44, 'Gündüz', 'Devrim', '2011-10-22 12:21:09.625923', '2011-10-22 13:57:38.369899', true, 0, 'C0001-0044', '1987-08-12', 13, '2010-05-18', 'TU', 22568.1200);
INSERT INTO employes VALUES (31, 'Lane', 'Tom', '2011-10-22 12:13:12.200697', '2011-10-22 12:24:38.281611', true, 0, '0DR02-0031', '1978-03-01', 5, '2006-09-11', 'US', 31589.2500);
INSERT INTO employes VALUES (32, 'Momjian', 'Bruce', '2011-10-22 12:13:32.05452', '2011-10-22 12:24:48.620373', true, 0, '0CP03-0032', '1989-09-25', 6, '2007-04-26', 'US', 35652.2500);
INSERT INTO employes VALUES (33, 'Page', 'Dave', '2011-10-22 12:13:47.319101', '2011-10-22 12:24:55.760698', true, 0, '0DR02-0033', '1981-11-12', 5, '2005-03-29', 'UK', 38596.2500);
INSERT INTO employes VALUES (37, 'Cramer', 'Dave', '2011-10-22 12:19:10.461494', '2011-10-22 13:57:57.657923', true, 0, '0CP03-0037', '1961-02-01', 6, '2002-09-26', 'CA', 27586.5400);
INSERT INTO employes VALUES (49, 'Doe', 'John', '2011-10-22 14:59:38.628635', '2011-10-22 17:22:40.371787', true, 0, '00PA3-0049', NULL, 10, '2011-10-22', NULL, 29854.2500);
INSERT INTO employes VALUES (34, 'Bartunov', 'Oleg', '2011-10-22 12:17:18.189704', '2011-10-22 13:55:41.705901', true, 0, 'P0001-0034', '1968-10-15', 3, '2004-03-03', 'RU', 39542.2500);
INSERT INTO employes VALUES (27, 'Cash', 'Johny', '2011-10-22 12:08:12.057929', '2011-10-23 11:29:10.213246', false, 0, 'P0001-0027', '1985-10-26', 3, '2011-01-12', 'FR', 24568.2500);
INSERT INTO employes VALUES (48, 'Ostrovitch', 'Vladimir', '2011-10-22 13:53:54.320972', '2011-10-23 15:12:42.143815', true, 0, '0TR02-0048', NULL, 7, '2010-10-22', 'RU', NULL);
INSERT INTO employes VALUES (13, 'Doe', 'John', '2011-10-19 19:24:41.734691', '2011-10-23 15:18:57.287738', true, 9825, 'D0001-0013', '1971-10-12', 4, '2001-04-12', 'FR', 58958.2500);


--
-- TOC entry 1995 (class 0 OID 20510)
-- Dependencies: 1570
-- Data for Name: employes_projet; Type: TABLE DATA; Schema: drh; Owner: formation_admin
--

INSERT INTO employes_projet VALUES (1, 13);
INSERT INTO employes_projet VALUES (1, 15);
INSERT INTO employes_projet VALUES (1, 34);
INSERT INTO employes_projet VALUES (1, 37);
INSERT INTO employes_projet VALUES (1, 38);
INSERT INTO employes_projet VALUES (1, 39);
INSERT INTO employes_projet VALUES (1, 40);
INSERT INTO employes_projet VALUES (2, 28);
INSERT INTO employes_projet VALUES (2, 29);
INSERT INTO employes_projet VALUES (2, 30);
INSERT INTO employes_projet VALUES (2, 31);
INSERT INTO employes_projet VALUES (2, 32);
INSERT INTO employes_projet VALUES (2, 33);
INSERT INTO employes_projet VALUES (2, 34);
INSERT INTO employes_projet VALUES (2, 35);
INSERT INTO employes_projet VALUES (2, 36);
INSERT INTO employes_projet VALUES (2, 37);
INSERT INTO employes_projet VALUES (2, 38);
INSERT INTO employes_projet VALUES (2, 39);
INSERT INTO employes_projet VALUES (2, 40);
INSERT INTO employes_projet VALUES (2, 42);
INSERT INTO employes_projet VALUES (2, 43);
INSERT INTO employes_projet VALUES (2, 44);
INSERT INTO employes_projet VALUES (2, 45);
INSERT INTO employes_projet VALUES (2, 48);
INSERT INTO employes_projet VALUES (3, 15);
INSERT INTO employes_projet VALUES (3, 30);
INSERT INTO employes_projet VALUES (3, 36);
INSERT INTO employes_projet VALUES (3, 41);
INSERT INTO employes_projet VALUES (3, 37);
INSERT INTO employes_projet VALUES (3, 31);
INSERT INTO employes_projet VALUES (4, 15);
INSERT INTO employes_projet VALUES (4, 30);
INSERT INTO employes_projet VALUES (4, 36);
INSERT INTO employes_projet VALUES (4, 41);
INSERT INTO employes_projet VALUES (4, 42);
INSERT INTO employes_projet VALUES (4, 43);
INSERT INTO employes_projet VALUES (4, 44);
INSERT INTO employes_projet VALUES (4, 48);
INSERT INTO employes_projet VALUES (3, 48);


--
-- TOC entry 1994 (class 0 OID 20491)
-- Dependencies: 1567
-- Data for Name: interimaires; Type: TABLE DATA; Schema: drh; Owner: formation_admin
--

INSERT INTO interimaires VALUES (16, 'Monk', 'Thelonius', '2011-10-19 19:28:06.36684', '2011-10-19 19:28:06.36684', true, 5505, 1, 15, 1, 15, 35.0000);
INSERT INTO interimaires VALUES (17, 'Parker', 'Charlie', '2011-10-20 09:57:23.259576', '2011-10-20 09:57:23.259576', true, 7840, 2, 5, 2, 5, 29.0000);
INSERT INTO interimaires VALUES (22, 'Reinhardt', 'Django', '2011-10-20 09:59:52.365789', '2011-10-20 09:59:52.365789', true, 6465, 3, 85, 4, 458, 35.4500);
INSERT INTO interimaires VALUES (24, 'Jackson', 'Mahalia', '2011-10-20 10:08:51.963194', '2011-10-20 10:08:51.963194', true, 9675, 1, 15, 6, 15, 45.3200);
INSERT INTO interimaires VALUES (25, 'Armstrong', 'Louis', '2011-10-20 10:09:24.387202', '2011-10-20 10:09:24.387202', true, 2260, 2, 26, 7, 426, 39.9900);
INSERT INTO interimaires VALUES (21, 'Davis', 'Miles', '2011-10-20 09:58:46.762352', '2011-10-20 09:58:46.762352', false, 6460, 3, 59, 3, 123, 29.2900);
INSERT INTO interimaires VALUES (23, 'Gillespsie', 'Dizzie', '2011-10-20 10:08:24.467249', '2011-10-20 10:08:24.467249', false, 7340, 2, 2, 5, 259, 29.0000);
INSERT INTO interimaires VALUES (26, 'Petrucianni', 'Michel', '2011-10-20 10:10:15.611359', '2011-10-20 10:10:15.611359', true, 10150, 3, 152, 8, 325, 27.2500);


--
-- TOC entry 1991 (class 0 OID 20454)
-- Dependencies: 1563
-- Data for Name: personnel; Type: TABLE DATA; Schema: drh; Owner: formation_admin
--

INSERT INTO personnel VALUES (46, 'Stosick', 'Tristan', '2011-10-22 13:51:47.048493', '2011-10-22 13:51:47.048493', true, 0);
INSERT INTO personnel VALUES (47, 'Leroy', 'Régis', '2011-10-22 13:52:16.049325', '2011-10-22 13:52:16.049325', true, 0);


--
-- TOC entry 1996 (class 0 OID 20515)
-- Dependencies: 1572
-- Data for Name: projet; Type: TABLE DATA; Schema: drh; Owner: formation_admin
--

INSERT INTO projet VALUES (2, 'Base de données');
INSERT INTO projet VALUES (4, 'Séminaire 2010');
INSERT INTO projet VALUES (1, 'Trombonnes 2004');
INSERT INTO projet VALUES (3, 'Séminaire 2009');
INSERT INTO projet VALUES (5, 'Séminaire 2011');


--
-- TOC entry 1992 (class 0 OID 20463)
-- Dependencies: 1564
-- Data for Name: services; Type: TABLE DATA; Schema: drh; Owner: formation_admin
--

INSERT INTO services VALUES (5, 'RH', '0DR02', 4, '2011-10-19 16:23:06.478274+02', '2011-10-19 16:23:30.726727+02', 0);
INSERT INTO services VALUES (8, 'Comité', '0CO03', 4, '2011-10-19 16:23:06.478274+02', '2011-10-19 16:23:30.726727+02', 0);
INSERT INTO services VALUES (9, 'Achats', '00AC2', 6, '2011-10-19 16:23:06.478274+02', '2011-10-19 16:23:30.726727+02', 0);
INSERT INTO services VALUES (10, 'Paye', '00PA3', 6, '2011-10-19 16:23:06.478274+02', '2011-10-19 16:23:30.726727+02', 0);
INSERT INTO services VALUES (11, 'Maintenance', '0MA02', 3, '2011-10-19 16:23:06.478274+02', '2011-10-19 16:23:30.726727+02', 0);
INSERT INTO services VALUES (12, 'Qualité', '0QA03', 3, '2011-10-19 16:23:06.478274+02', '2011-10-19 16:23:30.726727+02', 0);
INSERT INTO services VALUES (13, 'Commercial', 'C0001', 1, '2011-10-19 16:23:06.478274+02', '2011-10-19 17:55:43.037958+02', 0);
INSERT INTO services VALUES (1, 'Inconnu', 'X0000', 1, '2011-10-19 16:23:06.478274+02', '2011-10-19 17:55:43.037958+02', 0);
INSERT INTO services VALUES (6, 'Comptabilité', '0CP03', 2, '2011-10-19 16:23:06.478274+02', '2011-10-19 18:01:57.614285+02', 0);
INSERT INTO services VALUES (7, 'Trading', '0TR02', 2, '2011-10-19 16:23:06.478274+02', '2011-10-19 18:02:00.424357+02', 0);
INSERT INTO services VALUES (4, 'Direction', 'D0001', 1, '2011-10-19 16:23:06.478274+02', '2011-10-21 16:20:50.225659+02', 480);
INSERT INTO services VALUES (3, 'Production', 'P0001', 1, '2011-10-19 16:23:06.478274+02', '2011-10-21 16:20:50.716864+02', 430);
INSERT INTO services VALUES (2, 'Finances', 'F0001', 1, '2011-10-19 17:56:42.598624+02', '2011-10-21 16:20:51.961172+02', 490);


SET search_path = app, pg_catalog;

--
-- TOC entry 1962 (class 2606 OID 21627)
-- Dependencies: 1575 1575
-- Name: commandes_PRIMARY_KEY; Type: CONSTRAINT; Schema: app; Owner: formation_admin; Tablespace: 
--

ALTER TABLE ONLY commandes
    ADD CONSTRAINT "commandes_PRIMARY_KEY" PRIMARY KEY (com_id);


--
-- TOC entry 1965 (class 2606 OID 21629)
-- Dependencies: 1577 1577
-- Name: ligne_commande_PRIMARY_KEY; Type: CONSTRAINT; Schema: app; Owner: formation_admin; Tablespace: 
--

ALTER TABLE ONLY lignes_commande
    ADD CONSTRAINT "ligne_commande_PRIMARY_KEY" PRIMARY KEY (lic_id);


--
-- TOC entry 1967 (class 2606 OID 21631)
-- Dependencies: 1579 1579
-- Name: produit_PRIMARY_KEY; Type: CONSTRAINT; Schema: app; Owner: formation_admin; Tablespace: 
--

ALTER TABLE ONLY produit
    ADD CONSTRAINT "produit_PRIMARY_KEY" PRIMARY KEY (pro_id);


SET search_path = drh, pg_catalog;

--
-- TOC entry 1937 (class 2606 OID 20530)
-- Dependencies: 1562 1562
-- Name: agence_code_UNIQUE; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace: 
--

ALTER TABLE ONLY agences
    ADD CONSTRAINT "agence_code_UNIQUE" UNIQUE (age_code);


--
-- TOC entry 1939 (class 2606 OID 20532)
-- Dependencies: 1562 1562
-- Name: agences_PRIMARY_KEY; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace: 
--

ALTER TABLE ONLY agences
    ADD CONSTRAINT "agences_PRIMARY_KEY" PRIMARY KEY (age_id);


--
-- TOC entry 1941 (class 2606 OID 20534)
-- Dependencies: 1563 1563
-- Name: employes_PRIMARY_KEY; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace: 
--

ALTER TABLE ONLY personnel
    ADD CONSTRAINT "employes_PRIMARY_KEY" PRIMARY KEY (per_id);


--
-- TOC entry 1954 (class 2606 OID 20536)
-- Dependencies: 1570 1570 1570
-- Name: employes_projet_PRIMARY_KEY; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace: 
--

ALTER TABLE ONLY employes_projet
    ADD CONSTRAINT "employes_projet_PRIMARY_KEY" PRIMARY KEY (pro_id, emp_id);


--
-- TOC entry 1946 (class 2606 OID 20538)
-- Dependencies: 1566 1566
-- Name: emplyes_personnel_PRIMARY_KEY; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace: 
--

ALTER TABLE ONLY employes
    ADD CONSTRAINT "emplyes_personnel_PRIMARY_KEY" PRIMARY KEY (per_id);


--
-- TOC entry 1950 (class 2606 OID 20540)
-- Dependencies: 1567 1567
-- Name: interim_employes_PRIMARY_KEY; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace: 
--

ALTER TABLE ONLY interimaires
    ADD CONSTRAINT "interim_employes_PRIMARY_KEY" PRIMARY KEY (per_id);


--
-- TOC entry 1952 (class 2606 OID 20542)
-- Dependencies: 1567 1567
-- Name: interim_unique_int_id; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace: 
--

ALTER TABLE ONLY interimaires
    ADD CONSTRAINT interim_unique_int_id UNIQUE (int_id);


--
-- TOC entry 1958 (class 2606 OID 20544)
-- Dependencies: 1572 1572
-- Name: projet_PRIMARY_KEY; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace: 
--

ALTER TABLE ONLY projet
    ADD CONSTRAINT "projet_PRIMARY_KEY" PRIMARY KEY (pro_id);


--
-- TOC entry 1960 (class 2606 OID 20546)
-- Dependencies: 1572 1572
-- Name: projet_nom_UNIQUE; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace: 
--

ALTER TABLE ONLY projet
    ADD CONSTRAINT "projet_nom_UNIQUE" UNIQUE (pro_nom) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 1944 (class 2606 OID 20549)
-- Dependencies: 1564 1564
-- Name: service_PRIMARY_KEY; Type: CONSTRAINT; Schema: drh; Owner: formation_admin; Tablespace: 
--

ALTER TABLE ONLY services
    ADD CONSTRAINT "service_PRIMARY_KEY" PRIMARY KEY (ser_id);


SET search_path = app, pg_catalog;

--
-- TOC entry 1963 (class 1259 OID 21632)
-- Dependencies: 1577
-- Name: fki_ligne_commande_appartient_a_commande_FK; Type: INDEX; Schema: app; Owner: formation_admin; Tablespace: 
--

CREATE INDEX "fki_ligne_commande_appartient_a_commande_FK" ON lignes_commande USING btree (com_id);


SET search_path = drh, pg_catalog;

--
-- TOC entry 1947 (class 1259 OID 20550)
-- Dependencies: 1566
-- Name: fki_EMPLOYE_POUR_UN_SERVICE_FK; Type: INDEX; Schema: drh; Owner: formation_admin; Tablespace: 
--

CREATE INDEX "fki_EMPLOYE_POUR_UN_SERVICE_FK" ON employes USING btree (ser_id);


--
-- TOC entry 1955 (class 1259 OID 20551)
-- Dependencies: 1570
-- Name: fki_employes_projet_EMPLOYES_FK; Type: INDEX; Schema: drh; Owner: formation_admin; Tablespace: 
--

CREATE INDEX "fki_employes_projet_EMPLOYES_FK" ON employes_projet USING btree (emp_id);


--
-- TOC entry 1956 (class 1259 OID 20552)
-- Dependencies: 1570
-- Name: fki_employes_projet_PROJET_FK; Type: INDEX; Schema: drh; Owner: formation_admin; Tablespace: 
--

CREATE INDEX "fki_employes_projet_PROJET_FK" ON employes_projet USING btree (pro_id);


--
-- TOC entry 1948 (class 1259 OID 20553)
-- Dependencies: 1567
-- Name: fki_interimaires_agence_interim_FK; Type: INDEX; Schema: drh; Owner: formation_admin; Tablespace: 
--

CREATE INDEX "fki_interimaires_agence_interim_FK" ON interimaires USING btree (age_id);


--
-- TOC entry 1942 (class 1259 OID 20554)
-- Dependencies: 1563 1563 1563
-- Name: personnel_Actif_nom_prenom_IDX; Type: INDEX; Schema: drh; Owner: formation_admin; Tablespace: 
--

CREATE INDEX "personnel_Actif_nom_prenom_IDX" ON personnel USING btree (per_actif, per_nom, per_prenom);


SET search_path = app, pg_catalog;

--
-- TOC entry 1676 (class 2618 OID 21633)
-- Dependencies: 1582 1582 1582
-- Name: _vue_drh_points_upd_protect; Type: RULE; Schema: app; Owner: formation_admin
--

CREATE RULE _vue_drh_points_upd_protect AS ON UPDATE TO vue_drh_points DO INSTEAD NOTHING;


--
-- TOC entry 1677 (class 2618 OID 21634)
-- Dependencies: 1582 1582 1582 1582 1582 1562 1582
-- Name: vue_drh_points_agences; Type: RULE; Schema: app; Owner: formation_admin
--

CREATE RULE vue_drh_points_agences AS ON UPDATE TO vue_drh_points WHERE ((new.points <> old.points) AND (new.entity = 'agences'::text)) DO INSTEAD UPDATE drh.agences SET age_points = new.points WHERE (agences.age_id = old.id);


--
-- TOC entry 1678 (class 2618 OID 21635)
-- Dependencies: 1582 1582 1582
-- Name: vue_drh_points_del_protection; Type: RULE; Schema: app; Owner: formation_admin
--

CREATE RULE vue_drh_points_del_protection AS ON DELETE TO vue_drh_points DO INSTEAD NOTHING;


--
-- TOC entry 1679 (class 2618 OID 21636)
-- Dependencies: 1582 1582 1582
-- Name: vue_drh_points_ins_protection; Type: RULE; Schema: app; Owner: formation_admin
--

CREATE RULE vue_drh_points_ins_protection AS ON INSERT TO vue_drh_points DO INSTEAD NOTHING;


--
-- TOC entry 1680 (class 2618 OID 21637)
-- Dependencies: 1582 1582 1582 1582 1582 1563 1582
-- Name: vue_drh_points_personnels; Type: RULE; Schema: app; Owner: formation_admin
--

CREATE RULE vue_drh_points_personnels AS ON UPDATE TO vue_drh_points WHERE ((new.points <> old.points) AND (new.entity = 'personnels'::text)) DO INSTEAD UPDATE drh.personnel SET per_points = new.points WHERE (personnel.per_id = old.id);


--
-- TOC entry 1681 (class 2618 OID 21638)
-- Dependencies: 1582 1582 1582 1582 1582 1564 1582
-- Name: vue_drh_points_services; Type: RULE; Schema: app; Owner: formation_admin
--

CREATE RULE vue_drh_points_services AS ON UPDATE TO vue_drh_points WHERE ((new.points <> old.points) AND (new.entity = 'services'::text)) DO INSTEAD UPDATE drh.services SET ser_points = new.points WHERE (services.ser_id = old.id);


--
-- TOC entry 1979 (class 2620 OID 21639)
-- Dependencies: 1575 27
-- Name: TRIGGER_COMMANDES_AFTER_INSERT_COMPUTE_PERSONNEL_POINTS; Type: TRIGGER; Schema: app; Owner: formation_admin
--

CREATE TRIGGER "TRIGGER_COMMANDES_AFTER_INSERT_COMPUTE_PERSONNEL_POINTS" AFTER INSERT ON commandes FOR EACH ROW EXECUTE PROCEDURE repercute_points_to_personnel_and_service();


--
-- TOC entry 1980 (class 2620 OID 21640)
-- Dependencies: 1575 1575 1575 27
-- Name: TRIGGER_COMMANDES_AFTER_UPDATE_REATTRIBUTES_POINTS; Type: TRIGGER; Schema: app; Owner: formation_admin
--

CREATE TRIGGER "TRIGGER_COMMANDES_AFTER_UPDATE_REATTRIBUTES_POINTS" AFTER UPDATE ON commandes FOR EACH ROW WHEN (((new.com_points <> old.com_points) OR (new.per_id <> old.per_id))) EXECUTE PROCEDURE repercute_points_to_personnel_and_service();


--
-- TOC entry 1981 (class 2620 OID 21641)
-- Dependencies: 1575 27
-- Name: TRIGGER_COMMANDE_AFTER_DELETE_RECOMPUTE_POINTS; Type: TRIGGER; Schema: app; Owner: formation_admin
--

CREATE TRIGGER "TRIGGER_COMMANDE_AFTER_DELETE_RECOMPUTE_POINTS" AFTER DELETE ON commandes FOR EACH ROW EXECUTE PROCEDURE repercute_points_to_personnel_and_service();


--
-- TOC entry 1982 (class 2620 OID 21642)
-- Dependencies: 1575 22
-- Name: TRIGGER_COMMANDE_BEFORE_INSERT_COMPUTE_POINTS; Type: TRIGGER; Schema: app; Owner: formation_admin
--

CREATE TRIGGER "TRIGGER_COMMANDE_BEFORE_INSERT_COMPUTE_POINTS" BEFORE INSERT ON commandes FOR EACH ROW EXECUTE PROCEDURE commande_points();


--
-- TOC entry 1983 (class 2620 OID 21643)
-- Dependencies: 1575 1575 22
-- Name: TRIGGER_COMMANDE_BEFORE_UPDATE_RECOMPUTE_POINTS; Type: TRIGGER; Schema: app; Owner: formation_admin
--

CREATE TRIGGER "TRIGGER_COMMANDE_BEFORE_UPDATE_RECOMPUTE_POINTS" BEFORE UPDATE ON commandes FOR EACH ROW WHEN ((new.com_total_ht <> old.com_total_ht)) EXECUTE PROCEDURE commande_points();


--
-- TOC entry 1984 (class 2620 OID 21644)
-- Dependencies: 1577 32
-- Name: TRIGGER_LIGNE_COMMANDE_AFTER_DELETE_RECOMPUTE_TOTAL_COMMANDE; Type: TRIGGER; Schema: app; Owner: formation_admin
--

CREATE TRIGGER "TRIGGER_LIGNE_COMMANDE_AFTER_DELETE_RECOMPUTE_TOTAL_COMMANDE" AFTER DELETE ON lignes_commande FOR EACH ROW EXECUTE PROCEDURE total_commande_triggers();


--
-- TOC entry 1985 (class 2620 OID 21645)
-- Dependencies: 1577 32
-- Name: TRIGGER_LIGNE_COMMANDE_AFTER_INSERT_COMPUTE_TOTAL_COMMANDE; Type: TRIGGER; Schema: app; Owner: formation_admin
--

CREATE TRIGGER "TRIGGER_LIGNE_COMMANDE_AFTER_INSERT_COMPUTE_TOTAL_COMMANDE" AFTER INSERT ON lignes_commande FOR EACH ROW EXECUTE PROCEDURE total_commande_triggers();


--
-- TOC entry 1986 (class 2620 OID 21646)
-- Dependencies: 1577 1577 32
-- Name: TRIGGER_LIGNE_COMMANDE_AFTER_UPDATE_RECOMPUTE_TOTAL_COMMANDE; Type: TRIGGER; Schema: app; Owner: formation_admin
--

CREATE TRIGGER "TRIGGER_LIGNE_COMMANDE_AFTER_UPDATE_RECOMPUTE_TOTAL_COMMANDE" AFTER UPDATE ON lignes_commande FOR EACH ROW WHEN ((new.lic_total <> old.lic_total)) EXECUTE PROCEDURE total_commande_triggers();


--
-- TOC entry 1987 (class 2620 OID 21647)
-- Dependencies: 1577 24
-- Name: TRIGGER_LIGNE_COMMANDE_BEFORE_INSERT_COMPUTE_TOTAL_LIGNE; Type: TRIGGER; Schema: app; Owner: formation_admin
--

CREATE TRIGGER "TRIGGER_LIGNE_COMMANDE_BEFORE_INSERT_COMPUTE_TOTAL_LIGNE" BEFORE INSERT ON lignes_commande FOR EACH ROW EXECUTE PROCEDURE ligne_commande_total();


--
-- TOC entry 1988 (class 2620 OID 21648)
-- Dependencies: 1577 28
-- Name: TRIGGER_LIGNE_COMMANDE_BEFORE_UPDATE_01_CHECKS; Type: TRIGGER; Schema: app; Owner: formation_admin
--

CREATE TRIGGER "TRIGGER_LIGNE_COMMANDE_BEFORE_UPDATE_01_CHECKS" BEFORE UPDATE ON lignes_commande FOR EACH ROW EXECUTE PROCEDURE verif_modifications_autorisees_sur_ligne_commande();


--
-- TOC entry 1989 (class 2620 OID 21649)
-- Dependencies: 1577 1577 1577 24
-- Name: TRIGGER_LIGNE_COMMANDE_BEFORE_UPDATE_02_RECOMPUTE_TOTAL_LIGNE; Type: TRIGGER; Schema: app; Owner: formation_admin
--

CREATE TRIGGER "TRIGGER_LIGNE_COMMANDE_BEFORE_UPDATE_02_RECOMPUTE_TOTAL_LIGNE" BEFORE UPDATE ON lignes_commande FOR EACH ROW WHEN (((new.lic_quantite <> old.lic_quantite) OR (new.lic_prix_unitaire <> old.lic_prix_unitaire))) EXECUTE PROCEDURE ligne_commande_total();


SET search_path = drh, pg_catalog;

--
-- TOC entry 1976 (class 2620 OID 20555)
-- Dependencies: 1566 20
-- Name: emp_insert_code; Type: TRIGGER; Schema: drh; Owner: formation_admin
--

CREATE TRIGGER emp_insert_code BEFORE INSERT ON employes FOR EACH ROW EXECUTE PROCEDURE handle_employe_code();


--
-- TOC entry 1977 (class 2620 OID 20556)
-- Dependencies: 1566 1566 1566 20
-- Name: emp_update_code; Type: TRIGGER; Schema: drh; Owner: formation_admin
--

CREATE TRIGGER emp_update_code BEFORE UPDATE ON employes FOR EACH ROW WHEN (((new.per_id <> old.per_id) OR (new.ser_id <> old.ser_id))) EXECUTE PROCEDURE handle_employe_code();


--
-- TOC entry 1978 (class 2620 OID 20557)
-- Dependencies: 1566 21
-- Name: emp_update_date_modification; Type: TRIGGER; Schema: drh; Owner: formation_admin
--

CREATE TRIGGER emp_update_date_modification BEFORE UPDATE ON employes FOR EACH ROW EXECUTE PROCEDURE public.update_datemodif_column();


--
-- TOC entry 1974 (class 2620 OID 20558)
-- Dependencies: 1564 1564 20
-- Name: ser_update_alter_emp_code; Type: TRIGGER; Schema: drh; Owner: formation_admin
--

CREATE TRIGGER ser_update_alter_emp_code BEFORE UPDATE ON services FOR EACH ROW WHEN (((new.ser_code)::text <> (old.ser_code)::text)) EXECUTE PROCEDURE handle_employe_code();


--
-- TOC entry 1975 (class 2620 OID 20559)
-- Dependencies: 1564 21
-- Name: ser_update_date_modification; Type: TRIGGER; Schema: drh; Owner: formation_admin
--

CREATE TRIGGER ser_update_date_modification BEFORE UPDATE ON services FOR EACH ROW EXECUTE PROCEDURE public.update_datemodif_column();


SET search_path = app, pg_catalog;

--
-- TOC entry 1973 (class 2606 OID 21650)
-- Dependencies: 1961 1575 1577
-- Name: ligne_commande_appartient_a_commande_FK; Type: FK CONSTRAINT; Schema: app; Owner: formation_admin
--

ALTER TABLE ONLY lignes_commande
    ADD CONSTRAINT "ligne_commande_appartient_a_commande_FK" FOREIGN KEY (com_id) REFERENCES commandes(com_id) ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


SET search_path = drh, pg_catalog;

--
-- TOC entry 1969 (class 2606 OID 20560)
-- Dependencies: 1943 1564 1566
-- Name: EMPLOYE_POUR_UN_SERVICE_FK; Type: FK CONSTRAINT; Schema: drh; Owner: formation_admin
--

ALTER TABLE ONLY employes
    ADD CONSTRAINT "EMPLOYE_POUR_UN_SERVICE_FK" FOREIGN KEY (ser_id) REFERENCES services(ser_id) ON UPDATE CASCADE ON DELETE SET DEFAULT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 1968 (class 2606 OID 20565)
-- Dependencies: 1943 1564 1564
-- Name: SERVICE_RELATION_PARENT; Type: FK CONSTRAINT; Schema: drh; Owner: formation_admin
--

ALTER TABLE ONLY services
    ADD CONSTRAINT "SERVICE_RELATION_PARENT" FOREIGN KEY (ser_parent) REFERENCES services(ser_id) ON UPDATE CASCADE ON DELETE SET DEFAULT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 1972 (class 2606 OID 20570)
-- Dependencies: 1945 1566 1570
-- Name: employes_projet_EMPLOYES_FK; Type: FK CONSTRAINT; Schema: drh; Owner: formation_admin
--

ALTER TABLE ONLY employes_projet
    ADD CONSTRAINT "employes_projet_EMPLOYES_FK" FOREIGN KEY (emp_id) REFERENCES employes(per_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 1971 (class 2606 OID 20575)
-- Dependencies: 1957 1572 1570
-- Name: employes_projet_PROJET_FK; Type: FK CONSTRAINT; Schema: drh; Owner: formation_admin
--

ALTER TABLE ONLY employes_projet
    ADD CONSTRAINT "employes_projet_PROJET_FK" FOREIGN KEY (pro_id) REFERENCES projet(pro_id);


--
-- TOC entry 1970 (class 2606 OID 20580)
-- Dependencies: 1938 1562 1567
-- Name: interimaires_agence_interim_FK; Type: FK CONSTRAINT; Schema: drh; Owner: formation_admin
--

ALTER TABLE ONLY interimaires
    ADD CONSTRAINT "interimaires_agence_interim_FK" FOREIGN KEY (age_id) REFERENCES agences(age_id) ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2003 (class 0 OID 0)
-- Dependencies: 6
-- Name: app; Type: ACL; Schema: -; Owner: formation_admin
--

REVOKE ALL ON SCHEMA app FROM PUBLIC;
REVOKE ALL ON SCHEMA app FROM formation_admin;
GRANT ALL ON SCHEMA app TO formation_admin;
GRANT USAGE ON SCHEMA app TO formation_app;


--
-- TOC entry 2004 (class 0 OID 0)
-- Dependencies: 7
-- Name: drh; Type: ACL; Schema: -; Owner: formation_admin
--

REVOKE ALL ON SCHEMA drh FROM PUBLIC;
REVOKE ALL ON SCHEMA drh FROM formation_admin;
GRANT ALL ON SCHEMA drh TO formation_admin;
GRANT USAGE ON SCHEMA drh TO formation_drh;


--
-- TOC entry 2006 (class 0 OID 0)
-- Dependencies: 8
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


SET search_path = app, pg_catalog;

--
-- TOC entry 2007 (class 0 OID 0)
-- Dependencies: 22
-- Name: commande_points(); Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON FUNCTION commande_points() FROM PUBLIC;
GRANT ALL ON FUNCTION commande_points() TO postgres;
GRANT ALL ON FUNCTION commande_points() TO formation_ecriture;
GRANT ALL ON FUNCTION commande_points() TO formation_lecture;
GRANT ALL ON FUNCTION commande_points() TO PUBLIC;


--
-- TOC entry 2008 (class 0 OID 0)
-- Dependencies: 24
-- Name: ligne_commande_total(); Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON FUNCTION ligne_commande_total() FROM PUBLIC;
GRANT ALL ON FUNCTION ligne_commande_total() TO postgres;
GRANT ALL ON FUNCTION ligne_commande_total() TO formation_ecriture;
GRANT ALL ON FUNCTION ligne_commande_total() TO formation_lecture;
GRANT ALL ON FUNCTION ligne_commande_total() TO PUBLIC;


--
-- TOC entry 2009 (class 0 OID 0)
-- Dependencies: 23
-- Name: perform_new_points_add(integer, integer); Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON FUNCTION perform_new_points_add(points integer, personel_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION perform_new_points_add(points integer, personel_id integer) TO postgres;
GRANT ALL ON FUNCTION perform_new_points_add(points integer, personel_id integer) TO formation_ecriture;
GRANT ALL ON FUNCTION perform_new_points_add(points integer, personel_id integer) TO formation_lecture;
GRANT ALL ON FUNCTION perform_new_points_add(points integer, personel_id integer) TO PUBLIC;


--
-- TOC entry 2010 (class 0 OID 0)
-- Dependencies: 25
-- Name: perform_old_points_removal(integer, integer); Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON FUNCTION perform_old_points_removal(points integer, personel_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION perform_old_points_removal(points integer, personel_id integer) TO postgres;
GRANT ALL ON FUNCTION perform_old_points_removal(points integer, personel_id integer) TO formation_ecriture;
GRANT ALL ON FUNCTION perform_old_points_removal(points integer, personel_id integer) TO formation_lecture;
GRANT ALL ON FUNCTION perform_old_points_removal(points integer, personel_id integer) TO PUBLIC;


--
-- TOC entry 2011 (class 0 OID 0)
-- Dependencies: 26
-- Name: points_from_amount(numeric); Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON FUNCTION points_from_amount(numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION points_from_amount(numeric) TO postgres;
GRANT ALL ON FUNCTION points_from_amount(numeric) TO formation_ecriture;
GRANT ALL ON FUNCTION points_from_amount(numeric) TO formation_lecture;
GRANT ALL ON FUNCTION points_from_amount(numeric) TO PUBLIC;


--
-- TOC entry 2012 (class 0 OID 0)
-- Dependencies: 27
-- Name: repercute_points_to_personnel_and_service(); Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON FUNCTION repercute_points_to_personnel_and_service() FROM PUBLIC;
GRANT ALL ON FUNCTION repercute_points_to_personnel_and_service() TO postgres;
GRANT ALL ON FUNCTION repercute_points_to_personnel_and_service() TO formation_ecriture;
GRANT ALL ON FUNCTION repercute_points_to_personnel_and_service() TO formation_lecture;
GRANT ALL ON FUNCTION repercute_points_to_personnel_and_service() TO PUBLIC;


--
-- TOC entry 2013 (class 0 OID 0)
-- Dependencies: 29
-- Name: sum_commande(integer); Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON FUNCTION sum_commande(integer) FROM PUBLIC;
GRANT ALL ON FUNCTION sum_commande(integer) TO postgres;
GRANT ALL ON FUNCTION sum_commande(integer) TO formation_ecriture;
GRANT ALL ON FUNCTION sum_commande(integer) TO formation_lecture;
GRANT ALL ON FUNCTION sum_commande(integer) TO PUBLIC;


--
-- TOC entry 2014 (class 0 OID 0)
-- Dependencies: 32
-- Name: total_commande_triggers(); Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON FUNCTION total_commande_triggers() FROM PUBLIC;
GRANT ALL ON FUNCTION total_commande_triggers() TO postgres;
GRANT ALL ON FUNCTION total_commande_triggers() TO formation_ecriture;
GRANT ALL ON FUNCTION total_commande_triggers() TO formation_lecture;
GRANT ALL ON FUNCTION total_commande_triggers() TO PUBLIC;


--
-- TOC entry 2015 (class 0 OID 0)
-- Dependencies: 31
-- Name: update_commande_amounts(numeric, integer); Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON FUNCTION update_commande_amounts(numeric, integer) FROM PUBLIC;
GRANT ALL ON FUNCTION update_commande_amounts(numeric, integer) TO postgres;
GRANT ALL ON FUNCTION update_commande_amounts(numeric, integer) TO formation_ecriture;
GRANT ALL ON FUNCTION update_commande_amounts(numeric, integer) TO formation_lecture;
GRANT ALL ON FUNCTION update_commande_amounts(numeric, integer) TO PUBLIC;


--
-- TOC entry 2016 (class 0 OID 0)
-- Dependencies: 30
-- Name: update_points_vue_drh_tableau_personnel(integer, integer, text); Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON FUNCTION update_points_vue_drh_tableau_personnel(score integer, target_code integer, target_entity text) FROM PUBLIC;
GRANT ALL ON FUNCTION update_points_vue_drh_tableau_personnel(score integer, target_code integer, target_entity text) TO postgres;
GRANT ALL ON FUNCTION update_points_vue_drh_tableau_personnel(score integer, target_code integer, target_entity text) TO formation_ecriture;
GRANT ALL ON FUNCTION update_points_vue_drh_tableau_personnel(score integer, target_code integer, target_entity text) TO formation_lecture;
GRANT ALL ON FUNCTION update_points_vue_drh_tableau_personnel(score integer, target_code integer, target_entity text) TO PUBLIC;


--
-- TOC entry 2017 (class 0 OID 0)
-- Dependencies: 28
-- Name: verif_modifications_autorisees_sur_ligne_commande(); Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON FUNCTION verif_modifications_autorisees_sur_ligne_commande() FROM PUBLIC;
GRANT ALL ON FUNCTION verif_modifications_autorisees_sur_ligne_commande() TO postgres;
GRANT ALL ON FUNCTION verif_modifications_autorisees_sur_ligne_commande() TO formation_ecriture;
GRANT ALL ON FUNCTION verif_modifications_autorisees_sur_ligne_commande() TO formation_lecture;
GRANT ALL ON FUNCTION verif_modifications_autorisees_sur_ligne_commande() TO PUBLIC;


SET search_path = drh, pg_catalog;

--
-- TOC entry 2018 (class 0 OID 0)
-- Dependencies: 20
-- Name: handle_employe_code(); Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON FUNCTION handle_employe_code() FROM PUBLIC;
GRANT ALL ON FUNCTION handle_employe_code() TO postgres;
GRANT ALL ON FUNCTION handle_employe_code() TO formation_ecriture;
GRANT ALL ON FUNCTION handle_employe_code() TO formation_lecture;
GRANT ALL ON FUNCTION handle_employe_code() TO PUBLIC;


SET search_path = public, pg_catalog;

--
-- TOC entry 2019 (class 0 OID 0)
-- Dependencies: 21
-- Name: update_datemodif_column(); Type: ACL; Schema: public; Owner: formation_admin
--

REVOKE ALL ON FUNCTION update_datemodif_column() FROM PUBLIC;
GRANT ALL ON FUNCTION update_datemodif_column() TO formation_ecriture;
GRANT ALL ON FUNCTION update_datemodif_column() TO formation_lecture;
GRANT ALL ON FUNCTION update_datemodif_column() TO postgres;
GRANT ALL ON FUNCTION update_datemodif_column() TO PUBLIC;


SET search_path = app, pg_catalog;

--
-- TOC entry 2022 (class 0 OID 0)
-- Dependencies: 1575
-- Name: commandes; Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON TABLE commandes FROM PUBLIC;
GRANT ALL ON TABLE commandes TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE commandes TO formation_ecriture;
GRANT SELECT ON TABLE commandes TO formation_lecture;


--
-- TOC entry 2025 (class 0 OID 0)
-- Dependencies: 1576
-- Name: commandes_com_id_seq; Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON SEQUENCE commandes_com_id_seq FROM PUBLIC;
GRANT ALL ON SEQUENCE commandes_com_id_seq TO postgres;
GRANT ALL ON SEQUENCE commandes_com_id_seq TO formation_ecriture;
GRANT SELECT,USAGE ON SEQUENCE commandes_com_id_seq TO formation_lecture;


--
-- TOC entry 2026 (class 0 OID 0)
-- Dependencies: 1577
-- Name: lignes_commande; Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON TABLE lignes_commande FROM PUBLIC;
GRANT ALL ON TABLE lignes_commande TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE lignes_commande TO formation_ecriture;
GRANT SELECT ON TABLE lignes_commande TO formation_lecture;


--
-- TOC entry 2029 (class 0 OID 0)
-- Dependencies: 1578
-- Name: lignes_commande_lic_id_seq; Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON SEQUENCE lignes_commande_lic_id_seq FROM PUBLIC;
GRANT ALL ON SEQUENCE lignes_commande_lic_id_seq TO postgres;
GRANT ALL ON SEQUENCE lignes_commande_lic_id_seq TO formation_ecriture;
GRANT SELECT,USAGE ON SEQUENCE lignes_commande_lic_id_seq TO formation_lecture;


--
-- TOC entry 2030 (class 0 OID 0)
-- Dependencies: 1579
-- Name: produit; Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON TABLE produit FROM PUBLIC;
GRANT ALL ON TABLE produit TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE produit TO formation_ecriture;
GRANT SELECT ON TABLE produit TO formation_lecture;


--
-- TOC entry 2033 (class 0 OID 0)
-- Dependencies: 1580
-- Name: produit_pro_id_seq; Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON SEQUENCE produit_pro_id_seq FROM PUBLIC;
GRANT ALL ON SEQUENCE produit_pro_id_seq TO postgres;
GRANT ALL ON SEQUENCE produit_pro_id_seq TO formation_ecriture;
GRANT SELECT,USAGE ON SEQUENCE produit_pro_id_seq TO formation_lecture;


SET search_path = drh, pg_catalog;

--
-- TOC entry 2035 (class 0 OID 0)
-- Dependencies: 1562
-- Name: agences; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE agences FROM PUBLIC;
GRANT ALL ON TABLE agences TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE agences TO formation_ecriture;
GRANT SELECT ON TABLE agences TO formation_lecture;


SET search_path = app, pg_catalog;

--
-- TOC entry 2036 (class 0 OID 0)
-- Dependencies: 1581
-- Name: vue_drh_agences; Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON TABLE vue_drh_agences FROM PUBLIC;
GRANT ALL ON TABLE vue_drh_agences TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE vue_drh_agences TO formation_ecriture;
GRANT SELECT ON TABLE vue_drh_agences TO formation_lecture;


SET search_path = drh, pg_catalog;

--
-- TOC entry 2037 (class 0 OID 0)
-- Dependencies: 1563
-- Name: personnel; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE personnel FROM PUBLIC;
GRANT ALL ON TABLE personnel TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE personnel TO formation_ecriture;
GRANT SELECT ON TABLE personnel TO formation_lecture;


--
-- TOC entry 2038 (class 0 OID 0)
-- Dependencies: 1564
-- Name: services; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE services FROM PUBLIC;
GRANT ALL ON TABLE services TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE services TO formation_ecriture;
GRANT SELECT ON TABLE services TO formation_lecture;


SET search_path = app, pg_catalog;

--
-- TOC entry 2040 (class 0 OID 0)
-- Dependencies: 1582
-- Name: vue_drh_points; Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON TABLE vue_drh_points FROM PUBLIC;
GRANT ALL ON TABLE vue_drh_points TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE vue_drh_points TO formation_ecriture;
GRANT SELECT ON TABLE vue_drh_points TO formation_lecture;


--
-- TOC entry 2041 (class 0 OID 0)
-- Dependencies: 1583
-- Name: vue_drh_services; Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON TABLE vue_drh_services FROM PUBLIC;
GRANT ALL ON TABLE vue_drh_services TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE vue_drh_services TO formation_ecriture;
GRANT SELECT ON TABLE vue_drh_services TO formation_lecture;


SET search_path = drh, pg_catalog;

--
-- TOC entry 2044 (class 0 OID 0)
-- Dependencies: 1565
-- Name: employes_emp_id_seq; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON SEQUENCE employes_emp_id_seq FROM PUBLIC;
GRANT ALL ON SEQUENCE employes_emp_id_seq TO postgres;
GRANT ALL ON SEQUENCE employes_emp_id_seq TO formation_ecriture;
GRANT SELECT,USAGE ON SEQUENCE employes_emp_id_seq TO formation_lecture;


--
-- TOC entry 2045 (class 0 OID 0)
-- Dependencies: 1566
-- Name: employes; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE employes FROM PUBLIC;
GRANT ALL ON TABLE employes TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE employes TO formation_ecriture;
GRANT SELECT ON TABLE employes TO formation_lecture;


--
-- TOC entry 2046 (class 0 OID 0)
-- Dependencies: 1567
-- Name: interimaires; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE interimaires FROM PUBLIC;
GRANT ALL ON TABLE interimaires TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE interimaires TO formation_ecriture;
GRANT SELECT ON TABLE interimaires TO formation_lecture;


--
-- TOC entry 2047 (class 0 OID 0)
-- Dependencies: 1568
-- Name: vue_tableau_personnel; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE vue_tableau_personnel FROM PUBLIC;
GRANT ALL ON TABLE vue_tableau_personnel TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE vue_tableau_personnel TO formation_ecriture;
GRANT SELECT ON TABLE vue_tableau_personnel TO formation_lecture;
GRANT ALL ON TABLE vue_tableau_personnel TO aicha;


SET search_path = app, pg_catalog;

--
-- TOC entry 2048 (class 0 OID 0)
-- Dependencies: 1584
-- Name: vue_drh_tableau_personnel; Type: ACL; Schema: app; Owner: formation_admin
--

REVOKE ALL ON TABLE vue_drh_tableau_personnel FROM PUBLIC;
GRANT ALL ON TABLE vue_drh_tableau_personnel TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE vue_drh_tableau_personnel TO formation_ecriture;
GRANT SELECT ON TABLE vue_drh_tableau_personnel TO formation_lecture;


SET search_path = drh, pg_catalog;

--
-- TOC entry 2051 (class 0 OID 0)
-- Dependencies: 1569
-- Name: agences_age_id_seq; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON SEQUENCE agences_age_id_seq FROM PUBLIC;
GRANT ALL ON SEQUENCE agences_age_id_seq TO postgres;
GRANT ALL ON SEQUENCE agences_age_id_seq TO formation_ecriture;
GRANT SELECT,USAGE ON SEQUENCE agences_age_id_seq TO formation_lecture;


--
-- TOC entry 2052 (class 0 OID 0)
-- Dependencies: 1570
-- Name: employes_projet; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE employes_projet FROM PUBLIC;
GRANT ALL ON TABLE employes_projet TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE employes_projet TO formation_ecriture;
GRANT SELECT ON TABLE employes_projet TO formation_lecture;


--
-- TOC entry 2055 (class 0 OID 0)
-- Dependencies: 1571
-- Name: interimaires_int_id_seq; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON SEQUENCE interimaires_int_id_seq FROM PUBLIC;
GRANT ALL ON SEQUENCE interimaires_int_id_seq TO postgres;
GRANT ALL ON SEQUENCE interimaires_int_id_seq TO formation_ecriture;
GRANT SELECT,USAGE ON SEQUENCE interimaires_int_id_seq TO formation_lecture;


--
-- TOC entry 2056 (class 0 OID 0)
-- Dependencies: 1572
-- Name: projet; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON TABLE projet FROM PUBLIC;
GRANT ALL ON TABLE projet TO postgres;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE projet TO formation_ecriture;
GRANT SELECT ON TABLE projet TO formation_lecture;


--
-- TOC entry 2059 (class 0 OID 0)
-- Dependencies: 1573
-- Name: projet_pro_id_seq; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON SEQUENCE projet_pro_id_seq FROM PUBLIC;
GRANT ALL ON SEQUENCE projet_pro_id_seq TO postgres;
GRANT ALL ON SEQUENCE projet_pro_id_seq TO formation_ecriture;
GRANT SELECT,USAGE ON SEQUENCE projet_pro_id_seq TO formation_lecture;


--
-- TOC entry 2062 (class 0 OID 0)
-- Dependencies: 1574
-- Name: services_ser_id_seq; Type: ACL; Schema: drh; Owner: formation_admin
--

REVOKE ALL ON SEQUENCE services_ser_id_seq FROM PUBLIC;
GRANT ALL ON SEQUENCE services_ser_id_seq TO postgres;
GRANT ALL ON SEQUENCE services_ser_id_seq TO formation_ecriture;
GRANT SELECT,USAGE ON SEQUENCE services_ser_id_seq TO formation_lecture;


--
-- TOC entry 1220 (class 826 OID 20387)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON SEQUENCES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON SEQUENCES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON SEQUENCES  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT SELECT,USAGE ON SEQUENCES  TO formation_lecture;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON SEQUENCES  TO formation_admin WITH GRANT OPTION;


--
-- TOC entry 1221 (class 826 OID 20388)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: -; Owner: formation_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin REVOKE ALL ON SEQUENCES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON SEQUENCES  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT SELECT,USAGE ON SEQUENCES  TO formation_lecture;


--
-- TOC entry 1222 (class 826 OID 20390)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON FUNCTIONS  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON FUNCTIONS  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON FUNCTIONS  TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON FUNCTIONS  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON FUNCTIONS  TO formation_lecture;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON FUNCTIONS  TO formation_admin WITH GRANT OPTION;


--
-- TOC entry 1223 (class 826 OID 20391)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: formation_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin REVOKE ALL ON FUNCTIONS  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON FUNCTIONS  TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON FUNCTIONS  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON FUNCTIONS  TO formation_lecture;


--
-- TOC entry 1224 (class 826 OID 20393)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON TABLES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON TABLES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLES  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT SELECT ON TABLES  TO formation_lecture;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES  TO formation_admin WITH GRANT OPTION;


--
-- TOC entry 1225 (class 826 OID 20394)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: -; Owner: formation_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin REVOKE ALL ON TABLES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLES  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT SELECT ON TABLES  TO formation_lecture;


-- Completed on 2011-10-29 21:17:03 CEST

--
-- PostgreSQL database dump complete
--

