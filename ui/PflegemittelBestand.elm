module PflegemittelBestand exposing (main)

import Api exposing (Pflegemittel, PflegemittelBestand, BestellungMenge, pflegemittelLaden, pflegemittelBestandLaden, bestellungenMengeLaden)
import Ui exposing (p, auswahlfeld, fehlermeldung)
import Html exposing (Html, div, ul, li, text)
import Html.Attributes exposing (style)
import Svg exposing (Svg, foreignObject)
import Svg.Attributes exposing (stroke, x, y, width, height)
import Time exposing (inSeconds, second)
import Date exposing (Date, toTime, fromTime, day, month)
import Plot exposing (Series, Axis, DataPoint, LabelCustomizations, viewSeriesCustom, defaultSeriesPlotCustomizations, customAxis, viewSquare, viewLabel)


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


datenpunkt : (Float -> Float -> DataPoint Msg) -> (Datenpunkt -> DataPoint Msg)
datenpunkt form =
    \{ zeitstempel, wert } -> form (inSeconds <| toTime <| zeitstempel) (toFloat wert)


zeitreihe : Svg Msg -> (Model -> List Datenpunkt) -> Series Model Msg
zeitreihe form eigenschaft =
    { axis = Plot.axisAtMin
    , interpolation = Plot.Linear Nothing [ stroke "lightgrey" ]
    , toDataPoints = List.map (datenpunkt <| Plot.dot <| form) << eigenschaft
    }


geplanterVerbrauch : Series Model Msg
geplanterVerbrauch =
    zeitreihe (viewSquare 3 "red") .geplanterVerbrauch


vorhandeneMenge : Series Model Msg
vorhandeneMenge =
    zeitreihe (viewSquare 3 "green") .vorhandeneMenge


bestellteMenge : Series Model Msg
bestellteMenge =
    zeitreihe (viewSquare 3 "blue") .bestellteMenge


legende : Svg Msg
legende =
    let
        listItem color label =
            li [ style [ ( "list-style-type", "square" ), ( "color", color ), ( "font-size", "xx-small" ) ] ] [ text label ]
    in
        foreignObject [ x "-7.5em", y "0", width "10em", height "5em" ]
            [ ul []
                [ listItem "red" "geplanter Verbrauch"
                , listItem "green" "vorhandene Menge"
                , listItem "blue" "bestellte Menge"
                ]
            ]


tagUndMontag : Float -> LabelCustomizations
tagUndMontag position =
    let
        datum =
            fromTime <| position * second

        text =
            (toString <| day datum) ++ ". " ++ (toString <| month datum)
    in
        { position = position
        , view = viewLabel [] text
        }


zeitachse : Axis
zeitachse =
    customAxis <|
        \summary ->
            { position = Plot.closestToZero
            , axisLine = Just (Plot.simpleLine summary)
            , ticks = List.map Plot.simpleTick (Plot.decentPositions summary)
            , labels = List.map tagUndMontag (Plot.decentPositions summary)
            , flipAnchor = False
            }


view : Model -> Html Msg
view model =
    let
        optionItem =
            \pm -> ( toString pm.id, pm.bezeichnung )

        options =
            List.map optionItem model.pflegemittel

        plotCustomizations =
            { defaultSeriesPlotCustomizations
                | horizontalAxis = zeitachse
                , toDomainLowest = min 0
                , junk = \summary -> [ Plot.junk legende summary.x.dataMax summary.y.max ]
            }
    in
        div []
            [ p [] [ auswahlfeld options PflegemittelAuswaehlen ]
            , viewSeriesCustom plotCustomizations [ geplanterVerbrauch, vorhandeneMenge, bestellteMenge ] model
            , fehlermeldung model.letzterFehler
            ]
