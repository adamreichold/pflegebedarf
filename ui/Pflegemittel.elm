module Pflegemittel exposing (main)

import Api exposing (Pflegemittel, pflegemittelLaden, pflegemittelSpeichern)
import Ui exposing (formular, tabelle, textField, numberField, checkBox)
import Html exposing (Html)
import Dict exposing (Dict)


main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


type alias Model =
    { pflegemittel : List Pflegemittel
    , ungueltigeMengen : Dict Int String
    , letzterFehler : String
    }


type Msg
    = PflegemittelLaden (Result String (List Pflegemittel))
    | BezeichnungAendern ( Int, String )
    | EinheitAendern ( Int, String )
    | HerstellerUndProduktAendern ( Int, String )
    | PznOderRefAendern ( Int, String )
    | VorhandeneMengeAendern ( Int, String )
    | WirdVerwendetAendern ( Int, Bool )
    | PflegemittelSpeichern


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


gueltigePflegemittel : List Pflegemittel -> List Pflegemittel
gueltigePflegemittel pflegemittel =
    let
        neuesUngueltig =
            \pflegemittel ->
                pflegemittel.id == 0 && (String.isEmpty pflegemittel.bezeichnung || String.isEmpty pflegemittel.einheit)
    in
        List.filter (not << neuesUngueltig) pflegemittel


init : ( Model, Cmd Msg )
init =
    ( Model [] Dict.empty ""
    , pflegemittelLaden PflegemittelLaden
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PflegemittelLaden (Ok pflegemittel) ->
            ( { model | pflegemittel = pflegemittel ++ [ Pflegemittel 0 "" "" "" "" 0 True ] }, Cmd.none )

        PflegemittelLaden (Err err) ->
            ( { model | letzterFehler = err }, Cmd.none )

        BezeichnungAendern ( id, bezeichnung ) ->
            ( { model | pflegemittel = eigenschaftAendern model.pflegemittel id <| \val -> { val | bezeichnung = bezeichnung } }, Cmd.none )

        EinheitAendern ( id, einheit ) ->
            ( { model | pflegemittel = eigenschaftAendern model.pflegemittel id <| \val -> { val | einheit = einheit } }, Cmd.none )

        HerstellerUndProduktAendern ( id, herstellerUndProdukt ) ->
            ( { model | pflegemittel = eigenschaftAendern model.pflegemittel id <| \val -> { val | herstellerUndProdukt = herstellerUndProdukt } }, Cmd.none )

        PznOderRefAendern ( id, pznOderRef ) ->
            ( { model | pflegemittel = eigenschaftAendern model.pflegemittel id <| \val -> { val | pznOderRef = pznOderRef } }, Cmd.none )

        VorhandeneMengeAendern ( id, vorhandeneMenge ) ->
            ( vorhandeneMengeAendern model id vorhandeneMenge, Cmd.none )

        WirdVerwendetAendern ( id, wirdVerwendet ) ->
            ( { model | pflegemittel = eigenschaftAendern model.pflegemittel id <| \val -> { val | wirdVerwendet = wirdVerwendet } }, Cmd.none )

        PflegemittelSpeichern ->
            ( model, pflegemittelSpeichern PflegemittelLaden <| gueltigePflegemittel model.pflegemittel )


view : Model -> Html Msg
view model =
    let
        absendenEnabled =
            Dict.isEmpty model.ungueltigeMengen

        inhalt =
            [ pflegemittelTabelle model.pflegemittel model.ungueltigeMengen ]
    in
        formular PflegemittelSpeichern "Speichern" absendenEnabled inhalt model.letzterFehler


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


pflegemittelTabelle : List Pflegemittel -> Dict Int String -> Html Msg
pflegemittelTabelle pflegemittel ungueltigeMengen =
    let
        ueberschriften =
            [ "Bezeichnung", "Einheit", "Hersteller und Produkt", "PZN oder REF", "vorhandene Menge", "wird verwendet" ]

        zeile =
            \pflegemittel -> pflegemittelZeile pflegemittel ungueltigeMengen
    in
        tabelle ueberschriften <| List.map zeile pflegemittel


pflegemittelZeile : Pflegemittel -> Dict Int String -> List (Html Msg)
pflegemittelZeile pflegemittel ungueltigeMengen =
    let
        vorhandeneMenge =
            Maybe.withDefault
                (toString <| pflegemittel.vorhandeneMenge)
                (Dict.get pflegemittel.id ungueltigeMengen)
    in
        [ textField pflegemittel.bezeichnung <| curry BezeichnungAendern <| pflegemittel.id
        , textField pflegemittel.einheit <| curry EinheitAendern <| pflegemittel.id
        , textField pflegemittel.herstellerUndProdukt <| curry HerstellerUndProduktAendern <| pflegemittel.id
        , textField pflegemittel.pznOderRef <| curry PznOderRefAendern <| pflegemittel.id
        , numberField "0" vorhandeneMenge <| curry VorhandeneMengeAendern <| pflegemittel.id
        , checkBox pflegemittel.wirdVerwendet <| curry WirdVerwendetAendern <| pflegemittel.id
        ]
