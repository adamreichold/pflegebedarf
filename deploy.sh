#!/bin/bash -xe

./ui/build.sh

LIB_DIR=/usr/lib/pflegebedarf
WWW_DIR=/www/pflegebedarf

ssh $TARGET "mkdir -p $LIB_DIR $WWW_DIR"

scp -r lib/. $TARGET:$LIB_DIR
scp -r api/. $TARGET:$WWW_DIR/api
scp -r ui/html/. $TARGET:$WWW_DIR/ui
