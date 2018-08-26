module Ui exposing (ankreuzfeld, auswahlfeld, emailfeld, fehlermeldung, formular, optionsfeld, p, tabelle, textbereich, textfeld, versteckt, zahlenfeld, zentrierteElemente)

import Html exposing (Attribute, Html, form, option, select, tbody, text, textarea, tr)
import Html.Attributes exposing (attribute, checked, disabled, placeholder, property, rows, style, type_, value)
import Html.Events exposing (onCheck, onInput, onSubmit)
import Json.Encode


innerHtml : String -> Attribute msg
innerHtml html =
    property "innerHTML" (Json.Encode.string html)


quarterWidth =
    style "width" "25%"


fullWidth =
    style "width" "100%"


largePadding =
    style "padding" "1em"


largeWidth =
    style "width" "3em"


largeHeight =
    style "height" "3em"


centeredText =
    style "text-align" "center"


boldRedText =
    [ style "font-weight" "bold", style "color" "red" ]


stickyTop =
    [ style "position" "sticky", style "top" "0" ]


lightGrayBackground =
    style "background-color" "lightgray"


darkGrayBackground =
    style "background-color" "darkgray"


displayNone =
    style "display" "none"


displayFlex =
    style "display" "flex"


alignItemsCenter =
    style "align-items" "center"


versteckt =
    displayNone


zentrierteElemente =
    [ displayFlex, alignItemsCenter ]


p attributes children =
    Html.p (largePadding :: attributes) children


table attributes children =
    Html.table (fullWidth :: attributes) children


thead attributes children =
    Html.thead (stickyTop ++ attributes) children


th attributes children =
    Html.th (largePadding :: darkGrayBackground :: attributes) children


td attributes children =
    Html.td (largePadding :: centeredText :: attributes) children


input attributes children =
    Html.input (largeHeight :: attributes) children


fehlermeldung : String -> Html msg
fehlermeldung fehler =
    p (innerHtml fehler :: boldRedText) []


formular : msg -> String -> Bool -> List (Html msg) -> String -> String -> Html msg
formular absendenMsg absendenValue absendenEnabled inhalt meldung letzterFehler =
    form
        [ onSubmit absendenMsg, largePadding, lightGrayBackground ]
    <|
        inhalt
            ++ [ p [] [ input [ type_ "submit", value absendenValue, disabled <| not <| absendenEnabled, quarterWidth ] [] ]
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
    input [ type_ "text", value value_, onInput onInput_, fullWidth ] []


textbereich : String -> String -> (String -> msg) -> Html msg
textbereich placeholder_ value_ onInput_ =
    textarea [ placeholder placeholder_, value value_, onInput onInput_, rows 20, fullWidth ] []


zahlenfeld : String -> String -> (String -> msg) -> Html msg
zahlenfeld min_ value_ onInput_ =
    input [ type_ "number", Html.Attributes.min min_, value value_, onInput onInput_, fullWidth ] []


emailfeld : String -> String -> (String -> msg) -> Html msg
emailfeld placeholder_ value_ onInput_ =
    input [ type_ "email", placeholder placeholder_, value value_, onInput onInput_, fullWidth ] []


ankreuzfeld : Bool -> (Bool -> msg) -> Html msg
ankreuzfeld checked_ onCheck_ =
    input [ type_ "checkbox", checked checked_, onCheck onCheck_, largeWidth ] []


auswahlfeld : List ( String, String ) -> (String -> msg) -> Html msg
auswahlfeld options onInput_ =
    let
        optionItem =
            \( value_, text_ ) -> option [ attribute "value" value_ ] [ text text_ ]
    in
    select [ onInput onInput_, quarterWidth, largeHeight ] <| List.map optionItem options


optionsfeld : String -> Bool -> (Bool -> msg) -> List (Html msg)
optionsfeld text_ checked_ onCheck_ =
    [ input [ type_ "checkbox", checked checked_, onCheck onCheck_, largeWidth ] [], text text_ ]
