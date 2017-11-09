#!/bin/bash -xe

cd "$(dirname "${BASH_SOURCE[0]}")"

export PATH=node_modules/elm/binwrappers:$PATH

mkdir -p html

for MODULE in Pflegemittel NeueBestellung PflegemittelBestand
do
    elm-make ${MODULE}.elm --output=html/${MODULE}.html
done
