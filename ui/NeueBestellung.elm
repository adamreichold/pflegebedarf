module NeueBestellung exposing (main)

import Api exposing (Pflegemittel, BestellungPosten, Bestellung, pflegemittelLaden, bestellungenLaden, neueBestellungSpeichern)
import Ui exposing (p, formular, tabelle, textbereich, zahlenfeld, emailfeld)
import Html exposing (Html, text)
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
    , bestellungen : List Bestellung
    , letzteBestellung : Maybe Bestellung
    , neueBestellung : Bestellung
    , ungueltigeMengen : Dict Int String
    , wirdVersendet : Bool
    , meldung : String
    , letzterFehler : String
    }


type Msg
    = PflegemittelLaden (Result String (List Pflegemittel))
    | BestellungenLaden (Result String (List Bestellung))
    | EmpfaengerAendern String
    | NachrichtAendern String
    | MengeAendern Int String
    | NeueBestellungVersenden
    | NeueBestellungVersandt (Result String (List Bestellung))


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
        Bestellung 0 empfaenger nachricht posten


bestellungenAuswerten : Model -> List Bestellung -> Model
bestellungenAuswerten model bestellungen =
    let
        letzteBestellung =
            List.head bestellungen
    in
        { model
            | bestellungen = bestellungen
            , letzteBestellung = letzteBestellung
            , neueBestellung = neueBestellungAnlegen model.pflegemittel letzteBestellung
        }


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

        Err _ ->
            { model | ungueltigeMengen = Dict.insert pflegemittelId menge model.ungueltigeMengen }


ohneLeerePosten : Bestellung -> Bestellung
ohneLeerePosten bestellung =
    let
        nichtLeer =
            \posten ->
                posten.menge > 0
    in
        { bestellung | posten = List.filter nichtLeer bestellung.posten }


init : ( Model, Cmd Msg )
init =
    ( Model [] [] Nothing (neueBestellungAnlegen [] Nothing) Dict.empty False "" ""
    , pflegemittelLaden PflegemittelLaden
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PflegemittelLaden (Ok pflegemittel) ->
            ( { model | pflegemittel = List.filter .wirdVerwendet pflegemittel }, bestellungenLaden BestellungenLaden )

        PflegemittelLaden (Err err) ->
            ( { model | letzterFehler = err }, Cmd.none )

        BestellungenLaden (Ok bestellungen) ->
            ( bestellungenAuswerten model bestellungen, Cmd.none )

        BestellungenLaden (Err err) ->
            ( { model | letzterFehler = err }, Cmd.none )

        EmpfaengerAendern empfaenger ->
            ( neueBestellungAendern model <| \val -> { val | empfaenger = empfaenger }, Cmd.none )

        NachrichtAendern nachricht ->
            ( neueBestellungAendern model <| \val -> { val | nachricht = nachricht }, Cmd.none )

        MengeAendern pflegemittelId menge ->
            ( neueBestellungMengeAendern model pflegemittelId menge, Cmd.none )

        NeueBestellungVersenden ->
            ( { model | wirdVersendet = True, meldung = "Wird versandt...", letzterFehler = "" }, neueBestellungSpeichern NeueBestellungVersandt <| ohneLeerePosten model.neueBestellung )

        NeueBestellungVersandt (Ok bestellungen) ->
            let
                newModel =
                    bestellungenAuswerten model bestellungen
            in
                ( { newModel | wirdVersendet = False, meldung = "Wurde versandt." }, Cmd.none )

        NeueBestellungVersandt (Err err) ->
            ( { model | wirdVersendet = False, letzterFehler = err }, Cmd.none )


view : Model -> Html Msg
view model =
    let
        absendenEnabled =
            not model.wirdVersendet && Dict.isEmpty model.ungueltigeMengen

        inhalt =
            [ neueBestellungTabelle model.pflegemittel model.bestellungen model.letzteBestellung model.neueBestellung model.ungueltigeMengen
            , p [] [ emailfeld "Empfänger" model.neueBestellung.empfaenger EmpfaengerAendern ]
            , p [] [ textbereich "Nachricht" model.neueBestellung.nachricht NachrichtAendern ]
            ]
    in
        formular NeueBestellungVersenden "Versenden" absendenEnabled inhalt model.meldung model.letzterFehler


neueBestellungTabelle : List Pflegemittel -> List Bestellung -> Maybe Bestellung -> Bestellung -> Dict Int String -> Html Msg
neueBestellungTabelle pflegemittel bestellungen letzteBestellung neueBestellung ungueltigeMengen =
    let
        ueberschriften =
            [ "Bezeichnung", "Einheit", "geplanter Verbrauch", "vorhandene Menge", "mittlere Menge", "letzte Menge", "Menge" ]

        zeile =
            \pflegemittel -> neueBestellungZeile pflegemittel bestellungen letzteBestellung neueBestellung ungueltigeMengen
    in
        tabelle ueberschriften <| List.map zeile pflegemittel


neueBestellungZeile : Pflegemittel -> List Bestellung -> Maybe Bestellung -> Bestellung -> Dict Int String -> List (Html Msg)
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
        [ text pflegemittel.bezeichnung
        , text pflegemittel.einheit
        , text <| toString pflegemittel.geplanterVerbrauch
        , text <| toString pflegemittel.vorhandeneMenge
        , text mittlere
        , text letzte
        , zahlenfeld "0" neue <| MengeAendern pflegemittel.id
        ]
