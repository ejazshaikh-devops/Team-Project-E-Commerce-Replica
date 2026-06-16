# 🛒 Abhi+Ejaz Shop
### A Production-Grade E-Commerce Platform (Flipkart × Amazon × Myntra)

> Microservices architecture · Docker · Kubernetes on AWS EKS · Terraform IaC · MariaDB · CI/CD

---

## 📋 Project Phases

| Phase | Status | Description |
|-------|--------|-------------|
| **Phase 1** | ✅ Done | All 5 backend microservices + MariaDB schema + Docker Compose |
| **Phase 2** | ✅ Done | Full frontend (React/HTML) — all pages with real product UI |
| **Phase 3** | ✅ Done | Production Dockerfiles + ECR push scripts |
| **Phase 4** | ✅ Done | Terraform — AWS VPC + EKS + RDS MariaDB (fully automated) |
| **Phase 5** | ✅ Done | Kubernetes manifests — Ingress, HPA, Secrets, ConfigMaps |
| **Phase 6** | ✅ Done | GitHub Actions CI/CD — push = auto deploy |

---

## 🏗 Architecture

```
Internet
   │
   ▼
AWS ALB (Ingress)
   │
   ├── /           → Frontend Service (HTML/CSS/JS)
   ├── /clothes    → Product Service (category=clothes)
   ├── /electronics→ Product Service (category=electronics)
   ├── /cart       → Cart Service
   ├── /orders     → Order Service
   ├── /user       → User Service
   └── /api/*      → API Gateway → respective service
            │
            ├── Product Service :3001  ─── MariaDB (RDS)
            ├── Cart Service    :3002  ─── MariaDB (RDS)
            ├── Order Service   :3003  ─── MariaDB (RDS)
            └── User Service    :3004  ─── MariaDB (RDS)
```

## 🗂 Project Structure

```
abhi-ejaz-shop/
├── services/
│   ├── db-init/          # MariaDB schema + seed data
│   │   └── init.sql
│   ├── shared/
│   │   └── db.js         # Shared DB pool
│   ├── product-service/  # Node.js :3001
│   ├── cart-service/     # Node.js :3002
│   ├── order-service/    # Node.js :3003
│   ├── user-service/     # Node.js :3004
│   ├── api-gateway/      # Nginx :80
│   └── frontend/         # (Phase 2)
├── k8s/                  # (Phase 5)
├── terraform/            # (Phase 4)
├── .github/workflows/    # (Phase 6)
├── docker-compose.yml
└── .env.example
```

---

## 🚀 Phase 1: Local Setup

### Prerequisites
- Docker Desktop installed
- Node.js 20+ (for local dev without Docker)

### Run with Docker Compose

```bash
# 1. Clone the repo
git clone <your-repo-url>
cd abhi-ejaz-shop

# 2. Copy env file
cp .env.example .env

# 3. Start all services
docker-compose up --build

# 4. Wait ~30 seconds for MariaDB to initialize, then test:
curl http://localhost/health
curl http://localhost/api/products
curl http://localhost/api/categories
curl http://localhost/api/products/featured/all
```

### Test All Services

```bash
# Products
curl http://localhost/api/products?category=clothes
curl http://localhost/api/products?category=electronics
curl http://localhost/api/products/samsung-galaxy-s24

# Register & Login
curl -X POST http://localhost/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Abhishek","email":"abhi@test.com","password":"Test@123"}'

curl -X POST http://localhost/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"abhi@test.com","password":"Test@123"}'

# Cart (replace session_id with any unique string)
curl -X POST http://localhost/api/cart/add \
  -H "Content-Type: application/json" \
  -d '{"session_id":"sess123","product_id":1,"quantity":1}'

curl "http://localhost/api/cart?session_id=sess123"
```

---

## 📡 API Reference

### Product Service (`/api/products`)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/products` | List products (filter: category, brand, min, max, sort) |
| GET | `/api/products/:slug` | Single product + related + reviews |
| GET | `/api/products/featured/all` | Featured products |
| GET | `/api/categories` | All categories |
| GET | `/api/search?q=iphone` | Search products |

### Cart Service (`/api/cart`)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/cart?user_id=1` | Get cart |
| POST | `/api/cart/add` | Add item |
| PUT | `/api/cart/item/:id` | Update quantity |
| DELETE | `/api/cart/item/:id` | Remove item |
| DELETE | `/api/cart` | Clear cart |

### Order Service (`/api/orders`)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/orders` | Place order |
| GET | `/api/orders?user_id=1` | My orders |
| GET | `/api/orders/:id` | Order details |
| GET | `/api/orders/track/:orderNumber` | Track order |
| PATCH | `/api/orders/:id/cancel` | Cancel order |

### User Service (`/api/auth`, `/api/user`)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/register` | Register |
| POST | `/api/auth/login` | Login |
| GET | `/api/user/profile` | Profile (auth required) |
| PUT | `/api/user/profile` | Update profile |
| POST | `/api/user/addresses` | Add address |
| GET | `/api/user/wishlist` | Wishlist |

---

## 🌐 Path-Based Routing (after Phase 5)

Once deployed to AWS EKS, all routes accessible via public IP:

| URL | Page |
|-----|------|
| `http://<IP>/` | Homepage |
| `http://<IP>/clothes` | Clothing page |
| `http://<IP>/electronics` | Electronics page |
| `http://<IP>/footwear` | Footwear page |
| `http://<IP>/cart` | Shopping cart |
| `http://<IP>/orders` | My orders |
| `http://<IP>/user` | Account/Login |
| `http://<IP>/product/:slug` | Product detail |

---

## 🛠 Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Node.js 20, Express 4 |
| Database | MariaDB 11.2 |
| Gateway | Nginx 1.25 |
| Container | Docker (multi-stage builds) |
| Orchestration | Kubernetes (AWS EKS) |
| Infrastructure | Terraform |
| Cloud | AWS (EKS, RDS, ECR, ALB, VPC) |
| CI/CD | GitHub Actions |
| Monitoring | Prometheus + Grafana (Phase 6) |

---

*Built with ❤️ by Abhi+Ejaz*
