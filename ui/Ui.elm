module Ui exposing (p, formular, tabelle, textField, textArea, numberField, emailField, checkBox)

import Html exposing (Html, Attribute, form, tr, th, text, input, textarea)
import Html.Attributes exposing (property, type_, placeholder, value, checked, disabled, rows, style)
import Html.Events exposing (onSubmit, onInput, onCheck)
import Json.Encode


innerHtml : String -> Attribute msg
innerHtml html =
    property "innerHTML" (Json.Encode.string html)


fullWidth =
    [ ( "width", "100%" ) ]


largePadding =
    [ ( "padding", "1em" ) ]


centeredText =
    [ ( "text-align", "center" ) ]


boldRedText =
    [ ( "font-weight", "bold" ), ( "color", "red" ) ]


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


td attributes children =
    let
        style_ =
            style <| largePadding ++ centeredText
    in
        Html.td (style_ :: attributes) children


formular : msg -> String -> Bool -> List (Html msg) -> String -> Html msg
formular absendenMsg absendenValue absendenEnabled inhalt letzterFehler =
    form
        [ onSubmit absendenMsg, style largePadding ]
    <|
        inhalt
            ++ [ p [] [ input [ type_ "submit", value absendenValue, disabled <| not <| absendenEnabled ] [] ]
               , p [ style boldRedText, innerHtml letzterFehler ] []
               ]


tabelleKopfzeile : List String -> Html msg
tabelleKopfzeile ueberschriften =
    tr [] <| List.map (\ueberschrift -> th [] [ text ueberschrift ]) ueberschriften


tabelleZeile : List (Html msg) -> Html msg
tabelleZeile spalten =
    tr [] <| List.map (\spalte -> td [] [ spalte ]) spalten


tabelle : List String -> List (List (Html msg)) -> Html msg
tabelle ueberschriften zeilen =
    table [] <| (tabelleKopfzeile ueberschriften) :: (List.map tabelleZeile zeilen)


textField : String -> (String -> msg) -> Html msg
textField value_ onInput_ =
    input [ type_ "text", value value_, onInput onInput_, style fullWidth ] []


textArea : String -> String -> (String -> msg) -> Html msg
textArea placeholder_ value_ onInput_ =
    textarea [ placeholder placeholder_, value value_, onInput onInput_, rows 20, style fullWidth ] []


numberField : String -> String -> (String -> msg) -> Html msg
numberField min_ value_ onInput_ =
    input [ type_ "number", Html.Attributes.min min_, value value_, onInput onInput_, style fullWidth ] []


emailField : String -> String -> (String -> msg) -> Html msg
emailField placeholder_ value_ onInput_ =
    input [ type_ "email", placeholder placeholder_, value value_, onInput onInput_, style fullWidth ] []


checkBox : Bool -> (Bool -> msg) -> Html msg
checkBox checked_ onCheck_ =
    input [ type_ "checkbox", checked checked_, onCheck onCheck_ ] []
