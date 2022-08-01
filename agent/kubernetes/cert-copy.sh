
HOSTNAME=k8s-igrok-02.calit2.optiputer.net
cp ~/work/sense-ca/certs/server/$HOSTNAME/cert.pem ../conf/etc/grid-security/hostcert.pem-$HOSTNAME
cp ~/work/sense-ca/certs/server/$HOSTNAME/privkey.pem ../conf/etc/grid-security/hostkey.pem-$HOSTNAME
