#!/bin/bash

# VERSION:
#  dev - development branch, often updated, might not be working version
#  latest - stable working version

# Check if parameters are defined. If not, print usage and exit 1.
if [ $# == 0 ]; then
    echo "Usage: `basename $0` [-i imagetag]"
    echo "  -i imagetag (MANDATORY)"
    echo "     specify image tag, e.g. latest, dev, v1.3.0... For production deplyoment use latest, unless instructed otherwise by SENSE team"
    exit 1
fi

while getopts i: flag
do
  case "${flag}" in
    i) VERSION=${OPTARG};;
  esac
done

# is it podman?
podman --version > /dev/null 2>&1
if [ $? -eq 0 ]; then
  shopt -s expand_aliases
  alias docker='podman'
fi

echo "Stoping and removing existing containers and images for siterm-agent"
for id in `docker ps -a | grep sdnsense/siterm-agent | awk '{print $1}'`
do
  docker stop $id
  docker rm $id
done

for id in `docker image ls | grep sdnsense/siterm-agent | awk '{print $3}'`
do
  docker image rm $id --force
done

echo "Stoping and removing existing containers and images for siterm-debugger"
for id in `docker ps -a | grep sdnsense/siterm-debugger | awk '{print $1}'`
do
  docker stop $id
  docker rm $id
done

for id in `docker image ls | grep sdnsense/siterm-agent | awk '{print $3}'`
do
  docker image rm $id --force
done

echo "Starting new siterm-agent and debugger image with tag: $VERSION"
./run.sh -i $VERSION
