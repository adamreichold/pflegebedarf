module Api exposing (Pflegemittel, BestellungPosten, Bestellung, pflegemittelLaden, pflegemittelSpeichern, bestellungenLaden, neueBestellungSpeichern)

import Http
import Json.Decode as Decode
import Json.Encode as Encode


type alias Pflegemittel =
    { id : Int
    , bezeichnung : String
    , einheit : String
    , pznOderRef : String
    , vorhandeneMenge : Int
    , wirdVerwendet : Bool
    }


type alias BestellungPosten =
    { pflegemittelId : Int
    , menge : Int
    }


type alias Bestellung =
    { id : Int
    , empfaenger : String
    , nachricht : String
    , posten : List BestellungPosten
    }


encodeId : Int -> Encode.Value
encodeId id =
    if id /= 0 then
        Encode.int id
    else
        Encode.null


decodePflegemittel : Decode.Decoder Pflegemittel
decodePflegemittel =
    Decode.map6 Pflegemittel
        (Decode.field "id" Decode.int)
        (Decode.field "bezeichnung" Decode.string)
        (Decode.field "einheit" Decode.string)
        (Decode.field "pzn_oder_ref" Decode.string)
        (Decode.field "vorhandene_menge" Decode.int)
        (Decode.field "wird_verwendet" Decode.bool)


encodePflegemittel : Pflegemittel -> Encode.Value
encodePflegemittel pflegemittel =
    Encode.object
        [ ( "id", encodeId pflegemittel.id )
        , ( "bezeichnung", Encode.string pflegemittel.bezeichnung )
        , ( "einheit", Encode.string pflegemittel.einheit )
        , ( "pzn_oder_ref", Encode.string pflegemittel.pznOderRef )
        , ( "vorhandene_menge", Encode.int pflegemittel.vorhandeneMenge )
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
    Decode.map4 Bestellung
        (Decode.field "id" Decode.int)
        (Decode.field "empfaenger" Decode.string)
        (Decode.field "nachricht" Decode.string)
        (Decode.field "posten" (Decode.list decodeBestellungPosten))


encodeBestellung : Bestellung -> Encode.Value
encodeBestellung bestellung =
    Encode.object
        [ ( "id", encodeId bestellung.id )
        , ( "empfaenger", Encode.string bestellung.empfaenger )
        , ( "nachricht", Encode.string bestellung.nachricht )
        , ( "posten", Encode.list <| List.map encodeBestellungPosten bestellung.posten )
        ]


fehlerBehandeln : Result Http.Error a -> Result String a
fehlerBehandeln result =
    case result of
        Ok val ->
            Ok val

        Err (Http.BadPayload err response) ->
            Err response.body

        Err err ->
            Err <| toString err


objektLaden : (Result String a -> msg) -> String -> Decode.Decoder a -> Cmd msg
objektLaden msg url decoder =
    Http.send (msg << fehlerBehandeln) (Http.get url decoder)


objektSpeichern : (Result String a -> msg) -> String -> Decode.Decoder a -> (b -> Encode.Value) -> b -> Cmd msg
objektSpeichern msg url decoder encoder objekt =
    let
        body =
            Http.jsonBody <| encoder objekt
    in
        Http.send (msg << fehlerBehandeln) (Http.post url body decoder)


pflegemittelLaden : (Result String (List Pflegemittel) -> msg) -> Cmd msg
pflegemittelLaden msg =
    let
        url =
            "../api/pflegemittel.php"

        decoder =
            Decode.list decodePflegemittel
    in
        objektLaden msg url decoder


pflegemittelSpeichern : (Result String (List Pflegemittel) -> msg) -> List Pflegemittel -> Cmd msg
pflegemittelSpeichern msg pflegemittel =
    let
        url =
            "../api/pflegemittel.php"

        decoder =
            Decode.list decodePflegemittel

        encoder =
            Encode.list << List.map encodePflegemittel
    in
        objektSpeichern msg url decoder encoder pflegemittel


bestellungenLaden : (Result String (List Bestellung) -> msg) -> Cmd msg
bestellungenLaden msg =
    let
        url =
            "../api/bestellungen.php?limit=3"

        decoder =
            Decode.list decodeBestellung
    in
        objektLaden msg url decoder


neueBestellungSpeichern : (Result String (List Bestellung) -> msg) -> Bestellung -> Cmd msg
neueBestellungSpeichern msg bestellung =
    let
        url =
            "../api/bestellungen.php?limit=3"

        decoder =
            Decode.list decodeBestellung

        encoder =
            encodeBestellung
    in
        objektSpeichern msg url decoder encoder bestellung
