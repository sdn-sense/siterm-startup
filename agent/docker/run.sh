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
    i) SITERMIMGVERSION=${OPTARG};;
    *) echo "Usage: `basename $0` [-i imagetag]"
       echo "  -i imagetag (MANDATORY)"
       echo "     specify image tag, e.g. latest, dev, v1.3.0... For production deplyoment use latest, unless instructed otherwise by SENSE team"
       exit 1;;
  esac
done

DOCKVOL="siterm-agent"
DOCKVOLLOG="siterm-agent-logs"

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

# Check SELinux. If enabled, choose correct mount option and enable svirt_sandbox_file_t
MOUNT_OPT=":ro"
if command -v selinuxenabled >/dev/null 2>&1; then
  if selinuxenabled; then
    MOUNT_OPT=":ro,z"
  else
    MOUNT_OPT=":ro"
  fi
fi

# Check if modules are loaded:
MODULES=(sch_htb sch_sfq ifb sch_ingress cls_u32 act_mirred)

echo "[INFO] Checking if required kernel modules are loaded..."
for mod in "${MODULES[@]}"; do
    if lsmod | grep -q "^${mod}"; then
        echo "Module $mod already loaded"
    else
        if modprobe "$mod"; then
            echo "Loaded $mod"
        else
            echo -e "${RED}Failed to load $mod${NC}"
        fi
    fi
done

echo "[INFO] All modules processed."

# If lldpd daemon running on the host, we pass socket to container.
# SiteRM Agent will try to get lldpd information (lldpcli show neighbors)
# So that it can know automatically how things are connected.
# lldp must be enabled at the site level (host and network)
LLDPMOUNT=""
if `test -S /run/lldpd/lldpd.socket`; then
  LLDPMOUNT="-v /run/lldpd/lldpd.socket:/run/lldpd/lldpd.socket${MOUNT_OPT}"
fi

# If routing table file exists, we pass it to container.
RTTABLE=""
if `test -f /etc/iproute2/rt_tables`; then
  RTTABLE="-v /etc/iproute2/rt_tables:/etc/iproute2/rt_tables${MOUNT_OPT}"
else
  echo -e "${RED}WARNING: /etc/iproute2/rt_tables file does not exist."
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

FILES=(
  "$(realpath $(pwd)/../conf/etc/siterm.yaml)"
  "$(realpath $(pwd)/../conf/etc/grid-security/hostcert.pem)"
  "$(realpath $(pwd)/../conf/etc/grid-security/hostkey.pem)"
  "/etc/iproute2/rt_tables"
  "/run/lldpd/lldpd.socket"
)

if command -v selinuxenabled >/dev/null 2>&1; then
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
fi
# Identify OS version and set SITERMOSVERSION variable
# Use correct image based on OS version
# Default to el10 if not detected or unsupported version
SITERMOSVERSION="el10"
if [ -f /etc/os-release ]; then
  . /etc/os-release
  if [[ "$ID_LIKE" == *"rhel"* || "$ID" == *"almalinux"* || "$ID" == *"rocky"* ]]; then
    ELVER=$(echo "$VERSION_ID" | cut -d '.' -f1)
    if [[ "$ELVER" =~ ^(8|9|10)$ ]]; then
      SITERMOSVERSION="el${ELVER}"
    else
      echo -e "${RED}Unsupported EL version detected: $VERSION_ID. Defaulting to el10 image...${NC}"
    fi
  else
    echo "Non-EL system detected: $ID. Proceeding with el10 image."
  fi
else
  echo -e "${RED}/etc/os-release not found. Cannot detect OS. Defaulting to el10 image...${NC}"
fi

echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
echo "Starting SiteRM Agent container with image tag: ${SITERMIMGVERSION} and OS version: ${SITERMOSVERSION}"
docker run \
  -dit --name siterm-agent \
  -v $(pwd)/../conf/etc/siterm.yaml:/etc/siterm.yaml$MOUNT_OPT \
  -v $(pwd)/../conf/etc/grid-security/hostcert.pem:/etc/grid-security/hostcert.pem$MOUNT_OPT \
  -v $(pwd)/../conf/etc/grid-security/hostkey.pem:/etc/grid-security/hostkey.pem$MOUNT_OPT \
  -v ${DOCKVOL}:/opt/siterm/config/ \
  -v ${DOCKVOLLOG}:/var/log/ \
  ${RTTABLE} ${LLDPMOUNT} \
  --restart always \
  --cap-add=NET_ADMIN \
  --net=host \
  ${LOGOPTIONS} quay.io/sdnsense/siterm-agent:${SITERMIMGVERSION}-${SITERMOSVERSION}

echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
echo "Starting SiteRM Debugger container with image tag: ${VERSION} and OS version: el10"

docker run \
  -dit --name siterm-debugger \
  -v $(pwd)/../conf/etc/siterm.yaml:/etc/siterm.yaml$MOUNT_OPT \
  -v $(pwd)/../conf/etc/grid-security/hostcert.pem:/etc/grid-security/hostcert.pem$MOUNT_OPT \
  -v $(pwd)/../conf/etc/grid-security/hostkey.pem:/etc/grid-security/hostkey.pem$MOUNT_OPT \
  -v ${DOCKVOL}:/opt/siterm/config/ \
  -v ${DOCKVOLLOG}:/var/log/ \
  --restart always \
  --net=host \
  $LOGOPTIONS quay.io/sdnsense/siterm-debugger:${VERSION}-el10

  echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
  echo "SiteRM Agent and Debugger should be started. Use 'docker ps' to check. Use 'docker logs -f siterm-agent' to follow agent logs."
  echo "For more details, documentation is available here: https://sdn-sense.github.io/Installation.html"
  echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"