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

docker login
dockerimageid=`docker images | grep sitefe | grep latest | awk '{print $3}'`
docker tag $dockerimageid sdnsense/site-rm-sense:$TAG
docker push sdnsense/site-rm-sense:$TAG
