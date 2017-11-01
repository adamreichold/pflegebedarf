module Pflegemittel exposing (main)

import Api exposing (Pflegemittel, pflegemittelLaden, pflegemittelSpeichern)

import Html exposing (Html, form, table, tr, th, td, text, input)
import Html.Attributes exposing (type_, value, checked)
import Html.Events exposing (onInput, onCheck, onSubmit)

import List
import Maybe

main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }

type alias Model =
    { pflegemittel : List Pflegemittel
    , neuesPflegemittel : Maybe Pflegemittel
    }

type Msg
    = PflegemittelLaden (List Pflegemittel)
    | BezeichnungAendern (Maybe Int, String)
    | EinheitAendern (Maybe Int, String)
    | WirdVerwendetAendern (Maybe Int, Bool)
    | NeueBezeichungAendern String
    | NeueEinheitAendern String
    | NeueWirdVerwendetAendern Bool
    | PflegemittelSpeichern

eigenschaftAendern : List Pflegemittel -> Maybe Int -> (Pflegemittel -> Pflegemittel) -> List Pflegemittel
eigenschaftAendern pflegemittel id aenderung =
    List.map (\val -> if val.id == id then (aenderung val) else val) pflegemittel

bezeichnungAendern : List Pflegemittel -> Maybe Int -> String -> List Pflegemittel
bezeichnungAendern pflegemittel id bezeichnung =
    eigenschaftAendern pflegemittel id <| \val -> { val | bezeichnung = bezeichnung }

einheitAendern : List Pflegemittel -> Maybe Int -> String -> List Pflegemittel
einheitAendern pflegemittel id einheit =
    eigenschaftAendern pflegemittel id <| \val -> { val | einheit = einheit }

wirdVerwendetAendern : List Pflegemittel -> Maybe Int -> Bool -> List Pflegemittel
wirdVerwendetAendern pflegemittel id wirdVerwendet =
    eigenschaftAendern pflegemittel id <| \val -> { val | wirdVerwendet = wirdVerwendet }

neueEigenschaftAendern : Maybe Pflegemittel -> (Pflegemittel -> Pflegemittel) -> Maybe Pflegemittel
neueEigenschaftAendern pflegemittel aenderung =
    let
        default = Pflegemittel Nothing "" "" True
    in
        Just <| aenderung <| Maybe.withDefault default pflegemittel

neueBezeichungAendern : Maybe Pflegemittel -> String -> Maybe Pflegemittel
neueBezeichungAendern pflegemittel bezeichnung =
    neueEigenschaftAendern pflegemittel <| \val -> { val | bezeichnung = bezeichnung }

neueEinheitAendern : Maybe Pflegemittel -> String -> Maybe Pflegemittel
neueEinheitAendern pflegemittel einheit =
    neueEigenschaftAendern pflegemittel <| \val -> { val | einheit = einheit }

neueWirdVerwenderAendern : Maybe Pflegemittel -> Bool -> Maybe Pflegemittel
neueWirdVerwenderAendern pflegemittel wirdVerwendet =
    neueEigenschaftAendern pflegemittel <| \val -> { val | wirdVerwendet = wirdVerwendet }

allePflegemittel : Model -> List Pflegemittel
allePflegemittel model =
    case model.neuesPflegemittel of
        Nothing -> model.pflegemittel
        Just neuesPflegemittel -> neuesPflegemittel :: model.pflegemittel

init : (Model, Cmd Msg)
init =
    ( Model [] Nothing
    , pflegemittelLaden PflegemittelLaden
    )

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        PflegemittelLaden pflegemittel ->
            ({ model | pflegemittel = pflegemittel, neuesPflegemittel = Nothing }, Cmd.none)

        BezeichnungAendern (id, bezeichnung) ->
            ({ model | pflegemittel = bezeichnungAendern model.pflegemittel id bezeichnung }, Cmd.none)

        EinheitAendern (id, einheit) ->
            ({ model | pflegemittel = einheitAendern model.pflegemittel id einheit }, Cmd.none)

        WirdVerwendetAendern (id, wirdVerwendet) ->
            ({ model | pflegemittel = wirdVerwendetAendern model.pflegemittel id wirdVerwendet }, Cmd.none)

        NeueBezeichungAendern bezeichnung ->
            ({ model | neuesPflegemittel = neueBezeichungAendern model.neuesPflegemittel bezeichnung }, Cmd.none)

        NeueEinheitAendern einheit ->
            ({ model | neuesPflegemittel = neueEinheitAendern model.neuesPflegemittel einheit }, Cmd.none)

        NeueWirdVerwendetAendern wirdVerwendet ->
            ({ model | neuesPflegemittel = neueWirdVerwenderAendern model.neuesPflegemittel wirdVerwendet }, Cmd.none)

        PflegemittelSpeichern ->
            (model, pflegemittelSpeichern PflegemittelLaden <| allePflegemittel model)

view : Model -> Html Msg
view model =
    form
        [ onSubmit PflegemittelSpeichern ]
        [ pflegemittelTabelle model.pflegemittel
        , input [ type_ "submit", value "Speichern" ] []
        ]

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


pflegemittelTabelle : List Pflegemittel -> Html Msg
pflegemittelTabelle pflegemittel =
    table [] <| [ pflegemittelUeberschrift ] ++ List.map pflegemittelZeile pflegemittel ++ [ pflegemittelNeueZeile ]

pflegemittelUeberschrift : Html Msg
pflegemittelUeberschrift =
    tr []
        [ th [] [ text "Bezeichnung" ]
        , th [] [ text "Einheit" ]
        , th [] [ text "Wird verwendet" ]
        ]

pflegemittelZeile : Pflegemittel -> Html Msg
pflegemittelZeile pflegemittel =
    tr []
        [ td [] [ input [ type_ "text", value pflegemittel.bezeichnung, onInput <| (curry BezeichnungAendern) pflegemittel.id ] [] ]
        , td [] [ input [ type_ "text", value pflegemittel.einheit, onInput <| (curry EinheitAendern) pflegemittel.id ] [] ]
        , td [] [ input [ type_ "checkbox", checked pflegemittel.wirdVerwendet, onCheck <| (curry WirdVerwendetAendern) pflegemittel.id ] [] ]
        ]

pflegemittelNeueZeile : Html Msg
pflegemittelNeueZeile =
    tr []
        [ td [] [ input [ type_ "text", onInput NeueBezeichungAendern ] [] ]
        , td [] [ input [ type_ "text", onInput NeueEinheitAendern ] [] ]
        , td [] [ input [ type_ "checkbox", checked True, onCheck NeueWirdVerwendetAendern ] [] ]
        ]
