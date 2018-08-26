#!/bin/bash -xe

cd "$(dirname "${BASH_SOURCE[0]}")"

mkdir -p html

for MODULE in Pflegemittel NeueBestellung
do
    node_modules/elm/bin/elm make ${MODULE}.elm --optimize --output=html/${MODULE}.html
done
