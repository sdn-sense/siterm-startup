
HOSTNAME=sense-fe.nrp-nautilus.io
cp ~/work/sense-ca/certs/server/$HOSTNAME/cert.pem ../conf/etc/grid-security/hostcert.pem-$HOSTNAME
cp ~/work/sense-ca/certs/server/$HOSTNAME/privkey.pem ../conf/etc/grid-security/hostkey.pem-$HOSTNAME
cp ~/work/sense-ca/certs/server/$HOSTNAME/cert.pem ../conf/etc/httpd/certs/cert.pem-$HOSTNAME
cp ~/work/sense-ca/certs/server/$HOSTNAME/privkey.pem ../conf/etc/httpd/certs/privkey.pem-$HOSTNAME
cp ~/work/sense-ca/certs/server/$HOSTNAME/fullchain.pem ../conf/etc/httpd/certs/fullchain.pem-$HOSTNAME
