#!/bin/bash

set -e
if [ "$EUID" -ne 0 ]; then
    echo "Please, run with sudo command"
    exit 1;
fi

current_dir=$(pwd)
# minikube cp ./keycloak-config/data/import/keycloak.json /data/import/keycloak.json

# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
# helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
# helm repo update

# helm dependency update $current_dir/infra/helm
# helm install nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
# helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
# helm install carsties $current_dir/infra/helm --namespace default --create-namespace


cd "$current_dir"/devcerts
mkcert -key-file stacknotes-local-tls.key -cert-file stacknotes-local-tls.crt app.stacknotes.local api.stacknotes.local
chmod -R +rwx .

# cd "$current_dir"/infra/devcerts
# mkcert -key-file carsties-app-tls.key -cert-file carsties-app-tls.crt app.carsties.local api.carsties.local id.carsties.local
# mkcert -key-file monitoring-tls.key -cert-file monitoring-tls.crt prometheus.monitoring.local grafana.monitoring.local


cd "$current_dir"
CERTS_DIR="$current_dir"/devcerts #/infra/devcerts

if [ ! -d "$CERTS_DIR" ]; then
    echo "Cert folder not found";
    exit 1
fi

for cert in "$CERTS_DIR"/*.crt; do
    [ -e "$cert" ] || {
        echo "No certificate found in $CERTS_DIR";
        exit 1;
    }

    secret_name=$(basename "$cert" .crt)
    key="${CERTS_DIR}/${secret_name}.key"
    
    if [ ! -f "$key" ]; then
        echo "WARNING! Key for $cert not found"
        continue;
    fi

    kubectl delete secret "$secret_name" || true
    
    if [[ "$key" != *"monitoring"* ]]; then
        kubectl create secret tls "$secret_name" --key="$key" --cert="$cert"
    else
        kubectl create secret tls "$secret_name" --key="$key" --cert="$cert" --namespace=monitoring
    fi
    
    echo "Secret $secret_name created from $key and $cert"
done;


IP="127.0.0.1"
DOMAIN="app.stacknotes.local api.stacknotes.local"
LINE="$IP $DOMAIN"

if grep -Fxq "$LINE" /etc/hosts; then
    echo -e "Domains already added: $DOMAIN"
else
    echo -e "\n#Custom\n$LINE" | tee -a /etc/hosts > /dev/null
    echo "Domains added: $DOMAIN"
fi
