PostgreSQL-formation-pratique [FR]
==================================

French PostgreSQL practical training.

Markdown landslide support (html slides), sql dumps, tests scripts, a complete training
support in creative commons.

LICENCE CREATIVE COMMONS - CC - BY - SA
=======================================
Cette oeuvre est mise à disposition sous licence Paternité – Partage dans les mêmes conditions
Pour voir une copie de cette licence, visitez http://creativecommons.org/licenses/by-sa/3.0/
ou écrivez à Creative Commons, 444 Castro Street, Suite 900, Mountain View, California, 94041, USA.

Installation
=============

Après avoir cloné le dépôt git vous disposez de quasiment tout ce qu'il faut.

Si vous voulez régénerer les supports html à partir des source markdown il faut
cependant installer Landslide. Ce programme est écrit en python et il est préférable
de passer par un virtualenv pour isoler l'installation des dépendances.

La première fois on commence donc par créer ce virtualenv (qui existe surement sous forme de package dans votre distribution).

    virtualenv /home/roger/venvs/formation-pg
    source /home/roger/venvs/formation-pg/bin/activate
    pip install landslide
    pip install watchdog

Les fois suivantes il suffira d'activer le virtualenv pour avoir le programme landslide disponible dans votre session.

    source /home/roger/venvs/formation-pg/bin/activate

## Génération

    source /home/roger/venvs/formation-pg/bin/activate
    landslide src/SupportCoursPostgreSQL.cfg
    landslide src/SupportCoursPostgreSQL1.cfg
    landslide src/SupportCoursPostgreSQL2.cfg
    landslide src/SupportCoursPostgreSQL3.cfg
    landslide src/SupportCoursPostgreSQL4.cfg

Les documents html sont générés dans le docssier `docs`.


## Raccourcis clavier sur les slides

- `h`: aide
- `flèche gauche` et `flèche droite` pour la navigation
- `t` Sommaire, les titres de slides sont des liens
- `ESC` Vue résumé des slides (Exposé)
- `n` activer ou désactiver l'affichage du numéro
- `b` passage en écran blanc
- `c` pour changer le contexte du slide courant (slides précédents et suivants)
- `e` pour que le slide remplisse l'espace disponible dans le body
- `S` affichage du lien vers les sources pour chaque slide


## Faire un VirtualHost Nginx

Vous pouvez aussi faire un virtualhost Apache/Nginx.

Un Virtualhost au sein d'un serveur web n'est pas nécessaire pour afficher le
html, il peut s'afficher en local. Mais un virtualhost peut être utile en formation
pour rendre les pages visibles sur le réseau local.

Je donne donc un exemple avec un VirtualHost par défaut, qui serait donc aussi
accessible par IP.

Pour Nginx:

    server {
        listen 0.0.0.0:80;
        server_name default_server;

        root /home/roger/git/PostgreSQL-formation-pratique/docs;

        index index.html;

        access_log /tmp/default-access.log;
        error_log /tmp/default-error.log;

        location / {
            try_files $uri $uri/ =404;
        }
        location /resources {
            alias /home/roger/git/PostgreSQL-formation-pratique/resources;
            autoindex on;
            location ~* \.sql$ {
                 types {
                    text/plain    sql;
                 }
            }

        }
    }

Assurez vous ensuite que les dossiers en question sont bien accessibles en lecture
au groupe utilisé par votre serveur web.

    chgrp -R www-data docs*
    chmod 2755 docs
    chgrp -R www-data resources*
    chmod 2755 resources
