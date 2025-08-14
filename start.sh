#!/usr/bin/env bash

set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "Please, run with sudo command."
    exit 1
fi

command -v mkcert >/dev/null || { echo "Error: mkcert is required, install it first"; exit 1; }
command -v kubectl >/dev/null || { echo "Error: kubectl is required, install it first"; exit 1; }

CERTS_DIR="$(pwd)/devcerts"

if [ ! -d "$CERTS_DIR" ]; then
    mkdir -p "$CERTS_DIR"
    echo "Cert folder created at $CERTS_DIR."
fi

cd "$CERTS_DIR"

mkcert -key-file argocd-ui-tls.key \
       -cert-file argocd-ui-tls.crt \
       argocd.stacknotes.local

mkcert -key-file argocd-grpc-tls.key \
       -cert-file argocd-grpc-tls.crt \
       grpc.argocd.stacknotes.local

mkcert -key-file stacknotes-tls.key \
       -cert-file stacknotes-tls.crt \
       app.stacknotes.local api.stacknotes.local

mkcert -key-file promstack-tls.key \
       -cert-file promstack-tls.crt \
       prometheus.stacknotes.local grafana.stacknotes.local

chmod -R +rwx .
chown -R $SUDO_USER:$SUDO_USER .

for cert in "$CERTS_DIR"/*.crt; do
    secret_name=$(basename "$cert" .crt)
    key="$CERTS_DIR/$secret_name.key"

    if [[ "$secret_name" == promstack* ]]; then
        ns=monitoring
    elif [[ "$secret_name" == argocd* ]]; then
        ns=argocd
    else
        ns=default
    fi

    kubectl create namespace "$ns" || true
    kubectl delete secret "$secret_name" --namespace="$ns" || true
    kubectl create secret tls "$secret_name" \
        --key="$key" \
        --cert="$cert" \
        --namespace="$ns"
done


IP="127.0.0.1"
DOMAINS=(
  app.stacknotes.local
  api.stacknotes.local
  prometheus.stacknotes.local
  grafana.stacknotes.local
  argocd.stacknotes.local
  grpc.argocd.stacknotes.local
)

MARKER="#StackNotes"
HOSTS_FILE="/etc/hosts"
NEW_LINE="$IP ${DOMAINS[*]}"

TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

awk -v marker="$MARKER" -v newline="$NEW_LINE" '
  $0 == marker {
    print
    getline
    print newline
    next
  }
  { print }
' "$HOSTS_FILE" > "$TMP_FILE"


if ! grep -Fxq "$MARKER" "$HOSTS_FILE"; then
  {
    echo ""
    echo "$MARKER"
    echo "$NEW_LINE"
  } >> "$TMP_FILE"
fi

cp "$TMP_FILE" "$HOSTS_FILE"

echo "The /etc/hosts file has been updated under the $MARKER marker."
