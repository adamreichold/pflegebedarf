module Api exposing (Bestellung, BestellungPosten, Pflegemittel, bestellungenLaden, neueBestellungSpeichern, pflegemittelLaden, pflegemittelSpeichern)

import Http
import Json.Decode as Decode
import Json.Decode.Extra exposing (andMap)
import Json.Encode as Encode
import Url.Builder as Url


type alias Anbieter =
    { id : Int
    , bezeichnung : String
    }


type alias Pflegemittel =
    { id : Int
    , anbieterId : Int
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
    , anbieterId : Int
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
    Decode.succeed Pflegemittel
        |> andMap (Decode.field "id" Decode.int)
        |> andMap (Decode.field "anbieter_id" Decode.int)
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
        , ( "anbieter_id", Encode.int pflegemittel.anbieterId )
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
    Decode.map5 Bestellung
        (Decode.field "id" Decode.int)
        (Decode.field "anbieter_id" Decode.int)
        (Decode.field "empfaenger" Decode.string)
        (Decode.field "nachricht" Decode.string)
        (Decode.field "posten" (Decode.list decodeBestellungPosten))


encodeBestellung : Bestellung -> Encode.Value
encodeBestellung bestellung =
    Encode.object
        [ ( "id", encodeId bestellung.id )
        , ( "anbieter_id", Encode.int bestellung.anbieterId )
        , ( "empfaenger", Encode.string bestellung.empfaenger )
        , ( "nachricht", Encode.string bestellung.nachricht )
        , ( "posten", Encode.list encodeBestellungPosten bestellung.posten )
        ]


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
            Url.absolute [ "api", "pflegemittel" ] []

        decoder =
            Decode.list decodePflegemittel
    in
    objektLaden msg url decoder


pflegemittelSpeichern : (Result String (List Pflegemittel) -> msg) -> List Pflegemittel -> Cmd msg
pflegemittelSpeichern msg pflegemittel =
    let
        url =
            Url.absolute [ "api", "pflegemittel" ] []

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
            Url.absolute [ "api", "bestellungen" ] [ Url.int "bis_zu" 3 ]

        decoder =
            Decode.list decodeBestellung
    in
    objektLaden msg url decoder


neueBestellungSpeichern : (Result String (List Bestellung) -> msg) -> Bestellung -> Cmd msg
neueBestellungSpeichern msg bestellung =
    let
        url =
            Url.absolute [ "api", "bestellungen" ] [ Url.int "bis_zu" 3 ]

        decoder =
            Decode.list decodeBestellung

        encoder =
            encodeBestellung
    in
    objektSpeichern msg url decoder encoder bestellung
