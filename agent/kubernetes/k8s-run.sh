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

# Move config, hostcert, key - to name with hostname 
cp ../conf/etc/grid-security/hostcert.pem ../conf/etc/grid-security/hostcert.pem-$fqdn
cp ../conf/etc/grid-security/hostkey.pem ../conf/etc/grid-security/hostkey.pem-$fqdn
cp ../conf/etc/dtnrm.yaml ../conf/etc/dtnrm.yaml-$fqdn

# Copy and Modify the agent=k8s yaml file to include $fqdn
cp agent-k8s.yaml agent-k8s.yaml-$fqdn
sed "s|___REPLACEME___|$fqdn|g" agent-k8s.yaml-$fqdn

kubectl create secret generic sense-agent-$fqdn --from-file=agent-hostcert=../conf/etc/grid-security/hostcert.pem-$fqdn --from-file=agent-hostkey=../conf/etc/grid-security/hostkey.pem-$fqdn --namespace $namespace --kubeconfig $KUBECONF

kubectl create configmap sense-agent-$fqdn --from-file=sense-siterm-agent=../conf/etc/dtnrm.yaml-$fqdn --namespace $namespace --kubeconfig $KUBECONF


kubectl apply -f agent-k8s.yaml-$fqdn --namespace $namespace --kubeconfig $KUBECONF
