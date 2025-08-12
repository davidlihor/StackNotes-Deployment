Requirements: 
k8s cluster
Installed kubectl command-line tool.
Have a kubeconfig file (default location is ~/.kube/config).


1. Install Argo CD¶
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

run
start.sh to install certs


user: admin
password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

access at argocd.stacknotes.local, grpc.argocd.stacknotes.local for argocd cli
app will be avaible at: app.stacknotes.local





# Argo CD Setup Guide

## Requirements

- A running Kubernetes cluster.
- `kubectl` command-line tool installed and configured.
- A valid kubeconfig file (default location: `~/.kube/config`).

---

## 1. Install Argo CD

Create the `argocd` namespace and install Argo CD manifests:

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

---

## 2. Generate TLS Certificates and Create Kubernetes Secrets (`start.sh`)

Run the `start.sh` script to generate local TLS certificates for your domains and create Kubernetes TLS secrets:

sudo -E ./start.sh

### What `start.sh` does:

- Checks for root privileges (requires `sudo`).
- Uses `mkcert` to generate self-signed TLS certificates for these domains:
  - `app.stacknotes.local`
  - `api.stacknotes.local`
  - `argocd.stacknotes.local`
  - `grpc.argocd.stacknotes.local`
- Sets read/write permissions for the certificate files.
- Creates Kubernetes TLS secrets in the appropriate namespaces (`argocd`, `monitoring`, or default) from the generated certificates.
- Adds the custom domains to `/etc/hosts` for local resolution, pointing to `127.0.0.1`.

Note: You must have `mkcert` installed on your machine before running this script.  
This script helps you simulate HTTPS locally with trusted certificates.

---

## 3. Deploy Applications with Argo CD

Apply your application manifests using the "App of Apps" pattern:

kubectl apply -f apps-of-apps.yaml

This command tells Argo CD to synchronize all applications defined in `apps-of-apps.yaml`.

---

## 4. Access Information

- Argo CD UI:  
  Access the Argo CD web interface at:  
  https://argocd.stacknotes.local

- Argo CD CLI (gRPC):  
  Use the CLI to connect via:  
  grpc.argocd.stacknotes.local

- Managed Applications:  
  Application deployed through Argo CD is accessible at:  
  https://app.stacknotes.local

---

## 5. Argo CD Credentials

Get the initial admin password from the Kubernetes secret:

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

- Username: admin  
- Password: (output of the above command)

---

## Final notes

Make sure to:

- Run the `start.sh` script with sudo to generate certificates and create secrets.
- Run `kubectl apply -f apps-of-apps.yaml` to deploy your apps through Argo CD.
- Use the generated credentials to log in to Argo CD.
- Access the apps via configured hostnames on your local machine.



kubectl port-forward svc/argocd-server -n argocd 8080:443
argocd login localhost:8080 --insecure
argocd app create root-app \
  --repo https://github.com/davidlihor/StackNotes-Deployment \
  --path argocd/apps \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --directory-recurse \
  --sync-policy automated
