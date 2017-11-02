<?php

require '/usr/lib/pflegebedarf/schema.php';
require '/usr/lib/pflegebedarf/api.php';

function bestellungen_posten_bereinigen($posten)
{
    bereinigen($posten->pflegemittel_id, intval);
    bereinigen($posten->menge, intval);
}

function bestellungen_posten_laden($bestellung_id)
{
   global $pdo;

   $stmt = $pdo->prepare('SELECT pflegemittel_id, menge FROM bestellungen_posten WHERE bestellung_id = ?');

   $stmt->bindParam(1, $bestellung_id);

   $stmt->execute();

   return $stmt->fetchAll();
}

function bestellungen_posten_speichern($bestellung_id, $rows)
{
    global $pdo;

    $stmt = $pdo->prepare('INSERT INTO bestellungen_posten VALUES (?, ?, ?)');

    $stmt->bindParam(1, $bestellung_id);
    $stmt->bindParam(2, $pflegemittel_id);
    $stmt->bindParam(3, $menge);

    foreach($rows as $row)
    {
        $pflegemittel_id = $row->pflegemittel_id;
        $menge = $row->menge;

        $stmt->execute();
    }
}

function bestellungen_bereinigen($bestellung)
{
    if (isset($bestellung->id))
    {
        bereinigen($bestellung->id, intval);
    }

    bereinigen($bestellung->zeitstempel, intval);
    bereinigen($bestellung->empfaenger, strval);
    bereinigen($bestellung->nachricht, strval);

    if (isset($bestellung->posten) && is_array($bestellung->posten))
    {
        array_walk($bestellung->posten, bestellungen_posten_bereinigen);
    }
    else
    {
        $bestellung->posten = [];
    }
}

function bestellungen_laden()
{
    global $pdo;

    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 1;

    $stmt = $pdo->query("SELECT * FROM bestellungen ORDER BY zeitstempel DESC LIMIT {$limit}");
    $rows = $stmt->fetchAll();

    foreach ($rows as $row)
    {
        $row->posten = bestellungen_posten_laden($row->id);

        bestellungen_bereinigen($row);
    }

    header('Content-Type: application/json');
    print(json_encode($rows));
}

function bestellungen_speichern()
{
    global $pdo;

    $row = json_decode(file_get_contents('php://input'));

    if ($row === NULL || !is_object($row))
    {
        die('Konnte JSON-Darstellung nicht verarbeiten.');
    }

    bestellungen_bereinigen($row);

    $stmt = $pdo->prepare('INSERT INTO bestellungen (zeitstempel, empfaenger, nachricht) VALUES (?, ?, ?)');

    $stmt->bindParam(1, $row->zeitstempel);
    $stmt->bindParam(2, $row->empfaenger);
    $stmt->bindParam(3, $row->nachricht);

    $stmt->execute();

    bestellungen_posten_speichern($pdo->lastInsertId(), $row->posten);
}

anfrage_verarbeiten(bestellungen_laden, bestellungen_speichern);
