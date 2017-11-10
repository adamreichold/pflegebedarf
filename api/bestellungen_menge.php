<?php

require '/usr/lib/pflegebedarf/datenbank.php';
require '/usr/lib/pflegebedarf/api.php';

$id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT);

if ($id === NULL || $id === FALSE)
{
    die('Der Parameter id fehlt oder konnte nicht verarbeitet werden.');
}

$abfrage = <<<SQL
SELECT b.zeitstempel, bp.menge
FROM bestellungen b, bestellungen_posten bp
WHERE bp.bestellung_id = b.id AND bp.pflegemittel_id = ?
ORDER BY b.zeitstempel
SQL;

$zeilen = zeilen_laden($abfrage, $id);

foreach ($zeilen as $zeile)
{
    bereinigen($zeile->zeitstempel, intval);
    bereinigen($zeile->menge, intval);
}

header('Content-Type: application/json');
print(json_encode($zeilen));
