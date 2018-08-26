module Api exposing (Bestellung, BestellungMenge, BestellungPosten, Pflegemittel, PflegemittelBestand, bestellungenLaden, bestellungenMengeLaden, neueBestellungSpeichern, pflegemittelBestandLaden, pflegemittelLaden, pflegemittelSpeichern)

import Http
import Json.Decode as Decode
import Json.Decode.Extra exposing (andMap)
import Json.Encode as Encode
import Time exposing (millisToPosix)


type alias Pflegemittel =
    { id : Int
    , bezeichnung : String
    , einheit : String
    , herstellerUndProdukt : String
    , pznOderRef : String
    , geplanterVerbrauch : Int
    , vorhandeneMenge : Int
    , wirdVerwendet : Bool
    , wurdeGezaehlt : Bool
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


type alias PflegemittelBestand =
    { zeitstempel : Time.Posix
    , geplanterVerbrauch : Int
    , vorhandeneMenge : Int
    }


type alias BestellungMenge =
    { zeitstempel : Time.Posix
    , menge : Int
    }


decodeZeitstempel : Decode.Decoder Time.Posix
decodeZeitstempel =
    let
        toPosix =
            millisToPosix << (//) 1000
    in
    Decode.map toPosix Decode.int


encodeId : Int -> Encode.Value
encodeId id =
    if id /= 0 then
        Encode.int id

    else
        Encode.null


decodePflegemittel : Decode.Decoder Pflegemittel
decodePflegemittel =
    Decode.succeed Pflegemittel
        |> andMap (Decode.field "id" Decode.int)
        |> andMap (Decode.field "bezeichnung" Decode.string)
        |> andMap (Decode.field "einheit" Decode.string)
        |> andMap (Decode.field "hersteller_und_produkt" Decode.string)
        |> andMap (Decode.field "pzn_oder_ref" Decode.string)
        |> andMap (Decode.field "geplanter_verbrauch" Decode.int)
        |> andMap (Decode.field "vorhandene_menge" Decode.int)
        |> andMap (Decode.field "wird_verwendet" Decode.bool)
        |> andMap (Decode.field "wurde_gezaehlt" Decode.bool)


encodePflegemittel : Pflegemittel -> Encode.Value
encodePflegemittel pflegemittel =
    Encode.object
        [ ( "id", encodeId pflegemittel.id )
        , ( "bezeichnung", Encode.string pflegemittel.bezeichnung )
        , ( "einheit", Encode.string pflegemittel.einheit )
        , ( "hersteller_und_produkt", Encode.string pflegemittel.herstellerUndProdukt )
        , ( "pzn_oder_ref", Encode.string pflegemittel.pznOderRef )
        , ( "geplanter_verbrauch", Encode.int pflegemittel.geplanterVerbrauch )
        , ( "vorhandene_menge", Encode.int pflegemittel.vorhandeneMenge )
        , ( "wird_verwendet", Encode.bool pflegemittel.wirdVerwendet )
        , ( "wurde_gezaehlt", Encode.bool pflegemittel.wurdeGezaehlt )
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
        , ( "posten", Encode.list encodeBestellungPosten bestellung.posten )
        ]


decodePflegemittelBestand : Decode.Decoder PflegemittelBestand
decodePflegemittelBestand =
    Decode.map3 PflegemittelBestand
        (Decode.field "zeitstempel" decodeZeitstempel)
        (Decode.field "geplanter_verbrauch" Decode.int)
        (Decode.field "vorhandene_menge" Decode.int)


decodeBestellungMenge : Decode.Decoder BestellungMenge
decodeBestellungMenge =
    Decode.map2 BestellungMenge
        (Decode.field "zeitstempel" decodeZeitstempel)
        (Decode.field "menge" Decode.int)


fehlerBehandeln : Result Http.Error a -> Result String a
fehlerBehandeln result =
    case result of
        Ok val ->
            Ok val

        Err err ->
            let
                msg =
                    case err of
                        Http.BadStatus response ->
                            response.body

                        Http.BadPayload _ response ->
                            response.body

                        Http.Timeout ->
                            "Zeitüberschreitung"

                        Http.NetworkError ->
                            "Netzwerkfehler"

                        Http.BadUrl _ ->
                            "interner Fehler"
            in
            Err msg


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
            "/cgi-bin/pflegebedarf/api/pflegemittel"

        decoder =
            Decode.list decodePflegemittel
    in
    objektLaden msg url decoder


pflegemittelSpeichern : (Result String (List Pflegemittel) -> msg) -> List Pflegemittel -> Cmd msg
pflegemittelSpeichern msg pflegemittel =
    let
        url =
            "/cgi-bin/pflegebedarf/api/pflegemittel"

        decoder =
            Decode.list decodePflegemittel

        encoder =
            Encode.list encodePflegemittel
    in
    objektSpeichern msg url decoder encoder pflegemittel


bestellungenLaden : (Result String (List Bestellung) -> msg) -> Cmd msg
bestellungenLaden msg =
    let
        url =
            "/cgi-bin/pflegebedarf/api/bestellungen?limit=3"

        decoder =
            Decode.list decodeBestellung
    in
    objektLaden msg url decoder


neueBestellungSpeichern : (Result String (List Bestellung) -> msg) -> Bestellung -> Cmd msg
neueBestellungSpeichern msg bestellung =
    let
        url =
            "/cgi-bin/pflegebedarf/api/bestellungen?limit=3"

        decoder =
            Decode.list decodeBestellung

        encoder =
            encodeBestellung
    in
    objektSpeichern msg url decoder encoder bestellung


pflegemittelBestandLaden : Int -> (Result String (List PflegemittelBestand) -> msg) -> Cmd msg
pflegemittelBestandLaden id msg =
    let
        url =
            "/cgi-bin/pflegebedarf/api/pflegemittel_bestand?id=" ++ String.fromInt id

        decoder =
            Decode.list decodePflegemittelBestand
    in
    objektLaden msg url decoder


bestellungenMengeLaden : Int -> (Result String (List BestellungMenge) -> msg) -> Cmd msg
bestellungenMengeLaden id msg =
    let
        url =
            "/cgi-bin/pflegebedarf/api/bestellungen_menge?id=" ++ String.fromInt id

        decoder =
            Decode.list decodeBestellungMenge
    in
    objektLaden msg url decoder
