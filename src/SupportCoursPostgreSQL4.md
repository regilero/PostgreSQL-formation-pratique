# Formation Pratique PostgreSQL - partie 4 - Administration

--------------------------------------------------------------------------------

copyright (c) 2012-2022 : [Makina Corpus](http://www.makina-corpus.com) Creative Commons CC-BY-SA

.fx: alternate

--------------------------------------------------------------------------------

# 20. Administration PostgreSQL

.fx: title1 title1-3

--------------------------------------------------------------------------------

## 20.1. Pré-requis

<small>Puis-je commencer ici?</small>

.fx: title2

--------------------------------------------------------------------------------

Les chapitres précédents contenaient des informations utiles aux administrateurs.

Ainsi on n'oubliera pas de consulter dans les chapitres précédents:

* la gestion du **pg_hba.conf** (politique d'accès)
* la gestion des **rôles** et des **droits**
* les backups en dumps **SQL** et **COMPRESS** ainsi que leurs **restaurations**
* **l'indexation**

--------------------------------------------------------------------------------

## 20.2. 32bits vs 64bits

PostgreSQL existe en version 32 ou 64 bits.

Vous pouvez très bien installer une version 32bits sur un OS 64 bits.

Les principaux gains d'une version 64 bits sont:

* une meilleure gestion des types longs, qui peuvent être utilisés dans des
 registres au lieu de passer par des pointeurs (entiers longs, types date)
* la possibilité d'utiliser plus de 2Go pour le paramètre shared_buffers dont
 on verra qu'il s'agit d'un des paramètres très important pour les performances,
 surtout avant la version 9.5.

Mais des coûts supplémentaires apparaissent aussi en parallèle sur tous les types
de base (la taille d'un pointeur en RAM augmente).

**Sur un Linux 64 bits on devrait toujours installer une version 64bits**.

Sur un serveur Windows la version 64bits est beaucoup moins intéressante car les
serveurs Windows supportent assez mal une valeur supérieure à **500Mo** pour le
paramètre `shared_buffers` (on perd donc le principal gain).

Certains utilisateurs ont rapporté des installations sur Windows avec des très
fortes valeures de `work_mem`, pour lesquelles une version 64bits était plus performante. Mais comme nous le verrons en étudiant ces deux paramètres
(`shared_buffers` et `work_mem`) il s'agit là d'installations atypiques.


--------------------------------------------------------------------------------

## 20.3. Analysez l'usage de la base

Les applications qui utilisent la base peuvent avoir des formes et des usages
divers. On identifie par exemple certaines grandes familles ainsi:

* **Type Web** : Taille des données tenant en RAM, beaucoup de requêtes simples,
 beaucoup de lectures.
* **OLTP (Online Transaction Processing)** :  Taille des données très importante
  (supérieure à la RAM), un nombre important d'opérations d'écritures (plus de
  20% des requêtes). Des transactions importantes (beaucoup d'écritures au sein
  d'une même transaction)
* **Data Warehouse, Business Intelligence** : taille des données très importante,
 requêtes d'agrégation complexes (BI), requêtes d'import/export de grandes
 quantités de données

Les différents conseils sur les performances attendues des données dépendront du
profil de la base. Si vos usages sont très différents et que vous hébergez
plusieurs bases peut-être devrez-vous songer à utiliser différents serveurs de
base de données.

--------------------------------------------------------------------------------

## 20.4. Autovacuum, vacuum et analyze

* [http://docs.postgresql.fr/11/maintenance.html](http://docs.postgresql.fr/11/maintenance.html)
* [http://docs.postgresql.fr/11/runtime-config-autovacuum.html](http://docs.postgresql.fr/11/runtime-config-autovacuum.html)

La page de documentation de PostgreSQL sur les opérations de maintenance est
assez complète.

Parmi les choses importantes il faut identifier **le service autovacuum.**

Il s'agit d'un des processus fils de PostgreSQL dont le travail est de détecter
les maintenance à effectuer et **de les faire au fil de l'eau**.

Parmi toutes les tâches de maintenance les plus importantes sont donc les
**VACUUM**. Le but du vacuum est **triple**:

* **optimiser l'espace disque** occupé par la base, le fichier physique stocke
  plusieurs versions des lignes, ce qui permet d'assurer le MVCC dans les
  transactions. Lors des vacuums les lignes qui ne sont plus valides seront
  recyclées.
* **Mettre à jour les statistiques** sur le nombre de lignes des tables ou les
  cardinalités des index. Ceci afin d'optimiser les choix fait par l'analyseur
  de requête (vaut-il mieux un *seqscan* ou utiliser un *index* ?)
* A **long terme** éviter d'avoir un problème de **cycle d'identifiant de
  transaction** (qui n'est pas un nombre infini)

.fx: wide

--------------------------------------------------------------------------------

### vacuum full

Il y a une forme extrême du **VACUUM** qui est **VACUUM FULL**.

Cette commande SQL provoque une sorte de réécriture complète de la table, une
réorganisation de toutes ces lignes. **C'est une opération longue et bloquante.**

Depuis la version 9.0 de PostgreSQL cette opération est plus rapide que sur les
 versions précédentes mais elle impose de **disposer de deux fois la taille
 physique de la table** (au moins les lignes actives), Si vous avez une table 2Go sur laquelle vous effectuez
 un `VACUUM FULL` une nouvelle table sera créé, il faut donc environ 2Go
 d'espace disque disponible. Cette opération pose un **LOCK exclusif** sur la
 table, elle est inaccessible pour PostgreSQL.

Heureusement il n'est pas nécessaire à priori d'effectuer des `VACUUM FULL`.

Les opérations VACUUM standard suffisent à obtenir des maintenances efficaces et
ne sont pas bloquantes, ni en lecture ni en écriture (le DDL est bloqué par
contre).

On n'utilisera le VACUUM FULL que sur une table qui **après des imports/exports
massifs** occupe visiblement une place trop importante. Sur un fonctionnement
normal de la base **l'exécution régulière de VACUUM classiques** permet de ne
pas avoir de gaspillage de place.

.fx: wide

--------------------------------------------------------------------------------

### autovacuum

<div class="warning"><p>
Le but d'autovacuumm est donc de tourner suffisamment souvent pour maintenir la
<b>taille physique des tables</b> et pour garantir que le <b>planificateur de
requête</b> dispose d'informations à jour.
</p></div>

Le démon autovacuum dispose **d'indicateurs**, de réglages, pour ces deux
fonctions (analysez et nettoyage) qui vont lui permettre de décider du moment
ou il devra agir.

Parallèlement il ne faut pas que les vacuum se lancent trop souvent car s'ils ne
sont pas bloquants ils sont cependant **consommateurs** en ressource serveur.

--------------------------------------------------------------------------------

### autovacuum par table

Il y a des paramètres généraux qui s'appliquent à toutes les tables mais
**on peut changer ce paramétrage pour une table** (disponible dans les
propriétés de la table sur pgadmin):

    # suspendre l'autovacuum pour une table
    ALTER TABLE mytable SET autovacuum_enabled = false;
    # le rétablir
    ALTER TABLE mytable SET autovacuum_enabled = true;
    # Mettre des réglages particuliers pour une table
    ALTER TABLE mytable SET (
      autovacuum_vacuum_threshold = 25,
      autovacuum_analyze_threshold = 15,
      autovacuum_vacuum_scale_factor = 0.1,
      autovacuum_analyze_scale_factor = 0.001,
      autovacuum_vacuum_cost_delay = 10,
      autovacuum_vacuum_cost_limit = 100
    );
    # lire les réglages (moins facile)
    select relname, reloptions
      from pg_class
      where relname = "nom de ma table";
    # lire les éléments décisifs
    SELECT
      n_tup_ins as "inserts",
      n_tup_upd as "updates",
      n_tup_del as "deletes",
      n_live_tup as "live_tuples",
      n_dead_tup as "dead_tuples"
    FROM pg_stat_user_tables
    WHERE schemaname = 'nom_du_schema' and relname = 'nom_de_la_table';

.fx: wide

--------------------------------------------------------------------------------

La documentation nous donne ces deux formules:

    limite du vacuum = limite de base du vacuum
                       + facteur d'échelle du vacuum * nombre de lignes
    limite du analyze = limite de base du analyze
                        + facteur d'échelle du analyze * nombre de lignes

Si on mets les vrais noms de variables et des parenthèses on obtient:

    limite du vacuum = autovacuum_vacuum_threshold
                       + (autovacuum_vacuum_scale_factor * nb lignes)
    limite du analyze = autovacuum_analyze_thresold
                       + (autovacuum_analyze_scale_factor * nb lignes)

* **autovacuum_vacuum_threshold** : Après que ce nombre de lignes mortes dans la
 table (dues à des **delete** ou **update**) soit atteint un vacuum sera lancé afin de
 récupérer de l'espace disque.
* **autovacuum_analyze_threshold** : Après avoir atteint, en gros, ce nombre
 d'**insert** ou **update** ou **delete** un vacuum analyze sera lancé afin de
 mettre à jour les statistiques utilisées par l'analyseur de requêtes.
<div class="warning"><p>
le nombre d'<b>inserts</b> n'est utile qu'à l'analyse, pas au ménage.
</p></div>


.fx: wide

--------------------------------------------------------------------------------

### autovacuum

Les `*_scale_factor` sont des pourcentages appliqués à la taille de la table et
vont ajouter des valeurs au « thresold » (seuil) original. **Donc une grosse table
(2 millions de lignes) avec un scale factor de 0.1 (10%) va ajouter 200 000 au
seuil**:

    limite du vacuum = 50 + (0.1 * 2 000 000) = 50 + 200 000 = 200 050

Les paramètres **cost** et **delay** servent à éviter de trop impacter le
 fonctionnement normal de la base en forçant des suspensions/reprises des tâches
d'autovacuum en cours de traitement quand celle-ci atteignent les coûts indiqués.

Ces réglages ne sont à modifier que si vous observez des ralentissements
généraux dus aux vacuums de certains tables importantes.

.fx: wide

--------------------------------------------------------------------------------

### autovacuum

**Comment savoir si on doit changer les réglages par défaut d'une table ?**

En utilisant les outils de monitoring qui indiqueront les tables qui n'ont pas
subit de vacuum depuis très longtemps et en tracant les explain avec les requêtes
lentes, afin d'y repérer des mauvaises estimations de coûts par l'analyseur de
requête.

**Quelques points pour vous aider à trouver les bon réglages :**

* les valeurs indiquées pour **analyze** devraient être supérieures à celles de
**vacuum** car elles comptent aussi les insertions (si vous avez des insertions
 sur cette table)
* Pour une table **statique** (données de paramétrage par exemple), où les
 données bougent très rarement, ne vous occupez pas des problèmes de vacuum
* Une table qui ne subit **que des insertions** n'aura **jamais de vacuum**
 (mais n'a pas besoin de vacuum, si vous avez uniquement des insertions et un
 fillfactor à 100 la table ne va pas gaspiller d'espace disque)

--------------------------------------------------------------------------------

<div class="warning"><p>
Sur une table qui ne subit que des insertions ne vous occupez que des paramètres
analyze.
</p></div>
<div class="warning"><p>
faire tourner de petits vacuum fréquemment est moins coûteux que de faire tourner
un gros vacuum
</p></div>
<div class="warning"><p>
Pour les <b>grosses tables</b> (en nombre de lignes) qui subissent un <b>grand nombre d'insertions</b> vous aurez besoin de faire tourner <b>analyze</b> fréquemment,
 <b>réduisez le autovacuum_analyze_scale_factor</b>
</p></div>
<div class="warning"><p>
Pour les <b>grosses tables</b> (en nombre de lignes) avec beaucoup de
 <b>mouvements (delete, update, insert)</b> vous devriez <b>réduire le
  autovacuum_vacuum_scale_factor</b> pour avoir plus souvent des opérations de
  vacuum. Vous pouvez aussi décider de monter le <b>autovacuum_vacuum_thresold</b>
  à un chiffre élevé (comme 1000 ou 5000) et mettre <b>0 au
  autovacuum_vacuum_scale_factor</b>.
</p></div>

.fx: wide

--------------------------------------------------------------------------------

<div class="warning"><p>
Les réglages par défaut seront très bien (au sens ou vous n'avez pas besoin de
les modifier) si vous ne subissez pas de ralentissements sur vos requêtes et si
votre espace disque occupé est raisonnable
</p></div>
<div class="warning"><p>
Sur une <b>grosse table</b> avec <b>beaucoup de mises à jour</b> (chose assez
peu fréquente en fait) un moyen simple d'obtenir un vacuum plus <b>prévisible</b>
est de <b>diminuer le factor</b> et de mettre dans le <b>thresold une valeure
basse du nombre d'opérations par jour</b>.
</p></div>
<div class="warning"><p>
Pour une table qui reçoit des mises à jour en <b>mode batch</b>, par exemple
elle reçoit <b>10 000</b> nouvelles lignes chaque nuit graĉe à un cron; mettez
le <b>thresold d'analyze à 10000 et le factor à 0</b>, ainsi seul le nombre
d'insertions va déterminer le lancement du vacuum. S'il ne s'agit pas que
d'insertions mais aussi de mises à jour et de suppressions modifiez le thresold
et le factor du vacuum de la même façon.
</p></div>
<div class="warning"><p>
Vous pouvez aussi forcer le lancement de commandes VACCUUM sur les tables
impactées <b>en fin de batch</b>. On doit aussi parfois forcer ces commandes
<b>en cours de batch</b> pour s'assurer que le batch utilisera les bonnes
optimisations de requête.
</p></div>

.fx: wide

--------------------------------------------------------------------------------
### vacuumdb

Un utilitaire `vacuumdb` existe, avec un ensemble d'options disponibles, dont
une option `-j` qui permet de paralléliser les traitements de maintenance
(depuis la version 9.4).

Par exemple cette commande, lancée par l'utilisateur postgres:

    vacuumdb -j4 formation

Va permettre de lancer des vacuum en utilisant 4 process parallèles.

On peut avoir bien sur des commandes plus complexes:

    /usr/lib/postgresql/11/bin/vacuumdb -p 5435 \
      --echo \
      -j 2 \
      --analyze-only \
      -d formation

.fx: wide

--------------------------------------------------------------------------------

## 20.5. Paramètres de configuration principaux

.fx: title2

--------------------------------------------------------------------------------

Les paramètres de postgreSQL se trouvent dans le fichier `postgresql.conf`.

Ce fichier est disponible dans les répertoires `/etc/postgresql/*` sur les
 distributions type debian, mais il s'agit en fait, comme le `pg_hba.conf` que
 nous avons vu dans les parties précédentes, d'un simple raccourci vers le
 répertoire de stockage physique de la base.

La lecture complète de ce fichier et des commentaires qui s'y trouve vous
apportera toujours une base de connaissance utile (les commentaires indiquent
par exemple les paramètres qui nécessitent un redémarrage complet du serveur
pour être pris en compte, dans le cas contraire un simple reload suffira).

Faisons le point sur les principaux paramètres...

--------------------------------------------------------------------------------

### 20.5.1. Connexions

* **listen_addresses** : liste des interfaces réseau sur lesquelles le serveur
 est à l'écoute. Par défaut 'localhost' et donc uniquement en local, mettez '*'
 pour utiliser toutes les adresses réseaux du serveur.
* **port** : le port sur lequel le serveur est en écoute sur les interfaces
  listées dans le paramètre précédent. Modifiez le si plusieurs instances de
  PostgreSQL doivent tourner en parallèle (comme lors d'un upgrade)
* **max_connections** : nombre maximum de connexions acceptées, le défaut est à
  100 ce qui est très peu. Ajoutez un zéro et passez à 1000. Pensez par exemple
  que deux serveurs frontaux apache avec un MaxClients à 150 demanderont 300
  connexions en pic (s'ils ne servent qu'une seule application, avec un seul
  login sur une seule base...). Si vous utilisez Apache en mode multi-threadé
  (worker) vous risquez d'avoir un MaxClients beaucoup plus élevé côté apache,
  si vous utilisez plusieurs rôles cela va aussi augmenter la consommation de connexions. **Pensez à utiliser des pooler de connexions pour des besoins
  dépassants le milliers de connexions.**

* **superuser_reserved_connections** : Parmi toutes les connexions disponibles
 ce nombre de connexions (3 par défaut) sera réservé au superadmin postgres.
 Cela vous permettra de vous connecter à postgreSQL y compris au moment des pics.
Intégrez dans ce nombre la consommation des membres de l'équipe d'admin et des
logiciels de supervision.

.fx: wide

--------------------------------------------------------------------------------

### 20.5.2. Mémoire

* [http://docs.postgresqlfr.org/11/runtime-config-resource.html](http://docs.postgresqlfr.org/11/runtime-config-resource.html)


La mémoire est utilisée par PostgreSQL de deux façons, une partie de cette
mémoire est consommée par chaque connexion ouverte. Une seconde partie beaucoup
plus importante est utilisée en tant que mémoire partagée par toutes les
connexions (schématiquement).

Chaque connexion est un processus différent (fork) et la principale particularité
 de PostgreSQL avant la version 9.3 était l'utilisation intensive de cette
 mémoire partagée. La consommation n'est plus aussi importante depuis.

Sur la plupart des distributions les valeurs par défaut pour la mémoire sont très
 faibles, adaptées à une utilisation légère de PostgreSQL par un seul utilisateur.
Ceci parce que la plupart des distributions n'autorisent par défaut que des
valeurs très petites pour la taille d'un fichier de mémoire partagée.
Vous aurez donc assez souvent le besoin de modifier ces paramètres et de modifier
la taille limite des fichiers partagés dans le système.

La mémoire partagée était utilisée pour cacher les données du disque, ce qui
comprenait les données des journaux de transactions et les fichiers des tables
 et autres objets physiques (le contenu du répertoire de données de la base en
 fait).

Avec la version 9.3, PostgreSQL est passé d'une mémoire partagée SysV à une
mémoire partagée Posix (et mmap). Ceci à simplifié les installations et réglages
et n'impose plus la modification de SHMMAX et SHMALL dans la plupart des cas.

.fx: wide

--------------------------------------------------------------------------------

### Mémoire

* **wal_buffers** : taille réservé au cache des journaux transactions: 3% de
 `shared_buffers` par défaut (soit 64KB): sur un serveur ou des transactions
 sont réellement en œuvre (pas uniquement des opérations en lecture) et
 parallélisées utiliser des valeurs entre 1Mo et 10Mo.
* **shared_buffers** : 128MB par défaut (je crois) taille réservée au cache des
données : le plus est le mieux, plus vous pourrez mapper de vos données physiques
dans ce cache mieux le serveur se portera. Le problème étant que vous devez
disposer de cette mémoire (sinon le serveur va swapper, ce qui serait pire).
On conseille souvent d'utiliser au départ un quart de la mémoire du serveur
(**25%**, donc 500MB sur un serveur qui dispose de 2Go de RAM). En mode 32bit
la limite est de 2GB. Surveillez la statistique **cache_miss** pour voir si
votre paramètre est trop petit.

**ATTENTION:** sur Windows ne jamais utiliser plus de 512MB en shared_buffers.
Les performances s'effondrent une fois ce seuil dépassé. Il faudra jouer sur
d'autres paramètres.

Sur les PostgreSQL récents il est conseillé de ne pas dépasser **40%** de la
RAM du serveur sous Linux. Pour que le **cache disque de l'OS** puisse prendre
le relais.

Quand vous essayerez de démarrer ou redémarrer postgreSQL avec des nouvelles
valeurs dans ces champs il est probable que celui-ci refuse de se lancer à cause
d'une taille de fichier partagé trop importante. Regardez le fichier de log,
celui-ci indique la valeur que le serveur à tenté d'allouer:

.fx: wide

--------------------------------------------------------------------------------

### Mémoire

    > /etc/init.d/postgresql-9.6 restart
    Restarting PostgreSQL 9.6:
    waiting for server to shut down.... done
    server stopped
    waiting for server to start.......................pg_ctl: could not start server
    Examine the log output.
    PostgreSQL 9.0 did not start in a timely fashion, please see /path/to/data/pg_log/startup.log for details
    > tail -f -n 10 /path/to/data/pg_log/startup.log
    (...)
    2011-10-26 18:06:29 CEST FATAL:  could not create shared memory segment:
         Argument invalide
    2011-10-26 18:06:29 CEST DETAIL:  Failed system call was
         shmget(key=5439001, size=538116096, 03600).
    2011-10-26 18:06:29 This error usually means that PostgreSQL's request
    for a shared memory segment exceeded your kernel's SHMMAX parameter.
    You can either reduce the request size or reconfigure the kernel with
    larger SHMMAX.  To reduce the request size (currently 554467328 bytes),
    reduce PostgreSQL's shared_buffers parameter (currently 64000) and/or
    its max_connections parameter (currently 1004).
    If the request size is already small, it's possible that it is less
    than your kernel's SHMMIN parameter, in which case raising the request
    size or reconfiguring SHMMIN is called for.
    The PostgreSQL documentation contains more information about shared
    memory configuration.

--------------------------------------------------------------------------------

### Mémoire

Pour modifier les paramètre SHMIN et SHMMAX on utilise sysctl ainsi:

    ># voir les paramètres actuels
    > sysctl -a |grep -i shm
    kernel.shmmax = 33554432
    kernel.shmall = 2097152
    kernel.shmmni = 4096

On mets les nouvelles valeurs dans /etc/sysctl.conf:

    kernel.shmmax = 600000000
    kernel.shmall = 600000000

Puis on recharge ces valeurs:

    > sysctl -f /etc/sysctl.conf

Comme tous les serveurs de base de données PostgreSQL **adore la RAM**, pensez
à le séparer des autres processus dévoreurs de RAM comme Apache ou un serveur
J2EE. Donnez lui une machine dédiée, avec aussi des disques rapides et sûrs.

.fx: wide

--------------------------------------------------------------------------------

### Mémoire

Pour la **consommation par processus** le paramètre important est :

* **work_mem** : cela représente la mémoire que le processus a le droit
d'utiliser pour effectuer ses opérations de hachage et de tris (celles que le
explain montre). S'il a besoin de plus de mémoire il devra passer par un
**stockage temporaire sur disque** des opérations en cours. La difficulté de ce
 paramètre tient au fait que non seulement il est potentiellement à multiplier
 par le nombre de connexions parallèles (`max_connections` au pire) mais qu'en
 plus un même processus à le droit de l'utiliser plusieurs fois si la requête
 qu'il exécute comprends plusieurs opérations de hachage (certains explain nous
 ont montré des plans d'exécution complexes où cette work_mem aurait été utilisée
 plusieurs fois pour la même requête). La valeur par défaut est **1MB**.
 Vous pouvez essayer de monter à **10MB** mais pour 1000 connexions parallèles
 qui auraient des requêtes ardues à effectuer cela veut dire potentiellement
 10Go de RAM – il est improbable que toutes les connexions utilisent en même
 temps la maximum de ce qui leur est autorisé). Si vous mettez une valeur trop
 basse vous allez augmenter l'utilisation des fichiers temporaires ce qui
 ralentira le temps d'exécution des requêtes et augmentera l'activité sur disque
 (qui est lente).

<div class="warning"><p>
Vous pouvez affecter cette valeur à l'aide des variables utilisateur, par exemple
au niveau des rôles. Ainsi certains rôles effectuant du travail sur des quantités
importantes de données pourront avoir un work_mem par défaut plus important.
</p></div>

.fx: wide

--------------------------------------------------------------------------------

### Mémoire

* **maintenance_work_mem** : 16MB par défaut, montez à 100MB voir plus. Il
 s'agit de la mémoire allouée aux processus du superutilisateur effectuant des
 opérations de maintenance comme les **vacuums** ou les **réindexations**,
 les clusters etc. Il n'y a normalement pas de parallélisation de ces tâches

Lors d'un import de données massif, il n'y aura à priori que des connexions
destinées à cet import (si vous coupez les autres via le pg_hba.conf par
exemple), pensez à augmenter les valeurs de work_mem et maintenance_work_mem **temporairement** pour accélérer l'import.

--------------------------------------------------------------------------------

Signalons enfin d'autres paramètres proches de l'utilisation mémoire mais qui
sont plus des réglages informatifs:

* **effective_io_concurrency** : indiquez le nombre de disque présents sur le
 système

* **effective_cache_size** : 128MB par défaut il ne s'agit pas d'un paramètre de
 consommation de mémoire par PostgreSQL. Il s'agit d'un paramètre d'information
 sur le système d'exploitation, la taille de RAM libre disponible pour effectuer
des requêtes. Sur Linux mettez environ 2/3 de la RAM, sur Windows regardez la
valeur du cache disque sur le gestionnaire de tâches. Il s'agit ici d'indiquer à
PostgreSQL la taille du cache disque de l'OS pour que le planificateur de requêtes
calcule la probabilité qu'une table et/ou son index soient dans le cache disque
de l'OS.

* **random_page_cost** : il s'agit d'un indicateur de coût (unité arbitraire)
pour accéder à une page de donnée sur le disque. La valeur par défaut est 4.0.
Si vous pensez que votre machine dispose de disques qui valent mieux que la
moyenne du marché baissez ce coût. Par exemple à 3.0 ou 2.0. Dans l'idéal
faites des benchmarks pour mesurer les gains éventuels sur des requêtes.

<div class="warning"><p>
Ces deux derniers paramètres peuvent jouer en faveur des parcours d'index au
lieu de parcours séquentiels lors de l'exécution des requêtes.
</p></div>

.fx: wide

--------------------------------------------------------------------------------

### 20.5.3. Les logs

Il y a de nombreux paramètres liés aux journaux dans le fichier `postgresql.conf`.

On peut par exemple décider de loger au format **CSV**, de tracer toutes les
requêtes, ou bien aucune, ou bien seulement celles qui modifient la structure
de la base (ddl). On peut associer un explain avec les requêtes tracées,
garder une trace du temps d'exécution, des connections, etc.

Les paramètres les plus importants pour les logs sont:

* **log_min_duration_statement** : indiquez une valeur au dessus de laquelle
 vous garderez une trace de la requête, cela vous permettra d'identifier les
 requêtes qui nécessitent un travail de réécriture ou d'indexation.
* **log_temp_files** : indiquez une taille, si une requête nécessite la
 création d'un fichier temporaire supérieur à cette taille elle sera loguée.
* **lc_messages = 'C'** : contrairement aux autres paramètres de locales (comme
les monnaies, ordre de tris, heure) vous devriez laisser les messages dans la
locale par défaut **C**. Ceci vous permettra de retrouver plus vite de l'aide
sur Internet en recopiant les messages d'erreur retrouvés dans les logs.

.fx: wide

--------------------------------------------------------------------------------

# logs

Si vous voulez tester les logs en CSV vous devrez paramétrer vos logs ainsi :

    # eventlog & stderr ne sont pas requis pour les logs csv
    # mais on voit qu'il s'agit d'une liste et pas d'un réglage
    # unique
    # windows
    #log_destination = 'csvlog,eventlog,stderr'
    # linux
    log_destination = 'csvlog,syslog,stderr'
    logging_collector = on
    # Nous changeons le nom de fichier pour par exemple ne garder
    # que le nom du jour (lundi)
    log_filename = 'postgresql-%a.log'
    # Après une semaine le fichier 'lundi' sera réutilisé, il devra
    # avoir été remis à vide
    log_truncate_on_rotation = on
    # Ici si vous essayez de forcer la rotation des logs sur l'age
    # ou la taille cela ne devrait plus fonctionner. Sans doute
    # parce que l'heure ne figure plus dans log_filename
    log_rotation_age = 1440
    log_rotation_size = 100kB

--------------------------------------------------------------------------------

# logs

Puis, pour importer vos logs CSV dans une table PostgreSQL créez cette table:

    CREATE TABLE postgres_log
    (
      log_time timestamp(3) with time zone,
      user_name text,
      database_name text,
      process_id integer,
      connection_from text,
      session_id text,
      session_line_num bigint,
      command_tag text,
      session_start_time timestamp with time zone,
      virtual_transaction_id text,
      transaction_id bigint,
      error_severity text,
      sql_state_code text,
      message text,
      detail text,
      hint text,
      internal_query text,
      internal_query_pos integer,
      context text,
      query text,
      query_pos integer,
      location text,
      application_name text,
      PRIMARY KEY (session_id, session_line_num)
    );

.fx: wide

--------------------------------------------------------------------------------

# logs

Enfin, importez le log dans la table:

    COPY postgres_log FROM '/chemin/complet/vers/logfile.csv' WITH csv;

Attendez que le fichier de log ne soit plus utilisé pour l'importer (sinon vous
aurez des problèmes avec la clef primaire en essayant de le réimporter).

Si vous essayez de l'importer depuis une application faites attention au fait que
 certains des champs peuvent contenir des retours chariots et donc être sur
 plusieurs lignes (comme internal_query et message).

<div class="warning"><p>
<b>Certaines traces ne peuvent être poussées dans le csvlog ou l'eventlog</b>,
comme les logs en provenance des erreurs de linkage des librairies partagées
(python, perl) ou des corruptions de mémoire. Vous aurez donc toujours un
fichier de log classique (*.log), qui sera le plus souvent vide, mais n'oubliez
pas de le regarder. Le jour où ce fichier ne sera pas vide ce sera pour des
problèmes critiques <b>« on ne réalise pas qu'on en a besoin jusqu'à ce qu'on en
 ai besoin, et ce jour là on en a vraiment besoin ».</b>
</p></div>

.fx: wide

--------------------------------------------------------------------------------

### 20.5.4. Les journaux de transactions (WAL) et CHECKPOINT

Quand des écritures on lieu dans postgresql il y a toujours une **transaction**.
Chacune de ces transactions est tracée dans le WAL (Write Ahead Logging).
Nous pouvons d'ailleurs observer que parmi les premiers processus de PostgreSQL
l'un d'entre eux est dédié à cette opération:

    >ps auxf|grep postgres
    postgres  S      0:00 /path/to/bin/postgres -D /path/to/data
    postgres  Ss     0:00  \_ postgres: logger process
    postgres  Ss     0:00  \_ postgres: writer process
    postgres  Ss     0:00  \_ postgres: wal writer process
    postgres  Ss     0:00  \_ postgres: autovacuum launcher process
    postgres  Ss     0:00  \_ postgres: stats collector process

**Le WAL enregistre toutes les transactions validées.** Sans pour autant que ces
 opérations soient réellement transférées sur le disque au niveau des tables.
Cela permet la reprise d'un état cohérent de la base en cas d'arrêt brutal, sans
 pour autant ralentir les opérations d'écritures trop fortement en forçant les
 fichiers binaires des tables à être raccord avec l'état réel des données en
 permanence.

Le WAL est constitué de fichiers. Ces fichiers contiennent des copies des pages
 mémoire des tables et des informations de modification à effectuer.
 Quand un fichier WAL est rempli un nouveau fichier WAL est créé. Ces fichiers
 font 16MB.

.fx: wide

--------------------------------------------------------------------------------

### wal & checkpoint

Les fichiers WAL (journaux) sont stockés dans le dossier `pg_xlog` ou `pg_wal`
(après la version 10) du répertoire des données.
Il peut s'avérer très utile d'utiliser un disque différent sur ce
 point de montage du système de fichier (parallélisation, gestion du disque
cache, taux d'IO du disque). Sur Windows voir les systèmes de JUNCTION.

<div class="warning"><p>
Notez que même <b>une base sans aucune activité en écriture aura des fichiers WAL
 générés dans ce dossier</b>. Ceci parce qu'au moins une opération d'écriture
arrive régulièrement, le <b>CHECKPOINT</b> et que cette opération est elle-même
 enregistrée dans un fichier WAL.
</p></div>

Les checkpoints peuvent se produire à plusieurs moments:

* **'checkpoint_timeout' minutes** (par défaut 5) se sont passées depuis le
 dernier checkpoint
* avant 9.5 il y a eu **plus de 'checkpoint_segments' fichier WAL créés** (par défaut 3)
* apres 9.5 il y a eu **plus de 'max_wal_size' données créées dans les WAL** (par défaut 1GB)
* quelqu'un à lancé une commande SQL **CHECKPOINT;**

**Lors du checkpoint les changements stockés dans les fichiers WAL sont écrits dans
 les fichiers physiques des tables.**

.fx: wide

--------------------------------------------------------------------------------

### wal & checkpoint

On peut alors imaginer que l'opération de CHECKPOINT est une **opération coûteuse**
 pour l'OS, toutes les écritures sont reportés à un moment ultime, quand ce
moment intervient un grand nombre d'écritures doivent se faire.

Heureusement on peut répartir ces écritures entre deux checkpoints grâce au
paramètre **checkpoint_completion_target**. La valeur par défaut **0.5**
signifie que PostgreSQL dispose de `0.5*checkpoint_timeout`, soit 2 minutes 30
par défaut pour effectuer les écritures réelles. En le fixant à `0.9` on permet
un lissage plus fort encore de ces écritures. Mais vous pouvez aussi repousser
`checkpoint_timeout` et utiliser une valeur assez basse pour
 `checkpoint_completion_target`.

<div class="warning"><p>
Remarquez le paramètre <b>checkpoint_warning</b> à <b>30s</b> par défaut.
Si plus de 1Go de données ou de 3 WAL sont créés en moins de 30s un nouveau
CHECKPOINT très
rapproché de l'ancien sera généré et vous aurez une ligne de warning dans les
logs, si vous voyez un grand nombre de ces warnings lors d'une activité
régulière de la base cela signifiera que vous devrez <b>augmenter votre valeur
de max_wal_size ou checkpoint_segments</b> (en fonction de votre version).
</p></div>

--------------------------------------------------------------------------------

## 20.6. Considérations matérielles pour la performance

.fx: title2

--------------------------------------------------------------------------------

### considérations matérielles

Plus vous aurez de CPU (nombre) plus vous pourrez traiter de requêtes en
 parallèle. Et cela pourra aussi devenir crucial lors de l'utilisation de
 `pg_restore` pour paralléliser les traitements d'import.

Plus vous aurez de **RAM** plus vous pourrez espérer faire tenir l'intégralité
des données de la base dans le **shared_buffers** (ou dans le cache de l'OS),
ou plus vous aurez la possibilité d'augmenter `work_mem` afin d'éviter
l'utilisation de tables temporaires sur le disque lors d'un travail d'une
requête sur un grand nombre de données.

Si vous n'avez pas assez de RAM et que vous avez réglé des paramètres
d'utilisation de la RAM trop élevés les performances s'effondreront.

**Attention aux programmes tournant sur le même serveur.**

Certains type de RAM sont plus sûrs que d'autres (comme la RAM ECC).

les Entrées-Sorties disques seront importante si vous n'arrivez pas à faire
tenir la base dans `shared_buffers`. Soit parce que votre base est très grande,
soit parce que vous travaillez avec Windows. Si vous activez le WAL pour les
backups ou la réplication les opérations d'écritures vont aussi impliquer des
Entrées-Sortie disque, peut-être devrez-vous prévoir des disques très rapides,
supportant un grand nombre d'Entrées/Sorties, spécifiquement pour le WAL.

.fx: wide

--------------------------------------------------------------------------------

### considérations matérielles

Si vos disques sont en RAID [cf wikipedia](http://fr.wikipedia.org/wiki/RAID_%28informatique%29)
 notez qu'un **RAID5** peut ralentir les opérations d'écritures, le meilleur
 système de RAID est le **RAID1+0** (mirroring et agrégation), mais il est assez
coûteux en nombre de disques.

Pour des volumes vraiment très gros vous devrez étudier les différents système
de SAN à disposition, mais évitez les système de disque réseau type NFS ou ISCSI
si vous pouvez utiliser des vrais disques avec du RAID matériel.

Multipliez les **cartes réseau** et évitez de mélanger les différents flux
réseaux pour

* mieux **superviser** les flux
* mieux **détecter** les évolutions dans ces flux
* isoler les **flux de réplication**
* faciliter les **politiques d'accès** dans le pg_hba.conf
* mieux gérer le traffic des sauvegardes

**Monitorez** et mesurez les impacts des changements de matériel et de configuration

--------------------------------------------------------------------------------

## 20.7. Backup et Restaurations liés à l'archivage WAL

.fx: title2

--------------------------------------------------------------------------------

### Backup Wal

Nous verrons par la suite que le WAL peut servir à des politiques de **réplication**.

Dans un premier temps nous analyserons sa première utilité qui est de permettre
un **backup par sauvegarde des journaux de transactions** (associé à un backup de
l'état physique de la base à un instant couvert par ces journaux).

Ce type de backup est très puissant puisque contrairement aux dumps il permet:

* la sauvegarde des modifications au fil de l'eau
* le **PITR (Point In Time Recovery)**, la restauration à un état passé de la base.

--------------------------------------------------------------------------------

### 20.7.1. Configurer l'archivage des WAL

Les fichiers WAL que nous avons étudié avec les principaux paramètres de
configuration permettent de rejouer toutes les transactions qui ne sont pas
encore écrites sur les fichiers physiques.

Cela signifie qu'en partant d'une version ancienne des fichiers physiques de la
base et en rejouant tous les fichiers WAL créés depuis on peut ré-obtenir une
version récente de la base (et on peut s'arrêter à une transaction donnée).

Ce système de backup existe et s'appelle le **WAL Archiving**.

Ceci se fait en jouant sur querlques paramètres, le `wal_level`, l'`archive_mode`, et l'`archive_command`

Le [`wal_level`](https://docs.postgresql.fr/11/runtime-config-wal.html#guc-wal-level)
est un paramètre important dont les valeurs possibles on évolué entre les
[premières version 9.x](https://docs.postgresql.fr/9.5/runtime-config-wal.html#guc-wal-level)
et les versions 10 et 11.
Sur la version 11 sa valeur par défaut est `replica`, qui est suffisant pour le
mode backup, sur la version 9.5 on voit que la valeur par défaut est `minimal`.
En mode `minimal` on accélère l'écriture des wal sur disque, car ils contiennent
moins d'informations, mais on ne gère que le mode **'récupération de l'état de la base en cas d'arrêt catastrophique'**.

--------------------------------------------------------------------------------

### Archivage des wal

<div class="warning"><p>
Retenez les <b>principes généraux</b>, mais confirmez toujours les valeurs des
 paramètres par rapport à votre version cible.
</p></div>

Pour le `wal_level` il nous faut un mode supérieur à `minimal` pour la gestion
du backup, donc `replica` sur une version 11, ou encore `archive` sur des
versions 9.5 ou 9.6.

Nous allons aussi activer l'**archivage des journaux de transactions** avec
 [`archive_mode`](https://docs.postgresql.fr/11/runtime-config-wal.html#guc-archive-mode), et l'`archive_command`.

Il faut ensuite configurer quelques paramètres comme indiqué dans cet extrait de configuration commenté :

--------------------------------------------------------------------------------

    # Activation de l'archivage WAL
    wal_level = replica # ou archive sur les anciennes versions

    # Ceci va activer la commande d'archivage
    archive_mode = on

    # Ceci est la commande utilisée par PostgreSQL pour archiver les logs
    # %p : chemin du fichier à archiver (le journal de transaction original)
    # %f : le nom du fichier sans le chemin
    # la commande ne doit retourner 0 en code sortie qu'en cas de succès!!!
    # Il s'agit ici d'un script de backup incrémental
    # Quand le ficher WAL est plein ou trop vieux il sera archivé
    # à l'aide de cette commande et un nouveau WAL sera utilisé par le serveur
    # En cas de succès de l'archivage le fichier WAL peut être
    # supprimé ou réutilisé par postgreSQL
    # Ici nous pourrions aussi utiliser un script qui au passage ferait
    # une compression et utiliser un pipe pour cela (|)
    archive_command = 'test ! -f /mnt/serveur/archive/%f && cp -i %p /mnt/serveur/archive/%f </dev/null'

    # Ceci va forcer l'archivage d'un journal de transaction (WAL)
    # même si'il n'y a pas eu beaucoup de modifications.
    # Donc en cas de période d'inactivité sur la base nous aurons ici
    # le temps le plus long avant qu'une modification ne soit
    # réèllement archivée (300s->5min)
    archive_timeout = 300s

    # En utilisant la valeur par défaut (on) on indique que les commit
    # ne sont considérés réèl qu'après que le WAL soit écrit sur le disque
    synchronous_commit = on

.fx: wide

--------------------------------------------------------------------------------

    # Ceci est la méthode qui est utilisée pour s'assurer que le fichier
    # WAL est synchronisé sur le disque
    #"fsync" ou "fsync_writethrough" : Force écriture réèlle sur le disque
    # sans que l'OS puisse utiliser son cache disque
    # "open_datasync" : valeur par défaut pour windows
    # "fsync" apelle fsync() à chaque commit,"fsync_writethrough" aussi
    # en forcant les « write-through » des caches internes aux disques
    wal_sync_method = 'fsync_writethrough'
    # wal_sync_method = 'fsync'

    # checkpoint_completion_target indique que PostgreSQL peut utiliser
    # ce pourcentage de checkpoint_timeout (5min par défaut)
    # pour effectuer les vraies E/S disque lors des checkpoints
    # ici on utilise seulement 0.3, car 0.3*15min=4min30s
    checkpoint_completion_target = 0.3

    # la valeur par défaut est 5min,
    # on pourrait la garder mais cela provoque une modif dans le WAL
    # toutes les 5 minutes (à cause du checkpoint enregistré dans le WAL)
    # Donc comme un fichier WAL ne peut être plus vieux que 5 minutes,
    # cela génèrerait un fichier WAL toutes les 5 minutes au moins.
    # Nous le poussons à 15 minutes.
    # Cela signifie que les écritures de pages ne se feront sur le disque
    # que toutes les 15 minutes si l'activité est faible.
    # Les fichiers wal par contre restent écrits sur disque en permanence
    # Note: 15 minutes est uniquement un maximum,
    # <v9.5 :si 3 (checkpoint_segments) sont près un checkpoint sera effectué
    # >>v9.5 :si 1G (max_wal_size) d'écriture est passé un checkpoint sera effectué
    checkpoint_timeout = 15min
    # @deprecated in v9.5, cf min_wal_size and max_wal_size
    # checkpoint_segments = 3
    # -------
    # max_wal_size = 1GB
    # min_wal_size = 80MB

.fx: wide

--------------------------------------------------------------------------------

Le point important est **archive_command**. Le but de cette commande d'archivage
est de recopier les fichiers WAL stockés dans le dossier `pg_xlog` ou `pg_wal`
**vers un endroit sûr**.
La commande peut être un script complexe ou une simple ligne de
commande, le résultat est pour PostgreSQL **la certitude que ce WAL a été
recopié à un endroit où il ne craint plus un arrêt brutal du serveur**.

Examinons la paramètres de temps sur la génération de segments et les checkpoints.
Avec un **checkpoint_timeout de 15 minutes **et une base inactive on obtient sur
une frise chronologique:

    C: Checkpoint
    W: création fichier WAL
    WA: archivage fichier WAL

    |C---------------C--------------------C--------------------C--------
    0               15                  30                    45
    |W----WA---------W------WA------------W--------WA----------W-----WA
    0    5          15     20           30        35          45    50

Un fichier WAL est créé toutes les 15 minutes et il est archivé cinq minutes
plus tard par la commande `archive_command`. Bien sûr en cas d'activité en
écriture sur la base des fichiers WAL peuvent être créés beaucoup plus vite et
seront archivés quand ils auront plus de cinq minutes d'âge.

.fx: wide

--------------------------------------------------------------------------------

Le rôle de la commande d'archivage est de faire une copie de ces fichiers sur un
autre système. Vous pouvez utiliser rsync, ou une simple copie sur un disque
réseau, voir sur un disque dédié à cette tâche.

Les fichiers WAL font **16MB**, avec une base inactive et un WAL tous les quarts
 d'heures cela représente `96*16=1.5Go` de donnes minimales à archiver par jour.

N'hésitez donc pas **à compresser ces fichiers** lors de l'utilisation de
l'**archive_command**, vous pourrez gagner plus de 90% d'espace disque sur le
backup. Surtout sur les WAL créés en période inactive. Un programme nommé
**pg_compresslog** peut être utilisé à cette fin ainsi:

    archive_command = 'pg_compresslog %p - | gzip > /var/lib/pgsql/archive/%f'

Ce qui nous donnera pour la commande de restauration

    restore_command = 'gunzip < /mnt/server/archivedir/%f | pg_decompresslog - %p'.

<div class="action"><p>
Indiquez ces paramètres dans <b>postgresql.conf</b>, créez un dossier (<b>mkdir
 -p /mnt/serveur/archive; chown -R postgres /mnt/serveur;</b>) qui ne sera pas
déporté mais qui pourrait l'être. Redémarrez PostgreSQL puis testez l'effet du
 programme de génération de commandes (populate_app.php) sur les fichiers
 présents dans pg_wal et dans votre répertoire d'archivage (/mnt/serveur/archive).
</p></div>

.fx: wide

--------------------------------------------------------------------------------

### 20.7.2. Et sur Windows?

Sur une machine Windows on pourrait utiliser pour l'archive_command une commande
 de ce type:

    archive_command = 'copy %p E:\\ExternalBackup\\pg_wal\\%f'

Un des problèmes par contre sur windows est le `wal_sync_method` qui est à
**'open_datasync'** par défaut, avec comme indiqué dans le commentaire de ce
 paramètre le problème d'utilisation du cache disque par l'OS.
On peut utiliser **'fsync_writethrough'** ou tester **'open_datasync'** mais il
 faut alors empêcher le cache disque de windows en allant dans:

     # My Computer\Open\disk drive\Properties\Hardware\Properties\
                                  Policies\Enable write caching on the disk


--------------------------------------------------------------------------------

### 20.7.3. Automatiser une sauvegarde WAL

Les 3 opérations qui vont devoir être effectuées lors d'un backup sont:

* **1)** lancer un **SELECT pg_start_backup('iciunechaînedecaractères');**.
  Cette commande va créer un fichier dans le répertoire des données qui
  identifiera le backup en cours. Elle lance aussi un **CHECKPOINT** qui force
  l'écriture des données sur le disque. Si vous passez l'option `true` en
  deuxième argument ce CHECKPOINT sera forcé, sinon vous devrez attendre la fin
  du CHEKPOINT qui peut dépendre du paramètre **checkpoint_completion_target**
  que vous avez donné. La requête retournera un résultat quand le checkpoint se
  terminera. *Si cette commande renvoie des erreurs vous devriez sans doute arrêter le backup (un backup précédent qui ne s'est pas terminé?).*
* **2)** Faire **une copie de tout le contenu du répertoire des données.**
  Il n'est pas nécessaire de copier le sous-répertoire pg_wal. Celui-ci est
  normalement déjà pris en charge par le système d'archivage des WAL.
  Une des techniques de sauvegarde du répertoire des données et d'utiliser un
  système de fichier capable de faire des **snapshots** en faisant des freeze
  des fichiers et en gérant les modifications sur des système temporaires
  (comme XFS par exemple). Si vous pouvez faire un freeze du système de fichier
  juste après le pg_start_backup les opérations de restauration seront
  simplifiées car aucun fichier ne contiendra de données datant de transactions
  ultérieures au début du backup.

...

.fx: wide

--------------------------------------------------------------------------------

* **3)** effectuer un **SELECT pg_stop_backup();** ceci arrête le backup en
  passant au prochain WAL et retire le fichier `backup_label` du répertoire des
  données (que l'on aura donc copié avec la sauvegarde, mais ce n'est pas grave).
  Si nous sommes en mode `archive_mode` (backup des journaux de transactions)
  cette commande va attendre jusqu'à ce que le dernier segment WAL soit
  considéré comme archivé (celui qui contenait les dernières opérations
  effectuées en live sur la base pendant que nous faisions la copie binaire du
  répertoire des données entre `pg_start_backup` et `pg_stop_backup`).

<div class="warning"><p>
Si jamais <b>l'archive_command ne retourne pas 0</b> pour la sauvegarde du dernier
 WAL <b>pg_stop_backup() ne rendra pas la main</b>. Votre script pourra donc
 inclure une gestion du <b>timeout</b>. Votre système de supervision devrait aussi
 vérifier que les backups se terminent (pour Nagios voir les services passifs
 et le paramètre freshness, fraîcheur).
</p></div>

.fx: wide

--------------------------------------------------------------------------------

Pour lancer les commandes **SELECT** en début et fin de backup on pourra utiliser
`psql` avec l'option `-c`. Ce qui donne par exemple dans un script BAT (windows):

    %BINDIR%\psql.exe -h %SERVER% -U %USERNAME% -d %DATABASE% -p %PORT%^
     --no-password --echo-all -c "SET lc_messages=\"en_US\";^
     SELECT pg_start_backup(E'%BACKUPLABEL%');"
    IF ERRORLEVEL 1 goto (...)

Ou dans un script Bash:

    ${BINDIR}\psql -h ${SERVER} -U${USERNAME} -d ${DATABASE} -p ${PORT} \
     --no-password --echo-all -c "SET lc_messages=\"en_US\"; \
     SELECT pg_start_backup(E'%BACKUPLABEL%');"
    if [ $? ne 0 ]; then (...)

Nous pourrions utiliser `rsync`, `copy`, ou un simple `tar`.

--------------------------------------------------------------------------------

Testons un script simpliste (sans gestion d'erreur). Nommons ce script
**backup.sh**, il faut adapter dans ce script le dossier **DATADIR** par rapport
à votre vrai dossier de stockage de la base.

    #!/bin/bash
    DATADIR=/var/lib/pgsql/data
    ARCHIVEDIR=/mnt/serveur/archive
    BACKUPDIR=/mnt/serveur/backup
    # demarrage du backup
    psql --username=postgres -d postgres -c "select pg_start_backup('hot_backup');"
    # backup binaire
    tar -cf ${BACKUPDIR}/backup.tar ${DATADIR}
    # fin du backup
    psql --username=postgres -d postgres -c "select pg_stop_backup();"

Il nous faut rendre ce script exécutable et prévoir le dossier de stockage du backup:

    chmod u+x backup.sh
    sudo mkdir /mnt/serveur/backup/

Lancez le script. Vous pouvez normalement faire tourner le script php
`populate_app.php` en parallèle du backup.

    sudo ./backup.sh

.fx: wide

--------------------------------------------------------------------------------
### 20.7.4. Recovery: Restaurer un archivage de WAL

Maintenant que nous avons au moins une copie de la base et un archivage des
journaux de transaction nous devrions pouvoir tester une restauration.

Quelques notes utiles sur **les restaurations**:

* les segments de WAL qui ne seront pas retrouvés à l'emplacement d'archivage
 seront recherchés dans le dossier `pg_xlog` ou `pg_wal` de la base s'il existe
 encore (nous  somme en procédure de recovery, si ça se trouve on a plus ce
 dossier). Par contre **les segments présents dans le dossier d'archivage seront
 prioritaires**.
*  Avec une restauration on peut voir la gestion du temps dans PostgreSQL comme
  une **gestion parallèle du temps**. Un monde parallèle dans lequel les
  transactions de la restauration et les transactions éventuellement présente
  dans des WAL locaux ne seront pas mélangés.
* Normalement une restauration va reprendre tous les WAL qu'elle a à disposition, et donc ramener la base à un point dans le temps qui est le plus proche possible du présent. Normalement une restauration se termine avec un message dans les logs signalant un équivalent de « file not found », rien d'alarmant. Il peut aussi y avoir un message d'erreur en début de restauration sur un fichier 00000001.history, ce n'est pas non plus un vrai problème.


.fx: wide

--------------------------------------------------------------------------------

* La commande miroir de **archive_command** est **restore_command**. Elle doit
  permettre de **récupérer les segments archivés**. Comme la première cette
  commande doit renvoyer un code de sortie autre que 0 en cas d'erreur.
  Cette commande devra figurer dans un fichier `recovery.conf` situé dans le
  répertoire de la base.

* Il est possible d'écrire des fichiers **recovery.conf** avancés et de les stocker
  dans le répertoire des données de la base avant la restauration. Ceci permet
  le **Point in Time Recovery (PITR)** qui permettra de s'arrêter à un **temps**
  ou un **numéro de transaction** donné. Ce point dans le temps doit être situé
  **hors du temps du backup**. Il ne peut être situé entre le temps du
  `pg_start_backup()` et du `pg_stop_backup()`. Des exemples de `recovery.conf`
  sont disponibles et commentés dans `recovery.conf.sample` qui est livré avec le
  package ou les sources (dossier share).

Nous allons donc nous créer une situation de crash, un fichier de configuration
 spécifiquement dédié à la restauration (optionnel), un fichier de recovery
 (obligatoire) puis tenter cette restauration.

--------------------------------------------------------------------------------
### 20.7.5. Fichier de configuration dédié à la restauration

Au moment d'une restauration vous allez avoir de nombreux **journaux de
transactions à rejouer**, ou bien un **dump important à intégrer**. Il sera très
certainement utile de **préparer à l'avance un fichier de configuration
 optimisé** pour les restaurations. Stockez ce fichier à côté du fichier
 `postgresql.conf` officiel et utilisez-le le jour J.

    cp postgresql.conf postgresql.restore.conf
    cp postgresql.conf postgresql.orig.conf

Éditez cette copie postgresql.restore.conf puis changez ces paramètres:

    # Ne pas tout mettre dans les fichiers WAL
    # par exemple exclure les instructions COPY du dump
    wal_level = minimal
    # va désactiver l'archivage des WAL, ils ne sont donc plus archivés.
    archive_mode = off
    # repousser les écritures disques rèlles
    # (très dangereux en cas d'arrêt brutal de la base ou de l'OS)
    fsync = off
    synchronous_commit = off
    wal_sync_method = 'open_sync'

...

.fx: wide

--------------------------------------------------------------------------------

    # repousser les checkpoints à un temps très long
    checkpoint_timeout = 30min
    # repousser le checkpoint pour qu'il n'intervienne qu'après
    # un nombre très grands d'écritures de fichiers WAL
    # @deprecated in v9.5 cf min_wal_size and max_wal_size
    # checkpoint_segments = 5000
    max_wal_size = 2GB
    min_wal_size = 1GB

    # ici nous utilisons 0.00001, car 0.0001*30min est un chiffre très bas
    # (180ms je crois) et que cela prendra de toute façon plus de
    # temps dans la réalité
    checkpoint_completion_target = 0.00001

    # Si nous ne sommes pas sur windows on peut tenter une valeur
    # très élevée du stockage des journaux de transactions en mémoire
    # dans le segment de mémoire partagée
    # sur windows un 64kb suffira, sur Linux 16MB est très bien
    wal_buffers=16MB

    # donnons plus de mémoire pour les opérations DDL
    maintenance_work_mem = 500MB

    # désactivation des stats
    track_activities = off
    track_counts = off

    # désactivation de l'autovacuum
    autovacuum = off

    # On s'assure de ne pas charger trop de modules annexes
    shared_preload_libraries = ''
    custom_variable_classes = ''
    # et on enleve les settings des modules complémentaires s'il y en a

...

.fx: wide

--------------------------------------------------------------------------------

    # Assurons nous de ne pas avoir trop de logs
    log_destination = 'stderr'
    debug_print_parse = off
    debug_print_rewritten = off
    debug_print_plan = off
    debug_pretty_print = off
    # Ceci peut s'avérer utile pour vérifier que le checkpoint n'est
    # pas lancé et regarder combien de buffers sont écrits lors des
    # checkpoints manuels avec la commande CHECKPOINT;
    log_checkpoints = on
    log_connections = off
    log_disconnections = off
    log_duration = off
    log_error_verbosity = default
    log_hostname = off
    log_statement = 'none'
    log_temp_files=-1
    # Si vous avez un postgreSQL récent il faut vérifier que les éléments de
    # réplication sont bien suspendus
    max_wal_senders = 0
    max_logical_replication_workers = 0

On teste ce fichier (assurez d'avoir une copie du postgresql.conf original avant de mettre celui-ci en place)

    cp postgresql.conf postgresql.orig.conf
    cp postgresql.restore.conf postgresql.conf
    # et on relance avec une commande de ce type
    # /etc/init.d/postgresql-9.6 restart
    # ou encore
    systemctl restart postgresql@11-main

.fx: wide

--------------------------------------------------------------------------------

### Testez le mode unsafe/recovery

Testez le script `populate_app.php` sur cette version de PostgreSQL. Vous
devriez obtenir des **gains de vitesse très très importants**. Mais vous n'avez
plus en face un serveur de base de données très sûr en terme de stockage disque.

<div class="warning"><p>
Vous pouvez aussi utiliser ces réglages sur les <b>machines de développement</b> si
 la stabilité de la base n'est pas une priorité par rapport au temps de réponse
puisqu'il s'agit d'un fichier <b>optimisé en vitesse d'exécution</b> et non en
intégrité des données physiques.
</p></div>

--------------------------------------------------------------------------------
### 20.7.6. Créer un crash

**On va retirer le DATADIR de postgreSQL**, soit pendant qu'il tourne soit à
l'arrêt, la situation est la même, vous n'aurez plus de PostgreSQL et la base
est « perdue ». Sur Linux un `kill -9` des processus postgres pour tuer
brutalement le serveur sera utile. Le `mv` du dossier pouvant ne pas suffire
à lui faire perde ses descripteurs de fichiers.

Si nous prenons `/var/lib/pgsql/data` comme DATADIR il suffit de faire (en root):

    mv /var/lib/pgsql/data /mnt/otherdisk/olddata;
    mkdir /var/lib/pgsql/data;
    chown postgres:postgres /var/lib/pgsql/data;

Dans cet exemple nous avons à disposition les WAL archivés dans
`/mnt/serveur/archives` et un tar des fichiers physiques de la base dans
 `/mnt/serveur/archives`.

Vous pourrez tenter une variante de la restauration en recopiant les WAL de
`/mnt/otherdisk/olddata/pgxlog` dans `/var/lib/pgsql/data/pgxlog`

Faites une copie de vos fichiers `postgresql*.conf` ou refaites le backup, car
ces fichiers là ne sont pas dans le tar que nous avons fait initialement.

.fx: wide

--------------------------------------------------------------------------------
### 20.7.7. Lancer la restauration

Modifiez **pg_hba.conf pour n'autoriser que les accès locaux**. Par exemple en
indiquant uniquement:

    local   all             postgres                             trust

Ceci afin qu'aucune connexion cliente ne vienne troubler vos opérations.

Recopiez le dernier snaphot binaire effectué dans `/var/lib/pgsql/data` à la
racine puis décompressez le (sous sa forme actuelle le tar a stocké les chemins
absolus)

    cp /mnt/serveur/backup/backup.tar /
    cd /
    tar xvf backup.tar

Vérifiez que le fichier `postgresql.conf` du DATADIR est bien le fichier
optimisé pour les recovery.

...

--------------------------------------------------------------------------------

Créez un fichier `recovery.conf` et stockez le dans le DATADIR. Vous pouvez
utiliser une copie du sample ou bien n'indiquer que l'option `restore_command`
dans ce fichier:

    restore_command = 'cp -i /mnt/serveur/archive/%f %p'

Sur Windows on aurait quelque chose comme:

    restore_command = 'copy "E:\\ExternalBackup\\archives\\%f" "%p"'.

Mais utiliser un script plus complexe qu'un simple copy peut-être utile,
notamment pour s'assurer qu'un FILE NOT FOUND devrait retourner une code de
sortie 0.

Si votre `archive_command` compressait les WAL la `restore_command` doit les décompresser. Si vous utilisiez `pg_compresslog` vous devez utiliser
`pg_decompresslog`.

Cette commande va permettre à PostgreSQL de retrouver des segments de WAL afin
de les recopier dans le `pg_xlog` ou `pg_wal` local s'il en a besoin pour
remettre l'état binaire des fichiers physiques de la base à jour.

Pour le PITR regardez les paramètres `recovery_target_time` et
`recovery_target_xid`.

.fx: wide

--------------------------------------------------------------------------------

<div class="warning"><p>
<b>Attention:</b> PostgreSQL va essayer de renommer le fichier <b>recovery.conf</b>
 en <b>recovery.old</b> à la fin du processus. L'utilisateur postgres doit donc
 être en mesure de bouger ce fichier, n'oubliez pas de lui donner les droits sur
 recovery.conf!
</p></div>

    chown postgres recovery.conf

Vous pouvez retirer le `backup_label` du DATADIR. Ici nous utilisons les **WAL
 archivés** et nous n'avons plus de WAL dans le *'vrai'* `pg_wal`. Ce fichier
 contient des infos sur les derniers wal locaux valides, **mais ils ne sont
 plus là**.

Nous devrions être maintenant près pour lancer cette restauration (au fait, il
est évident qu'il vaut mieux avoir testé ces éléments et **rédigé une procédure**
avant d'en avoir besoin).

--------------------------------------------------------------------------------
#### Restauration

Démarrez PostgreSQL

    /etc/init.d/postgresql-9.6 start

Vous pouvez faire un `tail -f` sur le log actif afin d'observer la restauration.

S'il n'y a pas de messages de restaurations retentez le démarrage jusqu'à ce que
 ceux-ci apparaissent dans les logs.

Attendez tant que les messages soient du type:

    CET FATAL:  the database system is starting up

La fin de la restauration se traduit par un message:

    CET LOG: database system is ready to accept connections

--------------------------------------------------------------------------------
### 20.7.8. Finir la restauration: tout remettre en état

Après la restauration on lancera à la main (en SQL) un

    CHECKPOINT;

Quand cette commande se termine **la restauration est terminée** et les fichiers
écrits sur disques (ou dans le cache disque de l'OS au moins, vous pouvez taper
sync dans une console root).

* Il est conseillé ensuite d'éteindre postgreSQL puis de** remettre le fichier postgresql.conf original**.

* Remettez aussi le **pg_hba.conf** original en place.

* Redémarrez PostgreSQL

--------------------------------------------------------------------------------

Tapez ensuite un

    VACUUM ANALYZE

Cette commande va permettre à l'analyseur de remettre à jour toutes ses
statistiques, PostgreSQL mettra moins de temps à effectuer les bonnes opérations
 en fonction de la taille réelle des données. Même si vous n'avez pas utilisé un
fichier de configuration dédié à la restauration, dans lequel les statistiques
étaient suspendues, lancer cette commande accélèrera le retour « à la normale ».

Avec la restauration et la coupure des archivages de WAL la chaîne de PITR/WAL à
 été brisée. Il faut donc **refaire un backup complet des fichiers binaires de
 la base**, afin que ceux-ci puissent servir de base à **la prochaine
 restauration**.

--------------------------------------------------------------------------------
## 20.8. Tests de restauration de dump

.fx: title2

--------------------------------------------------------------------------------

Nous avons vu une **récupération de base à partir des journaux de transactions.**

Cela n'exclut pas la possibilité d'effectuer** des opérations de dumps et de
 restauration de dumps** (c'est par exemple obligatoire pour les migrations de
 version majeures).

Effectuez un dump au format compress de votre base avec l'option utf8.

    pg_dump --host localhost --port 5432 --username "postgres" --format custom \
      --blobs --encoding UTF8 --verbose --file "/path/to/formation_dump.backup" \
      "formation"

<div class="action"><p>
Testez la commande de restauration du dump avec les deux configurations <b>postgresql.orig.conf</b> et <b>postgresql.restore.conf</b>
</p></div>

A titre d'exemple sur un serveur Windows (donc pas le plus performant pour
postgreSQL) et avec un dump d'une base de 653MB – donnée obtenue avec un
`pg_size_pretty(pg_database_size('name'));` -- la différence de configuration
permet de passer de <b>10 minutes et 40s</b> à <b>2 minutes et 49s</b>
(8410 buffers dans le checkpoint). Sur la base formation avec 5000 commandes
le temps varie sur un poste Linux de <b>20s</b> à moins de <b>1s</b>.

.fx: wide

--------------------------------------------------------------------------------
Commande de test sur Windows:

    set foo1=%TIME%
    "C:/Program Files/PostgreSQL/9.0/bin\pg_restore.exe" --host localhost^
      --port 5432 --username "postgres" --dbname "formation" --disable-triggers^
      --no-data-for-failed-tables --clean --verbose "C:\Temp\formation_dump.backup"
    set foo2=%TIME%
    echo %foo1%
    echo %foo2%

Commande de test sur Linux:

    time  pg_restore --host localhost --port 5432 --username "postgres" \
     --dbname "formation" --disable-triggers --no-data-for-failed-tables \
     --clean --verbose /path/to/formation_dump .backup

On peut alors tester la parallélisation sur `pg_restore` avec l'option
`--jobs=nb` (uniquement pour les formats de dump « compress »). indiquez le
nombre de processeurs de votre serveur et essayez de le multiplier par deux
ensuite. Ce qui pourrait par exemple faire 4 jobs en parallèle pour la
restauration (attention on ne peut plus utiliser `--single-transaction` ici).

    time  pg_restore --host localhost --port 5432 --username "postgres" \
      --dbname "formation" --disable-triggers --no-data-for-failed-tables \
      --clean --verbose --jobs=4 /path/to/formation_dump.backup

.fx: wide

--------------------------------------------------------------------------------
Notez aussi qu'avec la configuration par défaut de **postgresql.conf** (la
version non optimisée pour un restore) il y a des chances pour que vous
n'observiez aucune différence avec la parallélisation. N'hésitez pas à augmenter
les chiffre si vous avez des CPU multithreadé et autres techniques multi-coeurs.

Pour ceux qui veulent plus d'infos sur les restaurations de grosses bases de
données voici [une histoire utile](http://www.depesz.com/index.php/2009/09/19/speeding-up-dumprestore-process/),
 dans cet exemple la restauration se situe sur une phase de `pg_upgrade`, donc
 un changement de version majeure de PostgreSQL qui demande un passage par le
 **dump & restore**.

--------------------------------------------------------------------------------

### pg_basebackup

Nous avons utilisé l'API bas niveau de PostgreSQL lors du backup en appelant
nous-même `pg_start_backup()` et `pg_stop_backup()`.

Il existe un utilitaire [`pg_basebackup`](https://docs.postgresql.fr/11/app-pgbasebackup.html) qui effectue des choses équivalentes, et qui sera utilisé
très souvent pour effectuer les sauvegardes de base servant à créer des réplicas:

    /usr/lib/postgresql/11/bin/pg_basebackup \
     --write-recovery-conf \
     --waldir="/mnt/serveur/backup2_pg_wal" \
     --wal-method=fetch \
     --format=plain \
     --label="backup via pg_basebackup plain" \
     --progress \
     --verbose \
     -h localhost -p 5432 -U postgres \
     --pgdata="/mnt/serveur/backup2/"

    /usr/lib/postgresql/11/bin/pg_basebackup \
     --write-recovery-conf \
     --wal-method=fetch \
     --format=tar --gzip \
     --label="backup via pg_basebackup tar" \
     --progress \
     --verbose \
     -h localhost -p 5432 -U postgres \
     --pgdata="/mnt/serveur/backup3/"

.fx: wide

--------------------------------------------------------------------------------

## 20.9. Intégrité des données

.fx: title2

--------------------------------------------------------------------------------

### intégrité des données

PostgreSQL s'assure que les données écrites sur le disque sont valides et bien
écrites, en travaillant à plusieurs niveaux ces vérifications d'écritures,
en stockant des pages mémoire dans les WAL, etc. Malheureusement une fois ces
données stockées sur le disque la prise en compte des défaillances du disque
n'est pas faite par PostgreSQL.

* [intégrité des wal](http://docs.postgresqlfr.org/11/wal.html#wal-reliability)
ici on trouvera des conseils divers sur les réglages de disques sur les
différents OS afin d'éviter par exemple que le disque stockant les WAL ne soit
en mode cache d'écriture.

Pensez aussi à spécifier les **options du système de fichier** dans les points de
montage. Ainsi un système ext3 sera plus rapide avec `--data=writeback, noatime,
nodiratime` sans que l'intégrité du système de fichier soit diminuée.

Depuis PostgreSQL 9.3 des sommes de contrôle CRC sont utilisés à divers endroits
pour se protéger des erreurs d'intégrité de données sur les disques (des bits
qui disparaîtraient). Depuis postgreSQL 11 on peut faire tourner un utilitaire
`pg_verify_checksums` sur un cluster éteint pour vérifier l'intégrité des données.

* [Des détails en anglais](https://bsdmag.org/page-checksum-protection-in-postgresql/)
 sur les vérifications d'intégrité de données. Où l'on voit qu'avec un `page checksum`
 actif PostgreSQL détectera les altérations de données dans les pages de la base
 mais ne fera pas les opérations de remise à zéro de ces pages sans interactions
 manuelles.

Notez qu'il faut l'option `--data-checksum` à la création du cluster pour avoir
ce fonctionnement. Cf [exemple](https://www.xf.is/convert-postgresql-cluster-to-use-page-checksums).

.fx: wide

--------------------------------------------------------------------------------
## 20.10. Exemple de Politique de backups

<small>Nous présentons ici une politique de backups. Il peut en exister
d'autres. Par exemple en n'activant ll'archivage des journaux de transactions
qu'au moment des backups.</small>

.fx: title2

--------------------------------------------------------------------------------
### 20.10.1. Backup incrémental

L'archivage des WAL est mis en place. A chaque fois qu'un fichier WAL de 16MB
est près ou qu'il est trop vieux il est recopié dans un répertoire externe à la
base (1er niveau de backup). Ce dossier est synchronisé sur un serveur distant
toutes les heures (2ème niveau de backup des WAL).

Les fichiers WAL sont compressés, et les fichiers trop vieux (voir ci-dessous la
 partie snapshot) seront effacés du serveur de backup.



--------------------------------------------------------------------------------
### 20.10.2. Snapshot

Toutes les nuits une **copie binaire des fichiers physiques** de la base devrait
être effectuée. Cette copie serait effectuée **en parallèle** du fonctionnement
de l'archivage des journaux de WAL en utilisant les commandes de backup de
PostgreSQL.

Grâce à cette copie binaire associée à l'archivage des WAL (backup incrémental),
 des restaurations PITR seront possibles. Le fait de disposer d'une version
binaire de la base à J-1 permet de n'avoir pas trop de journaux WAL à rejouer
lors des restaurations.

Suivant le nombre de jours que l'on veut pouvoir remonter sur un PITR on devra
organiser le backup des différentes versions binaires de la base et des WAL
associés (si on veut pouvoir remonter à n'importe quelle transaction survenue
entre J-7 et J il faut une version de la base à J-8 et tous les WAL intervenus
depuis).


--------------------------------------------------------------------------------
### 20.10.3. Dump

Le rythme pourrait être **quotidien**.

Extraction quotidienne d'un dump de la base au format compress (*.backup).

Le dump est capable de détecter une corruption de page.

Les dumps permettent une récupération plus simple que les solutions basées sur
les WAL et peuvent prendre le relais en cas de corruption du système de backup
des WAL.

Lors du dump tous les indexs sont parcourus et des « page faults » peuvent être
 détectées et faire échouer le dump.

En parallèle des dumps des différentes bases de données un `pg_dumpall` devrait
être lancé pour sauvegarder **les tables systèmes**, les **rôles et les GRANT**
d'accès aux bases.

    pg_dumpall --globals-only -f DESTINATION


--------------------------------------------------------------------------------
### 20.10.4. Réindexation

Une réindexation complète des bases, par exemple chaque semaine, peut permettre
d'éviter la corruption des index par un problème hardware. Lors d'un REINDEX les
index sont reconstruits de zéro. Si vous utilisez des index de type hash cela
évitera aussi des corruptions d'index suite à des restaurations.

Pour accélérer les opération de réindexation n'hésitez pas à modifier à la volée
 le paramètre `maintenance_work_mem` dans le script SQL avec une instruction
**SET**.

Lors du REINDEX les tables qui subissent ces ré-indexations sont lockées en
écriture mais pas en lecture. Cela signifie qu'il est possible de faire tourner
les réindexations en parallèle des opérations de dump. Pour une base madatabase
les commandes à utiliser sont:

    REINDEX SYSTEM madatabase;
    REINDEX DATABASE madatabse;

la commande **CLUSTER** par contre qui utiliserait un index pour réordonner le
contenu d'une table sur disque **bloquerait des opérations de lecture**
parallèles

--------------------------------------------------------------------------------
### 20.10.5. Restaurations

En s'appuyant sur la politique de backup présentée, en cas de problèmes nous
avons 4 cas:

* **cas 1)-** il s'agissait d'un **arrêt brutal du serveur** (oups le fil),
  nous allons relancer le serveur et tout sera remis en place par le `pg_xlog`
  ou `pg_wall`.
  Vous avez éteint le courant. Quand PostgreSQL va se relancer il va rejouer
  les transactions qui ne sont pas dans le stockage binaire des tables (en
  dehors des WAL qui ne sont pas passés au checkpoint la dernière écriture de
  **CHEKPOINT** en cours ne s'est peut-être même pas terminée proprement).
  **Vous n'avez rien à faire.** En fait il n'y a pas de problèmes, PostgreSQL
  travaille pour vous.

Maintenant examinons les 2 cas ou vous n'arrivez pas à relancer le serveur à
cause d'un problème un peu plus important. Par exemple le répertoire des
binaires ou le répertoire des `pg_xlog` ou `pg_wal` ont disparus (mauvaise journée quand
même...)

--------------------------------------------------------------------------------

* **cas 2)-** vous avez votre backup de premier niveau des WAL
  La commande d'archivage des WAL recopie les WAL quelque part, si vous avez
  encore ce « quelque part » vous n'avez pas tout perdu. Vous avez avec vous
 **les journaux de transactions du backup incrémental** (leur âge est au pire de
 15 minutes (max_checkpoint)) et vous avez **le dernier snapshot de la base**
 qui a eu lieu la nuit dernière donc vieux d'un jour maximum.

La procédure résumée en ligne :
[http://www.postgresql.org/docs/11/static/continuous-archiving.html#BACKUP-PITR-RECOVERY](http://www.postgresql.org/docs/11/static/continuous-archiving.html#BACKUP-PITR-RECOVERY)

Mais peut être possédez vous une procédure encore plus détaillée, adaptée à
votre cas, que vous avez déjà testé au moins une fois sur vos machines.

Nous avons déjà effectué cette procédure lors du teste de recovery. Ajoutons
simplement qu'il ne faut pas hésiter à faire une copie du répertoire `pg_xlog`
ou `pg_wal` du DATADIR actuel s'il est encore présent.

--------------------------------------------------------------------------------

* **cas 3)-** Vous **n'avez plus le backup des WAL de 1er niveau**.
  Allez chercher les WAL sur le 2ème niveau (serveur de backup).
  Vous devriez alors avoir **les journaux de transactions du backup
  incrémental** (leur âge est au pire de 1 jour si votre backup de 2ème niveau
  est quotidien, une heure s'il est horaire) et vous aurez **un snapshot de la
  base** qui sera vieux d'une semaine (au pire) à 1 jour (au mieux)

Procédure:

* Allez cherchez les données sur le serveur de backup
* Effectuez la même procédure que pour le cas2, sauf que vous aurez sans doute
  perdu un jour de transaction, ou bien une heure de transactions (suivant le
  rythme de votre backup de 2ème niveau des WAL).

Procédure **alternative**:

* utilisez **le dernier dump de la base**. Qui devrait être vieux d'un jour au pire

--------------------------------------------------------------------------------

* **cas 4)-** Vous avez **une corruption de donnée suite à un problème
 matériel**. Vous pouvez détecter ce type de problème suite à un pg_dumpall ou à
 un pg_dump, ou bien certaines requêtes sont rejetées avec des erreurs qui
 signalent que quelque chose est cassé.

* **a)** **suspendez l'accès** à PostgreSQL (modifiez le pg_hba.conf)
* **b)** essayez de **backuper le maximum de choses** de la base actuelle,
  mais le dump est cassé, donc:

* **--1.** fixer le problème matériel si cela est possible
* **--2.** démarrez par un snapshot binaire des fichiers de la base (utilisez
 les scripts de backups prévus pour cela)
* **--3.** essayez de triturer **pg_dump** pour qu'il sauve un maximum de choses.
 Par défaut `pg_dump` s'arrête sur un « page fault ». Nous allons dire à
 PostgreSQL de vider les données qui provoquent des « page fault » – ici nous
 perdrons des données – et de continuer le dump sur les données valides.
 Ajoutez temporairement le paramètre `zero_damaged_pages` dans postgresql.conf
 et redémarrez postgreSQL.

<div class="warning"><p>
<b>Perte de données.</b> Avec ce paramètre à chaque fois que PostgreSQL
rencontre une page cassée sur le disque il la vide. Alors que par défaut il
s'arrête.
</p></div>

    zero_damaged_pages=on

.fx: wide

--------------------------------------------------------------------------------

* **c)** faites un `pg_dumpall` complet (vous pouvez le faire avec
 `--globals-only`), vous aurez des avertissements, à chaque perte de données.
 N'oubliez pas de faire un **pg_dump au format 'c' compress** pour chaque base
 de données. Le format compress sera utilise pour les restaurations partielles
 alors que le pg_dumpall travaille en SQL pur.
* **d)** enlevez le paramètre `zero_damaged_pages` et redémarrez PostgreSQL
* **e)** Essayez d'identifier les données perdues. Un diff avec les précédents
 dump sauvegardés, retransformés en SQL pur à partir de serveurs différents,*
 peut vous aider
* **f)** faire un **REINDEX** sur tous les index existants ou sur les bases
 directement, il y a des chances que eux aussi aient été endommagés.
...

--------------------------------------------------------------------------------

On réindexe d'abord le catalogue. L'instruction de réindexation a besoin d'une
base de données en argument pour accéder au catalogue. Le catalogue est le même
sur toutes les bases, ce n'est donc pas la peine de relancer **REINDEX SYSTEM**
sur toutes les bases ensuite.

    REINDEX SYSTEM nomdunebasededonnees ;

Puis pour chaque base:

    REINDEX DATABASE dbname;

Si les index system (pg_catalog) sont cassés PostgreSQL pourrait refuser de
démarrer. Démarrez alors PostgreSQL avec l'option `-P` pour qu'il effectue des
vérifications sur les index system. Regardez aussi cette page pour voir ce que
vous pourriez faire:

[http://www.postgresql.org/docs/11/static/runtime-config-developer.html](http://www.postgresql.org/docs/11/static/runtime-config-developer.html)

* **g)** rétablissez le **ph_hba.conf** et relancez PostgreSQL
* **h)** faites une pause

.fx: wide

--------------------------------------------------------------------------------

## 20.11. Utiliser les WAL pour la réplication

.fx: title2

--------------------------------------------------------------------------------

Nous avons utilisé les WAL pour faire de la **restauration**.

Ce type de fonctionnement peut être étendu pour faire de la **réplication
maitre-esclave**.

Utiliser l'archivage des journaux de logs pour de la réplication signifie que
cette réplication sera **asynchrone** (il faut attendre l'archivage d'un certain
nombre de transactions et leur transfert sur l'esclave).

Cette réplication existe depuis PostgreSQL 8.2 grâce à l'utilitaire
 **pg_standby** et est appelée **WARM STANDBY**, avec un défaut important qui
est **l'impossibilité d'accéder au serveur esclave tant qu'il est en mode
réplication**, il faut effectuer une **bascule manuelle** de cet esclave pour
qu'il puisse prendre le relais du maître (il s'agit en fait d'une restauration
en continu, pour être prêt à reprendre le service plus rapidement).

PostgreSQL9 introduit une amélioration de cette réplication appelée
**HOT STANDBY** qui permet **l'accès en lecture au serveur esclave**.

Une deuxième amélioration consiste à utiliser la réplication par flux de
transactions (**STREAMING REPLICATION**) , et permet d'obtenir un **esclave sans
décalage dans le temps**.

Suivant les versions successives de PostgreSQL 9.x plusieurs améliorations
diverses ont eu lieu au niveau des processus de réplication
(*cascading streaming*, *streaming-only*, *multiple synchronous standbys*,
*replication slots*),
ainsi que l'ajout d'éléments de base pour les réplications master-master.

Il y a aussi la **réplication logique** qui est très différente.

.fx: wide

--------------------------------------------------------------------------------

De très bons articles publiés dans Linux Magazine France et rédigés en français
par Guillaume Lelarge donnent des procédure détaillées sur la mise en place de
tels système de réplication:

* [http://www.dalibo.org/hs44_la_replication_par_les_journaux_de_transactions](http://www.dalibo.org/hs44_la_replication_par_les_journaux_de_transactions)
* [http://www.dalibo.org/glmf131_mise_en_place_replication_postgresl_9.0_1](http://www.dalibo.org/glmf131_mise_en_place_replication_postgresl_9.0_1)
* [http://www.dalibo.org/glmf131_mise_en_place_replication_postgresl_9.0_2](http://www.dalibo.org/glmf131_mise_en_place_replication_postgresl_9.0_2)


--------------------------------------------------------------------------------
### 20.11.1. Limites

Pour que deux serveurs fonctionnent en mode réplication par les journaux de
transactions il faut qu'ils respectent certaines contraintes:

* il doivent avoir la même version majeure de PostgreSQL. Le format binaire des
  données pouvent être modifié lors d'un changement majeur de version.

**9.0**.4 et **9.0**.5 seront **compatibles**

**10**.4 et **10**.5 seront **compatibles**

**9.0**.4 et **9.1**.0 ne le sont **pas**, comme **10**.4 et **11**.2 non plus.

* il faut être consistant au niveau du stockage binaire (32bit litlle endian
 != 64 bits big endian).
* Une des autres limitation de ce type de réplication est qu'il concerne
 **l'ensemble d'un cluster PostgreSQL**, on ne travaille pas sur une base de
 données unique ou sur un set de tables unique (voir les replications par
 triggers type Slony et Londiste pour cela, ou la réplication logique).

--------------------------------------------------------------------------------
### 20.11.2. WARM STANDBY

Obtenir des serveurs en **WARM STANDBY** est assez proche de la problématique de
la restauration basée sur les WAL. Travaillez en binôme. L'un des deux serveurs
sera le maître et l'autre l'esclave. Ou bien montez [une deuxième instance
locale](https://stackoverflow.com/questions/37861262/create-multiple-postgres-instances-on-same-machine).

On commence par arrêter les serveurs PostgreSQL sur le maître et l'esclave.

Sur le maître on garde notre configuration où les WAL sont archivés avec
l'archive_command. Nous allons simplement modifier cette commande pour que
l'archivage sur fasse sur le serveur esclave si vous êtes en doublon.

Nous avions:

    archive_command = 'test ! -f /mnt/serveur/archive/%f && cp -i \
      %p /mnt/serveur/archive/%f </dev/null'

Nous le transformons en:

    archive_command = 'scp "%p" "serveuresclave:/mnt/serveur/archive/%f"'

Où `serveuresclave` est le nom ou l'adresse IP du serveur esclave.

Nous pourrions garder notre commande d'archivage en utilisant un système de
fichier réseau comme NFS pour monter le répertoire distant du serveur esclave
sur le **/mnt/serveur/archive** du maître.

.fx: wide

--------------------------------------------------------------------------------

### warm stand-by réseau

Toujourssi vous êtes en réseau, il faut aussi bien sur tester une commande scp
avec le user postgres à
destination de cette machine (par exemple en recopiant une vieiile archive que
nous avions dans notre /mnt/serveur/archive dans le même répertoire sur l'autre
machine). Nous avons écris un commande scp où la connexion ssh se fait sans
spécifier d'utilisateur ou de mot de passe, ceci est possible en configurant
une clef ssh pour l'utilisateur postgres et en la déployant sur le serveur
distant.

        > sudo su – postgres
        > ssh-keygen -t dsa
        # nous devrions obtenir une clef : /var/lib/postgresql/.ssh/id_rsa.pub
        # nous recopions cette clef sur le serveur esclave
        # (il faut le mot de passe root distant), c'est une commande sur
        # une seule ligne
        > scp /var/lib/postgresql/.ssh/id_dsa.pub \
         root@esclave:/tmp/id_dsa_master.pub

Sur le serveur esclave il faut installer cette clef de le HOME de l'utilisateur
`postgres`, dans le fichier `.ssh/authorized_keys`. Nous aurions pu automatiser
cette étape en utilisant `ssh-copy-id` depuis le serveur esclave, mais il
faudrait que l'utilisateur postgres possède un mot de passe.

.fx: wide

--------------------------------------------------------------------------------

### warm stand-by réseau

Sur le serveur esclave on passe donc root et on tape ces commandes:

    > sudo su -
    > # on en profite pour vider le répertoire d'archivage du serveur esclave.
    > rm -rf /mnt/serveur/archive/
    > # on devient l'utilisateur postgres pour installer
    > #les autorisations ssh
    > chown postgres /tmp/id_dsa_master.pub
    > su – postgres
    > mkdir ~/.ssh
    > cat /tmp/id_dsa_master.pub >> ~/.ssh/authorized_keys

Sur le serveur maître on teste que le scp fonctionne:

    > scp /mnt/serveur/archive/000000020000000000000050 \
     serveuresclave:/mnt/serveur/archive/

On peut alors relancer le serveur, l'archivage devrait se faire dans le dossier
`/mnt/serveur/archive` du serveur esclave (vous pouvez commencer à lancer le
script `populate_app.php`).

.fx: wide

--------------------------------------------------------------------------------

### warm stand-by local

Pour tester en local on créé une deuxième instance de postgreSQL 11.

    pg_createcluster -u postgres -g postgres \
      -d /var/lib/postgresql/11bis/main \
      -l /var/log/postgresql/postgresqlbis-11-main.log \
      -p 5436 \
      11 11bis
    pg_lsclusters

Si vous n'êtes pas sur une distribution de type Debian il faudra utiliser à la
place les vraies commandes PostgreSQL:

    initdb -D /var/lib/postgresql/11bis/main
    pg_ctl -D /var/lib/postgresql/11bis/main \
     -o "-p 5436" \
     -l /var/log/postgresql/postgresqlbis-11-main.log

.fx: wide

--------------------------------------------------------------------------------

### warm stand-by

On en profite aussi pour relancer notre script de backup afin d'avoir une copie
 binaire de la base à donner à l'esclave comme point de départ.

    > sudo ./backup.sh
    # puis on recopie ce backup binaire sur l'esclave, quelque part
    # en mode réseau
    > scp /mnt/serveur/backup/backup.tar \
      serveuresclave:/mnt/serveur/backup/
    # en local le fichier est déjà local, donc on ne fait rien

Sur l'esclave on modifie quelques éléments:

on utilise le backup binaire que l'on a reçu du maître pour initialiser le
contenu des fichiers physiques de la base

    cp /mnt/serveur/backup/backup.tar /backup.tar
    [root@localhost ~]# cd /
    # si vous êtes en mode réseau :
    [root@localhost /]# tar xfv backup.tar
    # si vous êtes en mode local :
    [root@localhost /]# tar xfv  backup.tar \
       --transform 's#postgresql/11/main#postgresql/11bis/main#'

Vérifiez que les deux serveurs sont **à la même heure!** Utilisez un protocole
comme **ntp** pour avoir des serveurs à l'heure.

.fx: wide

--------------------------------------------------------------------------------

### warm stand-by

Sur le serveur esclave de la réplication il faut une configuration différente.

On suspend l'archivage des WAL et on passe le `wal_level` à une valeur minimale.
Sur l'esclave on n'a pas besoin de générer une deuxième version des journaux de
transactions

    wal_level = minimal
    archive_mode = off
    hot_standby = off
    # si cette option existe et vaut autre chose
    # par exemple sur un postgresql11 qui par défaut est en mode replica
    max_wal_senders = 0

--------------------------------------------------------------------------------

### warm stand-by

<div class="warning"><p>
<b>ATTENTION:</b> en recopiant le dossier physique venant du maître on a
peut-être recopié son <b>pg_hba.conf</b> et son fichier <b>postgresql.conf</b>.
Il faut donc bien modifier ces valeurs de configuration après la copie.
Un script pourrait utiliser du sed, ou recopier un fichier de configuration
sauvegardé sous un autre nom.
</p></div>

Nous ne démarrons toujours pas le serveur sur l'esclave.
Au préalable il nous
faut **lui donner un fichier recovery.conf**, afin qu'il fonctionne comme un serveur
en mode restauration. Nous créons donc un fichier `recovery.conf` dans son
répertoire de données dans lequel nous indiquons une commande de restauration un
peu spéciale puisqu'elle utilise le programme `pg_standby`. (faites un
« locate pg_standby » pour trouver le votre, qui fait partie des programmes
contrib de postgreSQL).

    # cette commande tient sur une ligne
    restore_command = '/usr/lib/postgresql/11/bin/pg_standby -d -t \
     /tmp/trigger_stanby_end /mnt/serveur/archive %f %p %r \
     >>/var/log/postgresql/pg_standby.log 2>&1'

.fx: wide

--------------------------------------------------------------------------------

### warm stand-by

Nous pouvons voir que le programme va essayer de faire un log de ce qui lui
arrive dans `/var/log/postgresql/pg_standby.log`, on va donc initialiser ce
fichier et autoriser postgres à écrire dans ce fichier. On vérifiera aussi que
le DATADIR récupéré du maitre appartient bien à l'utilisateur postgres.

    > chown -R postgres /path/to/postgresql/data/*
    > touch /var/log/postgresql/pg_standby.log
    > chown postgres /var/log/postgresql/pg_standby.log

Enfin on peut démarrer notre serveur esclave

    /etc/init.d/postgresql start
    #ou
    systemctl start postgresql@11-main

Celui-ci se lance en mode restauration.

Pour visualiser ce que le serveur est en train de faire vous pouvez lancer ces
commandes:

    ps auxf|grep postgres
    tail -f /var/log/postgresql/pg_standby.log


.fx: wide

--------------------------------------------------------------------------------

### warm stand-by

Si la commande de population de la base (`populate_app.php`) tourne sur le
master on pourra visualiser l'arrivée progressive des WAL sur l'esclave.


Par contre toute tentative d'accès direct à la base esclave est impossible (ici
sur le 5432, mais si c'est un clone local c'est le 5436).

    psql -Upostgres -d postgres -p 5432

Par rapport à une restauration classique nous avons le programme `pg_standby`
qui est en fait en attente d'un fichier que nous lui avons indiqué dans la
commande. Tant que ce fichier « trigger file »  `/tmp/trigger_stanby_end`
 n'existe pas pg_standby force le serveur à rester en mode restauration (en
 attente de WAL), et donc le serveur est injoignable.

--------------------------------------------------------------------------------

### warm stand-by


Arrêtons la réplication en créant ce fichier:

    touch /tmp/trigger_stanby_end

On obtient alors une base **indépendante** de la base maître. La création de ce
**« fichier trigger »** est donc plutôt à la charge d'un service comme
**keepalived** qui démarre le service sur l'esclave lors d'une bascule.

Repasser l'esclave en statut esclave demande de **repartir d'un backup binaire du
maître.**

--------------------------------------------------------------------------------

### warm stand-by

Une **bascule retour (failback)** devrait être prévue dans vos procédures, sans
doute à partir d'une sauvegarde de ce nouveau maître (peut-être alors
faudra-t-il activer l'archivage des WAL sur cet esclave afin d'effectuer un
backup binaire)

<div class="warning"><p>
A noter: il existe des outils libres pour simplifier la mise en œuvre d'une
réplication <b>WARM STANDBY</b> : <b>walmgr</b> de Skype et <b>pitrtools</b> de
Command Prompt par exemple, ainsi que le programme <b>pg_basebackup</b>.
</p></div>

--------------------------------------------------------------------------------
### 20.11.3. HOT STANDBY

PostgreSQL 9 introduit une variation sur le **Warm Standby** qui est donc le
**Hot Standby**.

Dans ce mode la connexion au serveur esclave est possible et nous affiche le
contenu de la base en **décalé** (l'esclave ne dispose que des journaux transférés
– on parle de **log shipping**).

On peut réduire le décalage en jouant sur des paramètres **archive_timeout** de
l'ordre de quelques secondes sur le maître si les canal de transfert des
fichiers WAL est rapide entre le maître et l'esclave et que les scripts
d'archivage et de restauration font un nettoyage efficace des WAL qui ne sont
plus utiles.

--------------------------------------------------------------------------------

### hot standby

On commence par arrêter le serveur esclave qui est sans doute devenu maître à
la fin de l'exercice précédent, et on supprime le fichier
`/tmp/trigger_stanby_end`

On modifie le fichier `postgresql.conf` du maître pour passer à un niveau un
peu supérieur de WAL:

    wal_level = 'hot_standby' # version <10
    wal_level = 'replica' # version >=10

Puis comme dans le WARM STANDBY nous devons:

* **redémarrer** le serveur maître
* effectuer un **backup binaire**
* **transférer** ce backup sur l'esclave.
* **décompresser** le backup sur l'esclave
* s'assurer que tous les fichiers appartiennent bien à postgres

--------------------------------------------------------------------------------

### hot standby

Là nous allons modifier le fichier `postgresql.conf` de l'esclave pour lui
indiquer le paramétrage de l'esclave en hot_standby, en gras j'indique ce qui
change par rapport au warm standby:

<pre><code>wal_level = minimal
archive_mode = off
max_wal_senders = 0
<b>hot_standby = on</b>
</code></pre>

**Stoppez le serveur esclave.**
On le réinitialise avec cette fois la commande pg_basebackup.
Ici en mode local je dépose les fichiers directement dans le dossier de
l'esclave, en mode réseau il faut retransférer tout ça au bon endroit.

    rm -rf /var/lib/postgresql/11bis/main/
    mkdir /var/lib/postgresql/11bis/main/
    chown postgres:postgres /var/lib/postgresql/11bis/main/
    chmod 0700 /var/lib/postgresql/11bis/main/
    /usr/lib/postgresql/11/bin/pg_basebackup \
      --wal-method=fetch \
      --format=plain \
      --label="backup via pg_basebackup plain" \
      --progress \
      --verbose  \
      -h localhost -p 5435 -U postgres \
      --pgdata="/var/lib/postgresql/11bis/main/"


.fx: wide

--------------------------------------------------------------------------------

### hot standby

Comme avec le warm standby, nous aurons besoin d'un `recovery.conf` dans le
dossier des données de l'esclave, appartenant au user **postgres** et contenant:

    # cette commande tient sur une ligne
    restore_command = '/usr/lib/postgresql/11/bin/pg_standby -d -t \
     /tmp/trigger_stanby_end /mnt/serveur/archive %f %p %r \
     >>/var/log/postgresql/pg_standby.log 2>&1'

Puis:

    /etc/init.d/postgresql-11 start
    # ou
    systemctl start postgresql@11-11bis

Nous obtenons un serveur en lecture seule et en décalage léger avec le maître.

<div class="action"><p>
En utilisant populate_app.php sur le maître constatez les différences entre les
deux serveurs en effectuant des requête de <b>count(*)</b> sur
<b>app.commandes</b>.
</p></div>

.fx: wide

--------------------------------------------------------------------------------

### 20.11.4. STREAMING REPLICATION

Pour obtenir un serveur de type **hot standby** avec une **latence plus courte**,
un temps plus court de répercution des WAL, on peut donc réduire
**l'archive_timeout**. Mais une meilleure solution existe.

La **réplication par flux** va ajouter aux **Hot Standby** un **flux d'envoi
direct des transactions** (des wal) entre le maître et ses esclaves.

Au niveau du maître **des processus wal_sender** vont se charger d'envoyer des
informations en flux tendus à des **processus wal_receiver** situés au niveau
des esclaves.

Plusieurs nouveaux paramètres entrent en jeu:

* **max_wal_senders** : nombre de processus chargés de la synchronisation au
  niveau du maître (un par esclave)
* **wal_sender_delay** : délai d'attente, par défaut à 200ms entre chaque
  « exécution » du cycle de synchronisation, la valeur doit être un multiple
  de 10ms
* **wal_keep_segments** : nombre de WAL qui peuvent être conservés dans
  `pg_xlog` ou `pg_wal` pour la réplication par flux. Si l'esclave **prends du
  retard** et que les segments ne sont plus dans leur dossier il devra attendre la
  récupération via l'archivage des WAL (comme en hot_standby ou warm standby
  classique).
  Le défaut à 0 signifie que le maître ne fais pas attention à conserver ou pas
  des WAL pour la réplication par flux, il gère ces WAL dans le `pg_xlog` ou
  `pg_wall` comme
  d'habitude, en fonction des CHECKPOINT principalement.

.fx: wide

--------------------------------------------------------------------------------

### REPLICATION SLOTS

Imaginez un serveur maître.
Au départ si il dispose d'un commande `archive_command`, il peut se débarrasser
de ses fichiers wal dès lors que ceux-ci sont réputés sauvegardés à distance par
cette commande.

Il en garde quelques-uns en local pour assurer un reboot en cas de crash.

Maintenant ce serveur possède quelques serveurs esclaves, l'un de ces esclaves
peut se retrouver décalé dans le temps (par exemple ils est mis en pause).
Il aura besoin au redémarrage de wals assez anciens. Si ces wal anciens ne sont
plus disponibles pour le maître, il ne pourra **pas** les envoyer dans le flux
de réplication et la réplication sera en échec pour cet esclave.

L'arcive_command ets destinée à sauvegarder les wal, on pourrait avoir envoyé
tous les wal à tous les esclaves, pour êtr erejoués au cas où.

**On peut aussi prévoir de ne pas recycler les wals au niveau du serveur tant
qu'un des esclaves ne l'a pas reçu**. Et maintenir cette information sur la
rétention de wals par rapport aux différents clients de ces walls se manifeste
avec les [**replication slots**](https://www.opsdash.com/blog/postgresql-replication-slots.html), qui sont déclaratifs.

<div class="warning"><p>
Travailler avec des slots de réplication est <b>dangereux</b> si vous n'avez pas
une supervision opérationelle très active. Garder des wal en place sur le maître
avoir un slot de réplication qui se bloque <a href="https://saifulmuhajir.web.id/postgresql-inactive-replication-slot-the-butterfly-effect/">peut avoir des effets indésriables</a>.
</p></div>

 .fx: wide

--------------------------------------------------------------------------------

### STREAMING REPLICATION

Si l'esclave ne fonctionne qu'avec **un** wal_receiver et sans
**restore_command** capable de récupérer des WAL archivés il faut absolument
spécifier un nombre **assez élevé** dans wal_keep_segments afin d'éviter de
désynchroniser un esclave en cas de charge d'écriture importante qu'il n'aura
su effectuer dans les temps.

Cette réplication 'en flux tendu' va demander des connexions depuis l'esclave
vers le maître. Il faut donc que l'esclave utilise **un compte utilisateur**
(éventuellement avec un mot de passe) et que le maître autorise la connexion
avec cet utilisateur depuis l'adresse IP de l'esclave.

Il va donc nous falloir éditer le `pg_hba.conf du maître`. L'accès se fait sur
une base *'spéciale'* nommée **replication**. Nous ajoutons donc en fin de
fichier **pg_hba.conf** cette ligne (adaptez l'adresse IP à votre cas):

    # TYPE  DATABASE        USER            CIDR-ADDRESS            METHOD
    host    replication     ultrogothe        192.168.1.13/24            trust

On ajoute ensuite les premiers processus d'envoi des WAL en flux dans le
**postgresql.conf** du maître (qui est déjà configuré pour du hot_standby):

    max_wal_sender = 10

.fx: wide

--------------------------------------------------------------------------------

Faites un restart du serveur PostgreSQL du maître

    systemctl restart postgresql@11-main

Si nous regardons du côté du serveur esclave nous avons toujours notre esclave
en **HOT STANDBY**, avec un **recovery.conf actif**. Nous allons devoir
l'adapter au niveau de son **recovery.conf** pour qu'il se mette **en écoute du
flux de transactions du maître**.

Nous allons le configurer pour la réplication de flux en indiquant quelques
paramètres supplémentaires dans ce fichier, dont le principal est **standby_mode**.

A partir du moment où nous entrons dans ce mode l'utilitaire **pg_standby** que
nous utilisions pour le **HOT STANDBY** n'est **plus utile** (on a de nouvelles
options de configurations pour le trigger file par exemple) et la commande de
restauration se simplifie pour n'être plus qu'une simple copie des fichiers
d'archive:

On modifie donc le **recovery.conf** (pas le **postgresql.conf*) de cette façon
(ici 192.168.1.10 est l'IP du maître):

    standby_mode = 'on'
    restore_command = 'cp /mnt/serveur/archive/%f %p'
    primary_conninfo = 'host=192.168.1.10 port=5432 user=ultrogothe'
    trigger_file = '/tmp/trigger_stanby_end'
recovery_target_timeline = 'latest'
.fx: wide

--------------------------------------------------------------------------------

Il faut un user superutilisateur de la base, et sur les dernières versions il faut même un droit spécial de réplication. Donnons ce droit à ultrogothe sur le maître:

    ALTER ROLE ultrogothe
	    REPLICATION;

Consultez les logs de l'esclave pour d'éventuels problèmes de connexion et pour
observer la réplication (faires un grep replication sur les fichiers de log).


<div class="action"><p>
Faites tourner populate_app.php et faites des requêtes de comptage sur le maître
 et l'esclave, observez la réplication qui semble instantanée.
</p></div>

Cela nous permet de faire un premier aperçu de la réplication par PostgreSQL.

Nous obtenons une réplication maître esclave quasi-synchrone. Le risque étant un
décalage sur le serveur esclave à cause de requêtes en lecture longues qui
posent des locks sur des opérations d'écritures importantes. Une fois encore
je citerai [l'article de Guillaume Lelarge](http://www.dalibo.org/glmf131_mise_en_place_replication_postgresl_9.0_2)
Vous trouverez dans cet article des réglages assez fins des problématiques de
**lock de lecture** (sic) et des principes de bascules **(switchover, failover,
 failback)**.

.fx: wide

--------------------------------------------------------------------------------
## 20.12. Autres systèmes de réplication

.fx: title2

--------------------------------------------------------------------------------

D'autres système de réplication existent autour de PostgreSQL. Certains sont
utilisées depuis très longtemps. On citera les principaux:

* **SLONY** : **réplication par les triggers**. Historiquement Slony était le
 principal outil de réplication pour les solutions Web sur lesquelles on voulait
disposer d'un esclave accessible en lecture et synchrone avec les modifications
de la base. Slony impose de ne pas modifier le schéma de la base et de disposer
d'une liste des tables et des clefs primaires de chaque table.
Slony se charge ensuite, base par base, table par table, de répercuter les
modifications quand elles arrivent sur les esclaves (un serveur peut être maître
d'une base ou d'une partie des tables de la base, et esclaves sur d'autres bases
et/ou tables). **Ce qu'on retrouve dans postgreSQL11 avec la replication logique.**
* **Pgpool II** : **réplication des requêtes**. Pgpool est un **pooler de
 connexions**, une des fonctionnalités offertes par un pooler est de répercuter
 sur tous les serveurs d'une grappe l'ensemble des requêtes effectuant des
 opérations en écriture. Si toutes les connexions passent bien par le pooler et
 que les requêtes ne font pas appel à des valeurs aléatoires on obtient des
 bases identiques.
* **Londiste** : **réplication par les triggers**. Utilitaire de réplication de
 Skype. Sa configuration est plus simple que celle de SLONY, par contre sa
 documentation est encore plus succinte que celle de SLONY, qui n'est déjà pas
 un modèle du genre.

.fx: wide

--------------------------------------------------------------------------------

* **Bucardo**: réplication **master-master** : le système le plus **complexe**
  et le **plus avancé**, vous obtenez un cluster de serveurs PostgreSQL dans
  lequel vous pouvez effectuer vos écritures sur n'importe quel serveur
* **DRBD** : DRBD est une solution de **réplication des disques entre serveurs**,
  il ne s'agit donc pas d'une réplication de base de donnée. Les deux serveurs,
  le maître et l'esclave, partagent **un même disque dur**. Toutes les écritures
  effectuées sur le disque du maître sont répliquées sur le disque de l'esclave.
  On utilise le plus souvent DRBD pour faire des bascules d'urgence, l'esclave
  peut à tout moment reprendre la main sur le maître avec une bascule de type
  **keepalived**, il devient le maître de DRBD et peut alors lancer sa propre
  version de la base qui disposera des mêmes fichiers physiques (un partage
  DRBD devrait **inclure le partage du pg_xlog ou pg_wal** pour éviter d'avoir
  à faire une
  restauration). Certains système des fichiers avancés comme **OCFS-2** peuvent
  supporter des écritures concurrentes sur le partage DRBD, mais il serait
  dangereux d'utiliser DRBD dans ce sens avec des systèmes de base de données.


--------------------------------------------------------------------------------
## 20.13. Autres outils

.fx: title2

--------------------------------------------------------------------------------
### 20.13.1. Monitorer PostgreSQL

* [http://bucardo.org/wiki/Check_postgres](http://bucardo.org/wiki/Check_postgres)

Pour intégrer la supervsion de PostgreSQL dans vos solutions de monitoring le
principal outil sera la sonde **Nagios** **check_postgres**, sonde écrite en
**Perl** (mais très orientée Linux). Cette sonde est maintenue par **Bucardo**,
un des acteurs majeurs du monde PostgreSQL. L'ensemble des vérifications pouvant
être effectuées est assez important. Vous devrez créer plusieurs services Nagios
utilisant cette sonde de différentes manière. Ces différentes vérifications sont
les Actions de la sonde dont vous pouvez [voir la liste sur cette page](http://bucardo.org/check_postgres/check_postgres.pl.html).

En terme de **supervision passive (graphiques)** on pourra consulter ces liens:

* [http://wiki.postgresql.org/wiki/Cacti](http://wiki.postgresql.org/wiki/Cacti) (Cacti)
* [http://munin-monitoring.org/wiki/PluginCat](http://munin-monitoring.org/wiki/PluginCat) (Munin)
* [http://muninpgplugins.projects.postgresql.org/](http://muninpgplugins.projects.postgresql.org/) (Munin)
* [http://tigreraye.org/Modules%20PostgreSQL%20pour%20Munin](http://tigreraye.org/Modules%20PostgreSQL%20pour%20Munin) (Munin)

On trouvera beaucoup plus de ressources, et d'un meilleur niveau, pour Munin que
pour Cacti.

--------------------------------------------------------------------------------
### pg_monitor

Un rôle spécial a été créé (v 10) pour autoriser la collecte d'informations.

    GRANT pg_monitor TO user;

> The pg_monitor, pg_read_all_settings, pg_read_all_stats and
> pg_stat_scan_tables roles are intended to allow administrators to easily 
> configure a role for the purpose of monitoring the database server. They 
> grant a set of common privileges allowing the role to read various useful 
> configuration settings, statistics and other system information normally 
> restricted to superusers.

--------------------------------------------------------------------------------
### 20.13.2. PgSnap!

* [http://pgsnap.projects.postgresql.org/](http://pgsnap.projects.postgresql.org/)
* [http://pgsnap.projects.postgresql.org/pagila2_snap_20111029/](http://pgsnap.projects.postgresql.org/pagila2_snap_20111029/) (démo)

PGSnap! Est un programme PHP qui **génère un rapport sur l'état de la base**.

Je devrais plutôt dire qu'il génère un ensemble de rapports. Il s'agit d'un bon
outil complémentaire de la supervision et qui permettra à un DBA d'avoir une
vision de ses serveurs à la fois synthétique et détaillée pour les éventuels
problèmes.

Parcourez la démonstration pour découvrir les différents rapports. Remarquez la
possibilité de demander les requêtes effectuées sur le catalogue pour pouvoir
les réutiliser de votre côté en les adaptant.

--------------------------------------------------------------------------------
### 20.13.3. pgbadger

* [http://dalibo.github.io/pgbadger/](http://dalibo.github.io/pgbadger/)
* [https://github.com/dalibo/pgbadger](https://github.com/dalibo/pgbadger)
* [démo](https://github.com/dalibo/pgbadger)


Si vous trouvez PgSnap sympa et intéressant, **pgBadger** est en fait là pour
faire **la même chose en mieux**.

Il s'agit d'un analyseur de logs, qui va générer un rapport très complet et très
graphique sur de nombreux éléments (requêtes gourmandes, répartition du traffic
par type de requêtes, ar application, stats internes, vacuums, etc)

Comme pour beaucoup d'analyseurs de logs, avec une base qui génère des logs
quotidiens volumineux il faudra tester un fonctionnement.

Par exemple mettre en place la génération du rapport chaque jour, et la rotation
de logs de requêtes sur une journée max, retirer une partie des logs et donc
du rapport, etc.

--------------------------------------------------------------------------------
### 20.13.4. pgmetrics

Un utilitaire en ligne de commande pour rappatrier beaucoup d'informations utiles.

[https://pgmetrics.io/](https://pgmetrics.io/)

    wget https://github.com/rapidloop/pgmetrics/releases/download/v1.10.4/pgmetrics_1.10.4_linux_amd64.tar.gz
    tar xvf pgmetrics_1.10.4_linux_amd64.tar.gz
    cd pgmetrics_1.10.4_linux_amd64
   ./pgmetrics --help

--------------------------------------------------------------------------------
### 20.13.5. PgAgent

* [https://www.pgadmin.org/docs/pgadmin3/1.22/pgagent.html](https://www.pgadmin.org/docs/pgadmin3/1.22/pgagent.html)

**PgAgent** est un programme complémentaire de **pgAdmin** qui permet la mise en
place de **scripts de maintenance récurrents**. On peut l'utiliser pour
planifier des scripts SQL de traitements batchs, ou pour simplement faire des
appels à des procédures stockées de batchs. PgAgent peut aussi lancer des
scripts systèmes et découper ses « jobs » en plusieurs étapes (steps).


--------------------------------------------------------------------------------
### 20.13.6. PgPool II

* [http://pgpool.projects.postgresql.org/](http://pgpool.projects.postgresql.org/)
* [http://pgpool.projects.postgresql.org/pgpool-II/doc/pgpool-fr.html](http://pgpool.projects.postgresql.org/pgpool-II/doc/pgpool-fr.html)

**pgpool II** est un **pooler de connexions**.

Un des apports important d'un pooler de connexion est de pouvoir mettre en
attente les demandes de connexions supplémentaires plutôt que de les rejeter.
Vous obtiendrez, en cas d'un nombre de connexions trop élevé, des lenteurs
d'accès (plus ou moins longue suivant le dépassement), mais aucun message
d'erreur. Il y a un effet de **lissage**.

L'autre apport utile consiste à utiliser le pooler pour de la **répartition de
charge** sur un ensemble de serveurs. Si vous disposez d'esclaves en lecture
seule avec des données synchrones, le pooler pourra répartir la charge des
requêtes **hors-transaction** sur ces serveurs (les select au sein de
transactions devant bien sur rester sur le serveur de la transaction).

Enfin l'apport premier d'un pooler est de maintenir des connexions ouvertes sur
le serveur pour éviter les latences dues au **temps d'établissement de ces
connexions**.

Mais si vous lisez en détail la documentation de pgpool II vous découvrirez
certainement de nombreuses autres applications utiles (réplication des requêtes,
parallélisation de traitement, bascules failover, etc).


--------------------------------------------------------------------------------
### 20.13.7. pgfouine

* [http://pgfouine.projects.postgresql.org/](http://pgfouine.projects.postgresql.org/)
pgFouine est un programme PHP, c'est un analyseur de logs.

Examinez les démonstrations de rapports générés par pgFouine sur cette page http://pgfouine.projects.postgresql.org/reports.html

Comme pgSnap c'est un outil qui est sans doute dépassé par bdPadger, mais que
l'on trouve encore pour raisons historiques.

--------------------------------------------------------------------------------
### 20.13.8. d'autres?

* [https://wiki.postgresql.org/wiki/Performance_Analysis_Tools](https://wiki.postgresql.org/wiki/Performance_Analysis_Tools)
* [https://wiki.postgresql.org/wiki/Monitoring](https://wiki.postgresql.org/wiki/Monitoring)
