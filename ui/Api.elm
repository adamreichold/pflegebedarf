module Api exposing (Pflegemittel, BestellungPosten, Bestellung, pflegemittelLaden, pflegemittelSpeichern, bestellungenLaden, neueBestellungSpeichern)

import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Date exposing (Date, fromTime, toTime)
import Time exposing (Time, second, inSeconds)


type alias Pflegemittel =
    { id : Int
    , bezeichnung : String
    , einheit : String
    , pznOderRef : String
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
    , nachricht : String
    , posten : List BestellungPosten
    }


decodeZeitstempel : Decode.Decoder Date
decodeZeitstempel =
    let
        toDate =
            fromTime << (*) second << toFloat
    in
        Decode.map toDate Decode.int


encodeId : Int -> Encode.Value
encodeId id =
    if id /= 0 then
        Encode.int id
    else
        Encode.null


encodeZeitstempel : Date -> Encode.Value
encodeZeitstempel zeitstempel =
    Encode.int <| truncate <| inSeconds <| toTime zeitstempel


decodePflegemittel : Decode.Decoder Pflegemittel
decodePflegemittel =
    Decode.map5 Pflegemittel
        (Decode.field "id" Decode.int)
        (Decode.field "bezeichnung" Decode.string)
        (Decode.field "einheit" Decode.string)
        (Decode.field "pzn_oder_ref" Decode.string)
        (Decode.field "wird_verwendet" Decode.bool)


encodePflegemittel : Pflegemittel -> Encode.Value
encodePflegemittel pflegemittel =
    Encode.object
        [ ( "id", encodeId pflegemittel.id )
        , ( "bezeichnung", Encode.string pflegemittel.bezeichnung )
        , ( "einheit", Encode.string pflegemittel.einheit )
        , ( "pzn_oder_ref", Encode.string pflegemittel.pznOderRef )
        , ( "wird_verwendet", Encode.bool pflegemittel.wirdVerwendet )
        ]


decodeBestellungPosten : Decode.Decoder BestellungPosten
decodeBestellungPosten =
    Decode.map2 BestellungPosten
        (Decode.field "pflegemittel_id" Decode.int)
        (Decode.field "menge" Decode.int)


encodeBestellungPosten : BestellungPosten -> Encode.Value
encodeBestellungPosten posten =
    Encode.object
        [ ( "pflegemittel_id", Encode.int posten.pflegemittelId )
        , ( "menge", Encode.int posten.menge )
        ]


decodeBestellung : Decode.Decoder Bestellung
decodeBestellung =
    Decode.map5 Bestellung
        (Decode.field "id" Decode.int)
        (Decode.field "zeitstempel" decodeZeitstempel)
        (Decode.field "empfaenger" Decode.string)
        (Decode.field "nachricht" Decode.string)
        (Decode.field "posten" (Decode.list decodeBestellungPosten))


encodeBestellung : Bestellung -> Encode.Value
encodeBestellung bestellung =
    Encode.object
        [ ( "id", encodeId bestellung.id )
        , ( "zeitstempel", encodeZeitstempel bestellung.zeitstempel )
        , ( "empfaenger", Encode.string bestellung.empfaenger )
        , ( "nachricht", Encode.string bestellung.nachricht )
        , ( "posten", Encode.list <| List.map encodeBestellungPosten bestellung.posten )
        ]


fehlerBehandeln : Result Http.Error (List a) -> List a
fehlerBehandeln result =
    case result of
        Ok val ->
            val

        Err err ->
            let
                _ =
                    Debug.log "Err" err
            in
                []


objekteLaden : (List a -> msg) -> String -> Decode.Decoder (List a) -> Cmd msg
objekteLaden msg url decoder =
    Http.send (msg << fehlerBehandeln) (Http.get url decoder)


objekteSpeichern : (List a -> msg) -> String -> Decode.Decoder (List a) -> (b -> Encode.Value) -> b -> Cmd msg
objekteSpeichern msg url decoder encoder objekte =
    let
        body =
            Http.jsonBody <| encoder objekte
    in
        Http.send (msg << fehlerBehandeln) (Http.post url body decoder)


pflegemittelLaden : (List Pflegemittel -> msg) -> Cmd msg
pflegemittelLaden msg =
    let
        url =
            "../api/pflegemittel.php"

        decoder =
            Decode.list decodePflegemittel
    in
        objekteLaden msg url decoder


pflegemittelSpeichern : (List Pflegemittel -> msg) -> List Pflegemittel -> Cmd msg
pflegemittelSpeichern msg pflegemittel =
    let
        url =
            "../api/pflegemittel.php"

        decoder =
            Decode.list decodePflegemittel

        encoder =
            Encode.list << List.map encodePflegemittel
    in
        objekteSpeichern msg url decoder encoder pflegemittel


bestellungenLaden : (List Bestellung -> msg) -> Cmd msg
bestellungenLaden msg =
    let
        url =
            "../api/bestellungen.php?limit=3"

        decoder =
            Decode.list decodeBestellung
    in
        objekteLaden msg url decoder


neueBestellungSpeichern : (List Bestellung -> msg) -> Bestellung -> Cmd msg
neueBestellungSpeichern msg bestellung =
    let
        url =
            "../api/bestellungen.php?limit=3"

        decoder =
            Decode.list decodeBestellung

        encoder =
            encodeBestellung
    in
        objekteSpeichern msg url decoder encoder bestellung
