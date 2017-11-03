#!/bin/bash -xe

cd "$(dirname "${BASH_SOURCE[0]}")"

TEMP_FILE=$(mktemp)

for FILE in html/*.html
do
    node node_modules/html-minifier/cli.js --minify-js --output $TEMP_FILE $FILE
    cat $TEMP_FILE > $FILE
done
