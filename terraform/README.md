# Terraform — FIAP Videos infra

Two-stage setup: **bootstrap** (local state) then **main stack** (remote S3 backend).

## Free Tier / credits profile

For hackathon staging with ~$120 AWS credits:

```bash
cp terraform.tfvars.free-tier.example terraform.tfvars
```

Defaults:

| Setting | Value | Why |
|---------|-------|-----|
| EKS nodes | 1× `t3.small` | Cheaper than 2× `t3.medium` |
| RDS | `db.t3.micro`, 20 GB | Free Tier eligible |
| RabbitMQ / Redis | In-cluster URLs | Avoids Amazon MQ / ElastiCache cost |
| Secrets | Auto-filled on apply | DB URLs, JWT, messaging URLs |

**Still expect ~$90–110/month** if the cluster runs 24/7 (mostly EKS control plane ~$73). Run `terraform destroy` when not testing.

## 1. Bootstrap remote state (once per environment)

Creates the S3 state bucket and DynamoDB lock table.

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Note the `backend_config` output — copy values into `../backend.staging.hcl` (from `backend.staging.hcl.example`).

## 2. Main stack

```bash
cd terraform
cp terraform.tfvars.free-tier.example terraform.tfvars   # or terraform.tfvars.example
cp backend.staging.hcl.example backend.staging.hcl       # edit bucket/table from bootstrap output
terraform init -backend-config=backend.staging.hcl
terraform plan
terraform apply
```

After apply:

```bash
terraform output configure_kubectl
terraform output kustomize_replacements
terraform output -raw rds_init_sql
```

Configure kubectl:

```bash
aws eks update-kubeconfig --region <region> --name fiap-videos-staging
```

### One-time RDS setup

RDS creates only the default database `fiap_videos`. Create per-service databases from a pod in the VPC:

```bash
kubectl run psql-init --rm -it --restart=Never \
  --image=postgres:16-alpine \
  --env="PGPASSWORD=$(terraform output -raw rds_password)" \
  -- psql -h "$(terraform output -raw rds_endpoint)" -U fiap -d fiap_videos \
  -c "CREATE DATABASE fiap_videos_api;" \
  -c "CREATE DATABASE fiap_videos_processor;" \
  -c "CREATE DATABASE fiap_videos_notifier;"
```

Or use the full script from `terraform output -raw rds_init_sql`.

### Patch Kubernetes overlays

Use `terraform output kustomize_replacements`:

- `REPLACE_AWS_ACCOUNT` → ECR image URLs and IRSA ARNs
- `REPLACE_AWS_REGION` → `k8s/overlays/staging/external-secrets/cluster-secret-store.yaml`
- S3 bucket → `patches/storage-config.yaml`
- ESO role → annotate `external-secrets` service account in namespace `external-secrets`

CI uses `terraform init -backend=false` for validation only (no AWS credentials required).

## Modules

| Module | Resources |
|--------|-----------|
| `ecr` | Container image repositories |
| `s3` | Video/zip storage bucket |
| `rds` | PostgreSQL instance (`db.t3.micro`) |
| `secrets` | Secrets Manager keys + initial values |
| `eks` | EKS cluster, node group, OIDC provider |
| `irsa` | IAM roles for API + processor pods (S3 via IRSA) |
| `eso-irsa` | IAM role for External Secrets Operator |

## Tear down (save credits)

```bash
cd terraform
terraform destroy
```

Bootstrap state bucket is separate; destroy it only when decommissioning the project.

## Production

Duplicate bootstrap + backend config with `environment = "production"` and a separate state key or workspace.
