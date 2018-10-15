--
-- PostgreSQL database dump
--
-- LICENCE CREATIVE COMMONS - CC - BY - SA
-- =======================================
-- Cette oeuvre est mise à disposition sous licence Paternité – Partage dans les mêmes conditions
-- Pour voir une copie de cette licence, visitez http://creativecommons.org/licenses/by-sa/3.0/
-- ou écrivez à Creative Commons, 444 Castro Street, Suite 900, Mountain View, California, 94041, USA.



-- Dumped from database version 9.6.1
-- Dumped by pg_dump version 9.6.1

-- Started on 2017-06-06 15:50:00 CEST

SET statement_timeout = 0;
SET lock_timeout = 0;
--SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 305620)
-- Name: app; Type: SCHEMA; Schema: -; Owner: formation_admin
--

CREATE SCHEMA app;


ALTER SCHEMA app OWNER TO formation_admin;

--
-- TOC entry 6 (class 2615 OID 305621)
-- Name: drh; Type: SCHEMA; Schema: -; Owner: formation_admin
--

CREATE SCHEMA drh;


ALTER SCHEMA drh OWNER TO formation_admin;

--
-- TOC entry 1 (class 3079 OID 12435)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 2174 (class 0 OID 0)
-- Dependencies: 1
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- TOC entry 2171 (class 0 OID 0)
-- Dependencies: 5
-- Name: app; Type: ACL; Schema: -; Owner: formation_admin
--

GRANT USAGE ON SCHEMA app TO formation_app;


--
-- TOC entry 2172 (class 0 OID 0)
-- Dependencies: 6
-- Name: drh; Type: ACL; Schema: -; Owner: formation_admin
--

GRANT USAGE ON SCHEMA drh TO formation_drh;


--
-- TOC entry 1649 (class 826 OID 305623)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON SEQUENCES  TO formation_admin WITH GRANT OPTION;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON SEQUENCES  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT SELECT,USAGE ON SEQUENCES  TO formation_lecture;


--
-- TOC entry 1650 (class 826 OID 305624)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: -; Owner: formation_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON SEQUENCES  TO formation_admin WITH GRANT OPTION;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON SEQUENCES  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT SELECT,USAGE ON SEQUENCES  TO formation_lecture;


--
-- TOC entry 1651 (class 826 OID 305626)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON FUNCTIONS  TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON FUNCTIONS  TO formation_admin WITH GRANT OPTION;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON FUNCTIONS  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON FUNCTIONS  TO formation_lecture;


--
-- TOC entry 1652 (class 826 OID 305627)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: formation_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON FUNCTIONS  TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON FUNCTIONS  TO formation_admin WITH GRANT OPTION;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON FUNCTIONS  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON FUNCTIONS  TO formation_lecture;


--
-- TOC entry 1653 (class 826 OID 305629)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES  TO formation_admin WITH GRANT OPTION;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLES  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT SELECT ON TABLES  TO formation_lecture;


--
-- TOC entry 1654 (class 826 OID 305630)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: -; Owner: formation_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON TABLES  TO formation_admin WITH GRANT OPTION;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLES  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT SELECT ON TABLES  TO formation_lecture;


-- Completed on 2017-06-06 15:50:02 CEST

--
-- PostgreSQL database dump complete
--

