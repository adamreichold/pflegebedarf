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
    bereinigen($pflegemittel->vorhandene_menge, intval);
    bereinigen($pflegemittel->wird_verwendet, boolval);
}

function pflegemittel_laden()
{
    global $pdo;

    $stmt = $pdo->query('SELECT * FROM pflegemittel');
    $rows = $stmt->fetchAll();

    array_walk($rows, pflegemittel_bereinigen);

    header('Content-Type: application/json');
    print(json_encode($rows));
}

function pflegemittel_speichern()
{
    global $pdo;

    $rows = json_decode(file_get_contents('php://input'));

    if ($rows === NULL || !is_array($rows))
    {
        die('Konnte JSON-Darstellung nicht verarbeiten.');
    }

    $stmt = $pdo->prepare('INSERT OR REPLACE INTO pflegemittel VALUES (?, ?, ?, ?, ?, ?, ?, ?)');

    foreach ($rows as $row)
    {
        pflegemittel_bereinigen($row);

        $row->zeitstempel = time();

        $stmt->bindParam(1, $row->id);
        $stmt->bindParam(2, $row->zeitstempel);
        $stmt->bindParam(3, $row->bezeichnung);
        $stmt->bindParam(4, $row->einheit);
        $stmt->bindParam(5, $row->vorhandene_menge);
        $stmt->bindParam(6, $row->wird_verwendet);
        $stmt->bindParam(7, $row->hersteller_und_produkt);
        $stmt->bindParam(8, $row->pzn_oder_ref);

        $stmt->execute();
    }
}

anfrage_verarbeiten(pflegemittel_laden, pflegemittel_speichern);
