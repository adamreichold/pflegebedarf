module Api exposing (Pflegemittel, Bestellung, pflegemittelLaden, bestellungenLaden)

import Http
import Json.Decode as Decode
import Json.Encode as Encode

import Date exposing (Date, fromTime)
import Time exposing (Time, second)

import Debug


type alias Pflegemittel =
    { id : Int
    , bezeichnung : String
    , einheit : String
    }

type alias BestellungPosten =
    { pflegemittelId : Int
    , menge : Int
    }

type alias Bestellung =
    { id : Int
    , zeitstempel : Date
    , empfaenger : String
    , posten : List BestellungPosten
    }


decodeZeitstempel : Decode.Decoder Date
decodeZeitstempel =
    let
        toTime = (*) second
        toDate = fromTime << toTime << toFloat
    in
        Decode.map toDate Decode.int

decodePflegemittel : Decode.Decoder Pflegemittel
decodePflegemittel =
    Decode.map3 Pflegemittel
        (Decode.field "id" Decode.int)
        (Decode.field "bezeichnung" Decode.string)
        (Decode.field "einheit" Decode.string)

decodeBestellungPosten : Decode.Decoder BestellungPosten
decodeBestellungPosten =
    Decode.map2 BestellungPosten
        (Decode.field "pflegemittel_id" Decode.int)
        (Decode.field "menge" Decode.int)

decodeBestellung : Decode.Decoder Bestellung
decodeBestellung =
    Decode.map4 Bestellung
        (Decode.field "id" Decode.int)
        (Decode.field "zeitstempel" decodeZeitstempel)
        (Decode.field "empfaenger" Decode.string)
        (Decode.field "posten" (Decode.list decodeBestellungPosten))


fehlerBehandeln : Result Http.Error (List a) -> List a
fehlerBehandeln result =
    case result of
        (Ok val) -> val
        (Err err) -> let _ = Debug.log "Err" err in []

objekteLaden : (List a -> msg) -> String -> Decode.Decoder (List a) -> Cmd msg
objekteLaden msg url decoder =
    Http.send (msg << fehlerBehandeln) (Http.get url decoder)

pflegemittelLaden : (List Pflegemittel -> msg) -> Cmd msg
pflegemittelLaden msg =
    let
        url = "../api/pflegemittel.php"
        decoder = Decode.list decodePflegemittel
    in
        objekteLaden msg url decoder

bestellungenLaden : (List Bestellung -> msg) -> Cmd msg
bestellungenLaden msg =
    let
        url = "../api/bestellungen.php"
        decoder = Decode.list decodeBestellung
    in
        objekteLaden msg url decoder
