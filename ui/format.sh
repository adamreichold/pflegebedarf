#!/bin/bash -xe

cd "$(dirname "${BASH_SOURCE[0]}")"

export PATH=node_modules/elm-format/bin:$PATH

elm-format --yes *.elm
