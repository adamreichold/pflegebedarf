module Ui exposing (versteckt, zentrierteElemente, p, fehlermeldung, formular, tabelle, textfeld, textbereich, zahlenfeld, emailfeld, ankreuzfeld, auswahlfeld, optionsfeld)

import Html exposing (Html, Attribute, form, tbody, tr, text, textarea, select, option)
import Html.Attributes exposing (property, attribute, type_, placeholder, value, checked, disabled, rows, style)
import Html.Events exposing (onSubmit, onInput, onCheck)
import Json.Encode


innerHtml : String -> Attribute msg
innerHtml html =
    property "innerHTML" (Json.Encode.string html)


quarterWidth =
    [ ( "width", "25%" ) ]


fullWidth =
    [ ( "width", "100%" ) ]


largePadding =
    [ ( "padding", "1em" ) ]


largeWidth =
    [ ( "width", "3em" ) ]


largeHeight =
    [ ( "height", "3em" ) ]


centeredText =
    [ ( "text-align", "center" ) ]


boldRedText =
    [ ( "font-weight", "bold" ), ( "color", "red" ) ]


stickyTop =
    [ ( "position", "sticky" ), ( "top", "0" ) ]


lightGrayBackground =
    [ ( "background-color", "lightgray" ) ]


darkGrayBackground =
    [ ( "background-color", "darkgray" ) ]


displayNone =
    [ ( "display", "none" ) ]


displayFlex =
    [ ( "display", "flex" ) ]


alignItemsCenter =
    [ ( "align-items", "center" ) ]


versteckt =
    style displayNone


zentrierteElemente =
    style <| displayFlex ++ alignItemsCenter


p attributes children =
    let
        style_ =
            style largePadding
    in
        Html.p (style_ :: attributes) children


table attributes children =
    let
        style_ =
            style fullWidth
    in
        Html.table (style_ :: attributes) children


thead attributes children =
    let
        style_ =
            style stickyTop
    in
        Html.thead (style_ :: attributes) children


th attributes children =
    let
        style_ =
            style <| largePadding ++ darkGrayBackground
    in
        Html.th (style_ :: attributes) children


td attributes children =
    let
        style_ =
            style <| largePadding ++ centeredText
    in
        Html.td (style_ :: attributes) children


input attributes children =
    let
        style_ =
            style <| largeHeight
    in
        Html.input (style_ :: attributes) children


fehlermeldung : String -> Html msg
fehlermeldung fehler =
    p [ style boldRedText, innerHtml fehler ] []


formular : msg -> String -> Bool -> List (Html msg) -> String -> String -> Html msg
formular absendenMsg absendenValue absendenEnabled inhalt meldung letzterFehler =
    form
        [ onSubmit absendenMsg, style <| largePadding ++ lightGrayBackground ]
    <|
        inhalt
            ++ [ p [] [ input [ type_ "submit", value absendenValue, disabled <| not <| absendenEnabled, style quarterWidth ] [] ]
               , p [] [ text meldung ]
               , fehlermeldung letzterFehler
               ]


tabelleKopfzeile : List String -> Html msg
tabelleKopfzeile ueberschriften =
    tr [] <| List.map (\ueberschrift -> th [] [ text ueberschrift ]) ueberschriften


tabelleZeile : ( List (Attribute msg), List (Html msg) ) -> Html msg
tabelleZeile ( attribute, spalten ) =
    tr attribute <| List.map (\spalte -> td [] [ spalte ]) spalten


tabelle : List String -> List ( List (Attribute msg), List (Html msg) ) -> Html msg
tabelle ueberschriften zeilen =
    table []
        [ thead [] [ tabelleKopfzeile ueberschriften ]
        , tbody [] <| List.map tabelleZeile zeilen
        ]


textfeld : String -> (String -> msg) -> Html msg
textfeld value_ onInput_ =
    input [ type_ "text", value value_, onInput onInput_, style fullWidth ] []


textbereich : String -> String -> (String -> msg) -> Html msg
textbereich placeholder_ value_ onInput_ =
    textarea [ placeholder placeholder_, value value_, onInput onInput_, rows 20, style fullWidth ] []


zahlenfeld : String -> String -> (String -> msg) -> Html msg
zahlenfeld min_ value_ onInput_ =
    input [ type_ "number", Html.Attributes.min min_, value value_, onInput onInput_, style fullWidth ] []


emailfeld : String -> String -> (String -> msg) -> Html msg
emailfeld placeholder_ value_ onInput_ =
    input [ type_ "email", placeholder placeholder_, value value_, onInput onInput_, style fullWidth ] []


ankreuzfeld : Bool -> (Bool -> msg) -> Html msg
ankreuzfeld checked_ onCheck_ =
    input [ type_ "checkbox", checked checked_, onCheck onCheck_, style largeWidth ] []


auswahlfeld : List ( String, String ) -> (String -> msg) -> Html msg
auswahlfeld options onInput_ =
    let
        style_ =
            style <| quarterWidth ++ largeHeight

        optionItem =
            \( value_, text_ ) -> option [ attribute "value" value_ ] [ text text_ ]
    in
        select [ onInput onInput_, style_ ] <| List.map optionItem options


optionsfeld : String -> Bool -> (Bool -> msg) -> List (Html msg)
optionsfeld text_ checked_ onCheck_ =
    [ input [ type_ "checkbox", checked checked_, onCheck onCheck_, style <| largeWidth ] [], text text_ ]
