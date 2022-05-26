#!/bin/bash

BUILD_ARCH=""

case `arch` in
  "x86_64")
    BUILD_ARCH="amd64"
    ;;
  "ppc64le")
    BUILD_ARCH="ppc64le"
    ;;
  *)
    echo -n "Architecture is not supported"; exit 1;
    ;;
esac

docker build --no-cache -t siteagent:manifest-$BUILD_ARCH --build-arg ARCH=$BUILD_ARCH/ .
