<?php

function schema_v1_anlegen()
{
    global $pdo;

    error_log('Neue Datenbank v1 wird angelegt...');

    $pdo->beginTransaction();

    $pflegemittel = <<<SQL
CREATE TABLE pflegemittel (
    id INTEGER PRIMARY KEY,
    zeitstempel INTEGER NOT NULL,
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

function schema_v2_migrieren()
{
    global $pdo;

    error_log('Datenbank v1 wird auf v2 migriert...');

    $pdo->beginTransaction();

    $pdo->exec('ALTER TABLE pflegemittel ADD COLUMN vorhandene_menge INTEGER NOT NULL DEFAULT 0');
    $pdo->exec('ALTER TABLE pflegemittel ADD COLUMN wird_verwendet INTEGER NOT NULL DEFAULT 1');

    $pdo->exec('PRAGMA user_version = 2');

    $pdo->commit();
}

function schema_v3_migrieren()
{
    global $pdo;

    error_log('Datenbank v2 wird auf v3 migriert...');

    $pdo->beginTransaction();

    $pdo->exec("ALTER TABLE bestellungen ADD COLUMN nachricht TEXT NOT NULL DEFAULT ''");

    $pdo->exec('PRAGMA user_version = 3');

    $pdo->commit();
}

function schema_v4_migrieren()
{
    global $pdo;

    error_log('Datenbank v3 wird auf v4 migriert...');

    $pdo->beginTransaction();

    $pdo->exec("ALTER TABLE pflegemittel ADD COLUMN hersteller_und_produkt TEXT NOT NULL DEFAULT ''");
    $pdo->exec("ALTER TABLE pflegemittel ADD COLUMN pzn_oder_ref TEXT NOT NULL DEFAULT ''");

    $pdo->exec('PRAGMA user_version = 4');

    $pdo->commit();
}

function schema_v5_migrieren()
{
    global $pdo;

    error_log('Datenbank v4 wird auf v5 migriert...');

    $pdo->beginTransaction();

    $pdo->exec('ALTER TABLE pflegemittel ADD COLUMN geplanter_verbrauch INTEGER NOT NULL DEFAULT 0');

    $pdo->exec('PRAGMA user_version = 5');

    $pdo->commit();
}

function schema_v6_migrieren()
{
    global $pdo;

    error_log('Datenbank v5 wird auf v6 migriert...');

    $pdo->beginTransaction();

    $pdo->exec('ALTER TABLE pflegemittel RENAME TO pflegemittel_alt');

    $pflegemittel_neu = <<<SQL
CREATE TABLE pflegemittel (
    id INTEGER PRIMARY KEY,
    bezeichnung TEXT NOT NULL,
    einheit TEXT NOT NULL,
    hersteller_und_produkt TEXT NOT NULL,
    pzn_oder_ref TEXT NOT NULL,
    wird_verwendet INTEGER NOT NULL
)
SQL;

    $pdo->exec($pflegemittel_neu);

    $pdo->exec('INSERT INTO pflegemittel SELECT id, bezeichnung, einheit, hersteller_und_produkt, pzn_oder_ref, wird_verwendet FROM pflegemittel_alt');

    $pflegemittel_bestand = <<<SQL
CREATE TABLE pflegemittel_bestand (
    pflegemittel_id INTEGER,
    zeitstempel INTEGER,
    geplanter_verbrauch INTEGER NOT NULL,
    vorhandene_menge INTEGER NOT NULL,
    PRIMARY KEY (pflegemittel_id, zeitstempel),
    FOREIGN KEY (pflegemittel_id) REFERENCES pflegemittel (id)
)
SQL;

    $pdo->exec($pflegemittel_bestand);

    $pdo->exec('INSERT INTO pflegemittel_bestand SELECT id, zeitstempel, geplanter_verbrauch, vorhandene_menge FROM pflegemittel_alt');

    $pdo->exec('DROP TABLE pflegemittel_alt');

    $pdo->exec('PRAGMA user_version = 6');

    $pdo->commit();
}

function schema_pruefen()
{
    global $pdo;

    $user_version = $pdo->query('PRAGMA user_version')->fetch()->user_version;

    switch ($user_version)
    {
        case 0:
            schema_v1_anlegen();
        case 1:
            schema_v2_migrieren();
        case 2:
            schema_v3_migrieren();
        case 3:
            schema_v4_migrieren();
        case 4:
            schema_v5_migrieren();
        case 5:
            schema_v6_migrieren();
        case 6:
            break;
        default:
            die("Unbekannte Version {$user_version} der Datenbank.");
    }
}

function mit_datenbank_verbinden()
{
    global $pdo, $stmts;

    $pdo = new PDO('sqlite:/usr/lib/pflegebedarf/datenbank.sqlite');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_OBJ);

    $stmts = [];

    schema_pruefen();
}

function abfrage_vorbereiten($abfrage)
{
    global $pdo, $stmts;

    if (isset($stmts[$abfrage]))
    {
        return $stmts[$abfrage];
    }

    $stmt = $pdo->prepare($abfrage);

    $stmts[$abfrage] = $stmt;

    return $stmt;
}

function abfrage_durchfuehren($abfrage, ...$parameter)
{
    $stmt = abfrage_vorbereiten($abfrage);

    $stmt->execute($parameter);

    return $stmt;
}

function zeile_laden($abfrage, ...$parameter)
{
    return abfrage_durchfuehren($abfrage, ...$parameter)->fetch();
}

function zeilen_laden($abfrage, ...$parameter)
{
    return abfrage_durchfuehren($abfrage, ...$parameter)->fetchAll();
}

function zeile_einfuegen($abfrage, ...$parameter)
{
    global $pdo;

    $stmt = abfrage_durchfuehren($abfrage, ...$parameter);

    return $pdo->lastInsertId();
}

mit_datenbank_verbinden();
