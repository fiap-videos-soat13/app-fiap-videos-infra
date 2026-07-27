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
```

## Local development

Full stack via Docker Compose:

```bash
cd docker
docker compose up --build
```

| Service | Port | Description |
|---------|------|-------------|
| API | 3000 | Upload, auth, status, download |
| Processor | 3001 | ffmpeg workers + zip |
| Notifier | 3002 | Email notifications |
| PostgreSQL | 5433 | 3 databases |
| Redis | 6380 | List cache |
| RabbitMQ | 5673 / 15673 | Shared message broker |
| MinIO (S3 API) | 9000 | Object storage |
| MinIO console | 9001 | `minioadmin` / `minioadmin` |
| MailHog | 8025 | Test email UI |
| Prometheus | 9091 | Metrics |
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
# After EKS cluster exists and kubeconfig is set
kubectl apply -k k8s/overlays/staging
```

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

See [docs/CICD-SETUP.md](docs/CICD-SETUP.md) for GitHub Actions deploy configuration.

## Related repos

| Repo | Role |
|------|------|
| `app-fiap-videos-api` | HTTP edge |
| `app-fiap-videos-processor` | ffmpeg worker |
| `app-fiap-videos-notifier` | e-mail worker |

## Secrets

Production overlays expect **External Secrets Operator** syncing from AWS Secrets Manager keys created by Terraform (`terraform/modules/secrets`). See [k8s/docs/EXTERNAL-SECRETS.md](k8s/docs/EXTERNAL-SECRETS.md).
