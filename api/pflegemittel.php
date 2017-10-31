<?php

require '/var/lib/pflegebedarf/schema/schema.php';

function int_bereinigen(&$val)
{
    $val = intval($val);
}

function pflegemittel_bereinigen($pflegemittel)
{
    if (isset($pflegemittel->id))
    {
        int_bereinigen($pflegemittel->id);
    }
}

function pflegemittel_laden()
{
    global $pdo;

    $pdo->beginTransaction();

    $stmt = $pdo->query('SELECT * FROM pflegemittel');
    $rows = $stmt->fetchAll();

    $pdo->commit();

    array_walk($rows, pflegemittel_bereinigen);

    header('Content-Type: application/json');
    print(json_encode($rows));
}

function pflegemittel_speichern()
{
    global $pdo;

    $pflegemittel = json_decode(file_get_contents('php://input'));
    pflegemittel_bereinigen($pflegemittel);

    $pdo->beginTransaction();

    if (isset($pflegemittel->id))
    {
        $stmt = $pdo->prepare('UPDATE pflegemittel SET bezeichnung = ?, einheit = ? WHERE id = ?');
        $stmt->bindParam(3, $pflegemittel->id);
    }
    else
    {
        $stmt = $pdo->prepare('INSERT INTO pflegemittel (bezeichnung, einheit) VALUES (?, ?)');
    }

    $stmt->bindParam(1, $pflegemittel->bezeichnung);
    $stmt->bindParam(2, $pflegemittel->einheit);

    $stmt->execute();

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
                pflegemittel_laden();
                break;
            case 'POST':
                pflegemittel_speichern();
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
