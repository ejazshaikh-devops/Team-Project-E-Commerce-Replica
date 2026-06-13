# 🛒 Abhi+Ejaz Shop

> **E-Commerce Platform** — Microservices · Docker · Kubernetes (AWS EKS) · Terraform · MariaDB

A full-stack e-commerce app inspired by Flipkart, Amazon & Myntra. Built with 5 independent microservices, deployed on AWS EKS with one-command infrastructure provisioning.

---

## 🏗 Architecture

```
Internet
   │
   ▼
AWS ALB (Ingress)
   ├── /api/*      → API Gateway (Nginx) → Microservices
   └── /*          → Frontend (HTML/JS SPA)

Microservices:
   ├── product-service  :3001  (Node.js + MariaDB)
   ├── cart-service     :3002  (Node.js + MariaDB)
   ├── order-service    :3003  (Node.js + MariaDB)
   └── user-service     :3004  (Node.js + MariaDB + JWT)

Database: AWS RDS MariaDB (private subnet)
Registry: AWS ECR (one repo per service)
```

## 📁 Project Structure

```
abhi-ejaz-shop/
├── services/
│   ├── db-init/           # MariaDB schema + 15 real products seeded
│   ├── shared/            # Shared DB connection pool
│   ├── product-service/   # Products, categories, search
│   ├── cart-service/      # Cart with DB persistence
│   ├── order-service/     # Order lifecycle + tracking
│   ├── user-service/      # Auth (JWT), profile, wishlist
│   ├── api-gateway/       # Nginx reverse proxy
│   └── frontend/          # SPA — all pages
├── k8s/                   # Kubernetes manifests
├── terraform/             # AWS infrastructure as code
├── docker-compose.yml     # Local development
└── deploy.sh              # One-command deploy script
```

## 🌐 Page Routes

| URL | Page |
|-----|------|
| `/` | Home |
| `/clothes` | Clothing |
| `/electronics` | Electronics |
| `/footwear` | Footwear |
| `/cart` | Shopping Cart |
| `/orders` | My Orders |
| `/user` | Login / Profile |

---

## 🚀 Go-Live Guide (AWS Deployment)

Follow every step in order. Both collaborators should read this before starting.

---

### STEP 0 — Who Does What

| Task | Who |
|------|-----|
| AWS account setup + credentials | Owner |
| Terraform apply | Owner |
| Build & push Docker images | Either |
| Seed database | Either |
| kubectl apply | Either |

---

### STEP 1 — Install Tools

Run on your local machine (Ubuntu/Mac).

**AWS CLI**
```bash
apt install unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
aws --version
```

**Terraform**
```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**kubectl**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"l
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

**Docker**
```bash
sudo apt update && sudo apt install -y docker.io
sudo usermod -aG docker $USER
newgrp docker
docker --version
chmod 777 /var/run/docker.sock
```

**Helm**
```bash
HELM_BUILDKITE_APT_KEY_ID="DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6"

sudo apt-get install curl gpg apt-transport-https --yes

curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey > "${TMPDIR:-/tmp}/helm.gpg"

# Ensure that the key ID matches to prevent a repository compromise from establishing an attacker controlled key
if [ "$(gpg --show-keys --with-colons "${TMPDIR:-/tmp}/helm.gpg" | awk -F: '$1 == "fpr" {print $10}' | head -n 1)" != "${HELM_BUILDKITE_APT_KEY_ID}" ]; then echo "ERROR: Unexpected Helm APT key ID: potential key compromise"; exit 1; fi

cat "${TMPDIR:-/tmp}/helm.gpg" | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

sudo apt-get update
sudo apt-get install helm
```

**eksctl**
```bash
curl --silent --location \
  "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" \
  | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version
```

**MySQL client**
```bash
sudo apt install -y mysql-client
```

---

### STEP 2 — Configure AWS

> **Owner only.** Go to AWS Console → IAM → Users → your user → Security credentials → Create access key.

```bash
aws configure
# AWS Access Key ID:     <paste your key>
# AWS Secret Access Key: <paste your secret>
# Default region name:   ap-south-1
# Default output format: json
```

```bash
# Verify it worked
aws sts get-caller-identity
```

---

### STEP 3 — Clone & Configure

```bash
git clone https://github.com/YOUR_USERNAME/abhi-ejaz-shop.git
cd abhi-ejaz-shop
```

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
nano terraform/terraform.tfvars
```

Set it to this — **only change the password**:

```hcl
region             = "ap-south-1"
project            = "abhi-ejaz"
env                = "prod"
db_username        = "abhi_ejaz"
db_password        = "MyShop@Strong2024"   # ← CHANGE THIS
db_name            = "abhi_ejaz_shop"
node_instance_type = "t3.medium"
node_min           = 1
node_max           = 5
node_desired       = 2
```

> ⚠️ `terraform.tfvars` is in `.gitignore` — never commit it. Share the DB password with your collaborator privately.

---

### STEP 4 — Create Terraform State Bucket

> **Run once. Owner only.**

```bash
aws s3 mb s3://abhi-ejaz-terraform-state --region ap-south-1
```

```bash
aws s3api put-bucket-versioning \
  --bucket abhi-ejaz-terraform-state \
  --versioning-configuration Status=Enabled
```

```bash
aws s3api put-public-access-block \
  --bucket abhi-ejaz-terraform-state \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

```bash
aws dynamodb create-table \
  --table-name abhi-ejaz-tf-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1

echo "✅ State bucket ready"
```

---

### STEP 5 — Terraform Apply

> ⏰ Takes **15–20 minutes**. Creates VPC, EKS cluster, RDS MariaDB, ECR repos, security groups — everything.

```bash
cd terraform
terraform init
```

```bash
terraform plan
# Review — should show ~45 resources to create
```

```bash
terraform apply
# Type: yes when prompted
# Get a chai ☕ — takes 15-20 min
```

```bash
# Save outputs — needed in later steps
terraform output

cd ..
```

---

### STEP 6 — Connect kubectl to EKS

```bash
CLUSTER_NAME=$(cd terraform && terraform output -raw cluster_name)
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region ap-south-1
```

```bash
# Should show 2 nodes in Ready state
kubectl get nodes
```

---

### STEP 7 — Install AWS Load Balancer Controller

> Creates the public-facing ALB that gives you your URL.

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json
```

```bash
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
```

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER_NAME=$(cd terraform && terraform output -raw cluster_name)

eksctl create iamserviceaccount \
  --cluster="$CLUSTER_NAME" \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region ap-south-1
```

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

```bash
# Should show READY 2/2
kubectl get deployment -n kube-system aws-load-balancer-controller
```

---

### STEP 8 — Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

```bash
kubectl get deployment metrics-server -n kube-system
```

---

### STEP 9 — Build & Push Docker Images to ECR

```bash
ECR_REGISTRY=$(cd terraform && terraform output -raw ecr_registry)

aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"
# Should print: Login Succeeded
```

```bash
docker build -t "$ECR_REGISTRY/abhi-ejaz/product-service:latest" \
  -f services/product-service/Dockerfile ./services
docker push "$ECR_REGISTRY/abhi-ejaz/product-service:latest"
echo "✅ product-service"
```

```bash
docker build -t "$ECR_REGISTRY/abhi-ejaz/cart-service:latest" \
  -f services/cart-service/Dockerfile ./services
docker push "$ECR_REGISTRY/abhi-ejaz/cart-service:latest"
echo "✅ cart-service"
```

```bash
docker build -t "$ECR_REGISTRY/abhi-ejaz/order-service:latest" \
  -f services/order-service/Dockerfile ./services
docker push "$ECR_REGISTRY/abhi-ejaz/order-service:latest"
echo "✅ order-service"
```

```bash
docker build -t "$ECR_REGISTRY/abhi-ejaz/user-service:latest" \
  -f services/user-service/Dockerfile ./services
docker push "$ECR_REGISTRY/abhi-ejaz/user-service:latest"
echo "✅ user-service"
```

```bash
docker build -t "$ECR_REGISTRY/abhi-ejaz/api-gateway:latest" \
  ./services/api-gateway
docker push "$ECR_REGISTRY/abhi-ejaz/api-gateway:latest"
echo "✅ api-gateway"
```

```bash
docker build -t "$ECR_REGISTRY/abhi-ejaz/frontend-service:latest" \
  ./services/frontend
docker push "$ECR_REGISTRY/abhi-ejaz/frontend-service:latest"
echo "✅ frontend-service"
```

---

### STEP 10 — Seed the Database

```bash
RDS_ENDPOINT=$(cd terraform && terraform output -raw rds_endpoint)
echo "RDS: $RDS_ENDPOINT"
```

```bash
# Enter your db_password when prompted
mysql -h "$RDS_ENDPOINT" \
      -u abhi_ejaz \
      -p \
      abhi_ejaz_shop \
      < services/db-init/init.sql
```

```bash
# Verify 15 products were seeded
mysql -h "$RDS_ENDPOINT" -u abhi_ejaz -p abhi_ejaz_shop \
  -e "SELECT COUNT(*) as total FROM products;"
```

---

### STEP 11 — Deploy to Kubernetes

**Namespace**
```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl get namespace abhi-ejaz
```

**Secrets**
```bash
RDS_ENDPOINT=$(cd terraform && terraform output -raw rds_endpoint)
DB_PASSWORD="MyShop@Strong2024"   # same as terraform.tfvars

kubectl create secret generic ae-secrets \
  --namespace=abhi-ejaz \
  --from-literal=DB_HOST="$RDS_ENDPOINT" \
  --from-literal=DB_PORT="3306" \
  --from-literal=DB_USER="abhi_ejaz" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  --from-literal=DB_NAME="abhi_ejaz_shop" \
  --from-literal=JWT_SECRET="AbhiEjazJWTSuperSecret2024ChangeThis" \
  --dry-run=client -o yaml | kubectl apply -f -
```

**ConfigMap**
```bash
kubectl apply -f k8s/02-configmap.yaml
```

**Patch ECR URL into deployments**
```bash
ECR_REGISTRY=$(cd terraform && terraform output -raw ecr_registry)
sed -i "s|YOUR_ECR_REGISTRY|$ECR_REGISTRY|g" k8s/03-deployments.yaml

# Verify it looks right
grep "image:" k8s/03-deployments.yaml | head -3
```

**Deploy all services**
```bash
kubectl apply -f k8s/03-deployments.yaml
```

```bash
# Watch pods — wait until all show 1/1 Running, then Ctrl+C
kubectl get pods -n abhi-ejaz -w
```

**Ingress — creates the public ALB**
```bash
kubectl apply -f k8s/04-ingress.yaml
```

```bash
# Watch for ADDRESS column to fill in — takes 3-5 min, then Ctrl+C
kubectl get ingress ae-ingress -n abhi-ejaz -w
```

**HPA Autoscaling**
```bash
kubectl apply -f k8s/05-hpa.yaml
kubectl get hpa -n abhi-ejaz
```

---

### STEP 12 — Go Live 🎉

```bash
PUBLIC_URL=$(kubectl get ingress ae-ingress -n abhi-ejaz \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Your shop: http://$PUBLIC_URL"
```

```bash
curl http://$PUBLIC_URL/health
```

```bash
curl http://$PUBLIC_URL/api/products
```

**Open in browser:**
```
http://<YOUR_ALB_URL>/
http://<YOUR_ALB_URL>/clothes
http://<YOUR_ALB_URL>/electronics
http://<YOUR_ALB_URL>/cart
http://<YOUR_ALB_URL>/orders
http://<YOUR_ALB_URL>/user
```

---

## 🔧 Useful Commands

```bash
# All pods
kubectl get pods -n abhi-ejaz

# Logs
kubectl logs -f deployment/product-service  -n abhi-ejaz
kubectl logs -f deployment/cart-service     -n abhi-ejaz
kubectl logs -f deployment/order-service    -n abhi-ejaz
kubectl logs -f deployment/user-service     -n abhi-ejaz
kubectl logs -f deployment/api-gateway      -n abhi-ejaz
kubectl logs -f deployment/frontend-service -n abhi-ejaz

# Restart a service after pushing new image
kubectl rollout restart deployment/product-service -n abhi-ejaz

# Resource usage
kubectl top pods -n abhi-ejaz
kubectl top nodes

# Autoscaling status
kubectl get hpa -n abhi-ejaz
```

---

## 🐛 Troubleshooting

| Problem | Fix |
|---------|-----|
| Pod stuck in `Pending` | `kubectl describe pod <name> -n abhi-ejaz` — check Events section |
| `ImagePullBackOff` | Re-run the `aws ecr get-login-password` login command |
| `CrashLoopBackOff` | `kubectl logs deployment/<name> -n abhi-ejaz` — usually DB connection error |
| ALB ADDRESS stays empty | Wait 5 min. Check: `kubectl get pods -n kube-system` |
| DB connection refused | RDS security group must allow port 3306 from EKS node security group |
| `terraform apply` fails | Ensure AWS user has AdministratorAccess IAM policy |
| Wrong image in pod | Re-run `sed` command in Step 11 to patch ECR URL |

---

## 💰 Estimated AWS Cost

| Resource | Spec | Cost/month |
|----------|------|-----------|
| EKS Cluster | Control plane | ~$73 |
| EC2 Nodes | 2× t3.medium | ~$60 |
| RDS MariaDB | db.t3.micro | ~$15 |
| NAT Gateway | 1× | ~$33 |
| ALB | 1× | ~$18 |
| ECR Storage | 6 repos | ~$1 |
| **Total** | | **~₹16,500/month** |

> To save money while testing: `terraform destroy`. Take an RDS snapshot first to keep your data.

---

## 🛠 Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Node.js 20, Express 4 |
| Database | MariaDB 11 (AWS RDS) |
| Auth | JWT + bcryptjs |
| Gateway | Nginx 1.25 |
| Frontend | HTML/CSS/JS SPA |
| Containers | Docker (multi-stage) |
| Registry | AWS ECR |
| Orchestration | Kubernetes — AWS EKS 1.29 |
| Infrastructure | Terraform 1.7 |
| Cloud | AWS ap-south-1 (Mumbai) |
| Autoscaling | Kubernetes HPA |

---

## 👥 Team

Built by **Abhishek** & **Ejaz** 🛒
