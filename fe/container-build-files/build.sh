#!/bin/bash

ARCH=`arch`
if [ $ARCH = "x86_64" ]; then
  docker build --no-cache -t sitefe --build-arg ARCH=amd64 .
elif [ $ARCH = "ppc64le" ]; then
  docker build --no-cache -t sitefe --build-arg ARCH=ppc64le .
fi

