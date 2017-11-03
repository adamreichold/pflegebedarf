<?php

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

        $nachricht .= "\n* {$posten->menge} {$pflegemittel->einheit} {$pflegemittel->bezeichnung}";

        if (strlen($pflegemittel->pzn_oder_ref) > 0)
        {
            $nachricht .= " ({$pflegemittel->pzn_oder_ref})";
        }

        $nachricht .= " ({$pflegemittel->vorhandene_menge} {$pflegemittel->einheiten} vorhanden)";
    }

    if (mail($bestellung->empfaenger, $betreff, $nachricht, $kopfzeilen) === FALSE)
    {
        die('Konnte Bestellung nicht versenden.');
    }
}
