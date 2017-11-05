<?php

require '/usr/lib/pflegebedarf/schema.php';
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
    $rows = zeilen_laden('SELECT * FROM pflegemittel');

    array_walk($rows, pflegemittel_bereinigen);

    header('Content-Type: application/json');
    print(json_encode($rows));
}

function pflegemittel_speichern()
{
    $rows = json_decode(file_get_contents('php://input'));

    if ($rows === NULL || !is_array($rows))
    {
        die('Konnte JSON-Darstellung nicht verarbeiten.');
    }

    foreach ($rows as $row)
    {
        pflegemittel_bereinigen($row);

        $row->zeitstempel = time();

        zeile_einfuegen(
            'INSERT OR REPLACE INTO pflegemittel VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            $row->id,
            $row->zeitstempel,
            $row->bezeichnung,
            $row->einheit,
            $row->vorhandene_menge,
            $row->wird_verwendet,
            $row->hersteller_und_produkt,
            $row->pzn_oder_ref,
            $row->geplanter_verbrauch
        );
    }
}

anfrage_verarbeiten(pflegemittel_laden, pflegemittel_speichern);
