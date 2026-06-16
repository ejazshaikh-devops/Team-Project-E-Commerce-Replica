#!/bin/bash
# ════════════════════════════════════════════════════════════
# Abhi+Ejaz Shop — Full Deploy Script
# Run this ONCE after cloning the repo.
# After this, pushing to main auto-deploys (Phase CI/CD).
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh
# ════════════════════════════════════════════════════════════
set -e

REGION="ap-south-1"
PROJECT="abhi-ejaz"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     Abhi+Ejaz Shop — Full Deploy         ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Step 1: Terraform ──────────────────────────────────────
echo "▶ Step 1/5: Terraform — provisioning AWS infra..."
cd terraform

if [ ! -f "terraform.tfvars" ]; then
  echo "❌ terraform.tfvars not found."
  echo "   Copy terraform.tfvars.example → terraform.tfvars and fill in your DB password."
  exit 1
fi

terraform init
terraform apply -auto-approve

ECR_REGISTRY=$(terraform output -raw ecr_registry)
CLUSTER_NAME=$(terraform output -raw cluster_name)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)

echo "✅ Infra ready. ECR: $ECR_REGISTRY | Cluster: $CLUSTER_NAME"

# ── Step 2: kubectl config ─────────────────────────────────
echo ""
echo "▶ Step 2/5: Configuring kubectl..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
echo "✅ kubectl configured"

# ── Step 3: Build & Push images to ECR ────────────────────
echo ""
echo "▶ Step 3/5: Building and pushing Docker images to ECR..."
cd ..

aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

SERVICES="product-service cart-service order-service user-service api-gateway frontend-service"

for svc in $SERVICES; do
  echo "  Building $svc..."
  if [ "$svc" = "api-gateway" ]; then
    docker build -t "$ECR_REGISTRY/$PROJECT/$svc:latest" ./services/api-gateway
  elif [ "$svc" = "frontend-service" ]; then
    docker build -t "$ECR_REGISTRY/$PROJECT/$svc:latest" ./services/frontend
  else
    docker build -t "$ECR_REGISTRY/$PROJECT/$svc:latest" -f "./services/$svc/Dockerfile" ./services
  fi
  docker push "$ECR_REGISTRY/$PROJECT/$svc:latest"
  echo "  ✅ $svc pushed"
done

# ── Step 4: Update image references in K8s manifests ──────
echo ""
echo "▶ Step 4/5: Patching K8s manifests with ECR registry..."
sed -i "s|YOUR_ECR_REGISTRY|$ECR_REGISTRY|g" k8s/03-deployments.yaml
echo "✅ Manifests patched"

# ── Step 5: Apply K8s manifests ───────────────────────────
echo ""
echo "▶ Step 5/5: Applying Kubernetes manifests..."

kubectl apply -f k8s/00-namespace.yaml

# Create secret from RDS output
kubectl create secret generic ae-secrets \
  --namespace=abhi-ejaz \
  --from-literal=DB_HOST="$RDS_ENDPOINT" \
  --from-literal=DB_PORT="3306" \
  --from-literal=DB_USER="abhi_ejaz" \
  --from-literal=DB_PASSWORD="$(grep db_password terraform/terraform.tfvars | cut -d'"' -f2)" \
  --from-literal=DB_NAME="abhi_ejaz_shop" \
  --from-literal=JWT_SECRET="AbhiEjazJWTSuperSecret2024ChangeThis" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f k8s/02-configmap.yaml
kubectl apply -f k8s/03-deployments.yaml
kubectl apply -f k8s/04-ingress.yaml
kubectl apply -f k8s/05-hpa.yaml

echo ""
echo "⏳ Waiting for pods to be ready..."
kubectl rollout status deployment/product-service -n abhi-ejaz --timeout=120s
kubectl rollout status deployment/cart-service    -n abhi-ejaz --timeout=120s
kubectl rollout status deployment/order-service   -n abhi-ejaz --timeout=120s
kubectl rollout status deployment/user-service    -n abhi-ejaz --timeout=120s
kubectl rollout status deployment/api-gateway     -n abhi-ejaz --timeout=120s
kubectl rollout status deployment/frontend-service -n abhi-ejaz --timeout=120s

echo ""
echo "⏳ Getting public URL (may take 2-3 minutes for ALB)..."
sleep 30
PUBLIC_URL=$(kubectl get ingress ae-ingress -n abhi-ejaz \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending...")

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ✅  ABHI+EJAZ SHOP IS LIVE!                         ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  🌐 URL:         http://$PUBLIC_URL"
echo "║  👕 Clothing:    http://$PUBLIC_URL/clothes"
echo "║  📱 Electronics: http://$PUBLIC_URL/electronics"
echo "║  🛒 Cart:        http://$PUBLIC_URL/cart"
echo "║  📦 Orders:      http://$PUBLIC_URL/orders"
echo "║  👤 Login:       http://$PUBLIC_URL/user"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  NOTE: Run init.sql on RDS to seed products:         ║"
echo "║  mysql -h $RDS_ENDPOINT -u abhi_ejaz -p abhi_ejaz_shop < services/db-init/init.sql"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
