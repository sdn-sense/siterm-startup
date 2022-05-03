set -x

# TODO:
# 1. Ask which kubeconfig file to use
# 2. Check if cert's valid and if user wants to overwrite them
# 3. Config files can load and MariaDB password was changed.
# 4. Check kubernetes if if secrets or config map defined - if so - ask to overwrite or not?
# 5. Ask for public IP (for LoadBalancer type) - In future - have separate config for HAProxy

echo "Which kube config to use? Something like ~/.kube/config-prp-dev"
read KUBECONF

echo "Which Hostname we are deploying? Please enter full qualified domain name:"
read fqdn

echo "What is the external IP for Load Balancing?"
read publicip

echo "Which namespace on Kubernetes to use to deploy service?"
read namespace
# osg-gil

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
sed -i ".backup" "s|___REPLACEMENAMESPACE___|$namespace|g" sitefe-k8s.yaml-$fqdn
sed -i ".backup" "s|___REPLACEMEEXTERNALIP___|$publicip|g" sitefe-k8s.yaml-$fqdn

kubectl delete secret sense-fe-$fqdn --namespace $namespace --kubeconfig $KUBECONF
kubectl delete configmap sense-fe-$fqdn --namespace $namespace --kubeconfig $KUBECONF

kubectl create secret generic sense-fe-$fqdn \
        --from-file=fe-hostcert=../conf/etc/grid-security/hostcert.pem-$fqdn \
        --from-file=fe-hostkey=../conf/etc/grid-security/hostkey.pem-$fqdn \
        --from-file=fe-httpdcert=../conf/etc/httpd/certs/cert.pem-$fqdn \
        --from-file=fe-httpdprivkey=../conf/etc/httpd/certs/privkey.pem-$fqdn \
        --from-file=fe-httpdfullchain=../conf/etc/httpd/certs/fullchain.pem-$fqdn \
        --from-file=fe-environment=../conf/environment-$fqdn \
        --namespace $namespace --kubeconfig $KUBECONF
echo $?
kubectl create configmap sense-fe-$fqdn --from-file=sense-siterm-fe=../conf/etc/dtnrm.yaml-$fqdn --namespace $namespace --kubeconfig $KUBECONF
echo $?

kubectl apply -f sitefe-k8s.yaml-$fqdn --namespace $namespace --kubeconfig $KUBECONF
