# External Secrets Operator (ESO)

Staging and production overlays sync **per-service secrets** from **AWS Secrets Manager**. `base` does not ship static secrets — each overlay provides them.

| Kubernetes Secret | Services |
|-------------------|----------|
| `fiap-videos-api-secrets` | API + API migration job |
| `fiap-videos-processor-secrets` | Processor + processor migration job |
| `fiap-videos-notifier-secrets` | Notifier + notifier migration job |

## Prerequisites

1. Install [External Secrets Operator](https://external-secrets.io/) on the cluster.
2. Create an IAM role for the ESO service account (read access to Secrets Manager keys created by Terraform `modules/secrets`).
3. Annotate the ESO service account with the role from Terraform:

```bash
terraform output -raw eso_irsa_role_arn
```

```yaml
eks.amazonaws.com/role-arn: <eso_irsa_role_arn from terraform output>
```

## Terraform secret names

| Kubernetes key | Secrets Manager name |
|----------------|----------------------|
| `JWT_SECRET` | `fiap-videos/{env}/jwt-secret` |
| `DATABASE_URL` (API) | `fiap-videos/{env}/api-database-url` |
| `DATABASE_URL` (processor) | `fiap-videos/{env}/processor-database-url` |
| `DATABASE_URL` (notifier) | `fiap-videos/{env}/notifier-database-url` |
| `REDIS_URL` | `fiap-videos/{env}/redis-url` |
| `RABBITMQ_URL` | `fiap-videos/{env}/rabbitmq-url` |
| `SMTP_*` | `fiap-videos/{env}/smtp-config` (JSON: `host`, `port`, `from`) |

## Apply order

```bash
# 1. Install ESO (once per cluster)
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace

# 2. Wire IAM + populate Secrets Manager values

# 3. Apply overlay (includes ClusterSecretStore + ExternalSecrets)
kubectl apply -k k8s/overlays/staging
```

## Local / CI without ESO

The `local` overlay adds static `secrets/*.yaml` files. No placeholder secret in `base`.

For offline `kubectl kustomize` validation, ESO CRDs are ignored by kubeconform (`-ignore-missing-schemas`).
