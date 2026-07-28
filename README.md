# app-fiap-videos-infra

Local development platform and cloud infrastructure for FIAP Videos SOAT13.

## Layout

```
docker/              # Docker Compose (full stack + dependency profiles)
prometheus/          # Local metrics scrape config
grafana/             # Local dashboards and provisioning
insomnia/            # API collection for manual testing (Insomnia)
k8s/base/            # Kubernetes Deployments, Ingress, migration Jobs
k8s/overlays/        # staging / production Kustomize overlays
terraform/           # AWS: EKS, ECR, RDS, S3, Secrets Manager, IRSA
docs/                # CD setup and operational guides
README-database.md   # PostgreSQL layout, migrations, RDS setup
README-CICD.md       # GitHub Actions deploy configuration
```

## Architecture

### System context

Event-driven **choreography** over a shared RabbitMQ topic exchange. Each app service owns its PostgreSQL database and communicates only through domain events — no shared tables, no orchestrator.

```mermaid
graph TB
    User["User (Browser / API client)"]

    subgraph Platform["Platform (this repo)"]
        API["API :3000"]
        Processor["Processor :3001"]
        Notifier["Notifier :3002"]
        PG[("PostgreSQL — 3 DBs")]
        Redis[("Redis")]
        RMQ["RabbitMQ"]
        Storage["Object storage<br/>MinIO or S3"]
    end

    User --> API
    API --> PG
    API --> Redis
    API --> Storage
    API -- "VideoProcessingRequested" --> RMQ
    RMQ --> Processor
    Processor --> PG
    Processor --> Storage
    Processor -- "Started / Completed / Failed" --> RMQ
    RMQ --> API
    RMQ --> Notifier
    Notifier --> PG
    Notifier --> SMTP
```

### Event catalog

Exchange: `fiap-videos.events` (topic). DLX: `fiap-videos.events.dlx`. Queues: `fiap-videos.{service}.{eventType}`.

| Event | Producer | Consumers |
|-------|----------|-----------|
| `VideoProcessingRequested` | API | Processor, Notifier |
| `VideoProcessingStarted` | Processor | API |
| `VideoProcessingCompleted` | Processor | API, Notifier |
| `VideoProcessingFailed` | Processor | API, Notifier |

Reliability: transactional **outbox** (API, Processor), **inbox** on all consumers, per-queue DLQs, correlation IDs on every envelope.

### Local stack (`docker/`)

Compose wires all services and dependencies for full-stack development:

| Layer | Components |
|-------|------------|
| Apps | API, Processor, Notifier (built from sibling repos) |
| Data | PostgreSQL (3 databases), Redis, RabbitMQ |
| Storage | MinIO (`STORAGE_BACKEND=minio`) |
| Observability | Prometheus, Grafana |
| Mail | MailHog (SMTP capture) |

Isolated service repos start only their own Postgres; they share the **single RabbitMQ** instance from this compose file (`localhost:5673`).

### AWS (`terraform/`)

Two-stage Terraform: **bootstrap** (S3 remote state) → **main stack**.

| Module | Resources |
|--------|-----------|
| `ecr` | Container image repositories |
| `s3` | Video/zip object bucket |
| `rds` | PostgreSQL (per-service databases) |
| `secrets` | Secrets Manager (DB URLs, JWT, messaging, SMTP) |
| `eks` | Kubernetes cluster and node groups |
| `irsa` / `eso-irsa` | Pod IAM for S3 and External Secrets Operator |

Production data plane: RDS, S3, in-cluster or managed RabbitMQ/Redis (see `terraform.tfvars`).

### Kubernetes (`k8s/`)

Kustomize layout:

```
k8s/
├── base/              # Deployments, Services, Ingress, migration Jobs, HPA
├── overlays/
│   ├── local/         # kind cluster + in-cluster Postgres, Redis, RabbitMQ, MinIO
│   ├── staging/
│   └── production/    # IRSA, External Secrets, storage patches
└── docs/              # IRSA, HPA, External Secrets guides
```

App CD workflows push images to ECR; **staging deploy** runs from this repo (`make deploy-staging` or `.github/workflows/deploy-staging.yml`).

## Local development

Full stack via Docker Compose:

```bash
cd docker
cp .env.example .env   # edit JWT_SECRET if needed
docker compose up --build
```

| Service | Port | Description |
|---------|------|-------------|
| API | 3000 | Upload, auth, status, download |
| Processor | 3001 | ffmpeg workers + zip |
| Notifier | 3002 | Email notifications |
| PostgreSQL | 5432 | 3 databases |
| Redis | 6380 | List cache |
| RabbitMQ | 5673 / 15673 | Shared message broker |
| MinIO (S3 API) | 9000 | Object storage |
| MinIO console | 9001 | `minioadmin` / `minioadmin` |
| MailHog | 8025 | Test email UI |
| Prometheus | 9091 | Metrics |
| Alertmanager | 9093 | Alerts (dev: webhook dummy) |
| Grafana | 3003 | Dashboards |

### Dependencies only (yarn start:dev)

```bash
cd docker
docker compose up postgres redis rabbitmq mailhog minio minio-init -d
```

Shared RabbitMQ for isolated service compose files:

```bash
cd docker
docker compose up rabbitmq -d
```

All services use `RABBITMQ_URL=amqp://fiap:fiap@localhost:5673/`.

## AWS / Kubernetes

### Prerequisites

- Terraform >= 1.5
- AWS CLI configured for `us-east-2`
- kubectl + kustomize

### Terraform

```bash
# 1. Bootstrap remote state
cd terraform/bootstrap && terraform init && terraform apply

# 2. Main stack
cd ../terraform
cp backend.staging.hcl.example backend.staging.hcl   # use bootstrap outputs
terraform init -backend-config=backend.staging.hcl
terraform plan
terraform apply
```

See [terraform/README.md](terraform/README.md) for IRSA role outputs and module details.

### Kubernetes

```bash
# First time: provision AWS + cluster addons
make platform-up

# Deploy staging (infra + apps + migrations)
make deploy-staging

# Dry-run rendered manifests
make render-staging
```

Staging overlays use `${AWS_ACCOUNT_ID}`, `${S3_BUCKET}`, and IRSA ARNs — rendered via `envsubst` from Terraform outputs (local) or GitHub variables (CI). Do not run plain `kubectl apply -k` on staging without rendering.

#### Local Kubernetes (kind)

For local manifest testing with an in-cluster stack (Postgres, Redis, RabbitMQ, MinIO, MailHog):

**Prerequisites:** Docker, [kind](https://kind.sigs.k8s.io/), kubectl

The bootstrap script installs **ingress-nginx** and **metrics-server** (required for `kubectl top` and HPAs on kind).

```bash
# From app-fiap-videos-infra — builds images, creates cluster, applies overlay
./k8s/scripts/kind-local.sh
```

Add to `/etc/hosts`:

```
127.0.0.1 api.fiap-videos.local
```

API: `http://api.fiap-videos.local:8080`

Manual apply (if images are already built and loaded):

```bash
kubectl apply -k k8s/overlays/local
```

Teardown:

```bash
kubectl delete -k k8s/overlays/local
kind delete cluster --name fiap-videos
```

Image tags are patched per overlay. CD workflows in each app repo push to ECR and apply overlays from this repo.

See [k8s/docs/IRSA.md](k8s/docs/IRSA.md), [k8s/docs/HPA.md](k8s/docs/HPA.md), and [k8s/docs/EXTERNAL-SECRETS.md](k8s/docs/EXTERNAL-SECRETS.md) for pod IAM, autoscaling, and secrets setup.

See [README-CICD.md](README-CICD.md) for GitHub Actions deploy configuration and [README-database.md](README-database.md) for PostgreSQL layout and migrations.

## Related repos

| Repo | Role |
|------|------|
| `app-fiap-videos-api` | HTTP edge |
| `app-fiap-videos-processor` | ffmpeg worker |
| `app-fiap-videos-notifier` | e-mail worker |

## Secrets

Production overlays expect **External Secrets Operator** syncing from AWS Secrets Manager keys created by Terraform (`terraform/modules/secrets`). See [k8s/docs/EXTERNAL-SECRETS.md](k8s/docs/EXTERNAL-SECRETS.md).

## Observabilidade

Prometheus carrega regras em `prometheus/alerts.yml` e encaminha para Alertmanager (`:9093`).  
Em produção, substitua o receiver dummy em `prometheus/alertmanager.yml` por Slack/e-mail.
