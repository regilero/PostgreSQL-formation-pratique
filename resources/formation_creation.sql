-- LICENCE CREATIVE COMMONS - CC - BY - SA
-- =======================================
-- Cette oeuvre est mise à disposition sous licence Paternité – Partage dans les mêmes conditions
-- Pour voir une copie de cette licence, visitez http://creativecommons.org/licenses/by-sa/3.0/
-- ou écrivez à Creative Commons, 444 Castro Street, Suite 900, Mountain View, California, 94041, USA.
--
-- Adding default database creation and Database Grants
CREATE DATABASE formation
  WITH OWNER = formation_admin
       ENCODING = 'UTF8'
       TABLESPACE = pg_default
       LC_COLLATE = 'fr_FR.UTF-8'
       LC_CTYPE = 'fr_FR.UTF-8'
       CONNECTION LIMIT = -1;
ALTER ROLE ultrogothe IN DATABASE formation SET role='formation_admin';
GRANT CONNECT, TEMPORARY ON DATABASE formation TO public;
GRANT ALL ON DATABASE formation TO formation_admin WITH GRANT OPTION;
GRANT CONNECT, TEMPORARY ON DATABASE formation TO formation_ecriture;
GRANT CONNECT ON DATABASE formation TO formation_lecture;

