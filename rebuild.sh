#!/bin/bash

# TAGS:
#  dev - development branch, often updated, might not be working version
#  latest - stable working version

TAG=dev
if [ $# -eq 1 ]
  then
    echo "Argument specified. Will use $1 to tag docker image"
    TAG=$1
fi

# REBUILD FE
cd fe/container-build-files/
sh rebuild.sh
sh docker-hub-upload.sh $TAG
cd ../../

# REBUILD Agent
cd agent/container-build-files/
sh rebuild.sh
sh docker-hub-upload.sh $TAG
