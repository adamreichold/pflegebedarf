#!/bin/bash -xe

sudo docker run --rm --name pflegebedarf --publish 8080:80 pflegebedarf:v1
