<?php

require '/usr/lib/pflegebedarf/datenbank.php';
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
    $limit = filter_input(INPUT_GET, 'limit', FILTER_VALIDATE_INT);

    if ($limit === NULL)
    {
        $limit = 1;
    }
    else if ($limit === FALSE)
    {
        die('Der Parameter limit konnte nicht verarbeitet werden.');
    }

    $zeilen = zeilen_laden(
        'SELECT * FROM bestellungen ORDER BY zeitstempel DESC LIMIT ?',
        $limit
    );

    foreach ($zeilen as $zeile)
    {
        $zeile->posten = zeilen_laden(
            'SELECT pflegemittel_id, menge FROM bestellungen_posten WHERE bestellung_id = ?',
            $zeile->id
        );

        bestellung_bereinigen($zeile);
    }

    header('Content-Type: application/json');
    print(json_encode($zeilen));
}

function bestellung_speichern()
{
    $objekt = json_decode(file_get_contents('php://input'));

    if ($objekt === NULL || !is_object($objekt))
    {
        die('Konnte JSON-Darstellung nicht verarbeiten.');
    }

    bestellung_bereinigen($objekt);

    $objekt->zeitstempel = time();

    $objekt->id = zeile_einfuegen(
        'INSERT INTO bestellungen VALUES (?, ?, ?, ?)',
        $objekt->id,
        $objekt->zeitstempel,
        $objekt->empfaenger,
        $objekt->nachricht
    );

    foreach ($objekt->posten as $posten)
    {
        zeile_einfuegen(
            'INSERT INTO bestellungen_posten VALUES (?, ?, ?)',
            $objekt->id,
            $posten->pflegemittel_id,
            $posten->menge
        );
    }

    bestellung_versenden($objekt);
}

anfrage_verarbeiten(bestellungen_laden, bestellung_speichern);
