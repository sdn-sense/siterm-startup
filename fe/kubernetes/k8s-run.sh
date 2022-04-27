set -x

# ENVIRONMENT
KUBECONF=~/.kube/config-prp-dev

echo "Which Hostname we are deploying? Please enter full qualified domain name:"
read fqdn

echo "Which namespace on Kubernetes to use to deploy service?"
read namespace
# osg-gil

# Need to check all certificates, and configs.
# Certs need be valid;
# Config - have real config parameters
# Check that Mariadb password is set, if not - set random

# Some fields in yaml require listing without '.' - so we replace it to  '-'
fqdnnodots=$( echo ${fqdn:1} | tr '.' '-' )



# Move config, hostcert, key - to name with hostname 
cp ../conf/etc/grid-security/hostcert.pem ../conf/etc/grid-security/hostcert.pem-$fqdn
cp ../conf/etc/grid-security/hostkey.pem ../conf/etc/grid-security/hostkey.pem-$fqdn
cp ../conf/etc/httpd/certs/cert.pem ../conf/etc/httpd/certs/cert.pem-$fqdn
cp ../conf/etc/httpd/certs/privkey.pem ../conf/etc/httpd/certs/privkey.pem-$fqdn
cp ../conf/etc/httpd/certs/fullchain.pem ../conf/etc/httpd/certs/fullchain.pem-$fqdn
cp ../conf/environment ../conf/environment-$fqdn

cp ../conf/etc/dtnrm.yaml ../conf/etc/dtnrm.yaml-$fqdn

# Copy and Modify the agent=k8s yaml file to include $fqdn
cp sitefe-k8s.yaml sitefe-k8s.yaml-$fqdn
sed -i ".backup" "s|___REPLACEME___|$fqdn|g" sitefe-k8s.yaml-$fqdn
sed -i ".backup" "s|___REPLACEMENODOTS___|$fqdnnodots|g" sitefe-k8s.yaml-$fqdn



kubectl create secret generic sense-fe-$fqdn \
        --from-file=fe-hostcert=../conf/etc/grid-security/hostcert.pem-$fqdn \
        --from-file=fe-hostkey=../conf/etc/grid-security/hostkey.pem-$fqdn \
        --from-file=fe-httpdcert=../conf/etc/httpd/certs/cert.pem-$fqdn \
        --from-file=fe-httpdprivkey=../conf/etc/httpd/certs/privkey.pem-$fqdn \
        --from-file=fe-httpdfullchain=../conf/etc/httpd/certs/fullchain.pem-$fqdn \
        --from-file=fe-environment=../conf/environment-$fqdn \
        --namespace $namespace --kubeconfig $KUBECONF

kubectl create configmap sense-fe-$fqdn --from-file=sense-siterm-fe=../conf/etc/dtnrm.yaml-$fqdn --namespace $namespace --kubeconfig $KUBECONF


kubectl apply -f sitefe-k8s.yaml-$fqdn --namespace $namespace --kubeconfig $KUBECONF
