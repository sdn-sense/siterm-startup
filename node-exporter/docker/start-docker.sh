#!/bin/bash

# Do not use json-file logging if it is podman
ISPODMAN=`docker --version | grep podman | wc -l`
LOGOPTIONS=""
if [ $ISPODMAN -eq 0 ]; then
  LOGOPTIONS="--log-driver=json-file --log-opt max-size=10m --log-opt max-file=10"
fi
PORT=9100
while getopts "p:" opt; do
  case $opt in
    p)
      PORT=$OPTARG
      ;;
    *)
      echo "Usage: $0 [-p <PORT>]"
      exit 1
      ;;
  esac
done


docker run -d \
  --net="host" \
  --pid="host" \
  -v "/proc:/host/proc:ro" \
  -v "/sys:/host/sys:ro" \
  -v "/:/host:ro,rslave" \
  --restart always \
  $LOGOPTIONS \
  prom/node-exporter \
  --path.rootfs=/host \
  --collector.netdev.address-info \
  --web.listen-address=":$PORT"
