#!/bin/bash

set -e
if [ "$EUID" -ne 0 ]; then
    echo "Please, run with sudo command"
    exit 1;
fi

current_dir=$(pwd)

cd "$current_dir"/devcerts
mkcert -key-file argocd-ui-tls.key -cert-file argocd-ui-tls.crt argocd.stacknotes.local
mkcert -key-file argocd-grpc-tls.key -cert-file argocd-grpc-tls.crt grpc.argocd.stacknotes.local
mkcert -key-file stacknotes-tls.key -cert-file stacknotes-tls.crt app.stacknotes.local api.stacknotes.local
mkcert -key-file promstack-tls.key -cert-file promstack-tls.crt prometheus.stacknotes.local grafana.stacknotes.local

chmod -R +rwx .

cd "$current_dir"
CERTS_DIR="$current_dir"/devcerts

if [ ! -d "$CERTS_DIR" ]; then
    echo "Cert folder not found"
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
    
    if [[ "$key" == *"promstack"* ]]; then
        kubectl create secret tls "$secret_name" --key="$key" --cert="$cert" --namespace=monitoring
    elif [[ "$key" == *"argocd"* ]]; then
        kubectl create secret tls "$secret_name" --key="$key" --cert="$cert" --namespace=argocd
    else
        kubectl create secret tls "$secret_name" --key="$key" --cert="$cert"
    fi
    
    echo "Secret $secret_name created from $(basename "$key") and $(basename "$cert")"
done;


IP="127.0.0.1"
DOMAIN="grpc.argocd.stacknotes.local argocd.stacknotes.local app.stacknotes.local api.stacknotes.local prometheus.stacknotes.local grafana.stacknotes.local"
LINE="$IP $DOMAIN"

if grep -Fxq "$LINE" /etc/hosts; then
    echo -e "Domains already added: $DOMAIN"
else
    echo -e "\n#Custom\n$LINE" | tee -a /etc/hosts > /dev/null
    echo "Domains added: $DOMAIN"
fi
