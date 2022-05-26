#!/bin/bash
set -x
TAG=dev
if [ $# -eq 1 ]
  then
    echo "Argument specified. Will use $1 to tag docker image"
    TAG=$1
fi

# Precheck that image is present (built recently
count=`docker images | grep sitefe | grep latest | awk '{print $3}' | wc -l`
if [ "$count" -ne "1" ]; then
  echo "Count of docker images != 1. Which docker image you want to tag?"
  echo "Here is full list of docker images locally:"
  docker images | grep -i 'sitefe\|site-rm-sense\|REPOSITORY'
  echo "Please enter IMAGE ID:"
  read dockerimageid
else
  dockerimageid=`docker images | grep sitefe | grep latest | awk '{print $3}'`
fi

docker login

# Docker MultiArch build is experimental and we faced
# few issues with building ppc64le on x86_64 machine (gcc, mariadb issue)
# So onyl for ppc64le - we have separate build which is done on ppc64le machine
ARCH=`arch`
today=`date +%Y%m%d`
if [ $ARCH = "x86_64" ]; then
  docker tag $dockerimageid sdnsense/site-rm-sense:$TAG-$today
  docker push sdnsense/site-rm-sense:$TAG-$today
  docker tag $dockerimageid sdnsense/site-rm-sense:$TAG
  docker push sdnsense/site-rm-sense:$TAG
elif [ $ARCH = "ppc64le" ]; then
  docker tag $dockerimageid sdnsense/site-rm-sense:$TAG-$ARCH-$today
  docker push sdnsense/site-rm-sense:$TAG-$ARCH-$today
  docker tag $dockerimageid sdnsense/site-rm-sense:$TAG-$ARCH
  docker push sdnsense/site-rm-sense:$TAG-$ARCH
fi

