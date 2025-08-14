# StackNotes Deployment Guide

---

## 1. Install on Kubernetes Cluster via GitOps

### Prerequisites

- argocd CLI installed  
- kubectl installed and configured (default kubeconfig at `~/.kube/config`)  
- mkcert installed for HTTPS certificates  

### 1.1. Install Argo CD

Run the following commands to create the `argocd` namespace and install Argo CD:

```bash
kubectl create namespace argocd

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 1.2. Generate TLS Certificates and Create Secrets

Execute the `start.sh` script to generate local TLS certificates and create Kubernetes secrets:

```bash
sudo -E ./start.sh
```

What `start.sh` does:

- Checks for root privileges  
- Uses mkcert to generate self-signed certificates for:
  - `app.stacknotes.local`
  - `api.stacknotes.local`
  - `argocd.stacknotes.local`
  - `grpc.argocd.stacknotes.local`
- Sets read/write permissions on the certificate files  
- Creates TLS secrets in the appropriate namespaces (`argocd`, `monitoring`, `default`)  
- Adds entries to `/etc/hosts` pointing those domains to `127.0.0.1`  

### 1.3. Deploy Applications with Argo CD

Apply the “App of Apps” manifest to sync all applications:

```bash
kubectl apply -f apps-of-apps.yaml
```

### 1.4. Access Information

- Argo CD UI:  
  https://argocd.stacknotes.local

- Argo CD CLI (gRPC):  
  grpc.argocd.stacknotes.local

- StackNotes Frontend UI:  
  https://app.stacknotes.local

- StackNotes Backend API:  
  https://api.stacknotes.local

- Prometheus:  
  https://prometheus.stacknotes.local

- Grafana:  
  https://grafana.stacknotes.local

### 1.5. Argo CD Credentials

Retrieve the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

- Username: `admin`  
- Password: (output of the command above)

## Final Notes

- Always run `start.sh` with `sudo` to generate trusted certificates and secrets.  
- Use `kubectl apply -f apps-of-apps.yaml` to deploy your applications through Argo CD.  
- Obtain and use the Argo CD credentials to log in.  
- Ensure your `/etc/hosts` file contains entries for all `*.stacknotes.local` domains.

---

## 2. Deploy via EC2/VM Instances with Ansible


### 2.1 Prerequisites

- Three servers (EC2 instances or Vagrant VMs) named **db**, **backend**, and **frontend**  
- Public (or private for Vagrant) IP addresses for each node, defined in `inventory.yml`  
- Ansible installed on the control machine  
- Vault password file `.vault_pass.txt` located in the project root  

---

### 2.2 Inventory

Populate `inventory.yml` with the actual IPs and SSH usernames:

```yaml
all:
  hosts:
    db:
      ansible_host: <DB_PUBLIC_IP>
      ansible_user: ubuntu
    backend:
      ansible_host: <BACKEND_PUBLIC_IP>
      ansible_user: ubuntu
    frontend:
      ansible_host: <FRONTEND_PUBLIC_IP>
      ansible_user: ubuntu
  children:
    web_servers:
      hosts:
        backend:
        frontend:
    db_servers:
      hosts:
        db:
```

---

### 2.3 Vault Password File

Create a file in the project root containing your Vault password:

```bash
echo "your_secret_password" > .vault_pass.txt
chmod 600 .vault_pass.txt
```

Ensure `ansible.cfg` references this file:

```ini
vault_password_file = .vault_pass.txt
```

---

### 2.4 Defining and Encrypting Secrets

Place a `secrets.yml` under `roles/<role>/vars/` for each service, then encrypt.

#### roles/db/vars/secrets.yml
```yaml
mongo_initdb_root_username: root
mongo_initdb_root_password: mongopw
```

#### roles/backend/vars/secrets.yml

```yaml
node_environment: Development
cors_allowed_origins: "http://<FRONTEND_IP>"
database_uri: "mongodb://root:mongopw@<DB_IP>:27017/stacknotes?authSource=admin"
access_token_secret: "b94802f4675a1c374df3d61ec80bec89327ec9ec206b4d669524f543d04d46e7627e683d2674d09de0b2df5614c14fd9490bca954a5716c6c9b1327c6595a3dc"
refresh_token_secret: "9106c739cfbdf45f39d825beadc09ba66a137b9b04007760570f8888f6fc31346f26cb416f05832670b842eb951129f1525e8c466487e55780576bf0e82e07a1"
```

#### roles/frontend/vars/secrets.yml

```yaml
vite_api_url: "http://<BACKEND_IP>:3500"
```

Encrypt the files below:

```bash
ansible-vault encrypt roles/db/vars/secrets.yml
ansible-vault encrypt roles/backend/vars/secrets.yml
ansible-vault encrypt roles/frontend/vars/secrets.yml
```

---

### 2.5 Managing Secrets

- View decrypted contents:  
  ```bash
  ansible-vault view roles/backend/vars/secrets.yml
  ```

- Edit in place:  
  ```bash
  ansible-vault edit roles/frontend/vars/secrets.yml
  ```

- Fully decrypt:  
  ```bash
  ansible-vault decrypt roles/backend/vars/secrets.yml
  ```

- Re-encrypt after changes:  
  ```bash
  ansible-vault encrypt roles/backend/vars/secrets.yml
  ```

---

### 2.6 Provisioning and Deployment

1. If using Vagrant (skip step 2 because Vagrant will auto-provision), start the VMs:  
   ```bash
   vagrant up
   ```
2. Run the Ansible playbook:  
   ```bash
   ansible-playbook playbooks/site.yml -v
   ```
3. Check service status on backend node:  
   ```bash
   ansible backend -m shell -a "systemctl status stacknotes.service"
   ```

---

## Final Notes

- You need three instances (db, backend, frontend) either on EC2 or via Vagrant.  
- Define each host’s IP in `inventory.yml`, or let Vagrant manage it automatically.  
- Secrets are encrypted with Ansible Vault and decrypted during playbook execution using `.vault_pass.txt`.  
- Once the playbook completes, the frontend will reach the backend API at `window.ENV.STACKNOTES_API_URL`.
---