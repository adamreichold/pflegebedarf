module Pflegemittel exposing (main)

import Api exposing (Pflegemittel, pflegemittelLaden)

import Html exposing (Html, table, tr, th, td, text)

import List

main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }

type alias Model =
    { pflegemittel : List Pflegemittel
    }

type Msg
    = NeuePflegemittel (List Pflegemittel)

init : (Model, Cmd Msg)
init =
    ( Model []
    , pflegemittelLaden NeuePflegemittel
    )

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        NeuePflegemittel pflegemittel ->
            ({ model | pflegemittel = pflegemittel }, Cmd.none)

view : Model -> Html Msg
view model =
    pflegemittelTabelle model.pflegemittel

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


pflegemittelTabelle : List Pflegemittel -> Html Msg
pflegemittelTabelle pflegemittel =
    table []
        (pflegemittelUeberschrift :: List.map pflegemittelZeile pflegemittel)

pflegemittelUeberschrift : Html Msg
pflegemittelUeberschrift =
    tr []
        [ th [] [ text "Bezeichnung" ]
        , th [] [ text "Einheit" ]
        ]

pflegemittelZeile : Pflegemittel -> Html Msg
pflegemittelZeile pflegemittel =
    tr []
        [ td [] [ text pflegemittel.bezeichnung ]
        , td [] [ text pflegemittel.einheit ]
        ]
