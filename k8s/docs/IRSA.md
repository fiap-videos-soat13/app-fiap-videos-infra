# IRSA — Kubernetes ↔ AWS IAM

Pods that access S3 use **IAM Roles for Service Accounts (IRSA)**.

## Service accounts

| K8s ServiceAccount | Deployment | IAM role (Terraform) |
|--------------------|------------|----------------------|
| `fiap-videos-api` | API | `fiap-videos-{env}-api-s3` |
| `fiap-videos-processor` | Processor | `fiap-videos-{env}-processor-s3` |

Notifier has no S3 access (no IRSA role).

Service accounts live in **staging/production overlays only** (`overlays/{env}/serviceaccounts/`). Local kind does not use IRSA.

## Staging overlay

After `terraform apply` in `app-fiap-videos-infra`:

```bash
cd terraform
terraform output irsa_s3_role_arns
```

Replace `REPLACE_AWS_ACCOUNT` in:

- `k8s/overlays/staging/serviceaccounts/api-serviceaccount.yaml`
- `k8s/overlays/staging/serviceaccounts/processor-serviceaccount.yaml`

Or set ARNs exactly from Terraform output (role names must match `modules/irsa`).

## namePrefix note

Staging uses `namePrefix: staging-`, so effective ServiceAccount names are `staging-fiap-videos-api` and `staging-fiap-videos-processor`. Terraform IRSA trust policies must use the **prefixed** names when deploying the staging overlay. See `service_account_prefix` support in `modules/irsa`.

## Verify

```bash
kubectl kustomize k8s/overlays/staging | rg -A3 'kind: ServiceAccount'
aws sts get-caller-identity  # from a pod after S3 adapter is enabled
```
