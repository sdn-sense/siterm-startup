#!/bin/bash
# Check if parameters are defined. If not, print usage and exit 1.
if [ $# == 0 ]; then
    echo "Usage: `basename $0` [-i imagetag] [-n networkmode]"
    echo "  -i imagetag (OPTIONAL). Default latest"
    echo "     specify image tag, e.g. latest, dev, v1.3.0... For production deplyoment use latest, unless instructed otherwise by SENSE team"
    echo "  -n networkmode (OPTIONAL). Default port mode"
    echo "     specify network mode. One of: host,port."
    echo "     host means it will use --net host for docker startup. Please make sure to open port 80, 443 in firewall. Use this option only if any of your hosts, network devices are IPv6 only (no IPv4 address)."
    echo "     port means it will use -p 8080:80 -p 8443:443 in docker startup. Docker will open port on system firewall. Default parameter."
    echo "  -p Overwrite default ports for docker. Default is 8080:80 and 8443:443. Specify in quotes, like -p \"9443:1443 8443:443\""
    echo "  -u (Optional) Unique volume for docker mysql database (any string)/docker container name. If specified, will use it for docker volume creation and container name"
    exit 1
fi

# Set defaults
RED='\033[0;31m'
NC='\033[0m' # No Color
DOCKERNET=""
NETMODE="port"
DOCKVOL="siterm-mysql"
DOCKVOLLOG="sitermfe-log"
DOCKERNAME="site-fe-sense"
ENV_FILE="$(pwd)/../conf/environment"
VERSION="latest"

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
      echo -e "${RED}Certificate $1 expired or expires in 1 day. Please update certificate. SiteRM will fail to start${NC}"
      ERROR=true
    fi
  fi
  if [ "$ERROR" = true ]; then
    return 1
  fi
  return 0
}

while getopts i:n:l:p:u: flag
do
  echo "Processing flag: ${flag} with argument: ${OPTARG}"
  case "${flag}" in
    i) VERSION=${OPTARG};;
    n) NETMODE=${OPTARG}
       if [ "x$NETMODE" != "xhost" ] && [ "x$NETMODE" != "xport" ]; then
         echo "Parameter -n $NETMODE is not one of: host,port."
         exit 1
       elif [ "x$NETMODE" == "xhost" ]; then
         DOCKERNET="--net host"
       fi;;
    p) PORTS=${OPTARG}
       if [ "x$NETMODE" == "xhost" ] && [ -n "$PORTS" ]; then
         echo "Mistmatch. Cant use -p with -n host"
         exit 1
       fi
       DOCKERNET=$PORTS;;
    u) DOCKVOL="siterm-mysql-${OPTARG}"
       DOCKVOLLOG="sitermfe-log-${OPTARG}"
       DOCKERNAME="site-fe-sense-${OPTARG}";;
  esac
done

# Save cmd line arguments to file
CMD_FILE=".last_run_cmd"
CURRENT_CMD="./run.sh $@"
if [[ -f "$CMD_FILE" ]]; then
    SAVED_CMD=$(<"$CMD_FILE")
    if [[ "$CURRENT_CMD" != "$SAVED_CMD" ]]; then
        echo "Mismatch in run command:"
        echo "  Saved:   $SAVED_CMD"
        echo "  Current: $CURRENT_CMD"
        echo "To override, delete the file: $CMD_FILE"
        exit 1
    fi
fi
echo "$CURRENT_CMD" > "$CMD_FILE"

# Set docker network correct params
if [ "x$NETMODE" = "xport" ]; then
  if [ -z "$DOCKERNET" ]; then
    DOCKERNET="9443:1443 8443:443"
  fi
  for port in $DOCKERNET; do
    DOCKERNET_PARSED+=" -p $port"
  done
else
  if [ -z "$DOCKERNET" ]; then
    DOCKERNET="--net host"
  fi
  DOCKERNET_PARSED=$DOCKERNET
fi

# Do not use json-file logging if it is podman
ISPODMAN=`docker --version | grep podman | wc -l`
LOGOPTIONS=""
if [ $ISPODMAN -eq 0 ]; then
  LOGOPTIONS="--log-driver=json-file --log-opt max-size=10m --log-opt max-file=10"
fi

declare -a ARRAY=("becac06c584d32f066fc3e13795aed0b8c75e93171ff357da77053976a890a07  ../conf/etc/siterm.yaml" "fae5fe7ea1fb2366d90cdd851fe1692260f4a74bca16afea13e9999feaa34874  ../conf/etc/ansible-conf.yaml" "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  ../conf/etc/httpd/certs/cert.pem" "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  ../conf/etc/httpd/certs/privkey.pem" "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  ../conf/etc/grid-security/hostcert.pem" "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  ../conf/etc/grid-security/hostkey.pem" "bfaaddc288a2d2e8299660439b16ca3b1abdb924b417206c24ebab6ad7186a71  ../conf/environment")

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
certchecker ../conf/etc/httpd/certs/cert.pem ../conf/etc/httpd/certs/privkey.pem
if [ $? != 0 ]; then
  ERROR=true
fi

echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
echo "Testing certificates ../conf/etc/grid-security/{hostcert,hostkey}.pem"
certchecker ../conf/etc/grid-security/hostcert.pem ../conf/etc/grid-security/hostkey.pem
if [ $? != 0 ]; then
  ERROR=true
fi

if [ "$ERROR" = true ]; then
    echo -e "${RED}------------------------------------------------------------------------"
    echo -e "Due to Errors, SiteRM container will not be started. Please fix issues highlighted above and try again.${NC}"
    exit 1
fi

# Create docker volume for configuration storage
cmd="docker volume inspect ${DOCKVOL} &> /dev/null"
if eval "$cmd"
then
  echo "Docker volume available for FE Configuration. Will use ${DOCKVOL} for mysql database"
else
  echo "Docker volume not available for FE Configuration. Will create ${DOCKVOL} for mysql database"
  docker volume create ${DOCKVOL}
  if [ $? != 0 ]; then
    echo -e "${RED}There was a failure creating docker volume. See error above. SiteRM will not start${NC}"
    exit 1
  fi
fi

# Create docker volume for log storage
cmd="docker volume inspect ${DOCKVOLLOG} &> /dev/null"
if eval "$cmd"
then
  echo "Docker volume available for logs. Will use ${DOCKVOLLOG} for logs"
else
  echo "Docker volume not available for logs. Will create ${DOCKVOLLOG} for logs"
  docker volume create ${DOCKVOLLOG}
  if [ $? != 0 ]; then
    echo -e "${RED}There was a failure creating docker volume. See error above. SiteRM will not start${NC}"
    exit 1
  fi
fi


# Precreate mysql and ssh-keys empty directories if do not exist.
# That might be an issue of non existing dirs on podman installation
if [[ ! -d "$(pwd)/../conf/opt/siterm/config/ssh-keys" ]]; then
  mkdir -p $(pwd)/../conf/opt/siterm/config/ssh-keys
fi

docker run \
       -dit --name ${DOCKERNAME} \
       -v $(pwd)/../conf/etc/siterm.yaml:/etc/siterm.yaml \
       -v $(pwd)/../conf/etc/ansible-conf.yaml:/etc/ansible-conf.yaml \
       -v $(pwd)/../conf/etc/httpd/certs/cert.pem:/etc/httpd/certs/cert.pem \
       -v $(pwd)/../conf/etc/httpd/certs/privkey.pem:/etc/httpd/certs/privkey.pem \
       -v $(pwd)/../conf/etc/grid-security/hostcert.pem:/etc/grid-security/hostcert.pem \
       -v $(pwd)/../conf/etc/grid-security/hostkey.pem:/etc/grid-security/hostkey.pem \
       -v ${DOCKVOL}:/opt/siterm/config/mysql/ \
       -v ${DOCKVOLLOG}:/var/log/ \
       -v $(pwd)/../conf/opt/siterm/config/ssh-keys:/opt/siterm/config/ssh-keys \
       $DOCKERNET_PARSED \
       --restart always \
       --env-file $ENV_FILE \
       $LOGOPTIONS docker.io/sdnsense/site-rm-sense:$VERSION
