module PflegemittelBestand exposing (main)

import Api exposing (Pflegemittel, PflegemittelBestand, BestellungMenge, pflegemittelLaden, pflegemittelBestandLaden, bestellungenMengeLaden)
import Ui exposing (p, selectBox, fehlermeldung)
import Html exposing (Html, div)
import Time exposing (inSeconds)
import Date exposing (Date, toTime)
import Plot exposing (Series, DataPoint, viewSeries, dots, circle, triangle, square)


main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = \model -> Sub.none
        }


type alias Datenpunkt =
    { zeitstempel : Date
    , wert : Int
    }


type alias Model =
    { pflegemittel : List Pflegemittel
    , geplanterVerbrauch : List Datenpunkt
    , vorhandeneMenge : List Datenpunkt
    , bestellteMenge : List Datenpunkt
    , letzterFehler : String
    }


type Msg
    = PflegemittelLaden (Result String (List Pflegemittel))
    | PflegemittelAuswaehlen String
    | BestandGeladen Int (Result String (List PflegemittelBestand))
    | MengeGeladen Int (Result String (List BestellungMenge))


init : ( Model, Cmd Msg )
init =
    ( Model [] [] [] [] ""
    , pflegemittelLaden PflegemittelLaden
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PflegemittelLaden (Ok pflegemittel) ->
            let
                gewaehltesPflegemittel =
                    Maybe.map .id <| List.head pflegemittel
            in
                case gewaehltesPflegemittel of
                    Nothing ->
                        ( { model | pflegemittel = pflegemittel }, Cmd.none )

                    Just id ->
                        ( { model | pflegemittel = pflegemittel }, pflegemittelBestandLaden id <| BestandGeladen id )

        PflegemittelLaden (Err err) ->
            ( { model | letzterFehler = err }, Cmd.none )

        PflegemittelAuswaehlen id ->
            case String.toInt id of
                Ok id ->
                    ( model, pflegemittelBestandLaden id <| BestandGeladen id )

                Err _ ->
                    ( model, Cmd.none )

        BestandGeladen id (Ok bestand) ->
            let
                geplanterVerbrauch =
                    List.map (\val -> Datenpunkt val.zeitstempel val.geplanterVerbrauch) bestand

                vorhandeneMenge =
                    List.map (\val -> Datenpunkt val.zeitstempel val.vorhandeneMenge) bestand
            in
                ( { model | geplanterVerbrauch = geplanterVerbrauch, vorhandeneMenge = vorhandeneMenge }, bestellungenMengeLaden id <| MengeGeladen id )

        BestandGeladen id (Err err) ->
            ( { model | letzterFehler = err }, Cmd.none )

        MengeGeladen id (Ok menge) ->
            let
                bestellteMenge =
                    List.map (\val -> Datenpunkt val.zeitstempel val.menge) menge
            in
                ( { model | bestellteMenge = bestellteMenge }, Cmd.none )

        MengeGeladen id (Err err) ->
            ( { model | letzterFehler = err }, Cmd.none )


datenpunkt : (Float -> Float -> DataPoint msg) -> (Datenpunkt -> DataPoint msg)
datenpunkt form =
    \{ zeitstempel, wert } -> form (inSeconds <| toTime <| zeitstempel) (toFloat wert)


geplanterVerbrauch : Series Model Msg
geplanterVerbrauch =
    dots <| List.map (datenpunkt circle) << .geplanterVerbrauch


vorhandeneMenge : Series Model Msg
vorhandeneMenge =
    dots <| List.map (datenpunkt triangle) << .vorhandeneMenge


bestellteMenge : Series Model Msg
bestellteMenge =
    dots <| List.map (datenpunkt square) << .bestellteMenge


view : Model -> Html Msg
view model =
    let
        optionItem =
            \pm -> ( toString pm.id, pm.bezeichnung )

        options =
            List.map optionItem model.pflegemittel
    in
        div []
            [ p [] [ selectBox options PflegemittelAuswaehlen ]
            , viewSeries [ geplanterVerbrauch, vorhandeneMenge, bestellteMenge ] model
            , fehlermeldung model.letzterFehler
            ]
