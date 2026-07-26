# CD setup — FIAP Videos app repos

Deploy is **disabled by default** until AWS and EKS are provisioned.

Applies to `app-fiap-videos-api`, `app-fiap-videos-processor`, and `app-fiap-videos-notifier`.

## GitHub secrets

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | ECR push and EKS deploy |
| `AWS_SECRET_ACCESS_KEY` | ECR push and EKS deploy |
| `INFRA_CHECKOUT_TOKEN` | Optional PAT to checkout private `app-fiap-videos-infra` |

## GitHub variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `CD_ENABLED` | unset / `false` | Set to `true` to run the deploy job on `staging` |
| `EKS_CLUSTER_NAME` | `fiap-videos-staging` | Target EKS cluster |
| `INFRA_REPOSITORY` | `fiap-videos-soat13/app-fiap-videos-infra` | Manifests repo |

`INFRA_K8S_REPOSITORY` is still accepted as a fallback for older workflow versions.

## Flow

1. Push to `staging` or `main` builds **runner** and **migrator** Docker images and pushes to ECR (`latest-staging`, `migrator-staging`, and `{sha}` tags).
2. When `CD_ENABLED=true`, push to `staging` applies `k8s/overlays/staging` and waits for rollout.
3. Run migration Jobs (`*-db-migration`) before or as part of deploy using the `migrator-staging` image tag.

## Before first deploy

1. Run Terraform in `app-fiap-videos-infra/terraform` (EKS + ECR).
2. Create `fiap-videos-secrets` in the cluster (or External Secrets).
3. Replace `REPLACE_AWS_ACCOUNT` in Kustomize overlays with your AWS account ID.
4. Install nginx Ingress Controller on the cluster.
