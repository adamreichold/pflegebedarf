module NeueBestellung exposing (main)

import Api exposing (Pflegemittel, BestellungPosten, Bestellung, pflegemittelLaden, bestellungenLaden, neueBestellungSpeichern)
import Html exposing (Html, form, p, table, tr, th, td, text, input, textarea)
import Html.Attributes exposing (type_, placeholder, value, disabled)
import Html.Events exposing (onSubmit, onInput)
import Dict exposing (Dict)
import Date exposing (Date)
import Task


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
    , neueBestellung : Bestellung
    , ungueltigeMengen : Dict Int String
    }


type Msg
    = PflegemittelLaden (List Pflegemittel)
    | BestellungenLaden (List Bestellung)
    | ZeitstempelAendern Date
    | EmpfaengerAendern String
    | NachrichtAendern String
    | MengeAendern ( Int, String )
    | NeueBestellungSpeichern


mittelwert : List Int -> Maybe Float
mittelwert werte =
    if List.isEmpty werte then
        Nothing
    else
        Just <| (toFloat <| List.sum werte) / (toFloat <| List.length werte)


menge : Int -> Bestellung -> Int
menge pflegemittelId bestellung =
    let
        predicate =
            (==) pflegemittelId << .pflegemittelId

        filter =
            List.head << List.filter predicate << .posten
    in
        Maybe.withDefault 0 <| Maybe.map .menge <| filter bestellung


mengeAendern : Int -> Int -> Bestellung -> Bestellung
mengeAendern pflegemittelId menge bestellung =
    let
        aenderung =
            \posten ->
                if posten.pflegemittelId == pflegemittelId then
                    { posten | menge = menge }
                else
                    posten
    in
        { bestellung | posten = List.map aenderung bestellung.posten }


mittlereMenge : Int -> List Bestellung -> Int
mittlereMenge pflegemittelId bestellungen =
    let
        mengen =
            List.map (menge pflegemittelId) bestellungen
    in
        Maybe.withDefault 0 <| Maybe.map ceiling <| mittelwert mengen


letzteMenge : Int -> Maybe Bestellung -> Int
letzteMenge pflegemittelId letzteBestellung =
    Maybe.withDefault 0 <| Maybe.map (menge pflegemittelId) letzteBestellung


neueBestellungAnlegen : List Pflegemittel -> Maybe Bestellung -> Bestellung
neueBestellungAnlegen pflegemittel letzteBestellung =
    let
        empfaenger =
            Maybe.withDefault "" <| Maybe.map .empfaenger letzteBestellung

        nachricht =
            Maybe.withDefault "" <| Maybe.map .nachricht letzteBestellung

        neuerPosten =
            \pflegemittelId -> BestellungPosten pflegemittelId <| letzteMenge pflegemittelId letzteBestellung

        posten =
            List.map neuerPosten <| List.map .id pflegemittel
    in
        Bestellung 0 (Date.fromTime 0.0) empfaenger nachricht posten


neueBestellungAendern : Model -> (Bestellung -> Bestellung) -> Model
neueBestellungAendern model aenderung =
    { model | neueBestellung = aenderung model.neueBestellung }


neueBestellungMengeAendern : Model -> Int -> String -> Model
neueBestellungMengeAendern model pflegemittelId menge =
    case String.toInt menge of
        Ok menge ->
            let
                neueBestellung =
                    mengeAendern pflegemittelId menge model.neueBestellung
            in
                { model | neueBestellung = neueBestellung, ungueltigeMengen = Dict.remove pflegemittelId model.ungueltigeMengen }

        Err err ->
            { model | ungueltigeMengen = Dict.insert pflegemittelId menge model.ungueltigeMengen }


init : ( Model, Cmd Msg )
init =
    ( Model [] [] Nothing (neueBestellungAnlegen [] Nothing) Dict.empty
    , pflegemittelLaden PflegemittelLaden
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PflegemittelLaden pflegemittel ->
            ( { model | pflegemittel = List.filter .wirdVerwendet pflegemittel }, bestellungenLaden BestellungenLaden )

        BestellungenLaden bestellungen ->
            let
                letzteBestellung =
                    List.head bestellungen

                newModel =
                    { model
                        | bestellungen = bestellungen
                        , letzteBestellung = letzteBestellung
                        , neueBestellung = neueBestellungAnlegen model.pflegemittel letzteBestellung
                    }
            in
                ( newModel, Task.perform ZeitstempelAendern Date.now )

        ZeitstempelAendern zeitstempel ->
            ( neueBestellungAendern model <| \val -> { val | zeitstempel = zeitstempel }, Cmd.none )

        EmpfaengerAendern empfaenger ->
            ( neueBestellungAendern model <| \val -> { val | empfaenger = empfaenger }, Cmd.none )

        NachrichtAendern nachricht ->
            ( neueBestellungAendern model <| \val -> { val | nachricht = nachricht }, Cmd.none )

        MengeAendern ( pflegemittelId, menge ) ->
            ( neueBestellungMengeAendern model pflegemittelId menge, Cmd.none )

        NeueBestellungSpeichern ->
            ( model, neueBestellungSpeichern BestellungenLaden model.neueBestellung )


view : Model -> Html Msg
view model =
    form
        [ onSubmit NeueBestellungSpeichern ]
        [ neueBestellungTabelle model.pflegemittel model.bestellungen model.letzteBestellung model.neueBestellung model.ungueltigeMengen
        , p [] [ input [ type_ "email", placeholder "Empfänger", value model.neueBestellung.empfaenger, onInput EmpfaengerAendern ] [] ]
        , p [] [ textarea [ placeholder "Nachricht", value model.neueBestellung.nachricht, onInput NachrichtAendern ] [] ]
        , p [] [ input [ type_ "submit", value "Versenden", disabled <| not <| Dict.isEmpty model.ungueltigeMengen ] [] ]
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


neueBestellungTabelle : List Pflegemittel -> List Bestellung -> Maybe Bestellung -> Bestellung -> Dict Int String -> Html Msg
neueBestellungTabelle pflegemittel bestellungen letzteBestellung neueBestellung ungueltigeMengen =
    let
        zeile =
            \pflegemittel -> neueBestellungZeile pflegemittel bestellungen letzteBestellung neueBestellung ungueltigeMengen
    in
        table [] <| neueBestellungUeberschrift :: List.map zeile pflegemittel


neueBestellungUeberschrift : Html Msg
neueBestellungUeberschrift =
    tr []
        [ th [] [ text "Bezeichnung" ]
        , th [] [ text "Einheit" ]
        , th [] [ text "mittlere Menge" ]
        , th [] [ text "letzte Menge" ]
        , th [] [ text "Menge" ]
        ]


neueBestellungZeile : Pflegemittel -> List Bestellung -> Maybe Bestellung -> Bestellung -> Dict Int String -> Html Msg
neueBestellungZeile pflegemittel bestellungen letzteBestellung neueBestellung ungueltigeMengen =
    let
        mittlere =
            toString <| mittlereMenge pflegemittel.id bestellungen

        letzte =
            toString <| letzteMenge pflegemittel.id letzteBestellung

        neue =
            Maybe.withDefault
                (toString <| menge pflegemittel.id neueBestellung)
                (Dict.get pflegemittel.id ungueltigeMengen)
    in
        tr []
            [ td [] [ text pflegemittel.bezeichnung ]
            , td [] [ text pflegemittel.einheit ]
            , td [] [ text mittlere ]
            , td [] [ text letzte ]
            , td [] [ input [ type_ "number", Html.Attributes.min "0", value neue, onInput <| curry MengeAendern <| pflegemittel.id ] [] ]
            ]
