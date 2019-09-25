<?php
// Simple PHP script used to fill the datatabase
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
define('NUMBER_OF_COMMANDES',5000);
define('SHOW_STEP',50);
define('DROP_ALL_COMMANDS_BEFORE',TRUE);
define('INITIALIZE_POINTS',TRUE);

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

/* POPULATE DATABASE WITH REQUESTED NUMBER OF COMMANDES */
function populate($dbconn) {
    if (DROP_ALL_COMMANDS_BEFORE) {
        echo "->Cleaning up previous commands (...)\n";
        pg_query($dbconn,'DELETE FROM COMMANDES');
    }
    if (INITIALIZE_POINTS) {
        echo "->Put everyone to score 0\n";
        pg_query($dbconn,'UPDATE vue_drh_points SET points=0');
    }
    echo "->Generates\n";
    populate_prepare_queries($dbconn);
    for ($i=1;$i<= NUMBER_OF_COMMANDES;$i++) {
        echo ".";
        if (0==($i % (int)SHOW_STEP)) echo '['.$i.']';
        $per_id = populate_choose_personnel($dbconn);
        populate_create_commande($dbconn,$per_id);
        if (0==($i % (int)SHOW_STEP)) echo "\n";
    }
}
/* OPTIMISATION AND SECURITY: INSERT COMMANDS ARE PREPARED */
function populate_prepare_queries($dbconn) {
    // INSERT IN COMMANDES
    pg_prepare($dbconn, "insert_commandes", 'INSERT INTO commandes (per_id,com_date,com_date_expedition,com_date_facturation,com_statut,com_statut_facturation)'
      .' VALUES ($1,$2,$3,$4,$5,$6) RETURNING com_id');
    // INSERT IN LIGNES_COMMANDE
    pg_prepare($dbconn, "insert_lignes_commande", 'INSERT INTO lignes_commande (lic_quantite,pro_id,com_id,lic_est_reduction,lic_prix_unitaire)'
      .' VALUES ($1,$2,$3,$4,$5) RETURNING lic_id');
}

/* CHOOSE 1 GUY IN PERSONNELS FOR THE COMMAND */
function populate_choose_personnel($dbconn) {
    // get a random guy
    $query = 'SELECT per_id FROM app.vue_drh_tableau_personnel ORDER BY RANDOM() LIMIT 1';
    $result = pg_query($query) or die('Échec de la requête : ' . pg_last_error());
    $line = pg_fetch_array($result, null, PGSQL_ASSOC);
    $per_id = $line['per_id'];
    // Libère le résultat
    pg_free_result($result);
    return $per_id;
}

/* POPULATE DATABASE WITH ONE COMMAND AND SEVERAL LIGNES_COMMANDE */
function populate_create_commande($dbconn,$per_id) {
    // create the command cf populate_prepare_queries()
    $expedition = rand(0,1);
    $facturation = rand(0,1);
    // get some random dates for the commande
    $sql = 'SELECT tmp.start_date AS com_date, '
           ." tmp.start_date + (ceil(random()*10)||' days '||ceil(random()*10)||' hours '||ceil(random()*10)||' minutes')::interval as com_date_expedition,"
           ." tmp.start_date + (ceil(random()*10)||' days '||ceil(random()*10)||' hours '||ceil(random()*10)||' minutes')::interval as com_date_facturation"
           ." FROM ("
           ."  SELECT CURRENT_TIMESTAMP "
           ."  - ( ceil(random()*10)||' mon '||ceil(random()*10)||' days '||ceil(random()*10)||' hours '||ceil(random()*10)||' minutes')::interval"
           ."  as start_date"
           .") tmp";
    $result = pg_query($sql) or die('Échec de la requête : ' . pg_last_error());
    $line = pg_fetch_array($result, null, PGSQL_ASSOC);
    $com_date = $line['com_date'];
    $com_date_expedition = ($expedition)? $line['com_date_expedition'] : null;
    $com_date_facturation = ($facturation)? $line['com_date_facturation'] : null;
    pg_free_result($result);
    $statut = 'en attente';
    $statutfact = 'non facturée';

    if ($expedition) {
        $statut = 'expédiée';
    } else {
        switch(rand(0,2)) {
            case 0:
                $statut = 'en attente';
            break;
            case 1:
                $statut = 'en préparation';
            break;
            case 2:
                $statut = "prête à l'envoi";
            break;
        }
    }
    if ($facturation) {
        $statutfact = rand(0,1)? 'facturée' : 'payée';
    }
    // Exécute la requête préparée. Notez qu'il n'est pas nécessaire d'échapper
    $result = pg_execute($dbconn, "insert_commandes", array(
        $per_id,
        $com_date,
        $com_date_expedition,
        $com_date_facturation,
        $statut,
        $statutfact
    ));
    // we have an insert RETURNING, so we have the command id in the result
    $line = pg_fetch_array($result, null, PGSQL_ASSOC);
    $com_id = $line['com_id'];

    // first add products lines
    $nb_lignes = rand(0,15);
    $products = populate_choose_products($dbconn,$nb_lignes);
    foreach($products as $product) {
        $quantite = rand(1,10);
        $lic_prix_unitaire = populate_choose_price($dbconn,$product);
        populate_create_ligne_commande($dbconn,$com_id,$product['pro_id'],$quantite,$lic_prix_unitaire);
    }
    // now add some reductions
    $nb_lignes = rand(0,2);
    $products = populate_choose_products($dbconn,$nb_lignes,true);
    foreach($products as $product) {
        $quantite = 1;
        $lic_prix_unitaire = populate_choose_price($dbconn,$product,true);
        populate_create_ligne_commande($dbconn,$com_id,$product['pro_id'],$quantite,$lic_prix_unitaire,true);
    }
}
/* GET A RANDOM PRODUCT FROM DB TABLE */
function populate_choose_products($dbconn,$nb_products,$is_reduction=false) {
    // get at most $nb_products in RANDOM order
    $reduc = ($is_reduction)? 'pro_est_reduction' : 'NOT pro_est_reduction OR pro_est_reduction IS NULL';
    $query = 'SELECT * '
        . ' FROM app.produit '
        . ' WHERE ' . $reduc
        . ' ORDER BY RANDOM() '
        . ' LIMIT '. (int) $nb_products;
    $result = pg_query($query) or die('Échec de la requête : ' . pg_last_error());
    $products = array();
    while ($line = pg_fetch_array($result, null, PGSQL_ASSOC)) {
        $products[] = $line;
    }
    // Libère le résultat
    pg_free_result($result);
    return $products;
}
/* CHOOSE A REAL PRICE FROM THE OFFICIAL PRICE (price may have move in the past) */
function populate_choose_price($dbconn,$product,$is_reduction=false) {
    $price = $product['pro_prix_unitaire'];
    return $price;
}

/* Now that we have all elements required, create a line for the command */
function populate_create_ligne_commande($dbconn,$com_id,$pro_id,$quantite,$lic_prix_unitaire,$is_reduction=false) {
    // create the lignes_command cf populate_prepare_queries()
    // Exécute la requête préparée. Notez qu'il n'est pas nécessaire d'échapper
    //order is (lic_quantite,pro_id,com_id,lic_est_reduction,lic_prix_unitaire)
    $result = pg_execute($dbconn, "insert_lignes_commande", array(
        $quantite,
        $pro_id,
        $com_id,
        ($is_reduction)? 'TRUE':'FALSE',
        $lic_prix_unitaire,
    ));

}

function sowsummary($dbconn) {
    // Exécution de la requête SQL
    $query = 'SELECT COUNT(*) as nb FROM app.commandes';
    $result = pg_query($query) or die('Échec de la requête : ' . pg_last_error());
    echo "\nCommandes:";
    $line = pg_fetch_array($result, null, PGSQL_ASSOC);
    echo $line['nb']."\n";
    // Libère le résultat
    pg_free_result($result);

    $query = 'SELECT COUNT(*) as nb FROM app.lignes_commande';
    $result = pg_query($query) or die('Échec de la requête : ' . pg_last_error());
    echo "Lignes de commandes:";
    $line = pg_fetch_array($result, null, PGSQL_ASSOC);
    echo $line['nb']."\n";
    // Libère le résultat
    pg_free_result($result);
}

// MAIN PROGRAM **********
$dbconn = connect();
populate($dbconn);
sowsummary($dbconn);
endprogram($dbconn);
