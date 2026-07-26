# External Secrets Operator (ESO)

Staging and production overlays sync `fiap-videos-secrets` from **AWS Secrets Manager** instead of the placeholder Secret in `k8s/base/secrets/`.

## Prerequisites

1. Install [External Secrets Operator](https://external-secrets.io/) on the cluster.
2. Create an IAM role for the ESO service account (read access to Secrets Manager keys created by Terraform `modules/secrets`).
3. Annotate the ESO service account:

```yaml
eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/fiap-videos-staging-external-secrets
```

## Terraform secret names

| Kubernetes key | Secrets Manager name |
|----------------|----------------------|
| `JWT_SECRET` | `fiap-videos/{env}/jwt-secret` |
| `DATABASE_URL` | `fiap-videos/{env}/database-url` |
| `RABBITMQ_URL` | `fiap-videos/{env}/rabbitmq-url` |

Optional notifier SMTP keys can be added later from `fiap-videos/{env}/smtp-config` (store JSON in AWS).

## Apply order

```bash
# 1. Install ESO (once per cluster)
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace

# 2. Wire IAM + populate Secrets Manager values

# 3. Apply overlay (includes ClusterSecretStore + ExternalSecret)
kubectl apply -k k8s/overlays/staging
```

## Local / CI without ESO

`k8s/base` still ships `app-secrets.yaml` placeholders. Only overlays delete that Secret and expect ESO to materialize `fiap-videos-secrets`.

For offline `kubectl kustomize` validation, ESO CRDs are ignored by kubeconform (`-ignore-missing-schemas`).
