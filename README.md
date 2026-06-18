# 🛒 Abhi+Ejaz Shop
### A Production-Grade E-Commerce Platform (Flipkart × Amazon × Myntra)

> Microservices architecture · Docker · Kubernetes on AWS EKS · Terraform IaC · MariaDB · CI/CD

---

## 📋 Project Phases

|    Phase    |  Status |                           Description                          |
|-------------|---------|----------------------------------------------------------------|
| **Phase 1** | ✅ Done | All 5 backend microservices + MariaDB schema + Docker Compose |
| **Phase 2** | ✅ Done | Full frontend (React/HTML) — all pages with real product UI |
| **Phase 3** | ✅ Done | Production Dockerfiles + ECR push scripts |
| **Phase 4** | ✅ Done | Terraform — AWS VPC + EKS + RDS MariaDB (fully automated) |
| **Phase 5** | ✅ Done | Kubernetes manifests — Ingress, HPA, Secrets, ConfigMaps |
| **Phase 6** | ✅ Done | GitHub Actions CI/CD — push = auto deploy |
| **Phase 7** | ✅ Done | Monitoring with DataDog & for testing Grafana As well |
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
# Sonar webhook test

# Screenshots of WebPage

<img width="1600" height="900" alt="a6689bb5-cdd9-4990-b5b8-bb1e7547e4e5" src="https://github.com/user-attachments/assets/2888a51d-73ba-4ec3-b609-eb2dbe19640c" />

<img width="1600" height="900" alt="a1d569b3-ecf5-406a-830b-7d5da3dda5bc" src="https://github.com/user-attachments/assets/e2675b95-fe21-47f7-a751-5a7eb74d97bd" />

<img width="1600" height="900" alt="293891b3-1dfd-46ae-a39f-81da78bee5f2" src="https://github.com/user-attachments/assets/44ddd9a0-8fca-4d9e-bfec-cb641f959e62" />

<img width="1600" height="900" alt="42f1ff93-af0a-4b83-831a-337ced1e2170" src="https://github.com/user-attachments/assets/ba0d572f-7e13-4d4b-8131-61723b4813b7" />

<img width="1600" height="900" alt="1bf68974-2464-4ff4-aab6-9f9d2ab80307" src="https://github.com/user-attachments/assets/d1243f39-9c03-420b-8c64-ef64f8c6db9d" />

# Screenshots of CI/CD Pipeline

<img width="1600" height="900" alt="2915e16e-753f-48cc-8c05-12a88cb831e7" src="https://github.com/user-attachments/assets/6db3d557-fec1-4efa-829d-6d23df86af8b" />

<img width="1600" height="900" alt="31b1d0f5-f194-41f1-83ff-e6fab12c0096" src="https://github.com/user-attachments/assets/a7428567-5c83-4e6e-b6b3-2dfad116d5e1" />

# Screenshots of Monitoring Tools

<img width="1600" height="900" alt="7b17c769-0d7a-42b0-9267-1838781b1096" src="https://github.com/user-attachments/assets/d57bc685-313f-46a8-8516-da978a8afcb1" />

<img width="1600" height="900" alt="38a10728-fb66-4955-94b1-0129aee35a8b" src="https://github.com/user-attachments/assets/96b01eeb-e3b4-4dbf-93b5-f732648e45e6" />

<img width="1600" height="900" alt="57379378-e66b-4c88-a3c2-227878a63687" src="https://github.com/user-attachments/assets/9eab0c01-7ecc-47c7-a3e9-bd77362c9d57" />

<img width="1600" height="900" alt="b9d58634-b31a-44b8-bbe4-246a7d3c13cd" src="https://github.com/user-attachments/assets/db065abc-f31f-4539-958b-a72b0b683e1e" />

<img width="1600" height="900" alt="bdd44a34-8754-4313-b41e-cf2ef656c0fb" src="https://github.com/user-attachments/assets/8782564b-dccb-4a60-9597-cf41a8ca9a91" />

<img width="1600" height="900" alt="d6c161f2-e439-4fd4-a454-db08feb48813" src="https://github.com/user-attachments/assets/5447b0f9-a276-4e44-86b5-95a18f6fa6b6" />

<img width="1600" height="900" alt="eca19858-dec5-443c-974e-3a7918109bd7" src="https://github.com/user-attachments/assets/47ca74b0-002e-4b73-94b6-b59e9e39d092" />

<img width="1600" height="900" alt="ee8df97b-2b76-45d5-abec-5418e80e61cb" src="https://github.com/user-attachments/assets/b50fa3f3-3908-426b-bcb3-cb353cd2e64b" />

<img width="1600" height="900" alt="f33bf705-8c14-4885-80ae-a7ace2e21f92" src="https://github.com/user-attachments/assets/a29bb509-6a0c-4010-8afb-5c0578cc6dbf" />

<img width="1600" height="900" alt="feed0b0c-a758-4e57-854c-04291ca04924" src="https://github.com/user-attachments/assets/17cde113-52e1-42e5-af7c-bbb50e719bce" />



# Built with ❤️ by Abhi+Ejaz



