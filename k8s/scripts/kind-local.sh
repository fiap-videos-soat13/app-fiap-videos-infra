#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-fiap-videos}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_DIR="$(cd "${K8S_DIR}/.." && pwd)"
WORKSPACE_DIR="$(cd "${INFRA_DIR}/.." && pwd)"
OVERLAY_DIR="${K8S_DIR}/overlays/local"
KIND_CONFIG="${K8S_DIR}/kind/cluster.yaml"
INGRESS_MANIFEST="https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"
METRICS_SERVER_MANIFEST="https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

build_images() {
  local service="$1"
  local context="${WORKSPACE_DIR}/${service}"

  if [[ ! -d "${context}" ]]; then
    echo "Service directory not found: ${context}" >&2
    exit 1
  fi

  echo "Building ${service} images..."
  docker build -t "${service}:local" "${context}"
  docker build -t "${service}:local-migrator" --target migrator "${context}"
}

wait_for_job() {
  local namespace="$1"
  local job="$2"
  kubectl -n "${namespace}" wait --for=condition=complete "job/${job}" --timeout=300s
}

install_metrics_server() {
  echo "Installing metrics-server..."
  kubectl apply -f "${METRICS_SERVER_MANIFEST}"
  kubectl -n kube-system patch deployment metrics-server --type=json -p='[
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}
  ]'
  kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
}

main() {
  require docker
  require kind
  require kubectl

  if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
    echo "Creating kind cluster '${CLUSTER_NAME}'..."
    kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}"
  else
    echo "Using existing kind cluster '${CLUSTER_NAME}'"
  fi

  kubectl config use-context "kind-${CLUSTER_NAME}"

  echo "Installing ingress-nginx..."
  kubectl apply -f "${INGRESS_MANIFEST}"
  kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s

  install_metrics_server

  for service in app-fiap-videos-api app-fiap-videos-processor app-fiap-videos-notifier; do
    build_images "${service}"
    kind load docker-image "${service}:local" --name "${CLUSTER_NAME}"
    kind load docker-image "${service}:local-migrator" --name "${CLUSTER_NAME}"
  done

  echo "Applying local overlay..."
  kubectl apply -k "${OVERLAY_DIR}"

  echo "Waiting for infrastructure..."
  kubectl -n fiap-videos rollout status deploy/postgres --timeout=300s
  kubectl -n fiap-videos rollout status deploy/redis --timeout=180s
  kubectl -n fiap-videos rollout status deploy/rabbitmq --timeout=300s
  kubectl -n fiap-videos rollout status deploy/minio --timeout=180s
  kubectl -n fiap-videos rollout status deploy/mailhog --timeout=180s

  echo "Waiting for database migrations..."
  wait_for_job fiap-videos fiap-videos-api-db-migration
  wait_for_job fiap-videos fiap-videos-processor-db-migration
  wait_for_job fiap-videos fiap-videos-notifier-db-migration
  wait_for_job fiap-videos minio-init

  echo "Waiting for application deployments..."
  kubectl -n fiap-videos rollout status deploy/fiap-videos-api --timeout=300s
  kubectl -n fiap-videos rollout status deploy/fiap-videos-processor --timeout=300s
  kubectl -n fiap-videos rollout status deploy/fiap-videos-notifier --timeout=300s

  cat <<EOF

Local Kubernetes stack is ready.

Add this to /etc/hosts if needed:
  127.0.0.1 api.fiap-videos.local

Endpoints:
  API:              http://api.fiap-videos.local:8080
  RabbitMQ UI:      kubectl -n fiap-videos port-forward svc/rabbitmq 15673:15672
  MailHog UI:       kubectl -n fiap-videos port-forward svc/mailhog 8025:8025
  MinIO console:    kubectl -n fiap-videos port-forward svc/minio 9001:9001

Useful commands:
  kubectl -n fiap-videos get pods
  kubectl top pods -n fiap-videos
  kubectl -n fiap-videos get hpa
  kubectl -n fiap-videos logs deploy/fiap-videos-api -f
  kubectl delete -k ${OVERLAY_DIR}
  kind delete cluster --name ${CLUSTER_NAME}
EOF
}

main "$@"
