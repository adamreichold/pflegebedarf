<?php

require '/var/lib/pflegebedarf/schema/schema.php';

function int_bereinigen(&$val)
{
    $val = intval($val);
}

function posten_bereinigen($posten)
{
    if (isset($posten->bestellung_id))
    {
        int_bereinigen($posten->bestellung_id);
    }

    int_bereinigen($posten->pflegemittel_id);
    int_bereinigen($posten->menge);
}

function bestellung_bereinigen($bestellung)
{
    if (isset($bestellung->id))
    {
        int_bereinigen($bestellung->id);
    }

    int_bereinigen($bestellung->zeitstempel);

    if (isset($bestellung->posten))
    {
        array_walk($bestellung->posten, posten_bereinigen);
    }
}

function bestellungen_laden()
{
    global $pdo;

    $posten = [];

    $pdo->beginTransaction();

    $stmt = $pdo->query('SELECT * FROM bestellungen_posten');

    while ($row = $stmt->fetch())
    {
        posten_bereinigen($row);

        if (isset($posten[$row->bestellung_id]))
        {
            $posten[$row->bestellung_id][] = $row;
        }
        else
        {
            $posten[$row->bestellung_id] = [$row];
        }

        unset($row->bestellung_id);
    }

    $stmt = $pdo->query('SELECT * FROM bestellungen ORDER BY zeitstempel DESC');
    $rows = $stmt->fetchAll();

    foreach ($rows as $row)
    {
        bestellung_bereinigen($row);

        if (isset($posten[$row->id]))
        {
            $row->posten = $posten[$row->id];
        }
        else
        {
            $row->posten = [];
        }
    }

    header('Content-Type: application/json');
    print(json_encode($rows));
}

function bestellung_speichern()
{
    global $pdo;

    $bestellung = json_decode(file_get_contents('php://input'));
    bestellung_bereinigen($bestellung);

    $pdo->beginTransaction();

    if (isset($bestellung->id))
    {
        $stmt = $pdo->prepare('UPDATE bestellungen SET zeitstempel = ?, empfaenger = ? WHERE id = ?');
        $stmt->bindParam(3, $bestellung->id);
    }
    else
    {
        $stmt = $pdo->prepare('INSERT INTO bestellungen (zeitstempel, empfaenger) VALUES (?, ?)');
    }

    $stmt->bindParam(1, $bestellung->zeitstempel);
    $stmt->bindParam(2, $bestellung->empfaenger);

    $stmt->execute();

    if (!isset($bestellung->id))
    {
        $bestellung->id = $pdo->lastInsertId();
    }

    $stmt = $pdo->prepare('DELETE FROM bestellungen_posten WHERE bestellung_id = ?');

    $stmt->bindParam(1, $bestellung->id);

    $stmt->execute();

    $stmt = $pdo->prepare('INSERT INTO bestellungen_posten VALUES (?, ?, ?)');

    $stmt->bindParam(1, $bestellung->id);
    $stmt->bindParam(2, $pflegemittel_id);
    $stmt->bindParam(3, $menge);

    foreach($bestellung->posten as $posten)
    {
        $pflegemittel_id = $posten->pflegemittel_id;
        $menge = $posten->menge;

        $stmt->execute();
    }

    $pdo->commit();
}

function anfrage_verarbeiten($request_method)
{
    global $pdo;

    try
    {
        switch ($request_method)
        {
            case 'GET':
                bestellungen_laden();
                break;
            case 'POST':
                bestellung_speichern();
                break;
            default:
                http_response_code(405);
                break;
        }
    }
    catch (PDOException $e)
    {
        if ($pdo->inTransaction())
        {
            $pdo->rollback();
        }

        die('Fehler bei Zugriff auf Datenbank: ' . $e->getMessage());
    }
}

anfrage_verarbeiten($_SERVER['REQUEST_METHOD']);
