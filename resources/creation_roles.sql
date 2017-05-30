--
-- Role creation script, run this as superuser postgres only
--

-- LICENCE CREATIVE COMMONS - CC - BY - SA
-- =======================================
-- Cette oeuvre est mise à disposition sous licence Paternité – Partage dans les mêmes conditions
-- Pour voir une copie de cette licence, visitez http://creativecommons.org/licenses/by-sa/3.0/
-- ou écrivez à Creative Commons, 444 Castro Street, Suite 900, Mountain View, California, 94041, USA.

CREATE ROLE ultrogothe LOGIN VALID UNTIL 'infinity';
CREATE ROLE thibaut LOGIN VALID UNTIL 'infinity';
CREATE ROLE gondioque LOGIN VALID UNTIL 'infinity';
CREATE ROLE bertrude LOGIN VALID UNTIL 'infinity';
CREATE ROLE childeric LOGIN VALID UNTIL 'infinity';
CREATE ROLE nantilde LOGIN VALID UNTIL 'infinity';

CREATE ROLE formation_admin VALID UNTIL 'infinity';
CREATE ROLE formation_ecriture VALID UNTIL 'infinity';
CREATE ROLE formation_lecture VALID UNTIL 'infinity';
CREATE ROLE formation_app VALID UNTIL 'infinity';
CREATE ROLE formation_drh VALID UNTIL 'infinity';

GRANT formation_admin TO ultrogothe;
GRANT formation_drh TO childeric;
GRANT formation_ecriture TO childeric;
GRANT formation_drh TO nantilde;
GRANT formation_app TO nantilde;
GRANT formation_lecture TO bertrude;
GRANT formation_app TO bertrude;
GRANT formation_drh TO bertrude;
GRANT formation_lecture TO thibaut;
GRANT formation_app TO thibaut;
GRANT formation_lecture TO gondioque;
GRANT formation_app TO gondioque;
