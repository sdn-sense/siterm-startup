#!/bin/bash

# VERSION:
#  dev - development branch, often updated, might not be working version
#  latest - stable working version

# Check if parameters are defined. If not, print usage and exit 1.
if [ $# == 0 ]; then
    echo "Usage: `basename $0` [-i imagetag] [-n networkmode]"
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

RED='\033[0;31m'
NC='\033[0m' # No Color

certchecker () {
  local ERROR=false
  cdata=`openssl x509 -in $1 -pubkey -noout -outform pem`
  cexitcode=$?
  kdata=`openssl pkey -in $2 -pubout -outform pem`
  kexitcode=$?
  if [ $cexitcode != 0 ] || [ $kexitcode != 0 ]; then
    echo -e "${RED}ERROR: Issue with certificate files ($1 $2) SiteRM Will fail to start.${NC}"
    echo "You can test this with the following commands:"
    echo "  openssl x509 -in $1 -pubkey -noout -outform pem"
    echo "  openssl pkey -in $2 -pubout -outform pem"
    ERROR=true
  else
    csha=`echo $cdata | sha256sum`
    ksha=`echo $kdata | sha256sum`
    if [ "$csha" = "$ksha" ]; then
      echo "Public keys for cert and key match. OK"
    else
      echo -e "${RED}Public keys for cert and key do not match.${NC}"
      echo "You can test this with the following commands and output must be equal:"
      echo "  openssl x509 -in $1 -pubkey -noout -outform pem | sha256sum"
      echo "  openssl pkey -in $2 -pubout -outform pem | sha256sum"
    fi
    if openssl x509 -checkend 86400 -noout -in $1
    then
      echo -e "Certificate $1 is valid. OK"
    else
      echo -e "${RED}Certificate $1 expired or expires in 1 day. Please update certificate. SiteRM will fail to start"
      ERROR=true
    fi
  fi
  if [ "$ERROR" = true ]; then
    return 1
  fi
  return 0
}

declare -a ARRAY=("becac06c584d32f066fc3e13795aed0b8c75e93171ff357da77053976a890a07  ../conf/etc/siterm.yaml" "48120fbe195337ee5b54a2284a33e4280da9c1ddc5dfdf8a0cf0f807be4e089a  ../conf/etc/grid-security/hostcert.pem" "48120fbe195337ee5b54a2284a33e4280da9c1ddc5dfdf8a0cf0f807be4e089a  ../conf/etc/grid-security/hostkey.pem")

length=${#ARRAY[@]}

ERROR=false
for (( j=0; j<length; j++ ))
do
  echo "${ARRAY[$j]}" | sha256sum -c &> /dev/null
  if [ $? == 0 ]; then
    echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
    read -ra strarr <<< "${ARRAY[$j]}"
    echo -e "${RED}ERROR: Configuration file ${strarr[1]} was not modified. SiteRM Will fail to start.${NC}"
    echo "Please modify file and set correct values"
    echo "For more details, documentation is available here: https://sdn-sense.github.io/Installation.html"
    ERROR=true
  fi
done

echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
echo "Testing certificates ../conf/etc/httpd/certs/{cert,privkey}.pem"
certchecker ../conf/etc/grid-security/hostcert.pem ../conf/etc/grid-security/hostkey.pem
if [ $? != 0 ]; then
  ERROR=true
fi

if [ "$ERROR" = true ]; then
    echo -e "${RED}------------------------------------------------------------------------"
    echo -e "Due to Errors, SiteRM container will not be started. Please fix issues highlighted above and try again.${NC}"
    exit 1
fi

# Do not use json-file logging if it is podman
ISPODMAN=`docker --version | grep podman | wc -l`
LOGOPTIONS=""
if [ $ISPODMAN -eq 0 ]; then
  LOGOPTIONS="--log-driver=json-file --log-opt max-size=10m --log-opt max-file=10"
fi

# If lldpd daemon running on the host, we pass socket to container.
# SiteRM Agent will try to get lldpd information (lldpcli show neighbors)
# So that it can know automatically how things are connected.
# lldp must be enabled at the site level (host and network)
LLDPMOUNT=""
if `test -S /run/lldpd/lldpd.socket`; then
  LLDPMOUNT="-v /run/lldpd/lldpd.socket:/run/lldpd/lldpd.socket:ro"
fi

# Create docker volume for configuration storage
cmd="docker volume inspect siterm-agent &> /dev/null"
if eval "$cmd"
then
  echo "Docker volume available. Will use siterm-agent for runtime files"
else
  echo "Docker volume not available. Will create sitermfe-mysql for mysql database"
  docker volume create siterm-agent
  if [ $? != 0 ]; then
    echo -e "${RED}There was a failure creating docker volume. See error above. SiteRM will not start${NC}"
    exit 1
  fi
fi

docker run \
  -dit --name siteagent \
  -v $(pwd)/../conf/etc/siterm.yaml:/etc/siterm.yaml:ro \
  -v $(pwd)/../conf/etc/grid-security/hostcert.pem:/etc/grid-security/hostcert.pem:ro \
  -v $(pwd)/../conf/etc/grid-security/hostkey.pem:/etc/grid-security/hostkey.pem:ro \
  -v siterm-agent:/opt/siterm/config/ \
  -v /etc/iproute2/rt_tables:/etc/iproute2/rt_tables:ro $LLDPMOUNT \
  --restart always \
  --privileged \
  --cap-add=NET_ADMIN \
  --net=host \
  $LOGOPTIONS docker.io/sdnsense/site-agent-sense:$VERSION
# For development, add -v /home/jbalcas/siterm/:/opt/siterm/sitermcode/siterm/ \
