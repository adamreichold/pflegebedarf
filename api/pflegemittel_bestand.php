<?php

require '/usr/lib/pflegebedarf/datenbank.php';
require '/usr/lib/pflegebedarf/api.php';

$id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT);

if ($id === NULL || $id === FALSE)
{
    die('Der Parameter id fehlt oder konnte nicht verarbeitet werden.');
}

$zeilen = zeilen_laden('SELECT zeitstempel, geplanter_verbrauch, vorhandene_menge FROM pflegemittel_bestand WHERE pflegemittel_id = ?', $id);

foreach ($zeilen as $zeile)
{
    bereinigen($zeile->zeitstempel, intval);
    bereinigen($zeile->geplanter_verbrauch, intval);
    bereinigen($zeile->vorhandene_menge, intval);
}

header('Content-Type: application/json');
print(json_encode($zeilen));
