module Pflegemittel exposing (main)

import Api exposing (Pflegemittel, pflegemittelLaden, pflegemittelSpeichern)
import Ui exposing (formular, tabelle, textfeld, zahlenfeld, ankreuzfeld)
import Html exposing (Html)
import Dict exposing (Dict)


main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = \model -> Sub.none
        }


type alias Model =
    { pflegemittel : List Pflegemittel
    , urspruenglichePflegemittel : List Pflegemittel
    , ungueltigeVerbraeuche : Dict Int String
    , ungueltigeMengen : Dict Int String
    , wirdGespeichert : Bool
    , meldung : String
    , letzterFehler : String
    }


type Msg
    = PflegemittelLaden (Result String (List Pflegemittel))
    | BezeichnungAendern Int String
    | EinheitAendern Int String
    | HerstellerUndProduktAendern Int String
    | PznOderRefAendern Int String
    | GeplanterVerbrauchAendern Int String
    | VorhandeneMengeAendern Int String
    | WirdVerwendetAendern Int Bool
    | WurdeGezaehltAendern Int Bool
    | PflegemittelSpeichern
    | PflegemittelGespeichert (Result String (List Pflegemittel))


eigenschaftAendern : List Pflegemittel -> Int -> (Pflegemittel -> Pflegemittel) -> List Pflegemittel
eigenschaftAendern pflegemittel id aenderung =
    let
        eintragAendern =
            \pflegemittel ->
                if pflegemittel.id == id then
                    aenderung pflegemittel
                else
                    pflegemittel
    in
        List.map eintragAendern pflegemittel


pflegemittelAuswerten : Model -> List Pflegemittel -> Model
pflegemittelAuswerten model pflegemittel =
    let
        mitNeuemPflegemittel =
            pflegemittel ++ [ Pflegemittel 0 "" "" "" "" 0 0 True False ]
    in
        { model
            | pflegemittel = mitNeuemPflegemittel
            , urspruenglichePflegemittel = mitNeuemPflegemittel
        }


geplanterVerbrauchAendern : Model -> Int -> String -> Model
geplanterVerbrauchAendern model id geplanterVerbrauch =
    case String.toInt geplanterVerbrauch of
        Ok geplanterVerbrauch ->
            let
                pflegemittel =
                    eigenschaftAendern model.pflegemittel id <| \val -> { val | geplanterVerbrauch = geplanterVerbrauch }
            in
                { model | pflegemittel = pflegemittel, ungueltigeVerbraeuche = Dict.remove id model.ungueltigeVerbraeuche }

        Err _ ->
            { model | ungueltigeVerbraeuche = Dict.insert id geplanterVerbrauch model.ungueltigeVerbraeuche }


vorhandeneMengeAendern : Model -> Int -> String -> Model
vorhandeneMengeAendern model id vorhandeneMenge =
    case String.toInt vorhandeneMenge of
        Ok vorhandeneMenge ->
            let
                pflegemittel =
                    eigenschaftAendern model.pflegemittel id <| \val -> { val | vorhandeneMenge = vorhandeneMenge }
            in
                { model | pflegemittel = pflegemittel, ungueltigeMengen = Dict.remove id model.ungueltigeMengen }

        Err _ ->
            { model | ungueltigeMengen = Dict.insert id vorhandeneMenge model.ungueltigeMengen }


geaendertePflegemittel : Model -> List Pflegemittel
geaendertePflegemittel model =
    let
        geaendert =
            \pflegemittel ->
                not <| List.member pflegemittel model.urspruenglichePflegemittel
    in
        List.filter geaendert model.pflegemittel


init : ( Model, Cmd Msg )
init =
    ( Model [] [] Dict.empty Dict.empty False "" ""
    , pflegemittelLaden PflegemittelLaden
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PflegemittelLaden (Ok pflegemittel) ->
            ( pflegemittelAuswerten model pflegemittel, Cmd.none )

        PflegemittelLaden (Err err) ->
            ( { model | letzterFehler = err }, Cmd.none )

        BezeichnungAendern id bezeichnung ->
            ( { model | pflegemittel = eigenschaftAendern model.pflegemittel id <| \val -> { val | bezeichnung = bezeichnung } }, Cmd.none )

        EinheitAendern id einheit ->
            ( { model | pflegemittel = eigenschaftAendern model.pflegemittel id <| \val -> { val | einheit = einheit } }, Cmd.none )

        HerstellerUndProduktAendern id herstellerUndProdukt ->
            ( { model | pflegemittel = eigenschaftAendern model.pflegemittel id <| \val -> { val | herstellerUndProdukt = herstellerUndProdukt } }, Cmd.none )

        PznOderRefAendern id pznOderRef ->
            ( { model | pflegemittel = eigenschaftAendern model.pflegemittel id <| \val -> { val | pznOderRef = pznOderRef } }, Cmd.none )

        GeplanterVerbrauchAendern id geplanterVerbrauch ->
            ( geplanterVerbrauchAendern model id geplanterVerbrauch, Cmd.none )

        VorhandeneMengeAendern id vorhandeneMenge ->
            ( vorhandeneMengeAendern model id vorhandeneMenge, Cmd.none )

        WirdVerwendetAendern id wirdVerwendet ->
            ( { model | pflegemittel = eigenschaftAendern model.pflegemittel id <| \val -> { val | wirdVerwendet = wirdVerwendet } }, Cmd.none )

        WurdeGezaehltAendern id wurdeGezaehlt ->
            ( { model | pflegemittel = eigenschaftAendern model.pflegemittel id <| \val -> { val | wurdeGezaehlt = wurdeGezaehlt } }, Cmd.none )

        PflegemittelSpeichern ->
            ( { model | wirdGespeichert = True, meldung = "Wird gespeichert...", letzterFehler = "" }, pflegemittelSpeichern PflegemittelGespeichert <| geaendertePflegemittel model )

        PflegemittelGespeichert (Ok pflegemittel) ->
            let
                newModel =
                    pflegemittelAuswerten model pflegemittel
            in
                ( { newModel | wirdGespeichert = False, meldung = "Wurde gespeichert." }, Cmd.none )

        PflegemittelGespeichert (Err err) ->
            ( { model | wirdGespeichert = False, letzterFehler = err }, Cmd.none )


view : Model -> Html Msg
view model =
    let
        absendenEnabled =
            not model.wirdGespeichert && Dict.isEmpty model.ungueltigeVerbraeuche && Dict.isEmpty model.ungueltigeMengen

        inhalt =
            [ pflegemittelTabelle model.pflegemittel model.ungueltigeVerbraeuche model.ungueltigeMengen ]
    in
        formular PflegemittelSpeichern "Speichern" absendenEnabled inhalt model.meldung model.letzterFehler


pflegemittelTabelle : List Pflegemittel -> Dict Int String -> Dict Int String -> Html Msg
pflegemittelTabelle pflegemittel ungueltigeVerbraeuche ungueltigeMengen =
    let
        ueberschriften =
            [ "Bezeichnung", "Einheit", "Hersteller und Produkt", "PZN oder REF", "geplanter Verbrauch", "vorhandene Menge", "wird verwendet", "wurde gezählt" ]

        zeile =
            \pflegemittel -> pflegemittelZeile pflegemittel ungueltigeVerbraeuche ungueltigeMengen
    in
        tabelle ueberschriften <| List.map zeile pflegemittel


pflegemittelZeile : Pflegemittel -> Dict Int String -> Dict Int String -> List (Html Msg)
pflegemittelZeile pflegemittel ungueltigeVerbraeuche ungueltigeMengen =
    let
        geplanterVerbrauch =
            Maybe.withDefault
                (toString <| pflegemittel.geplanterVerbrauch)
                (Dict.get pflegemittel.id ungueltigeVerbraeuche)

        vorhandeneMenge =
            Maybe.withDefault
                (toString <| pflegemittel.vorhandeneMenge)
                (Dict.get pflegemittel.id ungueltigeMengen)
    in
        [ textfeld pflegemittel.bezeichnung <| BezeichnungAendern pflegemittel.id
        , textfeld pflegemittel.einheit <| EinheitAendern pflegemittel.id
        , textfeld pflegemittel.herstellerUndProdukt <| HerstellerUndProduktAendern pflegemittel.id
        , textfeld pflegemittel.pznOderRef <| PznOderRefAendern pflegemittel.id
        , zahlenfeld "0" geplanterVerbrauch <| GeplanterVerbrauchAendern pflegemittel.id
        , zahlenfeld "0" vorhandeneMenge <| VorhandeneMengeAendern pflegemittel.id
        , ankreuzfeld pflegemittel.wirdVerwendet <| WirdVerwendetAendern pflegemittel.id
        , ankreuzfeld pflegemittel.wurdeGezaehlt <| WurdeGezaehltAendern pflegemittel.id
        ]
