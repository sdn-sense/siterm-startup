#!/bin/bash

# VERSION:
#  dev - development branch, often updated, might not be working version
#  latest - stable working version

VERSION=latest
if [ $# -eq 1 ]
  then
    echo "Argument specified. Will use $1 version from docker hub"
    VERSION=$1
fi

docker run \
       -dit --name siteagent \
       -v $(pwd)/conf/etc/dtnrm.yaml:/etc/dtnrm.yaml \
       -v $(pwd)/conf/etc/grid-security/hostcert.pem:/etc/grid-security/hostcert.pem \
       -v $(pwd)/conf/etc/grid-security/hostkey.pem:/etc/grid-security/hostkey.pem \
       -v $(pwd)/conf/opt/config/:/opt/config/ \
       --cap-add=NET_ADMIN \
       --net=host \
       --log-driver="json-file" --log-opt max-size=10m --log-opt max-file=10 \
       sdnsense/site-agent-sense:$VERSION

# For development, add -v /home/jbalcas/siterm/:/opt/dtnrmcode/siterm/ \
