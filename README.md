# Healthcare PHI API

A production-grade **Patient Health Information (PHI) management system** built with Ruby on Rails 8. Designed for healthcare environments where data security, auditability, and access control are non-negotiable.

Healthcare PHI API provides a secure REST API for managing patient records, controlling role-based access, and maintaining a full audit trail — with all sensitive fields encrypted at rest using AES-256-GCM.

---

## Table of Contents

- [Tech Stack](#tech-stack)
- [Architecture Decisions](#architecture-decisions)
- [Roles & Permissions](#roles--permissions)
- [Getting Started](#getting-started)
- [Environment Variables](#environment-variables)
- [API Documentation](#api-documentation)
- [Running Tests](#running-tests)
- [Background Jobs](#background-jobs)
- [Kubernetes Deployment](#kubernetes-deployment)
- [Deployment](#deployment)
- [Security Notes](#security-notes)
- [Postman Collection](#postman-collection)
- [Swagger API Demo](#swagger-api-demo)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Ruby on Rails 8 (API-only) |
| Database | PostgreSQL |
| Cache / Queue backend | Redis |
| Background jobs | Sidekiq |
| Message broker | Apache Kafka + Zookeeper |
| Kafka consumer | Karafka |
| Authentication | JWT (with JTI revocation) |
| Authorisation | Pundit (RBAC) |
| Encryption | Active Record Encryption — AES-256-GCM |
| API Docs | rswag / OpenAPI 3.0 (Swagger UI) |
| Testing | RSpec + SimpleCov |
| CI | GitHub Actions |
| Containerisation | Docker / Docker Compose |
| Orchestration | Kubernetes (Minikube for local) |

---

## Architecture Decisions

### JWT with JTI Revocation
Stateless JWT authentication keeps the API horizontally scalable with no session store. Each token carries a unique `jti` (JWT ID) claim stored in Redis. On logout or forced revocation, the JTI is added to a blocklist — giving us the revocability of sessions without the overhead of a session table.

### Active Record Encryption (AES-256-GCM)
PHI fields (`name`, `email`, `diagnosis`, etc.) are encrypted transparently via Rails' built-in `encrypts` macro. Encryption keys are derived from `rails credentials` using `rails db:encryption:init`, meaning plaintext PHI never touches the database. The application queries and decrypts in memory only when needed.

### Pundit for RBAC
Pundit was chosen over CanCanCan for its explicit, per-policy files that map 1:1 with models. In a compliance-sensitive codebase, each policy being a plain Ruby class makes access rules easy to audit and test in isolation.

### Three-Layer Idempotency on Access Requests
`POST /api/v1/access_requests` is protected against duplicate submissions at three levels:
1. **Application check** — query for an existing record with the same `request_id` before inserting
2. **Database unique index** — enforces uniqueness at the DB level regardless of concurrency
3. **`rescue RecordNotUnique`** — handles the race window between steps 1 and 2 gracefully

### Redis Distributed Locking
`ProcessPhiJob` acquires a per-record distributed lock before mutating state. This prevents double-processing when the same job is enqueued multiple times (e.g. after a Sidekiq retry).

### Fail-Open Rate Limiting
The `Middleware::RateLimiter` Rack middleware enforces rate limits via Redis. If Redis becomes unavailable, the middleware **fails open** — requests are passed through rather than blocked. This prioritises availability over strict enforcement during infrastructure incidents.

---

## Roles & Permissions

| Action | `admin` | `doctor` | `nurse` | `lab_technician` |
|---|:---:|:---:|:---:|:---:|
| Manage users | ✅ | ❌ | ❌ | ❌ |
| View all patients | ✅ | ✅ | ✅ | ✅ |
| Create / update patients | ✅ | ✅ | ❌ | ❌ |
| View medical records | ✅ | ✅ | ✅ | ✅ |
| Create medical records | ✅ | ✅ | ❌ | ❌ |
| Approve access requests | ✅ | ✅ | ❌ | ❌ |
| View audit logs | ✅ | ❌ | ❌ | ❌ |

---

## Getting Started

### Prerequisites

- Docker & Docker Compose
- Ruby 3.x (only needed for local development without Docker)

### 1. Clone and boot

```bash
git clone https://github.com/vish-patil145/healthcare_phi_api.git
cd phi_vault_api
docker compose up --build
```

This starts Rails, PostgreSQL, Redis, and Sidekiq.

### 2. Set up the database

```bash
docker compose exec web rails db:create db:migrate db:seed
```

The seed file creates sample users for each role. Credentials are printed to the console on first run.

### 3. Get a JWT token

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@example.com", "password": "password"}'
```

Copy the `token` from the response and pass it as a Bearer token on subsequent requests:

```bash
curl http://localhost:3000/api/v1/patients \
  -H "Authorization: Bearer <your_token>"
```

---

## Environment Variables

Copy `.env.example` to `.env` and fill in the values before running locally.

| Variable | Description | Default |
|---|---|---|
| `DATABASE_URL` | PostgreSQL connection string | set by Docker Compose |
| `REDIS_URL` | Redis connection string | `redis://redis:6379/0` (Docker) |
| `RAILS_MASTER_KEY` | Decrypts `config/credentials.yml.enc` | required |
| `SECRET_KEY_BASE` | Rails session / cookie signing key | required in production |
| `JWT_SECRET` | Signs JWT tokens | derived from credentials |

> **Never commit `.env` or `config/master.key` to version control.**

---

## API Documentation

Interactive Swagger UI is available at:

```
http://localhost:3000/api-docs
```

The spec is a handwritten OpenAPI 3.0 YAML file (`swagger/v1/swagger.yaml`) with full request/response schemas, authentication flows, and example payloads for all endpoints.

### Key endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/v1/auth/login` | Obtain a JWT token |
| `DELETE` | `/api/v1/auth/logout` | Revoke the current token |
| `GET` | `/api/v1/patients` | List patients (paginated) |
| `POST` | `/api/v1/patients` | Create a patient |
| `GET` | `/api/v1/patients/:id/medical_records` | List medical records |
| `POST` | `/api/v1/access_requests` | Request PHI access (idempotent) |
| `GET` | `/api/v1/audit_logs` | View audit trail (admin only) |

---

## Running Tests

```bash
# Run the full suite
COVERAGE=true bundle exec rspec

# Run a specific file
bundle exec rspec spec/controllers/patients_controller_spec.rb

# Open the coverage report
open coverage/index.html
```

### Current coverage

| Layer | Coverage |
|---|---|
| Controllers | 100.0% |
| Models | 100.0% |
| Channels | 100.0% |
| Helpers | 100.0% |
| Mailers | 100.0% |
| Jobs | 100.0% |
| Libraries | 100.0% |
| **Overall** | **100.0%** |

---

## Background Jobs

### `ProcessPhiJob`

Processes PHI records asynchronously via Sidekiq.

```
Queue:    default
Retries:  3 attempts, 5-second wait between attempts
```

**Flow:**
1. Acquires a distributed Redis lock on the record
2. Checks if the record is already `completed` — returns early if so (idempotent)
3. Marks the record as `processing`
4. Performs the PHI processing work
5. Marks the record as `completed`
6. On any error: marks the record as `failed` and re-raises so Sidekiq retries

Monitor jobs via the Sidekiq Web UI at `/sidekiq` (admin access required).

---

## Kubernetes Deployment

The full stack is orchestrated with Kubernetes. For local development, [Minikube](https://minikube.sigs.k8s.io/) is used to run a single-node cluster inside Docker.

### Architecture

```
Minikube Cluster (local)
└── Namespace: healthcare
     ├── rails-web        (Deployment — 2 replicas)
     ├── sidekiq          (Deployment — 1 replica)
     ├── karafka          (Deployment — 1 replica)
     ├── postgres         (Deployment + PersistentVolumeClaim)
     ├── redis            (Deployment)
     ├── kafka            (Deployment)
     └── zookeeper        (Deployment)
```

Every docker-compose service maps to a Kubernetes **Deployment** and a **Service** for internal DNS routing. Sensitive values (passwords, keys) live in a Kubernetes **Secret**; non-sensitive config lives in a **ConfigMap**.

### Kubernetes folder structure

```
kubernetes/
├── namespace.yaml
├── secrets.yaml
├── configmap.yaml
├── postgres/
│   ├── pvc.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── redis/
│   ├── deployment.yaml
│   └── service.yaml
├── zookeeper/
│   ├── deployment.yaml
│   └── service.yaml
├── kafka/
│   ├── deployment.yaml
│   └── service.yaml
├── rails/
│   ├── deployment.yaml
│   └── service.yaml
├── sidekiq/
│   └── deployment.yaml
└── karafka/
    └── deployment.yaml
```

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (required as Minikube driver)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) — Kubernetes CLI
- [Minikube](https://minikube.sigs.k8s.io/docs/start/) — local Kubernetes cluster
- [Helm](https://helm.sh/docs/intro/install/) — Kubernetes package manager

### 1. Install kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client
```

### 2. Install Minikube

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube version
```

### 3. Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### 4. Start Minikube

```bash
minikube start --driver=docker --cpus=2 --memory=4096
kubectl get nodes
# NAME       STATUS   ROLES           AGE   VERSION
# minikube   Ready    control-plane   1m    v1.35.x
```

> If you get a Docker permission error: `sudo usermod -aG docker $USER && newgrp docker`

### 5. Enable addons

```bash
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard
```

### 6. Build the Docker image inside Minikube

Minikube runs its own Docker daemon. You must build the image inside it so Kubernetes can find it.

```bash
# Point your shell to Minikube's Docker
eval $(minikube docker-env)

# Build the production image
docker build --target production -t healthcare-phi-api:latest .

# Verify
docker images | grep healthcare
```

> **Important:** Run `eval $(minikube docker-env)` again after every Minikube restart.

### 7. Configure secrets

Edit `kubernetes/secrets.yaml` and fill in your values before deploying:

```yaml
stringData:
  db-user: "postgres"
  db-password: "yourpassword"
  db-name: "healthcare_phi_api_development"
  secret-key-base: "<output of rails secret>"
  redis-url: "redis://redis-service:6379/0"
  database-url: "postgres://postgres:yourpassword@postgres-service:5432/healthcare_phi_api_development"
```

> Note: All hostnames must use Kubernetes Service names (`postgres-service`, `redis-service`, `kafka-service`) — **not** docker-compose service names (`db`, `redis`, `kafka`).

### 8. Deploy all services

```bash
# Foundation
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/secrets.yaml
kubectl apply -f kubernetes/configmap.yaml

# Infrastructure (Postgres, Redis, Kafka)
kubectl apply -f kubernetes/postgres/
kubectl apply -f kubernetes/redis/
kubectl apply -f kubernetes/zookeeper/
kubectl apply -f kubernetes/kafka/

# Wait for database and cache to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n healthcare --timeout=120s
kubectl wait --for=condition=ready pod -l app=redis -n healthcare --timeout=60s

# Application services
kubectl apply -f kubernetes/rails/
kubectl apply -f kubernetes/sidekiq/
kubectl apply -f kubernetes/karafka/
```

### 9. Verify all pods are running

```bash
kubectl get pods -n healthcare
# NAME                         READY   STATUS    RESTARTS   AGE
# postgres-xxx                 1/1     Running   0          2m
# redis-xxx                    1/1     Running   0          2m
# zookeeper-xxx                1/1     Running   0          2m
# kafka-xxx                    1/1     Running   0          2m
# rails-web-xxx                1/1     Running   0          1m
# rails-web-yyy                1/1     Running   0          1m
# sidekiq-xxx                  1/1     Running   0          1m
# karafka-xxx                  1/1     Running   0          1m
```

### 10. Access the API locally

```bash
# Create a tunnel to the Rails service
kubectl port-forward -n healthcare service/rails-service 3000:3000

# In a new terminal — test the health endpoint
curl http://localhost:3000/up
# Returns: HTTP 200 with green response body
```

### Key differences: docker-compose vs Kubernetes

| Concept | docker-compose | Kubernetes |
|---|---|---|
| Service hostname | `db`, `redis`, `kafka` | `postgres-service`, `redis-service`, `kafka-service` |
| Secrets | `.env` file | `kubectl` Secret (base64 encoded) |
| Config | `.env` file | ConfigMap |
| Scaling | manual | `replicas:` in Deployment |
| Crash recovery | manual restart | automatic (always restarts) |
| Health checks | `healthcheck:` block | `readinessProbe` + `livenessProbe` |
| Persistent storage | `volumes:` | PersistentVolumeClaim |

### Useful commands

```bash
# Cluster management
minikube start / stop / status
minikube dashboard          # open visual UI in browser

# Pod management
kubectl get pods -n healthcare
kubectl logs -n healthcare <pod-name>
kubectl describe pod -n healthcare <pod-name>
kubectl exec -n healthcare -it <pod-name> -- bash

# Rolling restart (after image rebuild)
eval $(minikube docker-env)
docker build --target production -t healthcare-phi-api:latest .
kubectl rollout restart deployment/rails-web -n healthcare
kubectl rollout restart deployment/sidekiq -n healthcare
kubectl rollout restart deployment/karafka -n healthcare

# Delete and redeploy everything
kubectl delete namespace healthcare
kubectl apply -f kubernetes/namespace.yaml
# ... re-apply all manifests
```

### Known gotchas

- Always run `eval $(minikube docker-env)` before building — otherwise the image is built in your system Docker, not Minikube's, and pods will get `ImagePullBackOff`.
- The `debug` gem must have `require: false` in the Gemfile — the production image excludes development gems, so `require: "debug/prelude"` causes a `LoadError` at boot.
- Use Kubernetes Service names as hostnames everywhere (`postgres-service:5432`, not `localhost:5432`).
- `db:prepare` runs as a Kubernetes `initContainer` before Rails starts — this ensures migrations are applied before the app accepts traffic.

---

## Deployment

The app is deployed to [Fly.io](https://fly.io).

### First-time setup

```bash
fly auth login
fly launch          # creates fly.toml and provisions Postgres + Redis
fly secrets set RAILS_MASTER_KEY=$(cat config/master.key)
fly deploy
```

### Subsequent deploys

```bash
fly deploy
```

### CI/CD

GitHub Actions runs on every push to `main`:

1. Boots services (Postgres, Redis) via Docker Compose
2. Runs `rails db:create db:migrate`
3. Runs `bundle exec rspec`
4. Deploys to Fly.io on green (main branch only)

See `.github/workflows/ci.yml` for the full pipeline.

---

## Security Notes

| Control | Implementation |
|---|---|
| PHI encryption at rest | `encrypts` macro — AES-256-GCM via Active Record Encryption |
| Token revocation | JTI blocklist in Redis; invalidated on logout |
| Brute-force protection | Rate limiter: 5 requests/min on `/api/v1/auth` |
| General rate limiting | 100 requests/min per user/IP on all other endpoints |
| Access control | Pundit policies enforced on every controller action |
| Audit trail | `AuditLog` records every read and write on PHI |
| PHI filtered from logs | `config.filter_parameters` includes all PHI field names |
| Encrypted credentials | `rails credentials` — never stored in plain text |

---

## Test Suite

The project ships with **454 examples, 0 failures, 100% line coverage** across all layers.

```bash
COVERAGE=true bundle exec rspec
# 454 examples, 0 failures
# Line Coverage: 100.0% (299 / 299)
```

---

## Contributing

1. Branch from `main`: `git checkout -b feature/your-feature`
2. Write tests first — PRs without specs will not be merged
3. Ensure `bundle exec rspec` passes with no failures
4. Open a pull request with a clear description of the change

---

## Postman Collection

Import the collection directly into Postman:

[Open Postman Collection](https://www.postman.co/workspace/My-Workspace~5b8e950f-cab4-440c-8964-715df074bb38/collection/4087353-e1ee6d90-7b42-485c-99fc-9be47ac39418?action=share&creator=4087353)

---

## Swagger API Demo

Watch a walkthrough of the API via Swagger UI:

[View Demo on Google Drive](https://drive.google.com/file/d/1N5GlqUiq9_qCa0gWvvTxgORyjHwhwqRm/view?usp=sharing)

---

*Built with Rails 8 · Secured for healthcare · Tested with RSpec · Orchestrated with Kubernetes*