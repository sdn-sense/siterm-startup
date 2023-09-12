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
       -dit --name site-fe-sense \
       -v $(pwd)/../conf/etc/siterm.yaml:/etc/siterm.yaml \
       -v $(pwd)/../conf/etc/ansible-conf.yaml:/etc/ansible-conf.yaml \
       -v $(pwd)/../conf/etc/httpd/certs/cert.pem:/etc/httpd/certs/cert.pem \
       -v $(pwd)/../conf/etc/httpd/certs/privkey.pem:/etc/httpd/certs/privkey.pem \
       -v $(pwd)/../conf/etc/httpd/certs/fullchain.pem:/etc/httpd/certs/fullchain.pem \
       -v $(pwd)/../conf/etc/grid-security/hostcert.pem:/etc/grid-security/hostcert.pem \
       -v $(pwd)/../conf/etc/grid-security/hostkey.pem:/etc/grid-security/hostkey.pem \
       -v $(pwd)/../conf/opt/siterm/config/ssh-keys:/opt/siterm/config/ssh-keys \
       -p 8080:80 \
       -p 8443:443 \
       --env-file $(pwd)/../conf/environment \
       --log-driver="json-file" --log-opt max-size=10m --log-opt max-file=10 \
       docker.io/sdnsense/site-rm-sense:$VERSION

# For development, add -v /home/jbalcas/siterm/:/opt/siterm/sitermcode/siterm/ \
