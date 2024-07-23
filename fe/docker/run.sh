#!/bin/bash
# VERSION:
#  dev - development branch, often updated, might not be working version
#  latest - stable working version

# Check if parameters are defined. If not, print usage and exit 1.
if [ $# == 0 ]; then
    echo "Usage: `basename $0` [-i imagetag] [-n networkmode]"
    echo "  -i imagetag (MANDATORY)"
    echo "     specify image tag, e.g. latest, dev, v1.3.0... For production deplyoment use latest, unless instructed otherwise by SENSE team"
    echo "  -n networkmode (OPTIONAL). Default port mode"
    echo "     specify network mode. One of: host,port."
    echo "     host means it will use --net host for docker startup. Please make sure to open port 80, 443 in firewall. Use this option only if any of your hosts, network devices are IPv6 only (no IPv4 address)."
    echo "     port means it will use -p 8080:80 -p 8443:443 in docker startup. Docker will open port on system firewall. Default parameter"
    echo "  -l Instruct httpd to listen on a specific port. Default inside docker is 443. (Mainly for docker + nftables mode (no iptables) - where it is mandatory to use -n host)"
    exit 1
fi

# Set defaults
RED='\033[0;31m'
NC='\033[0m' # No Color
LISTEN_HTTPS=443
DOCKERNET="-p 8080:80 -p 8443:443"
ENV_FILE="$(pwd)/../conf/environment"

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

update_listen() {
    if grep -q '^LISTEN_HTTPS=' "$ENV_FILE"; then
        # Update the existing value
        sed -i "s/^LISTEN_HTTPS=.*/LISTEN_HTTPS=$LISTEN_HTTPS/" "$ENV_FILE"
        echo "LISTEN_HTTPS updated to $LISTEN_HTTPS in $ENV_FILE."
    else
        # Add the new value
        echo "LISTEN_HTTPS=$LISTEN_HTTPS" >> "$ENV_FILE"
        echo "LISTEN_HTTPS added with value $LISTEN_HTTPS in $ENV_FILE."
    fi
}

while getopts i:n: flag
do
  case "${flag}" in
    i) VERSION=${OPTARG};;
    l) LISTEN_HTTPS=${OPTARG};;
    n) NETMODE=${OPTARG}
       if [ "x$NETMODE" != "xhost" ] && [ "x$NETMODE" != "xport" ]; then
         echo "Parameter -n $NETMODE is not one of: host,port."
         exit 1
       elif [ "x$NETMODE" == "xhost" ]; then
         DOCKERNET="--net host"
       else
         DOCKERNET="-p 8080:80 -p 8443:443"
       fi;;
  esac
done


# Check if the file exists
if [[ -f "$ENV_FILE" ]]; then
    # Get the current value of LISTEN_HTTPS if defined
    CURRENT_LISTEN=$(grep '^LISTEN_HTTPS=' "$ENV_FILE" | cut -d '=' -f 2)
 
    if [[ "$CURRENT_LISTEN" != "$LISTEN_HTTPS" ]]; then
        update_listen
    else
        echo "LISTEN_HTTPS is already set to the desired value in $ENV_FILE."
    fi
else
    # If the file doesn't exist, create it and add LISTEN_HTTPS
    echo "LISTEN_HTTPS=$LISTEN_HTTPS" > "$ENV_FILE"
    echo "Environment file $ENV_FILE created and LISTEN_HTTPS set to $LISTEN_HTTPS."
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
cmd="docker volume inspect siterm-mysql &> /dev/null"
if eval "$cmd"
then
  echo "Docker volume available. Will use sitermfe-mysql for mysql database"
else
  echo "Docker volume not available. Will create sitermfe-mysql for mysql database"
  docker volume create siterm-mysql
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
       -dit --name site-fe-sense \
       -v $(pwd)/../conf/etc/siterm.yaml:/etc/siterm.yaml \
       -v $(pwd)/../conf/etc/ansible-conf.yaml:/etc/ansible-conf.yaml \
       -v $(pwd)/../conf/etc/httpd/certs/cert.pem:/etc/httpd/certs/cert.pem \
       -v $(pwd)/../conf/etc/httpd/certs/privkey.pem:/etc/httpd/certs/privkey.pem \
       -v $(pwd)/../conf/etc/grid-security/hostcert.pem:/etc/grid-security/hostcert.pem \
       -v $(pwd)/../conf/etc/grid-security/hostkey.pem:/etc/grid-security/hostkey.pem \
       -v sitermfe-mysql:/opt/siterm/config/mysql/ \
       -v $(pwd)/../conf/opt/siterm/config/ssh-keys:/opt/siterm/config/ssh-keys \
       $DOCKERNET \
       --restart always \
       --env-file $ENV_FILE \
       $LOGOPTIONS docker.io/sdnsense/site-rm-sense:$VERSION

# For development, add -v /home/jbalcas/siterm/:/opt/siterm/sitermcode/siterm/ \
