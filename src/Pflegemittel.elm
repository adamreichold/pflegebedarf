module Pflegemittel exposing (main)

import Api exposing (Anbieter, Pflegemittel, anbieterLaden, pflegemittelLaden, pflegemittelSpeichern)
import Browser
import Dict exposing (Dict)
import Html exposing (Attribute, Html)
import Ui exposing (ankreuzfeld, auswahlfeld, formular, optionsfeld, p, tabelle, textfeld, versteckt, zahlenfeld, zentrierteElemente)


main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \model -> Sub.none
        }


type alias Model =
    { pflegemittel : List Pflegemittel
    , urspruenglichePflegemittel : List Pflegemittel
    , anbieter : List Anbieter
    , ungueltigeVerbraeuche : Dict Int String
    , ungueltigeMengen : Dict Int String
    , wirdGespeichert : Bool
    , nurVerwendeteZeigen : Bool
    , nurUngezaehlteZeigen : Bool
    , meldung : String
    , letzterFehler : String
    }


type Msg
    = PflegemittelLaden (Result String (List Pflegemittel))
    | AnbieterLaden (Result String (List Anbieter))
    | AnbieterAendern Int String
    | BezeichnungAendern Int String
    | EinheitAendern Int String
    | HerstellerUndProduktAendern Int String
    | PznOderRefAendern Int String
    | GeplanterVerbrauchAendern Int String
    | VorhandeneMengeAendern Int String
    | WirdVerwendetAendern Int Bool
    | WurdeGezaehltAendern Int Bool
    | NurVerwendeteZeigenAendern Bool
    | NurUngezaehlteZeigenAendern Bool
    | PflegemittelSpeichern
    | PflegemittelGespeichert (Result String (List Pflegemittel))


eigenschaftAendern : List Pflegemittel -> Int -> (Pflegemittel -> Pflegemittel) -> List Pflegemittel
eigenschaftAendern allePflegemittel id aenderung =
    let
        eintragAendern =
            \pflegemittel ->
                if pflegemittel.id == id then
                    aenderung pflegemittel

                else
                    pflegemittel
    in
    List.map eintragAendern allePflegemittel


pflegemittelAuswerten : Model -> List Pflegemittel -> Model
pflegemittelAuswerten model pflegemittel =
    let
        mitNeuemPflegemittel =
            pflegemittel ++ [ Pflegemittel 0 0 "" "" "" "" 0 0 True False ]
    in
    { model
        | pflegemittel = mitNeuemPflegemittel
        , urspruenglichePflegemittel = mitNeuemPflegemittel
    }


anbieterAendern : Model -> Int -> String -> Model
anbieterAendern model id neueAnbieterId =
    case String.toInt neueAnbieterId of
        Just anbieterId ->
            let
                pflegemittel =
                    eigenschaftAendern model.pflegemittel id <| \val -> { val | anbieterId = anbieterId }
            in
            { model | pflegemittel = pflegemittel }

        Nothing ->
            model


geplanterVerbrauchAendern : Model -> Int -> String -> Model
geplanterVerbrauchAendern model id neuerGeplanterVerbrauch =
    case String.toInt neuerGeplanterVerbrauch of
        Just geplanterVerbrauch ->
            let
                pflegemittel =
                    eigenschaftAendern model.pflegemittel id <| \val -> { val | geplanterVerbrauch = geplanterVerbrauch }
            in
            { model | pflegemittel = pflegemittel, ungueltigeVerbraeuche = Dict.remove id model.ungueltigeVerbraeuche }

        Nothing ->
            { model | ungueltigeVerbraeuche = Dict.insert id neuerGeplanterVerbrauch model.ungueltigeVerbraeuche }


vorhandeneMengeAendern : Model -> Int -> String -> Model
vorhandeneMengeAendern model id neueVorhandeneMenge =
    case String.toInt neueVorhandeneMenge of
        Just vorhandeneMenge ->
            let
                pflegemittel =
                    eigenschaftAendern model.pflegemittel id <| \val -> { val | vorhandeneMenge = vorhandeneMenge }
            in
            { model | pflegemittel = pflegemittel, ungueltigeMengen = Dict.remove id model.ungueltigeMengen }

        Nothing ->
            { model | ungueltigeMengen = Dict.insert id neueVorhandeneMenge model.ungueltigeMengen }


geaendertePflegemittel : Model -> List Pflegemittel
geaendertePflegemittel model =
    let
        geaendert =
            \pflegemittel ->
                not <| List.member pflegemittel model.urspruenglichePflegemittel
    in
    List.filter geaendert model.pflegemittel


init : () -> ( Model, Cmd Msg )
init _ =
    ( Model [] [] [] Dict.empty Dict.empty False True False "" ""
    , anbieterLaden AnbieterLaden
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PflegemittelLaden (Ok pflegemittel) ->
            ( pflegemittelAuswerten model pflegemittel, Cmd.none )

        PflegemittelLaden (Err err) ->
            ( { model | letzterFehler = err }, Cmd.none )

        AnbieterLaden (Ok anbieter) ->
            ( { model | anbieter = anbieter }, pflegemittelLaden PflegemittelLaden )

        AnbieterLaden (Err err) ->
            ( { model | letzterFehler = err }, Cmd.none )

        AnbieterAendern id anbieterId ->
            ( anbieterAendern model id anbieterId, Cmd.none )

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

        NurVerwendeteZeigenAendern nurVerwendeteZeigen ->
            ( { model | nurVerwendeteZeigen = nurVerwendeteZeigen }, Cmd.none )

        NurUngezaehlteZeigenAendern nurUngezaehlteZeigen ->
            ( { model | nurUngezaehlteZeigen = nurUngezaehlteZeigen }, Cmd.none )

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
            [ pflegemittelTabelle model.pflegemittel model.anbieter model.ungueltigeVerbraeuche model.ungueltigeMengen model.nurVerwendeteZeigen model.nurUngezaehlteZeigen
            , p zentrierteElemente <|
                []
                    ++ optionsfeld "Nur verwendete zeigen" model.nurVerwendeteZeigen NurVerwendeteZeigenAendern
                    ++ optionsfeld "Nur ungezählte anzeigen" model.nurUngezaehlteZeigen NurUngezaehlteZeigenAendern
            ]
    in
    formular PflegemittelSpeichern "Speichern" absendenEnabled inhalt model.meldung model.letzterFehler


pflegemittelTabelle : List Pflegemittel -> List Anbieter -> Dict Int String -> Dict Int String -> Bool -> Bool -> Html Msg
pflegemittelTabelle allePflegemittel alleAnbieter ungueltigeVerbraeuche ungueltigeMengen nurVerwendeteZeigen nurUngezaehlteZeigen =
    let
        ueberschriften =
            [ "Bezeichnung", "Einheit", "Anbieter", "Hersteller und Produkt", "PZN oder REF", "geplanter Verbrauch", "vorhandene Menge", "wird verwendet", "wurde gezählt" ]

        anbieterBezeichnungen =
            List.map (\anbieter -> ( String.fromInt anbieter.id, anbieter.bezeichnung )) alleAnbieter

        filter =
            \pflegemittel -> pflegemittel.id == 0 || ((not nurVerwendeteZeigen || pflegemittel.wirdVerwendet) && (not nurUngezaehlteZeigen || not pflegemittel.wurdeGezaehlt))

        zeile =
            \pflegemittel -> pflegemittelZeile pflegemittel anbieterBezeichnungen ungueltigeVerbraeuche ungueltigeMengen filter
    in
    tabelle ueberschriften <| List.map zeile allePflegemittel


pflegemittelZeile : Pflegemittel -> List ( String, String ) -> Dict Int String -> Dict Int String -> (Pflegemittel -> Bool) -> ( List (Attribute Msg), List (Html Msg) )
pflegemittelZeile pflegemittel anbieterBezeichnungen ungueltigeVerbraeuche ungueltigeMengen filter =
    let
        geplanterVerbrauch =
            Maybe.withDefault
                (String.fromInt <| pflegemittel.geplanterVerbrauch)
                (Dict.get pflegemittel.id ungueltigeVerbraeuche)

        vorhandeneMenge =
            Maybe.withDefault
                (String.fromInt <| pflegemittel.vorhandeneMenge)
                (Dict.get pflegemittel.id ungueltigeMengen)

        anbieterId =
            String.fromInt pflegemittel.anbieterId

        gefiltert =
            if filter pflegemittel then
                []

            else
                [ versteckt ]
    in
    ( gefiltert
    , [ textfeld pflegemittel.bezeichnung <| BezeichnungAendern pflegemittel.id
      , textfeld pflegemittel.einheit <| EinheitAendern pflegemittel.id
      , auswahlfeld anbieterBezeichnungen anbieterId <| AnbieterAendern pflegemittel.id
      , textfeld pflegemittel.herstellerUndProdukt <| HerstellerUndProduktAendern pflegemittel.id
      , textfeld pflegemittel.pznOderRef <| PznOderRefAendern pflegemittel.id
      , zahlenfeld "0" geplanterVerbrauch <| GeplanterVerbrauchAendern pflegemittel.id
      , zahlenfeld "0" vorhandeneMenge <| VorhandeneMengeAendern pflegemittel.id
      , ankreuzfeld pflegemittel.wirdVerwendet <| WirdVerwendetAendern pflegemittel.id
      , ankreuzfeld pflegemittel.wurdeGezaehlt <| WurdeGezaehltAendern pflegemittel.id
      ]
    )
