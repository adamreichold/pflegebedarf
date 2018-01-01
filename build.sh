#!/bin/bash -xe

pushd api; cargo build; popd

./ui/build.sh

sudo docker build -t pflegebedarf .
