#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=export-deploy-env.sh
source "${SCRIPT_DIR}/export-deploy-env.sh"

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require kubectl
require envsubst

K8S_NAMESPACE="${K8S_NAMESPACE:-fiap-videos}"
OVERLAY_DIR="${INFRA_DIR}/k8s/overlays/staging"
INFRA_OVERLAY="${OVERLAY_DIR}/infra"

echo "Configuring kubectl for ${EKS_CLUSTER_NAME} (${AWS_REGION})..."
aws eks update-kubeconfig --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}"

echo "Cleaning up stale migration jobs from previous deploys..."
kubectl -n "${K8S_NAMESPACE}" delete jobs -l app.kubernetes.io/part-of=fiap-videos --ignore-not-found=true 2>/dev/null || true

echo "Applying messaging infra (RabbitMQ + Redis)..."
kubectl apply -k "${INFRA_OVERLAY}"
if ! kubectl -n "${K8S_NAMESPACE}" rollout status deploy/rabbitmq --timeout=300s; then
  echo ""
  echo "RabbitMQ rollout failed. Common cause on t3.small: node pod limit (11 pods/node)." >&2
  kubectl -n "${K8S_NAMESPACE}" describe pod -l app=rabbitmq | tail -20 >&2
  echo "Fix: scale the node group (make platform-up with eks_node_desired_size >= 2) or use t3.medium." >&2
  exit 1
fi
kubectl -n "${K8S_NAMESPACE}" rollout status deploy/redis --timeout=180s

echo "Applying staging application overlay..."
kubectl kustomize "${OVERLAY_DIR}" | envsubst "${ENVSUBST_VARS}" | kubectl apply -f -

wait_for_job() {
  local job="$1"
  kubectl -n "${K8S_NAMESPACE}" wait --for=condition=complete "job/${job}" --timeout=600s
}

echo "Waiting for database migrations..."
wait_for_job "staging-fiap-videos-api-db-migration"
wait_for_job "staging-fiap-videos-processor-db-migration"
wait_for_job "staging-fiap-videos-notifier-db-migration"

echo "Waiting for application rollouts..."
kubectl -n "${K8S_NAMESPACE}" rollout status deploy/staging-fiap-videos-api --timeout=600s
kubectl -n "${K8S_NAMESPACE}" rollout status deploy/staging-fiap-videos-processor --timeout=600s
kubectl -n "${K8S_NAMESPACE}" rollout status deploy/staging-fiap-videos-notifier --timeout=600s

echo ""
echo "Staging deploy complete."
kubectl -n "${K8S_NAMESPACE}" get pods
kubectl -n "${K8S_NAMESPACE}" get ingress
