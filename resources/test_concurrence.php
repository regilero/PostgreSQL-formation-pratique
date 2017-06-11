<?php
// Simple PHP script used to test concurrency problems
//
// Simplified BSD Licence
//----------------------------
// Copyright (c) 2012, Makina Corpus
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
//    Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
//    Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
define('PG_CONNECT_STRING','host=localhost dbname=formation port=5432 user=ultrogothe password=ultrogothe');
define('NUMBER_OF_COMMANDES',50);
define('SHOW_STEP',10);

/* CONNECT AND DISCONNECT */
function connect() {
    echo "Connect to ".PG_CONNECT_STRING."\n";
    // Connexion, sélection de la base de données
    $dbconn = pg_connect(PG_CONNECT_STRING) or die('Connexion impossible : ' . pg_last_error());
    return $dbconn;
}
function endprogram($dbconn) {
    // Ferme la connexion
    if (isset($dbconn)) {
        pg_close($dbconn);
    }
    echo "Bye!\n";
}

/* POPULATE DATABASE */
function populate($dbconn) {
    populate_prepare_queries($dbconn);
    echo "->Choose commande:";
    $com_id = populate_choose_min_commande($dbconn);
    echo $com_id . "\n";
    echo "->Generating\n";
    for ($i=1;$i<= NUMBER_OF_COMMANDES;$i++) {
        echo ".";
        if (0==($i % (int)SHOW_STEP)) echo '['.$i.']';
        populate_modify_quantity_in_ligne_commande($dbconn,$com_id);
        detect_incoherence($dbconn,$com_id);
        if (0==($i % (int)SHOW_STEP)) echo "\n";
    }
}
/* OPTIMISATION AND SECURITY: INSERT COMMANDS ARE PREPARED */
function populate_prepare_queries($dbconn) {
    // UPDATE COMMAND POINTS
    pg_prepare($dbconn, "update_lignes_commande_quantite", 'UPDATE app.lignes_commande SET lic_quantite=lic_quantite+$1 WHERE com_id=$2 '
    .' AND lic_id IN ( SELECT lic_id FROM app.lignes_commande WHERE com_id=$2 AND NOT lic_est_reduction ORDER BY RANDOM() LIMIT 1) ');
}

/* CHOOSE the command to run concurrency tests */
function populate_choose_min_commande($dbconn) {
    // get the minimum command id
    $query = 'SELECT min(com_id) as mincomid FROM app.commandes';
    $result = pg_query($query) or die('Échec de la requête : ' . pg_last_error());
    $line = pg_fetch_array($result, null, PGSQL_ASSOC);
    $com_id = $line['mincomid'];
    // Libère le résultat
    pg_free_result($result);
    return $com_id;
}
function populate_modify_quantity_in_ligne_commande($dbconn,$com_id) {
    // Exécute la requête préparée. Notez qu'il n'est pas nécessaire d'échapper
    $result = pg_execute($dbconn, "update_lignes_commande_quantite", array(
        rand(1,10),
        $com_id,
    ));
    // Libère le résultat
    pg_free_result($result);
}
function detect_incoherence($dbconn,$com_id) {
    // get the minimum command id
    $query = 'SELECT co.com_id,co.com_total_ht as tot1,sum(lc.lic_total) as tot2'
            .' FROM app.commandes co '
            .' INNER JOIN app.lignes_commande lc ON lc.com_id=co.com_id '
            .' WHERE co.com_id = ' . (int) $com_id
            .' GROUP BY co.com_id,co.com_total_ht;';
    $result = pg_query($query) or die('Échec de la requête : ' . pg_last_error());
    $line = pg_fetch_array($result, null, PGSQL_ASSOC);
    $tot1 = $line['tot1'];
    $tot2 = $line['tot2'];
    if ($tot1!=$tot2) {
        echo "\n ETAT INCOHERENT DETECTE!! $tot1 :: $tot2 \n";
    }
    // Libère le résultat
    pg_free_result($result);
    return $com_id;
}

// MAIN PROGRAM **********
$dbconn = connect();
populate($dbconn);
endprogram($dbconn);
