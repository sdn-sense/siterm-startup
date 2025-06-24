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

DOCKVOL="siterm-debugger"
DOCKVOLLOG="siterm-debugger-logs"

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


# Create docker volume for configuration storage
cmd="docker volume inspect ${DOCKVOL} &> /dev/null"
if eval "$cmd"
then
  echo "Docker volume available for config. Will use ${DOCKVOL} for runtime files"
else
  echo "Docker volume not available for config. Will create ${DOCKVOL} for mysql database"
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


# Check SELinux. If enabled, choose correct mount option and enable svirt_sandbox_file_t
MOUNT_OPT=""
if selinuxenabled; then
  MOUNT_OPT=":ro,z"
else
  MOUNT_OPT=":ro"
fi

FILES=(
  "$(realpath $(pwd)/../conf/etc/siterm.yaml)"
  "$(realpath $(pwd)/../conf/etc/grid-security/hostcert.pem)"
  "$(realpath $(pwd)/../conf/etc/grid-security/hostkey.pem)"
)

if selinuxenabled; then
  # Check and fix file contexts
  for file in "${FILES[@]}"; do
    current_context=$(ls -Z "$file" | awk '{print $1}')
    if [[ "$current_context" != *svirt_sandbox_file_t* && "$current_context" != *container_file_t* ]]; then
      echo "[FIX] Relabeling $file"
      chcon -t svirt_sandbox_file_t "$file"
    else
      echo "[OK] $file already labeled $current_context"
    fi
  done
fi

docker run \
  -dit --name siterm-debugger \
  -v $(pwd)/../conf/etc/siterm.yaml:/etc/siterm.yaml$MOUNT_OPT \
  -v $(pwd)/../conf/etc/grid-security/hostcert.pem:/etc/grid-security/hostcert.pem$MOUNT_OPT \
  -v $(pwd)/../conf/etc/grid-security/hostkey.pem:/etc/grid-security/hostkey.pem$MOUNT_OPT \
  -v ${DOCKVOL}:/opt/siterm/config/ \
  -v ${DOCKVOLLOG}:/var/log/ \
  --restart always \
  --net=host \
  $LOGOPTIONS docker.io/sdnsense/siterm-debugger:$VERSION
