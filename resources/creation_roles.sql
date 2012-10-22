--
-- Role creation script, run this as superuser postgres only
--

-- LICENCE CREATIVE COMMONS - CC - BY - SA
-- =======================================
-- Cette oeuvre est mise à disposition sous licence Paternité – Partage dans les mêmes conditions 
-- Pour voir une copie de cette licence, visitez http://creativecommons.org/licenses/by-sa/3.0/ 
-- ou écrivez à Creative Commons, 444 Castro Street, Suite 900, Mountain View, California, 94041, USA.

CREATE ROLE aicha LOGIN VALID UNTIL 'infinity';
CREATE ROLE martine LOGIN VALID UNTIL 'infinity';
CREATE ROLE dominique LOGIN VALID UNTIL 'infinity';
CREATE ROLE sebastien LOGIN VALID UNTIL 'infinity';
CREATE ROLE nicolas LOGIN VALID UNTIL 'infinity';
CREATE ROLE francois LOGIN VALID UNTIL 'infinity';

CREATE ROLE formation_admin VALID UNTIL 'infinity';
CREATE ROLE formation_ecriture VALID UNTIL 'infinity';
CREATE ROLE formation_lecture VALID UNTIL 'infinity';
CREATE ROLE formation_app VALID UNTIL 'infinity';
CREATE ROLE formation_drh VALID UNTIL 'infinity';

GRANT formation_admin TO aicha;
GRANT formation_drh TO nicolas;
GRANT formation_ecriture TO nicolas;
GRANT formation_drh TO francois;
GRANT formation_app TO francois;
GRANT formation_lecture TO sebastien;
GRANT formation_app TO sebastien;
GRANT formation_drh TO sebastien;
GRANT formation_lecture TO martine;
GRANT formation_app TO martine;
GRANT formation_lecture TO dominique;
GRANT formation_app TO dominique;
