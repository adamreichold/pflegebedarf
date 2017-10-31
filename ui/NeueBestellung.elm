module NeueBestellung exposing (main)

import Api exposing (Pflegemittel, Bestellung, pflegemittelLaden, bestellungenLaden)

import Html exposing (Html, text)

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
    , bestellungen : List Bestellung
    , letzteBestellung : Maybe Bestellung
    }

type Msg
    = NeuePflegemittel (List Pflegemittel)
    | NeueBestellungen (List Bestellung)

init : (Model, Cmd Msg)
init =
    ( Model [] [] Nothing
    , pflegemittelLaden NeuePflegemittel
    )

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        NeuePflegemittel pflegemittel ->
            ({ model | pflegemittel = pflegemittel }, bestellungenLaden NeueBestellungen)

        NeueBestellungen bestellungen ->
            ({ model | bestellungen = bestellungen, letzteBestellung = List.head bestellungen }, Cmd.none)

view : Model -> Html Msg
view model =
    text "TODO"

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
