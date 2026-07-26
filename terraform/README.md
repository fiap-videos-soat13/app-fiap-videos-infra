# Terraform — FIAP Videos infra

Two-stage setup: **bootstrap** (local state) then **main stack** (remote S3 backend).

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
cp terraform.tfvars.example terraform.tfvars
cp backend.staging.hcl.example backend.staging.hcl   # edit bucket/table from bootstrap output
terraform init -backend-config=backend.staging.hcl
terraform plan
terraform apply
```

CI uses `terraform init -backend=false` for validation only (no AWS credentials required).

## Modules

| Module | Resources |
|--------|-----------|
| `ecr` | Container image repositories |
| `s3` | Video/zip storage bucket |
| `rds` | PostgreSQL instance |
| `secrets` | Secrets Manager placeholders |
| `eks` | EKS cluster, node group, **OIDC provider** |
| `irsa` | IAM roles for API + processor pods (S3 access via IRSA) |

## IRSA → Kubernetes

After `terraform apply`, annotate service accounts:

```yaml
metadata:
  annotations:
    eks.amazonaws.com/role-arn: <api role from output irsa_s3_role_arns.api>
```

Set `k8s_service_account_prefix = "staging-"` to match Kustomize `namePrefix` on ServiceAccounts.

Outputs:

```bash
terraform output irsa_s3_role_arns
```

Set `STORAGE_BACKEND=s3` and bucket env vars in app Deployments when the S3 adapter lands in app repos.

## Production

Duplicate bootstrap + backend config with `environment = "production"` and a separate state key or workspace.
