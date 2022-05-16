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

# Docker MultiArch build is experimental and we faced
# few issues with building ppc64le on x86_64 machine (gcc, mariadb issue)
# So onyl for ppc64le - we have separate build which is done on ppc64le machine
docker login
dockerimageid=`docker images | grep sitefe | grep latest | awk '{print $3}'`
ARCH=`arch`
if [ $ARCH = "x86_64" ]; then
  docker tag $dockerimageid sdnsense/site-rm-sense:$TAG
  docker push sdnsense/site-rm-sense:$TAG
elif [ $ARCH = "ppc64le" ]; then
  docker tag $dockerimageid sdnsense/site-rm-sense:$TAG-$ARCH
  docker push sdnsense/site-rm-sense:$TAG-$ARCH
fi

