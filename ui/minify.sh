#!/bin/bash -xe

cd "$(dirname "${BASH_SOURCE[0]}")"

TEMP_FILE=$(mktemp)
MINIFY_JS='{"compress":{"pure_funcs":["F2","F3","F4","F5","F6","F7","F8","F9","A2","A3","A4","A5","A6","A7","A8","A9"],"pure_getters":true,"keep_fargs":false,"unsafe_comps":true,"unsafe":true}}'

for FILE in html/*.html
do
    node node_modules/html-minifier/cli.js --minify-js $MINIFY_JS --output $TEMP_FILE $FILE
    cat $TEMP_FILE > $FILE
done
