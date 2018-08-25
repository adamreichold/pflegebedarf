#!/bin/bash -xe

TARGET=$1

pushd api; cargo build --release --target=mips-unknown-linux-musl; popd
mips-openwrt-linux-strip ./api/target/mips-unknown-linux-musl/release/api

./ui/build.sh
./ui/minify.sh

LIB_DIR=/usr/lib/pflegebedarf
CGI_DIR=/www/cgi-bin/pflegebedarf
WWW_DIR=/www/pflegebedarf

ssh $TARGET "mkdir -p $LIB_DIR $CGI_DIR $WWW_DIR"

scp api/target/mips-unknown-linux-musl/release/api $TARGET:$CGI_DIR/
scp -r ui/html/. $TARGET:$WWW_DIR/ui
