#!/bin/bash -xe

./ui/build.sh

sudo docker build -t pflegebedarf:v1 .
