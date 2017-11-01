<?php

require '/var/lib/pflegebedarf/schema.php';
require '/var/lib/pflegebedarf/api.php';

function pflegemittel_bereinigen($pflegemittel)
{
    if (isset($pflegemittel->id))
    {
        bereinigen($pflegemittel->id, intval);
    }

    bereinigen($pflegemittel->bezeichnung, strval);
    bereinigen($pflegemittel->einheit, strval);
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

        if (isset($row->id))
        {
            $stmt = $pdo->prepare('UPDATE pflegemittel SET bezeichnung = ?, einheit = ?, wird_verwendet = ? WHERE id = ?');
            $stmt->bindParam(4, $row->id);
        }
        else
        {
            $stmt = $pdo->prepare('INSERT INTO pflegemittel (bezeichnung, einheit, wird_verwendet) VALUES (?, ?, ?)');
        }

        $stmt->bindParam(1, $row->bezeichnung);
        $stmt->bindParam(2, $row->einheit);
        $stmt->bindParam(3, $row->wird_verwendet);

        $stmt->execute();
    }
}

anfrage_verarbeiten(pflegemittel_laden, pflegemittel_speichern);
