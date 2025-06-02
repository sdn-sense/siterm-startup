#!/bin/bash

ARCH=`arch`
if [ $ARCH = "x86_64" ]; then
  docker build --no-cache -t sitermfebasebuild --build-arg ARCH=amd64 .
fi

