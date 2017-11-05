<?php

require '/usr/lib/pflegebedarf/schema.php';
require '/usr/lib/pflegebedarf/api.php';

require '/usr/lib/pflegebedarf/versenden.php';

function bestellung_posten_bereinigen($posten)
{
    bereinigen($posten->pflegemittel_id, intval);
    bereinigen($posten->menge, intval);
}

function bestellung_bereinigen($bestellung)
{
    if (isset($bestellung->id))
    {
        bereinigen($bestellung->id, intval);
    }
    else
    {
        $bestellung->id = NULL;
    }

    unset($bestellung->zeitstempel);

    bereinigen($bestellung->empfaenger, strval);
    bereinigen($bestellung->nachricht, strval);

    if (isset($bestellung->posten) && is_array($bestellung->posten))
    {
        array_walk($bestellung->posten, bestellung_posten_bereinigen);
    }
    else
    {
        $bestellung->posten = [];
    }
}

function bestellungen_laden()
{
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 1;

    $rows = zeilen_laden(
        'SELECT * FROM bestellungen ORDER BY zeitstempel DESC LIMIT ?',
        $limit
    );

    foreach ($rows as $row)
    {
        $row->posten = zeilen_laden(
            'SELECT pflegemittel_id, menge FROM bestellungen_posten WHERE bestellung_id = ?',
            $row->id
        );

        bestellung_bereinigen($row);
    }

    header('Content-Type: application/json');
    print(json_encode($rows));
}

function bestellung_speichern()
{
    $row = json_decode(file_get_contents('php://input'));

    if ($row === NULL || !is_object($row))
    {
        die('Konnte JSON-Darstellung nicht verarbeiten.');
    }

    bestellung_bereinigen($row);

    $row->zeitstempel = time();

    $row->id = zeile_einfuegen(
        'INSERT INTO bestellungen VALUES (?, ?, ?, ?)',
        $row->id,
        $row->zeitstempel,
        $row->empfaenger,
        $row->nachricht
    );

    foreach ($row->posten as $posten)
    {
        zeile_einfuegen(
            'INSERT INTO bestellungen_posten VALUES (?, ?, ?)',
            $row->id,
            $posten->pflegemittel_id,
            $posten->menge
        );
    }

    bestellung_versenden($row);
}

anfrage_verarbeiten(bestellungen_laden, bestellung_speichern);
