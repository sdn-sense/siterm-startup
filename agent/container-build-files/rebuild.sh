#!/bin/bash

dockerid=`docker ps | grep siteagent | awk '{print $1}'`
docker stop $dockerid
docker rm $dockerid

docker build --no-cache -t siteagent .
