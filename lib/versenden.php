<?php

function pflegemittel_laden($pflegemittel_id)
{
    global $pdo;

    $stmt = $pdo->prepare('SELECT * FROM pflegemittel WHERE id = ?');

    $stmt->bindParam(1, $pflegemittel_id);

    $stmt->execute();

    return $stmt->fetch();
}

function posten_formatieren($posten)
{
    $stichpunkte = '';

    $anstrich = '*';

    foreach ($posten as $p)
    {
        if ($p->menge < 1)
        {
            continue;
        }

        $pm = pflegemittel_laden($p->pflegemittel_id);

        $stichpunkte .= "{$anstrich} {$p->menge} {$pm->einheit} {$pm->bezeichnung}";

        $hersteller_und_produkt_gesetzt = strlen($pm->hersteller_und_produkt) > 0;
        $pzn_oder_ref_gesetzt = strlen($pm->pzn_oder_ref) > 0;

        if ($hersteller_und_produkt_gesetzt && $pzn_oder_ref_gesetzt)
        {
            $stichpunkte .= " ({$pm->hersteller_und_produkt} {$pm->pzn_oder_ref})";
        }
        else if ($hersteller_und_produkt_gesetzt)
        {
            $stichpunkte .= " ({$pm->hersteller_und_produkt})";
        }
        else if ($pzn_oder_ref_gesetzt)
        {
            $stichpunkte .= " ({$pm->pzn_oder_ref})";
        }

        $anstrich = "\n\n*";
    }

    return $stichpunkte;
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

    $posten = posten_formatieren($bestellung->posten);
    $nachricht = str_replace('{posten}', $posten, $bestellung->nachricht);

    if (mail($bestellung->empfaenger, $betreff, $nachricht, $kopfzeilen) === FALSE)
    {
        die('Konnte Bestellung nicht versenden.');
    }
}
