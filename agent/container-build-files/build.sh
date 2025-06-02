#!/bin/bash
RELEASE=dev
if [ $# -eq 1 ]
  then
    echo "Argument specified. Will use $1 to tag docker image"
    RELEASE=$1
fi

ARCH=`arch`
if [ $ARCH = "x86_64" ]; then
  docker build --no-cache -t siterm-agent --build-arg RELEASE=$RELEASE .
fi
