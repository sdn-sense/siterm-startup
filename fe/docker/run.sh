# VERSION:
#  dev - development branch, often updated, might not be working version
#  latest - stable working version

VERSION=latest
if [ $# -eq 1 ]
  then
    echo "Argument specified. Will use $1 version from docker hub"
    VERSION=$1
fi

# Docker MultiArch build is experimental and we faced
# few issues with building ppc64le on x86_64 machine (gcc, mariadb issue)
# So onyl for ppc64le - we have separate build which is done on ppc64le machine
ARCH=`arch`
if [ $ARCH = "ppc64le"]; then
  echo "This is $ARCH type machine and we will use image built for this type."
  VERSION=$VERSION-$ARCH
fi

docker run \
       -dit --name site-fe-sense \
       -v $(pwd)/../conf/etc/dtnrm.yaml:/etc/dtnrm.yaml \
       -v $(pwd)/../conf/etc/httpd/certs/cert.pem:/etc/httpd/certs/cert.pem \
       -v $(pwd)/../conf/etc/httpd/certs/privkey.pem:/etc/httpd/certs/privkey.pem \
       -v $(pwd)/../conf/etc/httpd/certs/fullchain.pem:/etc/httpd/certs/fullchain.pem \
       -v $(pwd)/../conf/etc/grid-security/hostcert.pem:/etc/grid-security/hostcert.pem \
       -v $(pwd)/../conf/etc/grid-security/hostkey.pem:/etc/grid-security/hostkey.pem \
       -v $(pwd)/../conf/opt/siterm/config/:/opt/siterm/config/ \
       -p 8080:80 \
       -p 8443:443 \
       --env-file $(pwd)/../conf/environment \
       --log-driver="json-file" --log-opt max-size=10m --log-opt max-file=10 \
       sdnsense/site-rm-sense:$VERSION

# For development, add -v /home/jbalcas/siterm/:/opt/siterm/dtnrmcode/siterm/ \
