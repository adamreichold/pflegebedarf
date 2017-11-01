<?php

function bereinigen(&$val, $valfun)
{
    $val = $valfun($val);
}

function anfrage_verarbeiten($laden, $speichern)
{
    global $pdo;

    $pdo->beginTransaction();

    switch ($_SERVER['REQUEST_METHOD'])
    {
        case 'POST':
            $speichern();
        case 'GET':
            $laden();
            break;
        default:
            http_response_code(405);
            break;
    }

    $pdo->commit();
}
