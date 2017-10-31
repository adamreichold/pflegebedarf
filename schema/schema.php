<?php

function schema_anlegen()
{
    global $pdo;

    error_log('Neue Datenbank wird angelegt...');

    $pflegemittel = <<<SQL
CREATE TABLE pflegemittel (
    id INTEGER PRIMARY KEY,
    bezeichnung TEXT,
    einheit TEXT
)
SQL;

    $pdo->exec($pflegemittel);

    $bestellungen = <<<SQL
CREATE TABLE bestellungen (
    id INTEGER PRIMARY KEY,
    zeitstempel INTEGER,
    empfaenger TEXT
)
SQL;

    $pdo->exec($bestellungen);

    $bestellungen_zeitstempel = <<<SQL
CREATE INDEX bestellungen_zeitstempel ON bestellungen (zeitstempel);
SQL;

    $pdo->exec($bestellungen_zeitstempel);

    $bestellungen_posten = <<<SQL
CREATE TABLE bestellungen_posten (
    bestellung_id INTEGER,
    pflegemittel_id INTEGER,
    menge INTEGER,
    PRIMARY KEY (bestellung_id, pflegemittel_id),
    FOREIGN KEY (bestellung_id) REFERENCES bestellungen (id),
    FOREIGN KEY (pflegemittel_id) REFERENCES pflegemittel (id)
)
SQL;

    $pdo->exec($bestellungen_posten);
}

function schema_pruefen()
{
    global $pdo;

    $stmt = $pdo->query('PRAGMA user_version');
    $row = $stmt->fetch();

    switch ($row->user_version)
    {
        case 0:
            schema_anlegen();
            break;
        case 1:
            break;
        default:
            die("Unbekannte Version {$row->user_version} der Datenbank.");
    }

    $pdo->exec('PRAGMA user_version = 1');
}

function mit_datenbank_verbinden()
{
    global $pdo;

    try
    {
        $pdo = new PDO('sqlite:/var/lib/pflegebedarf/schema/schema.sqlite');
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_OBJ);

        schema_pruefen();
    }
    catch (PDOException $e)
    {
        die('Konnte Datenbank nicht anlegen: ' . $e->getMessage());
    }
}

mit_datenbank_verbinden();
