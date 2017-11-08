<?php

require '/usr/lib/pflegebedarf/datenbank.php';
require '/usr/lib/pflegebedarf/api.php';

function pflegemittel_bereinigen($pflegemittel)
{
    if (isset($pflegemittel->id))
    {
        bereinigen($pflegemittel->id, intval);
    }
    else
    {
        $pflegemittel->id = NULL;
    }

    unset($pflegemittel->zeitstempel);

    bereinigen($pflegemittel->bezeichnung, strval);
    bereinigen($pflegemittel->einheit, strval);
    bereinigen($pflegemittel->hersteller_und_produkt, strval);
    bereinigen($pflegemittel->pzn_oder_ref, strval);
    bereinigen($pflegemittel->geplanter_verbrauch, intval);
    bereinigen($pflegemittel->vorhandene_menge, intval);
    bereinigen($pflegemittel->wird_verwendet, boolval);
}

function pflegemittel_laden()
{
    $abfrage = <<<SQL
WITH groesste_zeitstempel AS (
    SELECT pflegemittel_id, MAX(zeitstempel) AS zeitstempel
    FROM pflegemittel_bestand GROUP BY pflegemittel_id
)
SELECT pm.*, pmb.geplanter_verbrauch, pmb.vorhandene_menge
FROM pflegemittel pm, pflegemittel_bestand pmb, groesste_zeitstempel gzs
WHERE pm.id = pmb.pflegemittel_id
AND pmb.pflegemittel_id = gzs.pflegemittel_id AND pmb.zeitstempel = gzs.zeitstempel
SQL;

    $zeilen = zeilen_laden($abfrage);

    array_walk($zeilen, pflegemittel_bereinigen);

    header('Content-Type: application/json');
    print(json_encode($zeilen));
}

function pflegemittel_speichern()
{
    $objekte = json_decode(file_get_contents('php://input'));

    if ($objekte === NULL || !is_array($objekte))
    {
        die('Konnte JSON-Darstellung nicht verarbeiten.');
    }

    foreach ($objekte as $objekt)
    {
        pflegemittel_bereinigen($objekt);

        $objekt->zeitstempel = time();

        $objekt->id = zeile_einfuegen(
            'INSERT OR REPLACE INTO pflegemittel VALUES (?, ?, ?, ?, ?, ?)',
            $objekt->id,
            $objekt->bezeichnung,
            $objekt->einheit,
            $objekt->hersteller_und_produkt,
            $objekt->pzn_oder_ref,
            $objekt->wird_verwendet
        );

        zeile_einfuegen(
            'INSERT INTO pflegemittel_bestand VALUES (?, ?, ?, ?)',
            $objekt->id,
            $objekt->zeitstempel,
            $objekt->geplanter_verbrauch,
            $objekt->vorhandene_menge
        );
    }
}

anfrage_verarbeiten(pflegemittel_laden, pflegemittel_speichern);
