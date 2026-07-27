# CD setup — FIAP Videos

Deploy is **disabled by default** until AWS and EKS are provisioned.

## Repositories

| Repo | Role |
|------|------|
| `app-fiap-videos-api` | Build and push API image to ECR |
| `app-fiap-videos-processor` | Build and push Processor image to ECR |
| `app-fiap-videos-notifier` | Build and push Notifier image to ECR |
| `app-fiap-videos-infra` | Terraform, K8s manifests, **staging deploy** |

App repos only **build and push** Docker images. Kubernetes deploy runs from the **infra repo** (`deploy-staging.yml` or `make deploy-staging`).

## GitHub secrets (all repos)

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | ECR push and EKS access |
| `AWS_SECRET_ACCESS_KEY` | ECR push and EKS access |

## GitHub variables

### App repos (`api`, `processor`, `notifier`)

No deploy variables required. CD workflows push images on push to `main` or `staging`.

### Infra repo (`app-fiap-videos-infra`)

| Variable | Example | Purpose |
|----------|---------|---------|
| `CD_ENABLED` | `true` | Enables automatic staging deploy on infra changes |
| `S3_BUCKET` | from `terraform output video_bucket_name` | envsubst for staging overlay |
| `API_IRSA_ARN` | from `terraform output irsa_s3_role_arns` | API pod IAM |
| `PROCESSOR_IRSA_ARN` | from `terraform output irsa_s3_role_arns` | Processor pod IAM |
| `ESO_IRSA_ARN` | from `terraform output eso_irsa_role_arn` | External Secrets Operator IAM |

After the first `terraform apply`, copy values:

```bash
cd terraform
terraform output -raw video_bucket_name
terraform output -json irsa_s3_role_arns
terraform output -raw eso_irsa_role_arn
```

## Flow

1. Push to `staging` or `main` in an **app repo** → builds runner + migrator images, pushes to ECR (`latest-staging`, `migrator-staging`, `{sha}` tags).
2. Push to `staging`/`main` in **infra repo** (or manual `workflow_dispatch`) → when `CD_ENABLED=true`, runs `deploy-staging.yml`:
   - Bootstraps cluster addons (metrics-server, ingress-nginx, external-secrets)
   - Applies RabbitMQ + Redis (`k8s/overlays/staging/infra`)
   - Renders staging overlay with `envsubst` (account ID, region, S3 bucket, IRSA ARNs)
   - Runs DB migration Jobs, waits for rollouts

## Local deploy

From `app-fiap-videos-infra` (requires AWS credentials and `terraform` state):

```bash
make platform-up        # terraform apply + cluster addons (first time)
make deploy-staging     # full K8s deploy
make render-staging     # dry-run manifests (dummy env)
```

`export-deploy-env.sh` reads Terraform outputs locally. In CI it uses the GitHub variables above.

## Before first deploy

1. Run Terraform (`make platform-up` or manual `terraform apply`).
2. Create three RDS databases (`fiap_videos_api`, `fiap_videos_processor`, `fiap_videos_notifier`) — see `terraform output rds_init_sql`.
3. Set infra repo GitHub variables (`S3_BUCKET`, IRSA ARNs, `ESO_IRSA_ARN`).
4. Push app images to ECR (app CD workflows).
5. Set `CD_ENABLED=true` on the infra repo and run deploy (`make deploy-staging` or workflow).
