<?php

require '/usr/lib/pflegebedarf/schema.php';
require '/usr/lib/pflegebedarf/api.php';

function pflegemittel_bereinigen($pflegemittel)
{
    if (isset($pflegemittel->id))
    {
        bereinigen($pflegemittel->id, intval);
    }

    unset($pflegemittel->zeitstempel);

    bereinigen($pflegemittel->bezeichnung, strval);
    bereinigen($pflegemittel->einheit, strval);
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

    foreach ($rows as $row)
    {
        pflegemittel_bereinigen($row);

        $row->zeitstempel = time();

        if (isset($row->id))
        {
            $stmt = $pdo->prepare('UPDATE pflegemittel SET zeitstempel = ?, bezeichnung = ?, einheit = ?, pzn_oder_ref = ?, vorhandene_menge = ?, wird_verwendet = ? WHERE id = ?');
            $stmt->bindParam(7, $row->id);
        }
        else
        {
            $stmt = $pdo->prepare('INSERT INTO pflegemittel (zeitstempel, bezeichnung, einheit, pzn_oder_ref, vorhandene_menge, wird_verwendet) VALUES (?, ?, ?, ?, ?, ?)');
        }

        $stmt->bindParam(1, $row->zeitstempel);
        $stmt->bindParam(2, $row->bezeichnung);
        $stmt->bindParam(3, $row->einheit);
        $stmt->bindParam(4, $row->pzn_oder_ref);
        $stmt->bindParam(5, $row->vorhandene_menge);
        $stmt->bindParam(6, $row->wird_verwendet);

        $stmt->execute();
    }
}

anfrage_verarbeiten(pflegemittel_laden, pflegemittel_speichern);
