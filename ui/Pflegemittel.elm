module Pflegemittel exposing (main)

import Api exposing (Pflegemittel, pflegemittelLaden, pflegemittelSpeichern)
import Html exposing (Html, form, p, table, tr, th, td, text, input)
import Html.Attributes exposing (type_, value, checked, disabled)
import Html.Events exposing (onInput, onCheck, onSubmit)
import Json.Encode
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
            ( { model | pflegemittel = pflegemittel ++ [ Pflegemittel 0 "" "" "" 0 True ] }, Cmd.none )

        PflegemittelLaden (Err err) ->
            ( { model | letzterFehler = err }, Cmd.none )

        BezeichnungAendern ( id, bezeichnung ) ->
            ( { model | pflegemittel = eigenschaftAendern model.pflegemittel id <| \val -> { val | bezeichnung = bezeichnung } }, Cmd.none )

        EinheitAendern ( id, einheit ) ->
            ( { model | pflegemittel = eigenschaftAendern model.pflegemittel id <| \val -> { val | einheit = einheit } }, Cmd.none )

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
        letzterFehler =
            Html.Attributes.property "innerHTML" (Json.Encode.string model.letzterFehler)
    in
        form
            [ onSubmit PflegemittelSpeichern ]
            [ pflegemittelTabelle model.pflegemittel model.ungueltigeMengen
            , p [] [ input [ type_ "submit", value "Speichern", disabled <| not <| Dict.isEmpty model.ungueltigeMengen ] [] ]
            , p [ letzterFehler ] []
            ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


pflegemittelTabelle : List Pflegemittel -> Dict Int String -> Html Msg
pflegemittelTabelle pflegemittel ungueltigeMengen =
    let
        zeile =
            \pflegemittel -> pflegemittelZeile pflegemittel ungueltigeMengen
    in
        table [] <| pflegemittelUeberschrift :: List.map zeile pflegemittel


pflegemittelUeberschrift : Html Msg
pflegemittelUeberschrift =
    tr []
        [ th [] [ text "Bezeichnung" ]
        , th [] [ text "Einheit" ]
        , th [] [ text "PZN oder REF" ]
        , th [] [ text "vorhandene Menge" ]
        , th [] [ text "wird verwendet" ]
        ]


pflegemittelZeile : Pflegemittel -> Dict Int String -> Html Msg
pflegemittelZeile pflegemittel ungueltigeMengen =
    let
        vorhandeneMenge =
            Maybe.withDefault
                (toString <| pflegemittel.vorhandeneMenge)
                (Dict.get pflegemittel.id ungueltigeMengen)
    in
        tr []
            [ td [] [ input [ type_ "text", value pflegemittel.bezeichnung, onInput <| curry BezeichnungAendern <| pflegemittel.id ] [] ]
            , td [] [ input [ type_ "text", value pflegemittel.einheit, onInput <| curry EinheitAendern <| pflegemittel.id ] [] ]
            , td [] [ input [ type_ "text", value pflegemittel.pznOderRef, onInput <| curry PznOderRefAendern <| pflegemittel.id ] [] ]
            , td [] [ input [ type_ "number", value vorhandeneMenge, onInput <| curry VorhandeneMengeAendern <| pflegemittel.id ] [] ]
            , td [] [ input [ type_ "checkbox", checked pflegemittel.wirdVerwendet, onCheck <| curry WirdVerwendetAendern <| pflegemittel.id ] [] ]
            ]
