
HOSTNAME=sense-ladowntown-fe.sdn-lb.ultralight.org
cp ~/work/sense-ca/certs/server/$HOSTNAME/cert.pem ../conf/etc/grid-security/hostcert.pem
cp ~/work/sense-ca/certs/server/$HOSTNAME/privkey.pem ../conf/etc/grid-security/hostkey.pem
cp ~/work/sense-ca/certs/server/$HOSTNAME/cert.pem ../conf/etc/httpd/certs/cert.pem
cp ~/work/sense-ca/certs/server/$HOSTNAME/privkey.pem ../conf/etc/httpd/certs/privkey.pem
cp ~/work/sense-ca/certs/server/$HOSTNAME/fullchain.pem ../conf/etc/httpd/certs/fullchain.pem
