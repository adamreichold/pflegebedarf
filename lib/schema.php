<?php

function schema_anlegen()
{
    global $pdo;

    error_log('Neue Datenbank v1 wird angelegt...');

    $pdo->beginTransaction();

    $pflegemittel = <<<SQL
CREATE TABLE pflegemittel (
    id INTEGER PRIMARY KEY,
    bezeichnung TEXT NOT NULL,
    einheit TEXT NOT NULL
)
SQL;

    $pdo->exec($pflegemittel);

    $bestellungen = <<<SQL
CREATE TABLE bestellungen (
    id INTEGER PRIMARY KEY,
    zeitstempel INTEGER NOT NULL,
    empfaenger TEXT NOT NULL
)
SQL;

    $pdo->exec($bestellungen);

    $bestellungen_zeitstempel = <<<SQL
CREATE INDEX bestellungen_zeitstempel ON bestellungen (zeitstempel)
SQL;

    $pdo->exec($bestellungen_zeitstempel);

    $bestellungen_posten = <<<SQL
CREATE TABLE bestellungen_posten (
    bestellung_id INTEGER,
    pflegemittel_id INTEGER,
    menge INTEGER NOT NULL,
    PRIMARY KEY (bestellung_id, pflegemittel_id),
    FOREIGN KEY (bestellung_id) REFERENCES bestellungen (id),
    FOREIGN KEY (pflegemittel_id) REFERENCES pflegemittel (id)
)
SQL;

    $pdo->exec($bestellungen_posten);

    $pdo->exec('PRAGMA user_version = 1');

    $pdo->commit();
}

function schema_v1_migrieren()
{
    global $pdo;

    error_log('Datenbank v1 wird auf v2 migriert...');

    $pdo->beginTransaction();

    $pflegemittel = <<<SQL
ALTER TABLE pflegemittel ADD COLUMN wird_verwendet INTEGER NOT NULL DEFAULT 1
SQL;

    $pdo->exec($pflegemittel);

    $pdo->exec('PRAGMA user_version = 2');

    $pdo->commit();
}

function schema_v2_migrieren()
{
    global $pdo;

    error_log('Datenbank v2 wird auf v3 migriert...');

    $pdo->beginTransaction();

    $bestellungen = <<<SQL
ALTER TABLE bestellungen ADD COLUMN nachricht TEXT NOT NULL DEFAULT ''
SQL;

    $pdo->exec($bestellungen);

    $pdo->exec('PRAGMA user_version = 3');

    $pdo->commit();
}

function schema_v3_migrieren()
{
    global $pdo;

    error_log('Datenbank v3 wird auf v4 migriert...');

    $pdo->beginTransaction();

    $pflegemittel = <<<SQL
ALTER TABLE pflegemittel ADD COLUMN pzn_oder_ref TEXT
SQL;

    $pdo->exec($pflegemittel);

    $pdo->exec('PRAGMA user_version = 4');

    $pdo->commit();
}

function schema_pruefen()
{
    global $pdo;

    $user_version = $pdo->query('PRAGMA user_version')->fetch()->user_version;

    switch ($user_version)
    {
        case 0:
            schema_anlegen();
        case 1:
            schema_v1_migrieren();
        case 2:
            schema_v2_migrieren();
        case 3:
            schema_v3_migrieren();
        case 4:
            break;
        default:
            die("Unbekannte Version {$user_version} der Datenbank.");
    }
}

function mit_datenbank_verbinden()
{
    global $pdo;

    $pdo = new PDO('sqlite:/var/lib/pflegebedarf/datenbank.sqlite');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_OBJ);

    schema_pruefen();
}

mit_datenbank_verbinden();
