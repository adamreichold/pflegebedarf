#!/bin/bash -xe

cd "$(dirname "${BASH_SOURCE[0]}")"

node_modules/elm-format/bin/elm-format --yes *.elm
