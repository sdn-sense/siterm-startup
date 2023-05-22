#!/bin/bash
RELEASE=dev
if [ $# -eq 1 ]
  then
    echo "Argument specified. Will use $1 to tag docker image"
    RELEASE=$1
fi

ARCH=`arch`
if [ $ARCH = "x86_64" ]; then
  docker build --no-cache -t sitefe-main --build-arg RELEASE=$RELEASE --build-arg ARCH=$ARCH .
elif [ $ARCH = "ppc64le" ]; then
  docker build --no-cache -t sitefe-main --build-arg RELEASE=$RELEASE"-"$ARCH --build-arg ARCH=$ARCH .
fi
