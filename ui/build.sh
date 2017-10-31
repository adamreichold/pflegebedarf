#!/bin/bash -xe

cd "$(dirname "${BASH_SOURCE[0]}")"

export PATH=node_modules/elm/binwrappers:$PATH

mkdir -p html

elm-make Pflegemittel.elm --output=html/Pflegemittel.html
elm-make NeueBestellung.elm --output=html/NeueBestellung.html
