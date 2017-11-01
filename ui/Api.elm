module Api exposing (Pflegemittel, Bestellung, pflegemittelLaden, pflegemittelSpeichern, bestellungenLaden)

import Http
import Json.Decode as Decode
import Json.Encode as Encode

import Date exposing (Date, fromTime)
import Time exposing (Time, second)

import Debug


type alias Pflegemittel =
    { id : Maybe Int
    , bezeichnung : String
    , einheit : String
    , wirdVerwendet : Bool
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
    Decode.map4 Pflegemittel
        (Decode.map Just <| Decode.field "id" Decode.int)
        (Decode.field "bezeichnung" Decode.string)
        (Decode.field "einheit" Decode.string)
        (Decode.field "wird_verwendet" Decode.bool)

encodePflegemittel : Pflegemittel -> Encode.Value
encodePflegemittel pflegemittel =
    Encode.object
        [ ("id", Maybe.withDefault Encode.null <| Maybe.map Encode.int pflegemittel.id)
        , ("bezeichnung", Encode.string pflegemittel.bezeichnung)
        , ("einheit", Encode.string pflegemittel.einheit)
        , ("wird_verwendet", Encode.bool pflegemittel.wirdVerwendet)
        ]

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

objekteSpeichern : (List a -> msg) -> String -> Decode.Decoder (List a) -> (List a -> Encode.Value) -> List a -> Cmd msg
objekteSpeichern msg url decoder encoder objekte =
    let
        body = Http.jsonBody <| encoder objekte
    in
        Http.send (msg << fehlerBehandeln) (Http.post url body decoder)

pflegemittelLaden : (List Pflegemittel -> msg) -> Cmd msg
pflegemittelLaden msg =
    let
        url = "../api/pflegemittel.php"
        decoder = Decode.list decodePflegemittel
    in
        objekteLaden msg url decoder

pflegemittelSpeichern : (List Pflegemittel -> msg) -> List Pflegemittel -> Cmd msg
pflegemittelSpeichern msg pflegemittel =
    let
        url = "../api/pflegemittel.php"
        decoder = Decode.list decodePflegemittel
        encoder = Encode.list << List.map encodePflegemittel
    in
        objekteSpeichern msg url decoder encoder pflegemittel

bestellungenLaden : (List Bestellung -> msg) -> Cmd msg
bestellungenLaden msg =
    let
        url = "../api/bestellungen.php"
        decoder = Decode.list decodeBestellung
    in
        objekteLaden msg url decoder
