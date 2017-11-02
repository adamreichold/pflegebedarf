<?php

require '/usr/lib/pflegebedarf/schema.php';
require '/usr/lib/pflegebedarf/api.php';

function pflegemittel_laden($pflegemittel_id)
{
    global $pdo;

    $stmt = $pdo->prepare('SELECT * FROM pflegemittel WHERE id = ?');

    $stmt->bindParam(1, $pflegemittel_id);

    $stmt->execute();

    return $stmt->fetch();
}

function bestellung_versenden($bestellung)
{
    $konfiguration = parse_ini_file('/usr/lib/pflegebedarf/versenden.ini', false);

    if ($konfiguration === FALSE)
    {
        die('Konnte Konfiguration für Versand nicht verarbeiten.');
    }

    $datum = date('d.m.Y', $bestellung->zeitstempel);
    $betreff = str_replace('{datum}', $datum, $konfiguration['betreff']);

    $kopfzeilen = "From: {$konfiguration['von']}";
    $kopfzeilen .= "\r\nReply-To: {$konfiguration['antwort']}";

    foreach ($konfiguration['kopien'] as $kopie)
    {
        $kopfzeilen .= "\r\nCc: {$kopie}";
    }

    $nachricht = $bestellung->nachricht . "\n\n\n";

    foreach ($bestellung->posten as $posten)
    {
        if ($posten->menge < 1)
        {
            continue;
        }

        $pflegemittel = pflegemittel_laden($posten->pflegemittel_id);

        $nachricht .= "\n{$posten->menge} {$pflegemittel->einheit} {$pflegemittel->bezeichnung}";

        if (strlen($pflegemittel->pzn_oder_ref) > 0)
        {
            $nachricht .= " ({$pflegemittel->pzn_oder_ref})";
        }
    }

    if (mail($bestellung->empfaenger, $betreff, $nachricht, $kopfzeilen) === FALSE)
    {
        die('Konnte Bestellung nicht versenden.');
    }
}

function bestellung_posten_bereinigen($posten)
{
    bereinigen($posten->pflegemittel_id, intval);
    bereinigen($posten->menge, intval);
}

function bestellung_posten_laden($bestellung_id)
{
   global $pdo;

   $stmt = $pdo->prepare('SELECT pflegemittel_id, menge FROM bestellungen_posten WHERE bestellung_id = ?');

   $stmt->bindParam(1, $bestellung_id);

   $stmt->execute();

   return $stmt->fetchAll();
}

function bestellung_posten_speichern($bestellung_id, $rows)
{
    global $pdo;

    $stmt = $pdo->prepare('INSERT INTO bestellungen_posten VALUES (?, ?, ?)');

    $stmt->bindParam(1, $bestellung_id);
    $stmt->bindParam(2, $pflegemittel_id);
    $stmt->bindParam(3, $menge);

    foreach ($rows as $row)
    {
        $pflegemittel_id = $row->pflegemittel_id;
        $menge = $row->menge;

        $stmt->execute();
    }
}

function bestellung_bereinigen($bestellung)
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
        array_walk($bestellung->posten, bestellung_posten_bereinigen);
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
        $row->posten = bestellung_posten_laden($row->id);

        bestellung_bereinigen($row);
    }

    header('Content-Type: application/json');
    print(json_encode($rows));
}

function bestellung_speichern()
{
    global $pdo;

    $row = json_decode(file_get_contents('php://input'));

    if ($row === NULL || !is_object($row))
    {
        die('Konnte JSON-Darstellung nicht verarbeiten.');
    }

    bestellung_bereinigen($row);

    $stmt = $pdo->prepare('INSERT INTO bestellungen (zeitstempel, empfaenger, nachricht) VALUES (?, ?, ?)');

    $stmt->bindParam(1, $row->zeitstempel);
    $stmt->bindParam(2, $row->empfaenger);
    $stmt->bindParam(3, $row->nachricht);

    $stmt->execute();

    bestellung_posten_speichern($pdo->lastInsertId(), $row->posten);

    bestellung_versenden($row);
}

anfrage_verarbeiten(bestellungen_laden, bestellung_speichern);
