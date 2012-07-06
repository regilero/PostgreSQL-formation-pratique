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
-- Started on 2011-10-23 14:54:10 CEST

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- TOC entry 6 (class 2615 OID 17669)
-- Name: app; Type: SCHEMA; Schema: -; Owner: formation_admin
--

CREATE SCHEMA app;


ALTER SCHEMA app OWNER TO formation_admin;

--
-- TOC entry 7 (class 2615 OID 17670)
-- Name: drh; Type: SCHEMA; Schema: -; Owner: formation_admin
--

CREATE SCHEMA drh;


ALTER SCHEMA drh OWNER TO formation_admin;

--
-- TOC entry 365 (class 2612 OID 11574)
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: postgres
--

CREATE OR REPLACE PROCEDURAL LANGUAGE plpgsql;


ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO postgres;

--
-- TOC entry 1999 (class 0 OID 0)
-- Dependencies: 6
-- Name: app; Type: ACL; Schema: -; Owner: formation_admin
--

REVOKE ALL ON SCHEMA app FROM PUBLIC;
REVOKE ALL ON SCHEMA app FROM formation_admin;
GRANT ALL ON SCHEMA app TO formation_admin;
GRANT USAGE ON SCHEMA app TO formation_app;


--
-- TOC entry 2000 (class 0 OID 0)
-- Dependencies: 7
-- Name: drh; Type: ACL; Schema: -; Owner: formation_admin
--

REVOKE ALL ON SCHEMA drh FROM PUBLIC;
REVOKE ALL ON SCHEMA drh FROM formation_admin;
GRANT ALL ON SCHEMA drh TO formation_admin;
GRANT USAGE ON SCHEMA drh TO formation_drh;


--
-- TOC entry 2002 (class 0 OID 0)
-- Dependencies: 8
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- TOC entry 1221 (class 826 OID 17703)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON SEQUENCES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON SEQUENCES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON SEQUENCES  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT SELECT,USAGE ON SEQUENCES  TO formation_lecture;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON SEQUENCES  TO formation_admin WITH GRANT OPTION;


--
-- TOC entry 1222 (class 826 OID 17711)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: -; Owner: aicha
--

ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin REVOKE ALL ON SEQUENCES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin REVOKE ALL ON SEQUENCES  FROM formation_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON SEQUENCES  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT SELECT,USAGE ON SEQUENCES  TO formation_lecture;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON SEQUENCES  TO formation_admin WITH GRANT OPTION;


--
-- TOC entry 1223 (class 826 OID 17705)
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
-- TOC entry 1224 (class 826 OID 17712)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: aicha
--

ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin REVOKE ALL ON FUNCTIONS  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin REVOKE ALL ON FUNCTIONS  FROM formation_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON FUNCTIONS  TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON FUNCTIONS  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON FUNCTIONS  TO formation_lecture;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON FUNCTIONS  TO formation_admin WITH GRANT OPTION;


--
-- TOC entry 1225 (class 826 OID 17707)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON TABLES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON TABLES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLES  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT SELECT ON TABLES  TO formation_lecture;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES  TO formation_admin WITH GRANT OPTION;


--
-- TOC entry 1226 (class 826 OID 17713)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: -; Owner: aicha
--

ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin REVOKE ALL ON TABLES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin REVOKE ALL ON TABLES  FROM formation_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLES  TO formation_ecriture;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT SELECT ON TABLES  TO formation_lecture;
ALTER DEFAULT PRIVILEGES FOR ROLE formation_admin GRANT ALL ON TABLES  TO formation_admin WITH GRANT OPTION;


-- Completed on 2011-10-23 14:54:10 CEST

--
-- PostgreSQL database dump complete
--


